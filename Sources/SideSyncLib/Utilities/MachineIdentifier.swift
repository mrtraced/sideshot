import Foundation

public enum MachineIdentifier {
    /// Auto-detect a human-readable machine name.
    /// Uses the local hostname (e.g. "MacBook-Pro", "iMac-Studio").
    public static func autoDetect() -> String {
        // SCDynamicStoreCopyLocalHostName gives the "Computer Name" from System Preferences
        // but ProcessInfo.hostName is simpler and always available
        let host = ProcessInfo.processInfo.hostName
        // Strip ".local" suffix if present
        if host.hasSuffix(".local") {
            return String(host.dropLast(6))
        }
        return host
    }
}
