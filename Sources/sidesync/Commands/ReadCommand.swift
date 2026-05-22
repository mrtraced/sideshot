import ArgumentParser
import Foundation
import SideSyncLib

struct ReadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "read",
        abstract: "List current Finder sidebar favorites."
    )

    func run() throws {
        let sidebar = try SidebarService()
        let favorites = try sidebar.readFavorites()

        if favorites.isEmpty {
            print("No sidebar favorites found.")
            return
        }

        print("Finder sidebar favorites (\(favorites.count)):\n")
        for (i, fav) in favorites.enumerated() {
            print("  \(i + 1). \(fav.name)")
            print("     \(fav.path)")
        }
    }
}
