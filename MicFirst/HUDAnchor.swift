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

struct MenuBarWindowRecord: Equatable {
    var frame: CGRect
    var className: String
}

struct MenuBarScreenRecord: Equatable {
    var frame: CGRect
    var visibleFrame: CGRect
}

/// MicFirst's own menu-bar button, read from this process's status-bar window.
enum OwnMenuBarButton {
    static func frame(
        among windows: [MenuBarWindowRecord],
        on screens: [MenuBarScreenRecord],
        near mouseLocation: CGPoint
    ) -> CGRect? {
        let candidates = windows.compactMap { window -> CGRect? in
            guard window.className.contains("NSStatusBarWindow") else { return nil }
            let frame = window.frame
            guard [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite),
                  frame.width > 8, frame.width < 160, frame.height > 8, frame.height <= 40,
                  screenFrame(containing: frame, screens: screens) != nil else { return nil }
            return frame
        }
        guard !candidates.isEmpty else { return nil }
        let mouseScreen = screens.first { $0.frame.contains(mouseLocation) }?.frame
        let pool = candidates.filter { screenFrame(containing: $0, screens: screens) == mouseScreen }
        let choices = pool.isEmpty ? candidates : pool
        return choices.min { abs($0.midX - mouseLocation.x) < abs($1.midX - mouseLocation.x) }
    }

    private static func screenFrame(containing button: CGRect, screens: [MenuBarScreenRecord]) -> CGRect? {
        screens.first {
            $0.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: button.midX, y: button.midY))
                && $0.frame.maxY - button.midY <= 100
        }?.frame
    }
}
