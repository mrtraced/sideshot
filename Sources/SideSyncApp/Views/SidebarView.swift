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
                        currentRow(fav)
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
    private func currentRow(_ fav: SidebarFavorite) -> some View {
        let exists = PathResolver.exists(fav.path)
        let inLibrary = state.libraryItem(matchingPath: fav.path) != nil
        let inPending = state.pending.contains(where: { sameItem($0.path, fav.path) })

        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(fav.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Existence badge — green check or red x
                    if exists {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                            .help("Path exists on this machine")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                            .help("Path not found")
                    }

                    if inLibrary {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue.opacity(0.7))
                            .help("Also in Item Library")
                    }

                    if inPending {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange.opacity(0.8))
                            .help("Also in Pending")
                    }
                }
                Text(abbreviatePath(fav.path))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 1)
        .help(fav.path)
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
