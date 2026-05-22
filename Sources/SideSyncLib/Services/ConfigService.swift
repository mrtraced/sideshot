import Foundation

/// Reads and writes the local (non-synced) configuration file.
public final class ConfigService {
    public static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".sidesync")
    public static let configFile = configDirectory.appendingPathComponent("config.json")

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    public init() {}

    /// Read local config. Returns default config if file doesn't exist.
    public func read() -> LocalConfig {
        let url = Self.configFile
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(LocalConfig.self, from: data)
        else {
            return LocalConfig.defaultConfig
        }
        return config
    }

    /// Write local config, creating the directory if needed.
    public func write(_ config: LocalConfig) throws {
        let dir = Self.configDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(config)
        try data.write(to: Self.configFile, options: .atomic)
    }

    /// Get the machine ID, auto-detecting if not yet set.
    public func getMachineId() -> String {
        let config = read()
        if !config.machineId.isEmpty {
            return config.machineId
        }
        return MachineIdentifier.autoDetect()
    }

    /// Ensure machine ID is configured. Returns the ID or throws.
    public func requireMachineId() throws -> String {
        let id = getMachineId()
        let config = read()
        if config.machineId.isEmpty {
            // Auto-set on first use
            var updated = config
            updated.machineId = id
            try write(updated)
        }
        return id
    }
}
