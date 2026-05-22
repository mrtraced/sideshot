import Foundation
import CoreServices

// MARK: - LSSharedFileList API via dlsym

/// Wraps the deprecated-but-functional LSSharedFileList C API.
/// All symbols are loaded at runtime via dlsym so we don't need SDK headers.
public final class SidebarService {
    // Function type aliases matching the C signatures.
    // Note: sentinel constants (kLSSharedFileListItemLast etc.) are tiny pointer values
    // (0x1, 0x2) that cannot be passed as real LSSharedFileListItem objects — they would
    // crash on retain. We use UnsafeRawPointer? for the "afterItem" parameter instead.
    private typealias CreateFunc = @convention(c) (
        CFAllocator?, CFString, UnsafeMutableRawPointer?
    ) -> Unmanaged<LSSharedFileList>?

    private typealias SnapshotFunc = @convention(c) (
        LSSharedFileList, UnsafeMutablePointer<UInt32>
    ) -> Unmanaged<CFArray>?

    private typealias InsertItemURLFunc = @convention(c) (
        LSSharedFileList, UnsafeRawPointer?, CFString?, IconRef?, CFURL,
        CFDictionary?, CFArray?
    ) -> Unmanaged<LSSharedFileListItem>?

    private typealias RemoveItemFunc = @convention(c) (
        LSSharedFileList, LSSharedFileListItem
    ) -> OSStatus

    private typealias DisplayNameFunc = @convention(c) (
        LSSharedFileListItem
    ) -> Unmanaged<CFString>?

    private typealias ResolveFunc = @convention(c) (
        LSSharedFileListItem, UInt32,
        UnsafeMutablePointer<Unmanaged<CFURL>?>?,
        UnsafeMutablePointer<Unmanaged<CFError>?>?
    ) -> OSStatus

    private typealias MoveItemFunc = @convention(c) (
        LSSharedFileList, LSSharedFileListItem, UnsafeRawPointer?
    ) -> OSStatus

    // Loaded function pointers
    private let createList: CreateFunc
    private let copySnapshot: SnapshotFunc
    private let insertItemURL: InsertItemURLFunc
    private let removeItem: RemoveItemFunc
    private let displayNameFn: DisplayNameFunc
    private let resolveItem: ResolveFunc
    private let moveItem: MoveItemFunc

    // Constants
    private let kFavoriteItems: CFString
    /// Sentinel value for "insert after last item" — NOT a real CF object.
    private let kItemLast: UnsafeRawPointer?
    /// Sentinel value for "insert before first item" — NOT a real CF object.
    private let kItemBeforeFirst: UnsafeRawPointer?

    private let handle: UnsafeMutableRawPointer

    public init() throws {
        guard let h = dlopen(
            "/System/Library/Frameworks/CoreServices.framework/CoreServices",
            RTLD_LAZY
        ) else {
            throw SideSyncError.apiUnavailable("Cannot open CoreServices framework")
        }
        self.handle = h

        func loadSym<T>(_ name: String) throws -> T {
            guard let sym = dlsym(h, name) else {
                throw SideSyncError.apiUnavailable("Symbol \(name) not found")
            }
            return unsafeBitCast(sym, to: T.self)
        }

        self.createList = try loadSym("LSSharedFileListCreate")
        self.copySnapshot = try loadSym("LSSharedFileListCopySnapshot")
        self.insertItemURL = try loadSym("LSSharedFileListInsertItemURL")
        self.removeItem = try loadSym("LSSharedFileListItemRemove")
        self.displayNameFn = try loadSym("LSSharedFileListItemCopyDisplayName")
        self.resolveItem = try loadSym("LSSharedFileListItemResolve")
        self.moveItem = try loadSym("LSSharedFileListItemMove")

        // Load CFString constant (indirected — pointer to a pointer)
        let favPtr = dlsym(h, "kLSSharedFileListFavoriteItems")!
        self.kFavoriteItems = Unmanaged<CFString>.fromOpaque(
            favPtr.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
        ).takeUnretainedValue()

        // Load sentinel constants as raw pointers (NOT CF objects — just tiny integers)
        let lastPtr = dlsym(h, "kLSSharedFileListItemLast")!
        self.kItemLast = lastPtr.load(as: UnsafeRawPointer?.self)

        let firstPtr = dlsym(h, "kLSSharedFileListItemBeforeFirst")!
        self.kItemBeforeFirst = firstPtr.load(as: UnsafeRawPointer?.self)
    }

    deinit {
        dlclose(handle)
    }

    // MARK: - Public API

    /// Read all current Finder sidebar favorites.
    public func readFavorites() throws -> [SidebarFavorite] {
        let list = try getListRef()
        let items = try getSnapshot(list)

        var favorites: [SidebarFavorite] = []
        for item in items {
            let name = displayNameFn(item)?.takeRetainedValue() as String? ?? "(unknown)"

            var urlRef: Unmanaged<CFURL>?
            let status = resolveItem(item, 0, &urlRef, nil)
            guard status == noErr, let cfURL = urlRef?.takeRetainedValue() else {
                continue
            }
            let url = cfURL as URL
            favorites.append(SidebarFavorite(name: name, path: url.path, url: url))
        }
        return favorites
    }

    /// Add a folder to the Finder sidebar at the end.
    @discardableResult
    public func addFavorite(name: String, path: String) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        let list = try getListRef()

        guard let _ = insertItemURL(
            list, kItemLast, name as CFString, nil, url as CFURL, nil, nil
        )?.takeRetainedValue() else {
            return false
        }
        return true
    }

    /// Add a folder to the Finder sidebar after a specific existing item (by name).
    /// If afterName is nil, inserts at the end.
    @discardableResult
    public func addFavorite(name: String, path: String, afterName: String?) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        let list = try getListRef()

        guard let afterName = afterName else {
            // No positioning requested — insert at end
            return insertItemURL(
                list, kItemLast, name as CFString, nil, url as CFURL, nil, nil
            )?.takeRetainedValue() != nil
        }

        // Get snapshot and find the target item. We must keep the entire snapshot
        // array alive through the insertItemURL call because the C function does
        // objc_retain on the afterItem — if the snapshot is deallocated, the item
        // pointer is dangling and we get EXC_BAD_ACCESS.
        let items = try getSnapshot(list)

        return withExtendedLifetime(items) {
            var targetItem: LSSharedFileListItem?
            for item in items {
                let itemName = displayNameFn(item)?.takeRetainedValue() as String? ?? ""
                if itemName == afterName {
                    targetItem = item
                    break
                }
            }

            guard let target = targetItem else {
                // Target not found — fall back to inserting at end
                return insertItemURL(
                    list, kItemLast, name as CFString, nil, url as CFURL, nil, nil
                )?.takeRetainedValue() != nil
            }

            let afterPtr = UnsafeRawPointer(Unmanaged.passUnretained(target).toOpaque())
            return insertItemURL(
                list, afterPtr, name as CFString, nil, url as CFURL, nil, nil
            )?.takeRetainedValue() != nil
        }
    }

    /// Remove a favorite by name. Returns true if found and removed.
    @discardableResult
    public func removeFavorite(named name: String) throws -> Bool {
        let list = try getListRef()
        let items = try getSnapshot(list)

        for item in items {
            let itemName = displayNameFn(item)?.takeRetainedValue() as String? ?? ""
            if itemName == name {
                let status = removeItem(list, item)
                return status == noErr
            }
        }
        return false
    }

    /// Remove all favorites from the Finder sidebar. Returns the count removed.
    @discardableResult
    public func removeAllFavorites() throws -> Int {
        let list = try getListRef()
        let items = try getSnapshot(list)
        var removed = 0
        for item in items {
            if removeItem(list, item) == noErr {
                removed += 1
            }
        }
        return removed
    }

    /// Check if a favorite with the given name already exists in the sidebar.
    public func hasFavorite(named name: String) throws -> Bool {
        let favorites = try readFavorites()
        return favorites.contains { $0.name == name }
    }

    // MARK: - Private Helpers

    private func getListRef() throws -> LSSharedFileList {
        guard let ref = createList(kCFAllocatorDefault, kFavoriteItems, nil)?
            .takeRetainedValue()
        else {
            throw SideSyncError.apiUnavailable("Failed to create list reference")
        }
        return ref
    }

    private func getSnapshot(_ list: LSSharedFileList) throws -> [LSSharedFileListItem] {
        var seed: UInt32 = 0
        guard let items = copySnapshot(list, &seed)?
            .takeRetainedValue() as? [LSSharedFileListItem]
        else {
            throw SideSyncError.apiUnavailable("Failed to read sidebar snapshot")
        }
        return items
    }
}
