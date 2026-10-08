import SwiftUI

@main
struct MicFirstApp: App {
    @NSApplicationDelegateAdaptor(MicFirstAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            SoundMenuView(viewModel: appDelegate.viewModel)
        } label: {
            MicFirstMenuLabel(viewModel: appDelegate.viewModel, renderer: appDelegate.symbolRenderer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            InputPrioritySettingsView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
    }

}

@MainActor
final class MicFirstAppDelegate: NSObject, NSApplicationDelegate {
    let viewModel: AudioInputViewModel
    let statusController = StatusItemController()
    let symbolRenderer = MenuBarSymbolRenderer()
    #if DEBUG
    private var didShowPreview = false
    #endif

    override init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--priority-preview") {
            viewModel = InputPriorityPreview.makeViewModel()
        } else {
            viewModel = AudioInputViewModel()
        }
        #else
        viewModel = AudioInputViewModel()
        #endif
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--export-menu-symbols"), index + 1 < arguments.count {
            let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            do {
                try InputPriorityPreview.exportMenuSymbols(to: directory)
                fputs("exported menu symbols \(directory.path)\n", stderr)
            } catch {
                fputs("menu symbol export failed: \(error)\n", stderr)
                exit(1)
            }
            exit(0)
        }
        if let index = arguments.firstIndex(of: "--export-screenshots"), index + 1 < arguments.count {
            var directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            do {
                do {
                    try InputPriorityPreview.exportScreenshots(viewModel: viewModel, to: directory)
                } catch {
                    directory = FileManager.default.temporaryDirectory
                        .appendingPathComponent("MicFirstScreenshots", isDirectory: true)
                        .appendingPathComponent(directory.lastPathComponent, isDirectory: true)
                    try InputPriorityPreview.exportScreenshots(viewModel: viewModel, to: directory)
                }
                fputs("exported \(directory.path)\n", stderr)
            } catch {
                fputs("screenshot export failed: \(error)\n", stderr)
                exit(1)
            }
            exit(0)
        }
        #endif
        symbolRenderer.start(viewModel: viewModel)
        #if DEBUG
        InputPriorityPreview.setReviewReduceMotion = { [weak symbolRenderer] in symbolRenderer?.setReduceMotionForReview($0) }
        #endif
        let controller = statusController
        PreferredInputHUD.shared.anchorProvider = controller
        controller.anchorChanged = { [weak self] in
            PreferredInputHUD.shared.anchorDidChange()
            self?.showPreviewIfReady()
        }
        controller.start()
        #if DEBUG
        HUDDiagnostics.shared.start(
            anchor: { [weak controller] in controller?.hudAnchor() },
            presentation: { PreferredInputHUD.shared.diagnosticPresentation() }
        )
        #endif
        showPreviewIfReady()
    }

    private func showPreviewIfReady() {
        #if DEBUG
        guard !didShowPreview, ProcessInfo.processInfo.arguments.contains("--priority-preview") else { return }
        if ProcessInfo.processInfo.arguments.contains("--hud-preview"), statusController.hudAnchor() == nil { return }
        didShowPreview = true
        DispatchQueue.main.async { [viewModel] in
            InputPriorityPreview.showWindow(viewModel: viewModel)
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        PreferredInputHUD.shared.dismissForMenuOpening()
        statusController.stop()
        symbolRenderer.stop()
        #if DEBUG
        HUDDiagnostics.shared.stop()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct MicFirstMenuLabel: View {
    let viewModel: AudioInputViewModel
    @ObservedObject var renderer: MenuBarSymbolRenderer

    var body: some View {
        Label {
            Text("MicFirst")
        } icon: {
            if #available(macOS 26.0, *), renderer.isInstalled {
                Image(nsImage: MenuBarSymbolRenderer.placeholder)
            } else {
                LiveMicFirstMenuSymbol(viewModel: viewModel)
            }
        }
        .accessibilityIdentifier("micfirst-status-item")
    }
}

private struct LiveMicFirstMenuSymbol: View {
    @ObservedObject var viewModel: AudioInputViewModel
    var body: some View { MicFirstMenuSymbol(state: viewModel.menuBarMicrophoneState) }
}

/// Static asset review uses the same native masters, font, and scale as the
/// status item. Animation verification must capture the live status button.
struct MicFirstMenuSymbol: View {
    let state: MenuBarMicrophoneState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var symbol: Image {
        if state.usesSystemSymbol {
            return Image(systemName: state.symbolName)
        }
        return Image(state.symbolName, variableValue: state.variableValue, bundle: .main)
    }

    var body: some View {
        styledSymbol
    }

    private var styledSymbol: some View {
        symbol
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 16, weight: .regular))
            .imageScale(.small)
            .frame(width: 21, height: 18)
            .offset(x: state.horizontalOffset)
            .transaction { transaction in
                if reduceMotion { transaction.disablesAnimations = true }
            }
    }
}
