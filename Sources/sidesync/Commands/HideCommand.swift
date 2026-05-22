import ArgumentParser
import Foundation
import SideSyncLib

struct HideCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hide",
        abstract: "Hide a favorite on this machine (preserved in cloud)."
    )

    @Argument(help: "Name of the favorite to hide.")
    var name: String

    @Flag(name: .long, help: "Also remove from the Finder sidebar.")
    var removeSidebar: Bool = false

    func run() throws {
        let configService = ConfigService()
        var config = configService.read()

        let cloudService = CloudService()

        // Try to find the favorite in cloud data
        if let cloud = try cloudService.read(),
           let cloudFav = cloud.favorites.first(where: {
               $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
           })
        {
            if config.hiddenFavorites.contains(cloudFav.id) {
                print("\"\(cloudFav.name)\" is already hidden on this machine.")
                return
            }
            config.hiddenFavorites.append(cloudFav.id)
            try configService.write(config)
            print("\u{1f6ab} Hidden \"\(cloudFav.name)\" on this machine.")
            print("   It will be skipped on future pulls.")
            print("   Use `sidesync unhide \"\(cloudFav.name)\"` to restore.")
        } else {
            // No cloud data yet — still allow hiding by name for later
            // Generate a deterministic ID from the name
            let id = "local-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
            if !config.hiddenFavorites.contains(id) {
                config.hiddenFavorites.append(id)
                try configService.write(config)
            }
            print("\u{1f6ab} Marked \"\(name)\" as hidden (no cloud data found yet).")
        }

        // Optionally remove from sidebar
        if removeSidebar {
            let sidebar = try SidebarService()
            if try sidebar.removeFavorite(named: name) {
                print("   Removed from Finder sidebar.")
            } else {
                print("   Not found in current sidebar.")
            }
        }
    }
}
