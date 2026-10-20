import Foundation
import AppKit

/// Metadata schema for persisting File Shelf items across restarts
public struct FileShelfMetadataItem: Codable, Equatable, Sendable {
    public let id: UUID
    public let relativeFileName: String
    public let originalName: String
    public let originalSourcePath: String?
    public let dateAdded: Date
    public let fileSize: Int64
    public let isFolder: Bool
    public let isPastedText: Bool
    public let textSnippet: String?

    public init(
        id: UUID,
        relativeFileName: String,
        originalName: String,
        originalSourcePath: String?,
        dateAdded: Date,
        fileSize: Int64,
        isFolder: Bool,
        isPastedText: Bool,
        textSnippet: String?
    ) {
        self.id = id
        self.relativeFileName = relativeFileName
        self.originalName = originalName
        self.originalSourcePath = originalSourcePath
        self.dateAdded = dateAdded
        self.fileSize = fileSize
        self.isFolder = isFolder
        self.isPastedText = isPastedText
        self.textSnippet = textSnippet
    }
}

/// Manages persistent file shelf storage, metadata indexing, selection, text pasting, and native sharing
public final class FileShelfManager: ObservableObject, @unchecked Sendable {
    public static let shared = FileShelfManager()

    /// Default application support directory for persistent shelf storage
    public static let defaultStorageDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("com.kikonotch.mac/FileShelf", isDirectory: true)
    }()

    public let storageDirectory: URL

    @Published public private(set) var items: [FileShelfItem] = []
    @Published public var selectedItemIDs: Set<UUID> = []

    public init(storageDirectory: URL? = nil) {
        let dir = storageDirectory ?? FileShelfManager.defaultStorageDirectory
        self.storageDirectory = dir

        // Ensure storage directory exists
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Load existing items from persistent storage
        loadPersistedItems()
    }

    // MARK: - Filename Collision Handling

    /// Generates a collision-safe filename within a target directory (e.g. "report (1).pdf")
    public static func uniqueFilename(for originalName: String, in directory: URL) -> String {
        let fm = FileManager.default
        let initialURL = directory.appendingPathComponent(originalName)
        if !fm.fileExists(atPath: initialURL.path) {
            return originalName
        }

        let fileURL = URL(fileURLWithPath: originalName)
        let ext = fileURL.pathExtension
        let base = fileURL.deletingPathExtension().lastPathComponent

        var counter = 1
        while true {
            let candidate = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidate)
            if !fm.fileExists(atPath: candidateURL.path) {
                return candidate
            }
            counter += 1
        }
    }

    // MARK: - Persistence Engine

    private func saveMetadata() {
        let metadataList = items.map { item in
            FileShelfMetadataItem(
                id: item.id,
                relativeFileName: item.url.lastPathComponent,
                originalName: item.originalName,
                originalSourcePath: item.originalSourcePath,
                dateAdded: item.dateAdded,
                fileSize: item.fileSize,
                isFolder: item.isFolder,
                isPastedText: item.isPastedText,
                textSnippet: item.textSnippet
            )
        }

        let metadataURL = storageDirectory.appendingPathComponent("metadata.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(metadataList) {
            try? data.write(to: metadataURL, options: .atomic)
        }
    }

    private func loadPersistedItems() {
        let metadataURL = storageDirectory.appendingPathComponent("metadata.json")
        let fm = FileManager.default

        guard fm.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let metadataList = try? decoder.decode([FileShelfMetadataItem].self, from: data) else {
            return
        }

        var loadedItems: [FileShelfItem] = []
        for meta in metadataList {
            let fileURL = storageDirectory.appendingPathComponent(meta.relativeFileName)
            if fm.fileExists(atPath: fileURL.path) {
                let item = FileShelfItem(
                    id: meta.id,
                    url: fileURL,
                    name: meta.relativeFileName,
                    originalName: meta.originalName,
                    originalSourcePath: meta.originalSourcePath,
                    fileSize: meta.fileSize,
                    dateAdded: meta.dateAdded,
                    isFolder: meta.isFolder,
                    isPastedText: meta.isPastedText,
                    textSnippet: meta.textSnippet
                )
                loadedItems.append(item)
            }
        }
        self.items = loadedItems
    }

    // MARK: - Staging & Addition

    /// Imports external files or folders safely into persistent storage without modifying originals
    public func addFiles(urls: [URL]) {
        if Thread.isMainThread {
            self.addFilesSync(urls: urls)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.addFilesSync(urls: urls)
            }
        }
    }

    /// Synchronous import for tests and immediate operations
    public func addFilesSync(urls: [URL]) {
        let fm = FileManager.default
        var newItems = self.items

        for sourceURL in urls {
            // Prevent duplicate staging of the exact same source file
            if newItems.contains(where: {
                $0.originalSourcePath == sourceURL.path || $0.url.path == sourceURL.path
            }) {
                continue
            }

            guard fm.fileExists(atPath: sourceURL.path) else { continue }

            var isDir: ObjCBool = false
            _ = fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir)

            let safeName = FileShelfManager.uniqueFilename(for: sourceURL.lastPathComponent, in: storageDirectory)
            let destURL = storageDirectory.appendingPathComponent(safeName)

            do {
                // If the file is not already inside our storage directory, safely copy it
                if sourceURL.standardizedFileURL != destURL.standardizedFileURL {
                    try fm.copyItem(at: sourceURL, to: destURL)
                }

                let item = FileShelfItem(
                    url: destURL,
                    name: safeName,
                    originalName: sourceURL.lastPathComponent,
                    originalSourcePath: sourceURL.path,
                    isFolder: isDir.boolValue,
                    isPastedText: false,
                    textSnippet: nil
                )
                newItems.insert(item, at: 0)
            } catch {
                // Log and continue on single file copy failures
                continue
            }
        }

        self.items = newItems
        saveMetadata()
    }

    // MARK: - Text Pasting

    /// Saves pasted text as a persistent `.txt` note in the shelf
    @discardableResult
    public func addPastedText(_ text: String, customTitle: String? = nil) -> FileShelfItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Sanitize base title
        let baseName: String
        if let custom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            baseName = sanitizeFilename(custom)
        } else {
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? "Pasted Text"
            let snippetTitle = String(firstLine.prefix(24)).trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitized = sanitizeFilename(snippetTitle)
            baseName = sanitized.isEmpty ? "Pasted Text" : sanitized
        }

        let fullFilename = baseName.hasSuffix(".txt") ? baseName : "\(baseName).txt"
        let safeName = FileShelfManager.uniqueFilename(for: fullFilename, in: storageDirectory)
        let destURL = storageDirectory.appendingPathComponent(safeName)

        do {
            try trimmed.write(to: destURL, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }

        let snippet = String(trimmed.prefix(140)).replacingOccurrences(of: "\n", with: " ")
        let item = FileShelfItem(
            url: destURL,
            name: safeName,
            originalName: safeName,
            originalSourcePath: nil,
            fileSize: Int64(trimmed.utf8.count),
            dateAdded: Date(),
            isFolder: false,
            isPastedText: true,
            textSnippet: snippet
        )

        let action = { [weak self] in
            guard let self = self else { return }
            self.items.insert(item, at: 0)
            self.saveMetadata()
        }

        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }

        return item
    }

    private func sanitizeFilename(_ name: String) -> String {
        let illegalCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return name.components(separatedBy: illegalCharacters).joined(separator: "_")
    }

    // MARK: - Removal (Safely Deletes Storage Copy, Never External Files)

    public func removeItem(id: UUID) {
        if Thread.isMainThread {
            self.removeItemSync(id: id)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.removeItemSync(id: id)
            }
        }
    }

    public func removeItem(with id: UUID) {
        removeItem(id: id)
    }

    public func removeItemSync(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }

        // Clean up our internal shelf file copy
        if item.url.path.hasPrefix(storageDirectory.path) {
            try? FileManager.default.removeItem(at: item.url)
        }

        self.items.removeAll { $0.id == id }
        self.selectedItemIDs.remove(id)
        saveMetadata()
    }

    public func removeSelectedItems() {
        let idsToRemove = selectedItemIDs
        let action = { [weak self] in
            guard let self = self else { return }
            for id in idsToRemove {
                if let item = self.items.first(where: { $0.id == id }) {
                    if item.url.path.hasPrefix(self.storageDirectory.path) {
                        try? FileManager.default.removeItem(at: item.url)
                    }
                }
            }
            self.items.removeAll { idsToRemove.contains($0.id) }
            self.selectedItemIDs.removeAll()
            self.saveMetadata()
        }

        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    public func clearAll() {
        if Thread.isMainThread {
            self.clearAllSync()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.clearAllSync()
            }
        }
    }

    public func clearAllSync() {
        for item in items {
            if item.url.path.hasPrefix(storageDirectory.path) {
                try? FileManager.default.removeItem(at: item.url)
            }
        }
        self.items.removeAll()
        self.selectedItemIDs.removeAll()
        saveMetadata()
    }

    // MARK: - Selection Management

    public var selectedItems: [FileShelfItem] {
        items.filter { selectedItemIDs.contains($0.id) }
    }

    public func toggleSelection(id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    public func selectItem(id: UUID, isMulti: Bool) {
        if isMulti {
            toggleSelection(id: id)
        } else {
            if selectedItemIDs.count == 1 && selectedItemIDs.contains(id) {
                selectedItemIDs.removeAll()
            } else {
                selectedItemIDs = [id]
            }
        }
    }

    public func selectAll() {
        selectedItemIDs = Set(items.map { $0.id })
    }

    public func clearSelection() {
        selectedItemIDs.removeAll()
    }

    // MARK: - Native File Actions

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

    /// Copies the file or text note to the system clipboard
    public func copyItemToClipboard(item: FileShelfItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if item.isPastedText, let content = item.textContent {
            pb.setString(content, forType: .string)
        }
        pb.writeObjects([item.url as NSURL])
    }

    /// Native macOS Share Sheet & AirDrop integration via NSSharingServicePicker
    public func shareFiles(items: [FileShelfItem], from view: NSView, rect: NSRect) {
        guard !items.isEmpty else { return }
        let urls = items.map { $0.url }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }

    /// Sends the specified items or all selected items using the configured transfer destination
    public func sendItems(
        _ itemsToSend: [FileShelfItem]? = nil,
        destination: SendDestinationInfo? = nil,
        from view: NSView? = nil,
        completion: (@Sendable (Result<Int, FileSenderError>) -> Void)? = nil
    ) {
        let targetItems: [FileShelfItem]
        if let explicit = itemsToSend, !explicit.isEmpty {
            targetItems = explicit
        } else if !selectedItems.isEmpty {
            targetItems = selectedItems
        } else {
            targetItems = items
        }

        guard !targetItems.isEmpty else {
            completion?(.failure(.emptyFileList))
            return
        }

        let dest = destination ?? SettingsManager.shared.currentSendDestination
        let urls = targetItems.map { $0.url }
        FileSenderService.shared.send(urls: urls, destination: dest, from: view, completion: completion)
    }
}
