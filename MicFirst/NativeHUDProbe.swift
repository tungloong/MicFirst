import CoreGraphics
import Foundation

enum NativeHUDPresence: String, Codable {
    case visible, absent, unknown
}

struct NativeHUDWindowSample: Codable, Equatable {
    let id: CGWindowID
    let ownerPID: pid_t
    let owner: String
    let ownerBundleID: String?
    let rawCGFrame: CGRect
    let appKitFrame: CGRect
    let level: Int
    let alpha: Double
    let isOnScreen: Bool
    let isOnTargetScreen: Bool?
    let titleAvailability: String
    let matchesLegacyFilter: Bool
    let legacyAssumedCapsuleFrame: CGRect?
}

struct NativeHUDProbeResult: Codable, Equatable {
    let presence: NativeHUDPresence
    let reason: String
    let windows: [NativeHUDWindowSample]
}

/// Reconstruct the May 20 query as diagnostic evidence, not a placement policy.
/// Neither a legacy match nor an empty query proves the native HUD's visibility.
enum NativeHUDProbe {
    static let ownerBundles = [
        "com.apple.controlcenter", "com.apple.MenuBarAgent", "com.apple.OSDUIHelper", "com.apple.systemuiserver"
    ]

    static func inspect(
        windowInfos: [[String: Any]]?, ownerBundlesByPID: [pid_t: String], primaryScreenMaxY: CGFloat,
        targetScreen: CGRect?
    ) -> NativeHUDProbeResult {
        guard let windowInfos else {
            return NativeHUDProbeResult(presence: .unknown, reason: "window-enumeration-unavailable", windows: [])
        }
        let samples: [NativeHUDWindowSample] = windowInfos.compactMap { info in
            guard let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let owner = info[kCGWindowOwnerName as String] as? String,
                  ownerBundlesByPID[pid] != nil || owner == "Window Server",
                  let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let raw = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  [raw.minX, raw.minY, raw.width, raw.height].allSatisfy(\.isFinite),
                  let level = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
                  alpha.isFinite else { return nil }
            let onScreen = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
            let title = info[kCGWindowName as String] as? String
            let frame = CGRect(x: raw.minX, y: primaryScreenMaxY - raw.maxY, width: raw.width, height: raw.height)
            let onTargetScreen = targetScreen.map { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) }
            let legacyMatch = onScreen && owner == "Control Center" && (title ?? "").isEmpty
                && level >= 2000 && alpha > 0.02
                && (260...560).contains(frame.width) && (70...190).contains(frame.height)
                && onTargetScreen == true
            let assumedCapsule: CGRect? = legacyMatch ? CGRect(
                x: frame.midX - 235 / 2, y: frame.midY - 52 / 2, width: 235, height: 52
            ) : nil
            return NativeHUDWindowSample(
                id: id, ownerPID: pid, owner: owner, ownerBundleID: ownerBundlesByPID[pid],
                rawCGFrame: raw, appKitFrame: frame, level: level, alpha: alpha, isOnScreen: onScreen,
                isOnTargetScreen: onTargetScreen,
                titleAvailability: title == nil ? "missing" : (title!.isEmpty ? "empty" : "nonempty"),
                matchesLegacyFilter: legacyMatch, legacyAssumedCapsuleFrame: assumedCapsule
            )
        }.sorted { $0.id < $1.id }
        return NativeHUDProbeResult(
            presence: .unknown,
            reason: samples.contains(where: \.matchesLegacyFilter)
                ? "legacy-candidate-needs-visual-verification" : "no-legacy-match-not-proof-of-absence",
            windows: samples
        )
    }
}

struct HUDDiagnosticPresentation: Codable, Equatable {
    let isVisible: Bool
    let hostFrame: CGRect?
    let capsuleFrame: CGRect?
    let alpha: CGFloat
}
