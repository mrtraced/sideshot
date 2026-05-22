import SwiftUI
import SideSyncLib

/// Bottom-up drawer that overlays the Pending pane.
/// Lets the user pick a snapshot and load it into Pending (not Finder).
struct SnapshotDrawerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            body_
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
                .fill(Color.indigo.opacity(0.5))
                .frame(height: 2),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: -3)
        .frame(maxWidth: .infinity)
        .frame(height: 320)
    }

    // MARK: - Header — dropdown

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 13))
                .foregroundStyle(.indigo)
            Text("Snapshots")
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            if state.allSnapshots.isEmpty {
                Text("No snapshots yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("", selection: Binding(
                    get: { state.drawerSnapshotId ?? state.allSnapshots.first?.id ?? "" },
                    set: { state.drawerSnapshotId = $0 }
                )) {
                    ForEach(state.allSnapshots) { snap in
                        Text(displayName(snap))
                            .tag(snap.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 240)
            }

            Button {
                state.showSnapshotDrawer = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close snapshot picker")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func displayName(_ snap: SidebarSnapshot) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, HH:mm"
        return "\(snap.name) — \(snap.machineId) · \(fmt.string(from: snap.timestamp))"
    }

    // MARK: - Body — list of items in selected snapshot

    @ViewBuilder
    private var body_: some View {
        if let snap = selectedSnapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(snap.items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 12))
                                Text(item.path)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.vertical, 6)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text("No snapshots yet — Take Snapshot from the toolbar to capture one.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedSnapshot: SidebarSnapshot? {
        if let id = state.drawerSnapshotId,
           let snap = state.allSnapshots.first(where: { $0.id == id }) {
            return snap
        }
        return state.allSnapshots.first
    }

    // MARK: - Footer — Apply / Save Uniques / Trash

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                if let snap = selectedSnapshot {
                    state.loadSnapshotIntoPending(snap)
                    state.showSnapshotDrawer = false
                }
            } label: {
                Label("Apply to Pending", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(selectedSnapshot == nil)
            .help("Replace Pending with this snapshot's items (does NOT touch Finder)")

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
            .help("Add items not yet in Library to the Library")

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
            .help("Delete this snapshot")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
