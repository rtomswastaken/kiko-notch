import Foundation
import AppKit
import ServiceManagement

/// Coordinates application lifecycle, activation policy, launch at login, and background state
public final class AppLifecycle: ObservableObject, @unchecked Sendable {
    public static let shared = AppLifecycle()

    /// Strongly retained application delegate preventing deallocation by ARC in accessory mode
    public var appDelegate: (any NSApplicationDelegate)?

    /// Tracks whether application initialization has completed
    private(set) public var isStarted = false

    public var isApplicationRunning: Bool {
        isStarted
    }

    /// Directly exposes the strongly retained IslandPanel for automation and window inspection
    @MainActor
    public var panel: IslandPanel? {
        IslandWindowController.shared.window
    }

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

    /// Initializes core application systems and displays the floating island synchronously on the main thread
    public func startApplication(runEventLoopIfNeeded: Bool = true) {
        // Guard against duplicate initialization (Check 4 & Rule 8)
        guard !isStarted else {
            NSLog("[Kiko Notch] Application already initialized. Ensuring panel is visible.")
            ensurePanelVisible()
            return
        }
        isStarted = true

        NSLog("[Kiko Notch] Initializing core application systems...")

        let app = NSApplication.shared

        // Ensure application delegate is configured and strongly retained
        if app.delegate == nil {
            let defaultDelegate = KikoDefaultAppDelegate()
            self.appDelegate = defaultDelegate
            app.delegate = defaultDelegate
        }

        // Configure Dock activation policy immediately
        updateActivationPolicy(showInDock: showInDock)

        // Start hardware monitors
        BatteryMonitor.shared.start()
        Task { @MainActor in
            VolumeManager.shared.refresh()
            BrightnessManager.shared.refresh()
        }

        // Initialize Window Controller synchronously on main thread
        ensurePanelVisible()

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

        NotificationCenter.default.post(name: NSNotification.Name("KikoAppDidFinishLaunching"), object: nil)

        // Keep main run loop active if invoked in an environment where NSApp.run() hasn't started
        if runEventLoopIfNeeded && !app.isRunning {
            NSLog("[Kiko Notch] Starting NSApplication event run loop...")
            app.run()
        }
    }

    /// Ensures the floating island panel is created and ordered front on the main thread
    public func ensurePanelVisible() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                IslandWindowController.shared.showIsland()
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    IslandWindowController.shared.showIsland()
                }
            }
        }
    }

    /// Toggles Dock presence between accessory mode (menu bar only) and regular application mode
    public func setDockIconVisible(_ visible: Bool) {
        self.showInDock = visible
    }

    private func updateActivationPolicy(showInDock: Bool) {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        if Thread.isMainThread {
            _ = NSApplication.shared.setActivationPolicy(policy)
        } else {
            DispatchQueue.main.sync {
                _ = NSApplication.shared.setActivationPolicy(policy)
            }
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

/// Default AppKit Application Delegate used when running standalone or in test/automation harnesses
public final class KikoDefaultAppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Kiko Notch] Default application delegate did finish launching.")
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Kiko Notch runs as a menu bar / floating island companion and should not exit when windows close
        return false
    }
}
