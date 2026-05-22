import SwiftUI
import SideSyncLib

/// Top toolbar: machine name + individual action buttons.
struct SideSyncToolbar: SwiftUI.ToolbarContent {
    @Environment(AppState.self) private var state

    var body: some SwiftUI.ToolbarContent {
        // Left — machine name as plain text
        ToolbarItem(placement: .navigation) {
            Button {
                state.showMachinesBrowser = true
            } label: {
                Text(state.machineId)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .help("Browse machines and snapshot history")
        }

        // Right — individual buttons, with a spacer/divider before Apply
        ToolbarItem(placement: .primaryAction) {
            Button {
                state.showSaveSnapshotSheet = true
            } label: {
                Label("Take Snapshot", systemImage: "camera.fill")
            }
            .help("Save the current Finder sidebar as a named snapshot")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                state.showResetPendingConfirm = true
            } label: {
                Label("Reset Pending", systemImage: "arrow.counterclockwise")
            }
            .help("Replace the pending sidebar with the current Finder sidebar")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                state.showDeletePendingConfirm = true
            } label: {
                Label("Delete Pending", systemImage: "trash")
            }
            .help("Clear all items from the pending sidebar")
            .disabled(state.pending.isEmpty)
        }

        ToolbarItem(placement: .primaryAction) {
            Spacer()
        }

        ToolbarItem(placement: .primaryAction) {
            Divider()
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                state.showApplyPendingConfirm = true
            } label: {
                Label("Apply to Current Sidebar", systemImage: "square.and.arrow.down.fill")
            }
            .help("Replace the Finder sidebar with the pending draft")
            .disabled(state.pending.isEmpty)
        }
    }
}
