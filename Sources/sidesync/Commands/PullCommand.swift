import ArgumentParser
import Foundation
import SideSyncLib

struct PullCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: "Download favorites from iCloud and apply to this machine's sidebar."
    )

    @Flag(name: .long, help: "Skip interactive prompts — only add favorites with valid local paths.")
    var nonInteractive: Bool = false

    func run() throws {
        let configService = ConfigService()
        let machineId = try configService.requireMachineId()
        var config = configService.read()

        let cloudService = CloudService()
        guard let cloud = try cloudService.read() else {
            throw SideSyncError.cloudFileNotFound
        }

        let sidebar = try SidebarService()
        let localFavorites = try sidebar.readFavorites()

        // Role-based header
        let roleNote: String
        switch config.role {
        case .primary:
            roleNote = " (primary — two-way sync)"
        case .satellite:
            roleNote = " (satellite — inheriting from primary)"
        case .indie:
            roleNote = " (indie — inheriting parent changes, keeping local)"
        }

        print(
            "\u{2601}\u{fe0f}  Pulling from iCloud Drive\(roleNote)"
        )
        print("   Last updated by: \(cloud.lastUpdatedBy)")
        if let primary = cloud.primaryMachine {
            print("   Primary machine: \(primary)")
        }
        print("   Cloud favorites: \(cloud.favorites.count)")
        print("   Local favorites: \(localFavorites.count)")
        print()

        // For satellite mode: also remove local items not in cloud
        // (satellite fully mirrors the primary)
        var removedCount = 0
        if config.role == .satellite {
            for local in localFavorites {
                let inCloud = PathResolver.findCloudMatch(for: local, in: cloud.favorites)
                if inCloud == nil {
                    // This local item isn't in the cloud — remove it
                    if try sidebar.removeFavorite(named: local.name) {
                        print("  \u{1f5d1}  Removed \"\(local.name)\" (not in cloud)")
                        removedCount += 1
                    }
                }
            }
        }

        var addedCount = 0
        var skippedCount = 0
        var hiddenCount = 0

        for cloudFav in cloud.favorites {
            // Skip if hidden on this machine
            if config.hiddenFavorites.contains(cloudFav.id) {
                skippedCount += 1
                continue
            }

            // Skip if already exists locally (by name or path hint match)
            if PathResolver.findLocalMatch(for: cloudFav, in: localFavorites) != nil {
                continue  // Already present, nothing to do
            }

            // Try to resolve a local path
            if let localPath = PathResolver.resolveLocalPath(
                for: cloudFav, machineId: machineId, config: config
            ) {
                // Path exists — add to sidebar
                if try sidebar.addFavorite(name: cloudFav.name, path: localPath) {
                    print("  \u{2705} Added \"\(cloudFav.name)\" \u{2192} \(localPath)")
                    addedCount += 1
                }
            } else if !nonInteractive {
                // Path doesn't exist — prompt user
                let knownPaths = Array(cloudFav.paths.values)
                let resolution = PathResolver.promptForMissingPath(
                    favorite: cloudFav,
                    knownPaths: knownPaths
                )

                switch resolution {
                case .localPath(let path):
                    config.pathOverrides[cloudFav.id] = path
                    if PathResolver.exists(path) {
                        if try sidebar.addFavorite(name: cloudFav.name, path: path) {
                            print("  \u{2705} Added \"\(cloudFav.name)\" \u{2192} \(path)")
                            addedCount += 1
                        }
                    } else {
                        print(
                            "  \u{1f4be} Path saved for \"\(cloudFav.name)\" (will add when available)"
                        )
                    }

                case .hide:
                    config.hiddenFavorites.append(cloudFav.id)
                    print("  \u{1f6ab} Hidden \"\(cloudFav.name)\" on this machine")
                    hiddenCount += 1

                case .skip:
                    print("  \u{23ed}\u{fe0f}  Skipped \"\(cloudFav.name)\"")
                    skippedCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        // Save any config changes (path overrides, hidden items)
        try configService.write(config)

        print()
        print("Done.")
        if addedCount > 0 { print("  Added: \(addedCount)") }
        if removedCount > 0 { print("  Removed (satellite cleanup): \(removedCount)") }
        if skippedCount > 0 { print("  Skipped: \(skippedCount)") }
        if hiddenCount > 0 { print("  Hidden: \(hiddenCount)") }
    }
}
