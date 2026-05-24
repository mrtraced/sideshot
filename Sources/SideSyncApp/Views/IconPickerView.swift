import SwiftUI
import SideSyncLib

/// Inline icon picker for a Library record.
/// Preview row + Reset action, color swatches, optional search field, a
/// Recently Used row (when populated), and the curated grouped symbol grid.
struct IconPickerView: View {
    @Environment(AppState.self) private var state
    let favorite: CloudFavorite

    @State private var searchQuery: String = ""

    private var resolvedSymbol: String { IconStyle.symbol(for: favorite.iconSymbol) }
    private var resolvedColor: Color { IconStyle.color(for: favorite.iconColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            preview
            colorRow
            searchField
            if !state.config.recentIconSymbols.isEmpty && trimmedQuery.isEmpty {
                recentRow
            }
            symbolGroups
        }
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        HStack(spacing: Theme.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(resolvedColor.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: resolvedSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(resolvedColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Icon")
                    .font(Theme.Font_.editLabel)
                    .foregroundStyle(.secondary)
                Text(resolvedSymbol)
                    .font(Theme.Font_.tinyMono)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if favorite.iconSymbol != nil {
                Button {
                    applyIconToFinderNow()
                } label: {
                    Label("Push to Finder", systemImage: "square.and.arrow.down.on.square")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Write this icon to the folder on disk right now (no need to Apply Pending)")
            }
            if favorite.iconSymbol != nil || favorite.iconColor != nil {
                Button {
                    state.updateLibraryIcon(favorite, symbol: nil, color: nil)
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Clear custom icon — go back to default folder")
            }
        }
    }

    private func applyIconToFinderNow() {
        guard let symbol = favorite.iconSymbol else { return }
        // Resolve this machine's path for the favorite.
        guard let path = PathResolver.resolveLocalPath(
            for: favorite, machineId: state.machineId, config: state.config
        ) ?? favorite.paths[state.machineId] else {
            state.errorMessage = "No usable local path for \"\(favorite.name)\""
            return
        }
        let color = FinderIconWriter.nsColor(forToken: favorite.iconColor)
        if FinderIconWriter.writeIcon(symbol: symbol, color: color, toFile: path) {
            state.statusMessage = "Wrote icon to \"\(favorite.name)\" — Finder may take a moment to refresh"
        } else {
            state.errorMessage = "Couldn't write icon to \"\(favorite.name)\" (read-only or system folder?)"
        }
    }

    // MARK: - Color swatches

    @ViewBuilder
    private var colorRow: some View {
        HStack(spacing: Theme.Space.sm) {
            ForEach(IconStyle.colorTokens, id: \.self) { token in
                let isSelected = favorite.iconColor == token
                Circle()
                    .fill(IconStyle.color(for: token))
                    .frame(width: Theme.Size.colorSwatch, height: Theme.Size.colorSwatch)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.primary : Theme.Colors.border,
                                lineWidth: isSelected ? Theme.Stroke.prominent : Theme.Stroke.hairline
                            )
                    )
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                    .animation(Theme.Animation_.quick, value: isSelected)
                    .onTapGesture {
                        state.updateLibraryIcon(
                            favorite,
                            symbol: favorite.iconSymbol,
                            color: token
                        )
                    }
                    .help("Tint: \(token)")
            }
        }
    }

    // MARK: - Search

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search symbols (or paste an exact SF Symbol name)", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm - 1)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.Colors.tileRest)
        )
    }

    // MARK: - Recently used

    @ViewBuilder
    private var recentRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("RECENTLY USED")
                .font(Theme.Font_.editLabel)
                .foregroundStyle(.tertiary)
            symbolGrid(symbols: state.config.recentIconSymbols)
        }
    }

    // MARK: - Grouped grid (or search results)

    @ViewBuilder
    private var symbolGroups: some View {
        if trimmedQuery.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                ForEach(IconStyle.symbolGroups, id: \.label) { group in
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text(group.label.uppercased())
                            .font(Theme.Font_.editLabel)
                            .foregroundStyle(.tertiary)
                        symbolGrid(symbols: group.symbols)
                    }
                }
            }
        } else {
            let matches = searchMatches
            if matches.isEmpty {
                Text("No matching symbols")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Space.md)
            } else {
                symbolGrid(symbols: matches)
            }
        }
    }

    /// Curated-list substring match. If the exact query is itself a valid SF
    /// Symbol name (so power users can type any symbol directly), it's
    /// surfaced at the top of the list.
    private var searchMatches: [String] {
        let query = trimmedQuery
        let curated = IconStyle.symbolGroups.flatMap(\.symbols)
        var matches = curated.filter { $0.lowercased().contains(query) }
        if !matches.contains(query),
           NSImage(systemSymbolName: query, accessibilityDescription: nil) != nil {
            matches.insert(query, at: 0)
        }
        return matches
    }

    @ViewBuilder
    private func symbolGrid(symbols: [String]) -> some View {
        let cell = Theme.Size.iconPickerCell
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(cell), spacing: Theme.Space.xs), count: 6),
            spacing: Theme.Space.xs
        ) {
            ForEach(symbols, id: \.self) { symbol in
                symbolCell(symbol)
            }
        }
    }

    @ViewBuilder
    private func symbolCell(_ symbol: String) -> some View {
        let isSelected = favorite.iconSymbol == symbol
        let cell = Theme.Size.iconPickerCell

        Button {
            state.updateLibraryIcon(
                favorite,
                symbol: symbol,
                color: favorite.iconColor
            )
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? resolvedColor : .secondary)
                .frame(width: cell, height: cell)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(isSelected ? resolvedColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(
                            isSelected ? resolvedColor : Theme.Colors.borderSubtle,
                            lineWidth: isSelected ? Theme.Stroke.selected : Theme.Stroke.hairline
                        )
                )
        }
        .buttonStyle(.plain)
        .help(symbol)
    }
}
