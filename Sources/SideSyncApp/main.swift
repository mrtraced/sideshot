import AppKit

// SPM-built executables don't get an app bundle, so we must set the
// activation policy BEFORE SwiftUI creates the NSApplication instance.
// This makes the app appear in the Dock and show windows properly.
NSApplication.shared.setActivationPolicy(.regular)

// Now hand off to SwiftUI's App lifecycle
SideSyncApp.main()
