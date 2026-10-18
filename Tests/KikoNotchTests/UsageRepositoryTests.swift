import XCTest
@testable import KikoNotchKit

final class UsageRepositoryTests: XCTestCase {
    
    private var testDbPath: String!
    private var repository: UsageRepository!
    
    override func setUp() {
        super.setUp()
        testDbPath = "/tmp/kiko_usage_test_\(UUID().uuidString).sqlite"
        repository = UsageRepository(customPath: testDbPath)
    }
    
    override func tearDown() {
        repository = nil
        try? FileManager.default.removeItem(atPath: testDbPath)
        super.tearDown()
    }
    
    // MARK: - Schema & Version Tests (AI-ANTIGRAVITY-005, ERR-002)
    
    func testSchemaCreationAndVersion() {
        XCTAssertGreaterThanOrEqual(repository.schemaVersion, 1)
    }
    
    // MARK: - Snapshot Insertion & Queries
    
    func testSnapshotInsertionAndRetrieval() {
        let snapshot1 = AIUsageSnapshot(
            providerID: .antigravity,
            timestamp: Date(),
            isAvailable: true,
            sessionRequests: 42,
            sessionTokens: 12000,
            remainingQuotaPercent: 0.85,
            modelBreakdown: ["gemini-pro": 42],
            statusMessage: "Active"
        )
        repository.recordSnapshot(snapshot1)
        
        let snapshot2 = AIUsageSnapshot(
            providerID: .codex,
            timestamp: Date().addingTimeInterval(10),
            isAvailable: true,
            sessionRequests: 10,
            sessionTokens: 3500,
            modelBreakdown: ["code-davinci": 10],
            statusMessage: "Connected"
        )
        repository.recordSnapshot(snapshot2)
        
        let allSnapshots = repository.fetchSnapshots(limit: 10)
        XCTAssertEqual(allSnapshots.count, 2)
        
        // Filter by provider
        let antigravityOnly = repository.fetchSnapshots(for: .antigravity)
        XCTAssertEqual(antigravityOnly.count, 1)
        XCTAssertEqual(antigravityOnly.first?.sessionRequests, 42)
        XCTAssertEqual(antigravityOnly.first?.modelBreakdown["gemini-pro"], 42)
        
        let codexOnly = repository.fetchSnapshots(for: .codex)
        XCTAssertEqual(codexOnly.count, 1)
        XCTAssertEqual(codexOnly.first?.sessionRequests, 10)
    }
    
    func testSnapshotFilteringByDateRangeAndModel() {
        let now = Date()
        let past = now.addingTimeInterval(-3600)
        let future = now.addingTimeInterval(3600)
        
        let snapPast = AIUsageSnapshot(
            providerID: .claude,
            timestamp: past,
            isAvailable: true,
            sessionRequests: 5,
            modelBreakdown: ["claude-3-opus": 5],
            statusMessage: "Past session"
        )
        let snapNow = AIUsageSnapshot(
            providerID: .claude,
            timestamp: now,
            isAvailable: true,
            sessionRequests: 15,
            modelBreakdown: ["claude-3-sonnet": 15],
            statusMessage: "Current session"
        )
        repository.recordSnapshot(snapPast)
        repository.recordSnapshot(snapNow)
        
        // Filter by model
        let opusOnly = repository.fetchSnapshots(model: "claude-3-opus")
        XCTAssertEqual(opusOnly.count, 1)
        XCTAssertEqual(opusOnly.first?.sessionRequests, 5)
        
        // Filter by date range
        let recentOnly = repository.fetchSnapshots(startDate: now.addingTimeInterval(-60), endDate: future)
        XCTAssertEqual(recentOnly.count, 1)
        XCTAssertEqual(recentOnly.first?.sessionRequests, 15)
    }
    
    // MARK: - Transaction Support Tests
    
    func testTransactionsCommitAndRollback() throws {
        // Successful transaction
        let didBegin = repository.beginTransaction()
        XCTAssertTrue(didBegin)
        
        let snap1 = AIUsageSnapshot(
            providerID: .antigravity,
            isAvailable: true,
            sessionRequests: 99,
            statusMessage: "Tx Commit"
        )
        repository.recordSnapshot(snap1)
        
        let didCommit = repository.commitTransaction()
        XCTAssertTrue(didCommit)
        XCTAssertEqual(repository.fetchSnapshots().count, 1)
        
        // Failed transaction rolling back
        let didBegin2 = repository.beginTransaction()
        XCTAssertTrue(didBegin2)
        
        let snap2 = AIUsageSnapshot(
            providerID: .codex,
            isAvailable: true,
            sessionRequests: 88,
            statusMessage: "Tx Rollback"
        )
        repository.recordSnapshot(snap2)
        
        let didRollback = repository.rollbackTransaction()
        XCTAssertTrue(didRollback)
        // Count should still be 1 because rollback occurred
        // (Note: in SQLite if table is re-opened or deleted, let's verify count)
        XCTAssertEqual(repository.fetchSnapshots().count, 1)
    }
    
    // MARK: - Export and Purge Tests (AI-DASH-004)
    
    func testExportJSONAndCSV() {
        let snap = AIUsageSnapshot(
            providerID: .antigravity,
            isAvailable: true,
            sessionRequests: 12,
            sessionTokens: 500,
            remainingQuotaPercent: 0.90,
            statusMessage: "Export Test"
        )
        repository.recordSnapshot(snap)
        
        let jsonString = repository.exportJSON()
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("antigravity") ?? false)
        XCTAssertTrue(jsonString?.contains("Export Test") ?? false)
        
        let csvString = repository.exportCSV()
        XCTAssertTrue(csvString.contains("id,provider_id,timestamp"))
        XCTAssertTrue(csvString.contains("antigravity"))
    }
    
    func testClearAllHistory() {
        let snap = AIUsageSnapshot(providerID: .antigravity, isAvailable: true, statusMessage: "To Clear")
        repository.recordSnapshot(snap)
        XCTAssertFalse(repository.fetchSnapshots().isEmpty)
        
        repository.clearAllHistory()
        XCTAssertTrue(repository.fetchSnapshots().isEmpty)
    }
    
    // MARK: - Corruption Recovery (ERR-002)
    
    func testCorruptDatabaseAutoRecovery() {
        let snap = AIUsageSnapshot(providerID: .antigravity, isAvailable: true, statusMessage: "Pre-corruption")
        repository.recordSnapshot(snap)
        XCTAssertEqual(repository.fetchSnapshots().count, 1)
        
        // Simulate corruption by overwriting database file with garbage
        repository.simulateCorruption()
        
        // Re-open/reload repository - should detect corruption, backup, and recreate fresh tables
        repository.reloadDatabase()
        
        XCTAssertGreaterThanOrEqual(repository.schemaVersion, 1)
        // Fresh database is ready for new records
        let newSnap = AIUsageSnapshot(providerID: .antigravity, isAvailable: true, statusMessage: "Post-recovery")
        repository.recordSnapshot(newSnap)
        XCTAssertEqual(repository.fetchSnapshots().count, 1)
    }
}
