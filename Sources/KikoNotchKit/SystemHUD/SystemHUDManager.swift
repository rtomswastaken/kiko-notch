import Foundation
import Combine
import SwiftUI

/// Central coordinator for system HUD events and transient Island indicators.
/// Implements SYS-001 through SYS-005.
@MainActor
public final class SystemHUDManager: ObservableObject {
    public static let shared = SystemHUDManager()
    
    @Published public private(set) var activeEvent: SystemHUDEvent?
    @Published public var displayDuration: Double = 1.8 {
        didSet { UserDefaults.standard.set(displayDuration, forKey: "kiko.hud.duration") }
    }
    
    // Per-event enable/disable settings
    @Published public var isVolumeEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isVolumeEnabled, forKey: "kiko.hud.volumeEnabled") }
    }
    @Published public var isBrightnessEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isBrightnessEnabled, forKey: "kiko.hud.brightnessEnabled") }
    }
    @Published public var isBacklightEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isBacklightEnabled, forKey: "kiko.hud.backlightEnabled") }
    }
    @Published public var isAudioRouteEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isAudioRouteEnabled, forKey: "kiko.hud.audioRouteEnabled") }
    }
    @Published public var isBatteryEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isBatteryEnabled, forKey: "kiko.hud.batteryEnabled") }
    }
    @Published public var isBluetoothEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isBluetoothEnabled, forKey: "kiko.hud.bluetoothEnabled") }
    }
    @Published public var isDownloadsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isDownloadsEnabled, forKey: "kiko.hud.downloadsEnabled") }
    }
    
    private var dismissTimer: Timer?
    private var isStarted: Bool = false
    
    public init() {
        loadSettings()
    }
    
    public func loadSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "kiko.hud.duration") != nil {
            self.displayDuration = defaults.double(forKey: "kiko.hud.duration")
        }
        if defaults.object(forKey: "kiko.hud.volumeEnabled") != nil {
            self.isVolumeEnabled = defaults.bool(forKey: "kiko.hud.volumeEnabled")
        }
        if defaults.object(forKey: "kiko.hud.brightnessEnabled") != nil {
            self.isBrightnessEnabled = defaults.bool(forKey: "kiko.hud.brightnessEnabled")
        }
        if defaults.object(forKey: "kiko.hud.backlightEnabled") != nil {
            self.isBacklightEnabled = defaults.bool(forKey: "kiko.hud.backlightEnabled")
        }
        if defaults.object(forKey: "kiko.hud.audioRouteEnabled") != nil {
            self.isAudioRouteEnabled = defaults.bool(forKey: "kiko.hud.audioRouteEnabled")
        }
        if defaults.object(forKey: "kiko.hud.batteryEnabled") != nil {
            self.isBatteryEnabled = defaults.bool(forKey: "kiko.hud.batteryEnabled")
        }
        if defaults.object(forKey: "kiko.hud.bluetoothEnabled") != nil {
            self.isBluetoothEnabled = defaults.bool(forKey: "kiko.hud.bluetoothEnabled")
        }
        if defaults.object(forKey: "kiko.hud.downloadsEnabled") != nil {
            self.isDownloadsEnabled = defaults.bool(forKey: "kiko.hud.downloadsEnabled")
        }
    }
    
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        
        // Wire AudioHUDMonitor
        AudioHUDMonitor.shared.onVolumeChange = { [weak self] level, isMuted in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVolumeEnabled else { return }
                self.presentEvent(.volume(level: level, isMuted: isMuted))
            }
        }
        
        AudioHUDMonitor.shared.onOutputDeviceChange = { [weak self] deviceName in
            Task { @MainActor [weak self] in
                guard let self = self, self.isAudioRouteEnabled else { return }
                self.presentEvent(.audioOutputChanged(deviceName: deviceName))
            }
        }
        AudioHUDMonitor.shared.start()
        
        // Wire BrightnessHUDMonitor
        BrightnessHUDMonitor.shared.onBrightnessChange = { [weak self] level in
            Task { @MainActor [weak self] in
                guard let self = self, self.isBrightnessEnabled else { return }
                self.presentEvent(.brightness(level: level))
            }
        }
        BrightnessHUDMonitor.shared.start()
        
        // Wire KeyboardBacklightMonitor
        KeyboardBacklightMonitor.shared.onBacklightChange = { [weak self] level in
            Task { @MainActor [weak self] in
                guard let self = self, self.isBacklightEnabled else { return }
                self.presentEvent(.keyboardBacklight(level: level))
            }
        }
        KeyboardBacklightMonitor.shared.start()
        
        // Wire BatteryMonitor
        BatteryMonitor.shared.onBatteryChange = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self, self.isBatteryEnabled, state.hasBattery else { return }
                self.presentEvent(.batteryStatus(
                    percentage: state.percentage,
                    isCharging: state.isCharging,
                    timeRemainingMinutes: state.timeRemainingMinutes
                ))
            }
        }
        BatteryMonitor.shared.onLowBatteryAlert = { percentage in
            Task { @MainActor in
                NotificationManager.shared.postIslandBanner(IslandBannerItem(
                    title: "Low Battery Warning",
                    subtitle: "\(percentage)% remaining. Connect power source.",
                    systemImage: "battery.25",
                    isCritical: true
                ))
            }
        }
        BatteryMonitor.shared.start()
        
        // Wire BluetoothMonitor
        BluetoothMonitor.shared.onDeviceConnectionChanged = { [weak self] name, isConnected, battery in
            Task { @MainActor [weak self] in
                guard let self = self, self.isBluetoothEnabled else { return }
                self.presentEvent(.bluetoothDevice(name: name, isConnected: isConnected, batteryLevel: battery))
            }
        }
        BluetoothMonitor.shared.start()
        
        // Wire DownloadMonitor
        DownloadMonitor.shared.onDownloadCompleted = { [weak self] item in
            Task { @MainActor [weak self] in
                guard let self = self, self.isDownloadsEnabled else { return }
                self.presentEvent(.downloadProgress(filename: item.targetFilename, progress: 1.0, isComplete: true))
                
                NotificationManager.shared.postIslandBanner(IslandBannerItem(
                    title: "Download Finished",
                    subtitle: item.targetFilename,
                    systemImage: "arrow.down.circle.fill",
                    isCritical: false
                ))
            }
        }
        DownloadMonitor.shared.start()
    }
    
    public func stop() {
        guard isStarted else { return }
        isStarted = false
        
        AudioHUDMonitor.shared.stop()
        BrightnessHUDMonitor.shared.stop()
        KeyboardBacklightMonitor.shared.stop()
        BatteryMonitor.shared.stop()
        BluetoothMonitor.shared.stop()
        DownloadMonitor.shared.stop()
        
        dismissActiveHUD()
    }
    
    public func presentEvent(_ event: SystemHUDEvent) {
        activeEvent = event
        
        dismissTimer?.invalidate()
        let duration = max(0.5, displayDuration)
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissActiveHUD()
            }
        }
    }
    
    public func dismissActiveHUD() {
        activeEvent = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
    }
}
