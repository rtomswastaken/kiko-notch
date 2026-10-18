import XCTest
import AppKit
@testable import KikoNotchKit

final class SystemIntegrationTests: XCTestCase {
    
    // MARK: - Section 6: System HUD Tests
    
    func testAudioHUDMonitorQueries() {
        let monitor = AudioHUDMonitor.shared
        monitor.start()
        
        let exp = expectation(description: "Volume or output device change received")
        exp.assertForOverFulfill = false
        
        monitor.onVolumeChange = { vol, isMuted in
            XCTAssertGreaterThanOrEqual(vol, 0.0)
            XCTAssertLessThanOrEqual(vol, 1.0)
            exp.fulfill()
        }
        
        monitor.queryCurrentVolume()
        wait(for: [exp], timeout: 2.0)
        monitor.stop()
    }
    
private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

    func testBrightnessAndBacklightMonitors() {
        let brightnessMonitor = BrightnessHUDMonitor.shared
        let backlightMonitor = KeyboardBacklightMonitor.shared
        
        let receivedBrightness = TestBox<Float?>(nil)
        brightnessMonitor.onBrightnessChange = { val in
            receivedBrightness.value = val
        }
        brightnessMonitor.setSimulatedBrightness(0.75)
        XCTAssertEqual(receivedBrightness.value, 0.75)
        
        let receivedBacklight = TestBox<Float?>(nil)
        backlightMonitor.onBacklightChange = { val in
            receivedBacklight.value = val
        }
        backlightMonitor.setSimulatedBacklight(0.40)
        XCTAssertEqual(receivedBacklight.value, 0.40)
    }
    
    // MARK: - Section 7: Battery and Bluetooth Tests
    
    func testBatteryMonitorState() {
        let monitor = BatteryMonitor.shared
        let receivedState = TestBox<BatteryState?>(nil)
        
        monitor.onBatteryChange = { state in
            receivedState.value = state
        }
        monitor.updateBatteryState()
        
        XCTAssertNotNil(receivedState.value)
        if receivedState.value!.hasBattery {
            XCTAssertGreaterThanOrEqual(receivedState.value!.percentage, 0)
            XCTAssertLessThanOrEqual(receivedState.value!.percentage, 100)
        } else {
            // Desktop Mac behavior (honest state)
            XCTAssertTrue(receivedState.value!.isPluggedIn)
        }
    }
    
    func testBluetoothMonitorRefresh() {
        let monitor = BluetoothMonitor.shared
        let receivedList = TestBox<[BluetoothPeripheral]?>(nil)
        
        monitor.onDevicesUpdated = { list in
            receivedList.value = list
        }
        monitor.refreshConnectedDevices()
        
        XCTAssertNotNil(receivedList.value)
    }
    
    // MARK: - Section 8: Calendar and Productivity Tests
    
    @MainActor
    func testCalendarServiceCountdown() {
        let now = Date()
        let inFifteenMin = now.addingTimeInterval(15 * 60)
        let later = inFifteenMin.addingTimeInterval(30 * 60)
        
        let event = CalendarEventItem(
            id: "test-event",
            title: "Sprint Planning",
            startDate: inFifteenMin,
            endDate: later,
            isAllDay: false
        )
        
        XCTAssertTrue(event.countdownDescription.contains("In 15m") || event.countdownDescription.contains("In 14m"))
    }
    
    // MARK: - Section 9: Notifications & Focus Mode Tests
    
    @MainActor
    func testNotificationManagerFocusModeSuppression() {
        let manager = NotificationManager.shared
        manager.setFocusModeActive(true)
        
        // Non-critical banner should be suppressed
        let nonCritical = IslandBannerItem(title: "Info", systemImage: "info.circle", isCritical: false)
        manager.postIslandBanner(nonCritical)
        XCTAssertNil(manager.activeBanner)
        
        // Critical banner must break through focus mode
        let critical = IslandBannerItem(title: "Battery 10%", systemImage: "battery.25", isCritical: true)
        manager.postIslandBanner(critical)
        XCTAssertEqual(manager.activeBanner?.title, "Battery 10%")
        
        manager.dismissActiveBanner()
        manager.setFocusModeActive(false)
    }
    
    // MARK: - Section 10: Weather Tests
    
    @MainActor
    func testWeatherServiceUnitConversion() {
        let service = WeatherService.shared
        service.unit = .celsius
        XCTAssertEqual(service.formattedTemperature(20.0), "20°C")
        
        service.unit = .fahrenheit
        XCTAssertEqual(service.formattedTemperature(20.0), "68°F")
    }
    
    // MARK: - Section 12: Download Monitoring Tests
    
    func testDownloadItemSpeedCalculation() {
        let item = DownloadItem(
            filename: "xcode.xip.crdownload",
            targetFilename: "xcode.xip",
            path: "/Users/test/Downloads/xcode.xip.crdownload",
            state: .active,
            bytesDownloaded: 50_000_000,
            speedBytesPerSecond: 2_500_000
        )
        
        XCTAssertEqual(item.formattedSpeed, "2.4 MB/s")
    }
    
    // MARK: - Section 13: Clipboard Tests
    
    @MainActor
    func testClipboardManagerChangeTracking() {
        let manager = ClipboardManager.shared
        let pasteboard = NSPasteboard.general
        
        let uniqueText = "KikoTestString-\(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(uniqueText, forType: .string)
        
        manager.checkForChanges()
        XCTAssertTrue(manager.items.contains(where: { $0.text == uniqueText }))
        
        // Clean up
        manager.clearAllHistory()
        XCTAssertTrue(manager.items.isEmpty)
    }
    
    // MARK: - Section 19: Extensions & Fault Isolation Tests
    
    @MainActor
    private final class MockCrashingModule: KikoModule {
        let id: KikoFeatureID = .customActions
        let displayName: String = "Crashing Module"
        var isEnabled: Bool = true
        var didStart: Bool = false
        var didStop: Bool = false
        
        func start() {
            didStart = true
        }
        
        func stop() {
            didStop = true
        }
        
        func performDangerousAction() throws {
            struct FatalModuleError: Error {}
            throw FatalModuleError()
        }
    }
    
    @MainActor
    func testExtensionManagerCrashProtection() {
        let registry = FeatureRegistry.shared
        let extManager = ExtensionManager.shared
        
        let mock = MockCrashingModule()
        registry.register(mock)
        
        // Execute throwing action on module
        extManager.safelyExecute(id: mock.id) { mod in
            guard let m = mod as? MockCrashingModule else { return }
            try m.performDangerousAction()
        }
        
        // Module must be safely deactivated without crashing the app
        XCTAssertNotNil(extManager.deactivatedModules[mock.id])
        XCTAssertFalse(mock.isEnabled)
        XCTAssertTrue(mock.didStop)
        
        registry.unregister(mock.id)
    }
    
    // MARK: - Section 20: Update Manager Tests
    
    @MainActor
    func testUpdateManagerChannelSettings() {
        let manager = UpdateManager.shared
        manager.channel = .stable
        XCTAssertEqual(manager.channel, .stable)
        
        manager.channel = .beta
        XCTAssertEqual(manager.channel, .beta)
    }
}
