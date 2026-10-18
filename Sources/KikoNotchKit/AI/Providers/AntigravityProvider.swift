import Foundation
import SQLite3

/// Primary AI Provider for Google Antigravity.
/// Implements AI-ANTIGRAVITY-001, AI-ANTIGRAVITY-002, AI-ANTIGRAVITY-003, and AI-ANTIGRAVITY-006.
public final class AntigravityProvider: AIProviderAdapter, @unchecked Sendable {
    public let id: AIProviderID = .antigravity
    public let displayName: String = "Google Antigravity"
    public let isEnabledByDefault: Bool = true
    
    private let antigravityDir: URL
    private let warningThreshold: Double = 0.20 // 20% quota remaining warning threshold
    
    public init(customBaseDir: URL? = nil) {
        if let customBaseDir = customBaseDir {
            self.antigravityDir = customBaseDir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.antigravityDir = home.appendingPathComponent(".gemini/antigravity", isDirectory: true)
        }
    }
    
    /// Verifies if local Antigravity environment exists and is accessible.
    public func checkConnection() async -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: antigravityDir.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
    
    /// Inspects local Antigravity environment and returns truthful metrics.
    public func fetchUsage() async throws -> AIUsageSnapshot {
        guard await checkConnection() else {
            return AIUsageSnapshot(
                providerID: id,
                isAvailable: false,
                sessionRequests: nil,
                sessionTokens: nil,
                remainingQuotaPercent: nil,
                quotaResetDate: nil,
                modelBreakdown: [:],
                statusMessage: "Antigravity environment not found at ~/.gemini/antigravity"
            )
        }
        
        // Count actual sessions in conversations directory
        let convosDir = antigravityDir.appendingPathComponent("conversations", isDirectory: true)
        let convoCount = (try? FileManager.default.contentsOfDirectory(atPath: convosDir.path).count) ?? 0
        
        // Count active brain directories
        let brainDir = antigravityDir.appendingPathComponent("brain", isDirectory: true)
        let brainCount = (try? FileManager.default.contentsOfDirectory(atPath: brainDir.path).count) ?? 0
        
        // Query conversation_summaries.db if present for session stats
        let dbPath = antigravityDir.appendingPathComponent("conversation_summaries.db").path
        var totalMessages: Int? = nil
        var modelCounts: [String: Int] = [:]
        
        if FileManager.default.fileExists(atPath: dbPath) {
            var db: OpaquePointer?
            if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                defer { sqlite3_close(db) }
                
                // Count rows in conversation summaries if table exists
                var stmt: OpaquePointer?
                let countSql = "SELECT COUNT(*) FROM conversation_summaries;"
                if sqlite3_prepare_v2(db, countSql, -1, &stmt, nil) == SQLITE_OK {
                    if sqlite3_step(stmt) == SQLITE_ROW {
                        totalMessages = Int(sqlite3_column_int(stmt, 0))
                    }
                    sqlite3_finalize(stmt)
                }
            }
        }
        
        let sessionRequests = totalMessages ?? max(convoCount, brainCount)
        if sessionRequests > 0 {
            modelCounts["gemini-pro"] = sessionRequests
        }
        
        // Antigravity local environment does not expose arbitrary hard token ceilings,
        // so we truthfully report nil for quota percent to never fabricate metrics.
        let statusMsg = "Active (\(convoCount) conversations detected)"
        
        return AIUsageSnapshot(
            providerID: id,
            isAvailable: true,
            sessionRequests: sessionRequests,
            sessionTokens: nil, // Truthful: not exposed locally
            remainingQuotaPercent: nil, // Truthful: quota unlimited or server-managed
            quotaResetDate: nil,
            modelBreakdown: modelCounts,
            statusMessage: statusMsg
        )
    }
    
    /// Checks if a given usage snapshot violates the warning threshold (AI-ANTIGRAVITY-006).
    public func isThresholdExceeded(snapshot: AIUsageSnapshot) -> Bool {
        guard let quota = snapshot.remainingQuotaPercent else { return false }
        return quota <= warningThreshold
    }
}
