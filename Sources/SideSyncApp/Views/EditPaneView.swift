import SwiftUI
import AppKit
import SideSyncLib

/// Right-top — Edit pane.
/// Polymorphic: when a Pending row was last clicked, shows pending edit.
/// When a Library tile was last clicked, shows full cloud-favorite editor
/// (machine paths, set-path, hide/unhide, remove from cloud).
struct EditPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Image(systemName: "pencil")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(headerTitle)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var headerTitle: String {
        switch state.editPaneSource {
        case .pending: return "Edit Pending Item"
        case .library: return "Edit Library Item"
        case .none: return "Edit Item"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.editPaneSource {
        case .pending:
            if let item = state.selectedPendingItem {
                // Unified: if the pending item is linked to a library entry,
                // show the rich library editor (one record across views).
                if let linkedId = item.libraryItemId,
                   let lib = state.cloud?.favorites.first(where: { $0.id == linkedId }) {
                    LibraryItemEditor(favorite: lib)
                } else {
                    PendingItemEditor(item: item)
                }
            } else {
                empty
            }
        case .library:
            if let item = state.selectedCloudFavorite {
                LibraryItemEditor(favorite: item)
            } else {
                empty
            }
        case .none:
            empty
        }
    }

    @ViewBuilder
    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("Select an item to edit")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pending editor (light)

private struct PendingItemEditor: View {
    @Environment(AppState.self) private var state
    let item: PendingItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: item.libraryItemId != nil ? "link.circle.fill" : "folder.fill")
                        .foregroundStyle(item.libraryItemId != nil ? Color.accentColor : Color.blue)
                        .font(.system(size: 22))
                        .help(item.libraryItemId != nil
                              ? "Linked to a Library record — edits propagate across machines"
                              : "Independent sidebar item — not in the Library")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.libraryItemId != nil ? "Linked to Library" : "Independent (not in Library)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Divider()

                field(label: "Name", value: item.name)
                field(label: "Path (this machine)", value: item.path, monospaced: true)

                // Linked-to-library cross-machine paths
                if let linkedId = item.libraryItemId,
                   let libItem = state.cloud?.favorites.first(where: { $0.id == linkedId }) {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALSO ON")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        ForEach(libItem.paths.keys.sorted(), id: \.self) { machine in
                            HStack(spacing: 6) {
                                Image(systemName: "laptopcomputer")
                                    .font(.system(size: 10))
                                    .foregroundStyle(machine == state.machineId ? Color.green : Color.gray)
                                    .help(machine == state.machineId
                                          ? "This machine"
                                          : "Path known on \(machine)")
                                Text(machine)
                                    .font(.system(size: 11, weight: .medium))
                                Text(libItem.paths[machine] ?? "")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(libItem.paths[machine] ?? "")
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func field(label: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: monospaced ? .monospaced : .default))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Library editor (restored cloud-favorite preview)

private struct LibraryItemEditor: View {
    @Environment(AppState.self) private var state
    let favorite: CloudFavorite

    @State private var editingPath: String = ""
    @State private var isEditingPath: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerRow
                pathHintsBlock
                machinePathsBlock
                Divider()
                actionsBlock
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.name)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    if isInPending {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                            Text("In Pending")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        Text("Library only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var pathHintsBlock: some View {
        if !favorite.pathHints.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("PATH HINTS")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
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
    private var machinePathsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MACHINE PATHS")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(favorite.paths.keys.sorted(), id: \.self) { machine in
                PathRow(
                    machineName: machine,
                    path: favorite.paths[machine] ?? "",
                    isCurrent: machine == state.machineId,
                    pathExists: PathResolver.exists(favorite.paths[machine] ?? "")
                )
            }

            if favorite.paths[state.machineId] == nil {
                setPathRow
            }

            if let override = state.config.pathOverrides[favorite.id] {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                        .help("Local override — this machine uses this path instead of the shared one")
                    Text("Override: \(override)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .help(override)
                }
            }
        }
    }

    @ViewBuilder
    private var setPathRow: some View {
        if isEditingPath {
            HStack(spacing: 6) {
                TextField("Enter local path...", text: $editingPath)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commitPath)
                Button {
                    pickFolder()
                } label: { Image(systemName: "folder") }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Save", action: commitPath)
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
                if let suggested = state.suggestedPath(for: favorite) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested:")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(suggested)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                    Button("Use") {
                        state.updatePath(for: favorite, path: suggested)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                Button {
                    pickFolder()
                } label: {
                    Label("Browse…", systemImage: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                Button {
                    isEditingPath = true
                } label: {
                    Label("Type…", systemImage: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func commitPath() {
        guard !editingPath.isEmpty else { return }
        state.updatePath(for: favorite, path: editingPath)
        isEditingPath = false
        editingPath = ""
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the local folder for \"\(favorite.name)\""
        panel.prompt = "Select"
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
    private var actionsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIONS")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if isInPending {
                    Button(role: .destructive) {
                        removeFromPending()
                    } label: {
                        Label("Remove from Pending", systemImage: "minus.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        addToPending()
                    } label: {
                        Label("Add to Pending", systemImage: "plus.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if state.config.hiddenFavorites.contains(favorite.id) {
                    Button {
                        state.unhideFavorite(favorite)
                    } label: {
                        Label("Unhide", systemImage: "eye")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        state.hideFavorite(favorite)
                    } label: {
                        Label("Hide", systemImage: "eye.slash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(role: .destructive) {
                    state.removeFromLibrary(favorite)
                } label: {
                    Label("Remove from Library", systemImage: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var isInPending: Bool {
        state.isInPending(libraryItemId: favorite.id)
    }

    private func addToPending() {
        guard let path = PathResolver.resolveLocalPath(
            for: favorite, machineId: state.machineId, config: state.config
        ) ?? favorite.paths[state.machineId] else {
            state.errorMessage = "No usable local path for \"\(favorite.name)\""
            return
        }
        var newPending = state.pending
        newPending.append(PendingItem(
            name: favorite.name,
            path: path,
            libraryItemId: favorite.id
        ))
        state.pending = newPending
        state.statusMessage = "Added \"\(favorite.name)\" to pending"
    }

    private func removeFromPending() {
        var newPending = state.pending
        newPending.removeAll { $0.libraryItemId == favorite.id }
        state.pending = newPending
        if let id = state.selectedPendingItemId,
           !newPending.contains(where: { $0.id == id }) {
            state.selectedPendingItemId = nil
        }
        state.statusMessage = "Removed \"\(favorite.name)\" from pending"
    }
}
