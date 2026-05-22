import SwiftUI
import SideSyncLib

/// Sheet that prompts the user to name the current sidebar before saving it as a snapshot.
struct SaveSnapshotSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    /// Optional follow-on action — when set, fires after saving (used by Save & Replace flow).
    let onSaved: (() -> Void)?

    @State private var name: String = ""
    @FocusState private var focused: Bool

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Sidebar Snapshot")
                        .font(.headline)
                    Text("Capture the current Finder sidebar so you can apply it later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Snapshot name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(save)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            name = AppState.defaultSnapshotName(machineId: state.machineId, date: Date())
            focused = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.saveSnapshot(name: trimmed)
        dismiss()
        onSaved?()
    }
}
