import Foundation

/// How this machine participates in the sync topology.
///
/// - `primary`: Authoritative source. Push and pull are two-way.
///   Changes made here propagate to all machines on next pull.
/// - `satellite`: Inherits everything from primary. Local changes are
///   overwritten on pull (one-way parent->child).
/// - `indie`: Inherits parent changes on pull, but local-only favorites
///   are preserved and never pushed to cloud. Best of both worlds.
public enum SyncRole: String, Codable, CaseIterable, Sendable {
    case primary
    case satellite
    case indie

    public var label: String {
        switch self {
        case .primary: return "primary (two-way sync)"
        case .satellite: return "satellite (one-way from primary)"
        case .indie: return "indie (inherit parent, keep local)"
        }
    }
}

/// A single item in the user's "Pending" sidebar working draft.
/// `libraryItemId` non-nil = this row is linked to a cloud Library entry;
/// nil = independent (came from Current or a snapshot, not yet saved to Library).
public struct PendingItem: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var path: String
    public var libraryItemId: String?

    public init(id: String = UUID().uuidString, name: String, path: String, libraryItemId: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.libraryItemId = libraryItemId
    }
}

/// Last meaningful path component, used as a coarse identity key for dedup
/// in the Item Library ("most people don't have multiple shortcuts to the same folder").
public func libraryDedupKey(forPath path: String) -> String {
    let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
    let comp = URL(fileURLWithPath: trimmed).lastPathComponent
    return comp.lowercased()
}

/// Machine-local configuration stored outside of iCloud.
public struct LocalConfig: Codable {
    /// Human-readable name for this machine (e.g., "MacBook-Pro")
    public var machineId: String
    /// This machine's role in the sync topology
    public var role: SyncRole
    /// IDs of favorites hidden on this machine
    public var hiddenFavorites: [String]
    /// Cloud favorite ID -> local path override
    public var pathOverrides: [String: String]
    /// IDs of favorites that are local-only (indie mode: not pushed to cloud)
    public var localOnlyFavorites: Set<String>
    /// Persistent working draft of the sidebar the user is composing.
    public var pending: [PendingItem]
    /// Library dedup keys the user has explicitly removed; auto-import will not re-add them.
    public var ignoredLibraryKeys: Set<String>

    // MARK: - User settings (with sensible defaults)

    /// Absolute path to the directory where favorites.json lives.
    /// nil = use the default iCloud Drive location.
    public var cloudSyncDirectory: String?
    /// Automatically copy Current items into Library on launch.
    public var autoImportOnLaunch: Bool
    /// Seed the standard macOS locations into Library on launch.
    public var seedDefaultsOnLaunch: Bool
    /// Write custom SF Symbol icons to folders when applying Pending → Finder.
    public var writeFinderIconsOnApply: Bool
    /// Default sort mode for the Library grid (alpha / recent / unused).
    public var defaultLibrarySort: String
    /// In the Apply Pending alert, is "Save Current & Apply" the default action?
    public var saveBeforeApplyDefault: Bool
    /// Maximum snapshots to keep per machine. 0 = no limit (default).
    /// On save, older snapshots beyond this count are pruned.
    public var maxSnapshotsPerMachine: Int

    public init(
        machineId: String = "",
        role: SyncRole = .primary,
        hiddenFavorites: [String] = [],
        pathOverrides: [String: String] = [:],
        localOnlyFavorites: Set<String> = [],
        pending: [PendingItem] = [],
        ignoredLibraryKeys: Set<String> = [],
        cloudSyncDirectory: String? = nil,
        autoImportOnLaunch: Bool = true,
        seedDefaultsOnLaunch: Bool = true,
        writeFinderIconsOnApply: Bool = true,
        defaultLibrarySort: String = "alpha",
        saveBeforeApplyDefault: Bool = true,
        maxSnapshotsPerMachine: Int = 0
    ) {
        self.machineId = machineId
        self.role = role
        self.hiddenFavorites = hiddenFavorites
        self.pathOverrides = pathOverrides
        self.localOnlyFavorites = localOnlyFavorites
        self.pending = pending
        self.ignoredLibraryKeys = ignoredLibraryKeys
        self.cloudSyncDirectory = cloudSyncDirectory
        self.autoImportOnLaunch = autoImportOnLaunch
        self.seedDefaultsOnLaunch = seedDefaultsOnLaunch
        self.writeFinderIconsOnApply = writeFinderIconsOnApply
        self.defaultLibrarySort = defaultLibrarySort
        self.saveBeforeApplyDefault = saveBeforeApplyDefault
        self.maxSnapshotsPerMachine = maxSnapshotsPerMachine
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.machineId = try c.decodeIfPresent(String.self, forKey: .machineId) ?? ""
        self.role = try c.decodeIfPresent(SyncRole.self, forKey: .role) ?? .primary
        self.hiddenFavorites = try c.decodeIfPresent([String].self, forKey: .hiddenFavorites) ?? []
        self.pathOverrides = try c.decodeIfPresent([String: String].self, forKey: .pathOverrides) ?? [:]
        self.localOnlyFavorites = try c.decodeIfPresent(Set<String>.self, forKey: .localOnlyFavorites) ?? []
        self.pending = try c.decodeIfPresent([PendingItem].self, forKey: .pending) ?? []
        self.ignoredLibraryKeys = try c.decodeIfPresent(Set<String>.self, forKey: .ignoredLibraryKeys) ?? []
        self.cloudSyncDirectory = try c.decodeIfPresent(String.self, forKey: .cloudSyncDirectory)
        self.autoImportOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .autoImportOnLaunch) ?? true
        self.seedDefaultsOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .seedDefaultsOnLaunch) ?? true
        self.writeFinderIconsOnApply = try c.decodeIfPresent(Bool.self, forKey: .writeFinderIconsOnApply) ?? true
        self.defaultLibrarySort = try c.decodeIfPresent(String.self, forKey: .defaultLibrarySort) ?? "alpha"
        self.saveBeforeApplyDefault = try c.decodeIfPresent(Bool.self, forKey: .saveBeforeApplyDefault) ?? true
        self.maxSnapshotsPerMachine = try c.decodeIfPresent(Int.self, forKey: .maxSnapshotsPerMachine) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case machineId, role, hiddenFavorites, pathOverrides, localOnlyFavorites, pending, ignoredLibraryKeys
        case cloudSyncDirectory, autoImportOnLaunch, seedDefaultsOnLaunch, writeFinderIconsOnApply
        case defaultLibrarySort, saveBeforeApplyDefault, maxSnapshotsPerMachine
    }

    public static let defaultConfig = LocalConfig()
}
