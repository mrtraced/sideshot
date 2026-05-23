import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// A sidebar item being dragged between panes (Current, Pending, Library).
/// Carries enough context for the drop target to do the right thing.
struct DraggedSidebarItem: Codable, Transferable {
    enum Source: String, Codable {
        case library  // identifier = CloudFavorite.id
        case pending  // identifier = PendingItem.id
        case current  // identifier = "" (use name + path)
    }

    let source: Source
    let identifier: String
    let name: String
    let path: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .sideshotSidebarItem)
    }
}

extension UTType {
    /// Private UTI for our in-app drag payload. Distinct from public.folder so the
    /// drop targets only accept items dragged from inside SideSync.
    static let sideshotSidebarItem = UTType(exportedAs: "com.sidesync.sidebar-item")
}
