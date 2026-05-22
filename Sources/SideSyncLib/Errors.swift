import Foundation

public enum SideSyncError: LocalizedError {
    case apiUnavailable(String)
    case cloudFileNotFound
    case configNotFound
    case invalidPath(String)
    case machineIdNotSet

    public var errorDescription: String? {
        switch self {
        case .apiUnavailable(let msg): return "API unavailable: \(msg)"
        case .cloudFileNotFound: return "No sync file found in iCloud Drive"
        case .configNotFound:
            return "Local config not found. Run `sidesync config set-name <name>` first."
        case .invalidPath(let p): return "Path does not exist: \(p)"
        case .machineIdNotSet:
            return "Machine name not set. Run `sidesync config set-name <name>` first."
        }
    }
}
