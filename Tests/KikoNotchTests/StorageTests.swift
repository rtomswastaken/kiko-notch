import XCTest
@testable import KikoNotchKit

final class StorageTests: XCTestCase {
    
    func testKeychainHelperCRUD() {
        let helper = KeychainHelper.shared
        let testKey = "test_key_\(UUID().uuidString)"
        let testVal = "super_secret_token_value_42"
        
        // 1. Write
        let saved = helper.save(key: testKey, value: testVal)
        XCTAssertTrue(saved)
        
        // 2. Read
        let readVal = helper.read(key: testKey)
        XCTAssertEqual(readVal, testVal)
        
        // 3. Overwrite
        let updatedVal = "updated_secret_99"
        helper.save(key: testKey, value: updatedVal)
        XCTAssertEqual(helper.read(key: testKey), updatedVal)
        
        // 4. Delete
        let deleted = helper.delete(key: testKey)
        XCTAssertTrue(deleted)
        XCTAssertNil(helper.read(key: testKey))
    }
    
    func testUsageRepositorySQLiteCRUD() {
        let tempDbPath = NSTemporaryDirectory() + "test_usage_\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: tempDbPath) }
        
        let repo = UsageRepository(customPath: tempDbPath)
        
        let snapshot1 = AIUsageSnapshot(
            providerID: .antigravity,
            timestamp: Date(),
            isAvailable: true,
            sessionRequests: 42,
            sessionTokens: 1024,
            remainingQuotaPercent: 0.85,
            quotaResetDate: nil,
            modelBreakdown: ["gemini-pro": 42],
            statusMessage: "Active session"
        )
        
        repo.recordSnapshot(snapshot1)
        
        let fetched = repo.fetchSnapshots(for: .antigravity, limit: 10)
        XCTAssertFalse(fetched.isEmpty)
        XCTAssertEqual(fetched.first?.sessionRequests, 42)
        XCTAssertEqual(fetched.first?.sessionTokens, 1024)
        XCTAssertEqual(fetched.first?.modelBreakdown["gemini-pro"], 42)
        
        // Export tests
        let json = repo.exportJSON()
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("antigravity"))
        XCTAssertTrue(json!.contains("gemini-pro"))
        
        let csv = repo.exportCSV()
        XCTAssertTrue(csv.contains("antigravity"))
        XCTAssertTrue(csv.contains("42"))
        
        // Clear history
        repo.clearAllHistory()
        let cleared = repo.fetchSnapshots(for: .antigravity, limit: 10)
        XCTAssertTrue(cleared.isEmpty)
    }
    
    func testUsageRepositoryCorruptionAutoRecovery() {
        let tempDbPath = NSTemporaryDirectory() + "test_corrupt_\(UUID().uuidString).sqlite"
        defer {
            try? FileManager.default.removeItem(atPath: tempDbPath)
        }
        
        // Write invalid corrupted bytes to file
        let junk = "INVALID_SQLITE_GARBAGE_HEADER_DATA_123456789".data(using: .utf8)!
        try! junk.write(to: URL(fileURLWithPath: tempDbPath))
        
        // Initializing UsageRepository should trigger integrity check, detect corruption, and recover cleanly (ERR-002)
        let repo = UsageRepository(customPath: tempDbPath)
        
        let snapshot = AIUsageSnapshot(
            providerID: .antigravity,
            isAvailable: true,
            statusMessage: "Post-recovery snapshot"
        )
        repo.recordSnapshot(snapshot)
        
        let results = repo.fetchSnapshots(limit: 5)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.statusMessage, "Post-recovery snapshot")
    }
    
    func testClipboardStorageCapacityAndPurge() {
        let storage = ClipboardStorage.shared
        storage.clearAll()
        storage.maxCapacity = 5
        
        for i in 1...10 {
            storage.add(ClipboardItem(text: "Clip \(i)"))
        }
        
        let items = storage.getAll()
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.first?.text, "Clip 10")
        
        storage.clearAll()
        XCTAssertTrue(storage.getAll().isEmpty)
    }
}
