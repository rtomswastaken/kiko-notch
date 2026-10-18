import Foundation
import AppKit
import QuickLookThumbnailing

/// Represents a staged file reference on the Kiko Notch shelf
public final class FileShelfItem: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let fileSize: Int64
    public let dateAdded: Date
    
    @Published public var thumbnail: NSImage?
    @Published public var exists: Bool
    
    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.dateAdded = Date()
        
        let fileManager = FileManager.default
        let path = url.path
        if let attrs = try? fileManager.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int64 {
            self.fileSize = size
            self.exists = true
        } else {
            self.fileSize = 0
            self.exists = fileManager.fileExists(atPath: path)
        }
        
        // System workspace default file icon
        let defaultIcon = NSWorkspace.shared.icon(forFile: url.path)
        self.thumbnail = defaultIcon
        
        generateQuickLookThumbnail()
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Asynchronously requests a QuickLook thumbnail for images, documents, and PDFs
    public func generateQuickLookThumbnail() {
        guard exists else { return }
        
        let size = CGSize(width: 80, height: 80)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] (rep, error) in
            guard let self = self, let rep = rep else { return }
            DispatchQueue.main.async {
                self.thumbnail = rep.nsImage
            }
        }
    }
    
    /// Refreshes existence state if file was deleted or moved
    public func checkExistence() {
        let isNowPresent = FileManager.default.fileExists(atPath: url.path)
        if exists != isNowPresent {
            DispatchQueue.main.async {
                self.exists = isNowPresent
            }
        }
    }
}
