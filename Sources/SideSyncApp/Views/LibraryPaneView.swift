import SwiftUI
import SideSyncLib

/// Right-bottom — Item Library: flat pool of reusable items.
/// P1: read-only list. Drag-to-Pending and right-click actions arrive in P2/P3.
struct LibraryPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "tray.full")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Item Library")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(state.libraryItems.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                List(selection: Binding(
                    get: { state.selectedCloudFavorite?.id },
                    set: { newId in
                        state.selectedCloudFavorite = newId.flatMap { id in
                            state.libraryItems.first { $0.id == id }
                        }
                    }
                )) {
                    ForEach(state.libraryItems) { item in
                        LibraryRow(item: item)
                            .tag(item.id as String?)
                            .contextMenu {
                                Button(role: .destructive) {
                                    state.removeFromLibrary(item)
                                } label: {
                                    Label("Remove from Library", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct LibraryRow: View {
    let item: CloudFavorite

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                if !item.pathHints.isEmpty {
                    Text(item.pathHints.joined(separator: " / "))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 1)
    }
}
