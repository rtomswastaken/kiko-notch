import Foundation
import IOKit.ps

/// Battery info model
public struct BatteryState: Sendable, Equatable {
    public let hasBattery: Bool
    public let percentage: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let timeRemainingMinutes: Int?
    public let isLowBattery: Bool

    public var powerSource: String {
        if !hasBattery {
            return "AC Power"
        }
        if isCharging {
            return "Charging"
        }
        if isPluggedIn {
            return "Power Adapter"
        }
        return "Battery"
    }

    public static let unavailable = BatteryState(
        hasBattery: false,
        percentage: 0,
        isCharging: false,
        isPluggedIn: true,
        timeRemainingMinutes: nil,
        isLowBattery: false
    )
}

/// Event-driven battery monitor using IOPowerSources.
/// Implements BATT-001, BATT-002, BATT-003, and PERF-003.
public final class BatteryMonitor: ObservableObject, @unchecked Sendable {
    public static let shared = BatteryMonitor()

    @Published public private(set) var currentState: BatteryState = .unavailable
    public var onBatteryChange: (@Sendable (BatteryState) -> Void)?
    public var onLowBatteryAlert: (@Sendable (Int) -> Void)?

    public var lowBatteryThreshold: Int = 20
    private var runLoopSource: CFRunLoopSource?
    private var isMonitoring: Bool = false
    private var lastAlertedPercentage: Int? = nil

    public init() {
        start()
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let loopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.updateBatteryState()
        }, context).takeRetainedValue()

        self.runLoopSource = loopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)

        // Initial state query
        updateBatteryState()
    }

    public func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = nil
        }
    }

    public func updateBatteryState() {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]

        guard let sources = sources, !sources.isEmpty else {
            onBatteryChange?(.unavailable)
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Verify source is internal battery
            let isPresent = desc[kIOPSIsPresentKey] as? Bool ?? false
            guard isPresent else { continue }

            let currentCap = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let percentage = maxCap > 0 ? Int((Double(currentCap) / Double(maxCap)) * 100.0) : currentCap

            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let powerSourceState = desc[kIOPSPowerSourceStateKey] as? String
            let isPluggedIn = powerSourceState == kIOPSACPowerValue

            let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int
            let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int

            let timeRemaining: Int?
            if isCharging {
                timeRemaining = (timeToFull != nil && timeToFull! >= 0) ? timeToFull : nil
            } else {
                timeRemaining = (timeToEmpty != nil && timeToEmpty! >= 0) ? timeToEmpty : nil
            }

            let isLow = (!isPluggedIn && percentage <= lowBatteryThreshold)

            let state = BatteryState(
                hasBattery: true,
                percentage: percentage,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                timeRemainingMinutes: timeRemaining,
                isLowBattery: isLow
            )

            DispatchQueue.main.async { [weak self] in
                self?.currentState = state
            }
            onBatteryChange?(state)

            // Check low battery alert (BATT-003)
            if isLow && lastAlertedPercentage != percentage {
                lastAlertedPercentage = percentage
                onLowBatteryAlert?(percentage)
            } else if !isLow {
                lastAlertedPercentage = nil
            }

            return
        }

        // No battery found (e.g. Mac Studio, Mac mini)
        DispatchQueue.main.async { [weak self] in
            self?.currentState = .unavailable
        }
        onBatteryChange?(.unavailable)
    }

    /// Test helper to simulate battery states in headless or desktop environments
    public func setSimulatedState(_ state: BatteryState) {
        DispatchQueue.main.async { [weak self] in
            self?.currentState = state
        }
        onBatteryChange?(state)
        if state.isLowBattery {
            onLowBatteryAlert?(state.percentage)
        }
    }
}
