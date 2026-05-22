import SwiftUI
import SideSyncLib

/// Left column — read-only mirror of the live Finder sidebar (for reference).
struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Current Sidebar")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("read-only")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if state.localFavorites.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No favorites found")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.localFavorites) { fav in
                        localFavoriteRow(fav)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.06))
            }
        }
        .background(Color.gray.opacity(0.04))
    }

    @ViewBuilder
    private func localFavoriteRow(_ fav: SidebarFavorite) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 1) {
                Text(fav.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(abbreviatePath(fav.path))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
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
