import SwiftUI
import SideSyncLib

/// Right-bottom — Item Library: flat pool of reusable items as a tile grid.
struct LibraryPaneView: View {
    @Environment(AppState.self) private var state

    private let tileSize = CGSize(width: 140, height: 70)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "tray.full")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .help("Item Library — reusable folder records that live in the cloud")
                Text("Item Library")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(state.libraryItems.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Number of items in the Library")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if state.libraryItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No saved items")
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
                        ForEach(state.libraryItems) { item in
                            LibraryTile(item: item, size: tileSize)
                        }
                    }
                    .padding(10)
                }
            }
        }
    }
}

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
        .contextMenu {
            Button(role: .destructive) {
                state.removeFromLibrary(item)
            } label: {
                Label("Remove from Library", systemImage: "trash")
            }
        }
        .quickHelp(inUse ? "\(fullPath)  •  In use in Pending" : fullPath)
    }
}
