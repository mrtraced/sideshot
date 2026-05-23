import SwiftUI
import SideSyncLib

/// Middle column — the user's pending working draft of the sidebar.
/// P1: read-only display + selection. Editing/drag/drawer arrive in P2/P3.
struct PendingPaneView: View {
    @Environment(AppState.self) private var state

    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .help("Pending Sidebar — your working draft. Apply to push to Finder.")
                Text("Pending Sidebar")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(state.pending.count) items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Number of items in Pending")
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
        .background(
            isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear
        )
        .overlay(
            isDropTargeted
                ? RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                : nil
        )
        .dropDestination(for: DraggedSidebarItem.self) { items, _ in
            for d in items {
                switch d.source {
                case .library:
                    state.dropLibraryItemOntoPending(d.identifier)
                case .current:
                    state.dropCurrentOntoPending(name: d.name, path: d.path)
                case .pending:
                    break  // self-drag is a no-op (reorder is via ▲/▼)
                }
            }
            return true
        } isTargeted: { isDropTargeted = $0 }
    }
}

private struct PendingRow: View {
    @Environment(AppState.self) private var state
    let item: PendingItem

    var body: some View {
        let exists = PathResolver.exists(item.path)
        let inCurrent = state.localFavorites.contains(where: { sameItem($0.path, item.path) })
        let isLinked = item.libraryItemId != nil
        let isSelected = state.selectedPendingItemId == item.id
        let idx = state.pending.firstIndex(where: { $0.id == item.id }) ?? 0
        let canMoveUp = idx > 0
        let canMoveDown = idx < state.pending.count - 1

        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.blue)
                .font(.system(size: 14))
                .help("Sidebar item")

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    // Path existence — most important: will Apply actually work?
                    if exists {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                            .help("Path exists on this machine")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                            .help("Path missing — Apply will skip this item")
                    }

                    // Already in Current — applying won't change this entry
                    if inCurrent {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 9))
                            .foregroundStyle(.gray)
                            .help("Already in Current Sidebar — Apply is a no-op for this entry")
                    }

                    // Library linkage — edits propagate cross-machine
                    if isLinked {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                            .help("Linked to Library — edits propagate to other machines via the cloud record")
                    } else {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .help("Independent — not linked to Library; edits stay local")
                    }
                }
                Text(abbreviatePath(item.path))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(item.path)
            }

            Spacer(minLength: 0)

            // Reorder + remove controls — only on the selected row
            if isSelected {
                HStack(spacing: 2) {
                    Button {
                        state.movePendingItem(id: item.id, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canMoveUp)
                    .help("Move up")

                    Button {
                        state.movePendingItem(id: item.id, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canMoveDown)
                    .help("Move down")

                    Button(role: .destructive) {
                        state.removePendingItem(id: item.id)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove from Pending")
                }
            }
        }
        .padding(.vertical, 1)
        .draggable(DraggedSidebarItem(
            source: .pending,
            identifier: item.id,
            name: item.name,
            path: item.path
        )) {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.blue)
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(6)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func sameItem(_ a: String, _ b: String) -> Bool {
        let na = a.hasSuffix("/") ? String(a.dropLast()) : a
        let nb = b.hasSuffix("/") ? String(b.dropLast()) : b
        return na == nb
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
