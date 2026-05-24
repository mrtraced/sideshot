import Foundation
import AppKit
import UniformTypeIdentifiers

extension UTType {
    /// The UTI registered in Info.plist (UTExportedTypeDeclarations) for our
    /// in-process drag payload. Both sides of the drag must reference this.
    static let sideshotSidebarItem = UTType(importedAs: "com.sideshot.sidebar-item")
}

/// A sidebar item being dragged between panes (Current, Pending, Library).
/// Encoded as JSON inside an NSItemProvider with a private UTI string.
struct DraggedSidebarItem: Codable {
    enum Source: String, Codable {
        case library  // identifier = CloudFavorite.id
        case pending  // identifier = PendingItem.id
        case current  // identifier = "" (use name + path)
    }

    let source: Source
    let identifier: String
    let name: String
    let path: String

    /// Private UTI string used as the typeIdentifier for the NSItemProvider.
    /// Both ends of the drag must reference this same string.
    static let typeIdentifier = "com.sideshot.sidebar-item"

    func makeItemProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: Self.typeIdentifier,
            visibility: .ownProcess
        ) { completion in
            do {
                let data = try JSONEncoder().encode(self)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
        return provider
    }

    /// Result of decoding a batch of providers. `accepted` is the items the
    /// drop handler should process. `rejectedFiles` are non-folder file URLs
    /// the user dragged (we surface these in the status bar so the user knows
    /// why nothing happened). `failedURLs` are providers we couldn't load at
    /// all (rare; usually permissions or sandbox).
    struct DecodeResult {
        var accepted: [DraggedSidebarItem] = []
        var rejectedFiles: [String] = []  // non-folder names
        var failedURLs: Int = 0
    }

    static func decode(from providers: [NSItemProvider]) async -> DecodeResult {
        var result = DecodeResult()
        for provider in providers {
            // 1. SideShot's internal payload (preferred, carries source/identifier)
            if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                if let data = try? await provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier),
                   let item = try? JSONDecoder().decode(DraggedSidebarItem.self, from: data) {
                    result.accepted.append(item)
                    continue
                }
            }

            // 2. Folder URL dragged in from Finder (or any app exporting public.file-url).
            //    Treat as a .current-source item — same handlers that work for
            //    in-app current rows will ensureLibraryEntry and link.
            if provider.canLoadObject(ofClass: URL.self) {
                guard let url = await loadURL(from: provider), url.isFileURL else {
                    result.failedURLs += 1
                    continue
                }
                if isDirectory(at: url) {
                    result.accepted.append(DraggedSidebarItem(
                        source: .current,
                        identifier: "",
                        name: url.lastPathComponent,
                        path: url.path
                    ))
                } else {
                    result.rejectedFiles.append(url.lastPathComponent)
                }
            }
        }
        return result
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }
        return isDir.boolValue
    }
}

private extension NSItemProvider {
    /// async wrapper around the callback-based loadDataRepresentation.
    func loadDataRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = self.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadCorruptFile))
                }
            }
        }
    }
}
