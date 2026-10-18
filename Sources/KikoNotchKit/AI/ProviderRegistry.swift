import Foundation
import Combine

/// Central coordinator for AI Provider Adapters, persistence, and scheduling.
@MainActor
public final class ProviderRegistry: ObservableObject {
    public static let shared = ProviderRegistry()
    
    @Published public private(set) var snapshots: [AIProviderID: AIUsageSnapshot] = [:]
    @Published public private(set) var activeThresholdAlerts: [AIProviderID: String] = [:]
    
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
                    await self?.refreshAll()
                }
            }
            .store(in: &cancellables)
    }
    
    public func register(_ provider: any AIProviderAdapter) {
        providers[provider.id] = provider
    }
    
    public func adapter(for id: AIProviderID) -> (any AIProviderAdapter)? {
        providers[id]
    }
    
    @discardableResult
    public func refreshAll() async -> Bool {
        var allSucceeded = true
        let enabled = SettingsManager.shared.enabledAIProviders
        
        for (id, adapter) in providers {
            guard enabled.contains(id.rawValue) else { continue }
            
            do {
                let snapshot = try await adapter.fetchUsage()
                snapshots[id] = snapshot
                repository.recordSnapshot(snapshot)
                
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
            }
        }
        
        return allSucceeded
    }
}
