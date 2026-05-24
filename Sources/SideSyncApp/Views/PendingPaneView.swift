import SwiftUI
import UniformTypeIdentifiers
import SideSyncLib

/// Middle column — the user's pending working draft of the sidebar.
/// P1: read-only display + selection. Editing/drag/drawer arrive in P2/P3.
struct PendingPaneView: View {
    @Environment(AppState.self) private var state

    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                icon: "pencil.and.list.clipboard",
                iconHelp: "Pending Sidebar — your working draft. Apply to push to Finder.",
                title: "Pending Sidebar"
            ) {
                Text("\(state.pending.count) items")
                    .font(Theme.Font_.paneCount)
                    .foregroundStyle(.tertiary)
                    .help("Number of items in Pending")
            }

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
                    .onMove(perform: state.reorderPending)
                    .onInsert(of: [UTType.sideshotSidebarItem, UTType.fileURL], perform: state.insertIntoPending)
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
        .onDrop(of: [UTType.sideshotSidebarItem, UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            Task {
                let items = await DraggedSidebarItem.decode(from: providers)
                await MainActor.run {
                    for d in items {
                        switch d.source {
                        case .library:
                            state.dropLibraryItemOntoPending(d.identifier)
                        case .current:
                            state.dropCurrentOntoPending(name: d.name, path: d.path)
                        case .pending:
                            break  // self-drag is a no-op (reorder via ▲/▼)
                        }
                    }
                }
            }
            return true
        }
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

        HStack(spacing: Theme.Space.md) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.blue)
                .font(.system(size: 15))
                .help("Sidebar item")

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Theme.Space.xs) {
                    Text(item.name)
                        .font(Theme.Font_.rowTitle)
                        .lineLimit(1)

                    // Path existence — most important: will Apply actually work?
                    if exists {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Theme.Font_.badge)
                            .foregroundStyle(Theme.Colors.success)
                            .help("Path exists on this machine")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.Font_.badge)
                            .foregroundStyle(Theme.Colors.error)
                            .help("Path missing — Apply will skip this item")
                    }

                    // Already in Current — applying won't change this entry
                    if inCurrent {
                        Image(systemName: "sidebar.left")
                            .font(Theme.Font_.badge)
                            .foregroundStyle(.gray)
                            .help("Already in Current Sidebar — Apply is a no-op for this entry")
                    }

                    // Library linkage — edits propagate cross-machine
                    if isLinked {
                        Image(systemName: "link")
                            .font(Theme.Font_.badge)
                            .foregroundStyle(Theme.Colors.linkedAccent)
                            .help("Linked to Library — edits propagate to other machines via the cloud record")
                    } else {
                        Image(systemName: "link.badge.plus")
                            .font(Theme.Font_.badge)
                            .foregroundStyle(.tertiary)
                            .help("Independent — not linked to Library; edits stay local")
                    }
                }
                Text(abbreviatePath(item.path))
                    .font(Theme.Font_.rowPath)
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
        .onDrag {
            DraggedSidebarItem(
                source: .pending,
                identifier: item.id,
                name: item.name,
                path: item.path
            ).makeItemProvider()
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
