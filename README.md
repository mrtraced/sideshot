# sideshot

**macOS's Sidebar Synchronization and Snapshot tool.** Need to make sure different machines have the same sidebars, even with different paths? Now you can do it in one place.

Snapshot your macOS Finder sidebar, save reusable items to a library, and apply named sidebar layouts to any of your Macs. SideShot treats your Finder sidebar like a document you can version, share across machines, and swap out at will — not a continuous sync tool. You explicitly take snapshots and explicitly apply them.

## Features

- **Current Sidebar** — read-only mirror of the live Finder sidebar on this machine.
- **Pending Sidebar** — a persistent working draft. Compose what you want your sidebar to become, then apply it.
- **Snapshots** — named captures of a sidebar, stored in iCloud Drive so any of your Macs can apply them.
- **Item Library** — a flat pool of reusable favorites you can pull into Pending.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9 toolchain (Xcode 15+ or Swift CLI)
- iCloud Drive enabled (for cross-machine snapshots and library sync)

## Build

```bash
# Compile and bundle the app
bash build-app.sh

# Open it
open SideSync.app

# Or install to /Applications
bash install.sh
```

A CLI is also available:

```bash
swift run sidesync --help
```

## Status

Active development. The UI is being restructured around the snapshot model in phases:

- **Phase 1 (current)** — three-pane layout, pending working draft, item library, take/save snapshots.
- **Phase 2** — editing in Pending (rename, change path), drag from Library/Current into Pending, apply Pending → Finder.
- **Phase 3** — snapshot picker drawer, drag-drop polish, per-favorite icon customization.

## License

[MIT](LICENSE)
