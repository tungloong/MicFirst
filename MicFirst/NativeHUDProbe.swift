import AppKit

/// One of Apple's menu-bar banner hosts, read from public window metadata.
struct NativeHUDHost: Codable, Equatable {
    /// Volume, display brightness and keyboard brightness measured 290 pt wide on
    /// macOS 27.0; AirPods routing measured 235 pt. Metadata does not say which one
    /// is showing, so the widest stays clear.
    static let widestCapsuleWidth: CGFloat = 290

    let id: CGWindowID
    let ownerBundleID: String
    let level: Int
    /// AppKit screen points. The transparent host may extend past the screen edge.
    let frame: CGRect

    /// The capsule is centered in its host and narrower than it.
    var occupiedFrame: CGRect {
        frame.insetBy(dx: max(0, (frame.width - Self.widestCapsuleWidth) / 2), dy: 0)
    }
}

/// Apple draws its AirPods routing, volume and brightness banners inside a transparent
/// host window. Public window metadata lists that host without any permission, also
/// inside App Sandbox. No title, image or content is read.
///
/// macOS 27.0: MenuBarAgent, level 101, 352×157, top edge on the menu bar's bottom,
/// centered under the menu button that owns the banner. The Control Center signature
/// is the macOS 26 query from May 2026 and has not been re-verified.
enum NativeHUDProbe {
    static func hosts(
        in windowInfos: [[String: Any]],
        primaryScreenMaxY: CGFloat,
        bundleIdentifier: (pid_t) -> String?
    ) -> [NativeHUDHost] {
        let menuBarLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        return windowInfos.compactMap { info in
            guard (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true,
                  let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue, alpha > 0.02,
                  let level = (info[kCGWindowLayer as String] as? NSNumber)?.intValue, level > menuBarLevel,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let raw = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  [raw.minX, raw.minY].allSatisfy(\.isFinite),
                  (260...560).contains(raw.width), (70...190).contains(raw.height),
                  let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  // Resolve the owner last: only windows shaped like a banner host reach it.
                  let owner = bundleIdentifier(pid),
                  owner == "com.apple.MenuBarAgent" || (owner == "com.apple.controlcenter" && level >= 2000)
            else { return nil }
            return NativeHUDHost(
                id: id, ownerBundleID: owner, level: level,
                frame: CGRect(x: raw.minX, y: primaryScreenMaxY - raw.maxY, width: raw.width, height: raw.height)
            )
        }.sorted { $0.id < $1.id }
    }

    @MainActor
    static func visibleHosts() -> [NativeHUDHost] {
        guard let infos = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return [] }
        let primaryMaxY = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.maxY ?? 0
        return hosts(in: infos, primaryScreenMaxY: primaryMaxY) {
            NSRunningApplication(processIdentifier: $0)?.bundleIdentifier
        }
    }
}

struct HUDDiagnosticPresentation: Codable, Equatable {
    let isVisible: Bool
    let hostFrame: CGRect?
    let capsuleFrame: CGRect?
    let alpha: CGFloat
}
