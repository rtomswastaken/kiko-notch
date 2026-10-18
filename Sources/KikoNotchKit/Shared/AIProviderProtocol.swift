import Foundation

/// Supported AI Providers
public enum AIProviderID: String, CaseIterable, Codable, Sendable {
    case antigravity
    case codex
    case claude
}

/// Truthful AI Usage Snapshot
public struct AIUsageSnapshot: Codable, Sendable, Identifiable {
    public var id: String { "\(providerID.rawValue)-\(timestamp.timeIntervalSince1970)" }
    public let providerID: AIProviderID
    public let timestamp: Date
    public let isAvailable: Bool
    public let sessionRequests: Int?
    public let sessionTokens: Int?
    public let remainingQuotaPercent: Double?
    public let quotaResetDate: Date?
    public let modelBreakdown: [String: Int]
    public let statusMessage: String
    
    public init(
        providerID: AIProviderID,
        timestamp: Date = Date(),
        isAvailable: Bool,
        sessionRequests: Int? = nil,
        sessionTokens: Int? = nil,
        remainingQuotaPercent: Double? = nil,
        quotaResetDate: Date? = nil,
        modelBreakdown: [String: Int] = [:],
        statusMessage: String
    ) {
        self.providerID = providerID
        self.timestamp = timestamp
        self.isAvailable = isAvailable
        self.sessionRequests = sessionRequests
        self.sessionTokens = sessionTokens
        self.remainingQuotaPercent = remainingQuotaPercent
        self.quotaResetDate = quotaResetDate
        self.modelBreakdown = modelBreakdown
        self.statusMessage = statusMessage
    }
}

/// Common Protocol for all AI Provider Adapters
public protocol AIProviderAdapter: AnyObject, Sendable {
    var id: AIProviderID { get }
    var displayName: String { get }
    var isEnabledByDefault: Bool { get }
    func checkConnection() async -> Bool
    func fetchUsage() async throws -> AIUsageSnapshot
}
