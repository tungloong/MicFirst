import AppKit
import SwiftUI

@MainActor
protocol InputPriorityHUDPresenting: AnyObject {
    func show(deviceName: String, detail: String, unlock: @escaping () -> Void, lock: @escaping () -> Void)
    func dismissForMenuOpening()
}

@MainActor
final class PreferredInputHUD: InputPriorityHUDPresenting {
    static let shared = PreferredInputHUD()
    weak var anchorProvider: HUDAnchorProviding?
    private(set) var systemMenuAnchors: [HUDSystemMenuAnchor] = []

    func updateSystemMenuAnchors(_ anchors: [HUDSystemMenuAnchor]) {
        let valid = anchors.filter(\.isValid)
        guard valid != systemMenuAnchors else { return }
        systemMenuAnchors = valid
        refreshPlacement()
        #if DEBUG
        HUDDiagnostics.shared.record(event: "system-menu-anchors-updated")
        #endif
    }

    private var window: PreferredInputHUDWindow?
    private var hideWorkItem: DispatchWorkItem?
    private let placement = HUDPlacement()
    private var isPointerInside = false
    private var unlockAction: (() -> Void)?
    private var lockAction: (() -> Void)?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    private enum Layout {
        // Calibrated against the supplied 2x native AirPods banner reference.
        static let standaloneGapBelowMenuBar: CGFloat = 9
    }

    private enum Timing {
        static var initialVisibleDuration: TimeInterval {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--hud-preview") { return 60 }
            #endif
            return 4.2
        }
        static let hoverExitVisibleDuration: TimeInterval = 0.8
        static let unlockConfirmationDuration: TimeInterval = 1.4
    }

    func show(
        deviceName: String,
        detail: String,
        unlock: @escaping () -> Void,
        lock: @escaping () -> Void
    ) {
        hideWorkItem?.cancel()
        #if DEBUG
        HUDDiagnostics.shared.record(event: "hud-request")
        #endif
        isPointerInside = false
        unlockAction = unlock
        lockAction = lock

        showNow(deviceName: deviceName, detail: detail)
    }

    private func showNow(deviceName: String, detail: String) {
        guard let anchor = anchorProvider?.hudAnchor() else {
            #if DEBUG
            HUDDiagnostics.shared.record(event: "hud-skipped-anchor-unavailable")
            #endif
            hide()
            return
        }
        let baseFrame = anchor.normalWindowFrame(
            windowSize: PreferredInputHUDView.windowSize, capsuleSize: PreferredInputHUDView.capsuleSize,
            gap: Layout.standaloneGapBelowMenuBar
        )
        guard let initialFrame = placement.frame(
            anchoredAt: baseFrame, capsuleSize: PreferredInputHUDView.capsuleSize, on: anchor.screenFrame,
            nativeAnchor: HUDSystemMenuAnchor.preferred(in: systemMenuAnchors, on: anchor.screenFrame)
        ) else {
            hide()
            return
        }
        let window = window ?? makeWindow()
        let rootView = PreferredInputHUDView(
            deviceName: deviceName,
            detail: detail,
            hoverChanged: { [weak self] isHovered in
                self?.setPointerInside(isHovered)
            },
            close: { [weak self] in
                self?.hide()
            },
            unlock: { [weak self] in
                self?.unlock()
            },
            lock: { [weak self] in
                self?.lock()
            }
        )

        window.contentView = PreferredInputHUDContentView(rootView: rootView)
        window.appearance = nil
        window.setFrame(initialFrame, display: true)
        window.ignoresMouseEvents = true
        window.alphaValue = 0
        window.orderFrontRegardless()
        window.startGlassAppearance()
        self.window = window
        startMouseTracking()
        updateWindowMouseInteractivity()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }

        scheduleHide(after: Timing.initialVisibleDuration)
        #if DEBUG
        HUDDiagnostics.shared.record(event: "hud-shown")
        #endif
    }

    func dismissForMenuOpening() {
        hide()
    }

    func anchorDidChange() {
        refreshPlacement()
        #if DEBUG
        HUDDiagnostics.shared.record(event: "status-item-geometry-changed")
        #endif
    }

    private func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        stopMouseTracking()
        window?.stopGlassAppearance()
        #if DEBUG
        HUDDiagnostics.shared.record(event: "hud-hide-requested")
        #endif

        guard let window,
              window.isVisible else {
            return
        }

        window.ignoresMouseEvents = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak window] in
            guard let window,
                  window.alphaValue == 0 else {
                return
            }
            window.orderOut(nil)
        }
    }

    private func startMouseTracking() {
        stopMouseTracking()

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseDragged]
        ) { [weak self] event in
            self?.updateWindowMouseInteractivity()
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseDragged]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateWindowMouseInteractivity()
            }
        }
    }

    private func stopMouseTracking() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func updateWindowMouseInteractivity() {
        guard let window,
              window.isVisible else {
            return
        }

        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let acceptsMouse = PreferredInputHUDView.interactiveFrame.contains(point)
        window.ignoresMouseEvents = !acceptsMouse

        if acceptsMouse {
            if !isPointerInside {
                setPointerInside(true)
            }
        } else if isPointerInside {
            setPointerInside(false)
        }
    }

    private func unlock() {
        unlockAction?()
        hideWorkItem?.cancel()
        hideWorkItem = nil

        if !isPointerInside {
            scheduleHide(after: Timing.unlockConfirmationDuration)
        }
    }

    private func lock() {
        lockAction?()
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func setPointerInside(_ isInside: Bool) {
        isPointerInside = isInside
        if !isInside { refreshPlacement() }

        if isInside {
            hideWorkItem?.cancel()
            hideWorkItem = nil
        } else {
            scheduleHide(after: Timing.hoverExitVisibleDuration)
        }
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  !self.isPointerInside else {
                return
            }

            self.hide()
        }

        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func makeWindow() -> PreferredInputHUDWindow {
        PreferredInputHUDWindow(contentSize: PreferredInputHUDView.windowSize)
    }

    private func refreshPlacement() {
        guard let window, window.isVisible else { return }
        guard let anchor = anchorProvider?.hudAnchor() else { hide(); return }
        let baseFrame = anchor.normalWindowFrame(
            windowSize: PreferredInputHUDView.windowSize, capsuleSize: PreferredInputHUDView.capsuleSize,
            gap: Layout.standaloneGapBelowMenuBar
        )
        guard let frame = placement.frame(
            anchoredAt: baseFrame, capsuleSize: PreferredInputHUDView.capsuleSize, on: anchor.screenFrame,
            nativeAnchor: HUDSystemMenuAnchor.preferred(in: systemMenuAnchors, on: anchor.screenFrame)
        ) else {
            hide()
            return
        }
        if frame != window.frame {
            window.setFrame(frame, display: true)
            updateWindowMouseInteractivity()
        }
    }

    #if DEBUG
    func diagnosticPresentation() -> HUDDiagnosticPresentation {
        guard let window else {
            return HUDDiagnosticPresentation(isVisible: false, hostFrame: nil, capsuleFrame: nil, alpha: 0)
        }
        return HUDDiagnosticPresentation(
            isVisible: window.isVisible,
            hostFrame: window.frame,
            capsuleFrame: PreferredInputHUDView.visualCapsuleFrame.offsetBy(dx: window.frame.minX, dy: window.frame.minY),
            alpha: window.alphaValue
        )
    }
    #endif


}

// A nonactivating NSPanel cannot safely carry the process-local key appearance
// claim: BetterNotch's integration found that it disrupted other apps' focus.
// Keep a plain NSWindow that refuses actual key/main status instead.
private final class PreferredInputHUDWindow: NSWindow {
    private lazy var glassAppearance = HUDGlassAppearanceSession { [weak self] in
        self?.assertGlassAppearance()
    }

    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Keep the HUD above ordinary pop-up menus without acquiring focus.
        level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
            .transient
        ]
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        animationBehavior = .none
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func startGlassAppearance() {
        guard #available(macOS 26.0, *) else { return }
        glassAppearance.start()
    }

    func stopGlassAppearance() {
        glassAppearance.stop()
    }

    private func assertGlassAppearance() {
        guard isVisible else { return }
        // Public symbols used outside Apple's recommended calling pattern:
        // this remains a local appearance hint, never actual key/main focus.
        becomeKey()
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: self)
    }

    override func orderOut(_ sender: Any?) {
        stopGlassAppearance()
        super.orderOut(sender)
    }

    override func close() {
        stopGlassAppearance()
        super.close()
    }
}

/// Refresh only around presentation and app activation changes. No periodic timer.
@MainActor
final class HUDGlassAppearanceSession {
    private let assertAppearance: () -> Void
    private let notificationCenter: NotificationCenter
    private var isActive = false
    private var observers: [NSObjectProtocol] = []
    private var burst: Task<Void, Never>?

    init(
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        assertAppearance: @escaping () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.assertAppearance = assertAppearance
    }

    deinit {
        burst?.cancel()
        observers.forEach(notificationCenter.removeObserver)
    }

    func start() {
        if !isActive {
            isActive = true
            for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification] {
                observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
            }
        }
        // Also refresh when an already-visible HUD receives a new hosting view.
        refresh()
    }

    func stop() {
        isActive = false
        burst?.cancel()
        burst = nil
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    private func refresh() {
        guard isActive else { return }
        burst?.cancel()
        burst = Task { @MainActor [weak self] in
            // Let SwiftUI attach, then keep the original bounded 360 ms burst.
            for _ in 0..<18 {
                try? await Task.sleep(nanoseconds: 20_000_000)
                guard !Task.isCancelled else { return }
                self?.assertAppearance()
            }
        }
    }
}

private struct PreferredInputHUDView: View {
    static let windowSize = NSSize(width: 360, height: 136)
    static let capsuleSize = CGSize(width: 235, height: 52)
    static let hudIconSize: CGFloat = 34
    static let textColumnWidth: CGFloat = 128
    static let contentLeadingInset: CGFloat = 15
    static let contentTrailingInset: CGFloat = 13
    static let visualCapsuleFrame = NSRect(
        x: (windowSize.width - capsuleSize.width) / 2,
        y: (windowSize.height - capsuleSize.height) / 2,
        width: capsuleSize.width,
        height: capsuleSize.height
    )
    static let interactiveFrame = visualCapsuleFrame.insetBy(dx: -16, dy: -12)

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isHovered = false
    @State private var isUnlocked = false

    let deviceName: String
    let detail: String
    let hoverChanged: (Bool) -> Void
    let close: () -> Void
    let unlock: () -> Void
    let lock: () -> Void

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ZStack {
            capsule
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .background(Color.clear)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
            hoverChanged(hovering)
        }
    }

    @ViewBuilder
    private var capsule: some View {
        if #available(macOS 26.0, *) {
            ZStack {
                glassCapsule
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                hudContent
                    .frame(width: Self.capsuleSize.width, height: Self.capsuleSize.height)
            }
            .frame(width: Self.capsuleSize.width, height: Self.capsuleSize.height)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(alignment: .topLeading) {
                closeButton
            }
        } else {
            hudContent
                .frame(width: Self.capsuleSize.width, height: Self.capsuleSize.height)
                .background(fallbackBackground)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(isDark ? Color.white.opacity(0.15) : Color.white.opacity(0.78), lineWidth: isDark ? 0.6 : 0.7)
                }
                .shadow(color: Color.black.opacity(isDark ? 0.38 : 0.18), radius: isDark ? 13 : 16, x: 0, y: isDark ? 7.5 : 9)
                .shadow(color: Color.white.opacity(isDark ? 0.03 : 0.62), radius: 9, x: 0, y: -1.5)
                .overlay(alignment: .topLeading) {
                    closeButton
                }
        }
    }

    private var hudContent: some View {
        ZStack {
            textContent
                .frame(width: Self.textColumnWidth)

            HStack {
                PreferredInputHUDIcon(size: Self.hudIconSize)
                    .frame(width: Self.hudIconSize, height: Self.hudIconSize)

                Spacer(minLength: 0)

                lockButton
            }
            .padding(.leading, Self.contentLeadingInset)
            .padding(.trailing, Self.contentTrailingInset)
        }
    }

    private var textContent: some View {
        VStack(alignment: .center, spacing: 0) {
            MarqueeText(
                deviceName,
                font: .system(size: 13, weight: .semibold),
                foregroundColor: isDark ? Color.white : Color.black,
                height: 16,
                alignment: .center
            )
            .frame(maxWidth: .infinity, alignment: .center)

            Text(isUnlocked ? NSLocalizedString("Input Priority Off", comment: "HUD automatic input status") : detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.60))
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var lockButton: some View {
        Button(action: toggleLockState) {
            ZStack {
                Circle()
                    .fill(lockButtonBackground)

                Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(lockButtonForeground)
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(
            isUnlocked
                ? NSLocalizedString("Enable Input Priority", comment: "HUD automatic input button tooltip")
                : NSLocalizedString("Disable Input Priority", comment: "HUD automatic input button tooltip")
        )
        .accessibilityLabel(isUnlocked ? Text("Enable Input Priority") : Text("Disable Input Priority"))
    }

    @available(macOS 26.0, *)
    private var glassCapsule: some View {
        let shape = Capsule(style: .continuous)

        // Keep the material on its own shape, with HUD content as a sibling.
        // System glass supplies the refraction, edge highlights, and shadow.
        return GlassEffectContainer {
            shape
                .fill(.clear)
                .glassEffect(.clear.interactive(false), in: shape)
                .frame(width: Self.capsuleSize.width, height: Self.capsuleSize.height)
        }
    }

    private func toggleLockState() {
        if isUnlocked {
            lock()

            withAnimation(.easeInOut(duration: 0.18)) {
                isUnlocked = false
            }
        } else {
            unlock()

            withAnimation(.easeInOut(duration: 0.18)) {
                isUnlocked = true
            }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if isHovered {
            Button(action: close) {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))

                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .labelColor))
                }
                .frame(width: 18, height: 18)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: -4, y: -2)
            .transition(.opacity.combined(with: .scale(scale: 0.88)))
            .help(NSLocalizedString("Close", comment: "HUD close button tooltip"))
        }
    }

    private var lockButtonBackground: Color {
        if isUnlocked {
            return Color(nsColor: .labelColor).opacity(isDark ? 0.18 : 0.115)
        }

        return .accentColor
    }

    private var lockButtonForeground: Color {
        isUnlocked ? Color(nsColor: .secondaryLabelColor) : .white
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(isDark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.94, green: 0.94, blue: 0.94))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.055),
                                    Color.black.opacity(0.10)
                                ]
                                : [
                                    Color.white.opacity(0.84),
                                    Color.white.opacity(0.58),
                                    Color.white.opacity(0.44)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
}

private struct MarqueeText: View {
    let text: String
    let font: Font
    let foregroundColor: Color
    let height: CGFloat
    let alignment: Alignment

    @State private var measuredTextWidth: CGFloat = 0

    private let spacing: CGFloat = 22
    private let pixelsPerSecond: CGFloat = 24

    init(_ text: String, font: Font, foregroundColor: Color, height: CGFloat, alignment: Alignment = .leading) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.height = height
        self.alignment = alignment
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let shouldScroll = measuredTextWidth > availableWidth

            ZStack(alignment: shouldScroll ? .leading : alignment) {
                if shouldScroll {
                    TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                        let travelDistance = measuredTextWidth + spacing
                        let duration = max(3.2, Double(travelDistance / pixelsPerSecond))
                        let progress = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: duration) / duration

                        HStack(spacing: spacing) {
                            textView
                            textView
                        }
                        .offset(x: -travelDistance * progress)
                    }
                } else {
                    textView
                }
            }
            .frame(width: availableWidth, height: height, alignment: shouldScroll ? .leading : alignment)
            .clipped()
        }
        .frame(height: height)
        .background(measurementView)
    }

    private var textView: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var measurementView: some View {
        textView
            .hidden()
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: MarqueeTextWidthPreferenceKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(MarqueeTextWidthPreferenceKey.self) { width in
                measuredTextWidth = width
            }
    }
}

private struct MarqueeTextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PreferredInputHUDIcon: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = NSImage(named: "HUDMicrophone") ?? NSImage(named: "HUDMicrophone.png") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "music.microphone")
                    .font(.system(size: size * 0.70, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .shadow(color: .black.opacity(0.14), radius: 1.4, x: 0.35, y: 0.9)
    }
}

/// Approved readability recipe: an active Popover material at 0.80 behind the
/// untinted clear glass. Keep the foreground outside both background effects.
private final class PreferredInputHUDContentView: NSView {
    init(rootView: PreferredInputHUDView) {
        super.init(frame: NSRect(origin: .zero, size: PreferredInputHUDView.windowSize))
        if #available(macOS 26.0, *) {
            let backdrop = NSVisualEffectView(frame: PreferredInputHUDView.visualCapsuleFrame)
            backdrop.material = .popover
            backdrop.blendingMode = .behindWindow
            backdrop.state = .active
            backdrop.alphaValue = 0.80
            backdrop.wantsLayer = true
            backdrop.layer?.cornerRadius = PreferredInputHUDView.capsuleSize.height / 2
            backdrop.layer?.masksToBounds = true
            addSubview(backdrop)
        }
        addSubview(PreferredInputHUDHostingView(rootView: rootView))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard PreferredInputHUDView.interactiveFrame.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

private final class PreferredInputHUDHostingView: NSHostingView<PreferredInputHUDView> {
    required init(rootView: PreferredInputHUDView) {
        super.init(rootView: rootView)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard PreferredInputHUDView.interactiveFrame.contains(point) else {
            return nil
        }

        return super.hitTest(point)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configure()
    }

    private func configure() {
        frame = NSRect(origin: .zero, size: PreferredInputHUDView.windowSize)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}
