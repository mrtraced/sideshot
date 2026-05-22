import SwiftUI
import SideSyncLib

/// Right column — "Saved Sidebar Items": snapshots + reusable item library.
struct CloudListView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            List {
                if state.cloud == nil {
                    emptyState
                } else {
                    Section("Snapshots") {
                        if state.allSnapshots.isEmpty {
                            Text("No snapshots yet")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(state.allSnapshots) { snap in
                                SnapshotRow(snapshot: snap)
                            }
                        }
                    }

                    Section("Item Library") {
                        if let cloud = state.cloud {
                            let sorted = cloud.favorites.sorted { $0.order < $1.order }
                            if sorted.isEmpty {
                                Text("No saved items")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .italic()
                            } else {
                                ForEach(sorted) { fav in
                                    CloudFavoriteRow(favorite: fav, status: state.status(for: fav))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            state.selectedCloudFavorite = fav
                                            state.selectedSnapshot = nil
                                        }
                                        .background(
                                            state.selectedCloudFavorite?.id == fav.id
                                                ? Color.accentColor.opacity(0.15)
                                                : Color.clear
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle("Saved Sidebar Items")
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No cloud sync file")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Save your sidebar to create one.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// A row representing a saved sidebar snapshot, with inline Apply when selected.
private struct SnapshotRow: View {
    @Environment(AppState.self) private var state
    let snapshot: SidebarSnapshot

    var body: some View {
        let isSelected = state.selectedSnapshot?.id == snapshot.id

        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(snapshot.machineId)
                    Text("•")
                    Text(snapshot.timestamp, format: .dateTime.month().day().hour().minute())
                    Text("•")
                    Text("\(snapshot.items.count) items")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isSelected {
                Button {
                    state.pendingApplySnapshot = snapshot
                    state.showApplySnapshotConfirm = true
                } label: {
                    Label("Apply", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Replace the current Finder sidebar with this snapshot")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            state.selectedSnapshot = snapshot
            state.selectedCloudFavorite = nil
        }
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear
        )
    }
}
