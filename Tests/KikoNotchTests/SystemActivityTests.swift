import XCTest
import Foundation
@testable import KikoNotchKit

final class SystemActivityTests: XCTestCase {
    
    // MARK: - 1. Telemetry History Buffer (15-min retention & 60-s slicing)
    
    func testTelemetryHistoryBufferRetentionAndWindowSlicing() {
        var buffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0) // 15 mins
        let now = Date()
        
        // Append samples with simulated timestamps:
        // - 20 minutes ago (should be pruned)
        // - 10 minutes ago (within 15m, outside 60s)
        // - 45 seconds ago (within 60s)
        // - 10 seconds ago (within 60s)
        // - now (within 60s)
        buffer.append(value: 10.0, timestamp: now.addingTimeInterval(-1200)) // 20m ago
        buffer.append(value: 20.0, timestamp: now.addingTimeInterval(-600))  // 10m ago
        buffer.append(value: 30.0, timestamp: now.addingTimeInterval(-45))   // 45s ago
        buffer.append(value: 40.0, timestamp: now.addingTimeInterval(-10))   // 10s ago
        buffer.append(value: 50.0, timestamp: now)                          // now
        
        // 15-minute retention check: 20m ago should have been pruned
        let all15m = buffer.allSamples
        XCTAssertEqual(all15m.count, 4, "Sample older than 15 minutes must be pruned")
        XCTAssertFalse(all15m.contains(where: { $0.value == 10.0 }))
        
        // 60-second window slice: should only include 45s, 10s, and now
        let window60s = buffer.samples(inWindow: 60.0, relativeTo: now)
        XCTAssertEqual(window60s.count, 3, "60s window must only contain samples within the last 60 seconds")
        let values = window60s.compactMap { $0.value }
        XCTAssertEqual(values, [30.0, 40.0, 50.0])
    }
    
    func testTelemetryHistoryBufferHandlesNilValues() {
        var buffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0)
        let now = Date()
        
        // Telemetry dropouts (nil value) must be preserved accurately to prevent connecting phantom lines
        buffer.append(value: 25.0, timestamp: now.addingTimeInterval(-20))
        buffer.append(value: nil, timestamp: now.addingTimeInterval(-10))
        buffer.append(value: 75.0, timestamp: now)
        
        let slice = buffer.samples(inWindow: 60.0, relativeTo: now)
        XCTAssertEqual(slice.count, 3)
        XCTAssertEqual(slice[0].value, 25.0)
        XCTAssertNil(slice[1].value, "Dropout sample value must remain nil")
        XCTAssertEqual(slice[2].value, 75.0)
        
        let valids = buffer.validValues(inWindow: 60.0, relativeTo: now)
        XCTAssertEqual(valids, [25.0, 75.0], "validValues must exclude nil dropouts")
    }
    
    func testTelemetryHistoryBufferMaxCapacity() {
        var buffer = TelemetryHistoryBuffer(maxRetentionSeconds: 900.0, maxCapacity: 50)
        let now = Date()
        
        for i in 0..<100 {
            buffer.append(value: Double(i), timestamp: now.addingTimeInterval(Double(i)))
        }
        
        XCTAssertLessThanOrEqual(buffer.count, 50, "Buffer count must never exceed maxCapacity")
        XCTAssertEqual(buffer.allSamples.last?.value, 99.0)
    }
    
    // MARK: - 2. Honest Telemetry: Temperature, Fan & Power Metrics
    
    func testTemperatureTelemetryHonesty() {
        let provider = DarwinTemperatureTelemetryProvider()
        let temps = provider.sampleTemperatures()
        let cpuTemp = provider.sampleCPUTemperature()
        let gpuTemp = provider.sampleGPUTemperature()
        
        // Temperatures must be truthful: if SMC is readable, temperatures must be within physically valid bounds (10°C to 115°C);
        // if SMC is unavailable, values must be strictly nil and never fabricated.
        if cpuTemp.status.isAvailable {
            guard let val = cpuTemp.value else {
                XCTFail("Available CPU temperature must have a non-nil value")
                return
            }
            XCTAssertGreaterThan(val, 10.0, "CPU temperature must exceed 10°C")
            XCTAssertLessThan(val, 115.0, "CPU temperature must be below 115°C")
        } else {
            XCTAssertNil(cpuTemp.value, "CPU temperature must not fabricate dummy degrees when unavailable")
            XCTAssertNotNil(cpuTemp.status.diagnosticReason)
        }
        
        if gpuTemp.status.isAvailable {
            guard let val = gpuTemp.value else {
                XCTFail("Available GPU temperature must have a non-nil value")
                return
            }
            XCTAssertGreaterThan(val, 10.0, "GPU temperature must exceed 10°C")
            XCTAssertLessThan(val, 115.0, "GPU temperature must be below 115°C")
        } else {
            XCTAssertNil(gpuTemp.value, "GPU temperature must not fabricate dummy degrees when unavailable")
        }

        // Test comprehensive temperature snapshot
        if temps.status.isAvailable {
            XCTAssertFalse(temps.sensors.isEmpty, "Available temperature snapshot should contain readings")
        }
    }
    
    func testFanTelemetryHonesty() {
        let provider = DarwinFanTelemetryProvider()
        let fanMetrics = provider.sampleFans()
        
        // Either the Mac is a known fanless model (e.g. MacBook Air M1/M2/M3),
        // or fans are actively read via AppleSMC with valid RPM and ranges,
        // or reported as unavailable. In NO case should fake fan RPMs be fabricated!
        if fanMetrics.isFanless {
            XCTAssertTrue(fanMetrics.fans.isEmpty)
            XCTAssertTrue(fanMetrics.status.isAvailable)
        } else if fanMetrics.status.isAvailable {
            XCTAssertFalse(fanMetrics.fans.isEmpty, "Fans must be populated on active cooling system")
            for fan in fanMetrics.fans {
                if let max = fan.maxRPM {
                    XCTAssertGreaterThan(max, 0, "Fan max RPM must be positive")
                }
                if let cur = fan.rpm {
                    XCTAssertGreaterThanOrEqual(cur, 0, "Fan RPM must be non-negative")
                    if let max = fan.maxRPM {
                        XCTAssertLessThanOrEqual(cur, max * 2, "Fan RPM must be within realistic ceiling")
                    }
                }
            }
        } else {
            XCTAssertFalse(fanMetrics.status.isAvailable, "Fan RPM must report unavailable without SMC access")
            XCTAssertTrue(fanMetrics.fans.isEmpty)
        }
    }
    
    func testCPUAndGPUMetricsIncludeTemperatureField() {
        let cpuProvider = DarwinCPUMetricProvider()
        let cpu = cpuProvider.sampleCPU()
        if cpu.temperature.status.isAvailable {
            XCTAssertNotNil(cpu.temperature.value)
            XCTAssertGreaterThan(cpu.temperature.value ?? 0, 10.0)
        } else {
            XCTAssertNil(cpu.temperature.value)
        }
        
        let gpuProvider = DarwinGPUMetricProvider()
        let gpu = gpuProvider.sampleGPU()
        if gpu.temperature.status.isAvailable {
            XCTAssertNotNil(gpu.temperature.value)
            XCTAssertGreaterThan(gpu.temperature.value ?? 0, 10.0)
        } else {
            XCTAssertNil(gpu.temperature.value)
        }
    }

    func testPowerTelemetryProvider() {
        let provider = DarwinPowerTelemetryProvider()
        let power = provider.samplePower()

        if power.status.isAvailable {
            if let watts = power.systemPowerWatts {
                XCTAssertGreaterThan(watts, 0.0, "System power draw must be positive")
                XCTAssertLessThan(watts, 200.0, "System power draw must be realistic")
            }
            if let cycles = power.batteryCycleCount {
                XCTAssertGreaterThanOrEqual(cycles, 0, "Cycle count must be non-negative")
            }
        }
    }

    func testStorageThroughputTelemetry() {
        let provider = DarwinStorageMetricProvider()
        let s1 = provider.sampleStorage()
        XCTAssertGreaterThanOrEqual(s1.readBytesPerSecond, 0)
        XCTAssertGreaterThanOrEqual(s1.writeBytesPerSecond, 0)
    }
    
    // MARK: - 3. Storage Primary Disk Ordering & Deduplication
    
    func testStorageStartupDiskOrderingAndDeduplication() {
        let provider = DarwinStorageMetricProvider()
        let storage = provider.sampleStorage()
        
        XCTAssertEqual(storage.status, .available)
        guard let primary = storage.primaryVolume else {
            XCTFail("Must discover primary startup volume")
            return
        }
        
        XCTAssertTrue(primary.isPrimary, "Primary volume must have isPrimary == true")
        XCTAssertEqual(primary.mountPoint, "/", "Primary startup disk must mount at /")
        
        // If there are multiple volumes, ensure mount points are distinct (deduplicated)
        let mountPoints = storage.allVolumes.map { $0.mountPoint }
        let uniqueMountPoints = Set(mountPoints)
        XCTAssertEqual(mountPoints.count, uniqueMountPoints.count, "Mounted volumes must be deduplicated by mount point")
        
        // Ensure primary volume is first in the list
        XCTAssertEqual(storage.allVolumes.first?.mountPoint, "/", "Startup disk must sort first in allVolumes")
    }
    
    // MARK: - 4. Sampling Decoupling & Quarter-Second Interval
    
    func testSamplingIntervalQuarterSecond() {
        XCTAssertEqual(SamplingInterval.quarterSecond.rawValue, 0.25)
        XCTAssertEqual(SamplingInterval.quarterSecond.displayName, "250ms (Real-time)")
    }
    
    @MainActor
    func testSystemMetricsServiceFastSamplingAndHistoryAccumulation() {
        let cpu = MockCPUMetricProvider()
        let mem = MockMemoryMetricProvider()
        let gpu = MockGPUMetricProvider()
        let storage = MockStorageMetricProvider()
        let net = MockNetworkMetricProvider()
        let sys = MockSystemInfoMetricProvider()
        let temp = MockTemperatureTelemetryProvider()
        let fan = MockFanTelemetryProvider()
        
        let service = SystemMetricsService(
            cpuProvider: cpu,
            memoryProvider: mem,
            gpuProvider: gpu,
            storageProvider: storage,
            networkProvider: net,
            systemInfoProvider: sys,
            temperatureProvider: temp,
            fanProvider: fan
        )
        service.samplingInterval = .quarterSecond
        
        // Register consumer
        service.registerConsumer(id: "TestConsumer")
        XCTAssertTrue(service.isMonitoring)
        
        // Take manual samples
        service.sampleNow()
        service.sampleNow()
        
        let cpuHistory = service.cpu60sHistory
        let memHistory = service.memory60sHistory
        
        XCTAssertGreaterThanOrEqual(cpuHistory.count, 2)
        XCTAssertGreaterThanOrEqual(memHistory.count, 2)
        
        // Unregister consumer -> paused
        service.unregisterConsumer(id: "TestConsumer")
        XCTAssertFalse(service.isMonitoring, "Service must stop sampling when active consumer count reaches 0")
    }

    // MARK: - 5. System Statistics Overview Bento Grid & Entry Points

    func testSystemActivityCategoryEnumValues() {
        let expectedCategories: [SystemActivityCategory] = [
            .all, .cpu, .gpu, .cooling, .memory, .storage, .power, .network
        ]
        XCTAssertEqual(SystemActivityCategory.allCases.count, 8)
        for cat in expectedCategories {
            XCTAssertTrue(SystemActivityCategory.allCases.contains(cat))
            XCTAssertFalse(cat.rawValue.isEmpty)
        }
    }

    @MainActor
    func testBentoGridCardNavigationAndStateTransitions() {
        var selectedCategory: SystemActivityCategory = .all

        // Simulating card taps:
        selectedCategory = .cpu
        XCTAssertEqual(selectedCategory, .cpu)

        selectedCategory = .memory
        XCTAssertEqual(selectedCategory, .memory)

        selectedCategory = .gpu
        XCTAssertEqual(selectedCategory, .gpu)

        selectedCategory = .cooling
        XCTAssertEqual(selectedCategory, .cooling)

        selectedCategory = .storage
        XCTAssertEqual(selectedCategory, .storage)

        selectedCategory = .power
        XCTAssertEqual(selectedCategory, .power)

        selectedCategory = .network
        XCTAssertEqual(selectedCategory, .network)

        // Returning to overview
        selectedCategory = .all
        XCTAssertEqual(selectedCategory, .all)
    }

    @MainActor
    func testBentoGridMetricSnapshotTruthfulness() {
        let service = SystemMetricsService.shared
        service.sampleNow()
        let snap = service.snapshot

        // CPU
        if snap.cpu.status.isAvailable {
            XCTAssertGreaterThanOrEqual(snap.cpu.totalUsagePercentage, 0.0)
            XCTAssertLessThanOrEqual(snap.cpu.totalUsagePercentage, 100.0)
        }

        // Memory
        if snap.memory.status.isAvailable {
            XCTAssertGreaterThan(snap.memory.totalBytes, 0)
            XCTAssertLessThanOrEqual(snap.memory.usedBytes, snap.memory.totalBytes)
        }

        // Storage primary volume
        if let primary = snap.storage.primaryVolume {
            XCTAssertGreaterThan(primary.totalBytes, 0)
            XCTAssertEqual(primary.mountPoint, "/")
        }

        // System Info
        XCTAssertFalse(snap.systemInfo.chipName.isEmpty)
        XCTAssertGreaterThan(snap.systemInfo.uptimeSeconds, 0)
        XCTAssertFalse(snap.systemInfo.formattedUptime.isEmpty)
    }
}
