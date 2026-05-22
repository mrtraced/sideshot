import SwiftUI
import SideSyncLib

/// Full-pane takeover that replaces the Pending view when active.
/// Lets the user browse snapshots across all machines, then either
/// replace Pending with a snapshot's contents, harvest unique items
/// into Library, or delete the snapshot.
struct SnapshotDrawerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HSplitView {
                machinesList
                    .frame(minWidth: 140, idealWidth: 160, maxWidth: 200)

                snapshotDetail
                    .frame(minWidth: 220)
            }

            Divider()

            footer
        }
        .background(
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.10),
                    Color.indigo.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .fill(Color.indigo.opacity(0.45))
                .frame(height: 2),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: -3)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 13))
                .foregroundStyle(.indigo)
            Text("Snapshots & Machines")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button {
                state.showSnapshotDrawer = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Machines list (left)

    @ViewBuilder
    private var machinesList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MACHINES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if state.knownMachines.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "laptopcomputer.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                    Text("No machines yet")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { state.drawerMachineId ?? state.machineId },
                    set: {
                        state.drawerMachineId = $0
                        state.drawerSnapshotId = nil
                    }
                )) {
                    ForEach(state.knownMachines, id: \.self) { machine in
                        machineRow(machine)
                            .tag(machine as String?)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private func machineRow(_ machine: String) -> some View {
        let isMe = machine == state.machineId
        let count = state.snapshotsForMachine(machine).count

        HStack(spacing: 6) {
            Image(systemName: isMe ? "desktopcomputer" : "laptopcomputer")
                .font(.system(size: 11))
                .foregroundStyle(isMe ? Color.indigo : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(machine)
                        .font(.system(size: 12, weight: isMe ? .semibold : .regular))
                        .lineLimit(1)
                    if isMe {
                        Text("(this)")
                            .font(.system(size: 9))
                            .foregroundStyle(.indigo)
                    }
                }
                Text("\(count) snapshot\(count == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    // MARK: - Snapshot detail (right)

    private var activeMachine: String {
        state.drawerMachineId ?? state.machineId
    }

    private var machineSnapshots: [SidebarSnapshot] {
        state.snapshotsForMachine(activeMachine)
    }

    @ViewBuilder
    private var snapshotDetail: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SNAPSHOTS FROM \(activeMachine.uppercased())")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if machineSnapshots.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No snapshots from \(activeMachine)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if activeMachine == state.machineId {
                        Text("Use Take Snapshot in the toolbar to capture one.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { state.drawerSnapshotId },
                    set: { state.drawerSnapshotId = $0 }
                )) {
                    ForEach(machineSnapshots) { snap in
                        snapshotCard(snap)
                            .tag(snap.id as String?)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private func snapshotCard(_ snap: SidebarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.indigo)
                Text(snap.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(snap.items.count) items")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text(snap.timestamp, format: .dateTime.month().day().year().hour().minute())
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            // Item preview (first 6)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(snap.items.prefix(6).enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text(item.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                if snap.items.count > 6 {
                    Text("…and \(snap.items.count - 6) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 14)
                }
            }
            .padding(.leading, 4)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer actions

    private var selectedSnapshot: SidebarSnapshot? {
        guard let id = state.drawerSnapshotId else { return nil }
        return machineSnapshots.first { $0.id == id }
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                if let snap = selectedSnapshot {
                    state.loadSnapshotIntoPending(snap)
                    state.showSnapshotDrawer = false
                }
            } label: {
                Label("Replace Pending", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(selectedSnapshot == nil)
            .help("Replace Pending with this snapshot's items (Finder is NOT touched)")

            Button {
                if let snap = selectedSnapshot {
                    state.saveSnapshotUniquesToLibrary(snap)
                }
            } label: {
                Label("Save Uniques", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(selectedSnapshot == nil)
            .help("Add items not yet in Library to the Library (keeps Pending unchanged)")

            Button(role: .destructive) {
                if let snap = selectedSnapshot {
                    state.deleteSnapshot(snap)
                    state.drawerSnapshotId = nil
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(selectedSnapshot == nil)
            .help("Delete this snapshot from the cloud")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
