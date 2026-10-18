import Foundation
import Metal

// MARK: - Metric Availability Status

public enum MetricStatus: Equatable, Sendable {
    case available
    case loading
    case unavailable(reason: String)
    case error(message: String)
    
    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
    
    public var description: String {
        switch self {
        case .available:
            return "Available"
        case .loading:
            return "Loading..."
        case .unavailable(let reason):
            return "Unavailable (\(reason))"
        case .error(let msg):
            return "Error (\(msg))"
        }
    }
    
    public var diagnosticReason: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .error(let msg):
            return msg
        default:
            return nil
        }
    }
}

// MARK: - Generic Metric Value

public struct MetricValue<T: Sendable>: Sendable, Equatable where T: Equatable {
    public let value: T?
    public let unit: String
    public let status: MetricStatus
    public let timestamp: Date
    
    public init(value: T?, unit: String = "", status: MetricStatus, timestamp: Date = Date()) {
        self.value = value
        self.unit = unit
        self.status = status
        self.timestamp = timestamp
    }
    
    public static func available(_ value: T, unit: String = "") -> MetricValue<T> {
        MetricValue(value: value, unit: unit, status: .available)
    }
    
    public static func loading(unit: String = "") -> MetricValue<T> {
        MetricValue(value: nil, unit: unit, status: .loading)
    }
    
    public static func unavailable(reason: String = "", unit: String = "") -> MetricValue<T> {
        MetricValue(value: nil, unit: unit, status: .unavailable(reason: reason))
    }
    
    public static func error(message: String = "", unit: String = "") -> MetricValue<T> {
        MetricValue(value: nil, unit: unit, status: .error(message: message))
    }
}

// MARK: - CPU Models

public struct CoreLoad: Identifiable, Sendable, Equatable {
    public let id: Int
    public let userPercentage: Double
    public let systemPercentage: Double
    public let idlePercentage: Double
    public let totalUsagePercentage: Double
    
    public init(id: Int, userPercentage: Double, systemPercentage: Double, idlePercentage: Double) {
        self.id = id
        self.userPercentage = userPercentage
        self.systemPercentage = systemPercentage
        self.idlePercentage = idlePercentage
        self.totalUsagePercentage = max(0.0, min(100.0, userPercentage + systemPercentage))
    }
}

public struct CPUMetrics: Sendable, Equatable {
    public let status: MetricStatus
    public let totalUsagePercentage: Double
    public let userPercentage: Double
    public let systemPercentage: Double
    public let idlePercentage: Double
    public let physicalCores: Int
    public let logicalCores: Int
    public let coreLoads: [CoreLoad]
    public let timestamp: Date
    
    public init(
        status: MetricStatus = .available,
        totalUsagePercentage: Double = 0.0,
        userPercentage: Double = 0.0,
        systemPercentage: Double = 0.0,
        idlePercentage: Double = 100.0,
        physicalCores: Int = 1,
        logicalCores: Int = 1,
        coreLoads: [CoreLoad] = [],
        timestamp: Date = Date()
    ) {
        self.status = status
        self.totalUsagePercentage = max(0.0, min(100.0, totalUsagePercentage))
        self.userPercentage = userPercentage
        self.systemPercentage = systemPercentage
        self.idlePercentage = idlePercentage
        self.physicalCores = physicalCores
        self.logicalCores = logicalCores
        self.coreLoads = coreLoads
        self.timestamp = timestamp
    }
    
    public static var initial: CPUMetrics {
        CPUMetrics(status: .loading)
    }
}

public typealias CPUMetricsSnapshot = CPUMetrics

// MARK: - Memory Models

public enum MemoryPressureLevel: String, Sendable, Equatable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"
}

public struct MemoryMetrics: Sendable, Equatable {
    public let status: MetricStatus
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let availableBytes: UInt64
    public let appMemoryBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let cachedFilesBytes: UInt64
    public let swapTotalBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressureLevel: MemoryPressureLevel
    public let timestamp: Date
    
    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(100.0, (Double(usedBytes) / Double(totalBytes)) * 100.0)
    }
    
    public init(
        status: MetricStatus = .available,
        totalBytes: UInt64 = 0,
        usedBytes: UInt64 = 0,
        availableBytes: UInt64 = 0,
        appMemoryBytes: UInt64 = 0,
        wiredBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        cachedFilesBytes: UInt64 = 0,
        swapTotalBytes: UInt64 = 0,
        swapUsedBytes: UInt64 = 0,
        pressureLevel: MemoryPressureLevel = .normal,
        timestamp: Date = Date()
    ) {
        self.status = status
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.availableBytes = availableBytes
        self.appMemoryBytes = appMemoryBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.cachedFilesBytes = cachedFilesBytes
        self.swapTotalBytes = swapTotalBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressureLevel = pressureLevel
        self.timestamp = timestamp
    }
    
    public static var initial: MemoryMetrics {
        MemoryMetrics(status: .loading)
    }
}

public typealias MemoryMetricsSnapshot = MemoryMetrics

// MARK: - GPU Models

public struct GPUMetrics: Sendable, Equatable {
    public let name: String
    public let isAppleSilicon: Bool
    public let allocatedBytes: UInt64?
    public let recommendedMaxWorkingSetBytes: UInt64?
    /// GPU execution engine utilization percentage.
    /// Strictly reported as unavailable if not provided by public Darwin/Metal APIs. Never fabricated.
    public let utilization: MetricValue<Double>
    public let timestamp: Date
    
    public init(
        name: String,
        isAppleSilicon: Bool,
        allocatedBytes: UInt64? = nil,
        recommendedMaxWorkingSetBytes: UInt64? = nil,
        utilization: MetricValue<Double>,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.isAppleSilicon = isAppleSilicon
        self.allocatedBytes = allocatedBytes
        self.recommendedMaxWorkingSetBytes = recommendedMaxWorkingSetBytes
        self.utilization = utilization
        self.timestamp = timestamp
    }
    
    public static var unavailable: GPUMetrics {
        GPUMetrics(
            name: "Apple Silicon GPU",
            isAppleSilicon: true,
            allocatedBytes: nil,
            recommendedMaxWorkingSetBytes: nil,
            utilization: .unavailable(reason: "System-wide GPU execution engine utilization is restricted on macOS without private Apple Silicon entitlements")
        )
    }
}

public typealias GPUMetricsSnapshot = GPUMetrics

// MARK: - Storage Models

public struct VolumeMetrics: Identifiable, Sendable, Equatable {
    public var id: String { mountPoint }
    public let name: String
    public let mountPoint: String
    public let totalBytes: UInt64
    public let freeBytes: UInt64
    public let isRemovable: Bool
    public let isPrimary: Bool
    
    public var usedBytes: UInt64 {
        totalBytes >= freeBytes ? totalBytes - freeBytes : 0
    }
    
    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(100.0, (Double(usedBytes) / Double(totalBytes)) * 100.0)
    }
    
    public init(name: String, mountPoint: String, totalBytes: UInt64, freeBytes: UInt64, isRemovable: Bool, isPrimary: Bool) {
        self.name = name
        self.mountPoint = mountPoint
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.isRemovable = isRemovable
        self.isPrimary = isPrimary
    }
}

public struct StorageMetrics: Sendable, Equatable {
    public let status: MetricStatus
    public let primaryVolume: VolumeMetrics?
    public let allVolumes: [VolumeMetrics]
    public let timestamp: Date
    
    public init(status: MetricStatus = .available, primaryVolume: VolumeMetrics? = nil, allVolumes: [VolumeMetrics] = [], timestamp: Date = Date()) {
        self.status = status
        self.primaryVolume = primaryVolume
        self.allVolumes = allVolumes
        self.timestamp = timestamp
    }
    
    public static var initial: StorageMetrics {
        StorageMetrics(status: .loading)
    }
}

public typealias StorageMetricsSnapshot = StorageMetrics

// MARK: - Network Models

public struct NetworkMetrics: Sendable, Equatable {
    public let status: MetricStatus
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double
    public let totalBytesReceived: UInt64
    public let totalBytesSent: UInt64
    public let activeInterfaceName: String
    public let timestamp: Date
    
    public init(
        status: MetricStatus = .available,
        downloadBytesPerSecond: Double = 0.0,
        uploadBytesPerSecond: Double = 0.0,
        totalBytesReceived: UInt64 = 0,
        totalBytesSent: UInt64 = 0,
        activeInterfaceName: String = "",
        timestamp: Date = Date()
    ) {
        self.status = status
        self.downloadBytesPerSecond = max(0.0, downloadBytesPerSecond)
        self.uploadBytesPerSecond = max(0.0, uploadBytesPerSecond)
        self.totalBytesReceived = totalBytesReceived
        self.totalBytesSent = totalBytesSent
        self.activeInterfaceName = activeInterfaceName
        self.timestamp = timestamp
    }
    
    public static var initial: NetworkMetrics {
        NetworkMetrics(status: .loading)
    }
}

// MARK: - System Info Models

public enum ThermalStateLevel: String, Sendable, Equatable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    case unknown = "Unknown"
}

public struct SystemInfoMetrics: Sendable, Equatable {
    public let chipName: String
    public let modelIdentifier: String
    public let osVersionString: String
    public let uptimeSeconds: TimeInterval
    public let thermalState: ThermalStateLevel
    public let timestamp: Date
    
    public var formattedUptime: String {
        let total = Int(uptimeSeconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    public init(
        chipName: String = "Apple Silicon",
        modelIdentifier: String = "Mac",
        osVersionString: String = "",
        uptimeSeconds: TimeInterval = 0,
        thermalState: ThermalStateLevel = .nominal,
        timestamp: Date = Date()
    ) {
        self.chipName = chipName
        self.modelIdentifier = modelIdentifier
        self.osVersionString = osVersionString
        self.uptimeSeconds = uptimeSeconds
        self.thermalState = thermalState
        self.timestamp = timestamp
    }
    
    public static var initial: SystemInfoMetrics {
        SystemInfoMetrics()
    }
}

public typealias SystemInfoMetricsSnapshot = SystemInfoMetrics

// MARK: - Combined Snapshot

public struct SystemMetricsSnapshot: Sendable, Equatable {
    public let cpu: CPUMetrics
    public let memory: MemoryMetrics
    public let gpu: GPUMetrics
    public let storage: StorageMetrics
    public let network: NetworkMetrics
    public let systemInfo: SystemInfoMetrics
    public let timestamp: Date
    
    public init(
        cpu: CPUMetrics = .initial,
        memory: MemoryMetrics = .initial,
        gpu: GPUMetrics = .unavailable,
        storage: StorageMetrics = .initial,
        network: NetworkMetrics = .initial,
        systemInfo: SystemInfoMetrics = .initial,
        timestamp: Date = Date()
    ) {
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.storage = storage
        self.network = network
        self.systemInfo = systemInfo
        self.timestamp = timestamp
    }
    
    public static var initial: SystemMetricsSnapshot {
        SystemMetricsSnapshot()
    }
}

// MARK: - Sampling Interval

public enum SamplingInterval: Double, CaseIterable, Identifiable, Sendable {
    case oneSecond = 1.0
    case twoSeconds = 2.0
    case fiveSeconds = 5.0
    case tenSeconds = 10.0
    
    public var id: Double { rawValue }
    
    public var displayName: String {
        switch self {
        case .oneSecond: return "1s (High)"
        case .twoSeconds: return "2s (Default)"
        case .fiveSeconds: return "5s (Balanced)"
        case .tenSeconds: return "10s (Low Power)"
        }
    }
}

// MARK: - Bounded Ring Buffer

/// Thread-safe bounded FIFO buffer holding up to `capacity` samples for history sparklines.
public struct RingBuffer<Element: Sendable>: Sendable {
    private var elements: [Element]
    public let capacity: Int
    
    public init(capacity: Int = 60) {
        self.capacity = max(1, capacity)
        self.elements = []
        self.elements.reserveCapacity(self.capacity)
    }
    
    public mutating func append(_ element: Element) {
        elements.append(element)
        if elements.count > capacity {
            elements.removeFirst(elements.count - capacity)
        }
    }
    
    public var values: [Element] {
        elements
    }
    
    public var count: Int {
        elements.count
    }
    
    public var isEmpty: Bool {
        elements.isEmpty
    }
    
    public mutating func removeAll() {
        elements.removeAll(keepingCapacity: true)
    }
    
    public mutating func clear() {
        removeAll()
    }
}
