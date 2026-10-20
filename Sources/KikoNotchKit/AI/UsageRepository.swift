import Foundation
import SQLite3

/// SQLite3 repository for local AI usage historical snapshots.
/// Satisfies AI-ANTIGRAVITY-005, AI-DASH-002, AI-DASH-004, and ERR-002.
public final class UsageRepository: @unchecked Sendable {
    public static let shared = UsageRepository()

    private var db: OpaquePointer?
    private let dbPath: String
    private let lock = NSLock()

    public init(customPath: String? = nil) {
        if let customPath = customPath {
            self.dbPath = customPath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let kikoDir = appSupport.appendingPathComponent("KikoNotch", isDirectory: true)
            try? FileManager.default.createDirectory(at: kikoDir, withIntermediateDirectories: true)
            self.dbPath = kikoDir.appendingPathComponent("ai_usage.sqlite").path
        }

        initializeDatabase()
    }

    deinit {
        closeDatabase()
    }

    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - Database Initialization & Recovery (ERR-002)

    private func initializeDatabase() {
        lock.lock()
        defer { lock.unlock() }

        closeDatabase()

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            NSLog("[UsageRepository] Failed to open SQLite database at \(dbPath)")
            return
        }

        // Run integrity check
        if !checkIntegrity() {
            NSLog("[UsageRepository] WARNING: SQLite database corrupt. Executing recovery...")
            recoverCorruptDatabase()
            return
        }

        createTables()
    }

    private func checkIntegrity() -> Bool {
        var stmt: OpaquePointer?
        let sql = "PRAGMA integrity_check;"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let result = sqlite3_column_text(stmt, 0) {
                    let str = String(cString: result)
                    sqlite3_finalize(stmt)
                    return str == "ok"
                }
            }
            sqlite3_finalize(stmt)
        }
        return false
    }

    private func recoverCorruptDatabase() {
        closeDatabase()

        let backupPath = dbPath + ".corrupt.\(Int(Date().timeIntervalSince1970))"
        try? FileManager.default.moveItem(atPath: dbPath, toPath: backupPath)
        NSLog("[UsageRepository] Moved corrupt database to \(backupPath). Creating fresh database.")

        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            createTables()
        }
    }

    public var schemaVersion: Int {
        var stmt: OpaquePointer?
        var version = 0
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }
        return version
    }

    private func createTables() {
        let currentVer = schemaVersion
        if currentVer < 1 {
            let sql = """
            CREATE TABLE IF NOT EXISTS usage_snapshots (
                id TEXT PRIMARY KEY,
                provider_id TEXT NOT NULL,
                timestamp REAL NOT NULL,
                is_available INTEGER NOT NULL,
                session_requests INTEGER,
                session_tokens INTEGER,
                remaining_quota_percent REAL,
                quota_reset_date REAL,
                model_breakdown_json TEXT,
                status_message TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_provider_timestamp ON usage_snapshots(provider_id, timestamp);
            PRAGMA user_version = 1;
            """

            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
                if let errMsg = errMsg {
                    NSLog("[UsageRepository] Error creating tables: %s", errMsg)
                    sqlite3_free(errMsg)
                }
            }
        }
    }

    // MARK: - Transaction Support

    @discardableResult
    public func beginTransaction() -> Bool {
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil) == SQLITE_OK
    }

    @discardableResult
    public func commitTransaction() -> Bool {
        sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK
    }

    @discardableResult
    public func rollbackTransaction() -> Bool {
        sqlite3_exec(db, "ROLLBACK;", nil, nil, nil) == SQLITE_OK
    }

    public func performInTransaction<T>(_ block: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        beginTransaction()
        do {
            let result = try block()
            commitTransaction()
            return result
        } catch {
            rollbackTransaction()
            throw error
        }
    }

    // MARK: - CRUD Operations

    public func recordSnapshot(_ snapshot: AIUsageSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        INSERT OR REPLACE INTO usage_snapshots (
            id, provider_id, timestamp, is_available, session_requests,
            session_tokens, remaining_quota_percent, quota_reset_date,
            model_breakdown_json, status_message
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let breakdownData = try? JSONEncoder().encode(snapshot.modelBreakdown)
        let breakdownJson = breakdownData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        sqlite3_bind_text(stmt, 1, (snapshot.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (snapshot.providerID.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, snapshot.timestamp.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 4, snapshot.isAvailable ? 1 : 0)

        if let requests = snapshot.sessionRequests {
            sqlite3_bind_int(stmt, 5, Int32(requests))
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        if let tokens = snapshot.sessionTokens {
            sqlite3_bind_int(stmt, 6, Int32(tokens))
        } else {
            sqlite3_bind_null(stmt, 6)
        }

        if let quota = snapshot.remainingQuotaPercent {
            sqlite3_bind_double(stmt, 7, quota)
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        if let reset = snapshot.quotaResetDate {
            sqlite3_bind_double(stmt, 8, reset.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 8)
        }

        sqlite3_bind_text(stmt, 9, (breakdownJson as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 10, (snapshot.statusMessage as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            NSLog("[UsageRepository] Failed to insert snapshot for \(snapshot.providerID.rawValue)")
        }
    }

    /// Calculates total token usage within a given date range across specified or all providers.
    public func fetchTotalTokens(for provider: AIProviderID? = nil, startDate: Date? = nil, endDate: Date? = nil) -> Int? {
        lock.lock()
        defer { lock.unlock() }

        var conditions: [String] = ["session_tokens IS NOT NULL", "session_tokens > 0"]
        if let provider = provider {
            conditions.append("provider_id = '\(provider.rawValue)'")
        }
        if let startDate = startDate {
            conditions.append("timestamp >= \(startDate.timeIntervalSince1970)")
        }
        if let endDate = endDate {
            conditions.append("timestamp <= \(endDate.timeIntervalSince1970)")
        }

        let sql = "SELECT SUM(session_tokens) FROM usage_snapshots WHERE " + conditions.joined(separator: " AND ") + ";"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            if sqlite3_column_type(stmt, 0) != SQLITE_NULL {
                return Int(sqlite3_column_int64(stmt, 0))
            }
        }
        return nil
    }

    public func fetchSnapshots(
        for provider: AIProviderID? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        model: String? = nil,
        limit: Int = 100
    ) -> [AIUsageSnapshot] {
        lock.lock()
        defer { lock.unlock() }

        var conditions: [String] = []
        if let provider = provider {
            conditions.append("provider_id = '\(provider.rawValue)'")
        }
        if let startDate = startDate {
            conditions.append("timestamp >= \(startDate.timeIntervalSince1970)")
        }
        if let endDate = endDate {
            conditions.append("timestamp <= \(endDate.timeIntervalSince1970)")
        }
        if let model = model {
            conditions.append("model_breakdown_json LIKE '%\"\(model)\"%'")
        }

        var sql = "SELECT id, provider_id, timestamp, is_available, session_requests, session_tokens, remaining_quota_percent, quota_reset_date, model_breakdown_json, status_message FROM usage_snapshots"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT \(limit);"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [AIUsageSnapshot] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let provRaw = sqlite3_column_text(stmt, 1),
                  let providerID = AIProviderID(rawValue: String(cString: provRaw)) else {
                continue
            }

            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            let isAvailable = sqlite3_column_int(stmt, 3) == 1

            let requests: Int? = sqlite3_column_type(stmt, 4) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 4)) : nil
            let tokens: Int? = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 5)) : nil
            let quota: Double? = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? sqlite3_column_double(stmt, 6) : nil
            let resetDate: Date? = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7)) : nil

            var breakdown: [String: Int] = [:]
            if let breakdownRaw = sqlite3_column_text(stmt, 8),
               let data = String(cString: breakdownRaw).data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
                breakdown = decoded
            }

            let statusMessage = sqlite3_column_text(stmt, 9).flatMap { String(cString: $0) } ?? ""

            let snapshot = AIUsageSnapshot(
                providerID: providerID,
                timestamp: timestamp,
                isAvailable: isAvailable,
                sessionRequests: requests,
                sessionTokens: tokens,
                remainingQuotaPercent: quota,
                quotaResetDate: resetDate,
                modelBreakdown: breakdown,
                statusMessage: statusMessage
            )
            results.append(snapshot)
        }
        return results
    }

    public func deleteSnapshots(for provider: AIProviderID? = nil, before date: Date? = nil) {
        lock.lock()
        defer { lock.unlock() }

        var conditions: [String] = []
        if let provider = provider {
            conditions.append("provider_id = '\(provider.rawValue)'")
        }
        if let date = date {
            conditions.append("timestamp < \(date.timeIntervalSince1970)")
        }

        var sql = "DELETE FROM usage_snapshots"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += ";"
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    /// Test helper for simulating database corruption and verifying auto-recovery (ERR-002)
    public func simulateCorruption() {
        lock.lock()
        defer { lock.unlock() }
        closeDatabase()
        try? "corrupt_data_garbage_bytes".write(toFile: dbPath, atomically: true, encoding: .utf8)
    }

    public func reloadDatabase() {
        initializeDatabase()
    }

    /// Historical daily aggregated request counts for chart rendering (AI-DASH-002).
    public func fetchDailyUsage(days: Int = 7) -> [(day: String, requests: Int, tokens: Int)] {
        lock.lock()
        defer { lock.unlock() }

        let secondsPerDay: Double = 86400
        let startTime = Date().timeIntervalSince1970 - (Double(days) * secondsPerDay)

        let sql = """
        SELECT strftime('%m-%d', timestamp, 'unixepoch') AS day,
               MAX(session_requests) - MIN(session_requests) AS reqs,
               MAX(session_tokens) - MIN(session_tokens) AS toks
        FROM usage_snapshots
        WHERE timestamp >= \(startTime) AND session_requests IS NOT NULL
        GROUP BY day
        ORDER BY timestamp ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var rows: [(day: String, requests: Int, tokens: Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let day = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? ""
            let reqs = max(0, Int(sqlite3_column_int(stmt, 1)))
            let toks = max(0, Int(sqlite3_column_int(stmt, 2)))
            rows.append((day: day, requests: reqs, tokens: toks))
        }
        return rows
    }

    // MARK: - Export and Purge (AI-DASH-004)

    public func clearAllHistory() {
        lock.lock()
        defer { lock.unlock() }

        let sql = "DELETE FROM usage_snapshots;"
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    public func exportJSON() -> String? {
        let snapshots = fetchSnapshots(limit: 5000)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshots) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func exportCSV() -> String {
        let snapshots = fetchSnapshots(limit: 5000)
        var csv = "id,provider_id,timestamp,is_available,session_requests,session_tokens,remaining_quota_percent,status_message\n"
        for s in snapshots {
            let reqStr = s.sessionRequests.map { String($0) } ?? ""
            let tokStr = s.sessionTokens.map { String($0) } ?? ""
            let quotaStr = s.remainingQuotaPercent.map { String(format: "%.1f", $0) } ?? ""
            let cleanMsg = s.statusMessage.replacingOccurrences(of: ",", with: ";")
            csv += "\(s.id),\(s.providerID.rawValue),\(s.timestamp.timeIntervalSince1970),\(s.isAvailable ? 1 : 0),\(reqStr),\(tokStr),\(quotaStr),\"\(cleanMsg)\"\n"
        }
        return csv
    }
}
