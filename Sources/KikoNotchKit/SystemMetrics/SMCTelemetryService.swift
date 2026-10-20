import Foundation
import IOKit

/// Read-only System Management Controller (SMC) telemetry service.
/// Provides genuine hardware sensor readings (fans, temperatures, power draw) on macOS and Apple Silicon.
/// Complies with zero-privilege user-space operation via IOConnectCallStructMethod.
public final class SMCTelemetryService: @unchecked Sendable {
    public static let shared = SMCTelemetryService()
    
    // MARK: - SMC Data Structures (80-byte AppleSMC kernel interface)
    
    public struct SMCParamStruct {
        public struct SMCVersion {
            var major: UInt8 = 0
            var minor: UInt8 = 0
            var build: UInt8 = 0
            var reserved: UInt8 = 0
            var release: UInt16 = 0
        }
        public struct SMCPLimitData {
            var version: UInt16 = 0
            var length: UInt16 = 0
            var cpuPLimit: UInt32 = 0
            var gpuPLimit: UInt32 = 0
            var memPLimit: UInt32 = 0
        }
        public struct SMCKeyInfo {
            var dataSize: UInt32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
        }

        public var key: UInt32 = 0
        public var version: SMCVersion = SMCVersion()
        public var pLimitData: SMCPLimitData = SMCPLimitData()
        public var keyInfo: SMCKeyInfo = SMCKeyInfo()
        public var padding: UInt16 = 0
        public var result: UInt8 = 0
        public var status: UInt8 = 0
        public var data8: UInt8 = 0
        public var data32: UInt32 = 0
        public var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private let lock = NSLock()
    private var connection: io_connect_t = 0
    private var isConnected: Bool = false
    
    public init() {
        openConnection()
    }
    
    deinit {
        closeConnection()
    }
    
    // MARK: - Connection Management
    
    private func openConnection() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            isConnected = false
            return
        }
        defer { IOObjectRelease(service) }
        
        var conn: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
        if result == KERN_SUCCESS {
            connection = conn
            isConnected = true
        } else {
            isConnected = false
        }
    }
    
    private func closeConnection() {
        if isConnected && connection != 0 {
            IOServiceClose(connection)
            connection = 0
            isConnected = false
        }
    }
    
    // MARK: - FourCharCode Helpers
    
    public static func fourCharCode(_ str: String) -> UInt32 {
        var res: UInt32 = 0
        for c in str.utf8.prefix(4) {
            res = (res << 8) | UInt32(c)
        }
        return res
    }

    public static func stringFromFourCharCode(_ code: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
    
    // MARK: - Low-level Read Operations (Read-Only)
    
    private func callSMC(input: inout SMCParamStruct) -> kern_return_t {
        guard isConnected, connection != 0 else { return KERN_FAILURE }
        var output = SMCParamStruct()
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let kr = IOConnectCallStructMethod(connection, 2, &input, inputSize, &output, &outputSize)
        input = output
        return kr
    }
    
    public func readKeyRaw(keyStr: String) -> (type: String, bytes: [UInt8])? {
        lock.lock()
        defer { lock.unlock() }
        
        if !isConnected {
            openConnection()
            guard isConnected else { return nil }
        }
        
        var input = SMCParamStruct()
        input.key = Self.fourCharCode(keyStr)
        input.data8 = 9 // kSMCGetKeyInfo
        var kr = callSMC(input: &input)
        guard kr == KERN_SUCCESS && input.result == 0 else { return nil }
        
        let info = input.keyInfo
        guard info.dataSize > 0 && info.dataSize <= 32 else { return nil }
        
        input = SMCParamStruct()
        input.key = Self.fourCharCode(keyStr)
        input.keyInfo.dataSize = info.dataSize
        input.data8 = 5 // kSMCReadKey
        kr = callSMC(input: &input)
        guard kr == KERN_SUCCESS && input.result == 0 else { return nil }
        
        let rawBytes: [UInt8] = withUnsafeBytes(of: input.bytes) { Array($0.prefix(Int(info.dataSize))) }
        return (Self.stringFromFourCharCode(info.dataType), rawBytes)
    }
    
    public func readNumericKey(_ keyStr: String) -> Double? {
        guard let (type, bytes) = readKeyRaw(keyStr: keyStr) else { return nil }
        return parseNumeric(type: type, bytes: bytes)
    }
    
    public func parseNumeric(type: String, bytes: [UInt8]) -> Double? {
        switch type.trimmingCharacters(in: .whitespaces) {
        case "flt":
            guard bytes.count >= 4 else { return nil }
            let val = bytes.withUnsafeBytes { $0.load(as: Float.self) }
            return val.isFinite ? Double(val) : nil
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = (Int16(bytes[0]) << 8) | Int16(bytes[1])
            return Double(raw) / 256.0
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        case "ui8":
            guard let b = bytes.first else { return nil }
            return Double(b)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            let val = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            return Double(val)
        default:
            return nil
        }
    }
    
    // MARK: - Fan Telemetry
    
    public struct FanTelemetryData: Sendable {
        public let id: Int
        public let name: String
        public let currentRPM: Double?
        public let minRPM: Double?
        public let maxRPM: Double?
    }
    
    public func getFanCount() -> Int {
        if let count = readNumericKey("FNum") {
            return Int(count)
        }
        return 0
    }
    
    public func readAllFans() -> [FanTelemetryData] {
        let count = getFanCount()
        guard count > 0 else { return [] }
        
        var results: [FanTelemetryData] = []
        for i in 0..<count {
            let cur = readNumericKey("F\(i)Ac")
            let minR = readNumericKey("F\(i)Mn")
            let maxR = readNumericKey("F\(i)Mx")
            
            let fanName: String
            if count == 1 {
                fanName = "System Fan"
            } else if count == 2 {
                fanName = i == 0 ? "Left Fan" : "Right Fan"
            } else {
                fanName = "Fan \(i + 1)"
            }
            
            results.append(FanTelemetryData(
                id: i,
                name: fanName,
                currentRPM: cur,
                minRPM: minR,
                maxRPM: maxR
            ))
        }
        return results
    }
    
    // MARK: - Temperature Telemetry
    
    public struct ThermalReadingData: Sendable {
        public let key: String
        public let name: String
        public let celsius: Double
        public let category: TemperatureCategory
    }
    
    public enum TemperatureCategory: String, Sendable {
        case cpu = "CPU"
        case gpu = "GPU"
        case battery = "Battery"
        case ambient = "Ambient"
        case other = "Other"
    }
    
    /// Reads representative hardware temperatures on Apple Silicon and Intel Macs
    public func readTemperatures() -> (cpuAvg: Double?, gpuAvg: Double?, batteryAvg: Double?, ambient: Double?, all: [ThermalReadingData]) {
        var readings: [ThermalReadingData] = []
        
        // 1. CPU Core / Cluster Keys (Apple Silicon M1/M2/M3 & Intel)
        let cpuKeys = [
            ("TC10", "CPU Cluster 1 Core 0"),
            ("TC11", "CPU Cluster 1 Core 1"),
            ("TC12", "CPU Cluster 1 Core 2"),
            ("TC13", "CPU Cluster 1 Core 3"),
            ("TC20", "CPU Cluster 2 Core 0"),
            ("TC21", "CPU Cluster 2 Core 1"),
            ("TC22", "CPU Cluster 2 Core 2"),
            ("TC23", "CPU Cluster 2 Core 3"),
            ("TC30", "CPU Cluster 3 Core 0"),
            ("TC31", "CPU Cluster 3 Core 1"),
            ("TC0P", "CPU Proximity"),
            ("TC0D", "CPU Die")
        ]
        var cpuTemps: [Double] = []
        for (k, name) in cpuKeys {
            if let t = readNumericKey(k), t > 10.0, t < 125.0 {
                cpuTemps.append(t)
                readings.append(ThermalReadingData(key: k, name: name, celsius: t, category: .cpu))
            }
        }
        let cpuAvg = cpuTemps.isEmpty ? nil : (cpuTemps.reduce(0, +) / Double(cpuTemps.count))
        
        // 2. GPU Core / Die Keys
        let gpuKeys = [
            ("Tg04", "GPU Die 1"),
            ("Tg05", "GPU Die 2"),
            ("Tg0C", "GPU Cluster 1"),
            ("Tg0D", "GPU Cluster 2"),
            ("TG0D", "GPU Die"),
            ("TG0P", "GPU Proximity")
        ]
        var gpuTemps: [Double] = []
        for (k, name) in gpuKeys {
            if let t = readNumericKey(k), t > 10.0, t < 125.0 {
                gpuTemps.append(t)
                readings.append(ThermalReadingData(key: k, name: name, celsius: t, category: .gpu))
            }
        }
        let gpuAvg = gpuTemps.isEmpty ? nil : (gpuTemps.reduce(0, +) / Double(gpuTemps.count))
        
        // 3. Battery Keys
        let battKeys = [
            ("TB0T", "Battery Point 1"),
            ("TB1T", "Battery Point 2"),
            ("TB2T", "Battery Point 3")
        ]
        var battTemps: [Double] = []
        for (k, name) in battKeys {
            if let t = readNumericKey(k), t > 5.0, t < 80.0 {
                battTemps.append(t)
                readings.append(ThermalReadingData(key: k, name: name, celsius: t, category: .battery))
            }
        }
        let battAvg = battTemps.isEmpty ? nil : (battTemps.reduce(0, +) / Double(battTemps.count))
        
        // 4. Ambient / Airflow
        let ambient = readNumericKey("TAOL") ?? readNumericKey("TA0P")
        if let amb = ambient, amb > 5.0, amb < 70.0 {
            readings.append(ThermalReadingData(key: "TAOL", name: "Ambient Airflow", celsius: amb, category: .ambient))
        }
        
        return (cpuAvg, gpuAvg, battAvg, ambient, readings)
    }
    
    // MARK: - Power Telemetry
    
    public func readSystemPowerWatts() -> Double? {
        if let p = readNumericKey("PSTR"), p >= 0.0, p < 500.0 {
            return p
        }
        return nil
    }
}
