import AppKit

/// The system owns MenuBarExtra. Development launch supplies its public-AX button
/// snapshot; no alternate popover, custom panel, or second status item is created.
@MainActor
final class StatusItemController: HUDAnchorProviding {
    private var snapshot: HUDSystemMenuAnchor?
    var anchorChanged: (() -> Void)?
    @discardableResult
    func update(_ anchors: [HUDSystemMenuAnchor]) -> Bool {
        guard let candidate = anchors.first(where: { $0.identifier == "micfirst-status-item" && $0.isValid }),
              hudAnchor(for: candidate) != nil else { return false }
        snapshot = candidate
        anchorChanged?()
        return true
    }
    func hudAnchor() -> HUDAnchor? {
        snapshot.flatMap { hudAnchor(for: $0) }
    }
    private func hudAnchor(for snapshot: HUDSystemMenuAnchor) -> HUDAnchor? {
        guard let screen = NSScreen.screens.first(where: { $0.frame == snapshot.screenFrame }) else { return nil }
        // The menu-bar boundary comes from the display work area. This is a
        // measured menu region, not a claim to have read a foreign NSWindow.
        let bottom = screen.visibleFrame.maxY < screen.frame.maxY ? screen.visibleFrame.maxY : snapshot.buttonFrame.minY
        let menuRegion = CGRect(x: snapshot.buttonFrame.minX, y: bottom,
                                width: snapshot.buttonFrame.width, height: screen.frame.maxY - bottom)
        return HUDAnchor(buttonFrame: snapshot.buttonFrame, statusWindowFrame: menuRegion,
                         screenFrame: screen.frame, visibleScreenFrame: screen.visibleFrame,
                         backingScale: screen.backingScaleFactor)
    }
}
