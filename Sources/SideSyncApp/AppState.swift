import SwiftUI
import SideSyncLib

/// Central state management for the SideSync GUI.
@Observable
class AppState {
    var localFavorites: [SidebarFavorite] = []
    var cloud: CloudFavorites?
    var config: LocalConfig
    var machineId: String
    var selectedCloudFavorite: CloudFavorite?

    // Status
    var statusMessage: String?
    var isLoading: Bool = false
    var errorMessage: String?

    // Sheet state
    var showDeleteConfirm: Bool = false
    var showSaveBeforeApply: Bool = false
    var pendingApplyFavorite: CloudFavorite?
    var pendingDeleteFavorite: CloudFavorite?

    // Snapshot UI
    var selectedSnapshot: SidebarSnapshot?
    var showSaveSnapshotSheet: Bool = false
    var showApplySnapshotConfirm: Bool = false
    var pendingApplySnapshot: SidebarSnapshot?
    /// When set, the save sheet replaces the sidebar with this snapshot after saving.
    var pendingApplyAfterSave: SidebarSnapshot?

    // Pending working draft + selection
    var selectedPendingItemId: String?
    var showResetPendingConfirm: Bool = false
    var showDeletePendingConfirm: Bool = false
    var showApplyPendingConfirm: Bool = false

    // Snapshot drawer + Edit pane source tracking
    enum EditSource { case none, pending, library }
    var editPaneSource: EditSource = .none
    var showSnapshotDrawer: Bool = false
    /// Snapshot currently being previewed/applied in the drawer.
    var drawerSnapshotId: String?
    /// Machine currently selected in the drawer's left column.
    var drawerMachineId: String?

    // Role change confirmation
    var showRoleChangeConfirm: Bool = false
    var pendingRole: SyncRole?

    // Machine browser
    var showMachinesBrowser: Bool = false

    // Apply All / Apply Set
    var showApplyAllConfirm: Bool = false
    var showApplySetSheet: Bool = false

    // Services
    let sidebarService: SidebarService?
    let cloudService: CloudService
    let configService: ConfigService

    init() {
        self.configService = ConfigService()
        self.cloudService = CloudService()
        self.config = configService.read()
        self.machineId = configService.getMachineId()

        // SidebarService can fail if API unavailable
        self.sidebarService = try? SidebarService()

        refresh()
        autoImportCurrentToLibrary()

        // First-run init: seed pending from Current if it's empty.
        if config.pending.isEmpty && !localFavorites.isEmpty {
            resetPendingToCurrent()
        }
    }

    // MARK: - Actions

    /// Reload everything from disk.
    func refresh() {
        isLoading = true
        defer { isLoading = false }

        // Reload config
        config = configService.read()
        machineId = configService.getMachineId()

        // Reload local favorites
        if let sidebar = sidebarService {
            localFavorites = (try? sidebar.readFavorites()) ?? []
        }

        // Reload cloud
        cloud = try? cloudService.read()

        // Update selected favorite if it still exists
        if let selected = selectedCloudFavorite,
           let updated = cloud?.favorites.first(where: { $0.id == selected.id }) {
            selectedCloudFavorite = updated
        } else {
            selectedCloudFavorite = nil
        }
    }

    /// Push current sidebar to cloud.
    func pushToCloud() {
        guard config.role != .satellite else {
            errorMessage = "Satellite machines can't push. Change role first."
            return
        }

        guard let sidebar = sidebarService else {
            errorMessage = "Sidebar API unavailable."
            return
        }

        do {
            let localFavs = try sidebar.readFavorites()
            var cloudData = cloud ?? CloudFavorites(
                lastUpdatedBy: machineId,
                lastUpdatedAt: Date(),
                primaryMachine: config.role == .primary ? machineId : nil,
                favorites: []
            )

            var added = 0
            var updated = 0

            for (i, local) in localFavs.enumerated() {
                if config.role == .indie, config.localOnlyFavorites.contains(local.name) {
                    continue
                }

                if let matchIndex = cloudData.favorites.firstIndex(where: {
                    PathResolver.findCloudMatch(for: local, in: [$0]) != nil
                }) {
                    let existing = cloudData.favorites[matchIndex].paths[machineId]
                    cloudData.favorites[matchIndex].paths[machineId] = local.path
                    if cloudData.favorites[matchIndex].pathHints.isEmpty {
                        cloudData.favorites[matchIndex].pathHints =
                            CloudFavorite.buildPathHints(from: local.path)
                    }
                    if existing != local.path { updated += 1 }
                } else {
                    let cloudFav = CloudFavorite(
                        id: UUID().uuidString,
                        name: local.name,
                        pathHints: CloudFavorite.buildPathHints(from: local.path),
                        order: i,
                        paths: [machineId: local.path]
                    )
                    cloudData.favorites.append(cloudFav)
                    added += 1
                }
            }

            if config.role == .primary {
                cloudData.primaryMachine = machineId
            }
            cloudData.lastUpdatedBy = machineId
            cloudData.lastUpdatedAt = Date()

            // Save a sidebar snapshot for this machine
            let now = Date()
            let snapshot = SidebarSnapshot(
                machineId: machineId,
                timestamp: now,
                name: AppState.defaultSnapshotName(machineId: machineId, date: now),
                items: localFavs.map { SnapshotItem(name: $0.name, path: $0.path) }
            )
            var machineSnapshots = cloudData.snapshots ?? [:]
            var history = machineSnapshots[machineId] ?? []
            history.append(snapshot)
            machineSnapshots[machineId] = history
            cloudData.snapshots = machineSnapshots

            try cloudService.write(cloudData)
            statusMessage = "Pushed \(added) new, \(updated) updated"
            refresh()
        } catch {
            errorMessage = "Push failed: \(error.localizedDescription)"
        }
    }

    /// Build a default snapshot name from machine + date.
    static func defaultSnapshotName(machineId: String, date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(machineId) — \(fmt.string(from: date))"
    }

    /// Capture the current Finder sidebar as a named snapshot in the cloud.
    func saveSnapshot(name: String) {
        guard let sidebar = sidebarService else {
            errorMessage = "Sidebar API unavailable."
            return
        }

        do {
            let localFavs = try sidebar.readFavorites()
            var cloudData = cloud ?? CloudFavorites(
                lastUpdatedBy: machineId,
                lastUpdatedAt: Date(),
                primaryMachine: nil,
                favorites: []
            )

            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = trimmed.isEmpty
                ? AppState.defaultSnapshotName(machineId: machineId, date: Date())
                : trimmed

            let snapshot = SidebarSnapshot(
                machineId: machineId,
                timestamp: Date(),
                name: finalName,
                items: localFavs.map { SnapshotItem(name: $0.name, path: $0.path) }
            )

            var machineSnapshots = cloudData.snapshots ?? [:]
            var history = machineSnapshots[machineId] ?? []
            history.append(snapshot)
            machineSnapshots[machineId] = history
            cloudData.snapshots = machineSnapshots
            cloudData.lastUpdatedBy = machineId
            cloudData.lastUpdatedAt = Date()

            try cloudService.write(cloudData)
            statusMessage = "Saved snapshot \"\(finalName)\""
            refresh()
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    /// All snapshots across machines, newest first.
    var allSnapshots: [SidebarSnapshot] {
        guard let bucket = cloud?.snapshots else { return [] }
        return bucket.values.flatMap { $0 }.sorted { $0.timestamp > $1.timestamp }
    }

    /// Replace the entire Finder sidebar with the items from this snapshot.
    func replaceSidebar(with snapshot: SidebarSnapshot) {
        guard let sidebar = sidebarService else {
            errorMessage = "Sidebar API unavailable."
            return
        }

        do {
            try sidebar.removeAllFavorites()
        } catch {
            errorMessage = "Failed to clear sidebar: \(error.localizedDescription)"
            return
        }

        var applied = 0
        var skipped = 0
        let currentHome = FileManager.default.homeDirectoryForCurrentUser.path
        let currentUser = URL(fileURLWithPath: currentHome).lastPathComponent

        for item in snapshot.items {
            let resolved: String?
            if PathResolver.exists(item.path) {
                resolved = item.path
            } else {
                let components = URL(fileURLWithPath: item.path).pathComponents
                if components.count >= 3, components[1] == "Users", components[2] != currentUser {
                    var newComponents = components
                    newComponents[2] = currentUser
                    let candidate = newComponents.joined(separator: "/")
                        .replacingOccurrences(of: "//", with: "/")
                    resolved = PathResolver.exists(candidate) ? candidate : nil
                } else {
                    resolved = nil
                }
            }

            guard let localPath = resolved else {
                skipped += 1
                continue
            }

            do {
                if try sidebar.addFavorite(name: item.name, path: localPath) {
                    applied += 1
                }
            } catch {
                skipped += 1
            }
        }

        statusMessage = "Applied \"\(snapshot.name)\": \(applied) items\(skipped > 0 ? " (\(skipped) skipped)" : "")"
        refresh()
    }

    // MARK: - Pending sidebar (working draft)

    /// Current pending items, sourced from LocalConfig so they survive restarts.
    var pending: [PendingItem] {
        get { config.pending }
        set {
            config.pending = newValue
            try? configService.write(config)
        }
    }

    /// Replace pending with the live Finder sidebar contents (items are independent).
    func resetPendingToCurrent() {
        let mapped = localFavorites.map {
            PendingItem(name: $0.name, path: $0.path, libraryItemId: nil)
        }
        pending = mapped
        selectedPendingItemId = nil
        statusMessage = "Reset pending to current sidebar (\(mapped.count) items)"
    }

    /// Empty the pending draft.
    func clearPending() {
        pending = []
        selectedPendingItemId = nil
        statusMessage = "Cleared pending"
    }

    /// Currently selected pending item (if any).
    var selectedPendingItem: PendingItem? {
        guard let id = selectedPendingItemId else { return nil }
        return pending.first(where: { $0.id == id })
    }

    // MARK: - Library

    /// Library items, ordered for display.
    var libraryItems: [CloudFavorite] {
        (cloud?.favorites ?? []).sorted { $0.order < $1.order }
    }

    /// Find a library item whose path's last component matches the given path.
    func libraryItem(matchingPath path: String) -> CloudFavorite? {
        let key = libraryDedupKey(forPath: path)
        return cloud?.favorites.first { fav in
            if let myPath = fav.paths[machineId] {
                return libraryDedupKey(forPath: myPath) == key
            }
            return fav.pathHints.last.map { $0.lowercased() } == key
        }
    }

    /// On launch, copy any Current items into Library that aren't there yet and aren't ignored.
    func autoImportCurrentToLibrary() {
        guard !localFavorites.isEmpty else { return }
        var cloudData = cloud ?? CloudFavorites(
            lastUpdatedBy: machineId,
            lastUpdatedAt: Date(),
            favorites: []
        )

        var added = 0
        for (i, local) in localFavorites.enumerated() {
            let key = libraryDedupKey(forPath: local.path)
            if config.ignoredLibraryKeys.contains(key) { continue }
            if cloudData.favorites.contains(where: { fav in
                let favKey = libraryDedupKey(forPath: fav.paths[machineId] ?? "")
                return favKey == key || fav.pathHints.last?.lowercased() == key
            }) {
                continue
            }
            let nextOrder = (cloudData.favorites.map(\.order).max() ?? -1) + 1 + i
            let item = CloudFavorite(
                id: UUID().uuidString,
                name: local.name,
                pathHints: CloudFavorite.buildPathHints(from: local.path),
                order: nextOrder,
                paths: [machineId: local.path]
            )
            cloudData.favorites.append(item)
            added += 1
        }

        if added > 0 {
            cloudData.lastUpdatedBy = machineId
            cloudData.lastUpdatedAt = Date()
            try? cloudService.write(cloudData)
            cloud = cloudData
        }
    }

    /// Remove an item from the Library and remember the dedup key so auto-import skips it.
    func removeFromLibrary(_ favorite: CloudFavorite) {
        guard var cloudData = cloud else { return }
        cloudData.favorites.removeAll { $0.id == favorite.id }
        cloudData.lastUpdatedBy = machineId
        cloudData.lastUpdatedAt = Date()

        let key: String
        if let p = favorite.paths[machineId] {
            key = libraryDedupKey(forPath: p)
        } else if let hint = favorite.pathHints.last {
            key = hint.lowercased()
        } else {
            key = favorite.name.lowercased()
        }
        config.ignoredLibraryKeys.insert(key)

        do {
            try cloudService.write(cloudData)
            try configService.write(config)
            statusMessage = "Removed \"\(favorite.name)\" from Library"
            refresh()
        } catch {
            errorMessage = "Failed to remove: \(error.localizedDescription)"
        }
    }

    // MARK: - Snapshot drawer actions

    /// Replace pending with the contents of a snapshot (no Finder write).
    func loadSnapshotIntoPending(_ snapshot: SidebarSnapshot) {
        let mapped = snapshot.items.map { item -> PendingItem in
            // Link to library if a match exists by trailing path component.
            let linkedId = libraryItem(matchingPath: item.path)?.id
            return PendingItem(
                name: item.name,
                path: item.path,
                libraryItemId: linkedId
            )
        }
        pending = mapped
        selectedPendingItemId = nil
        editPaneSource = .none
        statusMessage = "Loaded \"\(snapshot.name)\" into pending (\(mapped.count) items)"
    }

    /// Add any snapshot items not already in Library to Library (by dedup key).
    func saveSnapshotUniquesToLibrary(_ snapshot: SidebarSnapshot) {
        var cloudData = cloud ?? CloudFavorites(
            lastUpdatedBy: machineId,
            lastUpdatedAt: Date(),
            favorites: []
        )

        var added = 0
        let nextBaseOrder = (cloudData.favorites.map(\.order).max() ?? -1) + 1
        for (offset, item) in snapshot.items.enumerated() {
            let key = libraryDedupKey(forPath: item.path)
            if config.ignoredLibraryKeys.contains(key) { continue }
            if cloudData.favorites.contains(where: { fav in
                let favKey = libraryDedupKey(forPath: fav.paths[machineId] ?? "")
                return favKey == key || fav.pathHints.last?.lowercased() == key
            }) {
                continue
            }
            let fav = CloudFavorite(
                id: UUID().uuidString,
                name: item.name,
                pathHints: CloudFavorite.buildPathHints(from: item.path),
                order: nextBaseOrder + offset,
                paths: [snapshot.machineId: item.path]
            )
            cloudData.favorites.append(fav)
            added += 1
        }

        if added > 0 {
            cloudData.lastUpdatedBy = machineId
            cloudData.lastUpdatedAt = Date()
            do {
                try cloudService.write(cloudData)
                statusMessage = "Saved \(added) unique item\(added == 1 ? "" : "s") to Library"
                refresh()
            } catch {
                errorMessage = "Failed to save uniques: \(error.localizedDescription)"
            }
        } else {
            statusMessage = "No new items to save — all already in Library"
        }
    }

    /// Delete a specific snapshot from history.
    func deleteSnapshot(_ snapshot: SidebarSnapshot) {
        guard var cloudData = cloud else { return }

        var machineSnapshots = cloudData.snapshots ?? [:]
        if var history = machineSnapshots[snapshot.machineId] {
            history.removeAll { $0.id == snapshot.id }
            machineSnapshots[snapshot.machineId] = history.isEmpty ? nil : history
            cloudData.snapshots = machineSnapshots.isEmpty ? nil : machineSnapshots
            cloudData.lastUpdatedBy = machineId
            cloudData.lastUpdatedAt = Date()

            do {
                try cloudService.write(cloudData)
                statusMessage = "Deleted snapshot"
                refresh()
            } catch {
                errorMessage = "Failed to delete snapshot: \(error.localizedDescription)"
            }
        }
    }

    /// Apply a snapshot from another machine (or a historical one) to the current sidebar.
    func applySnapshot(_ snapshot: SidebarSnapshot) {
        guard let sidebar = sidebarService else {
            errorMessage = "Sidebar API unavailable."
            return
        }

        var applied = 0
        var skipped = 0

        for item in snapshot.items {
            // Resolve the path for this machine
            let localPath: String
            if PathResolver.exists(item.path) {
                localPath = item.path
            } else {
                // Try auto-detecting with username substitution
                let currentHome = FileManager.default.homeDirectoryForCurrentUser.path
                let currentUser = URL(fileURLWithPath: currentHome).lastPathComponent
                let components = URL(fileURLWithPath: item.path).pathComponents
                if components.count >= 3, components[1] == "Users", components[2] != currentUser {
                    var newComponents = components
                    newComponents[2] = currentUser
                    let candidate = newComponents.joined(separator: "/")
                        .replacingOccurrences(of: "//", with: "/")
                    if PathResolver.exists(candidate) {
                        localPath = candidate
                    } else {
                        skipped += 1
                        continue
                    }
                } else {
                    skipped += 1
                    continue
                }
            }

            // Skip if already in sidebar
            if localFavorites.contains(where: { $0.name == item.name }) {
                continue
            }

            do {
                if try sidebar.addFavorite(name: item.name, path: localPath) {
                    applied += 1
                }
            } catch {
                skipped += 1
            }
        }

        statusMessage = "Applied \(applied) favorites\(skipped > 0 ? " (\(skipped) skipped — paths not found)" : "")"
        refresh()
    }

    /// Apply a single cloud favorite to the Finder sidebar, preserving cloud order.
    func applyFavorite(_ favorite: CloudFavorite) {
        guard let sidebar = sidebarService else {
            errorMessage = "Sidebar API unavailable."
            return
        }

        do {
            if let localPath = PathResolver.resolveLocalPath(
                for: favorite, machineId: machineId, config: config
            ) {
                // Find the preceding cloud favorite that's already in the sidebar
                // so we can insert after it to preserve ordering
                let afterName = findPrecedingSidebarItem(for: favorite)

                if try sidebar.addFavorite(name: favorite.name, path: localPath, afterName: afterName) {
                    statusMessage = "Added \"\(favorite.name)\" to sidebar"
                    refresh()
                }
            } else {
                errorMessage = "No valid local path for \"\(favorite.name)\""
            }
        } catch {
            errorMessage = "Failed to add: \(error.localizedDescription)"
        }
    }

    /// Find the name of the sidebar item that should precede this favorite
    /// based on cloud ordering. Returns nil to insert at the end if no match.
    private func findPrecedingSidebarItem(for favorite: CloudFavorite) -> String? {
        guard let cloudFavs = cloud?.favorites else { return nil }

        let sorted = cloudFavs.sorted { $0.order < $1.order }
        guard let targetIndex = sorted.firstIndex(where: { $0.id == favorite.id }) else {
            return nil
        }

        // Walk backwards from the target to find the nearest preceding cloud
        // favorite that exists in the local sidebar
        let localNames = Set(localFavorites.map(\.name))
        for i in stride(from: targetIndex - 1, through: 0, by: -1) {
            let preceding = sorted[i]
            if localNames.contains(preceding.name) {
                return preceding.name
            }
        }

        return nil
    }

    // MARK: - Apply All / Apply Set

    /// Cloud favorites that have valid local paths but aren't yet in the sidebar.
    var unappliedFavorites: [CloudFavorite] {
        guard let cloudFavs = cloud?.favorites else { return [] }
        return cloudFavs
            .sorted { $0.order < $1.order }
            .filter { fav in
                let s = status(for: fav)
                return s == .available
            }
    }

    /// Whether the local sidebar differs from the cloud set (content or order).
    var sidebarDiffersFromCloud: Bool {
        guard let cloudFavs = cloud?.favorites else { return false }
        let cloudSorted = cloudFavs.sorted { $0.order < $1.order }

        // Build the expected local names in cloud order (only those with valid paths)
        let expectedNames = cloudSorted.compactMap { fav -> String? in
            guard !config.hiddenFavorites.contains(fav.id) else { return nil }
            guard PathResolver.resolveLocalPath(for: fav, machineId: machineId, config: config) != nil else { return nil }
            return fav.name
        }

        let localNames = localFavorites.map(\.name)

        return localNames != expectedNames
    }

    /// Apply all unapplied cloud favorites that have valid local paths.
    func applyAll() {
        guard let sidebar = sidebarService else {
            errorMessage = "Sidebar API unavailable."
            return
        }

        let toApply = unappliedFavorites
        var applied = 0
        var failed = 0

        for fav in toApply {
            if let localPath = PathResolver.resolveLocalPath(
                for: fav, machineId: machineId, config: config
            ) {
                do {
                    if try sidebar.addFavorite(name: fav.name, path: localPath) {
                        applied += 1
                    }
                } catch {
                    failed += 1
                }
            }
        }

        statusMessage = "Applied \(applied) favorites\(failed > 0 ? " (\(failed) failed)" : "")"
        refresh()
    }

    /// Replace the entire sidebar with a selected set of cloud favorites in order.
    /// - Parameter selectedIds: ordered list of cloud favorite IDs to include
    func applySelectedSet(_ selectedIds: [String]) {
        guard let sidebar = sidebarService else {
            errorMessage = "Sidebar API unavailable."
            return
        }
        guard let cloudFavs = cloud?.favorites else { return }

        // Build ordered list of favorites matching the selection
        let favsById = Dictionary(uniqueKeysWithValues: cloudFavs.map { ($0.id, $0) })
        let ordered = selectedIds.compactMap { favsById[$0] }

        // Remove all current sidebar items
        do {
            try sidebar.removeAllFavorites()
        } catch {
            errorMessage = "Failed to clear sidebar: \(error.localizedDescription)"
            return
        }

        // Re-add in the specified order
        var applied = 0
        var skipped = 0

        for fav in ordered {
            if let localPath = PathResolver.resolveLocalPath(
                for: fav, machineId: machineId, config: config
            ) {
                do {
                    if try sidebar.addFavorite(name: fav.name, path: localPath) {
                        applied += 1
                    }
                } catch {
                    skipped += 1
                }
            } else {
                skipped += 1
            }
        }

        statusMessage = "Sidebar replaced: \(applied) favorites applied\(skipped > 0 ? " (\(skipped) skipped)" : "")"
        refresh()
    }

    /// Save a named set of favorites to the cloud.
    func saveSet(name: String, favoriteIds: [String]) {
        guard var cloudData = cloud else { return }

        let newSet = FavoriteSet(
            name: name,
            createdBy: machineId,
            createdAt: Date(),
            favoriteIds: favoriteIds
        )

        var sets = cloudData.sets ?? []
        sets.append(newSet)
        cloudData.sets = sets
        cloudData.lastUpdatedBy = machineId
        cloudData.lastUpdatedAt = Date()

        do {
            try cloudService.write(cloudData)
            statusMessage = "Saved set \"\(name)\" (\(favoriteIds.count) favorites)"
            refresh()
        } catch {
            errorMessage = "Failed to save set: \(error.localizedDescription)"
        }
    }

    /// Delete a saved set.
    func deleteSet(_ set: FavoriteSet) {
        guard var cloudData = cloud else { return }

        var sets = cloudData.sets ?? []
        sets.removeAll { $0.id == set.id }
        cloudData.sets = sets.isEmpty ? nil : sets
        cloudData.lastUpdatedBy = machineId
        cloudData.lastUpdatedAt = Date()

        do {
            try cloudService.write(cloudData)
            statusMessage = "Deleted set \"\(set.name)\""
            refresh()
        } catch {
            errorMessage = "Failed to delete set: \(error.localizedDescription)"
        }
    }

    /// Remove a cloud favorite permanently.
    func deleteFavorite(_ favorite: CloudFavorite) {
        guard var cloudData = cloud else { return }

        cloudData.favorites.removeAll { $0.id == favorite.id }
        cloudData.lastUpdatedBy = machineId
        cloudData.lastUpdatedAt = Date()

        do {
            try cloudService.write(cloudData)
            statusMessage = "Removed \"\(favorite.name)\" from cloud"
            if selectedCloudFavorite?.id == favorite.id {
                selectedCloudFavorite = nil
            }
            refresh()
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    /// Hide a favorite on this machine.
    func hideFavorite(_ favorite: CloudFavorite) {
        if !config.hiddenFavorites.contains(favorite.id) {
            config.hiddenFavorites.append(favorite.id)
            do {
                try configService.write(config)
                statusMessage = "Hidden \"\(favorite.name)\" on this machine"
                refresh()
            } catch {
                errorMessage = "Failed to hide: \(error.localizedDescription)"
            }
        }
    }

    /// Unhide a favorite on this machine.
    func unhideFavorite(_ favorite: CloudFavorite) {
        if let idx = config.hiddenFavorites.firstIndex(of: favorite.id) {
            config.hiddenFavorites.remove(at: idx)
            do {
                try configService.write(config)
                statusMessage = "Unhidden \"\(favorite.name)\""
                refresh()
            } catch {
                errorMessage = "Failed to unhide: \(error.localizedDescription)"
            }
        }
    }

    /// Update this machine's path for a cloud favorite.
    func updatePath(for favorite: CloudFavorite, path: String) {
        guard var cloudData = cloud else { return }

        if let idx = cloudData.favorites.firstIndex(where: { $0.id == favorite.id }) {
            cloudData.favorites[idx].paths[machineId] = path
            cloudData.lastUpdatedBy = machineId
            cloudData.lastUpdatedAt = Date()

            do {
                try cloudService.write(cloudData)
                statusMessage = "Updated path for \"\(favorite.name)\""
                refresh()
            } catch {
                errorMessage = "Failed to update path: \(error.localizedDescription)"
            }
        }
    }

    /// Change sync role with confirmation.
    func setRole(_ newRole: SyncRole) {
        let oldRole = config.role
        config.role = newRole

        do {
            try configService.write(config)

            if newRole == .primary {
                if var cloudData = cloud {
                    cloudData.primaryMachine = machineId
                    try cloudService.write(cloudData)
                }
            }

            statusMessage = "Role changed: \(oldRole.rawValue) \u{2192} \(newRole.rawValue)"
            refresh()
        } catch {
            errorMessage = "Failed to change role: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed

    /// Status for a cloud favorite on this machine.
    func status(for favorite: CloudFavorite) -> FavoriteStatus {
        if config.hiddenFavorites.contains(favorite.id) {
            return .hidden
        }
        if PathResolver.findLocalMatch(for: favorite, in: localFavorites) != nil {
            return .synced
        }
        if let path = PathResolver.resolveLocalPath(
            for: favorite, machineId: machineId, config: config
        ) {
            return PathResolver.exists(path) ? .available : .pathNotFound
        }
        return .noPath
    }

    /// Suggest a local path for a cloud favorite by auto-detecting username differences.
    /// Returns nil if no suggestion or if this machine already has a valid path.
    func suggestedPath(for favorite: CloudFavorite) -> String? {
        // Don't suggest if this machine already has a working path
        if let existing = favorite.paths[machineId], PathResolver.exists(existing) {
            return nil
        }
        return PathResolver.suggestLocalPath(for: favorite, machineId: machineId)
    }

    /// All known machine names from cloud data.
    var knownMachines: [String] {
        guard let cloudData = cloud else { return [] }
        var machines = Set<String>()
        for fav in cloudData.favorites {
            for machine in fav.paths.keys {
                machines.insert(machine)
            }
        }
        if let snaps = cloudData.snapshots {
            for machine in snaps.keys {
                machines.insert(machine)
            }
        }
        return machines.sorted()
    }

    /// Get the latest snapshot for a machine, if any.
    func latestSnapshot(for machine: String) -> SidebarSnapshot? {
        cloud?.snapshots?[machine]?.sorted(by: { $0.timestamp > $1.timestamp }).first
    }

    /// Get all snapshots for a machine, newest first.
    func snapshotsForMachine(_ machine: String) -> [SidebarSnapshot] {
        (cloud?.snapshots?[machine] ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    /// Check if a local favorite is synced to cloud.
    func isLocalSynced(_ local: SidebarFavorite) -> Bool {
        guard let cloudFavs = cloud?.favorites else { return false }
        return PathResolver.findCloudMatch(for: local, in: cloudFavs) != nil
    }
}

enum FavoriteStatus {
    case synced       // In local sidebar
    case available    // Path exists but not in sidebar
    case hidden       // Hidden on this machine
    case pathNotFound // Has a path mapping but path doesn't exist
    case noPath       // No path for this machine
    case localOnly    // Indie mode local-only

    var icon: String {
        switch self {
        case .synced: return "\u{2705}"
        case .available: return "\u{1f7e1}"
        case .hidden: return "\u{1f6ab}"
        case .pathNotFound: return "\u{274c}"
        case .noPath: return "\u{2753}"
        case .localOnly: return "\u{1f4cc}"
        }
    }

    var label: String {
        switch self {
        case .synced: return "Synced"
        case .available: return "Available"
        case .hidden: return "Hidden"
        case .pathNotFound: return "Path not found"
        case .noPath: return "No path"
        case .localOnly: return "Local only"
        }
    }
}
