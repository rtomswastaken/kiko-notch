import XCTest
@testable import KikoNotchKit

final class AIProviderTests: XCTestCase {
    
    // MARK: - Antigravity Provider Tests (AI-ANTIGRAVITY-001 through 006)
    
    func testAntigravityProviderDefaultStateAndThreshold() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("antigravity_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let provider = AntigravityProvider(customBaseDir: tempDir)
        XCTAssertEqual(provider.id, .antigravity)
        XCTAssertEqual(provider.displayName, "Google Antigravity")
        XCTAssertTrue(provider.isEnabledByDefault)
        
        // Check connection
        let isConnected = await provider.checkConnection()
        XCTAssertTrue(isConnected)
        
        // Fetch usage
        let snapshot = try await provider.fetchUsage()
        XCTAssertTrue(snapshot.isAvailable)
        XCTAssertEqual(snapshot.providerID, .antigravity)
        // Truthful: remaining quota percent is nil since local environment has no hard cap
        XCTAssertNil(snapshot.remainingQuotaPercent)
        
        // Threshold check (AI-ANTIGRAVITY-006)
        let lowQuotaSnapshot = AIUsageSnapshot(
            providerID: .antigravity,
            isAvailable: true,
            remainingQuotaPercent: 0.15, // 15% remaining (under 20%)
            statusMessage: "Quota low"
        )
        XCTAssertTrue(provider.isThresholdExceeded(snapshot: lowQuotaSnapshot))
        
        let healthyQuotaSnapshot = AIUsageSnapshot(
            providerID: .antigravity,
            isAvailable: true,
            remainingQuotaPercent: 0.85,
            statusMessage: "Quota healthy"
        )
        XCTAssertFalse(provider.isThresholdExceeded(snapshot: healthyQuotaSnapshot))
    }
    
    func testAntigravityMissingEnvironmentReportsTruthfully() async throws {
        let nonexistentDir = URL(fileURLWithPath: "/tmp/nonexistent_antigravity_\(UUID().uuidString)")
        let provider = AntigravityProvider(customBaseDir: nonexistentDir)
        
        let isConnected = await provider.checkConnection()
        XCTAssertFalse(isConnected)
        
        let snapshot = try await provider.fetchUsage()
        XCTAssertFalse(snapshot.isAvailable)
        XCTAssertTrue(snapshot.statusMessage.contains("not found"))
    }
    
    // MARK: - Codex Provider Tests (AI-CODEX-001, AI-CODEX-002, AI-CODEX-003)
    
    func testCodexProviderDefaultStateAndIsolation() async throws {
        let provider = CodexProvider()
        XCTAssertEqual(provider.id, .codex)
        XCTAssertFalse(provider.isEnabledByDefault)
        
        // When no API key is in Keychain, checkConnection returns false safely without crashing
        let isConnected = await provider.checkConnection()
        XCTAssertFalse(isConnected)
        
        // Fetch usage reports unauthenticated state without throwing
        let snapshot = try await provider.fetchUsage()
        XCTAssertFalse(snapshot.isAvailable)
    }
    
    // MARK: - Claude Provider Tests (AI-CLAUDE-001, AI-CLAUDE-002, AI-CLAUDE-003)
    
    func testClaudeProviderDefaultStateAndIsolation() async throws {
        let nonexistentDir = URL(fileURLWithPath: "/tmp/nonexistent_claude_\(UUID().uuidString)")
        let provider = ClaudeProvider(customHomeDir: nonexistentDir)
        XCTAssertEqual(provider.id, .claude)
        XCTAssertFalse(provider.isEnabledByDefault)
        
        let isConnected = await provider.checkConnection()
        XCTAssertFalse(isConnected)
        
        let snapshot = try await provider.fetchUsage()
        XCTAssertFalse(snapshot.isAvailable)
    }
    
private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

    // MARK: - Refresh Scheduler Tests (AI-ANTIGRAVITY-004)
    
    @MainActor
    func testRefreshSchedulerIntervalsAndManualTrigger() async {
        let scheduler = RefreshScheduler()
        scheduler.interval = .manual
        XCTAssertEqual(scheduler.interval.rawValue, 0)
        
        let refreshTriggered = TestBox<Bool>(false)
        scheduler.onRefresh = {
            refreshTriggered.value = true
            return true
        }
        
        await scheduler.triggerManualRefresh()
        XCTAssertTrue(refreshTriggered.value)
        XCTAssertNotNil(scheduler.lastSyncDate)
    }
    
    // MARK: - Provider Registry Coordination & Fault Isolation
    
    @MainActor
    func testProviderRegistryRegistrationAndAdapterLookup() {
        let repo = UsageRepository(customPath: "/tmp/test_ai_registry_\(UUID().uuidString).sqlite")
        defer { repo.clearAllHistory() }
        
        let scheduler = RefreshScheduler()
        let registry = ProviderRegistry(repository: repo, scheduler: scheduler)
        
        XCTAssertNotNil(registry.adapter(for: .antigravity))
        XCTAssertNotNil(registry.adapter(for: .codex))
        XCTAssertNotNil(registry.adapter(for: .claude))
    }
}
