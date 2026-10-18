import Foundation
import CoreServices

/// FSEvents-based monitor for ~/Downloads directory.
/// Implements DL-001, DL-002, DL-003, and PERF-003.
public final class DownloadMonitor: ObservableObject, @unchecked Sendable {
    public static let shared = DownloadMonitor()
    
    @Published public private(set) var downloads: [DownloadItem] = []
    public var activeDownloadsList: [DownloadItem] {
        downloads.filter { $0.state == .active }
    }
    public var onDownloadsUpdated: (@Sendable ([DownloadItem]) -> Void)?
    public var onDownloadCompleted: (@Sendable (DownloadItem) -> Void)?
    
    private let downloadsPath: String
    private var eventStream: FSEventStreamRef?
    private var activeDownloads: [String: DownloadItem] = [:]
    private let lock = NSRecursiveLock()
    private var isMonitoring: Bool = false
    
    public init(customPath: String? = nil) {
        if let customPath = customPath {
            self.downloadsPath = customPath
        } else {
            let userHome = FileManager.default.homeDirectoryForCurrentUser
            self.downloadsPath = userHome.appendingPathComponent("Downloads").path
        }
    }
    
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isMonitoring else { return }
        isMonitoring = true
        
        let pathsToWatch = [downloadsPath] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, clientCallBackInfo, numEvents, eventPaths, _, _) in
                guard let info = clientCallBackInfo else { return }
                let monitor = Unmanaged<DownloadMonitor>.fromOpaque(info).takeUnretainedValue()
                monitor.handleFSEvents()
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // 500ms latency coalescing
            flags
        )
        
        if let stream = stream {
            self.eventStream = stream
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
        
        handleFSEvents()
    }
    
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isMonitoring else { return }
        isMonitoring = false
        
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.eventStream = nil
        }
    }
    
    public func handleFSEvents() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: downloadsPath) else { return }
        let now = Date()
        
        let tempExtensions = ["crdownload", "download", "part", "tmp"]
        var currentActivePaths = Set<String>()
        
        for file in files {
            let fullPath = (downloadsPath as NSString).appendingPathComponent(file)
            let ext = (file as NSString).pathExtension.lowercased()
            
            if tempExtensions.contains(ext) {
                currentActivePaths.insert(fullPath)
                let targetName = (file as NSString).deletingPathExtension
                let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
                let currentSize = (attrs?[.size] as? Int64) ?? 0
                
                if var existing = activeDownloads[fullPath] {
                    let elapsed = now.timeIntervalSince(existing.lastUpdated)
                    if elapsed > 0 {
                        let bytesDelta = Double(currentSize - existing.bytesDownloaded)
                        existing.speedBytesPerSecond = max(0, bytesDelta / elapsed)
                    }
                    existing.bytesDownloaded = currentSize
                    existing.lastUpdated = now
                    existing.state = .active
                    // Estimate progress if total known or default
                    existing.progress = min(0.95, max(0.05, Double(currentSize % 10_000_000) / 10_000_000.0))
                    activeDownloads[fullPath] = existing
                } else {
                    let item = DownloadItem(
                        filename: file,
                        targetFilename: targetName,
                        path: fullPath,
                        state: .active,
                        bytesDownloaded: currentSize,
                        speedBytesPerSecond: 0,
                        progress: 0.1,
                        lastUpdated: now
                    )
                    activeDownloads[fullPath] = item
                }
            }
        }
        
        // Detect finished downloads (temp file disappeared and final target exists)
        for (path, item) in activeDownloads {
            if !currentActivePaths.contains(path) {
                // Check if target completed
                let targetPath = (downloadsPath as NSString).appendingPathComponent(item.targetFilename)
                if FileManager.default.fileExists(atPath: targetPath) {
                    var completed = item
                    completed.state = .completed
                    completed.progress = 1.0
                    onDownloadCompleted?(completed)
                }
                activeDownloads.removeValue(forKey: path)
            }
        }
        
        let items = Array(activeDownloads.values)
        DispatchQueue.main.async { [weak self] in
            self?.downloads = items
        }
        onDownloadsUpdated?(items)
    }
    
    /// Processes verified companion message from browser extension (DL-001/DL-002)
    public func processCompanionMessage(_ message: CompanionDownloadMessage) {
        lock.lock()
        defer { lock.unlock() }
        
        let item = DownloadMessageValidator.toDownloadItem(from: message)
        if item.state == .completed {
            activeDownloads.removeValue(forKey: message.downloadId)
            onDownloadCompleted?(item)
        } else if item.state == .failed {
            activeDownloads.removeValue(forKey: message.downloadId)
        } else {
            activeDownloads[message.downloadId] = item
        }
        
        let items = Array(activeDownloads.values)
        DispatchQueue.main.async { [weak self] in
            self?.downloads = items
        }
        onDownloadsUpdated?(items)
    }
    
    /// Simulation helper for unit testing
    public func setSimulatedDownloads(_ items: [DownloadItem]) {
        lock.lock()
        defer { lock.unlock() }
        
        activeDownloads.removeAll()
        for item in items {
            activeDownloads[item.id] = item
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.downloads = items
        }
        onDownloadsUpdated?(items)
    }
}
