import SwiftUI

/// Centralized design tokens — colors, spacing, radii, typography, strokes,
/// animation timings. Views should reach for `Theme.…` instead of literals so
/// the whole app can be retuned in one place.
///
/// Naming convention: semantic names (`surface`, `headerBackground`,
/// `tileSelected`) over raw values (`gray06`). When a token is mapped from a
/// SwiftUI ShapeStyle or system color, the mapping lives here so view code
/// stays declarative.
enum Theme {

    // MARK: - Colors (semantic)

    enum Colors {
        /// Main pane backgrounds.
        static let surface: Color = Color(nsColor: .windowBackgroundColor)
        /// Read-only or inactive surfaces (Current pane).
        static let surfaceMuted: Color = Color.gray.opacity(0.04)
        /// Header bars at the top of each pane.
        static let headerBackground: Color = .clear  // uses .bar material in callsite
        /// Subtle border / divider tint.
        static let border: Color = Color.gray.opacity(0.18)
        /// Even fainter borders for non-load-bearing decoration.
        static let borderSubtle: Color = Color.gray.opacity(0.10)

        // Tile states
        static let tileRest: Color = Color.gray.opacity(0.08)
        static let tileHover: Color = Color.gray.opacity(0.14)
        static let tileSelected: Color = Color.accentColor.opacity(0.18)
        static let tileInUse: Color = Color.gray.opacity(0.05)

        // Pending row states
        static let rowSelected: Color = Color.accentColor.opacity(0.16)

        // Drawer
        static let drawerTintTop: Color = Color.indigo.opacity(0.06)
        static let drawerTintBottom: Color = Color.indigo.opacity(0.015)
        static let drawerAccentStripe: Color = Color.indigo.opacity(0.35)

        // Status colors
        static let success: Color = .green
        static let warning: Color = .orange
        static let error: Color = .red
        static let info: Color = .blue

        // Text accents (icons / labels of meaning)
        static let linkedAccent: Color = .accentColor
        static let pendingPathBadge: Color = .orange
    }

    // MARK: - Spacing

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 16
        static let xxxl: CGFloat = 24
    }

    // MARK: - Radii

    enum Radius {
        static let xs: CGFloat = 3
        static let sm: CGFloat = 5
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 10
    }

    // MARK: - Typography

    enum Font_ {
        // Header bars at the top of each pane.
        static let paneHeader = Font.system(size: 12, weight: .semibold)
        static let paneCount = Font.system(size: 11)

        // Tiles & rows
        static let tileTitle = Font.system(size: 12, weight: .medium)
        static let tilePath = Font.system(size: 9, design: .monospaced)
        static let rowTitle = Font.system(size: 13)
        static let rowPath = Font.system(size: 10)

        // Edit pane
        static let editTitle = Font.system(size: 15, weight: .semibold)
        static let editLabel = Font.system(size: 9, weight: .medium)  // "PATH HINTS", "ICON", etc.
        static let editValue = Font.system(size: 12)
        static let editPath = Font.system(size: 11, design: .monospaced)

        // Badges
        static let badge = Font.system(size: 9, weight: .semibold)
        static let badgeLabel = Font.system(size: 10)

        // Misc
        static let tinyMono = Font.system(size: 10, design: .monospaced)
    }

    // MARK: - Strokes

    enum Stroke {
        static let hairline: CGFloat = 1
        static let selected: CGFloat = 1.5
        static let prominent: CGFloat = 2
    }

    // MARK: - Animations

    enum Animation_ {
        static let quick: Animation = .easeInOut(duration: 0.18)
        static let standard: Animation = .easeInOut(duration: 0.28)
        static let drawer: Animation = .easeInOut(duration: 0.32)
    }

    // MARK: - Sizes

    enum Size {
        /// Library tile default footprint.
        static let libraryTile = CGSize(width: 140, height: 70)
        /// Icon picker cell.
        static let iconPickerCell: CGFloat = 32
        /// Color swatch in icon picker.
        static let colorSwatch: CGFloat = 18
    }
}
