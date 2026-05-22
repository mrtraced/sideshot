import SwiftUI
import SideSyncLib

/// A single row in the cloud favorites list.
struct CloudFavoriteRow: View {
    let favorite: CloudFavorite
    let status: FavoriteStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: folderIcon)
                .foregroundStyle(folderColor)
                .font(.system(size: 16))

            Text(favorite.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .opacity(status == .hidden ? 0.5 : 1.0)

            Spacer()

            statusBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .synced:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        case .available:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
        case .hidden:
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        case .pathNotFound:
            Text("\u{26a0}\u{fe0f}")
                .font(.system(size: 10))
        case .noPath:
            Text("\u{2753}")
                .font(.system(size: 10))
        case .localOnly:
            Image(systemName: "pin.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        }
    }

    private var folderIcon: String {
        switch status {
        case .hidden: return "folder"
        case .synced: return "folder.fill"
        default: return "folder.fill"
        }
    }

    private var folderColor: Color {
        switch status {
        case .hidden: return .gray
        case .pathNotFound, .noPath: return .orange
        default: return .blue
        }
    }
}
