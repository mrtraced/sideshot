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

    static func decode(from providers: [NSItemProvider]) async -> [DraggedSidebarItem] {
        var out: [DraggedSidebarItem] = []
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { continue }
            do {
                let data = try await provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier)
                if let item = try? JSONDecoder().decode(DraggedSidebarItem.self, from: data) {
                    out.append(item)
                }
            } catch {
                continue
            }
        }
        return out
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
