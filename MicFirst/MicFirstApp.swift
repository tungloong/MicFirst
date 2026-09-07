import SwiftUI

@main
struct MicFirstApp: App {
    @StateObject private var viewModel: AudioInputViewModel

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--priority-preview") {
            let previewModel = InputPriorityPreview.makeViewModel()
            _viewModel = StateObject(wrappedValue: previewModel)
            DispatchQueue.main.async { InputPriorityPreview.showWindow(viewModel: previewModel) }
            return
        }
        #endif
        _viewModel = StateObject(wrappedValue: AudioInputViewModel())
    }

    var body: some Scene {
        MenuBarExtra {
            SoundMenuView(viewModel: viewModel)
        } label: {
            Label("Sound", image: viewModel.menuBarIconName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            InputPrioritySettingsView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}
