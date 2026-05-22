import Foundation

/// Reads and writes the cloud favorites JSON file in iCloud Drive.
public final class CloudService {
    public static let cloudDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/SideSync")
    public static let cloudFile = cloudDirectory.appendingPathComponent("favorites.json")

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

    public init() {}

    /// Read the cloud favorites file. Returns nil if it doesn't exist yet.
    public func read() throws -> CloudFavorites? {
        let url = Self.cloudFile
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(CloudFavorites.self, from: data)
    }

    /// Write the cloud favorites file, creating the directory if needed.
    public func write(_ favorites: CloudFavorites) throws {
        let dir = Self.cloudDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(favorites)
        try data.write(to: Self.cloudFile, options: .atomic)
    }

    /// Check if a cloud sync file exists.
    public var hasCloudFile: Bool {
        FileManager.default.fileExists(atPath: Self.cloudFile.path)
    }
}
