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

    public var diagnosticReason: String? {
        status.diagnosticReason
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
    public let efficiencyClusterPercentage: Double?
    public let performanceClusterPercentage: Double?
    public let powerWatts: Double?
    public let temperature: MetricValue<Double>
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
        efficiencyClusterPercentage: Double? = nil,
        performanceClusterPercentage: Double? = nil,
        powerWatts: Double? = nil,
        temperature: MetricValue<Double> = .unavailable(reason: "Temperature sensors require private SMC or kernel interfaces on macOS", unit: "°C"),
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
        self.efficiencyClusterPercentage = efficiencyClusterPercentage
        self.performanceClusterPercentage = performanceClusterPercentage
        self.powerWatts = powerWatts
        self.temperature = temperature
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
    public let inUseBytes: UInt64?
    public let recommendedMaxWorkingSetBytes: UInt64?
    /// GPU execution engine utilization percentage.
    public let utilization: MetricValue<Double>
    public let rendererUtilization: Double?
    public let tilerUtilization: Double?
    public let temperature: MetricValue<Double>
    public let powerWatts: Double?
    public let timestamp: Date

    public init(
        name: String,
        isAppleSilicon: Bool,
        allocatedBytes: UInt64? = nil,
        inUseBytes: UInt64? = nil,
        recommendedMaxWorkingSetBytes: UInt64? = nil,
        utilization: MetricValue<Double>,
        rendererUtilization: Double? = nil,
        tilerUtilization: Double? = nil,
        temperature: MetricValue<Double> = .unavailable(reason: "GPU temperature sensors require private Apple Silicon interfaces on macOS", unit: "°C"),
        powerWatts: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.isAppleSilicon = isAppleSilicon
        self.allocatedBytes = allocatedBytes
        self.inUseBytes = inUseBytes
        self.recommendedMaxWorkingSetBytes = recommendedMaxWorkingSetBytes
        self.utilization = utilization
        self.rendererUtilization = rendererUtilization
        self.tilerUtilization = tilerUtilization
        self.temperature = temperature
        self.powerWatts = powerWatts
        self.timestamp = timestamp
    }

    public static var unavailable: GPUMetrics {
        GPUMetrics(
            name: "Apple Silicon GPU",
            isAppleSilicon: true,
            allocatedBytes: nil,
            inUseBytes: nil,
            recommendedMaxWorkingSetBytes: nil,
            utilization: .unavailable(reason: "System-wide GPU execution engine utilization is restricted on macOS without private Apple Silicon entitlements"),
            temperature: .unavailable(reason: "GPU temperature sensors require private Apple Silicon interfaces on macOS", unit: "°C")
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
    public let readBytesPerSecond: Double
    public let writeBytesPerSecond: Double
    public let totalBytesRead: UInt64
    public let totalBytesWritten: UInt64
    public let timestamp: Date

    public init(
        status: MetricStatus = .available,
        primaryVolume: VolumeMetrics? = nil,
        allVolumes: [VolumeMetrics] = [],
        readBytesPerSecond: Double = 0.0,
        writeBytesPerSecond: Double = 0.0,
        totalBytesRead: UInt64 = 0,
        totalBytesWritten: UInt64 = 0,
        timestamp: Date = Date()
    ) {
        self.status = status
        self.primaryVolume = primaryVolume
        self.allVolumes = allVolumes
        self.readBytesPerSecond = max(0.0, readBytesPerSecond)
        self.writeBytesPerSecond = max(0.0, writeBytesPerSecond)
        self.totalBytesRead = totalBytesRead
        self.totalBytesWritten = totalBytesWritten
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

// MARK: - Fan Telemetry Models

public struct FanReading: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let rpm: Int?
    public let minRPM: Int?
    public let maxRPM: Int?
    public let status: MetricStatus

    public init(id: Int, name: String, rpm: Int?, minRPM: Int? = nil, maxRPM: Int? = nil, status: MetricStatus = .available) {
        self.id = id
        self.name = name
        self.rpm = rpm
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.status = status
    }
}

public struct FanMetrics: Sendable, Equatable {
    public let status: MetricStatus
    public let fans: [FanReading]
    public let fanCount: Int
    public let isFanless: Bool
    public let timestamp: Date

    public init(
        status: MetricStatus = .available,
        fans: [FanReading] = [],
        fanCount: Int? = nil,
        isFanless: Bool = false,
        timestamp: Date = Date()
    ) {
        self.status = status
        self.fans = fans
        self.fanCount = fanCount ?? fans.count
        self.isFanless = isFanless
        self.timestamp = timestamp
    }

    public static var initial: FanMetrics {
        FanMetrics(status: .loading)
    }

    public static var unavailable: FanMetrics {
        FanMetrics(status: .unavailable(reason: "Fan telemetry is not supported on this Mac"))
    }
}

// MARK: - Temperature Telemetry Models

public struct TemperatureSensorReading: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let celsius: Double
    public let status: MetricStatus

    public init(id: String, name: String, category: String, celsius: Double, status: MetricStatus = .available) {
        self.id = id
        self.name = name
        self.category = category
        self.celsius = celsius
        self.status = status
    }
}

public struct TemperatureMetrics: Sendable, Equatable {
    public let status: MetricStatus
    public let cpuTemperature: MetricValue<Double>
    public let gpuTemperature: MetricValue<Double>
    public let batteryTemperature: MetricValue<Double>
    public let ambientTemperature: MetricValue<Double>
    public let sensors: [TemperatureSensorReading]
    public let timestamp: Date

    public init(
        status: MetricStatus = .available,
        cpuTemperature: MetricValue<Double> = .loading(unit: "°C"),
        gpuTemperature: MetricValue<Double> = .loading(unit: "°C"),
        batteryTemperature: MetricValue<Double> = .loading(unit: "°C"),
        ambientTemperature: MetricValue<Double> = .loading(unit: "°C"),
        sensors: [TemperatureSensorReading] = [],
        timestamp: Date = Date()
    ) {
        self.status = status
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.batteryTemperature = batteryTemperature
        self.ambientTemperature = ambientTemperature
        self.sensors = sensors
        self.timestamp = timestamp
    }

    public static var initial: TemperatureMetrics {
        TemperatureMetrics(status: .loading)
    }

    public static var unavailable: TemperatureMetrics {
        TemperatureMetrics(
            status: .unavailable(reason: "Hardware thermal sensors unavailable"),
            cpuTemperature: .unavailable(reason: "Unsupported", unit: "°C"),
            gpuTemperature: .unavailable(reason: "Unsupported", unit: "°C"),
            batteryTemperature: .unavailable(reason: "Unsupported", unit: "°C"),
            ambientTemperature: .unavailable(reason: "Unsupported", unit: "°C")
        )
    }
}

// MARK: - Power & Battery Health Telemetry Models

public struct PowerMetrics: Sendable, Equatable {
    public let status: MetricStatus
    public let systemPowerWatts: Double?
    public let cpuPowerWatts: Double?
    public let gpuPowerWatts: Double?
    public let batteryHealthPercentage: Int?
    public let batteryCycleCount: Int?
    public let batteryCondition: String?
    public let isCharging: Bool
    public let timestamp: Date

    public init(
        status: MetricStatus = .available,
        systemPowerWatts: Double? = nil,
        cpuPowerWatts: Double? = nil,
        gpuPowerWatts: Double? = nil,
        batteryHealthPercentage: Int? = nil,
        batteryCycleCount: Int? = nil,
        batteryCondition: String? = nil,
        isCharging: Bool = false,
        timestamp: Date = Date()
    ) {
        self.status = status
        self.systemPowerWatts = systemPowerWatts
        self.cpuPowerWatts = cpuPowerWatts
        self.gpuPowerWatts = gpuPowerWatts
        self.batteryHealthPercentage = batteryHealthPercentage
        self.batteryCycleCount = batteryCycleCount
        self.batteryCondition = batteryCondition
        self.isCharging = isCharging
        self.timestamp = timestamp
    }

    public static var initial: PowerMetrics {
        PowerMetrics(status: .loading)
    }

    public static var unavailable: PowerMetrics {
        PowerMetrics(status: .unavailable(reason: "Power telemetry is not supported on this Mac"))
    }
}

// MARK: - Combined Snapshot

public struct SystemMetricsSnapshot: Sendable, Equatable {
    public let cpu: CPUMetrics
    public let memory: MemoryMetrics
    public let gpu: GPUMetrics
    public let storage: StorageMetrics
    public let network: NetworkMetrics
    public let systemInfo: SystemInfoMetrics
    public let fans: FanMetrics
    public let temperatures: TemperatureMetrics
    public let power: PowerMetrics
    public let timestamp: Date

    public init(
        cpu: CPUMetrics = .initial,
        memory: MemoryMetrics = .initial,
        gpu: GPUMetrics = .unavailable,
        storage: StorageMetrics = .initial,
        network: NetworkMetrics = .initial,
        systemInfo: SystemInfoMetrics = .initial,
        fans: FanMetrics = .unavailable,
        temperatures: TemperatureMetrics = .initial,
        power: PowerMetrics = .initial,
        timestamp: Date = Date()
    ) {
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.storage = storage
        self.network = network
        self.systemInfo = systemInfo
        self.fans = fans
        self.temperatures = temperatures
        self.power = power
        self.timestamp = timestamp
    }

    public static var initial: SystemMetricsSnapshot {
        SystemMetricsSnapshot()
    }
}

// MARK: - Sampling Interval

public enum SamplingInterval: Double, CaseIterable, Identifiable, Sendable {
    case quarterSecond = 0.25
    case oneSecond = 1.0
    case twoSeconds = 2.0
    case fiveSeconds = 5.0
    case tenSeconds = 10.0

    public var id: Double { rawValue }

    public var displayName: String {
        switch self {
        case .quarterSecond: return "250ms (Real-time)"
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

// MARK: - Telemetry History Buffer (15-Minute Retention)

public struct TimestampedSample: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let value: Double?

    public init(id: UUID = UUID(), timestamp: Date = Date(), value: Double?) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
    }
}

/// In-memory bounded rolling history buffer maintaining up to 15 minutes of samples.
/// Designed for lightweight memory retention without disk persistence or unbounded accumulation.
public struct TelemetryHistoryBuffer: Sendable {
    public let maxRetentionSeconds: TimeInterval
    public let maxCapacity: Int
    private var samples: [TimestampedSample]

    public init(maxRetentionSeconds: TimeInterval = 900.0, maxCapacity: Int = 1000) {
        self.maxRetentionSeconds = maxRetentionSeconds
        self.maxCapacity = maxCapacity
        self.samples = []
        self.samples.reserveCapacity(min(maxCapacity, 100))
    }

    public mutating func append(value: Double?, timestamp: Date = Date()) {
        pruneExpired(relativeTo: timestamp)
        samples.append(TimestampedSample(timestamp: timestamp, value: value))
        if samples.count > maxCapacity {
            samples.removeFirst(samples.count - maxCapacity)
        }
    }

    public mutating func pruneExpired(relativeTo referenceDate: Date = Date()) {
        let cutoff = referenceDate.addingTimeInterval(-maxRetentionSeconds)
        if let firstValidIndex = samples.firstIndex(where: { $0.timestamp >= cutoff }) {
            if firstValidIndex > 0 {
                samples.removeFirst(firstValidIndex)
            }
        } else if !samples.isEmpty {
            samples.removeAll(keepingCapacity: true)
        }
    }

    public var allSamples: [TimestampedSample] {
        samples
    }

    /// Returns the most recent samples within the given window (e.g. 60 seconds for live graphs)
    public func samples(inWindow seconds: TimeInterval, relativeTo referenceDate: Date = Date()) -> [TimestampedSample] {
        let cutoff = referenceDate.addingTimeInterval(-seconds)
        return samples.filter { $0.timestamp >= cutoff }
    }

    /// Returns only non-nil values within the specified time window
    public func validValues(inWindow seconds: TimeInterval, relativeTo referenceDate: Date = Date()) -> [Double] {
        let cutoff = referenceDate.addingTimeInterval(-seconds)
        return samples.compactMap { sample in
            guard sample.timestamp >= cutoff else { return nil }
            return sample.value
        }
    }

    public var count: Int {
        samples.count
    }

    public var isEmpty: Bool {
        samples.isEmpty
    }

    public mutating func clear() {
        samples.removeAll(keepingCapacity: true)
    }
}
