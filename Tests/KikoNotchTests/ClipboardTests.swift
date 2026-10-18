import XCTest
import AppKit
@testable import KikoNotchKit

final class ClipboardTests: XCTestCase {
    
    // MARK: - Clipboard Item & Storage Tests (CLIP-001, CLIP-002, PRIV-002)
    
    func testClipboardItemWithTextAndFileURL() {
        let textItem = ClipboardItem(text: "Hello Kiko Notch")
        XCTAssertEqual(textItem.text, "Hello Kiko Notch")
        XCTAssertEqual(textItem.characterCount, 16)
        XCTAssertFalse(textItem.isFileURL)
        XCTAssertNil(textItem.fileURL)
        
        let testURL = URL(fileURLWithPath: "/Users/test/Documents/report.pdf")
        let fileItem = ClipboardItem(text: testURL.path, fileURL: testURL)
        XCTAssertEqual(fileItem.text, "/Users/test/Documents/report.pdf")
        XCTAssertTrue(fileItem.isFileURL)
        XCTAssertEqual(fileItem.fileURL, testURL)
    }
    
    func testClipboardStorageCapacityAndDeduplication() {
        let storage = ClipboardStorage()
        storage.clearAll()
        storage.maxCapacity = 5
        
        // Add 5 distinct items
        for i in 1...5 {
            storage.add(ClipboardItem(text: "Item \(i)"))
        }
        XCTAssertEqual(storage.getAll().count, 5)
        XCTAssertEqual(storage.getAll().first?.text, "Item 5")
        
        // Add 6th item - should evict oldest (Item 1)
        storage.add(ClipboardItem(text: "Item 6"))
        XCTAssertEqual(storage.getAll().count, 5)
        XCTAssertEqual(storage.getAll().first?.text, "Item 6")
        XCTAssertFalse(storage.getAll().contains(where: { $0.text == "Item 1" }))
        
        // Add duplicate (Item 4) - should bring to top without increasing count
        storage.add(ClipboardItem(text: "Item 4"))
        XCTAssertEqual(storage.getAll().count, 5)
        XCTAssertEqual(storage.getAll().first?.text, "Item 4")
        
        // Clear all (CLIP-004, PRIV-002)
        storage.clearAll()
        XCTAssertTrue(storage.getAll().isEmpty)
    }
    
    // MARK: - Clipboard Manager Actions & Privacy (CLIP-003, CLIP-004)
    
    @MainActor
    func testClipboardManagerCopyBackAndClear() {
        let storage = ClipboardStorage()
        storage.clearAll()
        let manager = ClipboardManager(storage: storage)
        
        let item = ClipboardItem(text: "Test Copy Snippet")
        storage.add(item)
        
        manager.copyBackToPasteboard(item)
        let pasteboardString = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasteboardString, "Test Copy Snippet")
        
        manager.clearAllHistory()
        XCTAssertTrue(manager.items.isEmpty)
        XCTAssertTrue(storage.getAll().isEmpty)
    }
}
