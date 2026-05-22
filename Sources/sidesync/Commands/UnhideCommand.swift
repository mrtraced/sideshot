import ArgumentParser
import Foundation
import SideSyncLib

struct UnhideCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unhide",
        abstract: "Unhide a previously hidden favorite."
    )

    @Argument(help: "Name of the favorite to unhide.")
    var name: String

    func run() throws {
        let configService = ConfigService()
        var config = configService.read()

        let cloudService = CloudService()

        // Find matching cloud favorite
        var removed = false
        if let cloud = try cloudService.read(),
           let cloudFav = cloud.favorites.first(where: {
               $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
           })
        {
            if let idx = config.hiddenFavorites.firstIndex(of: cloudFav.id) {
                config.hiddenFavorites.remove(at: idx)
                removed = true
            }
        }

        // Also check for name-based local IDs
        let localId = "local-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        if let idx = config.hiddenFavorites.firstIndex(of: localId) {
            config.hiddenFavorites.remove(at: idx)
            removed = true
        }

        if removed {
            try configService.write(config)
            print("\u{2705} Unhidden \"\(name)\".")
            print("   Run `sidesync pull` to add it back to the sidebar.")
        } else {
            print("\"\(name)\" is not currently hidden.")
        }
    }
}
