import SwiftUI
import AppKit

/// Context menu builder and modifier for File Shelf items
public struct FileShelfContextMenu: ViewModifier {
    @ObservedObject public var item: FileShelfItem
    public var onQuickLook: (() -> Void)?

    public init(item: FileShelfItem, onQuickLook: (() -> Void)? = nil) {
        self.item = item
        self.onQuickLook = onQuickLook
    }

    public func body(content: Content) -> some View {
        let dest = SettingsManager.shared.currentSendDestination
        return content.contextMenu {
            // Quick Look Action
            Button {
                if let onQL = onQuickLook {
                    onQL()
                } else {
                    FileShelfManager.shared.openFile(item: item)
                }
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
            .accessibilityLabel("Quick Look \(item.name)")

            // Open in Default App
            Button {
                FileShelfManager.shared.openFile(item: item)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .accessibilityLabel("Open file \(item.name)")

            // Copy Action
            Button {
                FileShelfManager.shared.copyItemToClipboard(item: item)
            } label: {
                Label(item.isPastedText ? "Copy Text" : "Copy File", systemImage: "doc.on.doc")
            }
            .accessibilityLabel("Copy \(item.name) to clipboard")

            // Reveal in Finder
            Button {
                FileShelfManager.shared.revealInFinder(item: item)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            .accessibilityLabel("Show \(item.name) in Finder")

            Divider()

            // Send via Destination
            Button {
                FileShelfManager.shared.sendItems([item])
            } label: {
                Label("Send via \(dest.name)", systemImage: dest.systemSymbolName ?? "paperplane")
            }
            .accessibilityLabel("Send \(item.name) via \(dest.name)")

            // Share Sheet
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

            // Remove from Shelf
            Button(role: .destructive) {
                FileShelfManager.shared.removeItem(id: item.id)
            } label: {
                Label("Remove from Shelf", systemImage: "trash")
            }
            .accessibilityLabel("Remove \(item.name) from shelf")

            // Clear All
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
    func fileShelfContextMenu(for item: FileShelfItem, onQuickLook: (() -> Void)? = nil) -> some View {
        self.modifier(FileShelfContextMenu(item: item, onQuickLook: onQuickLook))
    }
}
