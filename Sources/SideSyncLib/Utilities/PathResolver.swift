import Foundation

public enum PathResolver {
    /// Check if a path exists on disk.
    public static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Resolve the best local path for a cloud favorite.
    /// Priority: local override > this machine's path > fuzzy match from any path > nil.
    public static func resolveLocalPath(
        for favorite: CloudFavorite,
        machineId: String,
        config: LocalConfig
    ) -> String? {
        // 1. Local override takes top priority
        if let override = config.pathOverrides[favorite.id] {
            if exists(override) { return override }
        }

        // 2. This machine's stored path
        if let machinePath = favorite.paths[machineId] {
            if exists(machinePath) { return machinePath }
        }

        // 3. Try any other machine's path (might work if same mount structure)
        for (_, path) in favorite.paths where path != favorite.paths[machineId] {
            if exists(path) { return path }
        }

        return nil
    }

    // MARK: - Matching

    /// Match a local sidebar favorite against cloud favorites.
    /// Returns the best-matching cloud favorite, if any.
    ///
    /// Matching signals (in priority order):
    /// 1. Exact display name match
    /// 2. Path hint match (last 1-2 folder components)
    public static func findCloudMatch(
        for local: SidebarFavorite,
        in cloudFavorites: [CloudFavorite]
    ) -> CloudFavorite? {
        // 1. Exact name match
        if let match = cloudFavorites.first(where: { $0.name == local.name }) {
            return match
        }

        // 2. Path hint match — compare last 2 path components
        let localHints = CloudFavorite.buildPathHints(from: local.path)
        if !localHints.isEmpty {
            // Full 2-component match
            if let match = cloudFavorites.first(where: { $0.pathHints == localHints }) {
                return match
            }
            // Last component match (the folder name itself)
            let localLast = localHints.last!
            if let match = cloudFavorites.first(where: { $0.pathHints.last == localLast }) {
                return match
            }
        }

        return nil
    }

    /// Match cloud favorites against local sidebar items during pull.
    /// Returns the best-matching local favorite, if any.
    public static func findLocalMatch(
        for cloud: CloudFavorite,
        in localFavorites: [SidebarFavorite]
    ) -> SidebarFavorite? {
        // 1. Exact name match
        if let match = localFavorites.first(where: { $0.name == cloud.name }) {
            return match
        }

        // 2. Path hint match
        if !cloud.pathHints.isEmpty {
            for local in localFavorites {
                let localHints = CloudFavorite.buildPathHints(from: local.path)
                // Full match
                if localHints == cloud.pathHints {
                    return local
                }
                // Last component match
                if localHints.last == cloud.pathHints.last {
                    return local
                }
            }
        }

        return nil
    }

    // MARK: - Auto-detect Path Suggestions

    /// Try to find a matching path for the current user by replacing the username
    /// component in paths from other machines. For example, if another machine has
    /// `/Users/bobbarker/Projects` and the current user is `janbarker`, this will
    /// check if `/Users/janbarker/Projects` exists.
    public static func suggestLocalPath(
        for favorite: CloudFavorite,
        machineId: String
    ) -> String? {
        let currentHome = FileManager.default.homeDirectoryForCurrentUser.path
        let currentUser = URL(fileURLWithPath: currentHome).lastPathComponent

        for (machine, path) in favorite.paths where machine != machineId {
            // Try replacing /Users/<otherUser>/... with /Users/<currentUser>/...
            let components = URL(fileURLWithPath: path).pathComponents
            if components.count >= 3,
               components[0] == "/",
               components[1] == "Users",
               components[2] != currentUser {
                var newComponents = components
                newComponents[2] = currentUser
                let candidate = newComponents.joined(separator: "/")
                    .replacingOccurrences(of: "//", with: "/")
                if exists(candidate) {
                    return candidate
                }
            }

            // Also try: same relative path from current home directory
            // e.g. /home/bob/Documents/Work -> ~/Documents/Work
            if path.hasPrefix("/Users/") || path.hasPrefix("/home/") {
                // Extract the relative part after the user directory
                let url = URL(fileURLWithPath: path)
                let pathComponents = url.pathComponents
                if pathComponents.count >= 3 {
                    let relativeComponents = Array(pathComponents.dropFirst(3)) // drop /, Users, username
                    if !relativeComponents.isEmpty {
                        let candidate = (currentHome as NSString)
                            .appendingPathComponent(relativeComponents.joined(separator: "/"))
                        if exists(candidate) {
                            return candidate
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Interactive Prompts

    /// Prompt the user interactively to resolve a missing path.
    /// Returns the action taken.
    public static func promptForMissingPath(
        favorite: CloudFavorite,
        knownPaths: [String]
    ) -> PathResolution {
        print("\n\u{26a0}\u{fe0f}  \"\(favorite.name)\" — no valid local path found")
        if !knownPaths.isEmpty {
            print("   Known paths from other machines:")
            for path in knownPaths {
                print("     \(path)")
            }
        }
        print()
        print("  [1] Enter a local path for this machine")
        print("  [2] Skip for now")
        print("  [3] Hide on this machine")
        print()
        print("  Choice: ", terminator: "")

        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else {
            return .skip
        }

        switch choice {
        case "1":
            print("  Path: ", terminator: "")
            guard let path = readLine()?.trimmingCharacters(in: .whitespaces),
                  !path.isEmpty
            else {
                print("  No path entered, skipping.")
                return .skip
            }
            // Expand ~ if present
            let expanded = NSString(string: path).expandingTildeInPath
            if exists(expanded) {
                return .localPath(expanded)
            } else {
                print("  \u{274c} Path does not exist: \(expanded)")
                print("  Add anyway? (y/n): ", terminator: "")
                if readLine()?.lowercased() == "y" {
                    return .localPath(expanded)
                }
                return .skip
            }

        case "3":
            return .hide

        default:
            return .skip
        }
    }
}

public enum PathResolution {
    case localPath(String)
    case skip
    case hide
}
