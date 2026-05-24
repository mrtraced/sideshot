import Foundation

/// Reads and writes the cloud favorites JSON file.
/// By default lives in iCloud Drive's SideSync folder; users can override
/// the directory via Settings, in which case the override path is passed in.
public final class CloudService {
    /// Default directory in iCloud Drive.
    public static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/SideSync")

    /// Effective directory currently in use.
    public private(set) var directory: URL
    /// Effective file URL (directory + "favorites.json").
    public var cloudFile: URL { directory.appendingPathComponent("favorites.json") }

    /// Backwards-compat: callers that hardcoded the old static path.
    public static var cloudDirectory: URL { defaultDirectory }
    public static var cloudFile: URL { defaultDirectory.appendingPathComponent("favorites.json") }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory
    }

    /// Switch the active directory. Doesn't move existing files — use migrate(to:) for that.
    public func setDirectory(_ url: URL) {
        self.directory = url
    }

    /// Move favorites.json from the current directory to a new one and switch over.
    /// If the destination already has a file, refuses unless `overwrite` is true.
    public func migrate(to newDirectory: URL, overwrite: Bool = false) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: newDirectory.path) {
            try fm.createDirectory(at: newDirectory, withIntermediateDirectories: true)
        }
        let src = cloudFile
        let dst = newDirectory.appendingPathComponent("favorites.json")

        if fm.fileExists(atPath: src.path) {
            if fm.fileExists(atPath: dst.path) {
                if overwrite {
                    try fm.removeItem(at: dst)
                } else {
                    throw NSError(
                        domain: "SideSync.CloudService",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey:
                            "A favorites.json already exists at the destination. Remove it first or choose overwrite."
                        ]
                    )
                }
            }
            try fm.moveItem(at: src, to: dst)
        }
        self.directory = newDirectory
    }

    /// Read the cloud favorites file. Returns nil if it doesn't exist yet.
    public func read() throws -> CloudFavorites? {
        let url = cloudFile
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(CloudFavorites.self, from: data)
    }

    /// Write the cloud favorites file, creating the directory if needed.
    public func write(_ favorites: CloudFavorites) throws {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(favorites)
        try data.write(to: cloudFile, options: .atomic)
    }

    /// Permanently delete the cloud file (does not delete the directory).
    public func wipeFile() throws {
        let url = cloudFile
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Check if a cloud sync file exists at the current directory.
    public var hasCloudFile: Bool {
        FileManager.default.fileExists(atPath: cloudFile.path)
    }
}
