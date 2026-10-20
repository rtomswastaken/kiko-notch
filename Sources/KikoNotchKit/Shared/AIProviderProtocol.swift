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
    var isConfigured: Bool { get }
    var capabilities: String { get }
    var limitations: String { get }
    func checkConnection() async -> Bool
    func fetchUsage() async throws -> AIUsageSnapshot
    func fetchQuotaSnapshot() async throws -> AIProviderQuotaSnapshot
}

public extension AIProviderAdapter {
    var isConfigured: Bool {
        SettingsManager.shared.isAIProviderEnabled(id)
    }

    var capabilities: String {
        "AI session and usage tracking"
    }

    var limitations: String {
        "Subscription quota windows not publicly exposed"
    }

    func fetchQuotaSnapshot() async throws -> AIProviderQuotaSnapshot {
        let usage = try await fetchUsage()
        var quotas: [AIQuotaMetric] = []

        if let remaining = usage.remainingQuotaPercent {
            quotas.append(AIQuotaMetric(
                windowType: .fiveHour,
                remainingPercent: remaining,
                remainingText: "\(Int(remaining * 100))% left",
                resetDate: usage.quotaResetDate,
                isAvailable: true,
                statusMessage: "Active"
            ))
        } else {
            quotas.append(.unavailable(window: .fiveHour, reason: "\(displayName) does not expose 5-hour quota API"))
        }

        quotas.append(.unavailable(window: .weekly, reason: "\(displayName) does not expose weekly quota API"))
        quotas.append(.unavailable(window: .monthly, reason: "\(displayName) does not expose monthly quota API"))

        return AIProviderQuotaSnapshot(
            providerID: id,
            displayName: displayName,
            timestamp: usage.timestamp,
            isAvailable: usage.isAvailable,
            statusMessage: usage.statusMessage,
            quotas: quotas,
            sessionTokens: usage.sessionTokens,
            sessionRequests: usage.sessionRequests
        )
    }
}
