import AppKit

/// SwiftUI owns MenuBarExtra. The HUD reads this process's status-bar window for
/// MicFirst's own icon. A Debug launch may also store an Accessibility snapshot
/// as a fallback and for Sound/Control Center avoidance.
@MainActor
final class StatusItemController: HUDAnchorProviding {
    private var fallback: HUDSystemMenuAnchor?
    private var screenObserver: NSObjectProtocol?
    private var watch: DispatchWorkItem?
    var anchorChanged: (() -> Void)?

    func start() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.anchorChanged?() }
        }
        publishWhenReady()
    }

    func stop() {
        watch?.cancel()
        watch = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    @discardableResult
    func update(_ anchors: [HUDSystemMenuAnchor]) -> Bool {
        guard let candidate = anchors.first(where: { $0.identifier == "micfirst-status-item" && $0.isValid }),
              anchor(for: candidate) != nil else { return false }
        fallback = candidate
        anchorChanged?()
        return true
    }

    func hudAnchor() -> HUDAnchor? {
        if let live = liveAnchor() { return live }
        return fallback.flatMap { anchor(for: $0) }
    }

    private func liveAnchor() -> HUDAnchor? {
        let windows = NSApp.windows.map { MenuBarWindowRecord(frame: $0.frame, className: $0.className) }
        let screens = NSScreen.screens.map { MenuBarScreenRecord(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        guard let button = OwnMenuBarButton.frame(among: windows, on: screens, near: NSEvent.mouseLocation) else { return nil }
        return anchor(buttonFrame: button)
    }

    private func publishWhenReady(remaining: Int = 50) {
        if hudAnchor() != nil {
            anchorChanged?()
            return
        }
        guard remaining > 0 else { return }
        let work = DispatchWorkItem { [weak self] in self?.publishWhenReady(remaining: remaining - 1) }
        watch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func anchor(buttonFrame: CGRect) -> HUDAnchor? {
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
        }) else { return nil }
        let snapshot = HUDSystemMenuAnchor(
            identifier: "micfirst-status-item", buttonFrame: buttonFrame, screenFrame: screen.frame
        )
        return anchor(for: snapshot)
    }

    private func anchor(for snapshot: HUDSystemMenuAnchor) -> HUDAnchor? {
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
