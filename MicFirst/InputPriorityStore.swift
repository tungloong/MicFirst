import CoreAudio
import Foundation

struct RememberedInputDevice: Codable, Equatable, Identifiable {
    let uid: String
    var name: String
    var iconSystemName: String
    var transportType: UInt32
    var isHiddenFromMenu = false
    var offlineSince: Date?

    var id: String { uid }

    init(_ device: InputDevice) {
        uid = device.uid
        name = device.displayName
        iconSystemName = device.iconSystemName
        transportType = device.transportType
    }

    init(uid: String, name: String, iconSystemName: String = "mic", transportType: UInt32 = 0) {
        self.uid = uid
        self.name = name
        self.iconSystemName = iconSystemName
        self.transportType = transportType
    }

    private enum CodingKeys: String, CodingKey {
        case uid, name, iconSystemName, transportType, isHiddenFromMenu, offlineSince
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        uid = try values.decode(String.self, forKey: .uid)
        name = try values.decode(String.self, forKey: .name)
        iconSystemName = try values.decode(String.self, forKey: .iconSystemName)
        transportType = try values.decode(UInt32.self, forKey: .transportType)
        // Keep the existing v1 order and mode when upgrading from the first priority release.
        isHiddenFromMenu = try values.decodeIfPresent(Bool.self, forKey: .isHiddenFromMenu) ?? false
        offlineSince = try values.decodeIfPresent(Date.self, forKey: .offlineSince)
    }

    var connectionName: String? {
        switch transportType {
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
        default: return nil
        }
    }
}

struct InputPriorityRow: Identifiable, Equatable {
    let id: String
    let name: String
    let iconSystemName: String
    let isOnline: Bool
    let isCurrent: Bool
    let priority: Int
    let isHiddenFromMenu: Bool
    let isShownInMenu: Bool
}

/// Durable order and user intent. Availability and the current route always come from Core Audio.
final class InputPriorityStore {
    static let preferencesKey = "inputPriorityPreferences.v1"

    private struct Preferences: Codable {
        var isEnabled: Bool
        var devices: [RememberedInputDevice]
        var showsHUD: Bool? = nil
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let offlineMenuGracePeriod: TimeInterval
    private var preferences: Preferences
    private var lastOnlineUIDs: Set<String> = []

    var isEnabled: Bool { preferences.isEnabled }
    var showsHUD: Bool { preferences.showsHUD ?? true }
    var devices: [RememberedInputDevice] { preferences.devices }

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        offlineMenuGracePeriod: TimeInterval = 5 * 60
    ) {
        self.defaults = defaults
        self.now = now
        self.offlineMenuGracePeriod = offlineMenuGracePeriod
        if let data = defaults.data(forKey: Self.preferencesKey),
            let saved = try? JSONDecoder().decode(Preferences.self, from: data)
        {
            var seen = Set<String>()
            preferences = Preferences(
                isEnabled: saved.isEnabled,
                devices: saved.devices.filter { !$0.uid.isEmpty && seen.insert($0.uid).inserted },
                showsHUD: saved.showsHUD
            )
        } else {
            let legacyUID = defaults.string(forKey: "preferredInputDeviceUID").flatMap { $0.isEmpty ? nil : $0 }
            let legacyEnabled = defaults.object(forKey: "inputLockEnabled") as? Bool
            let hasPreviousPreferences = legacyEnabled != nil || defaults.object(forKey: Self.preferencesKey) != nil
            // Preserve an existing lock, including an offline target. An explicitly unlocked
            // installation stays manual; a fresh installation starts with its current input first.
            preferences = Preferences(
                isEnabled: legacyUID != nil ? (legacyEnabled ?? true) : !hasPreviousPreferences,
                devices: legacyUID.map {
                    [
                        RememberedInputDevice(
                            uid: $0,
                            name: defaults.string(forKey: "preferredInputDeviceName")
                                ?? NSLocalizedString("Unknown Input Device", comment: "Fallback input device name")
                        )
                    ]
                } ?? []
            )
        }
    }

    func setShowsHUD(_ value: Bool) {
        preferences.showsHUD = value
        save()
    }

    func setEnabled(_ isEnabled: Bool) {
        preferences.isEnabled = isEnabled
        save()
    }

    func observe(_ onlineDevices: [InputDevice]) {
        let previous = preferences.devices
        let onlineUIDs = Set(onlineDevices.map(\.uid))
        let observationDate = now()
        var discoveries = onlineDevices
        if preferences.devices.isEmpty, let current = discoveries.firstIndex(where: \.isDefault) {
            discoveries.insert(discoveries.remove(at: current), at: 0)
        }

        for device in discoveries where !device.uid.isEmpty {
            let remembered = RememberedInputDevice(device)
            if let index = preferences.devices.firstIndex(where: { $0.uid == device.uid }) {
                preferences.devices[index].name = remembered.name
                preferences.devices[index].iconSystemName = remembered.iconSystemName
                preferences.devices[index].transportType = remembered.transportType
                preferences.devices[index].offlineSince = nil
            } else {
                preferences.devices.append(remembered)
            }
        }

        for index in preferences.devices.indices {
            let uid = preferences.devices[index].uid
            if !onlineUIDs.contains(uid), preferences.devices[index].offlineSince == nil {
                // History that is already offline at launch starts collapsed. A live disconnect
                // gets five minutes; a saved disconnect keeps its deadline across restarts.
                preferences.devices[index].offlineSince = lastOnlineUIDs.contains(uid) ? observationDate : .distantPast
            }
        }
        lastOnlineUIDs = onlineUIDs

        if previous != preferences.devices || defaults.data(forKey: Self.preferencesKey) == nil {
            save()
        }
    }

    func preferredDevice(in onlineDevices: [InputDevice]) -> InputDevice? {
        guard isEnabled else { return nil }
        for remembered in devices where !remembered.isHiddenFromMenu {
            if let device = onlineDevices.first(where: { $0.uid == remembered.uid }) {
                return device
            }
        }
        return nil
    }

    func rows(for onlineDevices: [InputDevice]) -> [InputPriorityRow] {
        let date = now()
        return devices.enumerated().map { index, remembered in
            let online = onlineDevices.first { $0.uid == remembered.uid }
            let hasSameName = devices.contains {
                $0.uid != remembered.uid && $0.name.localizedCaseInsensitiveCompare(remembered.name) == .orderedSame
            }
            let name: String
            if hasSameName, let connection = remembered.connectionName,
                !remembered.name.localizedCaseInsensitiveContains(connection)
            {
                name = "\(remembered.name) · \(connection)"
            } else {
                name = remembered.name
            }
            return InputPriorityRow(
                id: remembered.uid,
                name: name,
                iconSystemName: remembered.iconSystemName,
                isOnline: online != nil,
                isCurrent: online?.isDefault == true,
                priority: index + 1,
                isHiddenFromMenu: remembered.isHiddenFromMenu,
                isShownInMenu: !remembered.isHiddenFromMenu
                    && (online != nil || remembered.offlineSince.map {
                        date < $0.addingTimeInterval(offlineMenuGracePeriod)
                    } == true)
            )
        }
    }

    var nextMenuVisibilityRefreshDelay: TimeInterval? {
        let date = now()
        return devices.compactMap { device -> TimeInterval? in
            guard !device.isHiddenFromMenu, let offlineSince = device.offlineSince else { return nil }
            let remaining = offlineSince.addingTimeInterval(offlineMenuGracePeriod).timeIntervalSince(date)
            return remaining > 0 ? remaining : nil
        }.min()
    }

    func setHiddenFromMenu(_ isHidden: Bool, uid: String) {
        guard let index = preferences.devices.firstIndex(where: { $0.uid == uid }) else { return }
        preferences.devices[index].isHiddenFromMenu = isHidden
        save()
    }

    /// Reorder only the displayed slots. Collapsed and hidden devices keep their full-list positions.
    func move(uid: String, beforeUID: String?, within visibleUIDs: [String]) {
        let visible = Set(visibleUIDs)
        let indices = devices.indices.filter { visible.contains(devices[$0].uid) }
        guard indices.map({ devices[$0].uid }) == visibleUIDs,
            let source = visibleUIDs.firstIndex(of: uid), beforeUID != uid,
            beforeUID == nil || visible.contains(beforeUID!)
        else { return }
        var reordered = indices.map { preferences.devices[$0] }
        let moving = reordered.remove(at: source)
        let destination = beforeUID.flatMap { anchor in reordered.firstIndex { $0.uid == anchor } } ?? reordered.count
        reordered.insert(moving, at: destination)
        for (index, device) in zip(indices, reordered) { preferences.devices[index] = device }
        save()
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard !offsets.isEmpty, offsets.allSatisfy({ devices.indices.contains($0) }),
            (0...devices.count).contains(destination)
        else { return }
        let moving = offsets.map { preferences.devices[$0] }
        let insertion = destination - offsets.filter { $0 < destination }.count
        for index in offsets.reversed() {
            preferences.devices.remove(at: index)
        }
        preferences.devices.insert(contentsOf: moving, at: insertion)
        save()
    }

    func removeOfflineDevice(uid: String, onlineDevices: [InputDevice]) {
        guard !onlineDevices.contains(where: { $0.uid == uid }) else { return }
        preferences.devices.removeAll { $0.uid == uid }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.preferencesKey)
    }
}
