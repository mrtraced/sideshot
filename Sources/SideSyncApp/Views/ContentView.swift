import SwiftUI
import SideSyncLib

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            PendingPaneView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 480)
        } detail: {
            VSplitView {
                EditPaneView()
                    .frame(minHeight: 120, idealHeight: 180)

                LibraryPaneView()
                    .frame(minHeight: 200)
            }
        }
        .toolbar {
            SideSyncToolbar()
        }
        .sheet(isPresented: $state.showDeleteConfirm) {
            if let favorite = state.pendingDeleteFavorite {
                DeleteConfirmSheet(favorite: favorite)
            }
        }
        .sheet(isPresented: $state.showSaveBeforeApply) {
            if let favorite = state.pendingApplyFavorite {
                SaveBeforeApplySheet(favorite: favorite)
            }
        }
        .sheet(isPresented: $state.showMachinesBrowser) {
            MachinesBrowserSheet()
        }
        .sheet(isPresented: $state.showSaveSnapshotSheet) {
            SaveSnapshotSheet(onSaved: {
                if let target = state.pendingApplyAfterSave {
                    state.pendingApplyAfterSave = nil
                    state.replaceSidebar(with: target)
                }
            })
        }
        .sheet(isPresented: $state.showApplySnapshotConfirm) {
            if let snap = state.pendingApplySnapshot {
                ApplySnapshotSheet(snapshot: snap)
            }
        }
        .alert("Reset pending sidebar?", isPresented: $state.showResetPendingConfirm) {
            Button("Reset", role: .destructive) { state.resetPendingToCurrent() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pending will be replaced with the current Finder sidebar. Any in-progress edits will be lost.")
        }
        .alert("Delete pending sidebar?", isPresented: $state.showDeletePendingConfirm) {
            Button("Delete", role: .destructive) { state.clearPending() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes all items from pending. The Library is unaffected.")
        }
        .alert("Apply pending to Finder?", isPresented: $state.showApplyPendingConfirm) {
            Button("Apply", role: .destructive) {
                state.errorMessage = "Apply lands in P2 — coming next."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will land in Phase 2 — wired in next round.")
        }
        .overlay(alignment: .bottom) {
            statusBar
        }
    }

    @ViewBuilder
    private var statusBar: some View {
        if let msg = state.statusMessage ?? state.errorMessage {
            HStack {
                if state.errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(state.errorMessage != nil ? .red : .secondary)
                Spacer()
                Text("Machine: \(state.machineId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    state.statusMessage = nil
                    state.errorMessage = nil
                }
            }
        }
    }
}
