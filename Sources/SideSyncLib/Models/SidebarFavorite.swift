import Foundation

/// A Finder sidebar favorite as read from the system.
public struct SidebarFavorite: Identifiable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let url: URL

    public init(name: String, path: String, url: URL) {
        self.name = name
        self.path = path
        self.url = url
    }
}
