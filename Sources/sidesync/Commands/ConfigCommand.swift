import ArgumentParser
import Foundation
import SideSyncLib

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "View or update local configuration.",
        subcommands: [SetName.self, SetRole.self, LocalOnly.self, Show.self],
        defaultSubcommand: Show.self
    )

    // MARK: - set-name

    struct SetName: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set-name",
            abstract: "Set this machine's identifier."
        )

        @Argument(
            help: "A short name for this machine (e.g., \"MacBook-Pro\", \"iMac-Studio\")."
        )
        var name: String

        func run() throws {
            let service = ConfigService()
            var config = service.read()
            config.machineId = name
            try service.write(config)
            print("Machine name set to: \(name)")
        }
    }

    // MARK: - set-role

    struct SetRole: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set-role",
            abstract: "Set this machine's sync role.",
            discussion: """
                Roles control how push/pull behave:

                  primary    — Two-way sync. This machine's changes propagate to all
                               others. Only one machine should be primary.
                  satellite  — One-way from primary. Pull applies parent changes;
                               push is blocked. Local sidebar edits are overwritten
                               on next pull.
                  indie      — Inherit parent changes on pull, but local-only
                               favorites stay on this machine and are never pushed
                               to cloud. Mark favorites as local-only with
                               `sidesync config local-only add <name>`.
                """
        )

        @Argument(help: "Sync role: primary, satellite, or indie.")
        var role: SyncRole

        func run() throws {
            let service = ConfigService()
            var config = service.read()
            let oldRole = config.role
            config.role = role
            try service.write(config)
            print("Sync role changed: \(oldRole.rawValue) → \(role.rawValue)")
            print("  \(role.label)")

            if role == .primary {
                // Update cloud file to record this as primary
                let cloudService = CloudService()
                if var cloud = try cloudService.read() {
                    let machineId = service.getMachineId()
                    if cloud.primaryMachine != machineId {
                        cloud.primaryMachine = machineId
                        try cloudService.write(cloud)
                        print("  Registered as primary in cloud sync file.")
                    }
                }
            }
        }
    }

    // MARK: - local-only

    struct LocalOnly: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "local-only",
            abstract: "Manage local-only favorites (indie mode).",
            subcommands: [AddLocalOnly.self, RemoveLocalOnly.self, ListLocalOnly.self],
            defaultSubcommand: ListLocalOnly.self
        )

        struct AddLocalOnly: ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "add",
                abstract: "Mark a favorite as local-only (won't be pushed to cloud)."
            )

            @Argument(help: "Name of the favorite to mark as local-only.")
            var name: String

            func run() throws {
                let service = ConfigService()
                var config = service.read()
                config.localOnlyFavorites.insert(name)
                try service.write(config)
                print(
                    "\u{1f4cc} \"\(name)\" marked as local-only — it won't be pushed to cloud."
                )
            }
        }

        struct RemoveLocalOnly: ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "remove",
                abstract: "Remove local-only flag (favorite will sync normally)."
            )

            @Argument(help: "Name of the favorite to remove from local-only.")
            var name: String

            func run() throws {
                let service = ConfigService()
                var config = service.read()
                if config.localOnlyFavorites.remove(name) != nil {
                    try service.write(config)
                    print("\u{2705} \"\(name)\" will now sync to cloud on push.")
                } else {
                    print("\"\(name)\" is not marked as local-only.")
                }
            }
        }

        struct ListLocalOnly: ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "list",
                abstract: "List all local-only favorites."
            )

            func run() throws {
                let service = ConfigService()
                let config = service.read()

                if config.localOnlyFavorites.isEmpty {
                    print("No local-only favorites configured.")
                    print(
                        "Use `sidesync config local-only add <name>` to mark a favorite as local-only."
                    )
                } else {
                    print("Local-only favorites (\(config.localOnlyFavorites.count)):")
                    for name in config.localOnlyFavorites.sorted() {
                        print("  \u{1f4cc} \(name)")
                    }
                }
            }
        }
    }

    // MARK: - show

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show current configuration."
        )

        func run() throws {
            let service = ConfigService()
            let config = service.read()
            let machineId = service.getMachineId()

            print("Configuration (\(ConfigService.configFile.path)):\n")
            print(
                "  Machine ID: \(machineId)\(config.machineId.isEmpty ? " (auto-detected)" : "")"
            )
            print("  Sync role:  \(config.role.label)")
            print("  Hidden favorites: \(config.hiddenFavorites.count)")
            print("  Path overrides: \(config.pathOverrides.count)")
            print("  Local-only favorites: \(config.localOnlyFavorites.count)")

            if !config.pathOverrides.isEmpty {
                print()
                print("  Path overrides:")
                for (id, path) in config.pathOverrides.sorted(by: { $0.key < $1.key }) {
                    print("    \(id) → \(path)")
                }
            }

            if !config.localOnlyFavorites.isEmpty {
                print()
                print("  Local-only:")
                for name in config.localOnlyFavorites.sorted() {
                    print("    \u{1f4cc} \(name)")
                }
            }

            print()
            print("Cloud file: \(CloudService.cloudFile.path)")
            let cloudService = CloudService()
            if cloudService.hasCloudFile {
                print("  Exists: yes")
                if let cloud = try? cloudService.read() {
                    if let primary = cloud.primaryMachine {
                        print("  Primary machine: \(primary)")
                    }
                    let machines = Set(cloud.favorites.flatMap { $0.paths.keys }).sorted()
                    if !machines.isEmpty {
                        print("  Known machines: \(machines.joined(separator: ", "))")
                    }
                }
            } else {
                print("  Exists: no")
            }
        }
    }
}

// Make SyncRole conform to ExpressibleByArgument for ArgumentParser
extension SyncRole: ExpressibleByArgument {}
