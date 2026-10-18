import Foundation
import Combine

/// Centralized, high-efficiency System Metrics service for Kiko Notch.
/// Employs modular metric providers, bounded ring buffer history, and zero-idle-CPU consumer management.
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
    
    // MARK: - History Buffers (Capacity: 60 Samples)
    
    private var cpuRing = RingBuffer<Double>(capacity: 60)
    private var memRing = RingBuffer<Double>(capacity: 60)
    private var dlRing = RingBuffer<Double>(capacity: 60)
    private var ulRing = RingBuffer<Double>(capacity: 60)
    
    // MARK: - Dependencies
    
    public let cpuProvider: CPUMetricProvider
    public let memoryProvider: MemoryMetricProvider
    public let gpuProvider: GPUMetricProvider
    public let storageProvider: StorageMetricProvider
    public let networkProvider: NetworkMetricProvider
    public let systemInfoProvider: SystemInfoMetricProvider
    public let batteryMonitor: BatteryMonitor
    
    private var timer: AnyCancellable?
    
    // MARK: - Initialization
    
    public init(
        cpuProvider: CPUMetricProvider = DarwinCPUMetricProvider(),
        memoryProvider: MemoryMetricProvider = DarwinMemoryMetricProvider(),
        gpuProvider: GPUMetricProvider = DarwinGPUMetricProvider(),
        storageProvider: StorageMetricProvider = DarwinStorageMetricProvider(),
        networkProvider: NetworkMetricProvider = DarwinNetworkMetricProvider(),
        systemInfoProvider: SystemInfoMetricProvider = DarwinSystemInfoMetricProvider(),
        batteryMonitor: BatteryMonitor = BatteryMonitor.shared
    ) {
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.gpuProvider = gpuProvider
        self.storageProvider = storageProvider
        self.networkProvider = networkProvider
        self.systemInfoProvider = systemInfoProvider
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
        let wasEmpty = activeConsumers.isEmpty
        activeConsumers.insert(id)
        
        if wasEmpty && isEnabled {
            startSampling()
        }
    }
    
    /// Unregisters a consumer.
    /// When no consumers remain, periodic sampling stops to preserve zero idle CPU.
    public func unregisterConsumer(id: String) {
        activeConsumers.remove(id)
        
        if activeConsumers.isEmpty {
            stopSampling()
        }
    }
    
    public var activeConsumerCount: Int {
        activeConsumers.count
    }
    
    public func setSamplingInterval(_ interval: SamplingInterval) {
        self.samplingInterval = interval
    }
    
    public func setSamplingInterval(_ seconds: Double) {
        if seconds <= 1.5 {
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
        
        // Update Ring Buffers
        cpuRing.append(cpu.totalUsagePercentage)
        memRing.append(memory.usagePercentage)
        dlRing.append(network.downloadBytesPerSecond)
        ulRing.append(network.uploadBytesPerSecond)
        
        // Publish state
        self.cpuHistory = cpuRing.values
        self.memoryHistory = memRing.values
        self.networkDownloadHistory = dlRing.values
        self.networkUploadHistory = ulRing.values
        
        self.snapshot = SystemMetricsSnapshot(
            cpu: cpu,
            memory: memory,
            gpu: gpu,
            storage: storage,
            network: network,
            systemInfo: systemInfo,
            timestamp: Date()
        )
    }
    
    // MARK: - Internal Timer Management
    
    private func startSampling() {
        guard isEnabled, !isMonitoring else { return }
        isMonitoring = true
        
        // Initial sample
        sampleNow()
        
        setupTimer()
    }
    
    private func stopSampling() {
        guard isMonitoring else { return }
        isMonitoring = false
        timer?.cancel()
        timer = nil
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
                self?.sampleNow()
            }
    }
    
    /// Clears historical ring buffer samples.
    public func clearHistory() {
        cpuRing.removeAll()
        memRing.removeAll()
        dlRing.removeAll()
        ulRing.removeAll()
        cpuHistory = []
        memoryHistory = []
        networkDownloadHistory = []
        networkUploadHistory = []
    }
}
