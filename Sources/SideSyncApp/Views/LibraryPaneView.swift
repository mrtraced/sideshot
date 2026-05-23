import SwiftUI
import UniformTypeIdentifiers
import SideSyncLib

/// Right-bottom — Item Library: flat pool of reusable items as a tile grid.
struct LibraryPaneView: View {
    @Environment(AppState.self) private var state

    @State private var isDropTargeted = false

    private let tileSize = CGSize(width: 140, height: 70)

    var body: some View {
        @Bindable var state = state

        // Explicit subscriptions so SwiftUI's @Observable tracking sees these
        // through the computed libraryItems chain — without this, picking a
        // new sort or toggling archive doesn't re-render the grid until some
        // other observed property changes.
        let _ = state.librarySort
        let _ = state.showArchivedLibrary

        VStack(spacing: 0) {
            header(bindable: state)
            Divider()
            body_
        }
        .background(
            isDropTargeted
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .overlay(
            isDropTargeted
                ? RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                : nil
        )
        .onDrop(of: [UTType.sideshotSidebarItem], isTargeted: $isDropTargeted) { providers in
            guard !state.showArchivedLibrary else { return false }  // archive view doesn't accept drops
            Task {
                let items = await DraggedSidebarItem.decode(from: providers)
                await MainActor.run { handleDrop(items) }
            }
            return true
        }
    }

    private func handleDrop(_ items: [DraggedSidebarItem]) {
        for item in items {
            switch item.source {
            case .current:
                state.dropCurrentOntoLibrary(name: item.name, path: item.path)
            case .pending:
                state.dropPendingOntoLibrary(pendingId: item.identifier)
            case .library:
                break  // self-drag is a no-op
            }
        }
    }

    @ViewBuilder
    private func header(bindable: AppState) -> some View {
        @Bindable var bindable = bindable

        HStack(spacing: 6) {
            Image(systemName: state.showArchivedLibrary ? "archivebox.fill" : "tray.full")
                .font(.system(size: 11))
                .foregroundStyle(state.showArchivedLibrary ? Color.orange : .secondary)
                .help(state.showArchivedLibrary
                      ? "Archive — items you've removed but not permanently deleted"
                      : "Item Library — reusable folder records that live in the cloud")
            Text(state.showArchivedLibrary ? "Archive" : "Item Library")
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            Text("\(displayedCount)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .help("\(displayedCount) item\(displayedCount == 1 ? "" : "s") shown")

            sortPicker(bindable: bindable)

            archiveToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var displayedCount: Int {
        state.showArchivedLibrary ? state.archivedLibraryItems.count : state.libraryItems.count
    }

    @ViewBuilder
    private func sortPicker(bindable: AppState) -> some View {
        @Bindable var bindable = bindable

        Menu {
            Picker("Sort", selection: $bindable.librarySort) {
                ForEach(AppState.LibrarySort.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: state.librarySort.iconName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort: \(state.librarySort.rawValue)")
        .disabled(state.showArchivedLibrary)
    }

    @ViewBuilder
    private var archiveToggle: some View {
        Button {
            state.showArchivedLibrary.toggle()
        } label: {
            Image(systemName: state.showArchivedLibrary ? "tray.full" : "archivebox")
                .font(.system(size: 11))
                .foregroundStyle(state.showArchivedLibrary ? Color.accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .help(state.showArchivedLibrary
              ? "Back to Library"
              : "Show archived items (soft-deleted, can be restored)")
    }

    // MARK: - Body

    @ViewBuilder
    private var body_: some View {
        let items = state.showArchivedLibrary ? state.archivedLibraryItems : state.libraryItems

        if items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: state.showArchivedLibrary ? "archivebox" : "tray")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text(state.showArchivedLibrary ? "Nothing archived" : "No saved items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: tileSize.width, maximum: tileSize.width + 30), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(items) { item in
                        if state.showArchivedLibrary {
                            ArchivedTile(item: item, size: tileSize)
                        } else {
                            LibraryTile(item: item, size: tileSize)
                        }
                    }
                }
                .padding(10)
            }
        }
    }
}

// MARK: - Active Library tile

private struct LibraryTile: View {
    @Environment(AppState.self) private var state
    let item: CloudFavorite
    let size: CGSize

    var body: some View {
        let isSelected = state.selectedCloudFavorite?.id == item.id && state.editPaneSource == .library
        let inUse = state.isInPending(libraryItemId: item.id)
        let fullPath = item.paths[state.machineId] ?? item.paths.values.first ?? item.pathHints.joined(separator: "/")

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(inUse ? Color.gray.opacity(0.55) : Color.blue.opacity(0.85))
                    .font(.system(size: 14))
                    .help("Library item — saved across machines")
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(inUse ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if inUse {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .help("In use in Pending — already placed in the draft sidebar")
                }
            }
            Spacer(minLength: 0)
            Text(item.pathHints.last ?? "")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.18)
                    : inUse ? Color.gray.opacity(0.06)
                    : Color.gray.opacity(0.10)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.gray.opacity(0.22),
                    style: StrokeStyle(lineWidth: isSelected ? 1.5 : 1, dash: inUse ? [3, 2] : [])
                )
        )
        .opacity(inUse ? 0.65 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            state.selectedCloudFavorite = item
            state.editPaneSource = .library
        }
        .onDrag {
            DraggedSidebarItem(
                source: .library,
                identifier: item.id,
                name: item.name,
                path: fullPath
            ).makeItemProvider()
        }
        .contextMenu {
            Button {
                state.removeFromLibrary(item)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
        .quickHelp(inUse ? "\(fullPath)  •  In use in Pending" : fullPath)
    }
}

// MARK: - Archived tile (hover to reveal restore + hard-delete)

private struct ArchivedTile: View {
    @Environment(AppState.self) private var state
    let item: CloudFavorite
    let size: CGSize

    @State private var isHovering = false

    var body: some View {
        let fullPath = item.paths[state.machineId] ?? item.paths.values.first ?? item.pathHints.joined(separator: "/")

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .foregroundStyle(Color.gray.opacity(0.6))
                    .font(.system(size: 14))
                    .help("Archived item — restore to bring back to Library")
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text(item.pathHints.last ?? "")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(isHovering ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.30),
                              style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        )
        .overlay(alignment: .topTrailing) {
            if isHovering {
                HStack(spacing: 4) {
                    Button {
                        state.unarchiveFromLibrary(item)
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                    .help("Restore to Library")

                    Button {
                        state.hardDeleteFromLibrary(item)
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                    .help("Delete permanently")
                }
                .padding(4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
        .onTapGesture {
            state.selectedCloudFavorite = item
            state.editPaneSource = .library
        }
        .quickHelp("\(fullPath)  •  Archived")
    }
}
