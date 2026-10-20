import Foundation
import SQLite3

/// Primary AI Provider Adapter for Google Antigravity.
/// Implements AI-ANTIGRAVITY-001 through AI-ANTIGRAVITY-006 with truthful metrics,
/// verified transcript token extraction, CLI discovery, and structured diagnostics.
public final class AntigravityProvider: AIProviderAdapter, @unchecked Sendable {
    public let id: AIProviderID = .antigravity
    public let displayName: String = "Google Antigravity"
    public let isEnabledByDefault: Bool = true

    private let antigravityDir: URL
    private let warningThreshold: Double = 0.20

    public init(customBaseDir: URL? = nil) {
        if let customBaseDir = customBaseDir {
            self.antigravityDir = customBaseDir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.antigravityDir = home.appendingPathComponent(".gemini/antigravity", isDirectory: true)
        }
    }

    // MARK: - Executable Discovery

    /// Locates the `agy` CLI binary if installed on the system
    public var agyExecutableURL: URL? {
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/agy"),
            antigravityDir.appendingPathComponent("bin/agy"),
            URL(fileURLWithPath: "/opt/homebrew/bin/agy"),
            URL(fileURLWithPath: "/usr/local/bin/agy")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Probes the `agy` CLI with a short timeout to verify installation and get version string
    public func probeAgyCLI(timeout: TimeInterval = 2.5) -> (installed: Bool, version: String, exitCode: Int32) {
        guard let exe = agyExecutableURL else {
            return (false, "Not Installed", -1)
        }

        let process = Process()
        process.executableURL = exe
        process.arguments = ["--version"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()

            // Wait with timeout
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                usleep(50_000) // 50ms
            }
            if process.isRunning {
                process.terminate()
                return (true, "Timed Out", -2)
            }

            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let rawStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let version = rawStr.isEmpty ? "Unknown" : rawStr
            return (true, version, process.terminationStatus)
        } catch {
            return (true, "Error: \(error.localizedDescription)", -3)
        }
    }

    // MARK: - Connection Check

    /// Verifies if local Antigravity environment exists and is accessible.
    public func checkConnection() async -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: antigravityDir.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    // MARK: - Usage & Token Extraction Pipeline

    public struct ScannedTokenMetrics: Sendable {
        public let tokens5h: Int
        public let tokens7d: Int
        public let tokens30d: Int
        public let tokensPreviousMonth: Int
        public let scannedFileCount: Int
        public let totalStepsCount: Int
    }

    /// Scans verified local conversation transcripts in ~/.gemini/antigravity/brain
    public func scanTranscriptTokens(now: Date = Date()) -> ScannedTokenMetrics {
        let brainDir = antigravityDir.appendingPathComponent("brain", isDirectory: true)
        let fm = FileManager.default

        guard let subdirs = try? fm.contentsOfDirectory(atPath: brainDir.path) else {
            return ScannedTokenMetrics(tokens5h: 0, tokens7d: 0, tokens30d: 0, tokensPreviousMonth: 0, scannedFileCount: 0, totalStepsCount: 0)
        }

        let h5 = now.addingTimeInterval(-5 * 3600)
        let d7 = now.addingTimeInterval(-7 * 86400)
        let d30 = now.addingTimeInterval(-30 * 86400)
        let maxAgeThreshold = now.addingTimeInterval(-35 * 86400)

        // Previous calendar month boundaries
        let cal = Calendar.current
        let currentMonthComponents = cal.dateComponents([.year, .month], from: now)
        let currentMonthStart = cal.date(from: currentMonthComponents) ?? now
        let prevMonthStart = cal.date(byAdding: .month, value: -1, to: currentMonthStart) ?? now
        let prevMonthEnd = cal.date(byAdding: .second, value: -1, to: currentMonthStart) ?? now

        var tok5h = 0
        var tok7d = 0
        var tok30d = 0
        var tokPrev = 0
        var filesScanned = 0
        var totalSteps = 0

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackISO = ISO8601DateFormatter()
        fallbackISO.formatOptions = [.withInternetDateTime]

        for subdir in subdirs {
            let transcriptPath = brainDir.appendingPathComponent(subdir).appendingPathComponent(".system_generated/logs/transcript.jsonl").path

            guard let attrs = try? fm.attributesOfItem(atPath: transcriptPath),
                  let mtime = attrs[.modificationDate] as? Date else {
                continue
            }

            // Skip files not modified in the last 35 days
            if mtime < maxAgeThreshold {
                continue
            }

            filesScanned += 1

            guard let content = try? String(contentsOfFile: transcriptPath, encoding: .utf8) else {
                continue
            }

            content.enumerateLines { line, _ in
                // Fast-check before expensive JSON parsing
                guard line.contains("\"input_tokens\"") else { return }
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                guard let dateStr = obj["created_at"] as? String else { return }
                let stepDate = isoFormatter.date(from: dateStr) ?? fallbackISO.date(from: dateStr)
                guard let stepDate = stepDate else { return }

                let inp = (obj["input_tokens"] as? Int) ?? 0
                let out = (obj["output_tokens"] as? Int) ?? 0
                let tokens = inp + out
                guard tokens > 0 else { return }

                totalSteps += 1

                if stepDate >= h5 {
                    tok5h += tokens
                }
                if stepDate >= d7 {
                    tok7d += tokens
                }
                if stepDate >= d30 {
                    tok30d += tokens
                }
                if stepDate >= prevMonthStart && stepDate <= prevMonthEnd {
                    tokPrev += tokens
                }
            }
        }

        return ScannedTokenMetrics(
            tokens5h: tok5h,
            tokens7d: tok7d,
            tokens30d: tok30d,
            tokensPreviousMonth: tokPrev,
            scannedFileCount: filesScanned,
            totalStepsCount: totalSteps
        )
    }

    // MARK: - Database Metadata Helper

    private func queryConversationCount() -> Int {
        let dbPath = antigravityDir.appendingPathComponent("conversation_summaries.db").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            let convosDir = antigravityDir.appendingPathComponent("conversations", isDirectory: true)
            return (try? FileManager.default.contentsOfDirectory(atPath: convosDir.path).count) ?? 0
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM conversation_summaries;"
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }
        return count
    }

    // MARK: - AIProviderAdapter Implementation

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

        let convoCount = queryConversationCount()
        let metrics = await Task.detached(priority: .userInitiated) {
            self.scanTranscriptTokens()
        }.value

        var modelCounts: [String: Int] = [:]
        if convoCount > 0 {
            modelCounts["gemini-pro"] = convoCount
        }

        let statusMsg = "Active (\(convoCount) conversations · \(Self.formatTokens(metrics.tokens5h)) tokens 5h)"

        return AIUsageSnapshot(
            providerID: id,
            isAvailable: true,
            sessionRequests: convoCount,
            sessionTokens: metrics.tokens5h,
            remainingQuotaPercent: nil, // Truthful: Antigravity does not expose a hard ceiling percentage
            quotaResetDate: nil,
            modelBreakdown: modelCounts,
            statusMessage: statusMsg
        )
    }

    public func fetchQuotaSnapshot() async throws -> AIProviderQuotaSnapshot {
        let refreshStart = Date()
        guard await checkConnection() else {
            let diag = AIProviderDiagnostics(
                providerID: id,
                dataSource: antigravityDir.path,
                lastRefreshStart: refreshStart,
                lastRefreshCompletion: Date(),
                isRefreshing: false,
                processExitStatus: -1,
                parsingOutcome: "Antigravity directory not found",
                errorCategory: "NotFound",
                statusMessage: "Environment not found at \(antigravityDir.path)"
            )
            return AIProviderQuotaSnapshot.empty(
                providerID: id,
                displayName: displayName,
                message: "Antigravity not found at \(antigravityDir.path)",
                diagnostics: diag
            )
        }

        // Execute background scan without blocking main thread
        let metrics = await Task.detached(priority: .userInitiated) {
            self.scanTranscriptTokens()
        }.value

        let convoCount = queryConversationCount()
        let cliProbe = probeAgyCLI()

        let limit5h = SettingsManager.shared.aiQuota5hLimit
        let limitWeekly = SettingsManager.shared.aiQuotaWeeklyLimit
        let limitMonthly = SettingsManager.shared.aiQuotaMonthlyLimit

        let remaining5h = max(0, Int(limit5h) - metrics.tokens5h)
        let remainingWeekly = max(0, Int(limitWeekly) - metrics.tokens7d)
        let remainingMonthly = max(0, Int(limitMonthly) - metrics.tokens30d)

        // Formulate 3 verified circular metrics with quota limits and remaining tokens
        let metric5h = AIQuotaMetric.tokenUsage(
            window: .fiveHour,
            windowLabel: "5-HOUR",
            usedTokens: Double(metrics.tokens5h),
            totalLimit: limit5h,
            formattedTokens: "\(Self.formatTokens(remaining5h)) left",
            statusMessage: "\(Self.formatTokens(remaining5h)) tokens left (\(Self.formatTokens(metrics.tokens5h)) consumed of \(Self.formatTokens(Int(limit5h))))"
        )

        let metricWeekly = AIQuotaMetric.tokenUsage(
            window: .weekly,
            windowLabel: "WEEKLY",
            usedTokens: Double(metrics.tokens7d),
            totalLimit: limitWeekly,
            formattedTokens: "\(Self.formatTokens(remainingWeekly)) left",
            statusMessage: "\(Self.formatTokens(remainingWeekly)) tokens left (\(Self.formatTokens(metrics.tokens7d)) consumed of \(Self.formatTokens(Int(limitWeekly))))"
        )

        let metricMonthly = AIQuotaMetric.tokenUsage(
            window: .monthly,
            windowLabel: "MONTHLY",
            usedTokens: Double(metrics.tokens30d),
            totalLimit: limitMonthly,
            formattedTokens: "\(Self.formatTokens(remainingMonthly)) left",
            statusMessage: "\(Self.formatTokens(remainingMonthly)) tokens left (\(Self.formatTokens(metrics.tokens30d)) consumed of \(Self.formatTokens(Int(limitMonthly))))"
        )

        let refreshEnd = Date()
        let cliInfo = cliProbe.installed ? "CLI \(cliProbe.version)" : "Local Transcripts"
        let statusMessage = "\(cliInfo) · \(convoCount) convos · \(Self.formatTokens(metrics.tokens5h)) tokens (5h)"

        let diag = AIProviderDiagnostics(
            providerID: id,
            dataSource: "\(antigravityDir.path)/brain",
            lastRefreshStart: refreshStart,
            lastRefreshCompletion: refreshEnd,
            lastSuccessfulRefresh: refreshEnd,
            isRefreshing: false,
            processExitStatus: cliProbe.exitCode,
            parsingOutcome: "Scanned \(metrics.scannedFileCount) transcripts (\(metrics.totalStepsCount) steps)",
            errorCategory: nil,
            statusMessage: statusMessage
        )

        return AIProviderQuotaSnapshot(
            providerID: id,
            displayName: displayName,
            timestamp: refreshEnd,
            isAvailable: true,
            statusMessage: statusMessage,
            quotas: [metric5h, metricWeekly, metricMonthly],
            sessionTokens: metrics.tokens5h,
            sessionRequests: convoCount,
            previousMonthTokens: metrics.tokensPreviousMonth,
            diagnostics: diag
        )
    }

    public func isThresholdExceeded(snapshot: AIUsageSnapshot) -> Bool {
        guard let quota = snapshot.remainingQuotaPercent else { return false }
        return quota <= warningThreshold
    }

    // MARK: - Formatting Helper

    public static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}
