import Foundation

/// The top-level structure synced via iCloud Drive.
public struct CloudFavorites: Codable {
    public var version: Int = 1
    public var lastUpdatedBy: String
    public var lastUpdatedAt: Date
    /// The machine designated as the authoritative primary (if any).
    public var primaryMachine: String?
    public var favorites: [CloudFavorite]
    /// Per-machine sidebar snapshots (history). Key = machine name.
    public var snapshots: [String: [SidebarSnapshot]]?
    /// Named sidebar presets (saved sets of favorites in a specific order).
    public var sets: [FavoriteSet]?

    public init(
        version: Int = 1,
        lastUpdatedBy: String,
        lastUpdatedAt: Date,
        primaryMachine: String? = nil,
        favorites: [CloudFavorite],
        snapshots: [String: [SidebarSnapshot]]? = nil,
        sets: [FavoriteSet]? = nil
    ) {
        self.version = version
        self.lastUpdatedBy = lastUpdatedBy
        self.lastUpdatedAt = lastUpdatedAt
        self.primaryMachine = primaryMachine
        self.favorites = favorites
        self.snapshots = snapshots
        self.sets = sets
    }
}

/// A named sidebar preset — an ordered selection of cloud favorite IDs.
public struct FavoriteSet: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var createdBy: String
    public var createdAt: Date
    /// Ordered list of cloud favorite IDs in this set.
    public var favoriteIds: [String]

    public init(name: String, createdBy: String, createdAt: Date, favoriteIds: [String]) {
        self.id = UUID().uuidString
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.favoriteIds = favoriteIds
    }
}

/// A timestamped snapshot of a machine's sidebar state.
public struct SidebarSnapshot: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var machineId: String
    public var timestamp: Date
    /// User-provided name for this snapshot. Falls back to machine + timestamp for older records.
    public var name: String
    /// Ordered list of favorite names and paths at the time of the snapshot.
    public var items: [SnapshotItem]

    public init(machineId: String, timestamp: Date, name: String, items: [SnapshotItem]) {
        self.id = UUID().uuidString
        self.machineId = machineId
        self.timestamp = timestamp
        self.name = name
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.machineId = try c.decode(String.self, forKey: .machineId)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.items = try c.decode([SnapshotItem].self, forKey: .items)
        if let decodedName = try c.decodeIfPresent(String.self, forKey: .name), !decodedName.isEmpty {
            self.name = decodedName
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
            self.name = "\(self.machineId) — \(fmt.string(from: self.timestamp))"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, machineId, timestamp, name, items
    }
}

/// A single item in a sidebar snapshot.
public struct SnapshotItem: Codable, Equatable, Hashable {
    public var name: String
    public var path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

/// A single favorite stored in the cloud, with per-machine path mappings.
public struct CloudFavorite: Codable, Identifiable, Equatable, Hashable {
    /// Stable identifier (generated once, shared across machines)
    public var id: String
    /// Display name shown in Finder sidebar
    public var name: String
    /// Last 1-2 path components for fuzzy matching across machines
    /// e.g. "/Users/alice/Projects/WebApp" -> ["Projects", "WebApp"]
    public var pathHints: [String]
    /// Sort order (0-based)
    public var order: Int
    /// Machine-name -> absolute path on that machine
    public var paths: [String: String]
    /// Soft-deleted from the Library default view. Record is preserved so the
    /// user can restore it or browse the archive; hard delete is a separate action.
    public var archived: Bool
    /// Last time this item was applied to a Finder sidebar (any machine).
    /// nil = never used. Powers the Recent / Unused sorts.
    public var lastUsedAt: Date?

    public init(
        id: String,
        name: String,
        pathHints: [String],
        order: Int,
        paths: [String: String],
        archived: Bool = false,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.pathHints = pathHints
        self.order = order
        self.paths = paths
        self.archived = archived
        self.lastUsedAt = lastUsedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.pathHints = try c.decode([String].self, forKey: .pathHints)
        self.order = try c.decode(Int.self, forKey: .order)
        self.paths = try c.decode([String: String].self, forKey: .paths)
        self.archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        self.lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, pathHints, order, paths, archived, lastUsedAt
    }

    /// Build path hints from a full path (last 2 non-trivial components).
    public static func buildPathHints(from path: String) -> [String] {
        let components = URL(fileURLWithPath: path).pathComponents
            .filter { $0 != "/" }
        // Take last 2 meaningful components
        return Array(components.suffix(2))
    }
}
