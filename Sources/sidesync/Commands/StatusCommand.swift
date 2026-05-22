import ArgumentParser
import Foundation
import SideSyncLib

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show sync state: local vs cloud, hidden items, path mappings."
    )

    func run() throws {
        let configService = ConfigService()
        let config = configService.read()
        let machineId = configService.getMachineId()

        let sidebar = try SidebarService()
        let localFavorites = try sidebar.readFavorites()

        let cloudService = CloudService()
        let cloud = try cloudService.read()

        // Machine info
        print("Machine: \(machineId)\(config.machineId.isEmpty ? " (auto-detected)" : "")")
        print("Role:    \(config.role.label)")
        print()

        // Local sidebar
        print("Local sidebar (\(localFavorites.count) favorites):")
        for fav in localFavorites {
            print("  • \(fav.name)  →  \(fav.path)")
        }
        print()

        // Cloud state
        if let cloud = cloud {
            print(
                "Cloud (\(cloud.favorites.count) favorites, last updated by \(cloud.lastUpdatedBy)):"
            )
            for fav in cloud.favorites {
                let isHidden = config.hiddenFavorites.contains(fav.id)
                let localMatch = PathResolver.findLocalMatch(for: fav, in: localFavorites)
                let hasOverride = config.pathOverrides[fav.id] != nil

                var status = ""
                if isHidden {
                    status = "\u{1f6ab} hidden"
                } else if localMatch != nil {
                    status = "\u{2705} synced"
                } else if let path = PathResolver.resolveLocalPath(
                    for: fav, machineId: machineId, config: config)
                {
                    if PathResolver.exists(path) {
                        status = "\u{1f7e1} available (not in sidebar)"
                    } else {
                        status = "\u{274c} path not found"
                    }
                } else {
                    status = "\u{2753} no path for this machine"
                }

                print("  \(status)  \(fav.name)")

                // Show machine paths
                let machines = fav.paths.keys.sorted()
                for machine in machines {
                    let isCurrent = machine == machineId
                    let marker = isCurrent ? "→" : " "
                    print("      \(marker) \(machine): \(fav.paths[machine]!)")
                }
                if hasOverride {
                    print("      ⚡ override: \(config.pathOverrides[fav.id]!)")
                }
            }
        } else {
            print("Cloud: no sync file found")
            print("  Run `sidesync push` to upload your favorites.")
        }

        // Hidden items
        if !config.hiddenFavorites.isEmpty {
            print()
            print("Hidden on this machine: \(config.hiddenFavorites.count) favorites")
            if let cloud = cloud {
                for id in config.hiddenFavorites {
                    if let fav = cloud.favorites.first(where: { $0.id == id }) {
                        print("  \u{1f6ab} \(fav.name)")
                    } else {
                        print("  \u{1f6ab} (id: \(id))")
                    }
                }
            }
        }
    }
}
