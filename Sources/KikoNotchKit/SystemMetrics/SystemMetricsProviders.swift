import Foundation
import Metal
import Darwin

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

public typealias CPUMetricProviderProtocol = CPUMetricProvider
public typealias MemoryMetricProviderProtocol = MemoryMetricProvider
public typealias GPUMetricProviderProtocol = GPUMetricProvider
public typealias StorageMetricProviderProtocol = StorageMetricProvider
public typealias NetworkMetricProviderProtocol = NetworkMetricProvider
public typealias SystemInfoMetricProviderProtocol = SystemInfoMetricProvider

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
    
    public init() {}
    
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
        
        guard result == KERN_SUCCESS, let info = processorInfo else {
            return CPUMetrics(status: .error(message: "Failed to query host_processor_info (kern result: \(result))"))
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
        
        let infoSize = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), infoSize)
        
        let logicalCores = ProcessInfo.processInfo.processorCount
        let physicalCores = ProcessInfo.processInfo.activeProcessorCount
        
        // First sample establishes baseline ticks
        guard !previousCoreTicks.isEmpty, previousCoreTicks.count == currentCoreTicks.count else {
            previousCoreTicks = currentCoreTicks
            return CPUMetrics(
                status: .available,
                totalUsagePercentage: 0.0,
                userPercentage: 0.0,
                systemPercentage: 0.0,
                idlePercentage: 100.0,
                physicalCores: physicalCores,
                logicalCores: logicalCores,
                coreLoads: []
            )
        }
        
        var coreLoads: [CoreLoad] = []
        var totalUserDelta: Double = 0
        var totalSystemDelta: Double = 0
        var totalIdleDelta: Double = 0
        
        for i in 0..<count {
            let prev = previousCoreTicks[i]
            let curr = currentCoreTicks[i]
            
            let userDelta = Double(curr.user >= prev.user ? curr.user - prev.user : 0)
            let sysDelta = Double(curr.system >= prev.system ? curr.system - prev.system : 0)
            let idleDelta = Double(curr.idle >= prev.idle ? curr.idle - prev.idle : 0)
            let niceDelta = Double(curr.nice >= prev.nice ? curr.nice - prev.nice : 0)
            
            let combinedUserDelta = userDelta + niceDelta
            let coreTotal = combinedUserDelta + sysDelta + idleDelta
            
            let userPct = coreTotal > 0 ? (combinedUserDelta / coreTotal) * 100.0 : 0.0
            let sysPct = coreTotal > 0 ? (sysDelta / coreTotal) * 100.0 : 0.0
            let idlePct = coreTotal > 0 ? (idleDelta / coreTotal) * 100.0 : 100.0
            
            coreLoads.append(CoreLoad(id: i, userPercentage: userPct, systemPercentage: sysPct, idlePercentage: idlePct))
            
            totalUserDelta += combinedUserDelta
            totalSystemDelta += sysDelta
            totalIdleDelta += idleDelta
        }
        
        previousCoreTicks = currentCoreTicks
        
        let allDelta = totalUserDelta + totalSystemDelta + totalIdleDelta
        let overallUser = allDelta > 0 ? (totalUserDelta / allDelta) * 100.0 : 0.0
        let overallSys = allDelta > 0 ? (totalSystemDelta / allDelta) * 100.0 : 0.0
        let overallIdle = allDelta > 0 ? (totalIdleDelta / allDelta) * 100.0 : 100.0
        let overallUsage = min(100.0, overallUser + overallSys)
        
        return CPUMetrics(
            status: .available,
            totalUsagePercentage: overallUsage,
            userPercentage: overallUser,
            systemPercentage: overallSys,
            idlePercentage: overallIdle,
            physicalCores: physicalCores,
            logicalCores: logicalCores,
            coreLoads: coreLoads
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
        
        // Memory pressure level
        var pressureVal: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        let pressureResult = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureVal, &pressureSize, nil, 0)
        let pressureLevel: MemoryPressureLevel
        if pressureResult == 0 {
            switch pressureVal {
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
    public init() {}
    
    public func sampleGPU() -> GPUMetrics {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return GPUMetrics(
                name: "Unknown GPU",
                isAppleSilicon: false,
                allocatedBytes: nil,
                recommendedMaxWorkingSetBytes: nil,
                utilization: .unavailable(reason: "No Metal default device available")
            )
        }
        
        let name = device.name
        let isAppleSilicon = device.hasUnifiedMemory
        let allocated = UInt64(device.currentAllocatedSize)
        let maxWorkingSet = UInt64(device.recommendedMaxWorkingSetSize)
        
        // Transparent disclosure: GPU engine execution utilization requires private Apple Silicon entitlements on macOS.
        // We report strictly unavailable and never fabricate values.
        let utilization = MetricValue<Double>.unavailable(
            reason: "System-wide GPU execution engine utilization is restricted on macOS without private Apple Silicon entitlements"
        )
        
        return GPUMetrics(
            name: name,
            isAppleSilicon: isAppleSilicon,
            allocatedBytes: allocated,
            recommendedMaxWorkingSetBytes: maxWorkingSet,
            utilization: utilization
        )
    }
}

public typealias DefaultGPUMetricProvider = DarwinGPUMetricProvider

// MARK: - Darwin Storage Provider

public final class DarwinStorageMetricProvider: StorageMetricProvider, Sendable {
    public init() {}
    
    public func sampleStorage() -> StorageMetrics {
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
        
        for url in paths {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let name = values.volumeName ?? url.lastPathComponent
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            guard total > 0 else { continue }
            
            let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0))
            let isRemovable = values.volumeIsRemovable ?? false
            let isRoot = values.volumeIsRootFileSystem ?? false
            
            let volume = VolumeMetrics(
                name: name,
                mountPoint: url.path,
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
        
        return StorageMetrics(status: .available, primaryVolume: primary, allVolumes: volumes)
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
