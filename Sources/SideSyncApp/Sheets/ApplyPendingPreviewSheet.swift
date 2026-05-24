import SwiftUI
import SideSyncLib

/// Replaces the old plain-alert Apply confirm with a sheet that shows the
/// user a concrete diff between Pending and the live Finder sidebar before
/// they commit. Three sections (Added / Removed / Reordered) + Save & Apply,
/// Apply, Cancel.
struct ApplyPendingPreviewSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let diff = state.pendingDiff

        VStack(spacing: 0) {
            header

            Divider()

            if diff.isEmpty {
                noChanges
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !diff.added.isEmpty { addedSection(diff.added) }
                        if !diff.removed.isEmpty { removedSection(diff.removed) }
                        if !diff.reordered.isEmpty { reorderedSection(diff.reordered) }
                    }
                    .padding(16)
                }
            }

            Divider()

            footer(diff: diff)
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - Header / footer

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apply Pending to Finder")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(state.pending.count) item\(state.pending.count == 1 ? "" : "s") in Pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    @ViewBuilder
    private func footer(diff: AppState.PendingDiff) -> some View {
        HStack(spacing: 10) {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            if state.config.saveBeforeApplyDefault {
                Button("Apply", role: .destructive) {
                    dismiss()
                    state.applyPendingToFinder()
                }
                .buttonStyle(.bordered)

                Button("Save Current & Apply") {
                    dismiss()
                    state.pendingApplyToFinderAfterSave = true
                    state.showSaveSnapshotSheet = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Save Current & Apply") {
                    dismiss()
                    state.pendingApplyToFinderAfterSave = true
                    state.showSaveSnapshotSheet = true
                }
                .buttonStyle(.bordered)

                Button("Apply", role: .destructive) {
                    dismiss()
                    state.applyPendingToFinder()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    @ViewBuilder
    private var noChanges: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            Text("Pending matches Current")
                .font(.system(size: 13, weight: .medium))
            Text("Apply will rebuild the sidebar in the same order — no visible changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sections

    @ViewBuilder
    private func addedSection(_ items: [AppState.PendingDiff.Entry]) -> some View {
        sectionHeader(
            icon: "plus.circle.fill",
            color: .green,
            title: "Added",
            count: items.count
        )
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                row(icon: "plus", color: .green, name: item.name, secondary: abbreviate(item.path))
            }
        }
    }

    @ViewBuilder
    private func removedSection(_ items: [AppState.PendingDiff.Entry]) -> some View {
        sectionHeader(
            icon: "minus.circle.fill",
            color: .red,
            title: "Removed",
            count: items.count
        )
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                row(icon: "minus", color: .red, name: item.name, secondary: abbreviate(item.path))
            }
        }
    }

    @ViewBuilder
    private func reorderedSection(_ items: [AppState.PendingDiff.Reorder]) -> some View {
        sectionHeader(
            icon: "arrow.up.arrow.down.circle.fill",
            color: .orange,
            title: "Reordered",
            count: items.count
        )
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .frame(width: 14)
                    Text(item.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer()
                    Text("#\(item.fromIndex + 1)  →  #\(item.toIndex + 1)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(icon: String, color: Color, title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 12))
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func row(icon: String, color: Color, name: String, secondary: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
            Text(secondary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}
