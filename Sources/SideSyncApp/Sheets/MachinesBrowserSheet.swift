import SwiftUI
import SideSyncLib

/// Sheet for browsing other machines' sidebars and their history.
struct MachinesBrowserSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMachine: String?
    @State private var selectedSnapshot: SidebarSnapshot?
    @State private var showApplyConfirm: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Machines & Sidebar History")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Two-column layout: machines list | snapshot detail
            HSplitView {
                machinesList
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

                snapshotDetail
                    .frame(minWidth: 300, idealWidth: 400)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .frame(idealWidth: 700, idealHeight: 500)
        .alert("Apply Sidebar", isPresented: $showApplyConfirm) {
            Button("Apply", role: .destructive) {
                if let snapshot = selectedSnapshot {
                    state.applySnapshot(snapshot)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let snapshot = selectedSnapshot {
                Text("Apply \(snapshot.machineId)'s sidebar (\(snapshot.items.count) items) to this machine? New items will be added to your sidebar.")
            }
        }
    }

    @ViewBuilder
    private var machinesList: some View {
        List(selection: $selectedMachine) {
            Section("Machines") {
                ForEach(state.knownMachines, id: \.self) { machine in
                    HStack(spacing: 6) {
                        Image(systemName: machine == state.machineId
                              ? "desktopcomputer" : "laptopcomputer")
                            .font(.system(size: 12))
                            .foregroundStyle(machine == state.machineId ? .blue : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(machine)
                                    .font(.system(size: 13, weight: machine == state.machineId ? .semibold : .regular))
                                if machine == state.machineId {
                                    Text("(this)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.blue)
                                }
                            }

                            if let latest = state.latestSnapshot(for: machine) {
                                Text("\(latest.items.count) items")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .tag(machine)
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var snapshotDetail: some View {
        if let machine = selectedMachine {
            let snapshots = state.snapshotsForMachine(machine)

            if snapshots.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("No sidebar history for \(machine)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("History is saved each time this machine pushes to the cloud.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(snapshots) { snapshot in
                        snapshotRow(snapshot, machine: machine)
                    }
                }
                .listStyle(.inset)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sidebar.squares.leading")
                    .font(.system(size: 32))
                    .foregroundStyle(.quaternary)
                Text("Select a machine")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("View sidebar history and apply configurations from other machines.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func snapshotRow(_ snapshot: SidebarSnapshot, machine: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Snapshot header
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(snapshot.timestamp, style: .date)
                    .font(.system(size: 12, weight: .medium))
                Text(snapshot.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.items.count) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Items list
            VStack(alignment: .leading, spacing: 2) {
                ForEach(snapshot.items, id: \.name) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue.opacity(0.7))
                        Text(item.name)
                            .font(.system(size: 11))
                        Spacer()
                        Text(abbreviatedPath(item.path))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 4)

            // Action buttons
            HStack(spacing: 8) {
                if machine != state.machineId {
                    Button {
                        selectedSnapshot = snapshot
                        showApplyConfirm = true
                    } label: {
                        Label("Apply to This Machine", systemImage: "square.and.arrow.down")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Add these sidebar items to your current Finder sidebar")
                } else {
                    Button {
                        selectedSnapshot = snapshot
                        showApplyConfirm = true
                    } label: {
                        Label("Restore", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Restore this sidebar configuration")
                }

                Button(role: .destructive) {
                    state.deleteSnapshot(snapshot)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Remove this snapshot from history")
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
