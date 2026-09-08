import AppKit

/// The system owns MenuBarExtra. Development launch supplies its public-AX button
/// snapshot; no alternate popover, custom panel, or second status item is created.
@MainActor
final class StatusItemController: HUDAnchorProviding {
    private var snapshot: HUDSystemMenuAnchor?
    var anchorChanged: (() -> Void)?
    func update(_ anchors: [HUDSystemMenuAnchor]) {
        snapshot = anchors.first { $0.identifier == "micfirst-status-item" && $0.isValid }
        anchorChanged?()
    }
    func hudAnchor() -> HUDAnchor? {
        guard let snapshot, let screen = NSScreen.screens.first(where: { $0.frame == snapshot.screenFrame }) else { return nil }
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
