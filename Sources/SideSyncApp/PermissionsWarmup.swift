import Foundation

/// Proactively touches the user folders Apply will likely write to, so macOS
/// TCC prompts for "SideSync.app would like to access Desktop / Documents /
/// Downloads / …" happen in one batch on first launch rather than dribbled
/// out during Apply.
///
/// Each access is a tiny read (FileManager.contentsOfDirectory + count).
/// macOS gates the FIRST access per protected folder class with a prompt;
/// subsequent accesses are silently allowed once approved.
///
/// Caveat: TCC remembers the grant by app code-signature identity. Ad-hoc
/// signed dev builds may get re-prompted across rebuilds; properly signed
/// release builds will not.
enum PermissionsWarmup {

    /// Folders we want to pre-approve.
    /// Order is meaningful — the user sees prompts in this order.
    static let probedRelativePaths: [String] = [
        "Desktop",
        "Documents",
        "Downloads",
        "Movies",
        "Music",
        "Pictures",
        "Public",
        "Library/Mobile Documents/com~apple~CloudDocs"
    ]

    /// Touch each folder under the user's home directory. Existence check +
    /// directory-listing call is enough to trigger TCC.
    @discardableResult
    static func warmUp() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var touched: [String] = []
        for relative in probedRelativePaths {
            let path = "\(home)/\(relative)"
            guard FileManager.default.fileExists(atPath: path) else { continue }
            _ = try? FileManager.default.contentsOfDirectory(atPath: path)
            touched.append(path)
        }
        return touched
    }
}
