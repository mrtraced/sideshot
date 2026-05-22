import SwiftUI
import AppKit
import SideSyncLib

/// Right column — detail/preview for the selected cloud favorite.
struct PreviewPane: View {
    @Environment(AppState.self) private var state
    @State private var editingPath: String = ""
    @State private var isEditingPath: Bool = false
    @State private var showPathPicker: Bool = false

    var body: some View {
        if let favorite = state.selectedCloudFavorite {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(favorite)
                    Divider()
                    pathHintsSection(favorite)
                    machinePathsSection(favorite)
                    Divider()
                    actionsSection(favorite)
                }
                .padding(20)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ favorite: CloudFavorite) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                let status = state.status(for: favorite)
                HStack(spacing: 4) {
                    Text(status.icon)
                        .font(.system(size: 12))
                    Text(status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func pathHintsSection(_ favorite: CloudFavorite) -> some View {
        if !favorite.pathHints.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Path Hints")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 4) {
                    ForEach(favorite.pathHints, id: \.self) { hint in
                        Text(hint)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func machinePathsSection(_ favorite: CloudFavorite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Machine Paths")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let machines = favorite.paths.keys.sorted()
            ForEach(machines, id: \.self) { machine in
                PathRow(
                    machineName: machine,
                    path: favorite.paths[machine] ?? "",
                    isCurrent: machine == state.machineId,
                    pathExists: PathResolver.exists(favorite.paths[machine] ?? "")
                )
            }

            // Show "Set path..." if this machine doesn't have one
            if favorite.paths[state.machineId] == nil {
                setPathButton(favorite)
            }

            // Show path override if any
            if let override = state.config.pathOverrides[favorite.id] {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text("Override: \(override)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func setPathButton(_ favorite: CloudFavorite) -> some View {
        if isEditingPath {
            HStack {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                    .frame(width: 16)

                TextField("Enter local path...", text: $editingPath)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !editingPath.isEmpty {
                            state.updatePath(for: favorite, path: editingPath)
                            isEditingPath = false
                            editingPath = ""
                        }
                    }

                Button {
                    openFolderPicker(for: favorite)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Browse for folder...")

                Button("Save") {
                    if !editingPath.isEmpty {
                        state.updatePath(for: favorite, path: editingPath)
                        isEditingPath = false
                        editingPath = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Cancel") {
                    isEditingPath = false
                    editingPath = ""
                }
                .controlSize(.small)
            }
        } else {
            HStack(spacing: 8) {
                // Auto-suggested path (if detected)
                if let suggested = state.suggestedPath(for: favorite) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested path:")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(suggested)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.blue)
                    }

                    Button("Use") {
                        state.updatePath(for: favorite, path: suggested)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Accept this suggested path")
                }

                Button {
                    openFolderPicker(for: favorite)
                } label: {
                    Label("Browse for folder...", systemImage: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button {
                    isEditingPath = true
                } label: {
                    Label("Type path...", systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func openFolderPicker(for favorite: CloudFavorite) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the local folder for \"\(favorite.name)\""
        panel.prompt = "Select"

        // Start in a sensible directory based on known paths
        if let hint = favorite.paths.values.first {
            let parent = URL(fileURLWithPath: hint).deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) {
                panel.directoryURL = parent
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            state.updatePath(for: favorite, path: url.path)
        }
    }

    @ViewBuilder
    private func actionsSection(_ favorite: CloudFavorite) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let status = state.status(for: favorite)

            // Apply to Sidebar
            if status != .synced {
                Button {
                    state.pendingApplyFavorite = favorite
                    state.showSaveBeforeApply = true
                } label: {
                    Label("Apply to Sidebar", systemImage: "sidebar.leading")
                }
                .buttonStyle(.borderedProminent)
                .disabled(status == .pathNotFound || status == .noPath)
            } else {
                Label("Already in sidebar", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
            }

            // Hide/Unhide
            if state.config.hiddenFavorites.contains(favorite.id) {
                Button {
                    state.unhideFavorite(favorite)
                } label: {
                    Label("Unhide on This Machine", systemImage: "eye")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    state.hideFavorite(favorite)
                } label: {
                    Label("Hide on This Machine", systemImage: "eye.slash")
                }
                .buttonStyle(.bordered)
            }

            // Remove from Cloud
            Button(role: .destructive) {
                state.pendingDeleteFavorite = favorite
                state.showDeleteConfirm = true
            } label: {
                Label("Remove from Cloud", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("Select a cloud favorite")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Choose an item from the list to see its details.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
