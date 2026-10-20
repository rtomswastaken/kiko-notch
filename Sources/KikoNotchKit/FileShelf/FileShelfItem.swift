import Foundation
import AppKit
import QuickLookThumbnailing

/// Represents a persistent staged file or text note in the Kiko Notch File Shelf
public final class FileShelfItem: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let originalName: String
    public let originalSourcePath: String?
    public let fileSize: Int64
    public let dateAdded: Date
    public let isFolder: Bool
    public let isPastedText: Bool
    public let textSnippet: String?

    public var fileURL: URL { url }
    public var fileName: String { name }

    @Published public var thumbnail: NSImage?
    @Published public var exists: Bool
    private var isAccessingSecurityScope: Bool = false

    /// Full text content for pasted text notes
    public var textContent: String? {
        guard isPastedText && exists else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        originalName: String? = nil,
        originalSourcePath: String? = nil,
        fileSize: Int64? = nil,
        dateAdded: Date = Date(),
        isFolder: Bool? = nil,
        isPastedText: Bool = false,
        textSnippet: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.originalName = originalName ?? url.lastPathComponent
        self.originalSourcePath = originalSourcePath
        self.dateAdded = dateAdded
        self.isPastedText = isPastedText
        self.textSnippet = textSnippet

        let fileManager = FileManager.default
        let path = url.path

        // Check if directory
        if let explicitFolder = isFolder {
            self.isFolder = explicitFolder
        } else {
            var isDir: ObjCBool = false
            self.isFolder = fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }

        // Retain security scoped access if applicable
        self.isAccessingSecurityScope = url.startAccessingSecurityScopedResource()

        if let explicitSize = fileSize {
            self.fileSize = explicitSize
            self.exists = fileManager.fileExists(atPath: path)
        } else {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                self.fileSize = size
                self.exists = true
            } else {
                self.fileSize = 0
                self.exists = fileManager.fileExists(atPath: path)
            }
        }

        // Initial system icon
        let defaultIcon = NSWorkspace.shared.icon(forFile: url.path)
        self.thumbnail = defaultIcon

        generateQuickLookThumbnail()
    }

    public convenience init(url: URL) {
        self.init(id: UUID(), url: url)
    }

    deinit {
        if isAccessingSecurityScope {
            url.stopAccessingSecurityScopedResource()
        }
    }

    public var formattedSize: String {
        if isFolder {
            return "Folder"
        }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
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
