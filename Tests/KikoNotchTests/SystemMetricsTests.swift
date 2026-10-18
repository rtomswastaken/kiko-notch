import XCTest
import Foundation
@testable import KikoNotchKit

final class SystemMetricsTests: XCTestCase {
    
    // MARK: - CPU Provider Tests
    
    func testDarwinCPUMetricProviderSampling() {
        let provider = DarwinCPUMetricProvider()
        
        // Sample 1: Baseline initialization
        let sample1 = provider.sampleCPU()
        XCTAssertEqual(sample1.status, .available)
        XCTAssertEqual(sample1.totalUsagePercentage, 0.0)
        XCTAssertEqual(sample1.idlePercentage, 100.0)
        XCTAssertGreaterThan(sample1.logicalCores, 0)
        
        // Brief sleep to accumulate ticks
        Thread.sleep(forTimeInterval: 0.1)
        
        // Sample 2: Delta calculation
        let sample2 = provider.sampleCPU()
        XCTAssertEqual(sample2.status, .available)
        XCTAssertGreaterThanOrEqual(sample2.totalUsagePercentage, 0.0)
        XCTAssertLessThanOrEqual(sample2.totalUsagePercentage, 100.0)
        XCTAssertEqual(sample2.coreLoads.count, sample2.logicalCores)
        
        // Verify arithmetic: user + system + idle approx 100%
        let sum = sample2.userPercentage + sample2.systemPercentage + sample2.idlePercentage
        XCTAssertEqual(sum, 100.0, accuracy: 1.0)
    }
    
    // MARK: - Memory Provider Tests
    
    func testDarwinMemoryMetricProviderCalculations() {
        let provider = DarwinMemoryMetricProvider()
        let mem = provider.sampleMemory()
        
        XCTAssertEqual(mem.status, .available)
        XCTAssertGreaterThan(mem.totalBytes, 0)
        XCTAssertGreaterThan(mem.usedBytes, 0)
        XCTAssertGreaterThan(mem.availableBytes, 0)
        
        // Activity Monitor formula: Used = App + Wired + Compressed
        let expectedUsed = mem.appMemoryBytes + mem.wiredBytes + mem.compressedBytes
        XCTAssertEqual(mem.usedBytes, min(mem.totalBytes, expectedUsed))
        
        // Usage percentage formula
        let expectedPct = (Double(mem.usedBytes) / Double(mem.totalBytes)) * 100.0
        XCTAssertEqual(mem.usagePercentage, expectedPct, accuracy: 0.01)
        
        // Pressure level must be a recognized state
        XCTAssertTrue([MemoryPressureLevel.normal, .warning, .critical].contains(mem.pressureLevel))
    }
    
    // MARK: - GPU Provider & Truthful Unavailability Tests
    
    func testDarwinGPUMetricProviderTruthfulUnavailability() {
        let provider = DarwinGPUMetricProvider()
        let gpu = provider.sampleGPU()
        
        // Device name must be populated if Metal device exists
        XCTAssertFalse(gpu.name.isEmpty)
        
        // GPU Utilization MUST be explicitly reported as .unavailable and never fabricated
        XCTAssertEqual(
            gpu.utilization.status,
            .unavailable(reason: "System-wide GPU execution engine utilization is restricted on macOS without private Apple Silicon entitlements")
        )
        XCTAssertNil(gpu.utilization.value)
        
        // If Apple Silicon, unified memory metrics should be reported
        if gpu.isAppleSilicon {
            XCTAssertNotNil(gpu.recommendedMaxWorkingSetBytes)
            XCTAssertGreaterThan(gpu.recommendedMaxWorkingSetBytes ?? 0, 0)
        }
    }
    
    // MARK: - Storage Provider Tests
    
    func testDarwinStorageMetricProvider() {
        let provider = DarwinStorageMetricProvider()
        let storage = provider.sampleStorage()
        
        XCTAssertEqual(storage.status, .available)
        XCTAssertNotNil(storage.primaryVolume)
        
        guard let primary = storage.primaryVolume else {
            XCTFail("Primary volume was not detected")
            return
        }
        
        XCTAssertGreaterThan(primary.totalBytes, 0)
        XCTAssertGreaterThan(primary.freeBytes, 0)
        XCTAssertEqual(primary.usedBytes, primary.totalBytes - primary.freeBytes)
        
        let expectedPct = (Double(primary.usedBytes) / Double(primary.totalBytes)) * 100.0
        XCTAssertEqual(primary.usagePercentage, expectedPct, accuracy: 0.01)
    }
    
    // MARK: - Ring Buffer Tests
    
    func testRingBufferCapacityAndEviction() {
        var buffer = RingBuffer<Int>(capacity: 5)
        XCTAssertEqual(buffer.capacity, 5)
        XCTAssertEqual(buffer.count, 0)
        
        // Append 10 items (0 through 9)
        for i in 0..<10 {
            buffer.append(i)
        }
        
        XCTAssertEqual(buffer.count, 5)
        // Must contain latest 5 items: [5, 6, 7, 8, 9]
        XCTAssertEqual(buffer.values, [5, 6, 7, 8, 9])
        
        buffer.removeAll()
        XCTAssertEqual(buffer.count, 0)
        XCTAssertTrue(buffer.isEmpty)
    }
    
    // MARK: - Service Lifecycle & Zero-Idle CPU Tests
    
    @MainActor
    func testSystemMetricsServiceLifecycle() {
        let mockCPU = MockCPUMetricProvider()
        let mockMem = MockMemoryMetricProvider()
        let mockGPU = MockGPUMetricProvider()
        let mockSto = MockStorageMetricProvider()
        let mockNet = MockNetworkMetricProvider()
        let mockSys = MockSystemInfoMetricProvider()
        
        let service = SystemMetricsService(
            cpuProvider: mockCPU,
            memoryProvider: mockMem,
            gpuProvider: mockGPU,
            storageProvider: mockSto,
            networkProvider: mockNet,
            systemInfoProvider: mockSys
        )
        
        XCTAssertFalse(service.isMonitoring)
        XCTAssertEqual(service.activeConsumerCount, 0)
        
        // Register consumer 1 -> begins monitoring
        service.startMonitoring(consumerID: "Tab1")
        XCTAssertTrue(service.isMonitoring)
        XCTAssertEqual(service.activeConsumerCount, 1)
        
        // Register consumer 2 -> still monitoring
        service.startMonitoring(consumerID: "Tab2")
        XCTAssertTrue(service.isMonitoring)
        XCTAssertEqual(service.activeConsumerCount, 2)
        
        // Unregister consumer 1 -> still monitoring
        service.stopMonitoring(consumerID: "Tab1")
        XCTAssertTrue(service.isMonitoring)
        XCTAssertEqual(service.activeConsumerCount, 1)
        
        // Unregister consumer 2 -> stops monitoring (zero polling when hidden)
        service.stopMonitoring(consumerID: "Tab2")
        XCTAssertFalse(service.isMonitoring)
        XCTAssertEqual(service.activeConsumerCount, 0)
    }
    
    // MARK: - Service Sampling & Bounded History Tests
    
    @MainActor
    func testSystemMetricsServiceSampling() {
        let mockCPU = MockCPUMetricProvider()
        let mockMem = MockMemoryMetricProvider()
        let service = SystemMetricsService(
            cpuProvider: mockCPU,
            memoryProvider: mockMem
        )
        
        service.sampleNow()
        
        XCTAssertEqual(mockCPU.sampleCallCount, 1)
        XCTAssertEqual(mockMem.sampleCallCount, 1)
        XCTAssertEqual(service.currentSnapshot.cpu.totalUsagePercentage, 25.5)
        XCTAssertEqual(service.cpuHistory.count, 1)
        XCTAssertEqual(service.cpuHistory.first, 25.5)
        
        service.clearHistory()
        XCTAssertEqual(service.cpuHistory.count, 0)
    }
    
    // MARK: - Disabling Feature Stops Sampling Tests
    
    @MainActor
    func testDisablingFeatureStopsSampling() {
        let mockCPU = MockCPUMetricProvider()
        let service = SystemMetricsService(cpuProvider: mockCPU)
        service.startMonitoring(consumerID: "Tab1")
        XCTAssertTrue(service.isMonitoring)
        
        // Disable feature
        service.isEnabled = false
        XCTAssertFalse(service.isMonitoring)
        let countBefore = mockCPU.sampleCallCount
        service.sampleNow()
        XCTAssertEqual(mockCPU.sampleCallCount, countBefore, "When disabled, sampleNow should do nothing")
        
        // Re-enable
        service.isEnabled = true
        XCTAssertTrue(service.isMonitoring)
        service.stopMonitoring(consumerID: "Tab1")
        XCTAssertFalse(service.isMonitoring)
    }
    
    // MARK: - Configurable Interval Tests
    
    @MainActor
    func testSamplingIntervalChange() {
        let service = SystemMetricsService()
        XCTAssertEqual(service.samplingInterval, .twoSeconds)
        service.setSamplingInterval(5.0)
        XCTAssertEqual(service.samplingInterval, .fiveSeconds)
        service.setSamplingInterval(10.0)
        XCTAssertEqual(service.samplingInterval, .tenSeconds)
    }
    
    // MARK: - Error State & Zero-Delta Handling Tests
    
    func testErrorStatusPreservationAndNoSilentZeroConversion() {
        let errMetric = MetricValue<Double>.error(message: "Mach host query failure")
        XCTAssertEqual(errMetric.status, .error(message: "Mach host query failure"))
        XCTAssertNil(errMetric.value, "Error metric must not have a value")
        XCTAssertFalse(errMetric.status.isAvailable)
        XCTAssertEqual(errMetric.status.diagnosticReason, "Mach host query failure")
        
        let unavailMetric = MetricValue<Double>.unavailable(reason: "Private entitlement required")
        XCTAssertEqual(unavailMetric.status, .unavailable(reason: "Private entitlement required"))
        XCTAssertNil(unavailMetric.value, "Unavailable metric must never fabricate zero")
        XCTAssertFalse(unavailMetric.status.isAvailable)
        XCTAssertEqual(unavailMetric.status.diagnosticReason, "Private entitlement required")
    }
    
    func testZeroDeltaCPUMetrics() {
        let provider = DarwinCPUMetricProvider()
        _ = provider.sampleCPU()
        // Sampling back-to-back with zero elapsed time should not produce NaN or division-by-zero crashes
        let immediateSample = provider.sampleCPU()
        XCTAssertGreaterThanOrEqual(immediateSample.totalUsagePercentage, 0.0)
        XCTAssertLessThanOrEqual(immediateSample.totalUsagePercentage, 100.0)
        XCTAssertFalse(immediateSample.totalUsagePercentage.isNaN)
        XCTAssertFalse(immediateSample.idlePercentage.isNaN)
    }
    
    func testDarwinNetworkMetricProviderSampling() {
        let provider = DarwinNetworkMetricProvider()
        let sample1 = provider.sampleNetwork()
        XCTAssertEqual(sample1.status, .available)
        XCTAssertGreaterThanOrEqual(sample1.totalBytesReceived, 0)
        XCTAssertGreaterThanOrEqual(sample1.totalBytesSent, 0)
        
        Thread.sleep(forTimeInterval: 0.05)
        let sample2 = provider.sampleNetwork()
        XCTAssertEqual(sample2.status, .available)
        XCTAssertGreaterThanOrEqual(sample2.downloadBytesPerSecond, 0)
        XCTAssertGreaterThanOrEqual(sample2.uploadBytesPerSecond, 0)
    }
    
    func testDarwinSystemInfoMetricProviderSampling() {
        let provider = DarwinSystemInfoMetricProvider()
        let sys = provider.sampleSystemInfo()
        XCTAssertFalse(sys.chipName.isEmpty, "Chip name should not be empty")
        XCTAssertFalse(sys.modelIdentifier.isEmpty, "Model identifier should not be empty")
        XCTAssertFalse(sys.osVersionString.isEmpty, "OS version string should not be empty")
        XCTAssertGreaterThan(sys.uptimeSeconds, 0, "Uptime must be positive")
    }
    
    func testStorageMetricProviderErrorHandling() {
        let errorMetrics = StorageMetrics(status: .error(message: "Failed to read volumes"))
        XCTAssertFalse(errorMetrics.status.isAvailable)
        XCTAssertNil(errorMetrics.primaryVolume)
        XCTAssertTrue(errorMetrics.allVolumes.isEmpty)
        XCTAssertEqual(errorMetrics.status.diagnosticReason, "Failed to read volumes")
    }
}

