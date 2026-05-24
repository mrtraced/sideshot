import SwiftUI
import SideSyncLib

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            splitView
            statusBar
        }
    }

    @ViewBuilder
    private var splitView: some View {
        @Bindable var state = state

        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } content: {
            ZStack {
                PendingPaneView()
                if state.showSnapshotDrawer {
                    SnapshotDrawerView()
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.32), value: state.showSnapshotDrawer)
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            VSplitView {
                EditPaneView()
                    .frame(minHeight: 160, idealHeight: 220)

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
        .sheet(isPresented: $state.showSaveSnapshotSheet) {
            SaveSnapshotSheet(onSaved: {
                if let target = state.pendingApplyAfterSave {
                    state.pendingApplyAfterSave = nil
                    state.replaceSidebar(with: target)
                } else if state.pendingApplyToFinderAfterSave {
                    state.pendingApplyToFinderAfterSave = false
                    state.applyPendingToFinder()
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
        .sheet(isPresented: $state.showApplyPendingConfirm) {
            ApplyPendingPreviewSheet()
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
            .frame(maxWidth: .infinity)
            .background(.bar)
            .overlay(Divider(), alignment: .top)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        state.statusMessage = nil
                        state.errorMessage = nil
                    }
                }
            }
        }
    }
}
