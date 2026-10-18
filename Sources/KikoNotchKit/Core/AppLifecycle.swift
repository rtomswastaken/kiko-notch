import Foundation
import AppKit
import ServiceManagement

/// Coordinates application lifecycle, activation policy, launch at login, and background state
public final class AppLifecycle: ObservableObject, @unchecked Sendable {
    public static let shared = AppLifecycle()
    
    @Published public var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "kiko.showInDock")
            updateActivationPolicy(showInDock: showInDock)
        }
    }
    
    public var isDockIconVisible: Bool {
        showInDock
    }
    
    private init() {
        let stored = UserDefaults.standard.bool(forKey: "kiko.showInDock")
        self.showInDock = stored
    }
    
    /// Initializes core application systems and displays the floating island
    public func startApplication() {
        NSLog("[Kiko Notch] Initializing core application systems...")
        
        // Configure Dock activation policy
        updateActivationPolicy(showInDock: showInDock)
        
        // Initialize Window Controller on main thread
        DispatchQueue.main.async {
            IslandWindowController.shared.showIsland()
        }
        
        // Initialize Menu Bar companion
        MenuBarController.shared.setupStatusItem()
        
        // Link Menu Bar and HotKey callbacks
        MenuBarController.shared.onToggleIsland = {
            InteractionManager.shared.toggleExpandCollapse()
        }
        MenuBarController.shared.onOpenSettings = {
            SettingsWindowController.shared.showSettings()
        }
        
        HotKeyManager.shared.onToggle = {
            InteractionManager.shared.toggleExpandCollapse()
        }
        
        InteractionManager.shared.onOpenSettings = {
            SettingsWindowController.shared.showSettings()
        }
    }
    
    /// Toggles Dock presence between accessory mode (menu bar only) and regular application mode
    public func setDockIconVisible(_ visible: Bool) {
        self.showInDock = visible
    }
    
    private func updateActivationPolicy(showInDock: Bool) {
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
        }
    }
    
    /// Sets Launch at Login using macOS 13+ ServiceManagement SMAppService
    public func setLaunchAtLogin(_ enabled: Bool) {
        SettingsManager.shared.launchAtLogin = enabled
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[Kiko Notch] Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }
}
