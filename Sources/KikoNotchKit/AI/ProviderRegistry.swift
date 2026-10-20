import Foundation
import Combine

/// Central coordinator for AI Provider Adapters, persistence, and scheduling.
@MainActor
public final class ProviderRegistry: ObservableObject {
    public static let shared = ProviderRegistry()

    @Published public private(set) var snapshots: [AIProviderID: AIUsageSnapshot] = [:]
    @Published public private(set) var quotaSnapshots: [AIProviderID: AIProviderQuotaSnapshot] = [:]
    @Published public private(set) var diagnostics: [AIProviderID: AIProviderDiagnostics] = [:]
    @Published public private(set) var activeThresholdAlerts: [AIProviderID: String] = [:]
    @Published public private(set) var isRefreshing: Bool = false
    @Published public var selectedProviderID: AIProviderID? = nil

    private var providers: [AIProviderID: any AIProviderAdapter] = [:]
    private let repository: UsageRepository
    private let scheduler: RefreshScheduler
    private var cancellables = Set<AnyCancellable>()

    public init(repository: UsageRepository = .shared, scheduler: RefreshScheduler? = nil) {
        self.repository = repository
        let sched = scheduler ?? RefreshScheduler.shared
        self.scheduler = sched

        // Register default adapters
        register(AntigravityProvider())
        register(CodexProvider())
        register(ClaudeProvider())

        // Load most recent snapshots from repository
        for id in AIProviderID.allCases {
            if let latest = repository.fetchSnapshots(for: id, limit: 1).first {
                snapshots[id] = latest
            }
        }

        // Initial selected provider
        updateSelectedProvider()

        // Setup scheduler callback
        self.scheduler.onRefresh = { [weak self] in
            guard let self = self else { return true }
            return await self.refreshAll()
        }

        // Listen to SettingsManager AI provider toggle changes
        SettingsManager.shared.$enabledAIProviders
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateSelectedProvider()
                    await self?.refreshAll()
                }
            }
            .store(in: &cancellables)
    }

    public func register(_ provider: any AIProviderAdapter) {
        providers[provider.id] = provider
        updateSelectedProvider()
    }

    public func adapter(for id: AIProviderID) -> (any AIProviderAdapter)? {
        providers[id]
    }

    /// Returns only providers that are currently enabled/configured in Settings
    public var configuredProviders: [any AIProviderAdapter] {
        let enabled = SettingsManager.shared.enabledAIProviders
        return providers.values.filter { enabled.contains($0.id.rawValue) }.sorted { $0.displayName < $1.displayName }
    }

    public func selectProvider(_ id: AIProviderID) {
        selectedProviderID = id
    }

    private func updateSelectedProvider() {
        let configured = configuredProviders
        if let current = selectedProviderID, configured.contains(where: { $0.id == current }) {
            return
        }
        selectedProviderID = configured.first?.id
    }

    /// Removes a provider: disables in settings, deletes secret from Keychain, clears snapshots
    public func removeProvider(_ id: AIProviderID) {
        SettingsManager.shared.setAIProviderEnabled(id, enabled: false)
        switch id {
        case .codex:
            KeychainHelper.shared.delete(key: CodexProvider.keychainKey)
        case .claude:
            KeychainHelper.shared.delete(key: ClaudeProvider.keychainKey)
        case .antigravity:
            break
        }
        snapshots.removeValue(forKey: id)
        quotaSnapshots.removeValue(forKey: id)
        activeThresholdAlerts.removeValue(forKey: id)
        updateSelectedProvider()
    }

    /// Calculates total token usage for previous calendar month across configured AI providers
    public func previousCalendarMonthTokenUsage() -> (totalTokens: Int?, includedProviders: [String], monthLabel: String) {
        let calendar = Calendar.current
        let now = Date()

        // Boundaries of previous calendar month
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart),
              let prevMonthEnd = calendar.date(byAdding: .second, value: -1, to: currentMonthStart) else {
            return (nil, [], "PREVIOUS MONTH")
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthName = monthFormatter.string(from: prevMonthStart).uppercased()

        var total = 0
        var hasData = false
        var included: [String] = []

        for provider in configuredProviders {
            // Check in-memory snapshot first
            if let snap = quotaSnapshots[provider.id], let prev = snap.previousMonthTokens {
                total += prev
                hasData = true
                included.append(provider.displayName)
            } else if let count = repository.fetchTotalTokens(for: provider.id, startDate: prevMonthStart, endDate: prevMonthEnd) {
                total += count
                hasData = true
                included.append(provider.displayName)
            }
        }

        return (hasData ? total : nil, included, monthName)
    }

    @discardableResult
    public func refreshAll(force: Bool = false) async -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        var allSucceeded = true
        let enabled = SettingsManager.shared.enabledAIProviders

        for (id, adapter) in providers {
            guard enabled.contains(id.rawValue) else { continue }

            let startTime = Date()
            diagnostics[id] = AIProviderDiagnostics(
                providerID: id,
                dataSource: adapter.displayName,
                lastRefreshStart: startTime,
                isRefreshing: true,
                statusMessage: "Refreshing..."
            )

            do {
                let snapshot = try await adapter.fetchUsage()
                snapshots[id] = snapshot
                repository.recordSnapshot(snapshot)

                let quotaSnap = try await adapter.fetchQuotaSnapshot()
                quotaSnapshots[id] = quotaSnap

                if let diag = quotaSnap.diagnostics {
                    diagnostics[id] = diag
                } else {
                    diagnostics[id] = AIProviderDiagnostics(
                        providerID: id,
                        dataSource: adapter.displayName,
                        lastRefreshStart: startTime,
                        lastRefreshCompletion: Date(),
                        lastSuccessfulRefresh: Date(),
                        isRefreshing: false,
                        parsingOutcome: "Success",
                        statusMessage: quotaSnap.statusMessage
                    )
                }

                // Check quota threshold warnings (AI-ANTIGRAVITY-006)
                if let quota = snapshot.remainingQuotaPercent, quota <= 0.20 {
                    activeThresholdAlerts[id] = "\(adapter.displayName) quota low: \(Int(quota * 100))% remaining"
                } else {
                    activeThresholdAlerts.removeValue(forKey: id)
                }
            } catch {
                allSucceeded = false
                let errorSnapshot = AIUsageSnapshot(
                    providerID: id,
                    isAvailable: false,
                    statusMessage: "Error: \(error.localizedDescription)"
                )
                snapshots[id] = errorSnapshot
                repository.recordSnapshot(errorSnapshot)

                let errorDiag = AIProviderDiagnostics(
                    providerID: id,
                    dataSource: adapter.displayName,
                    lastRefreshStart: startTime,
                    lastRefreshCompletion: Date(),
                    lastSuccessfulRefresh: diagnostics[id]?.lastSuccessfulRefresh,
                    isRefreshing: false,
                    parsingOutcome: "Failed",
                    errorCategory: "FetchError",
                    statusMessage: "Error: \(error.localizedDescription)"
                )
                diagnostics[id] = errorDiag

                // Preserve last valid reading as stale if available
                if let existing = quotaSnapshots[id], existing.isAvailable {
                    let staleQuotas = existing.quotas.map { AIQuotaMetric.stale(from: $0, reason: "Stale: \(error.localizedDescription)") }
                    quotaSnapshots[id] = AIProviderQuotaSnapshot(
                        providerID: id,
                        displayName: adapter.displayName,
                        timestamp: existing.timestamp,
                        isAvailable: true,
                        statusMessage: "Stale: refresh failed (\(error.localizedDescription))",
                        quotas: staleQuotas,
                        sessionTokens: existing.sessionTokens,
                        sessionRequests: existing.sessionRequests,
                        previousMonthTokens: existing.previousMonthTokens,
                        diagnostics: errorDiag
                    )
                } else {
                    quotaSnapshots[id] = AIProviderQuotaSnapshot.empty(
                        providerID: id,
                        displayName: adapter.displayName,
                        message: "Error: \(error.localizedDescription)",
                        diagnostics: errorDiag
                    )
                }
            }
        }

        updateSelectedProvider()
        return allSucceeded
    }
}
