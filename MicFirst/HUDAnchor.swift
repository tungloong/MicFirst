import AppKit

@MainActor
protocol HUDAnchorProviding: AnyObject {
    func hudAnchor() -> HUDAnchor?
}

struct HUDAnchor: Equatable, Codable {
    let buttonFrame: CGRect
    let statusWindowFrame: CGRect
    let screenFrame: CGRect
    let visibleScreenFrame: CGRect
    let backingScale: CGFloat

    init?(buttonFrame: CGRect, statusWindowFrame: CGRect, screenFrame: CGRect,
          visibleScreenFrame: CGRect, backingScale: CGFloat) {
        let values = [buttonFrame, statusWindowFrame, screenFrame, visibleScreenFrame].flatMap {
            [$0.minX, $0.minY, $0.width, $0.height]
        } + [backingScale]
        guard values.allSatisfy(\.isFinite), buttonFrame.width > 0, buttonFrame.height > 0,
              screenFrame.width > 0, screenFrame.height > 0, backingScale > 0,
              statusWindowFrame.height > 0, statusWindowFrame.height <= 100,
              screenFrame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)),
              screenFrame.maxY - buttonFrame.midY <= statusWindowFrame.height else { return nil }
        // During initial attachment AppKit can briefly report the status window
        // below the menu bar. A reserved menu-bar area provides a measured gate.
        if visibleScreenFrame.maxY < screenFrame.maxY,
           buttonFrame.midY < visibleScreenFrame.maxY { return nil }
        self.buttonFrame = buttonFrame
        self.statusWindowFrame = statusWindowFrame
        self.screenFrame = screenFrame
        self.visibleScreenFrame = visibleScreenFrame
        self.backingScale = backingScale
    }

    func normalWindowFrame(windowSize: CGSize, capsuleSize: CGSize, gap: CGFloat) -> CGRect {
        // A status-item window can contain vertical overscan. Use the screen's
        // actual work-area boundary for a persistent menu bar. If the menu bar
        // is auto-hidden/revealed, use the measured thin status window instead.
        let menuBarBottom = visibleScreenFrame.maxY < screenFrame.maxY
            ? visibleScreenFrame.maxY : statusWindowFrame.minY
        let capsuleMaxYInWindow = (windowSize.height + capsuleSize.height) / 2
        return CGRect(
            x: buttonFrame.midX - windowSize.width / 2,
            y: menuBarBottom - gap - capsuleMaxYInWindow,
            width: windowSize.width, height: windowSize.height
        )
    }
}

/// System menu geometry predicts a reserved region, never native HUD visibility.
struct HUDSystemMenuAnchor: Codable, Equatable {
    let identifier: String
    let buttonFrame: CGRect
    let screenFrame: CGRect

    var isValid: Bool {
        [buttonFrame, screenFrame].allSatisfy { r in
            [r.minX, r.minY, r.width, r.height].allSatisfy(\.isFinite) && r.width > 0 && r.height > 0
        } && buttonFrame.height <= 100
            && screenFrame.contains(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            && screenFrame.maxY - buttonFrame.midY <= 100
    }

    static func preferred(in anchors: [Self], on screen: CGRect) -> Self? {
        let candidates = anchors.filter { $0.isValid && $0.screenFrame == screen }
        return candidates.first { $0.identifier == "com.apple.menuextra.sound" }
            ?? candidates.first { $0.identifier == "com.apple.menuextra.controlcenter" }
    }

    func capsuleFrame(on screen: CGRect, size: CGSize, inset: CGFloat) -> CGRect? {
        guard isValid, screenFrame == screen, screen.width >= size.width + 2 * inset else { return nil }
        let x = min(max(buttonFrame.midX - size.width / 2, screen.minX + inset), screen.maxX - inset - size.width)
        return CGRect(x: x, y: screen.maxY - size.height, width: size.width, height: size.height)
    }
}

#if DEBUG
/// One launch snapshot from the authorized development helper; no polling or expiry.
enum HUDMenuAnchorSnapshot {
    static func load(arguments: [String] = ProcessInfo.processInfo.arguments) -> [HUDSystemMenuAnchor] {
        guard let index = arguments.firstIndex(of: "--system-menu-anchors"), index + 1 < arguments.count else { return [] }
        let json = arguments[index + 1]
        guard json.utf8.count < 32_768,
              let anchors = try? JSONDecoder().decode([HUDSystemMenuAnchor].self, from: Data(json.utf8)),
              anchors.count <= 64 else { return [] }
        return anchors.filter(\.isValid)
    }
}
#endif
