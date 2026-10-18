import Foundation

/// Optional OpenAI Codex Provider Adapter.
/// Implements AI-CODEX-001, AI-CODEX-002, and AI-CODEX-003 with complete error isolation.
public final class CodexProvider: AIProviderAdapter, @unchecked Sendable {
    public let id: AIProviderID = .codex
    public let displayName: String = "OpenAI Codex"
    public let isEnabledByDefault: Bool = false
    
    public static let keychainKey = "codex_api_key"
    private let urlSession: URLSession
    
    public init(session: URLSession = .shared) {
        self.urlSession = session
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
    
    public func checkConnection() async -> Bool {
        guard let key = apiKey, !key.isEmpty else {
            return false
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            // Complete error isolation
            return false
        }
    }
    
    public func fetchUsage() async throws -> AIUsageSnapshot {
        guard let key = apiKey, !key.isEmpty else {
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: false,
                sessionRequests: nil,
                sessionTokens: nil,
                remainingQuotaPercent: nil,
                quotaResetDate: nil,
                modelBreakdown: [:],
                statusMessage: "API Key Not Configured in Keychain"
            )
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: false,
                sessionRequests: nil,
                sessionTokens: nil,
                remainingQuotaPercent: nil,
                quotaResetDate: nil,
                modelBreakdown: [:],
                statusMessage: "Invalid API Endpoint"
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
                    statusMessage: "Connection failed: Invalid HTTP response"
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
            
            guard (200...299).contains(httpResponse.statusCode) else {
                return AIUsageSnapshot(
                    providerID: id,
                    isAvailable: false,
                    sessionRequests: nil,
                    sessionTokens: nil,
                    remainingQuotaPercent: nil,
                    quotaResetDate: nil,
                    modelBreakdown: [:],
                    statusMessage: "API Error (HTTP \(httpResponse.statusCode))"
                )
            }
            
            // Check models count
            var modelCount = 0
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["data"] as? [[String: Any]] {
                modelCount = list.count
            }
            
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: true,
                sessionRequests: nil, // Truthful: not exposed by models endpoint
                sessionTokens: nil,
                remainingQuotaPercent: nil, // OpenAI does not expose remaining quota on standard models endpoint
                quotaResetDate: nil,
                modelBreakdown: ["models_available": modelCount],
                statusMessage: "Connected (\(modelCount) models available)"
            )
        } catch {
            // Fault isolation: strictly catches error and reports status without throwing to caller
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
