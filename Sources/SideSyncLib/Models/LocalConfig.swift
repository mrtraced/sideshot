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

    public init(
        machineId: String = "",
        role: SyncRole = .primary,
        hiddenFavorites: [String] = [],
        pathOverrides: [String: String] = [:],
        localOnlyFavorites: Set<String> = [],
        pending: [PendingItem] = [],
        ignoredLibraryKeys: Set<String> = []
    ) {
        self.machineId = machineId
        self.role = role
        self.hiddenFavorites = hiddenFavorites
        self.pathOverrides = pathOverrides
        self.localOnlyFavorites = localOnlyFavorites
        self.pending = pending
        self.ignoredLibraryKeys = ignoredLibraryKeys
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
    }

    private enum CodingKeys: String, CodingKey {
        case machineId, role, hiddenFavorites, pathOverrides, localOnlyFavorites, pending, ignoredLibraryKeys
    }

    public static let defaultConfig = LocalConfig()
}
