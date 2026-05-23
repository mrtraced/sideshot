import AppKit
import SwiftUI

/// Renders SF Symbols to multi-resolution NSImages and writes them as
/// folder icons via NSWorkspace. Used during Apply so the user's custom
/// Library icons appear in the actual Finder sidebar.
enum FinderIconWriter {
    /// Sizes (in points) of bitmap representations we attach to the NSImage.
    /// Finder picks the closest rep for the size it needs in any context
    /// (16pt sidebar, 32pt list view, 128–512pt icon view at high DPI).
    private static let renderSizes: [Int] = [16, 32, 64, 128, 256, 512]

    /// Render an SF Symbol with the given tint color into a single NSImage
    /// carrying multiple bitmap representations. Returns nil if the symbol
    /// name can't be resolved by the system.
    static func renderIcon(symbol: String, color: NSColor) -> NSImage? {
        // Sanity check — does this symbol exist at all?
        guard NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil else {
            return nil
        }

        let icon = NSImage(size: NSSize(width: 512, height: 512))
        for size in renderSizes {
            guard let rep = renderRep(symbol: symbol, color: color, size: size) else { continue }
            icon.addRepresentation(rep)
        }
        return icon.representations.isEmpty ? nil : icon
    }

    private static func renderRep(symbol: String, color: NSColor, size: Int) -> NSBitmapImageRep? {
        let dim = CGFloat(size)
        // SF Symbols look right at ~65% of the container — leaves visible
        // padding so the glyph doesn't ride the folder-icon edges.
        let pointSize = dim * 0.62

        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))

        guard let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            return nil
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = context

        // Transparent background
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: dim, height: dim).fill()

        // Center the symbol
        let imgSize = symbolImage.size
        let origin = NSPoint(
            x: (dim - imgSize.width) / 2,
            y: (dim - imgSize.height) / 2
        )
        symbolImage.draw(
            at: origin,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        return rep
    }

    /// Write the rendered icon onto the folder at `path` via NSWorkspace.
    /// - Throws: if the path doesn't exist, isn't writable, or the system
    ///   refuses (e.g. read-only volumes, /Applications, iCloud Drive root).
    /// - Returns: true if the icon was set, false if the path doesn't exist.
    @discardableResult
    static func writeIcon(symbol: String, color: NSColor, toFile path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        guard let image = renderIcon(symbol: symbol, color: color) else { return false }
        return NSWorkspace.shared.setIcon(image, forFile: path, options: [])
    }

    /// Clear any custom icon from the folder, restoring the system default.
    @discardableResult
    static func clearIcon(forFile path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        return NSWorkspace.shared.setIcon(nil, forFile: path, options: [])
    }

    /// Translate a SwiftUI Color token to an NSColor.
    static func nsColor(forToken token: String?) -> NSColor {
        switch token {
        case "red":    return .systemRed
        case "orange": return .systemOrange
        case "yellow": return .systemYellow
        case "green":  return .systemGreen
        case "mint":   return .systemMint
        case "teal":   return .systemTeal
        case "cyan":   return .systemCyan
        case "blue":   return .systemBlue
        case "indigo": return .systemIndigo
        case "purple": return .systemPurple
        case "pink":   return .systemPink
        case "brown":  return .systemBrown
        case "gray":   return .systemGray
        default:       return .systemBlue
        }
    }
}
