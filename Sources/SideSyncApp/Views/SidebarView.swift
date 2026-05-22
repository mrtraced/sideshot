import SwiftUI
import SideSyncLib

/// Left column.
/// Default mode: read-only mirror of the live Finder sidebar.
/// Drawer mode: machines list with expandable per-machine snapshot pickers.
struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            if state.showSnapshotDrawer {
                MachinesBrowserPane()
                    .transition(.opacity)
            } else {
                CurrentSidebarPane()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: state.showSnapshotDrawer)
    }
}

// MARK: - Default mode: Current Sidebar

private struct CurrentSidebarPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Current Sidebar")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("read-only")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if state.localFavorites.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No favorites found")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.localFavorites) { fav in
                        CurrentRow(fav: fav)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.06))
            }
        }
        .background(Color.gray.opacity(0.04))
    }
}

private struct CurrentRow: View {
    @Environment(AppState.self) private var state
    let fav: SidebarFavorite

    var body: some View {
        let exists = PathResolver.exists(fav.path)
        let inLibrary = state.libraryItem(matchingPath: fav.path) != nil
        let inPending = state.pending.contains(where: { sameItem($0.path, fav.path) })

        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(fav.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if exists {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                            .help("Path exists on this machine")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                            .help("Path not found")
                    }
                    if inLibrary {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue.opacity(0.7))
                            .help("Also in Item Library")
                    }
                    if inPending {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange.opacity(0.8))
                            .help("Also in Pending")
                    }
                }
                Text(abbreviatePath(fav.path))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 1)
        .help(fav.path)
    }

    private func sameItem(_ a: String, _ b: String) -> Bool {
        let na = a.hasSuffix("/") ? String(a.dropLast()) : a
        let nb = b.hasSuffix("/") ? String(b.dropLast()) : b
        return na == nb
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - Drawer mode: Machines + snapshot picker

private struct MachinesBrowserPane: View {
    @Environment(AppState.self) private var state
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.indigo)
                Text("Machines")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(state.knownMachines.count)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if state.knownMachines.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "laptopcomputer.slash")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No machines yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.knownMachines, id: \.self) { machine in
                        MachineRow(
                            machine: machine,
                            isExpanded: expanded.contains(machine),
                            onToggle: {
                                if expanded.contains(machine) {
                                    expanded.remove(machine)
                                } else {
                                    expanded.insert(machine)
                                }
                            }
                        )
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(Color.indigo.opacity(0.04))
                .onAppear {
                    // Auto-expand this machine by default so the user sees their snapshots immediately
                    expanded.insert(state.machineId)
                    // Auto-select the most recent snapshot if nothing chosen yet
                    if state.drawerSnapshotId == nil,
                       let first = state.snapshotsForMachine(state.machineId).first {
                        state.drawerSnapshotId = first.id
                        state.drawerMachineId = state.machineId
                    }
                }
            }
        }
        .background(Color.indigo.opacity(0.02))
    }
}

private struct MachineRow: View {
    @Environment(AppState.self) private var state
    let machine: String
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        let isMe = machine == state.machineId
        let snapshots = state.snapshotsForMachine(machine)

        VStack(alignment: .leading, spacing: 2) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: snapshots.isEmpty ? "chevron.right" : (isExpanded ? "chevron.down" : "chevron.right"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(snapshots.isEmpty ? Color.gray.opacity(0.3) : Color.secondary)
                        .frame(width: 10)
                    Image(systemName: isMe ? "desktopcomputer" : "laptopcomputer")
                        .font(.system(size: 12))
                        .foregroundStyle(isMe ? Color.indigo : Color.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(machine)
                                .font(.system(size: 12, weight: isMe ? .semibold : .regular))
                                .lineLimit(1)
                            if isMe {
                                Text("(this)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.indigo)
                            }
                        }
                        Text("\(snapshots.count) snapshot\(snapshots.count == 1 ? "" : "s")")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(snapshots.isEmpty)

            if isExpanded {
                ForEach(snapshots) { snap in
                    SnapshotPickerRow(snapshot: snap)
                        .padding(.leading, 22)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SnapshotPickerRow: View {
    @Environment(AppState.self) private var state
    let snapshot: SidebarSnapshot

    var body: some View {
        let isSelected = state.drawerSnapshotId == snapshot.id

        Button {
            state.drawerSnapshotId = snapshot.id
            state.drawerMachineId = snapshot.machineId
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.name)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    Text(snapshot.timestamp, format: .dateTime.month().day().hour().minute())
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                Text("\(snapshot.items.count)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
