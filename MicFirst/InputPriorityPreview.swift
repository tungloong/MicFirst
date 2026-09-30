#if DEBUG
    import CoreAudio
    import Foundation
    import SwiftUI

    /// A UI review window with isolated preferences and no writes to the Mac's audio route.
    @MainActor
    enum InputPriorityPreview {
        private static var window: NSWindow?

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

        private static func render<V: View>(_ view: V, width: CGFloat, minimumHeight: CGFloat, to url: URL) throws {
            let host = NSHostingView(rootView: AnyView(view.environment(\.colorScheme, .light)))
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
            let view = NSHostingView(rootView: SoundMenuView(viewModel: viewModel).background(.regularMaterial))
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
        }

        static func makeViewModel() -> AudioInputViewModel {
            let defaults = UserDefaults(suiteName: "com.tenglong.MicFirst.PriorityPreview")!
            defaults.removePersistentDomain(forName: "com.tenglong.MicFirst.PriorityPreview")
            var dateOffset: TimeInterval = ProcessInfo.processInfo.arguments.contains("--expired-offline") ? -301 : 0
            let store = InputPriorityStore(defaults: defaults, now: { Date().addingTimeInterval(dateOffset) })
            let manager = PreviewAudioManager()
            if ProcessInfo.processInfo.arguments.contains("--many-inputs") {
                manager.addExtraDevices()
            }
            store.observe(manager.allDevices)
            if let online = try? manager.loadInputDevices() { store.observe(online) }
            dateOffset = 0
            return AudioInputViewModel(audioManager: manager, preferences: store)
        }
    }

    private final class PreviewAudioManager: InputAudioManaging {
        private var currentID: AudioDeviceID = 1
        private var volume: Float = 0.8
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
            allDevices.filter { $0.id != 2 }.map {
                Self.makeDevice(
                    $0.id, name: $0.name, transport: $0.transportType, current: $0.id == currentID, volume: volume)
            }
        }
        func defaultInputDeviceID() throws -> AudioDeviceID { currentID }
        func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws { currentID = deviceID }
        func setInputVolume(_ volume: Float, for deviceID: AudioDeviceID) throws { self.volume = volume }
        func startMonitoring(_ onChange: @escaping () -> Void) {}
        func stopMonitoring() {}
        func monitorVolume(for deviceID: AudioDeviceID?) {}

        private static func makeDevice(
            _ id: AudioDeviceID, name: String, transport: UInt32, current: Bool = false, volume: Float = 0.8
        ) -> InputDevice {
            InputDevice(
                id: id, uid: "preview-\(id)", name: name, manufacturer: "", modelUID: "", transportType: transport,
                inputChannels: 1, isDefault: current, supportsInputVolume: true, inputVolume: volume)
        }
    }
#endif
