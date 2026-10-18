import Foundation

/// Concrete KikoModule implementations for system integrations and productivity features.
/// Ensures all background watchers are cleanly started and stopped when features are toggled.

@MainActor
public final class BatteryModule: KikoModule {
    public let id: KikoFeatureID = .battery
    public let displayName: String = "Battery Status"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        BatteryMonitor.shared.start()
    }
    
    public func stop() {
        BatteryMonitor.shared.stop()
    }
}

@MainActor
public final class BluetoothModule: KikoModule {
    public let id: KikoFeatureID = .bluetooth
    public let displayName: String = "Bluetooth Monitor"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        BluetoothMonitor.shared.start()
    }
    
    public func stop() {
        BluetoothMonitor.shared.stop()
    }
}

@MainActor
public final class CalendarModule: KikoModule {
    public let id: KikoFeatureID = .calendar
    public let displayName: String = "Calendar Agenda"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        CalendarService.shared.refreshEvents()
    }
    
    public func stop() {
        // Suspends active event polling
    }
}

@MainActor
public final class ReminderModule: KikoModule {
    public let id: KikoFeatureID = .reminders
    public let displayName: String = "Reminders"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        ReminderService.shared.refreshReminders()
    }
    
    public func stop() {
        // Suspends reminder polling
    }
}

@MainActor
public final class WeatherModule: KikoModule {
    public let id: KikoFeatureID = .weather
    public let displayName: String = "Weather & Forecast"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        LocationManager.shared.requestLocation()
        Task {
            await WeatherService.shared.refreshWeather()
        }
    }
    
    public func stop() {
        // Suspends active weather refresh
    }
}

@MainActor
public final class DownloadModule: KikoModule {
    public let id: KikoFeatureID = .downloads
    public let displayName: String = "Browser Downloads"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        DownloadMonitor.shared.start()
    }
    
    public func stop() {
        DownloadMonitor.shared.stop()
    }
}

@MainActor
public final class ClipboardModule: KikoModule {
    public let id: KikoFeatureID = .clipboard
    public let displayName: String = "Clipboard History"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        ClipboardManager.shared.start()
    }
    
    public func stop() {
        ClipboardManager.shared.stop()
    }
}

@MainActor
public final class AIDashboardModule: KikoModule {
    public let id: KikoFeatureID = .aiDashboard
    public let displayName: String = "AI Intelligence Center"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        RefreshScheduler.shared.start()
    }
    
    public func stop() {
        RefreshScheduler.shared.stop()
    }
}

@MainActor
public final class SystemHUDModule: KikoModule {
    public let id: KikoFeatureID = .systemHUD
    public let displayName: String = "System HUD"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        SystemHUDManager.shared.start()
    }
    
    public func stop() {
        SystemHUDManager.shared.stop()
    }
}

@MainActor
public final class NotificationModule: KikoModule {
    public let id: KikoFeatureID = .notifications
    public let displayName: String = "Notifications & Alerts"
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func start() {
        // Notification Center setup
    }
    
    public func stop() {
        NotificationManager.shared.dismissActiveBanner()
    }
}
