import Foundation

/// Browser Companion Extension Integration Contract
/// Defines the messaging protocol, validation, and schema for Safari, Chrome, and Firefox companion extensions.
/// Implements DL-001, DL-002, and DL-003 companion specifications.

public enum CompanionMessageType: String, Codable, Sendable {
    case downloadStarted = "download_started"
    case downloadProgress = "download_progress"
    case downloadPaused = "download_paused"
    case downloadResumed = "download_resumed"
    case downloadCompleted = "download_completed"
    case downloadInterrupted = "download_interrupted"
    case ping = "ping"
    case pong = "pong"
}

public struct CompanionDownloadMessage: Codable, Sendable, Equatable {
    public let type: CompanionMessageType
    public let downloadId: String
    public let filename: String
    public let url: String?
    public let mimeType: String?
    public let totalBytes: Int64?
    public let receivedBytes: Int64
    public let state: String? // "in_progress", "interrupted", "complete"
    public let error: String?
    public let timestamp: Date
    
    public init(
        type: CompanionMessageType,
        downloadId: String,
        filename: String,
        url: String? = nil,
        mimeType: String? = nil,
        totalBytes: Int64? = nil,
        receivedBytes: Int64 = 0,
        state: String? = nil,
        error: String? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.downloadId = downloadId
        self.filename = filename
        self.url = url
        self.mimeType = mimeType
        self.totalBytes = totalBytes
        self.receivedBytes = receivedBytes
        self.state = state
        self.error = error
        self.timestamp = timestamp
    }
}

public enum MessageValidationError: Error, LocalizedError, Sendable {
    case invalidJSON
    case missingRequiredFields(String)
    case invalidByteCount
    case unsupportedMessageType
    
    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Payload could not be parsed as valid JSON."
        case .missingRequiredFields(let field):
            return "Message missing mandatory field: \(field)"
        case .invalidByteCount:
            return "Received bytes exceeds total bytes or is negative."
        case .unsupportedMessageType:
            return "Message type is not supported."
        }
    }
}

/// Validates and parses incoming browser companion messages.
public struct DownloadMessageValidator: Sendable {
    public static func validate(data: Data) throws -> CompanionDownloadMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let message = try? decoder.decode(CompanionDownloadMessage.self, from: data) else {
            throw MessageValidationError.invalidJSON
        }
        
        guard !message.downloadId.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw MessageValidationError.missingRequiredFields("downloadId")
        }
        
        guard !message.filename.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw MessageValidationError.missingRequiredFields("filename")
        }
        
        if message.receivedBytes < 0 {
            throw MessageValidationError.invalidByteCount
        }
        
        if let total = message.totalBytes, total > 0, message.receivedBytes > total {
            throw MessageValidationError.invalidByteCount
        }
        
        return message
    }
    
    /// Converts a valid companion message to an internal `DownloadItem`.
    public static func toDownloadItem(from message: CompanionDownloadMessage) -> DownloadItem {
        let state: DownloadState
        switch message.type {
        case .downloadStarted, .downloadProgress, .downloadResumed:
            state = .active
        case .downloadPaused:
            state = .paused
        case .downloadCompleted:
            state = .completed
        case .downloadInterrupted:
            state = .failed
        case .ping, .pong:
            state = .active
        }
        
        let progress: Double
        if let total = message.totalBytes, total > 0 {
            progress = min(1.0, max(0.0, Double(message.receivedBytes) / Double(total)))
        } else if state == .completed {
            progress = 1.0
        } else {
            progress = 0.0
        }
        
        return DownloadItem(
            id: message.downloadId,
            filename: message.filename,
            targetFilename: message.filename,
            path: "",
            state: state,
            bytesDownloaded: message.receivedBytes,
            estimatedTotalBytes: message.totalBytes,
            speedBytesPerSecond: 0,
            progress: progress,
            lastUpdated: message.timestamp
        )
    }
}
