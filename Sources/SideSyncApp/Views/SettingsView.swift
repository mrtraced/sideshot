import SwiftUI
import AppKit
import SideSyncLib

/// Top-level Settings window. Six tabs, each a focused subview.
struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            CloudSettingsTab()
                .tabItem { Label("Cloud", systemImage: "icloud") }
            BehaviorSettingsTab()
                .tabItem { Label("Behavior", systemImage: "slider.horizontal.3") }
            SnapshotsSettingsTab()
                .tabItem { Label("Snapshots", systemImage: "camera") }
            ResetSettingsTab()
                .tabItem { Label("Reset", systemImage: "arrow.counterclockwise.circle") }
            DiagnosticsSettingsTab()
                .tabItem { Label("Diagnostics", systemImage: "wrench.and.screwdriver") }
        }
        .padding(20)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(AppState.self) private var state
    @State private var editedMachineName: String = ""

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Identity") {
                HStack {
                    TextField("Machine name", text: $editedMachineName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitMachineName() }
                    Button("Save") { commitMachineName() }
                        .disabled(editedMachineName.trimmingCharacters(in: .whitespaces).isEmpty
                                  || editedMachineName == state.machineId)
                }
                Text("Used to identify this machine in cross-machine snapshots and Library paths. Renaming creates a new identity — old paths under the previous name stay until cleaned up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Defaults") {
                Picker("Default library sort:", selection: Binding(
                    get: { state.librarySort },
                    set: { state.librarySort = $0; persistDefaultSort($0) }
                )) {
                    ForEach(AppState.LibrarySort.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Toggle(
                    "Default to \"Save Current & Apply\" in the Apply dialog",
                    isOn: Binding(
                        get: { state.config.saveBeforeApplyDefault },
                        set: { v in
                            state.config.saveBeforeApplyDefault = v
                            persistConfig()
                        }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .onAppear { editedMachineName = state.machineId }
    }

    private func commitMachineName() {
        let new = editedMachineName.trimmingCharacters(in: .whitespaces)
        guard !new.isEmpty, new != state.machineId else { return }
        state.machineId = new
        state.config.machineId = new
        try? state.configService.write(state.config)
        state.statusMessage = "Machine name set to \"\(new)\""
    }

    private func persistDefaultSort(_ mode: AppState.LibrarySort) {
        state.config.defaultLibrarySort = mode.settingKey
        persistConfig()
    }

    private func persistConfig() {
        try? state.configService.write(state.config)
    }
}

// MARK: - Cloud

private struct CloudSettingsTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Section("Cloud Sync Location") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.cloudDirectoryPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    HStack {
                        Button("Change…") { pickDirectory() }
                        Button("Reveal in Finder") { state.revealCloudFileInFinder() }
                        if state.config.cloudSyncDirectory != nil {
                            Button("Restore iCloud Default") {
                                state.resetCloudDirectoryToDefault()
                            }
                        }
                    }
                }

                Text("Where favorites.json is stored. Defaults to iCloud Drive so SideShot syncs between your Macs automatically. You can move it to Dropbox, Google Drive, or any cloud-synced folder — or a local folder if you prefer not to sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose where SideShot stores its cloud sync file"
        panel.prompt = "Use Folder"

        if panel.runModal() == .OK, let url = panel.url {
            // Ask whether to migrate existing data
            let alert = NSAlert()
            alert.messageText = "Move existing data to the new location?"
            alert.informativeText = "Choose Move to relocate favorites.json. Choose Start Fresh to leave the old file in place and begin a new one at \(url.lastPathComponent)."
            alert.addButton(withTitle: "Move")
            alert.addButton(withTitle: "Start Fresh")
            alert.addButton(withTitle: "Cancel")
            let resp = alert.runModal()
            switch resp {
            case .alertFirstButtonReturn:
                state.setCloudDirectory(url, migrateExisting: true)
            case .alertSecondButtonReturn:
                state.setCloudDirectory(url, migrateExisting: false)
            default:
                break
            }
        }
    }
}

// MARK: - Behavior

private struct BehaviorSettingsTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Section("On Launch") {
                Toggle("Auto-import current Finder sidebar items into Library", isOn: bind(\.autoImportOnLaunch))
                Toggle("Seed standard macOS locations into Library", isOn: bind(\.seedDefaultsOnLaunch))
                Text("These run once on launch. Disabling them won't remove items already in your Library; it just stops new ones from being added automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Apply") {
                Toggle(
                    "Write custom SF Symbol icons to folders on Apply",
                    isOn: bind(\.writeFinderIconsOnApply)
                )
                Text("When on, each Library item's custom icon is rendered to a multi-resolution NSImage and written onto the corresponding folder via NSWorkspace. Some folders (Applications, iCloud Drive root, read-only volumes) refuse this and will be reported in the status message.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private func bind(_ key: WritableKeyPath<LocalConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { state.config[keyPath: key] },
            set: { v in
                var newConfig = state.config
                newConfig[keyPath: key] = v
                state.config = newConfig
                try? state.configService.write(state.config)
            }
        )
    }
}

// MARK: - Snapshots

private struct SnapshotsSettingsTab: View {
    @Environment(AppState.self) private var state
    @State private var limit: Int = 0

    var body: some View {
        Form {
            Section("Retention") {
                Stepper(
                    "Max snapshots per machine: \(limit == 0 ? "Unlimited" : "\(limit)")",
                    value: $limit,
                    in: 0...100,
                    step: 1
                )
                .onChange(of: limit) { _, newValue in
                    state.config.maxSnapshotsPerMachine = newValue
                    try? state.configService.write(state.config)
                }

                Text("0 means no automatic pruning. When set higher than 0, saving a new snapshot for this machine prunes the oldest beyond the limit. Other machines' snapshots are left alone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Manual") {
                Button("Prune now") {
                    state.pruneSnapshotsIfNeeded()
                }
                .disabled(limit == 0)
                Text("Runs the same prune logic immediately against this machine's current snapshot list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { limit = state.config.maxSnapshotsPerMachine }
    }
}

// MARK: - Reset

private struct ResetSettingsTab: View {
    @Environment(AppState.self) private var state

    @State private var showRestoreIgnoredConfirm = false
    @State private var showDeleteArchivedConfirm = false
    @State private var showResetConfigConfirm = false
    @State private var keepMachineNameOnReset = true
    @State private var showWipeCloudConfirm = false

    var body: some View {
        Form {
            Section("Library") {
                actionRow(
                    title: "Restore Ignored Items",
                    description: "Clears the list of items you've deleted from Library. On next launch the standard defaults and current sidebar items will be re-imported.",
                    actionTitle: "Restore",
                    role: nil
                ) {
                    showRestoreIgnoredConfirm = true
                }

                actionRow(
                    title: "Delete All Archived Items",
                    description: "Permanently removes every archived Library record. Hard delete — can't be undone.",
                    actionTitle: "Delete All",
                    role: .destructive
                ) {
                    showDeleteArchivedConfirm = true
                }
            }

            Section("App") {
                actionRow(
                    title: "Reset Local App Config",
                    description: "Clears Pending, path overrides, hidden items, ignored keys, and behavior settings on this machine. Cloud data (Library, snapshots) is untouched.",
                    actionTitle: "Reset",
                    role: .destructive
                ) {
                    showResetConfigConfirm = true
                }
            }

            Section("Cloud") {
                actionRow(
                    title: "Wipe Cloud Sync File",
                    description: "Permanently deletes the cloud favorites.json. Other machines lose access to the shared Library and snapshots on next sync. Use only if you want to start over completely.",
                    actionTitle: "Wipe",
                    role: .destructive
                ) {
                    showWipeCloudConfirm = true
                }
            }
        }
        .formStyle(.grouped)
        .alert("Restore ignored items?", isPresented: $showRestoreIgnoredConfirm) {
            Button("Restore") { state.restoreIgnoredLibraryItems() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items you've deleted will be eligible for auto-import again on next launch.")
        }
        .alert("Delete all archived items?", isPresented: $showDeleteArchivedConfirm) {
            Button("Delete All", role: .destructive) { state.deleteAllArchived() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .alert("Reset local app config?", isPresented: $showResetConfigConfirm) {
            Toggle("Keep machine name", isOn: $keepMachineNameOnReset)
            Button("Reset", role: .destructive) {
                state.resetLocalConfig(keepMachineName: keepMachineNameOnReset)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears local Pending draft, path overrides, hidden items, ignored keys, and behavior toggles. Cloud Library and snapshots are preserved.")
        }
        .alert("Wipe cloud sync file?", isPresented: $showWipeCloudConfirm) {
            Button("Wipe", role: .destructive) { state.wipeCloudFile() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes the favorites.json. Other machines on this iCloud will lose access to the shared Library and snapshots.")
        }
    }

    @ViewBuilder
    private func actionRow(
        title: String,
        description: String,
        actionTitle: String,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(actionTitle, role: role, action: action)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Diagnostics

private struct DiagnosticsSettingsTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Section("Files") {
                pathRow(
                    label: "Cloud sync file",
                    path: state.cloudDirectoryPath + "/favorites.json",
                    reveal: { state.revealCloudFileInFinder() }
                )
                pathRow(
                    label: "Local config",
                    path: state.configFilePath,
                    reveal: { state.revealConfigFileInFinder() }
                )
            }

            Section("Build") {
                LabeledContent("Machine") { Text(state.machineId).textSelection(.enabled) }
                LabeledContent("Library items") { Text("\(state.libraryItems.count) active / \(state.archivedLibraryItems.count) archived") }
                LabeledContent("Pending items") { Text("\(state.pending.count)") }
                LabeledContent("Snapshots (this machine)") { Text("\(state.snapshotsForMachine(state.machineId).count)") }
                LabeledContent("Known machines") { Text(state.knownMachines.joined(separator: ", ")) }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func pathRow(label: String, path: String, reveal: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("Reveal") { reveal() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
