import Foundation
import Combine

/// Centralized, high-efficiency System Metrics service for Kiko Notch.
/// Employs modular metric providers, bounded 15-minute rolling history,
/// 60-second live graph buffers, and zero-idle-CPU consumer management.
@MainActor
public final class SystemMetricsService: ObservableObject {
    public static let shared = SystemMetricsService()

    public static let supportedIntervals: [SamplingInterval] = SamplingInterval.allCases

    // MARK: - Published Properties

    @Published public private(set) var snapshot: SystemMetricsSnapshot = .initial
    @Published public private(set) var cpuHistory: [Double] = []
    @Published public private(set) var memoryHistory: [Double] = []
    @Published public private(set) var networkDownloadHistory: [Double] = []
    @Published public private(set) var networkUploadHistory: [Double] = []

    /// 60-second live graph samples
    @Published public private(set) var cpu60sHistory: [TimestampedSample] = []
    @Published public private(set) var gpu60sHistory: [TimestampedSample] = []
    @Published public private(set) var memory60sHistory: [TimestampedSample] = []
    @Published public private(set) var networkDownload60sHistory: [TimestampedSample] = []
    @Published public private(set) var networkUpload60sHistory: [TimestampedSample] = []
    @Published public private(set) var diskRead60sHistory: [TimestampedSample] = []
    @Published public private(set) var diskWrite60sHistory: [TimestampedSample] = []
    @Published public private(set) var temperature60sHistory: [TimestampedSample] = []
    @Published public private(set) var fanSpeed60sHistory: [TimestampedSample] = []

    /// Understated human-readable indicator of most recent successful sample
    @Published public private(set) var lastUpdatedString: String = "Never"

    @Published public private(set) var isMonitoring: Bool = false

    @Published public var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                if isMonitoring {
                    stopSampling()
                }
            } else {
                if !activeConsumers.isEmpty && !isMonitoring {
                    startSampling()
                }
            }
        }
    }

    @Published public var samplingInterval: SamplingInterval = .twoSeconds {
        didSet {
            if isMonitoring {
                restartTimer()
            }
        }
    }

    public var currentSnapshot: SystemMetricsSnapshot {
        snapshot
    }

    // MARK: - Consumer Management (Zero-Idle CPU)

    private var activeConsumers: Set<String> = []

    // MARK: - History Buffers (Capacity: 60 Samples for legacy, 15 Minutes for dashboard)

    private var cpuRing = RingBuffer<Double>(capacity: 60)
    private var memRing = RingBuffer<Double>(capacity: 60)
    private var dlRing = RingBuffer<Double>(capacity: 60)
    private var ulRing = RingBuffer<Double>(capacity: 60)

    public private(set) var cpu15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var gpu15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var memory15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var networkDownload15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var networkUpload15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var diskRead15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var diskWrite15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var temperature15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)
    public private(set) var fanSpeed15mBuffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 1000)

    // MARK: - Dependencies

    public let cpuProvider: CPUMetricProvider
    public let memoryProvider: MemoryMetricProvider
    public let gpuProvider: GPUMetricProvider
    public let storageProvider: StorageMetricProvider
    public let networkProvider: NetworkMetricProvider
    public let systemInfoProvider: SystemInfoMetricProvider
    public let temperatureProvider: TemperatureTelemetryProvider
    public let fanProvider: FanTelemetryProvider
    public let powerProvider: PowerTelemetryProvider
    public let batteryMonitor: BatteryMonitor

    private var timer: AnyCancellable?
    private var presentationTimer: AnyCancellable?
    private var sampleCount: UInt64 = 0
    private let backgroundQueue = DispatchQueue(label: "com.kikonotch.metrics.sampling", qos: .userInitiated)

    // Cached telemetry for decoupled cadences
    private var cachedStorage: StorageMetrics = .initial
    private var cachedSystemInfo: SystemInfoMetrics = .initial
    private var cachedFans: FanMetrics = .unavailable
    private var cachedTemperatures: TemperatureMetrics = .initial
    private var cachedPower: PowerMetrics = .initial

    // MARK: - Initialization

    public init(
        cpuProvider: CPUMetricProvider = DarwinCPUMetricProvider(),
        memoryProvider: MemoryMetricProvider = DarwinMemoryMetricProvider(),
        gpuProvider: GPUMetricProvider = DarwinGPUMetricProvider(),
        storageProvider: StorageMetricProvider = DarwinStorageMetricProvider(),
        networkProvider: NetworkMetricProvider = DarwinNetworkMetricProvider(),
        systemInfoProvider: SystemInfoMetricProvider = DarwinSystemInfoMetricProvider(),
        temperatureProvider: TemperatureTelemetryProvider = DarwinTemperatureTelemetryProvider(),
        fanProvider: FanTelemetryProvider = DarwinFanTelemetryProvider(),
        powerProvider: PowerTelemetryProvider = DarwinPowerTelemetryProvider(),
        batteryMonitor: BatteryMonitor = BatteryMonitor.shared
    ) {
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.gpuProvider = gpuProvider
        self.storageProvider = storageProvider
        self.networkProvider = networkProvider
        self.systemInfoProvider = systemInfoProvider
        self.temperatureProvider = temperatureProvider
        self.fanProvider = fanProvider
        self.powerProvider = powerProvider
        self.batteryMonitor = batteryMonitor
    }

    // MARK: - Lifecycle & Registration

    public func startMonitoring(consumerID: String) {
        registerConsumer(id: consumerID)
    }

    public func stopMonitoring(consumerID: String) {
        unregisterConsumer(id: consumerID)
    }

    /// Registers a UI component or service as an active consumer.
    /// When the first consumer registers, periodic sampling automatically starts.
    public func registerConsumer(id: String) {
        activeConsumers.insert(id)
        if isEnabled && !isMonitoring {
            startSampling()
        }
    }

    /// Unregisters an active consumer.
    /// When no consumers remain, periodic sampling automatically stops to ensure Zero-Idle CPU.
    public func unregisterConsumer(id: String) {
        activeConsumers.remove(id)
        if activeConsumers.isEmpty && isMonitoring {
            stopSampling()
        }
    }

    public var activeConsumerCount: Int {
        activeConsumers.count
    }

    public func setSamplingInterval(seconds: TimeInterval) {
        if seconds <= 0.5 {
            self.samplingInterval = .quarterSecond
        } else if seconds <= 1.5 {
            self.samplingInterval = .oneSecond
        } else if seconds <= 3.5 {
            self.samplingInterval = .twoSeconds
        } else if seconds <= 7.5 {
            self.samplingInterval = .fiveSeconds
        } else {
            self.samplingInterval = .tenSeconds
        }
    }

    // MARK: - Sampling

    /// Triggers an immediate synchronous sample of all metrics and updates published history.
    public func sampleNow() {
        guard isEnabled else { return }

        let cpu = cpuProvider.sampleCPU()
        let memory = memoryProvider.sampleMemory()
        let gpu = gpuProvider.sampleGPU()
        let storage = storageProvider.sampleStorage()
        let network = networkProvider.sampleNetwork()
        let systemInfo = systemInfoProvider.sampleSystemInfo()
        let fans = fanProvider.sampleFans()
        let temps = temperatureProvider.sampleTemperatures()
        let power = powerProvider.samplePower()

        cachedStorage = storage
        cachedSystemInfo = systemInfo
        cachedFans = fans
        cachedTemperatures = temps
        cachedPower = power

        let now = Date()

        // Update Ring Buffers (legacy)
        cpuRing.append(cpu.totalUsagePercentage)
        memRing.append(memory.usagePercentage)
        dlRing.append(network.downloadBytesPerSecond)
        ulRing.append(network.uploadBytesPerSecond)

        // Update 15-Minute Buffers
        cpu15mBuffer.append(value: cpu.totalUsagePercentage, timestamp: now)
        let gpuVal: Double? = gpu.utilization.status == .available ? gpu.utilization.value : nil
        gpu15mBuffer.append(value: gpuVal, timestamp: now)
        memory15mBuffer.append(value: memory.usagePercentage, timestamp: now)
        networkDownload15mBuffer.append(value: network.downloadBytesPerSecond, timestamp: now)
        networkUpload15mBuffer.append(value: network.uploadBytesPerSecond, timestamp: now)
        diskRead15mBuffer.append(value: storage.readBytesPerSecond, timestamp: now)
        diskWrite15mBuffer.append(value: storage.writeBytesPerSecond, timestamp: now)
        temperature15mBuffer.append(value: temps.cpuTemperature.value, timestamp: now)
        let primaryFanRpm = fans.fans.first?.rpm.map { Double($0) }
        fanSpeed15mBuffer.append(value: primaryFanRpm, timestamp: now)

        // Publish state
        self.cpuHistory = cpuRing.values
        self.memoryHistory = memRing.values
        self.networkDownloadHistory = dlRing.values
        self.networkUploadHistory = ulRing.values

        // 60-Second Window slices
        self.cpu60sHistory = cpu15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.gpu60sHistory = gpu15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.memory60sHistory = memory15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.networkDownload60sHistory = networkDownload15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.networkUpload60sHistory = networkUpload15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.diskRead60sHistory = diskRead15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.diskWrite60sHistory = diskWrite15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.temperature60sHistory = temperature15mBuffer.samples(inWindow: 60.0, relativeTo: now)
        self.fanSpeed60sHistory = fanSpeed15mBuffer.samples(inWindow: 60.0, relativeTo: now)

        self.snapshot = SystemMetricsSnapshot(
            cpu: cpu,
            memory: memory,
            gpu: gpu,
            storage: storage,
            network: network,
            systemInfo: systemInfo,
            fans: fans,
            temperatures: temps,
            power: power,
            timestamp: now
        )
        self.lastUpdatedString = "Just now"
    }

    /// Asynchronous sampling for continuous polling that decouples query cadences
    private func executeDecoupledSample() {
        let isMon = self.isMonitoring
        guard isEnabled, isMon else { return }
        sampleCount += 1
        let count = sampleCount

        // Decoupled query schedules:
        // Fast metrics (every tick): CPU, GPU, Network, Storage Throughput
        // SMC metrics (every 4 ticks or ~1-2s): Fans, Temperatures, Power
        let querySMC = (count % 4 == 0) || cachedFans.status == .loading
        // Slow metrics (every 20 ticks or ~5-10s): System Info
        let querySystemInfo = (count % 20 == 0) || cachedSystemInfo.modelIdentifier.isEmpty

        let cpuProv = self.cpuProvider
        let memProv = self.memoryProvider
        let gpuProv = self.gpuProvider
        let storProv = self.storageProvider
        let netProv = self.networkProvider
        let sysProv = self.systemInfoProvider
        let fanProv = self.fanProvider
        let tempProv = self.temperatureProvider
        let pwrProv = self.powerProvider

        let existingSysInfo = self.cachedSystemInfo
        let existingFans = self.cachedFans
        let existingTemps = self.cachedTemperatures
        let existingPower = self.cachedPower

        backgroundQueue.async { [weak self] in
            let cpu = cpuProv.sampleCPU()
            let memory = memProv.sampleMemory()
            let gpu = gpuProv.sampleGPU()
            let network = netProv.sampleNetwork()
            let storage = storProv.sampleStorage() // Queries storage throughput every tick; volume list is fast
            let systemInfo = querySystemInfo ? sysProv.sampleSystemInfo() : existingSysInfo
            let fans = querySMC ? fanProv.sampleFans() : existingFans
            let temps = querySMC ? tempProv.sampleTemperatures() : existingTemps
            let power = querySMC ? pwrProv.samplePower() : existingPower

            let now = Date()

            Task { @MainActor [weak self] in
                guard let self = self, self.isMonitoring else { return }

                self.cachedStorage = storage
                self.cachedSystemInfo = systemInfo
                self.cachedFans = fans
                self.cachedTemperatures = temps
                self.cachedPower = power

                self.cpuRing.append(cpu.totalUsagePercentage)
                self.memRing.append(memory.usagePercentage)
                self.dlRing.append(network.downloadBytesPerSecond)
                self.ulRing.append(network.uploadBytesPerSecond)

                self.cpu15mBuffer.append(value: cpu.totalUsagePercentage, timestamp: now)
                let gpuVal: Double? = gpu.utilization.status == .available ? gpu.utilization.value : nil
                self.gpu15mBuffer.append(value: gpuVal, timestamp: now)
                self.memory15mBuffer.append(value: memory.usagePercentage, timestamp: now)
                self.networkDownload15mBuffer.append(value: network.downloadBytesPerSecond, timestamp: now)
                self.networkUpload15mBuffer.append(value: network.uploadBytesPerSecond, timestamp: now)
                self.diskRead15mBuffer.append(value: storage.readBytesPerSecond, timestamp: now)
                self.diskWrite15mBuffer.append(value: storage.writeBytesPerSecond, timestamp: now)
                self.temperature15mBuffer.append(value: temps.cpuTemperature.value, timestamp: now)
                let primaryFanRpm = fans.fans.first?.rpm.map { Double($0) }
                self.fanSpeed15mBuffer.append(value: primaryFanRpm, timestamp: now)

                self.cpuHistory = self.cpuRing.values
                self.memoryHistory = self.memRing.values
                self.networkDownloadHistory = self.dlRing.values
                self.networkUploadHistory = self.ulRing.values

                self.cpu60sHistory = self.cpu15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.gpu60sHistory = self.gpu15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.memory60sHistory = self.memory15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.networkDownload60sHistory = self.networkDownload15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.networkUpload60sHistory = self.networkUpload15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.diskRead60sHistory = self.diskRead15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.diskWrite60sHistory = self.diskWrite15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.temperature60sHistory = self.temperature15mBuffer.samples(inWindow: 60.0, relativeTo: now)
                self.fanSpeed60sHistory = self.fanSpeed15mBuffer.samples(inWindow: 60.0, relativeTo: now)

                self.snapshot = SystemMetricsSnapshot(
                    cpu: cpu,
                    memory: memory,
                    gpu: gpu,
                    storage: storage,
                    network: network,
                    systemInfo: systemInfo,
                    fans: fans,
                    temperatures: temps,
                    power: power,
                    timestamp: now
                )
                self.lastUpdatedString = "Just now"
            }
        }
    }

    // MARK: - Internal Timer Management

    private func startSampling() {
        guard isEnabled, !isMonitoring else { return }
        isMonitoring = true

        // Initial sample
        sampleNow()

        setupTimer()
        setupPresentationTimer()
    }

    private func stopSampling() {
        guard isMonitoring else { return }
        isMonitoring = false
        timer?.cancel()
        timer = nil
        presentationTimer?.cancel()
        presentationTimer = nil
    }

    private func restartTimer() {
        timer?.cancel()
        timer = nil
        if isMonitoring && isEnabled {
            setupTimer()
        }
    }

    private func setupTimer() {
        let interval = samplingInterval.rawValue
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.executeDecoupledSample()
            }
    }

    private func setupPresentationTimer() {
        // Presentation clock: updates relative timestamp ("Just now", "2s ago") and keeps graphs moving
        presentationTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let elapsed = Int(Date().timeIntervalSince(self.snapshot.timestamp))
                if elapsed < 2 {
                    self.lastUpdatedString = "Just now"
                } else if elapsed < 60 {
                    self.lastUpdatedString = "\(elapsed)s ago"
                } else {
                    self.lastUpdatedString = "\(elapsed / 60)m ago"
                }
            }
    }

    /// Clears historical ring buffer and 15-minute samples.
    public func clearHistory() {
        cpuRing.removeAll()
        memRing.removeAll()
        dlRing.removeAll()
        ulRing.removeAll()
        cpu15mBuffer.clear()
        gpu15mBuffer.clear()
        memory15mBuffer.clear()
        networkDownload15mBuffer.clear()
        networkUpload15mBuffer.clear()
        diskRead15mBuffer.clear()
        diskWrite15mBuffer.clear()
        temperature15mBuffer.clear()
        fanSpeed15mBuffer.clear()

        cpuHistory = []
        memoryHistory = []
        networkDownloadHistory = []
        networkUploadHistory = []
        cpu60sHistory = []
        gpu60sHistory = []
        memory60sHistory = []
        networkDownload60sHistory = []
        networkUpload60sHistory = []
        diskRead60sHistory = []
        diskWrite60sHistory = []
        temperature60sHistory = []
        fanSpeed60sHistory = []
    }
}
