import SwiftUI
import AppKit

/// Context menu builder and modifier for File Shelf items
public struct FileShelfContextMenu: ViewModifier {
    @ObservedObject public var item: FileShelfItem
    
    public func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                FileShelfManager.shared.openFile(item: item)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .accessibilityLabel("Open file \(item.name)")
            
            Button {
                FileShelfManager.shared.revealInFinder(item: item)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            .accessibilityLabel("Show \(item.name) in Finder")
            
            Divider()
            
            Button {
                let picker = NSSharingServicePicker(items: [item.url])
                if let keyWindow = NSApp.keyWindow, let contentView = keyWindow.contentView {
                    picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
                }
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Share \(item.name)")
            
            Divider()
            
            Button(role: .destructive) {
                FileShelfManager.shared.removeItem(id: item.id)
            } label: {
                Label("Remove from Shelf", systemImage: "trash")
            }
            .accessibilityLabel("Remove \(item.name) from shelf")
            
            Button(role: .destructive) {
                FileShelfManager.shared.clearAll()
            } label: {
                Label("Clear All Files", systemImage: "xmark.circle")
            }
            .accessibilityLabel("Clear all staged files")
        }
    }
}

public extension View {
    func fileShelfContextMenu(for item: FileShelfItem) -> some View {
        self.modifier(FileShelfContextMenu(item: item))
    }
}
