import Foundation
import Combine

/// Dedicated service responsible for WakaTime integration, authentication,
/// coding-time aggregation, and annual activity heatmap retrieval.
@MainActor
public final class WakaTimeService: ObservableObject {
    public static let shared = WakaTimeService()
    public static let keychainKey = "wakatime_api_key"
    public static let userDefaultsLastSync = "kiko.wakatime.lastSync"
    
    @Published public private(set) var stats: WakaTimeCodingStats = .empty
    @Published public private(set) var annualActivity: [WakaTimeDayActivity] = []
    @Published public private(set) var isConfigured: Bool = false
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil
    
    private let session: URLSession
    private let baseURL = URL(string: "https://api.wakatime.com/api/v1")!
    private var inFlightTask: Task<Void, Never>?
    private let minRefreshInterval: TimeInterval = 300.0 // 5 minutes cache
    
    public init(session: URLSession = .shared) {
        self.session = session
        self.isConfigured = (KeychainHelper.shared.read(key: Self.keychainKey) != nil)
        if let last = UserDefaults.standard.object(forKey: Self.userDefaultsLastSync) as? Date {
            self.lastSyncDate = last
        }
    }
    
    // MARK: - Credential Management
    
    /// Reads API key securely from Keychain.
    public var apiKey: String? {
        KeychainHelper.shared.read(key: Self.keychainKey)
    }
    
    /// Returns a masked display version of the stored API key (e.g. "••••••••1234").
    public var maskedApiKey: String {
        guard let key = apiKey, !key.isEmpty else { return "Not Configured" }
        if key.count > 4 {
            let suffix = key.suffix(4)
            return "••••••••\(suffix)"
        }
        return "••••••••"
    }
    
    public func saveApiKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        KeychainHelper.shared.save(key: Self.keychainKey, value: clean)
        self.isConfigured = true
    }
    
    public func disconnect() {
        inFlightTask?.cancel()
        inFlightTask = nil
        KeychainHelper.shared.delete(key: Self.keychainKey)
        self.isConfigured = false
        self.stats = .empty
        self.annualActivity = []
        self.lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsLastSync)
    }
    
    // MARK: - Connection Verification
    
    /// Tests connectivity with the provided or stored API key without modifying state.
    public func testConnection(key: String? = nil) async -> (success: Bool, message: String) {
        let keyToUse = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? apiKey
        guard let token = keyToUse, !token.isEmpty else {
            return (false, "No API Key provided")
        }
        
        let url = baseURL.appendingPathComponent("users/current")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        // Canonical WakaTime HTTP Basic Auth header: Basic <base64(api_key)>
        let credentials = Data(token.utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "Invalid HTTP response from WakaTime")
            }
            
            switch http.statusCode {
            case 200...299:
                if let decoded = try? JSONDecoder().decode(WakaTimeUserResponse.self, from: data),
                   let user = decoded.data {
                    let name = user.display_name ?? user.username ?? "User"
                    return (true, "Connected as \(name)")
                }
                return (true, "Connection successful")
            case 401:
                return (false, "Authentication failed (HTTP 401). Verify your API key.")
            case 429:
                return (false, "Rate limit reached (HTTP 429). Please try again later.")
            default:
                return (false, "API returned status \(http.statusCode)")
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Synchronize Data
    
    /// Synchronizes coding stats and annual activity heatmap data.
    public func refresh(force: Bool = false) async {
        guard let token = apiKey, !token.isEmpty else {
            self.stats = .empty
            self.stats.status = .notConfigured
            self.annualActivity = []
            return
        }
        
        // Check cache validity
        if !force, let lastSync = lastSyncDate, Date().timeIntervalSince(lastSync) < minRefreshInterval, !annualActivity.isEmpty {
            self.stats.status = .cached
            return
        }
        
        if isSyncing { return }
        isSyncing = true
        stats.status = .loading
        
        defer {
            isSyncing = false
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        
        // Date range for past 365 calendar days
        let startDate = calendar.date(byAdding: .day, value: -364, to: today) ?? today
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: today)
        
        async let allTimeFetch = fetchAllTimeStats(token: token)
        async let summariesFetch = fetchSummaries(token: token, start: startStr, end: endStr)
        
        let (allTimeResult, summariesResult) = await (allTimeFetch, summariesFetch)
        
        var newStats = WakaTimeCodingStats.empty
        
        // Handle all-time stats
        switch allTimeResult {
        case .success(let allTime):
            newStats.allTimeSeconds = allTime.total_seconds ?? 0
            newStats.allTimeText = allTime.text ?? WakaTimeDayActivity.formatDuration(seconds: allTime.total_seconds ?? 0)
        case .failure(let err):
            newStats.status = .apiError(err.localizedDescription)
        }
        
        // Handle summaries & build heatmap
        switch summariesResult {
        case .success(let summariesResponse):
            let rawDays = summariesResponse.data ?? []
            var daysByDate: [String: WakaTimeSummariesResponse.DaySummary] = [:]
            for d in rawDays {
                if let dateStr = d.range?.date {
                    daysByDate[dateStr] = d
                }
            }
            
            // Generate exact 365 consecutive days
            var builtHeatmap: [WakaTimeDayActivity] = []
            var todaySecs: Double = 0
            var todayTxt = "0m"
            var last7Secs: Double = 0
            
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            
            for offset in 0..<365 {
                guard let dayDate = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
                let dateKey = dateFormatter.string(from: dayDate)
                
                if let summary = daysByDate[dateKey] {
                    let sec = summary.grand_total?.total_seconds ?? 0
                    let txt = summary.grand_total?.text ?? WakaTimeDayActivity.formatDuration(seconds: sec)
                    let intensity = WakaTimeDayActivity.computeIntensity(seconds: sec)
                    
                    builtHeatmap.append(WakaTimeDayActivity(
                        date: dayDate,
                        dateString: dateKey,
                        totalSeconds: sec,
                        humanReadableText: txt,
                        intensityLevel: intensity,
                        isAvailable: true
                    ))
                    
                    if dayDate >= sevenDaysAgo {
                        last7Secs += sec
                    }
                    if calendar.isDate(dayDate, inSameDayAs: today) {
                        todaySecs = sec
                        todayTxt = txt
                    }
                } else {
                    // Day was not returned by API or represents missing data
                    let isPast = dayDate < today
                    builtHeatmap.append(WakaTimeDayActivity(
                        date: dayDate,
                        dateString: dateKey,
                        totalSeconds: 0,
                        humanReadableText: "No activity recorded",
                        intensityLevel: 0,
                        isAvailable: isPast
                    ))
                }
            }
            
            self.annualActivity = builtHeatmap
            newStats.todaySeconds = todaySecs
            newStats.todayText = todaySecs > 0 ? todayTxt : "0m"
            newStats.last7DaysSeconds = last7Secs
            newStats.last7DaysText = WakaTimeDayActivity.formatDuration(seconds: last7Secs)
            newStats.status = .connected
            newStats.lastUpdated = Date()
            
            self.stats = newStats
            self.lastSyncDate = Date()
            UserDefaults.standard.set(self.lastSyncDate, forKey: Self.userDefaultsLastSync)
            
        case .failure(let error):
            if case WakaTimeAPIError.unauthorized = error {
                newStats.status = .authFailure("Invalid API Key")
            } else if case WakaTimeAPIError.rateLimited = error {
                newStats.status = .rateLimited("Rate limit exceeded")
            } else {
                newStats.status = .apiError(error.localizedDescription)
            }
            self.stats = newStats
        }
    }
    
    // MARK: - Private API Helpers
    
    private func fetchAllTimeStats(token: String) async -> Result<WakaTimeAllTimeResponse.DataClass, Error> {
        let url = baseURL.appendingPathComponent("users/current/all_time_since_today")
        var request = URLRequest(url: url)
        request.timeoutInterval = 12.0
        let credentials = Data(token.utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(WakaTimeAPIError.invalidResponse)
            }
            if http.statusCode == 401 { return .failure(WakaTimeAPIError.unauthorized) }
            if http.statusCode == 429 { return .failure(WakaTimeAPIError.rateLimited) }
            guard (200...299).contains(http.statusCode) else {
                return .failure(WakaTimeAPIError.httpError(http.statusCode))
            }
            
            let decoded = try JSONDecoder().decode(WakaTimeAllTimeResponse.self, from: data)
            guard let dataClass = decoded.data else {
                return .failure(WakaTimeAPIError.missingData)
            }
            return .success(dataClass)
        } catch {
            return .failure(error)
        }
    }
    
    private func fetchSummaries(token: String, start: String, end: String) async -> Result<WakaTimeSummariesResponse, Error> {
        var components = URLComponents(url: baseURL.appendingPathComponent("users/current/summaries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start", value: start),
            URLQueryItem(name: "end", value: end)
        ]
        guard let url = components.url else {
            return .failure(WakaTimeAPIError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        let credentials = Data(token.utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(WakaTimeAPIError.invalidResponse)
            }
            if http.statusCode == 401 { return .failure(WakaTimeAPIError.unauthorized) }
            if http.statusCode == 429 { return .failure(WakaTimeAPIError.rateLimited) }
            guard (200...299).contains(http.statusCode) else {
                return .failure(WakaTimeAPIError.httpError(http.statusCode))
            }
            
            let decoded = try JSONDecoder().decode(WakaTimeSummariesResponse.self, from: data)
            return .success(decoded)
        } catch {
            return .failure(error)
        }
    }
}

public enum WakaTimeAPIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(Int)
    case missingData
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid WakaTime URL"
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Unauthorized: Invalid API Key"
        case .rateLimited: return "WakaTime API rate limit exceeded"
        case .httpError(let code): return "HTTP Error \(code)"
        case .missingData: return "Response missing data"
        }
    }
}
