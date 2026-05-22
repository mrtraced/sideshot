import SwiftUI
import SideSyncLib

/// Middle pane content when the snapshot drawer is open.
/// Shows the items inside the currently-selected snapshot (chosen from
/// the Machines pane on the left) and the three action buttons across
/// the bottom: Replace Pending, Save Uniques, Trash.
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
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.10),
                        Color.indigo.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
                .font(.system(size: 11))
                .foregroundStyle(.indigo)
            if let snap = selectedSnapshot {
                Text(snap.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(snap.machineId)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("Snapshot Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
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
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Body — items in the selected snapshot

    @ViewBuilder
    private var body_: some View {
        if let snap = selectedSnapshot {
            List {
                ForEach(Array(snap.items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue.opacity(0.7))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Text(abbreviatePath(item.path))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                    .help(item.path)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("Pick a snapshot")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Expand a machine on the left and choose one of its snapshots to preview its contents here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedSnapshot: SidebarSnapshot? {
        guard let id = state.drawerSnapshotId else { return nil }
        return state.allSnapshots.first { $0.id == id }
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Footer — actions (always visible)

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
