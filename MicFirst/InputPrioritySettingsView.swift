import SwiftUI

struct InputPrioritySettingsView: View {
    @ObservedObject var viewModel: AudioInputViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Input Priority").fontWeight(.semibold)
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
                .controlSize(.small)
                .accessibilityIdentifier("settings-input-priority-toggle")
            }

            VStack(spacing: 0) {
                tableHeader
                Divider()
                if viewModel.priorityRows.isEmpty {
                    Text("No Input Devices")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    ReorderableInputList(
                        rows: viewModel.priorityRows, rowHeight: 40, maximumVisibleRows: 8,
                        move: { viewModel.moveDevice(uid: $0, beforeUID: $1) }
                    ) { row, handle in
                        SettingsDeviceRow(row: row, handle: handle, viewModel: viewModel)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5) }

            Text("Offline devices leave the menu after 5 minutes. Manually hidden devices aren’t selected automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Text("Show HUD Notifications")
                Spacer()
                Toggle("Show HUD Notifications", isOn: Binding(
                    get: { viewModel.showsHUD }, set: viewModel.setShowsHUD
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityIdentifier("settings-hud-toggle")
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 13))
        .padding(20)
        .frame(width: 660)
        .navigationTitle("Settings")
        .onAppear(perform: viewModel.settingsDidOpen)
    }

    private var tableHeader: some View {
        HStack(spacing: 10) {
            Text("#").frame(width: 26)
            Text("Input Device").frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: 70, alignment: .leading)
            Text("Show in Menu").frame(width: 104)
            Color.clear.frame(width: 24, height: 1)
            Color.clear.frame(width: 14, height: 1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
    }
}

private struct SettingsDeviceRow: View {
    let row: InputPriorityRow
    let handle: InputPriorityDragHandle
    @ObservedObject var viewModel: AudioInputViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text(row.priority, format: .number)
                .monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 26)

            HStack(spacing: 8) {
                Image(systemName: row.iconSystemName)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(row.name)
                    .foregroundStyle(row.isOnline ? Color.primary : Color.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(row.name)

            Text(row.isOnline ? (row.isCurrent ? "Current Input" : "Available") : "Offline")
                .font(.system(size: 11))
                .foregroundStyle(row.isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 70, alignment: .leading)

            Toggle(
                "Show in Menu",
                isOn: Binding(
                    get: { row.isShownInMenu },
                    set: { viewModel.setDeviceShownInMenu($0, uid: row.id) }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(!row.isOnline)
            .frame(width: 104)
            .accessibilityLabel(Text("Show in Menu: \(row.name)"))
            .accessibilityIdentifier("show-device-\(row.id)")
            .help(row.isOnline
                ? Text("Hidden devices are excluded from automatic selection.")
                : Text("Offline devices leave the menu after 5 minutes and return when connected, unless manually hidden."))

            Button {
                viewModel.removeOfflineDevice(uid: row.id)
            } label: {
                Image(systemName: "trash").frame(width: 24, height: 28)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(row.isOnline)
            .opacity(row.isOnline ? 0 : 1)
            .accessibilityHidden(row.isOnline)
            .accessibilityLabel(Text("Delete Device: \(row.name)"))
            .accessibilityIdentifier("delete-device-\(row.id)")
            .help(Text("Delete Device"))

            handle
        }
        .padding(.horizontal, 10)
        .background(row.priority.isMultiple(of: 2) ? Color.primary.opacity(0.025) : Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-device-\(row.id)")
    }
}

struct AppSettingsButton: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            OpenAppSettingsButton()
        } else {
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                MenuActionLabel("MicFirst Settings…", shortcut: "⌘,")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",")
        }
    }
}

@available(macOS 14.0, *)
private struct OpenAppSettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            MenuActionLabel("MicFirst Settings…", shortcut: "⌘,")
        }
        .buttonStyle(.plain)
        .keyboardShortcut(",")
        .accessibilityIdentifier("open-app-settings")
    }
}
