import ArgumentParser
import SideSyncLib

@main
struct SideSync: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sidesync",
        abstract: "Sync Finder sidebar favorites across Macs via iCloud Drive.",
        version: "0.1.0",
        subcommands: [
            ReadCommand.self,
            PushCommand.self,
            PullCommand.self,
            HideCommand.self,
            UnhideCommand.self,
            StatusCommand.self,
            ConfigCommand.self,
        ],
        defaultSubcommand: StatusCommand.self
    )
}
