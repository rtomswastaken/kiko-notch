import Foundation

/// Connection status states for the WakaTime integration.
public enum WakaTimeConnectionStatus: Equatable, Sendable {
    case notConfigured
    case connecting
    case connected
    case loading
    case noData
    case offline(String)
    case authFailure(String)
    case rateLimited(String)
    case apiError(String)
    case cached
    
    public var displayText: String {
        switch self {
        case .notConfigured: return "Not Configured"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .loading: return "Updating..."
        case .noData: return "No Activity"
        case .offline(let msg): return "Offline: \(msg)"
        case .authFailure(let msg): return "Auth Failed: \(msg)"
        case .rateLimited(let msg): return "Rate Limited: \(msg)"
        case .apiError(let msg): return "API Error: \(msg)"
        case .cached: return "Cached"
        }
    }
    
    public var isSuccess: Bool {
        switch self {
        case .connected, .cached: return true
        default: return false
        }
    }
}

/// Represents coding activity on a single calendar day for the annual heatmap.
public struct WakaTimeDayActivity: Identifiable, Sendable, Equatable {
    public var id: String { dateString }
    public let date: Date
    public let dateString: String // "YYYY-MM-DD"
    public let totalSeconds: Double
    public let humanReadableText: String
    public let intensityLevel: Int // 0 to 4
    public let isAvailable: Bool
    
    public init(
        date: Date,
        dateString: String,
        totalSeconds: Double,
        humanReadableText: String,
        intensityLevel: Int,
        isAvailable: Bool = true
    ) {
        self.date = date
        self.dateString = dateString
        self.totalSeconds = totalSeconds
        self.humanReadableText = humanReadableText
        self.intensityLevel = intensityLevel
        self.isAvailable = isAvailable
    }
    
    /// Formats seconds into clean compact text like "2h 34m" or "0s"
    public static func formatDuration(seconds: Double) -> String {
        guard seconds > 0 else { return "0m" }
        let totalMins = Int(round(seconds / 60.0))
        let hours = totalMins / 60
        let mins = totalMins % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    /// Classifies total coding seconds into 0 to 4 intensity levels
    public static func computeIntensity(seconds: Double) -> Int {
        if seconds <= 0 { return 0 }
        let hours = seconds / 3600.0
        if hours < 1.0 { return 1 }
        if hours < 3.0 { return 2 }
        if hours < 6.0 { return 3 }
        return 4
    }
}

/// Aggregated coding statistics displayed beside the quota indicators.
public struct WakaTimeCodingStats: Sendable, Equatable {
    public var todaySeconds: Double
    public var todayText: String
    public var last7DaysSeconds: Double
    public var last7DaysText: String
    public var allTimeSeconds: Double
    public var allTimeText: String
    public var lastUpdated: Date?
    public var status: WakaTimeConnectionStatus
    
    public static let empty = WakaTimeCodingStats(
        todaySeconds: 0,
        todayText: "—",
        last7DaysSeconds: 0,
        last7DaysText: "—",
        allTimeSeconds: 0,
        allTimeText: "—",
        lastUpdated: nil,
        status: .notConfigured
    )
    
    public init(
        todaySeconds: Double,
        todayText: String,
        last7DaysSeconds: Double,
        last7DaysText: String,
        allTimeSeconds: Double,
        allTimeText: String,
        lastUpdated: Date? = nil,
        status: WakaTimeConnectionStatus = .notConfigured
    ) {
        self.todaySeconds = todaySeconds
        self.todayText = todayText
        self.last7DaysSeconds = last7DaysSeconds
        self.last7DaysText = last7DaysText
        self.allTimeSeconds = allTimeSeconds
        self.allTimeText = allTimeText
        self.lastUpdated = lastUpdated
        self.status = status
    }
}

// MARK: - WakaTime Official API Response Schemas

/// Schema for `GET /api/v1/users/current/all_time_since_today`
public struct WakaTimeAllTimeResponse: Decodable {
    public struct DataClass: Decodable {
        public let total_seconds: Double?
        public let text: String?
        public let decimal: String?
        public let digital: String?
        public let is_up_to_date: Bool?
    }
    public let data: DataClass?
}

/// Schema for `GET /api/v1/users/current/summaries`
public struct WakaTimeSummariesResponse: Decodable {
    public struct DaySummary: Decodable {
        public struct GrandTotal: Decodable {
            public let total_seconds: Double?
            public let text: String?
            public let digital: String?
            public let hours: Int?
            public let minutes: Int?
        }
        public struct DayRange: Decodable {
            public let date: String?
            public let text: String?
            public let start: String?
            public let end: String?
        }
        
        public let grand_total: GrandTotal?
        public let range: DayRange?
    }
    
    public struct CumulativeTotal: Decodable {
        public let total_seconds: Double?
        public let text: String?
        public let decimal: String?
    }
    
    public let data: [DaySummary]?
    public let cumulative_total: CumulativeTotal?
    public let start: String?
    public let end: String?
}

/// Schema for `GET /api/v1/users/current` profile / connection check
public struct WakaTimeUserResponse: Decodable {
    public struct UserData: Decodable {
        public let id: String?
        public let username: String?
        public let display_name: String?
        public let email: String?
    }
    public let data: UserData?
}
