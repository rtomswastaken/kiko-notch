import Foundation

public enum DownloadState: String, Sendable, Codable {
    case active
    case paused
    case completed
    case failed
}

public struct DownloadItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let filename: String
    public let targetFilename: String
    public let path: String
    public var state: DownloadState
    public var bytesDownloaded: Int64
    public var estimatedTotalBytes: Int64?
    public var speedBytesPerSecond: Double
    public var progress: Double // 0.0 to 1.0
    public var lastUpdated: Date
    
    public init(
        id: String = UUID().uuidString,
        filename: String,
        targetFilename: String,
        path: String,
        state: DownloadState = .active,
        bytesDownloaded: Int64 = 0,
        estimatedTotalBytes: Int64? = nil,
        speedBytesPerSecond: Double = 0,
        progress: Double = 0,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.targetFilename = targetFilename
        self.path = path
        self.state = state
        self.bytesDownloaded = bytesDownloaded
        self.estimatedTotalBytes = estimatedTotalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.progress = progress
        self.lastUpdated = lastUpdated
    }
    
    public var formattedSpeed: String {
        let kb = speedBytesPerSecond / 1024.0
        if kb < 1000 {
            return String(format: "%.0f KB/s", kb)
        } else {
            let mb = kb / 1024.0
            return String(format: "%.1f MB/s", mb)
        }
    }
}
