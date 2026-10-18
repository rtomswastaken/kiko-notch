import XCTest
@testable import KikoNotchKit

private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

final class BatteryAndSensorsTests: XCTestCase {
    
    // MARK: - Battery Monitor Tests (BATT-001, BATT-002, BATT-003)
    
    func testBatteryStateAvailable() {
        let state = BatteryState(
            hasBattery: true,
            percentage: 85,
            isCharging: true,
            isPluggedIn: true,
            timeRemainingMinutes: 45,
            isLowBattery: false
        )
        
        XCTAssertTrue(state.hasBattery)
        XCTAssertEqual(state.percentage, 85)
        XCTAssertTrue(state.isCharging)
        XCTAssertTrue(state.isPluggedIn)
        XCTAssertEqual(state.timeRemainingMinutes, 45)
        XCTAssertFalse(state.isLowBattery)
    }
    
    func testBatteryStateUnavailableOnDesktops() {
        let unavailable = BatteryState.unavailable
        XCTAssertFalse(unavailable.hasBattery)
        XCTAssertEqual(unavailable.percentage, 0)
        XCTAssertFalse(unavailable.isCharging)
        XCTAssertTrue(unavailable.isPluggedIn)
        XCTAssertNil(unavailable.timeRemainingMinutes)
        XCTAssertFalse(unavailable.isLowBattery)
    }
    
    func testBatteryMonitorSimulationAndLowBatteryAlert() {
        let monitor = BatteryMonitor()
        monitor.lowBatteryThreshold = 20
        
        let receivedState = TestBox<BatteryState?>(nil)
        let alertPercentage = TestBox<Int?>(nil)
        
        monitor.onBatteryChange = { state in
            receivedState.value = state
        }
        monitor.onLowBatteryAlert = { pct in
            alertPercentage.value = pct
        }
        
        // 1. Simulate normal battery
        let normalState = BatteryState(
            hasBattery: true,
            percentage: 75,
            isCharging: false,
            isPluggedIn: false,
            timeRemainingMinutes: 180,
            isLowBattery: false
        )
        monitor.setSimulatedState(normalState)
        XCTAssertEqual(receivedState.value?.percentage, 75)
        XCTAssertNil(alertPercentage.value)
        
        // 2. Simulate low battery threshold crossing
        let lowState = BatteryState(
            hasBattery: true,
            percentage: 15,
            isCharging: false,
            isPluggedIn: false,
            timeRemainingMinutes: 25,
            isLowBattery: true
        )
        monitor.setSimulatedState(lowState)
        XCTAssertEqual(receivedState.value?.percentage, 15)
        XCTAssertEqual(alertPercentage.value, 15)
    }
    
    // MARK: - Bluetooth Monitor Tests (BT-001, BT-002)
    
    func testBluetoothPeripheralModel() {
        let dev = BluetoothPeripheral(id: "AA:BB:CC:DD", name: "AirPods Pro", isConnected: true, batteryLevel: 90)
        XCTAssertEqual(dev.id, "AA:BB:CC:DD")
        XCTAssertEqual(dev.name, "AirPods Pro")
        XCTAssertTrue(dev.isConnected)
        XCTAssertEqual(dev.batteryLevel, 90)
    }
    
    func testBluetoothMonitorSimulation() {
        let monitor = BluetoothMonitor()
        let updatedList = TestBox<[BluetoothPeripheral]>([])
        let connectionEvents = TestBox<[(name: String, isConnected: Bool, battery: Int?)]>([])
        
        monitor.onDevicesUpdated = { list in
            updatedList.value = list
        }
        monitor.onDeviceConnectionChanged = { name, connected, battery in
            connectionEvents.value.append((name, connected, battery))
        }
        
        let devs = [
            BluetoothPeripheral(id: "1", name: "Magic Keyboard", isConnected: true, batteryLevel: 80),
            BluetoothPeripheral(id: "2", name: "Magic Mouse", isConnected: true, batteryLevel: 65)
        ]
        
        monitor.setSimulatedDevices(devs)
        XCTAssertEqual(updatedList.value.count, 2)
        XCTAssertEqual(updatedList.value.first?.name, "Magic Keyboard")
        
        monitor.simulateDeviceEvent(name: "AirPods Max", isConnected: true, batteryLevel: 95)
        XCTAssertEqual(connectionEvents.value.count, 1)
        XCTAssertEqual(connectionEvents.value.first?.name, "AirPods Max")
        XCTAssertTrue(connectionEvents.value.first?.isConnected ?? false)
    }
    
    // MARK: - System HUD Monitors & Coordinator Tests (SYS-001 through SYS-005)
    
    func testAudioHUDMonitorSimulation() {
        let monitor = AudioHUDMonitor()
        let reportedVolume = TestBox<Float?>(nil)
        let reportedMute = TestBox<Bool?>(nil)
        
        monitor.onVolumeChange = { vol, mute in
            reportedVolume.value = vol
            reportedMute.value = mute
        }
        
        monitor.onVolumeChange?(0.65, false)
        XCTAssertEqual(reportedVolume.value, 0.65)
        XCTAssertEqual(reportedMute.value, false)
        
        monitor.onVolumeChange?(0.0, true)
        XCTAssertEqual(reportedMute.value, true)
    }
    
    func testBrightnessAndBacklightMonitors() {
        let brightMonitor = BrightnessHUDMonitor()
        let brightLevel = TestBox<Float?>(nil)
        brightMonitor.onBrightnessChange = { level in
            brightLevel.value = level
        }
        brightMonitor.setSimulatedBrightness(0.8)
        XCTAssertEqual(brightLevel.value, 0.8)
        
        let kbdMonitor = KeyboardBacklightMonitor()
        let kbdLevel = TestBox<Float?>(nil)
        kbdMonitor.onBacklightChange = { level in
            kbdLevel.value = level
        }
        kbdMonitor.setSimulatedBacklight(0.4)
        XCTAssertEqual(kbdLevel.value, 0.4)
    }
    
    @MainActor
    func testSystemHUDManagerCoordination() {
        let manager = SystemHUDManager()
        manager.displayDuration = 0.5
        
        manager.presentEvent(.volume(level: 0.75, isMuted: false))
        XCTAssertEqual(manager.activeEvent, .volume(level: 0.75, isMuted: false))
        
        manager.dismissActiveHUD()
        XCTAssertNil(manager.activeEvent)
        
        manager.presentEvent(.audioOutputChanged(deviceName: "External Headphones"))
        XCTAssertEqual(manager.activeEvent, .audioOutputChanged(deviceName: "External Headphones"))
    }
}
