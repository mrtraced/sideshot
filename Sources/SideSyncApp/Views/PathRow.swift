import SwiftUI

/// A single machine-path row in the preview pane.
struct PathRow: View {
    let machineName: String
    let path: String
    let isCurrent: Bool
    let pathExists: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Current machine indicator
            if isCurrent {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.blue)
                    .frame(width: 16)
            } else {
                Spacer()
                    .frame(width: 16)
            }

            // Machine name
            Text(machineName)
                .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .frame(width: 90, alignment: .leading)

            // Path
            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(pathExists ? Color.primary : Color.red)
                .lineLimit(1)
                .truncationMode(.middle)

            // Warning for non-existent paths
            if !pathExists {
                Text("\u{26a0}\u{fe0f}")
                    .font(.system(size: 10))
                    .help("Path does not exist on this machine")
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isCurrent ? Color.blue.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
