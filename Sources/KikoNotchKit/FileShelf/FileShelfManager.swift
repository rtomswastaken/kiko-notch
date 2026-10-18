import Foundation
import AppKit

/// Manages temporary file staging and native sharing on the Kiko Notch File Shelf
public final class FileShelfManager: ObservableObject, @unchecked Sendable {
    public static let shared = FileShelfManager()
    
    @Published public private(set) var items: [FileShelfItem] = []
    
    private init() {}
    
    /// Staged file addition from drag-and-drop or file selection
    public func addFiles(urls: [URL]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var newItems = self.items
            for url in urls {
                // Avoid duplicating exact same file path
                if !newItems.contains(where: { $0.url.path == url.path }) {
                    let item = FileShelfItem(url: url)
                    newItems.insert(item, at: 0)
                }
            }
            self.items = newItems
        }
    }
    
    public func removeItem(id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.items.removeAll { $0.id == id }
        }
    }
    
    public func removeItem(with id: UUID) {
        removeItem(id: id)
    }
    
    public func clearAll() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.items.removeAll()
        }
    }
    
    public func openFile(item: FileShelfItem) {
        NSWorkspace.shared.open(item.url)
    }
    
    public func openItem(with id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            openFile(item: item)
        }
    }
    
    public func revealInFinder(item: FileShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    public func revealItemInFinder(with id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            revealInFinder(item: item)
        }
    }
    
    /// Native macOS Share Sheet & AirDrop integration via NSSharingServicePicker
    public func shareFiles(items: [FileShelfItem], from view: NSView, rect: NSRect) {
        guard !items.isEmpty else { return }
        let urls = items.map { $0.url }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }
}
