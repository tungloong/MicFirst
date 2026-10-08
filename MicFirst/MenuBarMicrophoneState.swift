import Foundation

/// These levels match SF Symbols' three Variable Color thresholds. An absent
/// reading is a separate state; only a confirmed zero represents mute.
enum MenuBarInputVolumeLevel: CaseIterable, Equatable {
    case low, medium, high

    var variableValue: Double {
        switch self {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 1
        }
    }
}

enum MenuBarMicrophoneState: Equatable {
    case unknown(automatic: Bool)
    case muted
    case volume(MenuBarInputVolumeLevel, automatic: Bool)

    init(volume: Double?, automaticInputIsEnabled: Bool) {
        guard let volume, volume.isFinite else {
            self = .unknown(automatic: automaticInputIsEnabled)
            return
        }
        let normalizedVolume = min(max(volume, 0), 1)
        guard normalizedVolume > 0 else {
            self = .muted
            return
        }
        let level: MenuBarInputVolumeLevel = normalizedVolume < 0.34 ? .low : normalizedVolume < 0.68 ? .medium : .high
        self = .volume(level, automatic: automaticInputIsEnabled)
    }

    /// Optical correction approved for the six wave-bearing states.
    var horizontalOffset: Double {
        if case .volume = self { return 2 }
        return 0
    }

    var symbolName: String {
        switch self {
        case .unknown(automatic: false):
            // The original names are available on macOS 13; newer SF Symbols
            // calls the same native shapes microphone.fill / microphone.slash.fill.
            return "mic.fill"
        case .unknown(automatic: true): return "MenuBarMicrophoneUnknownLocked"
        case .muted: return "mic.slash.fill"
        case .volume(_, automatic: false): return "MenuBarMicrophoneVolume"
        case .volume(_, automatic: true): return "MenuBarMicrophoneVolumeLocked"
        }
    }

    var usesSystemSymbol: Bool {
        switch self {
        case .unknown(automatic: false), .muted: return true
        default: return false
        }
    }

    var variableValue: Double? {
        if case .volume(let level, _) = self { return level.variableValue }
        return nil
    }
}
