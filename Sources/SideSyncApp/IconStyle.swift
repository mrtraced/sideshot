import SwiftUI

/// UI-layer mapping from the Library record's string-token icon fields
/// (iconSymbol, iconColor) to actual SwiftUI Color + SF Symbol values.
/// Tokens stay as strings in the cloud record so the file is portable and
/// non-Apple-platform readable.
enum IconStyle {
    /// Color tokens offered in the picker. Order is the display order.
    static let colorTokens: [String] = [
        "blue", "indigo", "purple", "pink",
        "red", "orange", "yellow", "green",
        "mint", "teal", "cyan", "brown",
        "gray"
    ]

    /// Curated set of SF Symbols suitable for folders, locations, and projects.
    /// Grouped by theme for visual scanability in the picker.
    static let symbolGroups: [(label: String, symbols: [String])] = [
        ("Folders", [
            "folder.fill",
            "folder.fill.badge.gearshape",
            "folder.fill.badge.person.crop",
            "folder.fill.badge.plus",
            "tray.full.fill",
            "archivebox.fill"
        ]),
        ("Home & Places", [
            "house.fill",
            "building.2.fill",
            "globe",
            "network",
            "location.fill",
            "map.fill"
        ]),
        ("Documents", [
            "doc.fill",
            "doc.text.fill",
            "doc.richtext.fill",
            "book.fill",
            "books.vertical.fill",
            "newspaper.fill"
        ]),
        ("Personal", [
            "star.fill",
            "heart.fill",
            "bookmark.fill",
            "tag.fill",
            "flag.fill",
            "bell.fill"
        ]),
        ("Work", [
            "briefcase.fill",
            "case.fill",
            "hammer.fill",
            "wrench.and.screwdriver.fill",
            "gear",
            "terminal.fill"
        ]),
        ("Media", [
            "music.note",
            "photo.fill",
            "film.fill",
            "headphones",
            "camera.fill",
            "paintbrush.fill"
        ]),
        ("Devices & Cloud", [
            "desktopcomputer",
            "laptopcomputer",
            "externaldrive.fill",
            "icloud.fill",
            "internaldrive.fill",
            "server.rack"
        ]),
        ("Communication", [
            "envelope.fill",
            "paperplane.fill",
            "message.fill",
            "phone.fill",
            "calendar",
            "clock.fill"
        ])
    ]

    /// Resolve a color token to a SwiftUI Color. Unknown tokens fall back to blue.
    static func color(for token: String?) -> Color {
        switch token {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return .green
        case "mint":   return .mint
        case "teal":   return .teal
        case "cyan":   return .cyan
        case "blue":   return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink":   return .pink
        case "brown":  return .brown
        case "gray":   return .gray
        default:       return .blue
        }
    }

    /// Resolve the SF Symbol name. Unknown / nil → "folder.fill".
    static func symbol(for token: String?) -> String {
        guard let token, !token.isEmpty else { return "folder.fill" }
        return token
    }
}
