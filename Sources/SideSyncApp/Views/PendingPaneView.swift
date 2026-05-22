import SwiftUI
import SideSyncLib

/// Middle column — the user's pending working draft of the sidebar.
/// P1: read-only display + selection. Editing/drag/drawer arrive in P2/P3.
struct PendingPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Pending Sidebar")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(state.pending.count) items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Body
            if state.pending.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("Pending is empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Use Reset Pending to copy the current sidebar, or drag items from the Library.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { state.selectedPendingItemId },
                    set: { newId in
                        state.selectedPendingItemId = newId
                        if newId != nil { state.editPaneSource = .pending }
                    }
                )) {
                    ForEach(state.pending) { item in
                        PendingRow(item: item)
                            .tag(item.id as String?)
                    }
                }
                .listStyle(.inset)
            }

        }
    }
}

private struct PendingRow: View {
    @Environment(AppState.self) private var state
    let item: PendingItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.libraryItemId != nil ? "link.circle.fill" : "folder.fill")
                .foregroundStyle(item.libraryItemId != nil ? Color.accentColor : Color.blue)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(abbreviatePath(item.path))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 1)
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
