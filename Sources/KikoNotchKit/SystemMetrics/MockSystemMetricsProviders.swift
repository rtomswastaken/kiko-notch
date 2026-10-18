import Foundation

public final class MockCPUMetricProvider: CPUMetricProvider, @unchecked Sendable {
    public var metricsToReturn: CPUMetrics
    public var sampleCallCount = 0
    
    public init(metrics: CPUMetrics? = nil) {
        self.metricsToReturn = metrics ?? CPUMetrics(
            status: .available,
            totalUsagePercentage: 25.5,
            userPercentage: 15.0,
            systemPercentage: 10.5,
            idlePercentage: 74.5,
            physicalCores: 8,
            logicalCores: 8,
            coreLoads: [
                CoreLoad(id: 0, userPercentage: 15.0, systemPercentage: 5.0, idlePercentage: 80.0),
                CoreLoad(id: 1, userPercentage: 20.0, systemPercentage: 11.0, idlePercentage: 69.0)
            ]
        )
    }
    
    public func sampleCPU() -> CPUMetrics {
        sampleCallCount += 1
        return metricsToReturn
    }
}

public final class MockMemoryMetricProvider: MemoryMetricProvider, @unchecked Sendable {
    public var metricsToReturn: MemoryMetrics
    public var sampleCallCount = 0
    
    public init(metrics: MemoryMetrics? = nil) {
        let total: UInt64 = 32 * 1024 * 1024 * 1024
        let app: UInt64 = 8 * 1024 * 1024 * 1024
        let wired: UInt64 = 4 * 1024 * 1024 * 1024
        let compressed: UInt64 = 2 * 1024 * 1024 * 1024
        let used = app + wired + compressed
        let available = total - used
        
        self.metricsToReturn = metrics ?? MemoryMetrics(
            status: .available,
            totalBytes: total,
            usedBytes: used,
            availableBytes: available,
            appMemoryBytes: app,
            wiredBytes: wired,
            compressedBytes: compressed,
            cachedFilesBytes: 1 * 1024 * 1024 * 1024,
            swapTotalBytes: 2 * 1024 * 1024 * 1024,
            swapUsedBytes: 512 * 1024 * 1024,
            pressureLevel: .normal
        )
    }
    
    public func sampleMemory() -> MemoryMetrics {
        sampleCallCount += 1
        return metricsToReturn
    }
}

public final class MockGPUMetricProvider: GPUMetricProvider, @unchecked Sendable {
    public var metricsToReturn: GPUMetrics
    public var sampleCallCount = 0
    
    public init(metrics: GPUMetrics? = nil) {
        self.metricsToReturn = metrics ?? GPUMetrics(
            name: "Apple M3 Pro",
            isAppleSilicon: true,
            allocatedBytes: 2 * 1024 * 1024 * 1024,
            recommendedMaxWorkingSetBytes: 24 * 1024 * 1024 * 1024,
            utilization: .unavailable(reason: "System-wide GPU execution engine utilization is restricted on macOS without private Apple Silicon entitlements")
        )
    }
    
    public func sampleGPU() -> GPUMetrics {
        sampleCallCount += 1
        return metricsToReturn
    }
}

public final class MockStorageMetricProvider: StorageMetricProvider, @unchecked Sendable {
    public var metricsToReturn: StorageMetrics
    public var sampleCallCount = 0
    
    public init(metrics: StorageMetrics? = nil) {
        let root = VolumeMetrics(
            name: "Macintosh HD",
            mountPoint: "/",
            totalBytes: 1_000_000_000_000,
            freeBytes: 600_000_000_000,
            isRemovable: false,
            isPrimary: true
        )
        self.metricsToReturn = metrics ?? StorageMetrics(status: .available, primaryVolume: root, allVolumes: [root])
    }
    
    public func sampleStorage() -> StorageMetrics {
        sampleCallCount += 1
        return metricsToReturn
    }
}

public final class MockNetworkMetricProvider: NetworkMetricProvider, @unchecked Sendable {
    public var metricsToReturn: NetworkMetrics
    public var sampleCallCount = 0
    
    public init(metrics: NetworkMetrics? = nil) {
        self.metricsToReturn = metrics ?? NetworkMetrics(
            status: .available,
            downloadBytesPerSecond: 1_250_000,
            uploadBytesPerSecond: 450_000,
            totalBytesReceived: 10_000_000_000,
            totalBytesSent: 3_000_000_000,
            activeInterfaceName: "en0"
        )
    }
    
    public func sampleNetwork() -> NetworkMetrics {
        sampleCallCount += 1
        return metricsToReturn
    }
}

public final class MockSystemInfoMetricProvider: SystemInfoMetricProvider, @unchecked Sendable {
    public var metricsToReturn: SystemInfoMetrics
    public var sampleCallCount = 0
    
    public init(metrics: SystemInfoMetrics? = nil) {
        self.metricsToReturn = metrics ?? SystemInfoMetrics(
            chipName: "Apple M3 Pro",
            modelIdentifier: "Mac15,6",
            osVersionString: "macOS 14.5",
            uptimeSeconds: 86400,
            thermalState: .nominal
        )
    }
    
    public func sampleSystemInfo() -> SystemInfoMetrics {
        sampleCallCount += 1
        return metricsToReturn
    }
}
