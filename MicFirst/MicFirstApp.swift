import SwiftUI

@main
struct MicFirstApp: App {
    @NSApplicationDelegateAdaptor(MicFirstAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            SoundMenuView(viewModel: appDelegate.viewModel)
        } label: {
            MicFirstMenuLabel(viewModel: appDelegate.viewModel)
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
    #if DEBUG
    private var didShowPreview = false
    private var menuAnchorReceiver: HUDMenuAnchorReceiver?
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
        let controller = statusController
        PreferredInputHUD.shared.anchorProvider = controller
        controller.anchorChanged = { [weak self] in
            PreferredInputHUD.shared.anchorDidChange()
            self?.showPreviewIfReady()
        }
        #if DEBUG
        let receiver = HUDMenuAnchorReceiver { [weak controller] anchors in
            guard let controller, controller.update(anchors) else { return false }
            PreferredInputHUD.shared.updateSystemMenuAnchors(anchors)
            return true
        }
        menuAnchorReceiver = receiver
        receiver.start()
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
        #if DEBUG
        HUDDiagnostics.shared.stop()
        menuAnchorReceiver?.stop()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct MicFirstMenuLabel: View {
    @ObservedObject var viewModel: AudioInputViewModel
    var body: some View {
        Label("MicFirst", image: viewModel.menuBarIconName)
            .accessibilityIdentifier("micfirst-status-item")
    }
}
