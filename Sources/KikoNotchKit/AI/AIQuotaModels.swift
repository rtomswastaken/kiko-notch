import Foundation

/// Standard or custom quota window types.
public enum AIQuotaWindowType: Equatable, Hashable, Sendable {
    case fiveHour
    case weekly
    case monthly
    case session
    case custom(String)
    
    public var label: String {
        switch self {
        case .fiveHour: return "5-HOUR"
        case .weekly: return "WEEKLY"
        case .monthly: return "MONTHLY"
        case .session: return "SESSION"
        case .custom(let name): return name.uppercased()
        }
    }
}

/// Explicit lifecycle and retrieval status for an AI quota or usage gauge.
public enum AIQuotaMetricStatus: String, Sendable, Equatable, Codable {
    case active         // Valid remaining percentage available (e.g. 75% remaining)
    case tokenUsage     // Verified token consumption tracked (e.g. 3.2M tokens consumed)
    case loading        // Currently refreshing
    case stale          // Previously retrieved but stale
    case authRequired   // Authentication or API key required
    case unavailable    // Provider installation / CLI not found
    case unsupported    // Provider does not expose this window or quota metric
    case failed         // Network, CLI, or parsing error
}

/// Diagnostic metadata for provider retrieval transparency.
public struct AIProviderDiagnostics: Sendable, Equatable {
    public let providerID: AIProviderID
    public var providerId: AIProviderID { providerID }
    public let dataSource: String
    public let lastRefreshStart: Date?
    public let lastRefreshCompletion: Date?
    public let lastSuccessfulRefresh: Date?
    public let isRefreshing: Bool
    public let processExitStatus: Int32?
    public let parsingOutcome: String
    public let errorCategory: String?
    public let statusMessage: String
    
    public init(
        providerID: AIProviderID,
        dataSource: String = "",
        lastRefreshStart: Date? = nil,
        lastRefreshCompletion: Date? = nil,
        lastSuccessfulRefresh: Date? = nil,
        isRefreshing: Bool = false,
        processExitStatus: Int32? = nil,
        parsingOutcome: String = "",
        errorCategory: String? = nil,
        statusMessage: String = ""
    ) {
        self.providerID = providerID
        self.dataSource = dataSource
        self.lastRefreshStart = lastRefreshStart
        self.lastRefreshCompletion = lastRefreshCompletion
        self.lastSuccessfulRefresh = lastSuccessfulRefresh
        self.isRefreshing = isRefreshing
        self.processExitStatus = processExitStatus
        self.parsingOutcome = parsingOutcome
        self.errorCategory = errorCategory
        self.statusMessage = statusMessage
    }
    
    public var statusSummary: String {
        if isRefreshing {
            return "Refreshing..."
        }
        if let err = errorCategory {
            return "Error: \(err)"
        }
        if let last = lastSuccessfulRefresh {
            let df = DateFormatter()
            df.timeStyle = .short
            return "Synced \(df.string(from: last))"
        }
        return statusMessage.isEmpty ? "Ready" : statusMessage
    }
}

/// Normalized single quota gauge metric for the 3 circular indicators.
public struct AIQuotaMetric: Identifiable, Sendable, Equatable {
    public var id: String { "\(windowType.label)-\(windowLabel)" }
    public let windowType: AIQuotaWindowType
    public let windowLabel: String
    public let status: AIQuotaMetricStatus
    public let remainingPercent: Double? // 0.0 to 1.0; nil if unavailable
    public let remainingText: String?
    public let usedAmount: Double?
    public let totalLimit: Double?
    public let resetDate: Date?
    public let isAvailable: Bool
    public let statusMessage: String
    public let lastUpdated: Date

    /// Computed remaining tokens if totalLimit is available
    public var remainingTokens: Double? {
        if let total = totalLimit, let used = usedAmount {
            return max(0.0, total - used)
        }
        if let total = totalLimit, let p = remainingPercent {
            return max(0.0, total * p)
        }
        return nil
    }
    
    public init(
        windowType: AIQuotaWindowType,
        windowLabel: String? = nil,
        status: AIQuotaMetricStatus? = nil,
        remainingPercent: Double? = nil,
        remainingText: String? = nil,
        usedAmount: Double? = nil,
        totalLimit: Double? = nil,
        resetDate: Date? = nil,
        isAvailable: Bool = true,
        statusMessage: String = "",
        lastUpdated: Date = Date()
    ) {
        self.windowType = windowType
        self.windowLabel = windowLabel ?? windowType.label
        
        // Infer status if not explicitly passed (for backwards compatibility)
        if let explicitStatus = status {
            self.status = explicitStatus
        } else if !isAvailable {
            let lower = statusMessage.lowercased()
            if lower.contains("key") || lower.contains("auth") || lower.contains("unauthorized") {
                self.status = .authRequired
            } else if lower.contains("not found") || lower.contains("not installed") || lower.contains("offline") {
                self.status = .unavailable
            } else if lower.contains("unsupported") || lower.contains("does not expose") {
                self.status = .unsupported
            } else if lower.contains("error") || lower.contains("failed") {
                self.status = .failed
            } else {
                self.status = .unavailable
            }
        } else if remainingPercent != nil {
            self.status = .active
        } else if usedAmount != nil {
            self.status = .tokenUsage
        } else {
            self.status = .unsupported
        }
        
        // Clamped to 0.0 ... 1.0 if provided
        if let p = remainingPercent {
            self.remainingPercent = min(max(p, 0.0), 1.0)
        } else {
            self.remainingPercent = nil
        }
        self.remainingText = remainingText
        self.usedAmount = usedAmount
        self.totalLimit = totalLimit
        self.resetDate = resetDate
        self.isAvailable = isAvailable
        self.statusMessage = statusMessage
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Factory Constructors
    
    public static func active(
        window: AIQuotaWindowType,
        windowLabel: String? = nil,
        remainingPercent: Double,
        remainingText: String? = nil,
        usedAmount: Double? = nil,
        totalLimit: Double? = nil,
        resetDate: Date? = nil,
        statusMessage: String = "Active"
    ) -> AIQuotaMetric {
        AIQuotaMetric(
            windowType: window,
            windowLabel: windowLabel,
            status: .active,
            remainingPercent: remainingPercent,
            remainingText: remainingText ?? "\(Int(round(remainingPercent * 100)))% left",
            usedAmount: usedAmount,
            totalLimit: totalLimit,
            resetDate: resetDate,
            isAvailable: true,
            statusMessage: statusMessage
        )
    }

    public static func tokenUsage(
        window: AIQuotaWindowType,
        windowLabel: String? = nil,
        usedTokens: Double,
        totalLimit: Double? = nil,
        formattedTokens: String = "",
        label: String? = nil,
        statusMessage: String = "Verified Token Usage"
    ) -> AIQuotaMetric {
        let percent: Double? = {
            if let total = totalLimit, total > 0 {
                let remaining = max(0.0, total - usedTokens)
                return min(max(remaining / total, 0.0), 1.0)
            }
            return nil
        }()

        let text = formattedTokens.isEmpty ? (label ?? "\(Int(usedTokens))") : formattedTokens
        return AIQuotaMetric(
            windowType: window,
            windowLabel: windowLabel,
            status: .tokenUsage,
            remainingPercent: percent,
            remainingText: text,
            usedAmount: usedTokens,
            totalLimit: totalLimit,
            isAvailable: true,
            statusMessage: statusMessage
        )
    }
    
    public static func loading(window: AIQuotaWindowType) -> AIQuotaMetric {
        AIQuotaMetric(
            windowType: window,
            status: .loading,
            remainingText: "Updating...",
            isAvailable: true,
            statusMessage: "Refreshing usage metrics..."
        )
    }
    
    public static func stale(from metric: AIQuotaMetric, reason: String = "Stale (refresh failed)") -> AIQuotaMetric {
        AIQuotaMetric(
            windowType: metric.windowType,
            windowLabel: metric.windowLabel,
            status: .stale,
            remainingPercent: metric.remainingPercent,
            remainingText: metric.remainingText,
            usedAmount: metric.usedAmount,
            totalLimit: metric.totalLimit,
            resetDate: metric.resetDate,
            isAvailable: true,
            statusMessage: reason,
            lastUpdated: metric.lastUpdated
        )
    }
    
    public func asStale(reason: String = "Stale (refresh failed)") -> AIQuotaMetric {
        AIQuotaMetric.stale(from: self, reason: reason)
    }

    public static func authRequired(window: AIQuotaWindowType, reason: String = "", message: String? = nil) -> AIQuotaMetric {
        let msg = message ?? reason
        return AIQuotaMetric(
            windowType: window,
            status: .authRequired,
            remainingText: "API Key Required",
            isAvailable: false,
            statusMessage: msg
        )
    }
    
    public static func unavailable(window: AIQuotaWindowType, reason: String) -> AIQuotaMetric {
        AIQuotaMetric(
            windowType: window,
            status: .unavailable,
            remainingText: "Unavailable",
            isAvailable: false,
            statusMessage: reason
        )
    }
    
    public static func unsupported(window: AIQuotaWindowType, reason: String) -> AIQuotaMetric {
        AIQuotaMetric(
            windowType: window,
            status: .unsupported,
            remainingText: "Unsupported",
            isAvailable: false,
            statusMessage: reason
        )
    }
    
    public static func failed(window: AIQuotaWindowType, error: String) -> AIQuotaMetric {
        AIQuotaMetric(
            windowType: window,
            status: .failed,
            remainingText: "Failed",
            isAvailable: false,
            statusMessage: error
        )
    }
}

/// Normalized full quota snapshot for a provider.
public struct AIProviderQuotaSnapshot: Sendable, Equatable {
    public let providerID: AIProviderID
    public let displayName: String
    public let timestamp: Date
    public let isAvailable: Bool
    public let statusMessage: String
    public let quotas: [AIQuotaMetric]
    public var metrics: [AIQuotaMetric] { quotas }
    public let sessionTokens: Int?
    public let sessionRequests: Int?
    public let previousMonthTokens: Int?
    public let diagnostics: AIProviderDiagnostics?
    
    public init(
        providerID: AIProviderID,
        displayName: String,
        timestamp: Date = Date(),
        isAvailable: Bool,
        statusMessage: String,
        quotas: [AIQuotaMetric],
        sessionTokens: Int? = nil,
        sessionRequests: Int? = nil,
        previousMonthTokens: Int? = nil,
        diagnostics: AIProviderDiagnostics? = nil
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.timestamp = timestamp
        self.isAvailable = isAvailable
        self.statusMessage = statusMessage
        self.quotas = quotas
        self.sessionTokens = sessionTokens
        self.sessionRequests = sessionRequests
        self.previousMonthTokens = previousMonthTokens
        self.diagnostics = diagnostics
    }
    
    /// Fallback snapshot when a provider has no data or is not configured
    public static func empty(
        providerID: AIProviderID,
        displayName: String,
        message: String,
        diagnostics: AIProviderDiagnostics? = nil
    ) -> AIProviderQuotaSnapshot {
        let diag = diagnostics ?? AIProviderDiagnostics(
            providerID: providerID,
            statusMessage: message
        )
        return AIProviderQuotaSnapshot(
            providerID: providerID,
            displayName: displayName,
            isAvailable: false,
            statusMessage: message,
            quotas: [
                .unavailable(window: .fiveHour, reason: message),
                .unavailable(window: .weekly, reason: message),
                .unavailable(window: .monthly, reason: message)
            ],
            diagnostics: diag
        )
    }
}
