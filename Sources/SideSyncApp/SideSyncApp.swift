import SwiftUI
import AppKit
import SideSyncLib

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared AppState, set during init from SideSyncApp so the delegate can
    /// inspect pending changes when the user tries to quit.
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Intercept quit and offer to apply Pending if it differs from Current.
    /// Returning .terminateLater suspends termination while the alert is up;
    /// we call NSApp.reply(toApplicationShouldTerminate:) once the user picks.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let state = appState, !state.pendingDiff.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Apply Pending changes before quitting?"
        let diff = state.pendingDiff
        var bullets: [String] = []
        if !diff.added.isEmpty { bullets.append("• \(diff.added.count) added") }
        if !diff.removed.isEmpty { bullets.append("• \(diff.removed.count) removed") }
        if !diff.reordered.isEmpty { bullets.append("• \(diff.reordered.count) reordered") }
        alert.informativeText =
            "Your Pending sidebar differs from the Finder sidebar:\n" +
            bullets.joined(separator: "\n") +
            "\n\nQuitting now leaves the Finder sidebar unchanged."

        alert.alertStyle = .warning
        alert.addButton(withTitle: "Apply & Quit")       // default
        alert.addButton(withTitle: "Quit Without Applying")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            state.applyPendingToFinder()
            return .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}

struct SideSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear { delegate.appState = appState }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 600)

        // Native Settings window — ⌘, and menu bar > SideSync > Settings…
        Settings {
            SettingsView()
                .environment(appState)
                .frame(width: 560, height: 460)
        }
    }
}
