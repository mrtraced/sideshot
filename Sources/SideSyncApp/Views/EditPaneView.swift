import SwiftUI
import SideSyncLib

/// Right-top — Edit pane for the currently-selected Pending item.
/// P1: read-only display. Name/path become editable in P2.
struct EditPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Edit Item")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if let item = state.selectedPendingItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        field(label: "Name", value: item.name)
                        field(label: "Path (this machine)", value: item.path, monospaced: true)

                        // Icon slot — deferred
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Icon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)
                                Text("Customize (coming soon)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(6)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Also on — read from cloud
                        if let linkedId = item.libraryItemId,
                           let libItem = state.cloud?.favorites.first(where: { $0.id == linkedId }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Also on")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(libItem.paths.keys.sorted(), id: \.self) { machine in
                                    HStack(spacing: 6) {
                                        Image(systemName: "laptopcomputer")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                        Text(machine)
                                            .font(.system(size: 11, weight: .medium))
                                        Text(libItem.paths[machine] ?? "")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "cursorarrow.click")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("Select a pending item to edit")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func field(label: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: monospaced ? .monospaced : .default))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}
