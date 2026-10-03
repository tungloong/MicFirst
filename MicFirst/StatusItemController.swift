import AppKit

/// SwiftUI owns MenuBarExtra. The HUD reads this process's status-bar window for
/// MicFirst's own icon when it is presented and when the display configuration changes.
@MainActor
final class StatusItemController: HUDAnchorProviding {
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

    func hudAnchor() -> HUDAnchor? {
        let windows = NSApp.windows.map { MenuBarWindowRecord(frame: $0.frame, className: $0.className) }
        let screens = NSScreen.screens.map { MenuBarScreenRecord(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        guard let button = OwnMenuBarButton.frame(among: windows, on: screens, near: NSEvent.mouseLocation),
              let screen = NSScreen.screens.first(where: {
                  $0.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: button.midX, y: button.midY))
              }) else { return nil }
        // The menu-bar boundary comes from the display work area. This is a
        // measured menu region, not a claim to have read a foreign NSWindow.
        let bottom = screen.visibleFrame.maxY < screen.frame.maxY ? screen.visibleFrame.maxY : button.minY
        let menuRegion = CGRect(x: button.minX, y: bottom, width: button.width, height: screen.frame.maxY - bottom)
        return HUDAnchor(buttonFrame: button, statusWindowFrame: menuRegion,
                         screenFrame: screen.frame, visibleScreenFrame: screen.visibleFrame,
                         backingScale: screen.backingScaleFactor)
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
}
