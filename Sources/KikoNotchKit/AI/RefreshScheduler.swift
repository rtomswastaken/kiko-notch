import Foundation

/// Interval options for AI usage refresh
public enum AIRefreshInterval: Int, CaseIterable, Codable, Sendable {
    case manual = 0
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case oneHour = 3600
    
    public var title: String {
        switch self {
        case .manual: return "Manual Only"
        case .fiveMinutes: return "Every 5 Minutes"
        case .fifteenMinutes: return "Every 15 Minutes"
        case .oneHour: return "Every 1 Hour"
        }
    }
}

/// Refresh scheduler with exponential backoff on errors.
/// Implements AI-ANTIGRAVITY-004.
@MainActor
public final class RefreshScheduler: ObservableObject {
    public static let shared = RefreshScheduler()
    
    @Published public var interval: AIRefreshInterval {
        didSet {
            UserDefaults.standard.set(interval.rawValue, forKey: "kiko.ai.refreshInterval")
            restartTimer()
        }
    }
    
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var isRefreshing: Bool = false
    
    private var timer: Timer?
    private var backoffMultiplier: Double = 1.0
    private let maxBackoffMultiplier: Double = 8.0
    
    public var onRefresh: (@Sendable () async -> Bool)?
    
    public init() {
        let stored = UserDefaults.standard.integer(forKey: "kiko.ai.refreshInterval")
        self.interval = AIRefreshInterval(rawValue: stored) ?? .fifteenMinutes
    }
    
    public func start() {
        restartTimer()
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func triggerManualRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        
        let success = await onRefresh?() ?? true
        if success {
            backoffMultiplier = 1.0
            lastSyncDate = Date()
        } else {
            // Exponential backoff
            backoffMultiplier = min(backoffMultiplier * 2.0, maxBackoffMultiplier)
        }
    }
    
    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        
        guard interval != .manual else { return }
        
        let delay = Double(interval.rawValue) * backoffMultiplier
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.triggerManualRefresh()
            }
        }
    }
}
