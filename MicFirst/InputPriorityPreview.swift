#if DEBUG
    import CoreAudio
    import Foundation
    import SwiftUI

    /// A UI review window with isolated preferences and no writes to the Mac's audio route.
    @MainActor
    enum InputPriorityPreview {
        private static var window: NSWindow?

        static func showWindow(viewModel: AudioInputViewModel) {
            if ProcessInfo.processInfo.arguments.contains("--hud-preview") {
                viewModel.showHUDPreview()
                return
            }
            let view = NSHostingView(rootView: SoundMenuView(viewModel: viewModel).background(.regularMaterial))
            let preview = NSWindow(
                contentRect: NSRect(origin: .zero, size: view.fittingSize),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            preview.title = "Input Priority Preview"
            preview.contentView = view
            preview.isReleasedWhenClosed = false
            preview.center()
            preview.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window = preview
        }

        static func makeViewModel() -> AudioInputViewModel {
            let defaults = UserDefaults(suiteName: "com.tungloong.AudioInputLocker.PriorityPreview")!
            defaults.removePersistentDomain(forName: "com.tungloong.AudioInputLocker.PriorityPreview")
            var dateOffset: TimeInterval = ProcessInfo.processInfo.arguments.contains("--expired-offline") ? -301 : 0
            let store = InputPriorityStore(defaults: defaults, now: { Date().addingTimeInterval(dateOffset) })
            let manager = PreviewAudioManager()
            if ProcessInfo.processInfo.arguments.contains("--many-inputs") {
                manager.addExtraDevices()
            }
            store.observe(manager.allDevices)
            if let online = try? manager.loadInputDevices() { store.observe(online) }
            dateOffset = 0
            return AudioInputViewModel(audioManager: manager, preferences: store)
        }
    }

    private final class PreviewAudioManager: InputAudioManaging {
        private var currentID: AudioDeviceID = 1
        private var volume: Float = 0.8
        private(set) var allDevices: [InputDevice] = [
            makeDevice(1, name: "DJI Mic Mini", transport: kAudioDeviceTransportTypeUSB, current: true),
            makeDevice(2, name: "DJI Mic Mini", transport: kAudioDeviceTransportTypeBluetooth),
            makeDevice(3, name: "AirPods", transport: kAudioDeviceTransportTypeBluetooth),
            makeDevice(4, name: "MacBook Air Microphone", transport: kAudioDeviceTransportTypeBuiltIn),
        ]

        func addExtraDevices() {
            allDevices += (5...16).map {
                Self.makeDevice(AudioDeviceID($0), name: "Studio Input \($0)", transport: kAudioDeviceTransportTypeUSB)
            }
        }

        func loadInputDevices() throws -> [InputDevice] {
            allDevices.filter { $0.id != 2 }.map {
                Self.makeDevice(
                    $0.id, name: $0.name, transport: $0.transportType, current: $0.id == currentID, volume: volume)
            }
        }
        func defaultInputDeviceID() throws -> AudioDeviceID { currentID }
        func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws { currentID = deviceID }
        func setInputVolume(_ volume: Float, for deviceID: AudioDeviceID) throws { self.volume = volume }
        func startMonitoring(_ onChange: @escaping () -> Void) {}
        func stopMonitoring() {}
        func monitorVolume(for deviceID: AudioDeviceID?) {}

        private static func makeDevice(
            _ id: AudioDeviceID, name: String, transport: UInt32, current: Bool = false, volume: Float = 0.8
        ) -> InputDevice {
            InputDevice(
                id: id, uid: "preview-\(id)", name: name, manufacturer: "", modelUID: "", transportType: transport,
                inputChannels: 1, isDefault: current, supportsInputVolume: true, inputVolume: volume)
        }
    }
#endif
