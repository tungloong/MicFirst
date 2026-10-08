import AppKit
import Combine
import SwiftUI
import Symbols

/// MenuBarExtra owns the status item and menu. Its label becomes an NSImage,
/// so a small public AppKit bridge attaches live symbol views to our own button.
@MainActor
final class MenuBarSymbolRenderer: ObservableObject {
    // Approved in the live menu bar on 2026-10-08. Share timing across effects.
    private static let animationSpeed = 0.8

    @Published private(set) var isInstalled = false
    private weak var button: NSStatusBarButton?
    private let canvas = StatusSymbolCanvas()
    private let symbolView = StatusSymbolImageView()
    private let waveViews = (0..<3).map { _ in StatusSymbolImageView() }
    private var waveAssetNames: [String?] = Array(repeating: nil, count: 3)
    private var subscription: AnyCancellable?
    private var updateObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?
    private var state: MenuBarMicrophoneState?
    private var initialAttach: DispatchWorkItem?
    private var centerConstraints: [NSLayoutConstraint] = []
    #if DEBUG
    private var reviewReduceMotion = false
    #endif

    static let placeholder = NSImage(size: NSSize(width: 18, height: 20), flipped: false) { _ in true }

    func start(viewModel: AudioInputViewModel) {
        guard #available(macOS 26.0, *), subscription == nil else { return }
        subscription = viewModel.$currentVolume.combineLatest(viewModel.$automaticInputIsEnabled)
            .map { MenuBarMicrophoneState(volume: $0, automaticInputIsEnabled: $1) }
            .removeDuplicates()
            .sink { [weak self] in self?.update($0, animated: true) }
        updateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didUpdateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.attachIfReady() }
        }
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let state = self.state else { return }
                self.update(state, animated: false)
            }
        }
        attachWhenReady()
    }

    func stop() {
        initialAttach?.cancel()
        initialAttach = nil
        subscription = nil
        if let updateObserver { NotificationCenter.default.removeObserver(updateObserver) }
        updateObserver = nil
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
        accessibilityObserver = nil
        if #available(macOS 26.0, *) {
            for view in [symbolView] + waveViews {
                view.removeAllSymbolEffects(animated: false)
            }
            canvas.removeFromSuperview()
        }
        button = nil
        isInstalled = false
        state = nil
        waveAssetNames = Array(repeating: nil, count: 3)
    }

    private func attachWhenReady(remaining: Int = 30) {
        attachIfReady()
        guard !isInstalled, remaining > 0 else { return }
        let work = DispatchWorkItem { [weak self] in self?.attachWhenReady(remaining: remaining - 1) }
        initialAttach = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    private func attachIfReady() {
        guard #available(macOS 26.0, *) else { return }
        if let button, canvas.superview === button,
           button.window?.isVisible == true, button.window?.frame.height ?? 0 > 0 { return }
        func statusButton(in view: NSView) -> NSStatusBarButton? {
            if let button = view as? NSStatusBarButton { return button }
            return view.subviews.lazy.compactMap { statusButton(in: $0) }.first
        }
        guard let candidate = NSApp.windows.filter({ $0.isVisible && $0.frame.height > 0 })
            .compactMap({ $0.contentView }).compactMap({ statusButton(in: $0) }).first else {
            if isInstalled { isInstalled = false }
            return
        }
        button = candidate
        candidate.wantsLayer = true
        canvas.removeFromSuperview()
        canvas.frame = candidate.bounds
        canvas.autoresizingMask = [.width, .height]
        canvas.wantsLayer = true
        canvas.setAccessibilityElement(false)
        candidate.addSubview(canvas)
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular, scale: .small)
            .applying(.preferringMonochrome())
            .applying(NSImage.SymbolConfiguration(variableValueMode: .color))
        centerConstraints.removeAll()
        for view in [symbolView] + waveViews {
            view.removeFromSuperview()
            view.setAccessibilityElement(false)
            view.wantsLayer = true
            view.symbolConfiguration = configuration
            view.imageScaling = .scaleNone
            view.contentTintColor = .labelColor
            view.translatesAutoresizingMaskIntoConstraints = false
            canvas.addSubview(view)
            let center = view.centerXAnchor.constraint(equalTo: canvas.centerXAnchor)
            centerConstraints.append(center)
            NSLayoutConstraint.activate([
                center,
                view.centerYAnchor.constraint(equalTo: canvas.centerYAnchor),
                view.widthAnchor.constraint(equalToConstant: 24),
                view.heightAnchor.constraint(equalToConstant: 22)
            ])
        }
        if let state { update(state, animated: false) }
        isInstalled = true
    }

    #if DEBUG
    func setReduceMotionForReview(_ enabled: Bool) {
        reviewReduceMotion = enabled
        if #available(macOS 26.0, *), let state { update(state, animated: false) }
    }
    #endif

    @available(macOS 26.0, *)
    private func update(_ next: MenuBarMicrophoneState, animated: Bool) {
        let previous = state
        let shouldAnimate = animated && previous != nil && !reduceMotion
        state = next
        centerConstraints.forEach { $0.constant = CGFloat(next.horizontalOffset) }
        canvas.layoutSubtreeIfNeeded()
        // A zero variable-color base keeps every inactive wave at Apple's native
        // reduced opacity. Separate native wave views draw only changed waves,
        // without replaying the microphone or the waves that are already active.
        if previous?.symbolName != next.symbolName || !shouldAnimate {
            if let image = Self.image(for: next, variableValue: 0) {
                if shouldAnimate {
                    symbolView.setSymbolImage(image, contentTransition: .replace.magic(fallback: .replace), options: .speed(Self.animationSpeed))
                } else {
                    symbolView.removeAllSymbolEffects(animated: false)
                    symbolView.image = image
                }
            }
        }
        let count = next.activeWaveCount
        for (index, view) in waveViews.enumerated() {
            let visible = index < count
            let wasVisible = index < (previous?.activeWaveCount ?? 0)
            let locked = next.isAutomaticVolume
            let name = "MenuBarMicrophoneDrawWave\(index + 1)\(locked ? "Locked" : "")"
            let imageChanged = waveAssetNames[index] != name
            if imageChanged {
                view.removeAllSymbolEffects(animated: false)
                view.image = NSImage(symbolName: name, bundle: .main, variableValue: 1)
                waveAssetNames[index] = name
                if shouldAnimate && !wasVisible {
                    view.addSymbolEffect(.drawOff.wholeSymbol, animated: false)
                }
            }
            guard visible != wasVisible || imageChanged || !shouldAnimate else { continue }
            if visible {
                if shouldAnimate && !wasVisible {
                    // Preserve the hidden Draw Off state until Draw On replaces
                    // it. Clearing effects here would reveal the final path
                    // immediately and leave Draw On with nothing to animate.
                    view.addSymbolEffect(.drawOn.wholeSymbol, options: .speed(Self.animationSpeed))
                } else {
                    view.removeAllSymbolEffects(animated: false)
                }
            } else {
                // Keep visibility effects paired when their direction changes;
                // AppKit owns the native Draw effect's timing and starting path.
                if !shouldAnimate { view.removeAllSymbolEffects(animated: false) }
                view.addSymbolEffect(.drawOff.reversed.wholeSymbol, options: .speed(Self.animationSpeed),
                                     animated: shouldAnimate && wasVisible)
            }
        }
    }

    private var reduceMotion: Bool {
        #if DEBUG
        if reviewReduceMotion { return true }
        #endif
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func image(for state: MenuBarMicrophoneState, variableValue: Double? = nil) -> NSImage? {
        if state.usesSystemSymbol {
            return NSImage(systemSymbolName: state.symbolName, accessibilityDescription: nil)
        }
        return NSImage(symbolName: state.symbolName, bundle: .main, variableValue: variableValue ?? state.variableValue ?? 1)
    }

}

private extension MenuBarMicrophoneState {
    var activeWaveCount: Int {
        guard case .volume(let level, _) = self else { return 0 }
        switch level {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    var isAutomaticVolume: Bool {
        if case .volume(_, automatic: true) = self { return true }
        return false
    }
}

/// Let the original status button keep native tracking and accessibility.
private final class StatusSymbolImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class StatusSymbolCanvas: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
