import Foundation
import Metal
import Darwin
import IOKit

// MARK: - Protocols

public protocol CPUMetricProvider: Sendable {
    func sampleCPU() -> CPUMetrics
}

public protocol MemoryMetricProvider: Sendable {
    func sampleMemory() -> MemoryMetrics
}

public protocol GPUMetricProvider: Sendable {
    func sampleGPU() -> GPUMetrics
}

public protocol StorageMetricProvider: Sendable {
    func sampleStorage() -> StorageMetrics
}

public protocol NetworkMetricProvider: Sendable {
    func sampleNetwork() -> NetworkMetrics
}

public protocol SystemInfoMetricProvider: Sendable {
    func sampleSystemInfo() -> SystemInfoMetrics
}

public protocol TemperatureTelemetryProvider: Sendable {
    func sampleTemperatures() -> TemperatureMetrics
    func sampleCPUTemperature() -> MetricValue<Double>
    func sampleGPUTemperature() -> MetricValue<Double>
}

public protocol FanTelemetryProvider: Sendable {
    func sampleFans() -> FanMetrics
}

public protocol PowerTelemetryProvider: Sendable {
    func samplePower() -> PowerMetrics
}

public typealias CPUMetricProviderProtocol = CPUMetricProvider
public typealias MemoryMetricProviderProtocol = MemoryMetricProvider
public typealias GPUMetricProviderProtocol = GPUMetricProvider
public typealias StorageMetricProviderProtocol = StorageMetricProvider
public typealias NetworkMetricProviderProtocol = NetworkMetricProvider
public typealias SystemInfoMetricProviderProtocol = SystemInfoMetricProvider
public typealias TemperatureTelemetryProviderProtocol = TemperatureTelemetryProvider
public typealias FanTelemetryProviderProtocol = FanTelemetryProvider
public typealias PowerTelemetryProviderProtocol = PowerTelemetryProvider

// MARK: - Darwin CPU Provider

public final class DarwinCPUMetricProvider: CPUMetricProvider, @unchecked Sendable {
    private struct CoreTicks {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    private let lock = NSLock()
    private var previousCoreTicks: [CoreTicks] = []
    public let temperatureProvider: TemperatureTelemetryProvider

    public init(temperatureProvider: TemperatureTelemetryProvider = DarwinTemperatureTelemetryProvider()) {
        self.temperatureProvider = temperatureProvider
    }

    public func sampleCPU() -> CPUMetrics {
        lock.lock()
        defer { lock.unlock() }

        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        let temp = temperatureProvider.sampleCPUTemperature()
        let sysPower = SMCTelemetryService.shared.readSystemPowerWatts()

        guard result == KERN_SUCCESS, let info = processorInfo else {
            return CPUMetrics(
                status: .error(message: "Failed to query host_processor_info (kern result: \(result))"),
                powerWatts: sysPower,
                temperature: temp
            )
        }

        let count = Int(processorCount)
        var currentCoreTicks: [CoreTicks] = []
        currentCoreTicks.reserveCapacity(count)

        for i in 0..<count {
            let offset = i * Int(CPU_STATE_MAX)
            let user = UInt32(info[offset + Int(CPU_STATE_USER)])
            let system = UInt32(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt32(info[offset + Int(CPU_STATE_NICE)])
            currentCoreTicks.append(CoreTicks(user: user, system: system, idle: idle, nice: nice))
        }

        // Deallocate vm memory allocated by host_processor_info
        let vmSize = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vmSize)

        // Baseline initialization check
        guard !previousCoreTicks.isEmpty, previousCoreTicks.count == count else {
            previousCoreTicks = currentCoreTicks
            var coreLoads: [CoreLoad] = []
            for i in 0..<count {
                coreLoads.append(CoreLoad(id: i, userPercentage: 0, systemPercentage: 0, idlePercentage: 100))
            }
            return CPUMetrics(
                status: .available,
                totalUsagePercentage: 0.0,
                userPercentage: 0.0,
                systemPercentage: 0.0,
                idlePercentage: 100.0,
                physicalCores: count,
                logicalCores: count,
                coreLoads: coreLoads,
                efficiencyClusterPercentage: 0.0,
                performanceClusterPercentage: 0.0,
                powerWatts: sysPower,
                temperature: temp
            )
        }

        var totalUserDelta: UInt64 = 0
        var totalSystemDelta: UInt64 = 0
        var totalIdleDelta: UInt64 = 0
        var totalNiceDelta: UInt64 = 0
        var coreLoads: [CoreLoad] = []
        coreLoads.reserveCapacity(count)

        for i in 0..<count {
            let cur = currentCoreTicks[i]
            let prev = previousCoreTicks[i]

            let userDelta = UInt64(cur.user >= prev.user ? cur.user - prev.user : 0)
            let systemDelta = UInt64(cur.system >= prev.system ? cur.system - prev.system : 0)
            let idleDelta = UInt64(cur.idle >= prev.idle ? cur.idle - prev.idle : 0)
            let niceDelta = UInt64(cur.nice >= prev.nice ? cur.nice - prev.nice : 0)

            totalUserDelta += userDelta
            totalSystemDelta += systemDelta
            totalIdleDelta += idleDelta
            totalNiceDelta += niceDelta

            let coreTotal = userDelta + systemDelta + idleDelta + niceDelta
            if coreTotal > 0 {
                let uPct = (Double(userDelta + niceDelta) / Double(coreTotal)) * 100.0
                let sPct = (Double(systemDelta) / Double(coreTotal)) * 100.0
                let iPct = (Double(idleDelta) / Double(coreTotal)) * 100.0
                coreLoads.append(CoreLoad(id: i, userPercentage: uPct, systemPercentage: sPct, idlePercentage: iPct))
            } else {
                coreLoads.append(CoreLoad(id: i, userPercentage: 0, systemPercentage: 0, idlePercentage: 100))
            }
        }

        previousCoreTicks = currentCoreTicks

        let overallTotal = totalUserDelta + totalSystemDelta + totalIdleDelta + totalNiceDelta
        var userPct: Double = 0.0
        var sysPct: Double = 0.0
        var idlePct: Double = 100.0
        var totalUsage: Double = 0.0

        if overallTotal > 0 {
            userPct = (Double(totalUserDelta + totalNiceDelta) / Double(overallTotal)) * 100.0
            sysPct = (Double(totalSystemDelta) / Double(overallTotal)) * 100.0
            idlePct = (Double(totalIdleDelta) / Double(overallTotal)) * 100.0
            totalUsage = max(0.0, min(100.0, userPct + sysPct))
        }

        // Calculate Cluster Utilization for Apple Silicon (Efficiency & Performance)
        var eClusterPct: Double? = nil
        var pClusterPct: Double? = nil
        var pCoresCount: Int = 0
        var eCoresCount: Int = 0
        var pSize = MemoryLayout<Int>.size
        var eSize = MemoryLayout<Int>.size
        if sysctlbyname("hw.perflevel0.logicalcpu", &pCoresCount, &pSize, nil, 0) == 0 &&
           sysctlbyname("hw.perflevel1.logicalcpu", &eCoresCount, &eSize, nil, 0) == 0 {
            if eCoresCount > 0 && pCoresCount > 0 && (eCoresCount + pCoresCount == count) {
                // Efficiency cores occupy 0..<eCoresCount
                let eCores = coreLoads.prefix(eCoresCount)
                let pCores = coreLoads.suffix(pCoresCount)
                eClusterPct = eCores.map { $0.totalUsagePercentage }.reduce(0, +) / Double(eCoresCount)
                pClusterPct = pCores.map { $0.totalUsagePercentage }.reduce(0, +) / Double(pCoresCount)
            }
        }

        return CPUMetrics(
            status: .available,
            totalUsagePercentage: totalUsage,
            userPercentage: userPct,
            systemPercentage: sysPct,
            idlePercentage: idlePct,
            physicalCores: count,
            logicalCores: count,
            coreLoads: coreLoads,
            efficiencyClusterPercentage: eClusterPct,
            performanceClusterPercentage: pClusterPct,
            powerWatts: sysPower,
            temperature: temp
        )
    }
}

public typealias DefaultCPUMetricProvider = DarwinCPUMetricProvider

// MARK: - Darwin Memory Provider

public final class DarwinMemoryMetricProvider: MemoryMetricProvider, Sendable {
    public init() {}

    public func sampleMemory() -> MemoryMetrics {
        let totalBytes = ProcessInfo.processInfo.physicalMemory

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetrics(status: .error(message: "Failed to query host_statistics64 (kern result: \(result))"))
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let speculative = UInt64(vmStats.speculative_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let purgeable = UInt64(vmStats.purgeable_count) * pageSize
        let free = UInt64(vmStats.free_count) * pageSize

        // Apple Activity Monitor formula:
        // App Memory = active + speculative
        // Used = App Memory + wired + compressed
        let appMemory = active + speculative
        let used = appMemory + wired + compressed
        let available = totalBytes >= used ? totalBytes - used : free + purgeable
        let cachedFiles = purgeable

        // Swap usage via vm.swapusage
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapResult = sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
        let swapTotal = swapResult == 0 ? UInt64(swapUsage.xsu_total) : 0
        let swapUsed = swapResult == 0 ? UInt64(swapUsage.xsu_used) : 0

        // Memory pressure level via kern.memorystatus_vm_pressure_level
        var pressureInt: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        let pressureResult = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureInt, &pressureSize, nil, 0)
        let pressureLevel: MemoryPressureLevel
        if pressureResult == 0 {
            switch pressureInt {
            case 1: pressureLevel = .normal
            case 2: pressureLevel = .warning
            case 4: pressureLevel = .critical
            default: pressureLevel = .normal
            }
        } else {
            pressureLevel = .normal
        }

        return MemoryMetrics(
            status: .available,
            totalBytes: totalBytes,
            usedBytes: min(totalBytes, used),
            availableBytes: available,
            appMemoryBytes: appMemory,
            wiredBytes: wired,
            compressedBytes: compressed,
            cachedFilesBytes: cachedFiles,
            swapTotalBytes: swapTotal,
            swapUsedBytes: swapUsed,
            pressureLevel: pressureLevel
        )
    }
}

public typealias DefaultMemoryMetricProvider = DarwinMemoryMetricProvider

// MARK: - Darwin GPU Provider

public final class DarwinGPUMetricProvider: GPUMetricProvider, Sendable {
    public let temperatureProvider: TemperatureTelemetryProvider

    public init(temperatureProvider: TemperatureTelemetryProvider = DarwinTemperatureTelemetryProvider()) {
        self.temperatureProvider = temperatureProvider
    }

    public func sampleGPU() -> GPUMetrics {
        let temp = temperatureProvider.sampleGPUTemperature()

        guard let device = MTLCreateSystemDefaultDevice() else {
            return GPUMetrics(
                name: "Unknown GPU",
                isAppleSilicon: false,
                allocatedBytes: nil,
                recommendedMaxWorkingSetBytes: nil,
                utilization: .unavailable(reason: "No Metal default device available"),
                temperature: temp
            )
        }

        let name = device.name
        let isAppleSilicon = device.hasUnifiedMemory
        let allocated = UInt64(device.currentAllocatedSize)
        let maxWorkingSet = UInt64(device.recommendedMaxWorkingSetSize)

        // Query genuine GPU execution utilization via IOAccelerator PerformanceStatistics
        var deviceUtil: Double? = nil
        var rendUtil: Double? = nil
        var tilerUtil: Double? = nil
        var inUseBytes: UInt64? = nil

        let match = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS {
            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let p = props?.takeRetainedValue() as? [String: Any],
                   let stats = p["PerformanceStatistics"] as? [String: Any] {
                    if let dev = stats["Device Utilization %"] as? Int {
                        deviceUtil = Double(dev)
                    }
                    if let rend = stats["Renderer Utilization %"] as? Int {
                        rendUtil = Double(rend)
                    }
                    if let tiler = stats["Tiler Utilization %"] as? Int {
                        tilerUtil = Double(tiler)
                    }
                    if let inUse = stats["In use system memory"] as? UInt64 {
                        inUseBytes = inUse
                    }
                }
            }
        }

        let utilization: MetricValue<Double>
        if let devUtil = deviceUtil {
            utilization = .available(devUtil, unit: "%")
        } else {
            utilization = .unavailable(
                reason: "System-wide GPU execution engine utilization is restricted on macOS without private Apple Silicon entitlements"
            )
        }

        return GPUMetrics(
            name: name,
            isAppleSilicon: isAppleSilicon,
            allocatedBytes: allocated,
            inUseBytes: inUseBytes,
            recommendedMaxWorkingSetBytes: maxWorkingSet,
            utilization: utilization,
            rendererUtilization: rendUtil,
            tilerUtilization: tilerUtil,
            temperature: temp
        )
    }
}

public typealias DefaultGPUMetricProvider = DarwinGPUMetricProvider

// MARK: - Darwin Temperature Provider

public final class DarwinTemperatureTelemetryProvider: TemperatureTelemetryProvider, Sendable {
    public init() {}

    public func sampleTemperatures() -> TemperatureMetrics {
        let (cpuAvg, gpuAvg, battAvg, ambient, allReadings) = SMCTelemetryService.shared.readTemperatures()

        let cpuMetric: MetricValue<Double>
        if let c = cpuAvg {
            cpuMetric = .available(c, unit: "°C")
        } else {
            cpuMetric = .unavailable(reason: "CPU thermal sensors unavailable", unit: "°C")
        }

        let gpuMetric: MetricValue<Double>
        if let g = gpuAvg {
            gpuMetric = .available(g, unit: "°C")
        } else {
            gpuMetric = .unavailable(reason: "GPU thermal sensors unavailable", unit: "°C")
        }

        let battMetric: MetricValue<Double>
        if let b = battAvg {
            battMetric = .available(b, unit: "°C")
        } else {
            battMetric = .unavailable(reason: "Battery thermal sensor unavailable", unit: "°C")
        }

        let ambientMetric: MetricValue<Double>
        if let a = ambient {
            ambientMetric = .available(a, unit: "°C")
        } else {
            ambientMetric = .unavailable(reason: "Ambient thermal sensor unavailable", unit: "°C")
        }

        let sensorReadings = allReadings.map { r in
            TemperatureSensorReading(
                id: r.key,
                name: r.name,
                category: r.category.rawValue,
                celsius: r.celsius,
                status: .available
            )
        }

        let isAvail = cpuAvg != nil || gpuAvg != nil
        return TemperatureMetrics(
            status: isAvail ? .available : .unavailable(reason: "Hardware thermal sensors unavailable"),
            cpuTemperature: cpuMetric,
            gpuTemperature: gpuMetric,
            batteryTemperature: battMetric,
            ambientTemperature: ambientMetric,
            sensors: sensorReadings
        )
    }

    public func sampleCPUTemperature() -> MetricValue<Double> {
        sampleTemperatures().cpuTemperature
    }

    public func sampleGPUTemperature() -> MetricValue<Double> {
        sampleTemperatures().gpuTemperature
    }
}

public typealias DefaultTemperatureTelemetryProvider = DarwinTemperatureTelemetryProvider

// MARK: - Darwin Fan Telemetry Provider

public final class DarwinFanTelemetryProvider: FanTelemetryProvider, Sendable {
    public init() {}

    public func sampleFans() -> FanMetrics {
        // 1. Query genuine fan tachometers via SMCTelemetryService
        let smcFans = SMCTelemetryService.shared.readAllFans()
        if !smcFans.isEmpty {
            let readings = smcFans.map { f in
                FanReading(
                    id: f.id,
                    name: f.name,
                    rpm: f.currentRPM.map { Int($0.rounded()) },
                    minRPM: f.minRPM.map { Int($0.rounded()) },
                    maxRPM: f.maxRPM.map { Int($0.rounded()) },
                    status: f.currentRPM != nil ? .available : .unavailable(reason: "Reading failed")
                )
            }
            return FanMetrics(
                status: .available,
                fans: readings,
                fanCount: readings.count,
                isFanless: false
            )
        }

        // 2. Identify if this Mac is confirmed fanless (e.g. MacBook Air M1/M2/M3)
        var model = ""
        var modelSize: size_t = 0
        if sysctlbyname("hw.model", nil, &modelSize, nil, 0) == 0 && modelSize > 0 {
            var modelBuf = [CChar](repeating: 0, count: modelSize)
            if sysctlbyname("hw.model", &modelBuf, &modelSize, nil, 0) == 0 {
                model = String(cString: modelBuf)
            }
        }

        let fanlessModels = [
            "MacBookAir10,1", // M1 MacBook Air
            "Mac14,2",        // M2 MacBook Air (13-inch)
            "Mac14,15",       // M2 MacBook Air (15-inch)
            "Mac15,12",       // M3 MacBook Air (13-inch)
            "Mac15,13"        // M3 MacBook Air (15-inch)
        ]

        if fanlessModels.contains(model) || model.hasPrefix("MacBookAir") {
            return FanMetrics(
                status: .available,
                fans: [],
                fanCount: 0,
                isFanless: true
            )
        }

        return FanMetrics(
            status: .unavailable(reason: "Fan telemetry is not supported on this Mac"),
            fans: [],
            fanCount: 0,
            isFanless: false
        )
    }
}

public typealias DefaultFanTelemetryProvider = DarwinFanTelemetryProvider

// MARK: - Darwin Power Telemetry Provider

public final class DarwinPowerTelemetryProvider: PowerTelemetryProvider, Sendable {
    public init() {}

    public func samplePower() -> PowerMetrics {
        let systemWatts = SMCTelemetryService.shared.readSystemPowerWatts()

        var cycleCount: Int? = nil
        var healthPct: Int? = nil
        var isCharging = false
        var condition: String? = "Normal"

        let match = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS {
            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let p = props?.takeRetainedValue() as? [String: Any] {
                    if let c = p["CycleCount"] as? Int {
                        cycleCount = c
                    }
                    if let charging = p["IsCharging"] as? Bool {
                        isCharging = charging
                    }
                    if let cond = p["Condition"] as? String {
                        condition = cond
                    }
                    if let maxC = p["MaxCapacity"] as? Int, maxC > 0 {
                        healthPct = maxC
                    }
                }
            }
        }

        return PowerMetrics(
            status: .available,
            systemPowerWatts: systemWatts,
            batteryHealthPercentage: healthPct,
            batteryCycleCount: cycleCount,
            batteryCondition: condition,
            isCharging: isCharging
        )
    }
}

public typealias DefaultPowerTelemetryProvider = DarwinPowerTelemetryProvider

// MARK: - Darwin Storage Provider

public final class DarwinStorageMetricProvider: StorageMetricProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var lastDiskSampleDate: Date?
    private var lastTotalBytesRead: UInt64 = 0
    private var lastTotalBytesWritten: UInt64 = 0

    public init() {}

    public func sampleStorage() -> StorageMetrics {
        lock.lock()
        defer { lock.unlock() }

        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsRootFileSystemKey
        ]

        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var volumes: [VolumeMetrics] = []
        var primary: VolumeMetrics?
        var seenMounts = Set<String>()

        for url in paths {
            let mountPath = url.path
            guard !seenMounts.contains(mountPath) else { continue }
            seenMounts.insert(mountPath)

            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let name = values.volumeName ?? url.lastPathComponent
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            guard total > 0 else { continue }

            let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0))
            let isRemovable = values.volumeIsRemovable ?? false
            let isRoot = (values.volumeIsRootFileSystem ?? false) || mountPath == "/"

            let volume = VolumeMetrics(
                name: name,
                mountPoint: mountPath,
                totalBytes: total,
                freeBytes: free,
                isRemovable: isRemovable,
                isPrimary: isRoot
            )

            volumes.append(volume)
            if isRoot || (primary == nil && !isRemovable) {
                primary = volume
            }
        }

        // Sort so primary/startup volume is first, followed by internal mounts, then removable
        volumes.sort { a, b in
            if a.isPrimary != b.isPrimary { return a.isPrimary }
            if a.isRemovable != b.isRemovable { return !a.isRemovable }
            return a.name < b.name
        }

        // Query IOBlockStorageDriver for real-time Disk Throughput (Read & Write Bytes)
        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0

        let match = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS {
            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let p = props?.takeRetainedValue() as? [String: Any],
                   let stats = p["Statistics"] as? [String: Any] {
                    if let r = stats["Bytes (Read)"] as? UInt64 { totalRead += r }
                    if let w = stats["Bytes (Write)"] as? UInt64 { totalWritten += w }
                }
            }
        }

        let now = Date()
        var readBps: Double = 0.0
        var writeBps: Double = 0.0

        if let lastDate = lastDiskSampleDate {
            let elapsed = now.timeIntervalSince(lastDate)
            if elapsed > 0.05 {
                let deltaR = totalRead >= lastTotalBytesRead ? totalRead - lastTotalBytesRead : 0
                let deltaW = totalWritten >= lastTotalBytesWritten ? totalWritten - lastTotalBytesWritten : 0
                readBps = Double(deltaR) / elapsed
                writeBps = Double(deltaW) / elapsed
            }
        }

        lastDiskSampleDate = now
        lastTotalBytesRead = totalRead
        lastTotalBytesWritten = totalWritten

        return StorageMetrics(
            status: .available,
            primaryVolume: primary,
            allVolumes: volumes,
            readBytesPerSecond: readBps,
            writeBytesPerSecond: writeBps,
            totalBytesRead: totalRead,
            totalBytesWritten: totalWritten,
            timestamp: now
        )
    }
}

public typealias DefaultStorageMetricProvider = DarwinStorageMetricProvider

// MARK: - Darwin Network Provider

public final class DarwinNetworkMetricProvider: NetworkMetricProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var lastSampleDate: Date?
    private var lastTotalBytesIn: UInt64 = 0
    private var lastTotalBytesOut: UInt64 = 0

    public init() {}

    public func sampleNetwork() -> NetworkMetrics {
        lock.lock()
        defer { lock.unlock() }

        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else {
            return NetworkMetrics(status: .error(message: "Failed to call getifaddrs"))
        }
        defer { freeifaddrs(ifap) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var primaryName = "en0"

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let addr = current.pointee.ifa_addr
            let flags = Int32(current.pointee.ifa_flags)

            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            if isUp && !isLoopback && addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: current.pointee.ifa_name)
                if let data = current.pointee.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(ifData.ifi_ibytes)
                    totalOut += UInt64(ifData.ifi_obytes)
                    if name.hasPrefix("en") {
                        primaryName = name
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }

        let now = Date()
        var downloadBps: Double = 0.0
        var uploadBps: Double = 0.0

        if let lastDate = lastSampleDate {
            let elapsed = now.timeIntervalSince(lastDate)
            if elapsed > 0.05 {
                let deltaIn = totalIn >= lastTotalBytesIn ? totalIn - lastTotalBytesIn : 0
                let deltaOut = totalOut >= lastTotalBytesOut ? totalOut - lastTotalBytesOut : 0
                downloadBps = Double(deltaIn) / elapsed
                uploadBps = Double(deltaOut) / elapsed
            }
        }

        lastSampleDate = now
        lastTotalBytesIn = totalIn
        lastTotalBytesOut = totalOut

        return NetworkMetrics(
            status: .available,
            downloadBytesPerSecond: downloadBps,
            uploadBytesPerSecond: uploadBps,
            totalBytesReceived: totalIn,
            totalBytesSent: totalOut,
            activeInterfaceName: primaryName,
            timestamp: now
        )
    }
}

public typealias DefaultNetworkMetricProvider = DarwinNetworkMetricProvider

// MARK: - Darwin System Info Provider

public final class DarwinSystemInfoMetricProvider: SystemInfoMetricProvider, Sendable {
    public init() {}

    public func sampleSystemInfo() -> SystemInfoMetrics {
        // Chip name
        var chipName = "Apple Silicon"
        var size: size_t = 0
        if sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0 && size > 0 {
            var brand = [CChar](repeating: 0, count: size)
            if sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 {
                chipName = String(cString: brand).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Model identifier
        var model = "Mac"
        var modelSize: size_t = 0
        if sysctlbyname("hw.model", nil, &modelSize, nil, 0) == 0 && modelSize > 0 {
            var modelBuf = [CChar](repeating: 0, count: modelSize)
            if sysctlbyname("hw.model", &modelBuf, &modelSize, nil, 0) == 0 {
                model = String(cString: modelBuf).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // OS version
        let os = ProcessInfo.processInfo.operatingSystemVersionString

        // Uptime
        var boottime = timeval()
        var bootSize = MemoryLayout<timeval>.size
        var uptime: TimeInterval = 0
        if sysctlbyname("kern.boottime", &boottime, &bootSize, nil, 0) == 0 {
            let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
            uptime = max(0, Date().timeIntervalSince(bootDate))
        }

        // Thermal State
        let thermalState: ThermalStateLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = .nominal
        case .fair: thermalState = .fair
        case .serious: thermalState = .serious
        case .critical: thermalState = .critical
        @unknown default: thermalState = .unknown
        }

        return SystemInfoMetrics(
            chipName: chipName,
            modelIdentifier: model,
            osVersionString: os,
            uptimeSeconds: uptime,
            thermalState: thermalState
        )
    }
}

public typealias DefaultSystemInfoMetricProvider = DarwinSystemInfoMetricProvider
