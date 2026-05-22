import SwiftUI
import SideSyncLib

/// Trash-can-drop style delete confirmation sheet.
struct DeleteConfirmSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    let favorite: CloudFavorite

    @State private var animateTrash = false
    @State private var animateDrop = false

    var body: some View {
        VStack(spacing: 20) {
            // Trash can animation area
            ZStack {
                // Trash can
                Image(systemName: "trash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red.opacity(0.8))
                    .offset(y: animateTrash ? 0 : -5)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: animateTrash
                    )

                // Folder dropping in
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue.opacity(animateDrop ? 0 : 0.8))
                    .offset(y: animateDrop ? 20 : -40)
                    .scaleEffect(animateDrop ? 0.3 : 1.0)
                    .animation(.easeIn(duration: 0.8), value: animateDrop)
            }
            .frame(height: 80)
            .onAppear {
                animateTrash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateDrop = true
                }
            }

            // Title
            Text("Remove \"\(favorite.name)\" from cloud?")
                .font(.headline)

            // Description
            Text("This will remove it from the cloud sync file. Other machines won't see it anymore.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Machine paths that will be lost
            if !favorite.paths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paths that will be removed:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(favorite.paths.keys.sorted(), id: \.self) { machine in
                        HStack(spacing: 4) {
                            Text(machine)
                                .font(.system(size: 11, weight: .medium))
                            Text(favorite.paths[machine] ?? "")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    state.pendingDeleteFavorite = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Remove", role: .destructive) {
                    state.deleteFavorite(favorite)
                    state.pendingDeleteFavorite = nil
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}
