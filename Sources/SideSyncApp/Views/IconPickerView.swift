import SwiftUI
import SideSyncLib

/// Inline icon picker for a Library record.
/// Shows the current icon, a row of color swatches, and a grid of SF Symbols
/// grouped by theme. Changes write through to the Library record immediately;
/// linked Pending rows and tiles re-render reactively.
struct IconPickerView: View {
    @Environment(AppState.self) private var state
    let favorite: CloudFavorite

    private var resolvedSymbol: String { IconStyle.symbol(for: favorite.iconSymbol) }
    private var resolvedColor: Color { IconStyle.color(for: favorite.iconColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            preview
            colorRow
            symbolGrid
        }
    }

    // MARK: - Preview row

    @ViewBuilder
    private var preview: some View {
        HStack(spacing: 8) {
            Image(systemName: resolvedSymbol)
                .font(.system(size: 18))
                .foregroundStyle(resolvedColor)
                .frame(width: 22, height: 22)
            Text("Icon")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
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

    // MARK: - Color swatches

    @ViewBuilder
    private var colorRow: some View {
        HStack(spacing: 6) {
            ForEach(IconStyle.colorTokens, id: \.self) { token in
                let isSelected = favorite.iconColor == token
                Circle()
                    .fill(IconStyle.color(for: token))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.primary : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .scaleEffect(isSelected ? 1.15 : 1.0)
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

    // MARK: - Symbol grid

    @ViewBuilder
    private var symbolGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(IconStyle.symbolGroups, id: \.label) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.label.uppercased())
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 6),
                        spacing: 4
                    ) {
                        ForEach(group.symbols, id: \.self) { symbol in
                            symbolCell(symbol)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func symbolCell(_ symbol: String) -> some View {
        let isSelected = favorite.iconSymbol == symbol

        Button {
            state.updateLibraryIcon(
                favorite,
                symbol: symbol,
                color: favorite.iconColor
            )
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? resolvedColor : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? resolvedColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isSelected ? resolvedColor : Color.gray.opacity(0.2),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(symbol)
    }
}
