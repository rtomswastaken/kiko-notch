import Foundation

/// Optional Anthropic Claude Provider Adapter.
/// Implements AI-CLAUDE-001, AI-CLAUDE-002, and AI-CLAUDE-003 with complete error isolation.
public final class ClaudeProvider: AIProviderAdapter, @unchecked Sendable {
    public let id: AIProviderID = .claude
    public let displayName: String = "Anthropic Claude"
    public let isEnabledByDefault: Bool = false
    
    public static let keychainKey = "claude_api_key"
    private let urlSession: URLSession
    private let claudeHomeDir: URL
    
    public init(session: URLSession = .shared, customHomeDir: URL? = nil) {
        self.urlSession = session
        if let customHomeDir = customHomeDir {
            self.claudeHomeDir = customHomeDir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.claudeHomeDir = home.appendingPathComponent(".claude", isDirectory: true)
        }
    }
    
    /// Reads API key securely from macOS Keychain.
    public var apiKey: String? {
        KeychainHelper.shared.read(key: Self.keychainKey)
    }
    
    public func setApiKey(_ key: String) {
        KeychainHelper.shared.save(key: Self.keychainKey, value: key)
    }
    
    public func clearApiKey() {
        KeychainHelper.shared.delete(key: Self.keychainKey)
    }
    
    /// Verifies connection either via Anthropic API (if key present) or local Claude Code CLI installation.
    public func checkConnection() async -> Bool {
        if let key = apiKey, !key.isEmpty {
            guard let url = URL(string: "https://api.anthropic.com/v1/models") else { return false }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = 8.0
            
            do {
                let (_, response) = try await urlSession.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    return (200...299).contains(httpResponse.statusCode)
                }
            } catch {
                // fall through to local check
            }
        }
        
        // Check local Claude Code directory
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: claudeHomeDir.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    public func fetchUsage() async throws -> AIUsageSnapshot {
        // First check if API key is provided
        if let key = apiKey, !key.isEmpty {
            return await fetchFromAPI(key: key)
        }
        
        // Otherwise inspect local Claude Code session if installed
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: claudeHomeDir.path, isDirectory: &isDir) && isDir.boolValue {
            // Count local projects or transcripts in ~/.claude
            let projectsDir = claudeHomeDir.appendingPathComponent("projects", isDirectory: true)
            let count = (try? FileManager.default.contentsOfDirectory(atPath: projectsDir.path).count) ?? 0
            
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: true,
                sessionRequests: count > 0 ? count : nil,
                sessionTokens: nil,
                remainingQuotaPercent: nil,
                quotaResetDate: nil,
                modelBreakdown: [:],
                statusMessage: "Claude Code CLI detected (\(count) projects)"
            )
        }
        
        return AIUsageSnapshot(
            providerID: id,
            isAvailable: false,
            sessionRequests: nil,
            sessionTokens: nil,
            remainingQuotaPercent: nil,
            quotaResetDate: nil,
            modelBreakdown: [:],
            statusMessage: "Neither API Key nor local Claude CLI found"
        )
    }
    
    private func fetchFromAPI(key: String) async -> AIUsageSnapshot {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: false,
                sessionRequests: nil,
                sessionTokens: nil,
                remainingQuotaPercent: nil,
                quotaResetDate: nil,
                modelBreakdown: [:],
                statusMessage: "Invalid endpoint"
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return AIUsageSnapshot(
                    providerID: id,
                    isAvailable: false,
                    sessionRequests: nil,
                    sessionTokens: nil,
                    remainingQuotaPercent: nil,
                    quotaResetDate: nil,
                    modelBreakdown: [:],
                    statusMessage: "Invalid HTTP response"
                )
            }
            
            if httpResponse.statusCode == 401 {
                return AIUsageSnapshot(
                    providerID: id,
                    isAvailable: false,
                    sessionRequests: nil,
                    sessionTokens: nil,
                    remainingQuotaPercent: nil,
                    quotaResetDate: nil,
                    modelBreakdown: [:],
                    statusMessage: "Authentication failed: Invalid API key"
                )
            }
            
            // Extract rate limit headers if available
            var remainingTokens: Int? = nil
            if let tokenHeader = httpResponse.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-remaining"),
               let val = Int(tokenHeader) {
                remainingTokens = val
            }
            
            var modelCount = 0
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["data"] as? [[String: Any]] {
                modelCount = list.count
            }
            
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: (200...299).contains(httpResponse.statusCode),
                sessionRequests: nil,
                sessionTokens: remainingTokens,
                remainingQuotaPercent: nil,
                quotaResetDate: nil,
                modelBreakdown: ["models_available": modelCount],
                statusMessage: "Connected (\(modelCount) models available)"
            )
        } catch {
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: false,
                sessionRequests: nil,
                sessionTokens: nil,
                remainingQuotaPercent: nil,
                quotaResetDate: nil,
                modelBreakdown: [:],
                statusMessage: "Offline: \(error.localizedDescription)"
            )
        }
    }
}
