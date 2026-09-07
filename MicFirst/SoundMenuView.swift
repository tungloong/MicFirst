import SwiftUI

struct SoundMenuView: View {
    @ObservedObject var viewModel: AudioInputViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            volumeSection
            Divider().padding(.horizontal, 16)
            HStack {
                Text("Input Priority")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(
                    "Input Priority",
                    isOn: Binding(
                        get: { viewModel.automaticInputIsEnabled },
                        set: viewModel.setAutomaticInputEnabled
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityIdentifier("input-priority-toggle")
            }
            .frame(height: 16)
            .padding(.horizontal, 16)
            .padding(.top, 11)
            .padding(.bottom, 7)

            deviceList
                .padding(.bottom, 10)

            if let errorMessage = viewModel.errorMessage {
                Divider().padding(.horizontal, 16)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            Divider().padding(.horizontal, 8)
            VStack(spacing: 0) {
                Button {
                    dismiss()
                    viewModel.openSoundSettings()
                } label: {
                    MenuActionLabel("macOS Sound Settings…")
                }
                .buttonStyle(.plain)

                AppSettingsButton()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    MenuActionLabel("Quit MicFirst", shortcut: "⌘Q")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .font(.system(size: 13))
        .frame(width: 308)
        .onAppear(perform: viewModel.menuDidOpen)
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sound")
                .font(.system(size: 13, weight: .semibold))
            HStack {
                Image(systemName: "mic.and.signal.meter.fill", variableValue: 0.25)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { viewModel.currentVolume },
                        set: viewModel.setCurrentVolume
                    ), in: 0...1
                )
                .tint(Color(nsColor: .systemBlue))
                .controlSize(.small)
                .disabled(!viewModel.volumeIsEnabled)
                .accessibilityLabel(Text("Input Volume"))
                Image(systemName: "mic.and.signal.meter.fill", variableValue: 1)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 11)
    }

    @ViewBuilder
    private var deviceList: some View {
        if viewModel.menuRows.isEmpty {
            Text(viewModel.priorityRows.isEmpty ? "No Input Devices" : "No Devices Shown in Menu")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .frame(height: 30)
        } else {
            ReorderableInputList(
                rows: viewModel.menuRows, rowHeight: 30, maximumVisibleRows: 10,
                showsHandlesOnHover: true, horizontalInset: 8,
                move: { viewModel.moveDevice(uid: $0, beforeUID: $1, inMenu: true) }
            ) { row, handle in
                InputPriorityDeviceRow(row: row, handle: handle) { viewModel.selectDevice(uid: row.id) }
            }
        }
    }
}

private struct InputPriorityDeviceRow: View {
    let row: InputPriorityRow
    let handle: InputPriorityDragHandle
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(
                            row.isCurrent ? Color(nsColor: .systemBlue) : Color(nsColor: .labelColor).opacity(0.115))
                        Image(systemName: row.iconSystemName)
                            .font(.system(size: 14, weight: .medium))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(row.isCurrent ? .white : .secondary)
                    }
                    .frame(width: 26, height: 26)
                    .opacity(row.isOnline ? 1 : 0.45)

                    Text(row.name)
                        .foregroundStyle(row.isOnline ? Color.primary : Color(nsColor: .disabledControlTextColor))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            handle
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .contentShape(Rectangle())
        .menuItemHover()
        // Offline rows remain draggable during the five-minute grace period.
        .padding(.horizontal, 8)
        .help(row.name)
        .accessibilityLabel(row.name)
        .accessibilityValue(
            row.isOnline ? (row.isCurrent ? Text("Current Input") : Text("Available")) : Text("Offline")
        )
        .accessibilityIdentifier("input-device-\(row.id)")
    }
}

struct MenuActionLabel: View {
    let title: LocalizedStringKey
    var shortcut: String?

    init(_ title: LocalizedStringKey, shortcut: String? = nil) {
        self.title = title
        self.shortcut = shortcut
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let shortcut { Text(shortcut).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .menuItemHover()
    }
}

private struct MenuItemHover: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                Color(nsColor: .labelColor).opacity(isHovered ? 0.11 : 0),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .onHover { isHovered = $0 }
    }
}

extension View {
    fileprivate func menuItemHover() -> some View { modifier(MenuItemHover()) }
}
