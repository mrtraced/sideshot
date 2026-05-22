import SwiftUI
import SideSyncLib

/// "Save current sidebar state first?" prompt before applying a cloud favorite.
struct SaveBeforeApplySheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    let favorite: CloudFavorite

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            Text("Apply \"\(favorite.name)\" to Sidebar")
                .font(.headline)

            Text("Would you like to save your current sidebar state to the cloud first?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Cancel") {
                    state.pendingApplyFavorite = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Skip") {
                    // Apply without saving first
                    state.applyFavorite(favorite)
                    state.pendingApplyFavorite = nil
                    dismiss()
                }

                Button("Save & Apply") {
                    // Push first, then apply
                    state.pushToCloud()
                    state.applyFavorite(favorite)
                    state.pendingApplyFavorite = nil
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}
