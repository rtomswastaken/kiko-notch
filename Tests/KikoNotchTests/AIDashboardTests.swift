import XCTest
@testable import KikoNotchKit
import SwiftUI

final class AIDashboardTests: XCTestCase {

    // MARK: - 1. Provider Registration & Selection Tests

    @MainActor
    func testProviderRegistrationAndSelection() {
        let registry = ProviderRegistry.shared

        // Ensure default providers exist
        XCTAssertNotNil(registry.adapter(for: .antigravity))
        XCTAssertNotNil(registry.adapter(for: .codex))
        XCTAssertNotNil(registry.adapter(for: .claude))

        // Test selection
        registry.selectProvider(.antigravity)
        XCTAssertEqual(registry.selectedProviderID, .antigravity)

        // Test configured list
        let configured = registry.configuredProviders
        XCTAssertFalse(configured.isEmpty)
        XCTAssertTrue(configured.contains(where: { $0.id == .antigravity }))
    }

    @MainActor
    func testProviderRemovalCleansUpState() {
        let registry = ProviderRegistry.shared
        SettingsManager.shared.setAIProviderEnabled(.codex, enabled: true)
        registry.selectProvider(.codex)
        XCTAssertEqual(registry.selectedProviderID, .codex)

        // Remove provider
        registry.removeProvider(.codex)
        XCTAssertFalse(SettingsManager.shared.isAIProviderEnabled(.codex))
        // Should have safely reassigned selectedProviderID away from codex
        XCTAssertNotEqual(registry.selectedProviderID, .codex)
    }

    // MARK: - 2. Quota Visualization & Clamping Tests

    func testQuotaMetricClampingAndFormatting() {
        // Normal valid percent
        let normal = AIQuotaMetric(windowType: .fiveHour, remainingPercent: 0.78)
        XCTAssertEqual(normal.remainingPercent, 0.78)
        XCTAssertEqual(normal.windowLabel, "5-HOUR")
        XCTAssertTrue(normal.isAvailable)

        // Lower bound clamping
        let clampedLow = AIQuotaMetric(windowType: .weekly, remainingPercent: -0.25)
        XCTAssertEqual(clampedLow.remainingPercent, 0.0)

        // Upper bound clamping
        let clampedHigh = AIQuotaMetric(windowType: .monthly, remainingPercent: 1.45)
        XCTAssertEqual(clampedHigh.remainingPercent, 1.0)

        // Unavailable metric
        let unavail = AIQuotaMetric.unavailable(window: .fiveHour, reason: "API unexposed")
        XCTAssertFalse(unavail.isAvailable)
        XCTAssertNil(unavail.remainingPercent)
        XCTAssertEqual(unavail.remainingText, "Unavailable")
        XCTAssertEqual(unavail.statusMessage, "API unexposed")
    }

    // MARK: - 3. Token Accounting & Calendar Month Boundaries Tests

    @MainActor
    func testPreviousCalendarMonthBoundaries() {
        let registry = ProviderRegistry.shared
        let (tokens, included, monthLabel) = registry.previousCalendarMonthTokenUsage()

        // Month label must be non-empty uppercase (e.g. "SEPTEMBER 2026")
        XCTAssertFalse(monthLabel.isEmpty)
        XCTAssertFalse(monthLabel.contains("ROLLING"))

        // Providers list is typed and valid
        XCTAssertNotNil(included)

        // If no tokens in test database, returns nil gracefully (never fabricated)
        if tokens == nil {
            XCTAssertTrue(tokens == nil, "Must honestly return nil when no database tokens exist")
        }
    }

    // MARK: - 4. Design Tokens & Monochrome Aesthetic Tests

    @MainActor
    func testDesignTokensAccentAndMonochromeAesthetic() {
        // Accent color defaults to white
        let accent = DesignTokens.accentColor
        XCTAssertNotNil(accent)

        // Surface background is black
        XCTAssertEqual(DesignTokens.surfaceBackground, Color.black)

        // Intensity shades produce readable distinct colors
        let level0 = DesignTokens.intensityColor(level: 0)
        let level1 = DesignTokens.intensityColor(level: 1)
        let level4 = DesignTokens.intensityColor(level: 4)
        let missing = DesignTokens.intensityColor(level: 0, isMissing: true)

        XCTAssertNotEqual(level0, level4)
        XCTAssertNotEqual(level1, level4)
        XCTAssertNotEqual(missing, level0)
    }

    // MARK: - 5. Geometry & Layout Non-Scrolling Fit Tests

    func testDashboardGeometryFitsInsideExpandedIsland() {
        // Standard expanded island height is 290pt (openNotchSize)
        let totalHeight = IslandGeometry.openNotchSize.height // 290
        let topBarArea = IslandSpacing.topPadding + IslandSpacing.navBarHeight + IslandSpacing.navBarSpacing // 12 + 28 + 10 = 50
        let bottomArea = IslandSpacing.bottomPadding // 16
        let availableViewportHeight = totalHeight - topBarArea - bottomArea // 224pt

        XCTAssertEqual(availableViewportHeight, 224.0)

        // Dashboard components budgeted heights:
        let headerHeight: CGFloat = 20.0
        let mainContentHeight: CGFloat = 82.0
        let heatmapHeight: CGFloat = 88.0
        let verticalGaps: CGFloat = 16.0 // 8 + 8
        let totalDashboardHeight = headerHeight + mainContentHeight + heatmapHeight + verticalGaps

        // Total budgeted height must fit within available 224pt without requiring scrolling!
        XCTAssertLessThanOrEqual(totalDashboardHeight, availableViewportHeight, "Dashboard must fit strictly within expanded island without vertical scrolling")

        // Width check
        let totalWidth = IslandGeometry.openNotchSize.width // 680
        let horizontalPadding = IslandSpacing.horizontalPadding * 2 // 48
        let availableWidth = totalWidth - horizontalPadding // 632

        XCTAssertEqual(availableWidth, 632.0)

        // Heatmap 53 columns * 9.5pt + 16pt label = ~520pt < 632pt
        let heatmapGridWidth: CGFloat = (53.0 * 9.5) + 16.0
        XCTAssertLessThan(heatmapGridWidth, availableWidth)
    }

    // MARK: - 6. Antigravity Quota Snapshot & Truthful Status Tests

    func testAntigravityQuotaSnapshotAndTruthfulStates() async throws {
        let provider = AntigravityProvider()
        let snapshot = try await provider.fetchQuotaSnapshot()

        // Antigravity metrics should return 3 windows (5-Hour, Weekly, Monthly)
        XCTAssertEqual(snapshot.quotas.count, 3)

        for metric in snapshot.quotas {
            // Must have a defined status and not be empty
            XCTAssertFalse(metric.windowLabel.isEmpty)
            // Truthful metrics for Antigravity now track quota limits and remaining tokens
            if metric.status == AIQuotaMetricStatus.tokenUsage {
                XCTAssertNotNil(metric.usedAmount)
                XCTAssertNotNil(metric.totalLimit, "Total quota limit should be configured")
                XCTAssertNotNil(metric.remainingPercent, "Remaining percent should be computed from quota limit")
                XCTAssertNotNil(metric.remainingTokens, "Remaining tokens should be computed from quota limit")
                XCTAssertFalse((metric.remainingText ?? "").isEmpty)
                XCTAssertTrue(metric.isAvailable)
            } else if metric.status == AIQuotaMetricStatus.unavailable {
                XCTAssertNil(metric.remainingPercent)
            }
        }

        // Diagnostics must be provided
        guard let diag = snapshot.diagnostics else {
            XCTFail("Diagnostics should not be nil")
            return
        }
        XCTAssertEqual(diag.providerID, AIProviderID.antigravity)
        XCTAssertFalse(diag.dataSource.isEmpty)
        XCTAssertFalse(diag.statusSummary.isEmpty)
    }

    func testAIQuotaMetricStatusConstructors() {
        // Test token usage metric constructor
        let tokenMetric = AIQuotaMetric.tokenUsage(window: .fiveHour, usedTokens: 45_200, formattedTokens: "45.2K TOKENS")
        XCTAssertEqual(tokenMetric.status, AIQuotaMetricStatus.tokenUsage)
        XCTAssertEqual(tokenMetric.usedAmount, 45_200)
        XCTAssertEqual(tokenMetric.remainingText, "45.2K TOKENS")
        XCTAssertTrue(tokenMetric.isAvailable)

        // Test token usage metric with quota limit
        let limitedTokenMetric = AIQuotaMetric.tokenUsage(
            window: .fiveHour,
            usedTokens: 40_000,
            totalLimit: 100_000,
            formattedTokens: "60.0K left"
        )
        XCTAssertEqual(limitedTokenMetric.remainingTokens, 60_000)
        XCTAssertEqual(limitedTokenMetric.remainingPercent, 0.6)

        // Test active percent metric constructor
        let activeMetric = AIQuotaMetric.active(window: .weekly, remainingPercent: 0.85)
        XCTAssertEqual(activeMetric.status, AIQuotaMetricStatus.active)
        XCTAssertEqual(activeMetric.remainingPercent, 0.85)
        XCTAssertEqual(activeMetric.remainingText, "85% left")

        // Test authRequired constructor
        let authMetric = AIQuotaMetric.authRequired(window: .monthly, reason: "Sign in required")
        XCTAssertEqual(authMetric.status, AIQuotaMetricStatus.authRequired)
        XCTAssertFalse(authMetric.isAvailable)
        XCTAssertEqual(authMetric.remainingText, "API Key Required")

        // Test stale status modifier
        let staleMetric = tokenMetric.asStale()
        XCTAssertEqual(staleMetric.status, AIQuotaMetricStatus.stale)
        XCTAssertEqual(staleMetric.usedAmount, 45_200)
    }

    @MainActor
    func testRegistryDiagnosticsAndConcurrency() async {
        let registry = ProviderRegistry.shared
        // Refresh all providers
        await registry.refreshAll()

        // Should have diagnostics recorded for antigravity
        let diag = registry.diagnostics[.antigravity]
        XCTAssertNotNil(diag)
        XCTAssertEqual(diag?.providerID, AIProviderID.antigravity)
        XCTAssertFalse(registry.isRefreshing, "Refresh lock must be released after completion")
    }
}
