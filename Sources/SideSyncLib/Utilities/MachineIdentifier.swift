import Foundation
import SystemConfiguration

public enum MachineIdentifier {
    /// Auto-detect a human-readable machine name.
    ///
    /// Uses SCDynamicStoreCopyComputerName which reads the System Settings
    /// "Computer Name" directly. This is purely local — unlike
    /// ProcessInfo.processInfo.hostName, it does NOT trigger reverse-DNS
    /// lookups, so it never causes "cannot reach server" dialogs when offline.
    public static func autoDetect() -> String {
        if let cfName = SCDynamicStoreCopyComputerName(nil, nil) {
            let name = cfName as String
            if !name.isEmpty {
                return name
            }
        }

        // Fallback: gethostname() reads the local kernel hostname without DNS.
        var buf = [CChar](repeating: 0, count: 256)
        if gethostname(&buf, buf.count) == 0 {
            let host = String(cString: buf)
            if host.hasSuffix(".local") {
                return String(host.dropLast(6))
            }
            if !host.isEmpty {
                return host
            }
        }

        return "Mac"
    }
}
