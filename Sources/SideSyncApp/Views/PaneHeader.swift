import SwiftUI

/// Standard header bar for the three main panes (Current, Pending, Library) and
/// for the snapshot drawer. Consistent height, padding, divider, and font.
struct PaneHeader<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let iconHelp: String?
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: String,
        iconColor: Color = .secondary,
        iconHelp: String? = nil,
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconHelp = iconHelp
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(iconColor)
                .help(iconHelp ?? "")

            Text(title)
                .font(Theme.Font_.paneHeader)

            Spacer()

            trailing()
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.sm + 1)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Colors.borderSubtle)
                .frame(height: 1)
        }
    }
}
