import SwiftUI
import SideSyncLib

/// Confirm sheet for replacing the current Finder sidebar with a snapshot.
/// Two paths: "Save & Replace" (snapshot current state first) and "Replace" (destructive).
struct ApplySnapshotSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    let snapshot: SidebarSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apply Snapshot")
                        .font(.headline)
                    Text("\"\(snapshot.name)\" — \(snapshot.items.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("This replaces your current Finder sidebar. Saving first lets you return to it later.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel") {
                    state.pendingApplySnapshot = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Replace") {
                    let snap = snapshot
                    state.pendingApplySnapshot = nil
                    dismiss()
                    state.replaceSidebar(with: snap)
                }
                .buttonStyle(.bordered)

                Button("Save & Replace") {
                    let snap = snapshot
                    state.pendingApplySnapshot = nil
                    dismiss()
                    // Open the save sheet; on save, replace with the target snapshot.
                    state.showSaveSnapshotSheet = true
                    state.pendingApplyAfterSave = snap
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
