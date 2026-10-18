import XCTest
@testable import KikoNotchKit

final class DownloadMonitoringTests: XCTestCase {
    
    // MARK: - Download Item Model Tests (DL-001, DL-002)
    
    func testDownloadItemSpeedFormatting() {
        let item1 = DownloadItem(
            filename: "archive.zip.crdownload",
            targetFilename: "archive.zip",
            path: "/Users/test/Downloads/archive.zip.crdownload",
            state: .active,
            bytesDownloaded: 500_000,
            speedBytesPerSecond: 512 * 1024 // 512 KB/s
        )
        XCTAssertEqual(item1.formattedSpeed, "512 KB/s")
        
        let item2 = DownloadItem(
            filename: "installer.pkg.download",
            targetFilename: "installer.pkg",
            path: "/Users/test/Downloads/installer.pkg.download",
            state: .active,
            bytesDownloaded: 15_000_000,
            speedBytesPerSecond: 2.5 * 1024 * 1024 // 2.5 MB/s
        )
        XCTAssertEqual(item2.formattedSpeed, "2.5 MB/s")
    }
    
    // MARK: - Companion Message Validator Tests (DL-001, DL-003)
    
    func testValidCompanionMessageParsing() throws {
        let json = """
        {
            "type": "download_progress",
            "downloadId": "dl-101",
            "filename": "Xcode_16.xip",
            "totalBytes": 10000000,
            "receivedBytes": 4500000,
            "timestamp": "2026-10-18T10:00:00Z"
        }
        """.data(using: .utf8)!
        
        let message = try DownloadMessageValidator.validate(data: json)
        XCTAssertEqual(message.type, .downloadProgress)
        XCTAssertEqual(message.downloadId, "dl-101")
        XCTAssertEqual(message.filename, "Xcode_16.xip")
        XCTAssertEqual(message.totalBytes, 10_000_000)
        XCTAssertEqual(message.receivedBytes, 4_500_000)
        
        let item = DownloadMessageValidator.toDownloadItem(from: message)
        XCTAssertEqual(item.id, "dl-101")
        XCTAssertEqual(item.state, .active)
        XCTAssertEqual(item.progress, 0.45, accuracy: 0.01)
    }
    
    func testInvalidCompanionMessages() {
        // Missing filename
        let missingFilenameJson = """
        {
            "type": "download_started",
            "downloadId": "dl-102",
            "filename": "",
            "receivedBytes": 0,
            "timestamp": "2026-10-18T10:00:00Z"
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try DownloadMessageValidator.validate(data: missingFilenameJson)) { error in
            guard case MessageValidationError.missingRequiredFields(let field) = error else {
                return XCTFail("Expected missingRequiredFields error")
            }
            XCTAssertEqual(field, "filename")
        }
        
        // Negative byte count
        let negativeBytesJson = """
        {
            "type": "download_progress",
            "downloadId": "dl-103",
            "filename": "file.pdf",
            "totalBytes": 1000,
            "receivedBytes": -50,
            "timestamp": "2026-10-18T10:00:00Z"
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try DownloadMessageValidator.validate(data: negativeBytesJson)) { error in
            guard case MessageValidationError.invalidByteCount = error else {
                return XCTFail("Expected invalidByteCount error")
            }
        }
    }
    
private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

    // MARK: - Download Monitor Simulation Tests (DL-002, DL-003)
    
    func testDownloadMonitorCompanionProcessing() {
        let monitor = DownloadMonitor(customPath: "/tmp/kiko_downloads_test")
        let receivedItems = TestBox<[DownloadItem]>([])
        let completedItem = TestBox<DownloadItem?>(nil)
        
        monitor.onDownloadsUpdated = { items in
            receivedItems.value = items
        }
        monitor.onDownloadCompleted = { item in
            completedItem.value = item
        }
        
        let startMsg = CompanionDownloadMessage(
            type: .downloadStarted,
            downloadId: "msg-1",
            filename: "bigfile.iso",
            totalBytes: 50_000_000,
            receivedBytes: 1_000_000
        )
        monitor.processCompanionMessage(startMsg)
        
        XCTAssertEqual(receivedItems.value.count, 1)
        XCTAssertEqual(receivedItems.value.first?.filename, "bigfile.iso")
        XCTAssertEqual(receivedItems.value.first?.state, .active)
        
        let completeMsg = CompanionDownloadMessage(
            type: .downloadCompleted,
            downloadId: "msg-1",
            filename: "bigfile.iso",
            totalBytes: 50_000_000,
            receivedBytes: 50_000_000
        )
        monitor.processCompanionMessage(completeMsg)
        
        XCTAssertNotNil(completedItem.value)
        XCTAssertEqual(completedItem.value?.filename, "bigfile.iso")
        XCTAssertEqual(completedItem.value?.state, .completed)
    }
}
