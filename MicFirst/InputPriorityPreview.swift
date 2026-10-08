#if DEBUG
    import CoreAudio
    import Foundation
    import SwiftUI

    /// A UI review window with isolated preferences and no writes to the Mac's audio route.
    @MainActor
    enum InputPriorityPreview {
        private static var window: NSWindow?
        private static var symbolBoardWindow: NSWindow?
        private static var symbolReviewManager: PreviewAudioManager?
        private static var symbolCaptureGeneration = 0
        static var setReviewReduceMotion: ((Bool) -> Void)?
        private(set) static var reviewReduceMotion = false

        static func simulateReduceMotion(_ enabled: Bool) {
            reviewReduceMotion = enabled
            setReviewReduceMotion?(enabled)
        }

        static let symbolReviewCases: [(id: String, title: String, state: MenuBarMicrophoneState)] = [
            ("unknown-off", "Unknown · Off", .unknown(automatic: false)),
            ("unknown-on", "Unknown · On", .unknown(automatic: true)),
            ("zero", "0 · Shared", .muted),
            ("low-off", "Low · Off", .volume(.low, automatic: false)),
            ("medium-off", "Mid · Off", .volume(.medium, automatic: false)),
            ("high-off", "High · Off", .volume(.high, automatic: false)),
            ("low-on", "Low · On", .volume(.low, automatic: true)),
            ("medium-on", "Mid · On", .volume(.medium, automatic: true)),
            ("high-on", "High · On", .volume(.high, automatic: true))
        ]

        static func exportMenuSymbols(to directory: URL) throws {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for scheme in [ColorScheme.light, .dark] {
                let appearance = scheme == .light ? "light" : "dark"
                try render(
                    MenuBarSymbolReviewBoard(scheme: scheme), width: 600, minimumHeight: 444,
                    scheme: scheme, to: directory.appendingPathComponent("nine-states-\(appearance).png"))
                for review in symbolReviewCases {
                    try render(
                        MicFirstMenuSymbol(state: review.state)
                            .foregroundStyle(.primary)
                            .background(Color(nsColor: .windowBackgroundColor)),
                        width: 21, minimumHeight: 18, scheme: scheme,
                        to: directory.appendingPathComponent("\(review.id)-\(appearance).png"))
                }
            }
        }

        static func exportScreenshots(viewModel: AudioInputViewModel, to directory: URL) throws {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            viewModel.menuDidOpen()
            try render(
                SoundMenuView(viewModel: viewModel).background(.regularMaterial),
                width: 308, minimumHeight: 320, to: directory.appendingPathComponent("menu.png"))
            viewModel.settingsDidOpen()
            try render(
                InputPrioritySettingsView(viewModel: viewModel)
                    .frame(width: 660, alignment: .top)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(24)
                    .background(Color(nsColor: .windowBackgroundColor)),
                width: 708, minimumHeight: 560, to: directory.appendingPathComponent("settings.png"))
            if let hud = micFirstHUDReviewImage() {
                try writePNG(hud, to: directory.appendingPathComponent("hud.png"))
            }
        }

        private static func render<V: View>(
            _ view: V, width: CGFloat, minimumHeight: CGFloat, scheme: ColorScheme = .light, to url: URL
        ) throws {
            let host = NSHostingView(rootView: AnyView(view.environment(\.colorScheme, scheme)))
            host.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
            host.frame = NSRect(x: 0, y: 0, width: width, height: minimumHeight)
            let fitted = host.fittingSize
            host.frame.size = NSSize(width: width, height: max(fitted.height, minimumHeight))
            let window = NSWindow(
                contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .windowBackgroundColor
            window.contentView = host
            window.setFrameOrigin(NSPoint(x: 40, y: 80))
            window.orderFrontRegardless()
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            let settled = host.fittingSize
            if settled.height > host.frame.height {
                host.frame.size.height = settled.height
                window.setContentSize(host.frame.size)
            }
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                throw CocoaError(.coderInvalidValue)
            }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                throw CocoaError(.coderInvalidValue)
            }
            try data.write(to: url)
            window.orderOut(nil)
        }

        private static func writePNG(_ image: NSImage, to url: URL) throws {
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .png, properties: [:]) else {
                throw CocoaError(.coderInvalidValue)
            }
            try data.write(to: url)
        }

        static func showWindow(viewModel: AudioInputViewModel) {
            if ProcessInfo.processInfo.arguments.contains("--hud-preview") {
                viewModel.showHUDPreview()
                return
            }
            let view = NSHostingView(rootView: VStack(spacing: 0) {
                if ProcessInfo.processInfo.arguments.contains("--menu-symbol-review") {
                    MenuBarSymbolReviewControls(viewModel: viewModel) { volume, automatic in
                        symbolReviewManager?.reviewVolume = volume
                        symbolReviewManager?.hasDevices = true
                        viewModel.setAutomaticInputEnabled(automatic)
                        viewModel.menuDidOpen()
                        recordMenuBarSymbol(viewModel: viewModel, captureTransition: true)
                    } noDevices: {
                        symbolReviewManager?.hasDevices = false
                        viewModel.menuDidOpen()
                        recordMenuBarSymbol(viewModel: viewModel, name: "no-devices", captureTransition: true)
                    }
                    Divider()
                }
                SoundMenuView(viewModel: viewModel)
            }.background(.regularMaterial))
            let preview = NSWindow(
                contentRect: NSRect(origin: .zero, size: view.fittingSize),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            preview.title = "Input Priority Preview"
            preview.contentView = view
            preview.isReleasedWhenClosed = false
            preview.center()
            preview.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window = preview
            if ProcessInfo.processInfo.arguments.contains("--menu-symbol-review") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    recordMenuBarSymbol(viewModel: viewModel)
                }
            }
        }

        private static func recordMenuBarSymbol(
            viewModel: AudioInputViewModel, name: String? = nil, captureTransition: Bool = false
        ) {
            // Manual visual review should not continuously render and write PNGs.
            guard ProcessInfo.processInfo.arguments.contains("--capture-menu-symbols") else { return }
            let state = viewModel.menuBarMicrophoneState
            let filename: String
            switch state {
            case .unknown(let automatic): filename = "unknown-\(automatic ? "on" : "off")"
            case .muted: filename = "zero"
            case .volume(let level, let automatic): filename = "\(level)-\(automatic ? "on" : "off")"
            }
            let target = (name ?? filename) + (reviewReduceMotion ? "-reduce-motion" : "")
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("MicFirstMenuSymbolReview", isDirectory: true)
                .appendingPathComponent("status-button", isDirectory: true)
            symbolCaptureGeneration += 1
            let generation = symbolCaptureGeneration
            let start = Date()
            // This captures only our own public NSStatusBarButton. In a sandbox,
            // temporaryDirectory belongs to the app's container, not the shell's TMPDIR.
            func snapshot(frame: Int?) {
                guard generation == symbolCaptureGeneration else { return }
                func button(in view: NSView) -> NSStatusBarButton? {
                    if let button = view as? NSStatusBarButton { return button }
                    return view.subviews.lazy.compactMap { button(in: $0) }.first
                }
                let buttons = NSApp.windows.compactMap({ $0.contentView }).compactMap({ button(in: $0) })
                func imageViews(in view: NSView) -> [NSImageView] {
                    (view as? NSImageView).map { [$0] } ?? view.subviews.flatMap { imageViews(in: $0) }
                }
                let activeButton = buttons.first(where: { !imageViews(in: $0).isEmpty })
                    ?? buttons.first
                guard let statusButton = activeButton,
                    let statusWindow = statusButton.window, statusWindow.isVisible, statusWindow.frame.height > 0,
                    let bitmap = statusButton.bitmapImageRepForCachingDisplay(in: statusButton.bounds) else {
                    fputs("menu symbol review: no public status button found; use Show Nine States for asset review\n", stderr)
                    return
                }
                statusButton.cacheDisplay(in: statusButton.bounds, to: bitmap)
                let destination = frame.map {
                    directory.appendingPathComponent("transition-to-\(target)", isDirectory: true)
                        .appendingPathComponent(String(format: "frame-%02d.png", $0))
                } ?? directory.appendingPathComponent("\(target).png")
                do {
                    try FileManager.default.createDirectory(
                        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    guard let data = bitmap.representation(using: .png, properties: [:]) else {
                        throw CocoaError(.coderInvalidValue)
                    }
                    try data.write(to: destination)
                    func layers(_ layer: CALayer?) -> String {
                        guard let layer else { return "none" }
                        return "\(type(of: layer)) animations=\(layer.animationKeys() ?? []) [\((layer.sublayers ?? []).map { layers($0) }.joined(separator: ";"))]"
                    }
                    let images = imageViews(in: statusButton).map {
                        "frame=\($0.frame) image=\(String(describing: $0.image))"
                    }.joined(separator: ";")
                    let details = "target=\(state) elapsed=\(Date().timeIntervalSince(start)) bounds=\(statusButton.bounds) window=\(statusWindow.frame) visible=\(statusWindow.isVisible) reviewWindow=\(String(describing: window?.frame)) screen=\(String(describing: statusWindow.screen?.frame)) image=\(String(describing: statusButton.image)) layerAnimations=\(layers(statusButton.layer)) subviews=\(statusButton.subviews.count) systemReduceMotion=\(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) simulatedReduceMotion=\(reviewReduceMotion) imageViews=\(images)\n"
                    try details.write(to: destination.deletingPathExtension().appendingPathExtension("txt"), atomically: true, encoding: .utf8)
                    if frame == nil { fputs("menu symbol review exported \(destination.path)\n", stderr) }
                } catch {
                    fputs("menu symbol review failed: \(error)\n", stderr)
                }
            }
            if captureTransition {
                // 31 samples over 600 ms. These are public-view snapshots, not a
                // video of the screen or proof of every compositor animation.
                for frame in 0...30 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(frame) * 0.02) {
                        snapshot(frame: frame)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { snapshot(frame: nil) }
        }

        static func showSymbolBoard() {
            if let symbolBoardWindow {
                symbolBoardWindow.makeKeyAndOrderFront(nil)
                return
            }
            let view = NSHostingView(rootView: HStack(spacing: 12) {
                MenuBarSymbolReviewBoard(scheme: .light)
                MenuBarSymbolReviewBoard(scheme: .dark)
            }.padding(12))
            let board = NSWindow(
                contentRect: NSRect(origin: .zero, size: view.fittingSize),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            board.title = "Compiled Menu Symbols · Light / Dark"
            board.contentView = view
            board.isReleasedWhenClosed = false
            board.center()
            board.makeKeyAndOrderFront(nil)
            symbolBoardWindow = board
        }

        static func makeViewModel() -> AudioInputViewModel {
            let defaults = UserDefaults(suiteName: "com.tenglong.MicFirst.PriorityPreview")!
            defaults.removePersistentDomain(forName: "com.tenglong.MicFirst.PriorityPreview")
            var dateOffset: TimeInterval = ProcessInfo.processInfo.arguments.contains("--expired-offline") ? -301 : 0
            let store = InputPriorityStore(defaults: defaults, now: { Date().addingTimeInterval(dateOffset) })
            let manager = PreviewAudioManager()
            if ProcessInfo.processInfo.arguments.contains("--menu-symbol-review") {
                symbolReviewManager = manager
            }
            if ProcessInfo.processInfo.arguments.contains("--many-inputs") {
                manager.addExtraDevices()
            }
            store.observe(manager.allDevices)
            if let online = try? manager.loadInputDevices() { store.observe(online) }
            dateOffset = 0
            return AudioInputViewModel(audioManager: manager, preferences: store)
        }
    }

    /// Buttons change the simulated device reading, so the real native status item
    /// receives exactly the same observable state as a Core Audio notification.
    private struct MenuBarSymbolReviewControls: View {
        @ObservedObject var viewModel: AudioInputViewModel
        let apply: (Float?, Bool) -> Void
        let noDevices: () -> Void
        @State private var simulateReduceMotion = false

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Bar Symbol Review").font(.headline)
                HStack(spacing: 18) {
                    MicFirstMenuSymbol(state: viewModel.menuBarMicrophoneState)
                    MicFirstMenuSymbol(state: viewModel.menuBarMicrophoneState)
                        .scaleEffect(4)
                        .frame(width: 84, height: 72)
                    Text("21 × 18 pt / 4×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Unknown · Off") { apply(nil, false) }
                    Button("Unknown · On") { apply(nil, true) }
                    Button("0 · Shared") { apply(0, true) }
                }
                ForEach(Array(zip(["Low", "Mid", "High"], [Float(0.25), 0.5, 0.8])), id: \.0) { name, volume in
                    HStack {
                        Button("\(name) · Off") { apply(volume, false) }
                        Button("\(name) · On") { apply(volume, true) }
                    }
                }
                Button("No Devices", action: noDevices)
                Button("Show Nine States") { InputPriorityPreview.showSymbolBoard() }
                Toggle("Simulate Reduce Motion", isOn: $simulateReduceMotion)
                    .onChange(of: simulateReduceMotion) { InputPriorityPreview.simulateReduceMotion($0) }
                Text("Reading: \(viewModel.currentVolume.map { String(format: "%.2f", $0) } ?? "unknown")")
                    .font(.caption.monospacedDigit())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(12)
        }
    }

    private struct MenuBarSymbolReviewBoard: View {
        let scheme: ColorScheme

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text("Compiled Menu Symbols · \(scheme == .light ? "Light" : "Dark")")
                    .font(.headline)
                Text("Compiled static symbols · 21 × 18 pt and 4×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(InputPriorityPreview.symbolReviewCases, id: \.id) { review in
                        VStack(spacing: 8) {
                            MicFirstMenuSymbol(state: review.state)
                                .scaleEffect(4)
                                .frame(width: 84, height: 72)
                            HStack(spacing: 8) {
                                MicFirstMenuSymbol(state: review.state)
                                Text(review.title).font(.caption)
                            }
                        }
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding(24)
            .frame(width: 600, height: 444, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)
        }
    }

    private final class PreviewAudioManager: InputAudioManaging {
        private var currentID: AudioDeviceID = 1
        var reviewVolume: Float? = 0.8
        var hasDevices = true
        private(set) var allDevices: [InputDevice] = [
            makeDevice(1, name: "DJI Mic Mini", transport: kAudioDeviceTransportTypeUSB, current: true),
            makeDevice(2, name: "DJI Mic Mini", transport: kAudioDeviceTransportTypeBluetooth),
            makeDevice(3, name: "AirPods", transport: kAudioDeviceTransportTypeBluetooth),
            makeDevice(4, name: "MacBook Air Microphone", transport: kAudioDeviceTransportTypeBuiltIn),
        ]

        func addExtraDevices() {
            allDevices += (5...16).map {
                Self.makeDevice(AudioDeviceID($0), name: "Studio Input \($0)", transport: kAudioDeviceTransportTypeUSB)
            }
        }

        func loadInputDevices() throws -> [InputDevice] {
            guard hasDevices else { return [] }
            return allDevices.filter { $0.id != 2 }.map {
                Self.makeDevice(
                    $0.id, name: $0.name, transport: $0.transportType, current: $0.id == currentID, volume: reviewVolume)
            }
        }
        func defaultInputDeviceID() throws -> AudioDeviceID { currentID }
        func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws { currentID = deviceID }
        func setInputVolume(_ volume: Float, for deviceID: AudioDeviceID) throws { reviewVolume = volume }
        func startMonitoring(_ onChange: @escaping () -> Void) {}
        func stopMonitoring() {}
        func monitorVolume(for deviceID: AudioDeviceID?) {}

        private static func makeDevice(
            _ id: AudioDeviceID, name: String, transport: UInt32, current: Bool = false, volume: Float? = 0.8
        ) -> InputDevice {
            InputDevice(
                id: id, uid: "preview-\(id)", name: name, manufacturer: "", modelUID: "", transportType: transport,
                inputChannels: 1, isDefault: current, supportsInputVolume: true, inputVolume: volume)
        }
    }
#endif
