import ArgumentParser
import Foundation
import SideSyncLib

struct PushCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "push",
        abstract: "Save current sidebar favorites to iCloud Drive."
    )

    func run() throws {
        let configService = ConfigService()
        let machineId = try configService.requireMachineId()
        let config = configService.read()

        // Satellites cannot push
        if config.role == .satellite {
            print(
                "\u{1f6ab} This machine is a satellite — it only receives changes from the primary."
            )
            print("   Use `sidesync config set-role primary` or `indie` to change this.")
            throw ExitCode.failure
        }

        let sidebar = try SidebarService()
        let localFavorites = try sidebar.readFavorites()

        let cloudService = CloudService()
        var cloud = try cloudService.read() ?? CloudFavorites(
            lastUpdatedBy: machineId,
            lastUpdatedAt: Date(),
            primaryMachine: config.role == .primary ? machineId : nil,
            favorites: []
        )

        var added = 0
        var updated = 0

        for (i, local) in localFavorites.enumerated() {
            // In indie mode, skip local-only favorites (don't push them to cloud)
            if config.role == .indie, config.localOnlyFavorites.contains(local.name) {
                continue
            }

            if let matchIndex = cloud.favorites.firstIndex(where: {
                PathResolver.findCloudMatch(for: local, in: [$0]) != nil
            }) {
                // Update existing entry with this machine's path
                let existing = cloud.favorites[matchIndex].paths[machineId]
                cloud.favorites[matchIndex].paths[machineId] = local.path
                if cloud.favorites[matchIndex].pathHints.isEmpty {
                    cloud.favorites[matchIndex].pathHints =
                        CloudFavorite.buildPathHints(from: local.path)
                }
                if existing != local.path {
                    updated += 1
                }
            } else {
                // New favorite — add it
                let cloudFav = CloudFavorite(
                    id: UUID().uuidString,
                    name: local.name,
                    pathHints: CloudFavorite.buildPathHints(from: local.path),
                    order: i,
                    paths: [machineId: local.path]
                )
                cloud.favorites.append(cloudFav)
                added += 1
            }
        }

        // If this is the primary, update the cloud record
        if config.role == .primary {
            cloud.primaryMachine = machineId
        }

        cloud.lastUpdatedBy = machineId
        cloud.lastUpdatedAt = Date()

        try cloudService.write(cloud)

        let roleNote = config.role == .indie ? " (indie — local-only items excluded)" : ""
        print("\u{2601}\u{fe0f}  Pushed to iCloud Drive\(roleNote)")
        print("   Machine: \(machineId) [\(config.role.rawValue)]")
        print("   Total favorites in cloud: \(cloud.favorites.count)")
        if added > 0 { print("   New: \(added)") }
        if updated > 0 { print("   Updated paths: \(updated)") }
        print("   File: \(CloudService.cloudFile.path)")
    }
}
