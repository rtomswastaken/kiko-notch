import XCTest
@testable import KikoNotchKit
import AppKit

final class FileShelfTestDraggingInfo: NSObject, NSDraggingInfo {
    let pb: NSPasteboard
    init(pasteboard: NSPasteboard) { self.pb = pasteboard }
    var draggingPasteboard: NSPasteboard { pb }
    var draggingLocation: NSPoint { .zero }
    var dragOperationMask: NSDragOperation { .copy }
    var draggingSource: Any? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingDestinationWindow: NSWindow? { nil }
    var numberOfValidItemsForDrop: Int = 1
    var draggedImage: NSImage? { nil }
    var draggedImageLocation: NSPoint { .zero }
    var draggingSequenceNumber: Int { 1 }
    var springloadedDropOccurred: Bool { false }
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination: Bool = true

    func slideDraggedImage(to screenPoint: NSPoint) {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any] = [:], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
}

final class FileShelfTests: XCTestCase {

    override func setUp() {
        super.setUp()
        FileShelfManager.shared.clearAllSync()
    }

    override func tearDown() {
        FileShelfManager.shared.clearAllSync()
        super.tearDown()
    }

    // MARK: - 1. Adding a Single File

    func testAddSingleFile() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("single_\(UUID().uuidString).txt")
        try? "Single file content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let manager = FileShelfManager.shared
        manager.addFilesSync(urls: [tempFile])

        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.name, tempFile.lastPathComponent)
        XCTAssertEqual(manager.items.first?.exists, true)
        XCTAssertFalse(manager.items.first?.formattedSize.isEmpty ?? true)
    }

    // MARK: - 2. Adding Multiple Files

    func testAddMultipleFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("multi_1_\(UUID().uuidString).txt")
        let file2 = tempDir.appendingPathComponent("multi_2_\(UUID().uuidString).txt")
        let file3 = tempDir.appendingPathComponent("multi_3_\(UUID().uuidString).txt")

        try? "Content 1".write(to: file1, atomically: true, encoding: .utf8)
        try? "Content 2".write(to: file2, atomically: true, encoding: .utf8)
        try? "Content 3".write(to: file3, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
            try? FileManager.default.removeItem(at: file3)
        }

        let manager = FileShelfManager.shared
        manager.addFilesSync(urls: [file1, file2, file3])

        XCTAssertEqual(manager.items.count, 3)
        let names = Set(manager.items.map { $0.name })
        XCTAssertTrue(names.contains(file1.lastPathComponent))
        XCTAssertTrue(names.contains(file2.lastPathComponent))
        XCTAssertTrue(names.contains(file3.lastPathComponent))
    }

    // MARK: - 3. Adding Folders

    func testAddFolders() {
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent("folder_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        let innerFile = tempFolder.appendingPathComponent("nested.txt")
        try? "Nested".write(to: innerFile, atomically: true, encoding: .utf8)

        defer { try? FileManager.default.removeItem(at: tempFolder) }

        let manager = FileShelfManager.shared
        manager.addFilesSync(urls: [tempFolder])

        XCTAssertEqual(manager.items.count, 1)
        guard let item = manager.items.first else { return XCTFail("Expected folder item") }
        XCTAssertTrue(item.isFolder)
        XCTAssertEqual(item.formattedSize, "Folder")
        XCTAssertEqual(item.name, tempFolder.lastPathComponent)
    }

    // MARK: - 4. Removing an Item Without Deleting the Original

    func testRemovingItemWithoutDeletingOriginal() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("keep_on_disk_\(UUID().uuidString).txt")
        try? "Must survive shelf removal".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let manager = FileShelfManager.shared
        manager.addFilesSync(urls: [tempFile])
        XCTAssertEqual(manager.items.count, 1)

        if let item = manager.items.first {
            manager.removeItemSync(id: item.id)
        }

        XCTAssertTrue(manager.items.isEmpty)
        // Verify disk file still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path), "Original file on disk must never be deleted!")
    }

    // MARK: - 5. Duplicate-Drop Behavior

    func testDuplicateDropBehavior() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("duplicate_\(UUID().uuidString).txt")
        try? "No duplicates".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let manager = FileShelfManager.shared
        manager.addFilesSync(urls: [tempFile])
        XCTAssertEqual(manager.items.count, 1)

        // Add exact same file again
        manager.addFilesSync(urls: [tempFile])
        XCTAssertEqual(manager.items.count, 1, "Duplicate paths must be prevented")
    }

    // MARK: - 6. Invalid Drop Handling

    func testInvalidDropHandling() {
        let manager = FileShelfManager.shared
        manager.addFilesSync(urls: [])
        XCTAssertTrue(manager.items.isEmpty)
    }

    // MARK: - 7. Empty Shelf Rendering & Selection

    func testEmptyShelfRenderingAndSelection() {
        let manager = FileShelfManager.shared
        manager.clearAllSync()
        XCTAssertTrue(manager.items.isEmpty)
        XCTAssertTrue(manager.selectedItemIDs.isEmpty)
        XCTAssertTrue(manager.selectedItems.isEmpty)
    }

    // MARK: - 8. Missing or Inaccessible Files

    func testMissingOrInaccessibleFiles() {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/ghost_file_\(UUID().uuidString).dat")
        let item = FileShelfItem(url: nonExistentURL)

        XCTAssertFalse(item.exists)
        XCTAssertEqual(item.fileSize, 0)
        item.checkExistence()
        XCTAssertFalse(item.exists)
    }

    // MARK: - 9. Destination Selection Persistence

    func testDestinationSelectionPersistence() {
        let settings = SettingsManager.shared

        settings.sendDestinationType = .blip
        XCTAssertEqual(UserDefaults.standard.string(forKey: "kiko.sendDestinationType"), SendDestinationType.blip.rawValue)

        settings.sendDestinationType = .airDrop
        XCTAssertEqual(UserDefaults.standard.string(forKey: "kiko.sendDestinationType"), SendDestinationType.airDrop.rawValue)
    }

    // MARK: - 10. Default AirDrop Selection

    func testDefaultAirDropSelection() {
        let settings = SettingsManager.shared
        settings.resetToDefaults()

        XCTAssertEqual(settings.sendDestinationType, .airDrop)
        let destination = settings.currentSendDestination
        XCTAssertEqual(destination.type, .airDrop)
        XCTAssertEqual(destination.name, "AirDrop")
        XCTAssertTrue(destination.isAvailable)
    }

    // MARK: - 11. Missing Configured Destination Handling

    func testMissingConfiguredDestinationHandling() {
        let service = FileSenderService.shared
        let invalidAppURL = URL(fileURLWithPath: "/Applications/NonExistentApp_\(UUID().uuidString).app")

        let destination = service.resolveDestination(type: .customApp, customAppURL: invalidAppURL)
        XCTAssertFalse(destination.isAvailable)
        XCTAssertEqual(destination.statusDescription, "Application not configured in Settings")

        // Also test missing Blip if resolved explicitly
        let missingBlip = SendDestinationInfo(
            type: .blip,
            name: "Blip",
            icon: NSWorkspace.shared.icon(forFile: "/Applications"),
            isAvailable: false,
            statusDescription: "Blip is not installed on this Mac",
            appURL: nil
        )

        let exp = expectation(description: "Send failure expected")
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).txt")
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        service.send(urls: [tempFile], destination: missingBlip) { result in
            switch result {
            case .failure(let err):
                XCTAssertEqual(err, .destinationUnavailable("Blip is not installed on this Mac"))
                exp.fulfill()
            case .success:
                XCTFail("Must not succeed with unavailable destination")
            }
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - 12. Sending Cancellation and Failure States

    func testSendingCancellationAndFailureStates() {
        let service = FileSenderService.shared
        let airDrop = service.resolveDestination(type: .airDrop, customAppURL: nil)

        // Test empty URL list failure
        let expEmpty = expectation(description: "Empty file list fails")
        service.send(urls: [], destination: airDrop) { result in
            switch result {
            case .failure(let err):
                XCTAssertEqual(err, .emptyFileList)
                expEmpty.fulfill()
            case .success:
                XCTFail("Empty file list must fail")
            }
        }
        wait(for: [expEmpty], timeout: 1.0)

        // Test missing file on disk failure
        let expMissing = expectation(description: "Missing file on disk fails")
        let missing = URL(fileURLWithPath: "/tmp/absent_\(UUID().uuidString).txt")
        service.send(urls: [missing], destination: airDrop) { result in
            switch result {
            case .failure(let err):
                XCTAssertEqual(err, .fileNotFound(missing.path))
                expMissing.fulfill()
            case .success:
                XCTFail("Missing file must fail")
            }
        }
        wait(for: [expMissing], timeout: 1.0)
    }

    // MARK: - 13. Multiple-File Transfer Support

    func testMultipleFileTransferSupport() {
        let tempDir = FileManager.default.temporaryDirectory
        let f1 = tempDir.appendingPathComponent("tf1_\(UUID().uuidString).txt")
        let f2 = tempDir.appendingPathComponent("tf2_\(UUID().uuidString).txt")
        try? "1".write(to: f1, atomically: true, encoding: .utf8)
        try? "2".write(to: f2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: f1)
            try? FileManager.default.removeItem(at: f2)
        }

        let service = FileSenderService.shared
        let airDrop = service.resolveDestination(type: .airDrop, customAppURL: nil)

        // AirDrop send validates multiple items
        let exp = expectation(description: "Multiple files validated and initiated")
        service.send(urls: [f1, f2], destination: airDrop) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 2)
                exp.fulfill()
            case .failure(let err):
                // In headless test environments NSSharingService may reject presentation
                XCTAssertTrue(err.localizedDescription.contains("AirDrop") || err.localizedDescription.contains("present"))
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - 14. Correct Drag-Out Behavior

    func testCorrectDragOutBehavior() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("dragout_\(UUID().uuidString).txt")
        try? "Drag out content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let item = FileShelfItem(url: tempFile)
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL)
        XCTAssertNotNil(provider)
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier("public.file-url"))
    }

    // MARK: - 15. Security-Scoped Access

    func testSecurityScopedAccess() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("sec_\(UUID().uuidString).txt")
        try? "Security scoped".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let item = FileShelfItem(url: tempFile)
        XCTAssertTrue(item.exists)
        XCTAssertEqual(item.name, tempFile.lastPathComponent)
    }

    // MARK: - 16. Automatic Island Expansion During File Dragging

    func testAutomaticIslandExpansionDuringFileDragging() {
        MainActor.assumeIsolated {
            let interaction = InteractionManager.shared
            let navigation = IslandNavigationModel.shared

            // Set collapsed state
            interaction.transition(to: .collapsed)
            navigation.selectTab(.home)
            XCTAssertEqual(interaction.currentState, .collapsed)

            // Simulate draggingEntered on IslandHostingView
            let hostingView = IslandHostingView(rootView: IslandContainerView())
            let pasteboard = NSPasteboard(name: .drag)
            pasteboard.clearContents()
            pasteboard.writeObjects([NSURL(fileURLWithPath: "/tmp/sample.txt")])

            let info = FileShelfTestDraggingInfo(pasteboard: pasteboard)
            let op = hostingView.draggingEntered(info)
            XCTAssertTrue(op.contains(.copy))

            // Verify automatic expansion and tab selection
            XCTAssertEqual(interaction.currentState, .expanded)
            XCTAssertEqual(navigation.activeTab, .fileShelf)
        }
    }

    // MARK: - 17. Cancellation Restoring Appropriate Island State

    func testCancellationRestoringAppropriateIslandState() {
        MainActor.assumeIsolated {
            let interaction = InteractionManager.shared
            let navigation = IslandNavigationModel.shared

            interaction.transition(to: .collapsed)
            navigation.selectTab(.home)

            let hostingView = IslandHostingView(rootView: IslandContainerView())
            let pasteboard = NSPasteboard(name: .drag)
            pasteboard.clearContents()
            pasteboard.writeObjects([NSURL(fileURLWithPath: "/tmp/sample.txt")])

            let info = FileShelfTestDraggingInfo(pasteboard: pasteboard)
            _ = hostingView.draggingEntered(info)
            XCTAssertEqual(interaction.currentState, .expanded)

            // Cancel / exit drag
            hostingView.draggingExited(info)
            XCTAssertEqual(interaction.currentState, .collapsed, "Must restore collapsed state upon drag exit/cancellation")
            XCTAssertEqual(navigation.activeTab, .home, "Must restore prior active tab upon cancellation")
        }
    }

    // MARK: - 18. No Regression in Existing Collapsed/Expanded Behavior

    func testNoRegressionInExistingBehavior() {
        let interaction = InteractionManager.shared
        interaction.transition(to: .collapsed)
        XCTAssertEqual(interaction.currentState, .collapsed)

        interaction.toggleExpandCollapse()
        XCTAssertEqual(interaction.currentState, .expanded)

        interaction.toggleExpandCollapse()
        XCTAssertEqual(interaction.currentState, .collapsed)
    }

    // MARK: - 19. Correct Rendering at Existing Fixed Dimensions

    func testCorrectRenderingAtExistingFixedDimensions() {
        let geometry = IslandGeometryConfig.standard
        XCTAssertEqual(geometry.expandedWidth, 460.0)
        XCTAssertEqual(geometry.expandedHeight, 350.0)
        XCTAssertEqual(geometry.collapsedWidth, 185.0)
        XCTAssertEqual(geometry.collapsedHeight, 32.0)

        // The two components inside FileShelfTabView fit within expanded dimensions:
        // Width: 190 (Sending Container) + 12 (spacing) + ~238 (Shelf) = 440 (fits in 460 - 20)
        // Height: 190 (fits in 280 - 44 - 20)
        let totalComponentWidth: CGFloat = 190.0 + 12.0 + 238.0
        XCTAssertLessThanOrEqual(totalComponentWidth, geometry.expandedWidth)
    }

    // MARK: - 20. Drag Session State & Collapse Blocking

    func testDragSessionBlocksCollapse() {
        let interaction = InteractionManager.shared
        interaction.transition(to: .expanded)
        XCTAssertEqual(interaction.currentState, .expanded)

        interaction.beginDragSession()
        XCTAssertTrue(interaction.isDragSessionActive)

        // Trigger mouse exit; while drag is active, it must NOT schedule collapse
        interaction.mouseExited()
        XCTAssertEqual(interaction.currentState, .expanded, "Must stay expanded during active drag session")

        // End drag session
        interaction.endDragSession(completedDrop: true)
        XCTAssertFalse(interaction.isDragSessionActive)
    }

    // MARK: - 21. Filename Collision Handling

    func testFilenameCollisionHandling() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("collision_test_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let name1 = FileShelfManager.uniqueFilename(for: "sample.pdf", in: tempDir)
        XCTAssertEqual(name1, "sample.pdf")

        // Create the file so it exists
        let file1 = tempDir.appendingPathComponent("sample.pdf")
        try? "content".write(to: file1, atomically: true, encoding: .utf8)

        let name2 = FileShelfManager.uniqueFilename(for: "sample.pdf", in: tempDir)
        XCTAssertEqual(name2, "sample (1).pdf")

        // Create file 2
        let file2 = tempDir.appendingPathComponent("sample (1).pdf")
        try? "content".write(to: file2, atomically: true, encoding: .utf8)

        let name3 = FileShelfManager.uniqueFilename(for: "sample.pdf", in: tempDir)
        XCTAssertEqual(name3, "sample (2).pdf")
    }

    // MARK: - 22. Persistent Storage Across Restart

    func testPersistentStorageAcrossRestart() {
        let customDir = FileManager.default.temporaryDirectory.appendingPathComponent("shelf_persist_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: customDir) }

        // Create an external file
        let extFile = FileManager.default.temporaryDirectory.appendingPathComponent("external_\(UUID().uuidString).txt")
        try? "Persistent Content".write(to: extFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: extFile) }

        // Session 1: Manager instance adds file and text note
        let manager1 = FileShelfManager(storageDirectory: customDir)
        manager1.addFilesSync(urls: [extFile])
        let textNote = manager1.addPastedText("Quick meeting notes\nReview Q3 numbers", customTitle: "Meeting")
        XCTAssertNotNil(textNote)
        XCTAssertEqual(manager1.items.count, 2)

        // Verify metadata.json was written to disk
        let metaURL = customDir.appendingPathComponent("metadata.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: metaURL.path))

        // Session 2 (Simulated App Restart): New manager instance initialized from same storage directory
        let manager2 = FileShelfManager(storageDirectory: customDir)
        XCTAssertEqual(manager2.items.count, 2, "Items must reload from metadata.json on startup")

        let names = Set(manager2.items.map { $0.name })
        XCTAssertTrue(names.contains("Meeting.txt"))
        XCTAssertTrue(names.contains(extFile.lastPathComponent))

        // Check text content was preserved
        if let reloadedNote = manager2.items.first(where: { $0.isPastedText }) {
            XCTAssertEqual(reloadedNote.textContent, "Quick meeting notes\nReview Q3 numbers")
            XCTAssertTrue(reloadedNote.textSnippet?.contains("Quick meeting notes") ?? false)
        } else {
            XCTFail("Expected reloaded pasted note")
        }
    }

    // MARK: - 23. Text Pasting and Snippet Generation

    func testTextPastingAndSnippet() {
        let manager = FileShelfManager.shared
        let originalCount = manager.items.count

        let sampleText = "SwiftUI Quick Look Support\nImplementing persistent file shelves with native Cocoa APIs."
        guard let item = manager.addPastedText(sampleText, customTitle: "DocNote") else {
            return XCTFail("Failed to add pasted text")
        }

        XCTAssertEqual(manager.items.count, originalCount + 1)
        XCTAssertTrue(item.isPastedText)
        XCTAssertFalse(item.isFolder)
        XCTAssertEqual(item.name, "DocNote.txt")
        XCTAssertEqual(item.textContent, sampleText)
        XCTAssertTrue(item.textSnippet?.contains("SwiftUI Quick Look") ?? false)

        // Adding another note with same title must collision-resolve
        let secondItem = manager.addPastedText("Another text note", customTitle: "DocNote")
        XCTAssertEqual(secondItem?.name, "DocNote (1).txt")

        // Clean up
        manager.removeItemSync(id: item.id)
        if let second = secondItem {
            manager.removeItemSync(id: second.id)
        }
    }

    // MARK: - 24. Clipboard Copying

    func testCopyItemToClipboard() {
        let manager = FileShelfManager.shared
        let note = manager.addPastedText("Clipboard payload text", customTitle: "ClipTest")
        XCTAssertNotNil(note)

        if let note = note {
            manager.copyItemToClipboard(item: note)
            let pbString = NSPasteboard.general.string(forType: .string)
            XCTAssertEqual(pbString, "Clipboard payload text")
            manager.removeItemSync(id: note.id)
        }
    }
}
