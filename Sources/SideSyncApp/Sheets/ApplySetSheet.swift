import SwiftUI
import SideSyncLib

/// Sheet for selecting which favorites to include when applying a set,
/// loading saved sets, and saving new ones.
struct ApplySetSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<String> = []
    @State private var showSaveSetName: Bool = false
    @State private var saveSetName: String = ""
    @State private var showDeleteSetConfirm: Bool = false
    @State private var pendingDeleteSet: FavoriteSet?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Apply Set")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                // Left: favorites checklist
                favoritesChecklist
                    .frame(minWidth: 300, idealWidth: 380)

                Divider()

                // Right: saved sets
                savedSetsList
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
            }

            Divider()

            // Bottom action bar
            bottomBar
        }
        .frame(minWidth: 550, minHeight: 400)
        .frame(idealWidth: 650, idealHeight: 500)
        .onAppear {
            // Start with all non-hidden favorites with valid paths selected
            initializeSelection()
        }
        .alert("Delete Set", isPresented: $showDeleteSetConfirm) {
            Button("Delete", role: .destructive) {
                if let set = pendingDeleteSet {
                    state.deleteSet(set)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let set = pendingDeleteSet {
                Text("Delete the saved set \"\(set.name)\"?")
            }
        }
    }

    // MARK: - Favorites Checklist

    @ViewBuilder
    private var favoritesChecklist: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Select All / None
            HStack {
                Text("Favorites")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button("All") { selectAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                Text("/")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button("None") { selectedIds.removeAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List {
                if let cloud = state.cloud {
                    let sorted = cloud.favorites.sorted { $0.order < $1.order }
                    ForEach(sorted) { fav in
                        favoriteCheckRow(fav)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func favoriteCheckRow(_ fav: CloudFavorite) -> some View {
        let hasPath = PathResolver.resolveLocalPath(
            for: fav, machineId: state.machineId, config: state.config
        ) != nil
        let isChecked = selectedIds.contains(fav.id)

        HStack(spacing: 8) {
            // Checkbox
            Button {
                if isChecked {
                    selectedIds.remove(fav.id)
                } else {
                    selectedIds.insert(fav.id)
                }
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? .blue : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            // Folder icon
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundStyle(hasPath ? .blue : .gray)

            // Name
            Text(fav.name)
                .font(.system(size: 13))
                .foregroundStyle(hasPath ? .primary : .tertiary)

            Spacer()

            // Status indicator
            if !hasPath {
                Text("no path")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.vertical, 2)
        .opacity(hasPath ? 1 : 0.6)
    }

    // MARK: - Saved Sets

    @ViewBuilder
    private var savedSetsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Saved Sets")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            let sets = state.cloud?.sets ?? []

            if sets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                    Text("No saved sets")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Save your current selection as a named set.")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(sets) { set in
                        savedSetRow(set)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func savedSetRow(_ set: FavoriteSet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(set.name)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(set.favoriteIds.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text("by \(set.createdBy)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(set.createdAt, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                Button("Load") {
                    loadSet(set)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Load this set's selection into the checklist")

                Button("Apply") {
                    state.applySelectedSet(set.favoriteIds)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .help("Apply this saved set directly to the sidebar")

                Spacer()

                Button {
                    pendingDeleteSet = set
                    showDeleteSetConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.7))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 10) {
            // Save Set
            if showSaveSetName {
                HStack(spacing: 6) {
                    TextField("Set name...", text: $saveSetName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(maxWidth: 180)
                        .onSubmit { performSaveSet() }

                    Button("Save") { performSaveSet() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(saveSetName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Cancel") {
                        showSaveSetName = false
                        saveSetName = ""
                    }
                    .controlSize(.small)
                }
            } else {
                Button {
                    showSaveSetName = true
                } label: {
                    Label("Save Set", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedIds.isEmpty)
                .help("Save the current selection as a named set")
            }

            Spacer()

            Text("\(selectedIds.count) selected")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Apply Set
            Button {
                let orderedIds = orderedSelectedIds()
                state.applySelectedSet(orderedIds)
                dismiss()
            } label: {
                Label("Apply Set", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedIds.isEmpty)
            .help("Replace your entire sidebar with the selected favorites in cloud order")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func initializeSelection() {
        guard let cloudFavs = state.cloud?.favorites else { return }
        for fav in cloudFavs {
            if !state.config.hiddenFavorites.contains(fav.id),
               PathResolver.resolveLocalPath(for: fav, machineId: state.machineId, config: state.config) != nil {
                selectedIds.insert(fav.id)
            }
        }
    }

    private func selectAll() {
        guard let cloudFavs = state.cloud?.favorites else { return }
        for fav in cloudFavs {
            if PathResolver.resolveLocalPath(for: fav, machineId: state.machineId, config: state.config) != nil {
                selectedIds.insert(fav.id)
            }
        }
    }

    private func loadSet(_ set: FavoriteSet) {
        selectedIds = Set(set.favoriteIds)
    }

    private func orderedSelectedIds() -> [String] {
        guard let cloudFavs = state.cloud?.favorites else { return Array(selectedIds) }
        return cloudFavs
            .sorted { $0.order < $1.order }
            .filter { selectedIds.contains($0.id) }
            .map(\.id)
    }

    private func performSaveSet() {
        let name = saveSetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let orderedIds = orderedSelectedIds()
        state.saveSet(name: name, favoriteIds: orderedIds)
        showSaveSetName = false
        saveSetName = ""
    }
}
