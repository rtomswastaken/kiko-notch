import XCTest
@testable import KikoNotchKit
import AppKit

final class FileShelfTests: XCTestCase {
    
    // MARK: - Section 5: FILES-001 through FILES-006
    
    func testAddAndRemoveFiles() {
        let manager = FileShelfManager.shared
        manager.clearAll()
        XCTAssertTrue(manager.items.isEmpty)
        
        // Create temporary test files
        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("test_shelf_1_\(UUID().uuidString).txt")
        let file2 = tempDir.appendingPathComponent("test_shelf_2_\(UUID().uuidString).txt")
        
        try? "File 1 content".write(to: file1, atomically: true, encoding: .utf8)
        try? "File 2 longer content data".write(to: file2, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
            manager.clearAll()
        }
        
        // Add multiple files
        manager.addFiles(urls: [file1, file2])
        
        let exp = expectation(description: "Files added to shelf")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(manager.items.count, 2)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        // Test duplicate insertion prevention
        manager.addFiles(urls: [file1])
        let exp2 = expectation(description: "Duplicate prevented")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(manager.items.count, 2)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)
        
        // Remove single item
        if let first = manager.items.first {
            manager.removeItem(id: first.id)
            let exp3 = expectation(description: "Item removed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(manager.items.count, 1)
                exp3.fulfill()
            }
            wait(for: [exp3], timeout: 1.0)
        }
        
        // Clear all
        manager.clearAll()
        let exp4 = expectation(description: "Cleared all")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(manager.items.isEmpty)
            exp4.fulfill()
        }
        wait(for: [exp4], timeout: 1.0)
    }
    
    func testFileShelfItemModel() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("sample_\(UUID().uuidString).txt")
        let sampleData = "Hello Kiko Notch!".data(using: .utf8)!
        try? sampleData.write(to: tempFile)
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        let item = FileShelfItem(url: tempFile)
        XCTAssertEqual(item.name, tempFile.lastPathComponent)
        XCTAssertEqual(item.fileSize, Int64(sampleData.count))
        XCTAssertTrue(item.exists)
        XCTAssertFalse(item.formattedSize.isEmpty)
        XCTAssertNotNil(item.thumbnail)
    }
    
    func testMissingFileHandling() {
        let fakeURL = URL(fileURLWithPath: "/tmp/non_existent_file_\(UUID().uuidString).dat")
        let item = FileShelfItem(url: fakeURL)
        XCTAssertFalse(item.exists)
        XCTAssertEqual(item.fileSize, 0)
        
        item.checkExistence()
        XCTAssertFalse(item.exists)
    }
}
