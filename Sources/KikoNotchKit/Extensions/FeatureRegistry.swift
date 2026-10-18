import Foundation
import SwiftUI

/// Runtime registry for all modular Kiko Notch extensions and system features.
/// Implements EXT-001, EXT-003, and SET-005.
@MainActor
public final class FeatureRegistry: ObservableObject {
    public static let shared = FeatureRegistry()
    
    @Published public private(set) var registeredModules: [KikoFeatureID: any KikoModule] = [:]
    @Published public private(set) var registeredMetadata: [KikoFeatureID: FeatureMetadata] = [:]
    
    public init(registerDefaults: Bool = true) {
        if registerDefaults {
            registerDefaultModules()
        }
    }
    
    public func register(_ module: any KikoModule, metadata: FeatureMetadata? = nil) {
        registeredModules[module.id] = module
        if let metadata = metadata {
            registeredMetadata[module.id] = metadata
        } else {
            registeredMetadata[module.id] = FeatureMetadata(
                id: module.id,
                name: module.displayName,
                summary: "Core modular component for \(module.displayName)"
            )
        }
        
        // Sync enabled state with SettingsManager
        let isEnabled = SettingsManager.shared.isFeatureEnabled(module.id)
        module.isEnabled = isEnabled
        if isEnabled {
            module.start()
        }
    }
    
    public func unregister(_ id: KikoFeatureID) {
        if let module = registeredModules[id] {
            module.stop()
            registeredModules.removeValue(forKey: id)
            registeredMetadata.removeValue(forKey: id)
        }
    }
    
    public func module(for id: KikoFeatureID) -> (any KikoModule)? {
        registeredModules[id]
    }
    
    public func metadata(for id: KikoFeatureID) -> FeatureMetadata? {
        registeredMetadata[id]
    }
    
    /// Verifies all declared dependencies are currently enabled.
    public func validateDependencies(for id: KikoFeatureID) -> [KikoFeatureID] {
        guard let meta = registeredMetadata[id] else { return [] }
        var missing: [KikoFeatureID] = []
        for dep in meta.dependencies {
            if !SettingsManager.shared.isFeatureEnabled(dep) {
                missing.append(dep)
            }
        }
        return missing
    }
    
    public func setModuleEnabled(_ id: KikoFeatureID, enabled: Bool) {
        guard let module = registeredModules[id] else { return }
        
        if enabled {
            let missing = validateDependencies(for: id)
            if !missing.isEmpty {
                NSLog("[FeatureRegistry] Warning: Feature '\(id.rawValue)' enabled while missing dependencies: \(missing.map { $0.rawValue })")
            }
        }
        
        module.isEnabled = enabled
        SettingsManager.shared.toggleFeature(id)
        if enabled {
            module.start()
        } else {
            module.stop()
        }
    }
    
    private func registerDefaultModules() {
        register(BatteryModule(), metadata: FeatureMetadata(
            id: .battery,
            name: "Battery Monitor",
            summary: "IOPowerSources battery percentage, charging state, and low-battery alerts."
        ))
        
        register(BluetoothModule(), metadata: FeatureMetadata(
            id: .bluetooth,
            name: "Bluetooth Peripherals",
            summary: "IOBluetooth device connectivity tracking and battery levels."
        ))
        
        register(CalendarModule(), metadata: FeatureMetadata(
            id: .calendar,
            name: "Calendar Agenda",
            summary: "EventKit calendar integration displaying today's schedule and live event countdowns.",
            requiredPermissions: ["NSCalendarsUsageDescription"]
        ))
        
        register(ReminderModule(), metadata: FeatureMetadata(
            id: .reminders,
            name: "Reminders",
            summary: "EventKit reminders integration for overdue and upcoming tasks.",
            requiredPermissions: ["NSRemindersUsageDescription"]
        ))
        
        register(WeatherModule(), metadata: FeatureMetadata(
            id: .weather,
            name: "Weather & Forecast",
            summary: "Open-Meteo REST API weather conditions, rain forecast, and CoreLocation integration.",
            requiredPermissions: ["NSLocationWhenInUseUsageDescription"]
        ))
        
        register(DownloadModule(), metadata: FeatureMetadata(
            id: .downloads,
            name: "Browser Downloads",
            summary: "FSEvents ~/Downloads directory file tracking and companion extension bridge."
        ))
        
        register(ClipboardModule(), metadata: FeatureMetadata(
            id: .clipboard,
            name: "Clipboard History",
            summary: "Encrypted local clipboard history with password-manager exclusion."
        ))
        
        register(AIDashboardModule(), metadata: FeatureMetadata(
            id: .aiDashboard,
            name: "AI Intelligence Center",
            summary: "Local AI provider monitoring (Google Antigravity, OpenAI Codex, Anthropic Claude)."
        ))
        
        register(SystemHUDModule(), metadata: FeatureMetadata(
            id: .systemHUD,
            name: "System HUD",
            summary: "Event-driven system HUD for Volume, Brightness, Keyboard Backlight, and Audio Output."
        ))
        
        register(NotificationModule(), metadata: FeatureMetadata(
            id: .notifications,
            name: "Notifications & Alerts",
            summary: "UserNotifications integration and in-island alert banner presentation."
        ))
    }
}
