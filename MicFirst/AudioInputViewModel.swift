import AppKit
import Combine
import CoreAudio
import Foundation

@MainActor
final class AudioInputViewModel: ObservableObject {
    @Published private(set) var devices: [InputDevice] = []
    @Published private(set) var priorityRows: [InputPriorityRow] = []
    @Published private(set) var menuRows: [InputPriorityRow] = []
    @Published private(set) var automaticInputIsEnabled: Bool
    @Published private(set) var currentVolume: Double = 0
    @Published private(set) var volumeIsEnabled = false
    @Published private(set) var errorMessage: String?

    var menuBarIconName: String {
        automaticInputIsEnabled ? "MenuBarIconLocked" : "MenuBarIcon"
    }

    private struct Restoration {
        let token = UUID()
        let uid: String
        let stackBelowNativeHUD: Bool
        let shouldNotify: Bool
        var attempts = 0
    }

    private let audioManager: InputAudioManaging
    private let preferences: InputPriorityStore
    private let hud: InputPriorityHUDPresenting
    private let volumeWriteQueue = DispatchQueue(label: "MicFirst.VolumeWrite", qos: .userInitiated)
    private var volumeWriteWorkItem: DispatchWorkItem?
    private var restorationWorkItem: DispatchWorkItem?
    private var menuRefreshWorkItem: DispatchWorkItem?
    private var restoration: Restoration?
    private var monitoredDeviceID: AudioDeviceID?
    private var suppressVolumeEchoUntil = Date.distantPast
    private var debugHUDObserver: NSObjectProtocol?

    private var currentDevice: InputDevice? { devices.first(where: \.isDefault) }

    init(
        audioManager: InputAudioManaging = CoreAudioInputManager(),
        preferences: InputPriorityStore = InputPriorityStore(),
        hud: InputPriorityHUDPresenting? = nil
    ) {
        self.audioManager = audioManager
        self.preferences = preferences
        self.hud = hud ?? PreferredInputHUD.shared
        automaticInputIsEnabled = preferences.isEnabled
        refresh(shouldNotify: false)
        audioManager.startMonitoring { [weak self] in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        #if DEBUG
            installDebugHUDTrigger()
        #endif
    }

    deinit {
        volumeWriteWorkItem?.cancel()
        restorationWorkItem?.cancel()
        menuRefreshWorkItem?.cancel()
        audioManager.stopMonitoring()
        if let debugHUDObserver {
            DistributedNotificationCenter.default().removeObserver(debugHUDObserver)
        }
    }

    func menuDidOpen() {
        hud.dismissForMenuOpening()
        refresh(shouldNotify: false)
    }

    func settingsDidOpen() {
        refresh(shouldNotify: false)
    }

    func selectDevice(uid: String) {
        do {
            // Resolve the UID again: a device ID or row may have changed since the menu opened.
            applyLoadedDevices(try audioManager.loadInputDevices())
            guard let device = devices.first(where: { $0.uid == uid }), !device.isDefault else { return }
            let wasEnabled = automaticInputIsEnabled
            setAutomaticState(false)
            do {
                try audioManager.setDefaultInputDevice(device.id)
                errorMessage = nil
                refresh(shouldNotify: false)
            } catch {
                setAutomaticState(wasEnabled)
                refresh(shouldNotify: false)
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setAutomaticInputEnabled(_ isEnabled: Bool) {
        guard automaticInputIsEnabled != isEnabled else { return }
        setAutomaticState(isEnabled)
        refresh(shouldNotify: false)
    }

    func moveDevices(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        preferences.move(fromOffsets: offsets, toOffset: destination)
        updatePriorityRows()
        refresh(shouldNotify: false)
    }

    func moveDevice(uid: String, beforeUID: String?, inMenu: Bool = false) {
        let rows = inMenu ? menuRows : priorityRows
        preferences.move(uid: uid, beforeUID: beforeUID, within: rows.map(\.id))
        updatePriorityRows()
        refresh(shouldNotify: false)
    }

    func setDeviceShownInMenu(_ isShown: Bool, uid: String) {
        preferences.setHiddenFromMenu(!isShown, uid: uid)
        updatePriorityRows()
        // Hiding the active input immediately chooses the next eligible device in automatic mode.
        // In manual mode this is only a preference change; it does not change the system route.
        refresh(shouldNotify: false)
    }

    func removeOfflineDevice(uid: String) {
        do {
            // A reconnect while Settings is open must never delete an online device.
            applyLoadedDevices(try audioManager.loadInputDevices())
            preferences.removeOfflineDevice(uid: uid, onlineDevices: devices)
            updatePriorityRows()
            enforcePriority(shouldNotify: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setCurrentVolume(_ volume: Double) {
        let clampedVolume = min(max(volume, 0), 1)
        currentVolume = clampedVolume
        suppressVolumeEchoUntil = Date().addingTimeInterval(0.25)
        guard volumeIsEnabled, let deviceID = currentDevice?.id else { return }
        volumeWriteWorkItem?.cancel()
        let workItem = DispatchWorkItem { [audioManager, weak self] in
            let result = Result { try audioManager.setInputVolume(Float(clampedVolume), for: deviceID) }
            DispatchQueue.main.async {
                guard let self else { return }
                if case .failure(let error) = result {
                    self.refresh(shouldNotify: false)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        volumeWriteWorkItem = workItem
        volumeWriteQueue.asyncAfter(deadline: .now() + 0.045, execute: workItem)
    }

    func openSoundSettings() {
        for urlString in [
            "x-apple.systempreferences:com.apple.Sound-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.sound",
        ] {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) { return }
        }
    }

    private func setAutomaticState(_ isEnabled: Bool) {
        automaticInputIsEnabled = isEnabled
        preferences.setEnabled(isEnabled)
        cancelRestoration()
    }

    private func refresh(shouldNotify: Bool = true) {
        do {
            applyLoadedDevices(try audioManager.loadInputDevices())
            errorMessage = nil
            enforcePriority(shouldNotify: shouldNotify)
        } catch {
            // A failed enumeration is not evidence that remembered devices went offline.
            errorMessage = error.localizedDescription
        }
    }

    private func applyLoadedDevices(_ loadedDevices: [InputDevice]) {
        let previousUID = currentDevice?.uid
        devices = loadedDevices
        preferences.observe(loadedDevices)
        updatePriorityRows()
        if let current = currentDevice {
            // Suppress only the slider echo, never hot-plug or default-route events.
            if current.uid != previousUID || Date() >= suppressVolumeEchoUntil {
                currentVolume = Double(current.inputVolume ?? 0)
            }
            volumeIsEnabled = current.supportsInputVolume
        } else {
            currentVolume = 0
            volumeIsEnabled = false
        }
        if monitoredDeviceID != currentDevice?.id {
            volumeWriteWorkItem?.cancel()
            monitoredDeviceID = currentDevice?.id
            audioManager.monitorVolume(for: monitoredDeviceID)
        }
    }

    private func updatePriorityRows() {
        priorityRows = preferences.rows(for: devices)
        menuRows = priorityRows.filter(\.isShownInMenu)
        menuRefreshWorkItem?.cancel()
        menuRefreshWorkItem = nil
        guard let delay = preferences.nextMenuVisibilityRefreshDelay else { return }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in self?.updatePriorityRows() }
        }
        menuRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, delay), execute: workItem)
    }

    private func enforcePriority(shouldNotify: Bool) {
        guard let target = preferences.preferredDevice(in: devices) else {
            cancelRestoration()
            return
        }
        if target.isDefault {
            confirmRestoration(to: target)
            return
        }
        guard restoration?.uid != target.uid else { return }
        cancelRestoration()
        restoration = Restoration(
            uid: target.uid,
            stackBelowNativeHUD: currentDevice?.mayTriggerNativeRouteHUD ?? false,
            shouldNotify: shouldNotify
        )
        attemptRestoration()
    }

    private func attemptRestoration() {
        guard let pending = restoration,
            let target = preferences.preferredDevice(in: devices), target.uid == pending.uid
        else {
            cancelRestoration()
            return
        }
        restoration?.attempts += 1
        do {
            try audioManager.setDefaultInputDevice(target.id)
            applyLoadedDevices(try audioManager.loadInputDevices())
            if let preferred = preferences.preferredDevice(in: devices), preferred.isDefault {
                confirmRestoration(to: preferred)
                return
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // Some routes appear before they are ready. Retry briefly without depending on
        // a further Core Audio event, and always re-resolve the highest available UID.
        let delays: [TimeInterval] = [0.15, 0.4, 1]
        let attempt = restoration?.attempts ?? 1
        guard attempt <= delays.count else {
            if errorMessage == nil {
                errorMessage = String(
                    format: NSLocalizedString("Unable to activate %@.", comment: "Input route verification failure"),
                    target.displayName
                )
            }
            cancelRestoration()
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.restoration?.token == pending.token else { return }
                self.restorationWorkItem = nil
                self.refresh(shouldNotify: pending.shouldNotify)
                if self.restoration?.token == pending.token { self.attemptRestoration() }
            }
        }
        restorationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delays[attempt - 1], execute: workItem)
    }

    private func confirmRestoration(to device: InputDevice) {
        let pending = restoration
        cancelRestoration()
        guard pending?.uid == device.uid else { return }
        errorMessage = nil
        guard pending?.shouldNotify == true else { return }
        showRestorationHUD(for: device, stackBelowNativeHUD: pending?.stackBelowNativeHUD ?? false)
    }

    private func cancelRestoration() {
        restorationWorkItem?.cancel()
        restorationWorkItem = nil
        restoration = nil
    }

    private func showRestorationHUD(for device: InputDevice, stackBelowNativeHUD: Bool) {
        hud.show(
            deviceName: priorityRows.first(where: { $0.id == device.uid })?.name ?? device.displayName,
            detail: NSLocalizedString("Input Priority On", comment: "HUD automatic input status"),
            stackBelowNativeHUD: stackBelowNativeHUD,
            unlock: { [weak self] in self?.setAutomaticInputEnabled(false) },
            lock: { [weak self] in
                guard let self else { return }
                self.setAutomaticInputEnabled(true)
                if let preferred = self.preferences.preferredDevice(in: self.devices), preferred.isDefault {
                    self.showRestorationHUD(for: preferred, stackBelowNativeHUD: false)
                } else {
                    self.hud.dismissForMenuOpening()
                }
            }
        )
    }

    #if DEBUG
        private func installDebugHUDTrigger() {
            debugHUDObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("MicFirst.ShowPreferredInputHUD"), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let device = self.currentDevice else { return }
                    self.showRestorationHUD(for: device, stackBelowNativeHUD: false)
                }
            }
        }
    #endif
}
