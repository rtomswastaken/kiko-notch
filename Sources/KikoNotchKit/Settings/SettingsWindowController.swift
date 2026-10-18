import Foundation
import AppKit
import SwiftUI

/// Tab identifier for Settings window
public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case displays = "Displays"
    case media = "Media"
    case hud = "HUD & System"
    case ai = "AI Providers"
    case weather = "Weather"
    case clipboard = "Clipboard"
    case features = "Features"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintpalette"
        case .displays: return "display"
        case .media: return "play.circle"
        case .hud: return "slider.horizontal.3"
        case .ai: return "sparkles"
        case .weather: return "cloud.sun"
        case .clipboard: return "doc.on.clipboard"
        case .features: return "switch.2"
        case .about: return "info.circle"
        }
    }
}

/// Observable state for programmatically selecting active settings tabs
public final class SettingsTabSelection: ObservableObject, @unchecked Sendable {
    public static let shared = SettingsTabSelection()
    @Published public var selectedTab: SettingsTab = .general
}

/// SwiftUI multi-tab settings root view with macOS NavigationSplitView sidebar
public struct SettingsRootView: View {
    @ObservedObject public var tabSelection = SettingsTabSelection.shared
    
    public init(initialTab: SettingsTab = .general) {
        tabSelection.selectedTab = initialTab
    }
    
    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $tabSelection.selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.iconName)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 220)
        } detail: {
            Group {
                switch tabSelection.selectedTab {
                case .general:
                    GeneralSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .displays:
                    DisplaySettingsView()
                case .media:
                    MediaSettingsView()
                case .hud:
                    HUDSettingsView()
                case .ai:
                    AIProvidersSettingsView()
                case .weather:
                    WeatherSettingsView()
                case .clipboard:
                    ClipboardSettingsView()
                case .features:
                    FeatureToggleSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 460, idealHeight: 520)
    }
}

/// Window controller managing the native Settings window with proper macOS activation policy and focus retention
public final class SettingsWindowController: NSWindowController, NSWindowDelegate, @unchecked Sendable {
    public static let shared = SettingsWindowController()
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(BrandAssets.appName) Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("KikoNotchSettingsWindow")
        
        // Ensure proper window behaviors across Spaces and Cycles
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = false
        window.isMovableByWindowBackground = true
        
        let hostingView = NSHostingView(rootView: SettingsRootView())
        window.contentView = hostingView
        
        super.init(window: window)
        window.delegate = self
        
        // Link interaction manager and menu bar callbacks
        InteractionManager.shared.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        MenuBarController.shared.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func showSettings(tab: SettingsTab? = nil) {
        if let tab = tab {
            SettingsTabSelection.shared.selectedTab = tab
        }
        
        // Set app to regular mode so window can receive focus and key events
        NSApp.setActivationPolicy(.regular)
        
        guard let window = self.window else { return }
        
        if window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.center()
        
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    public override func close() {
        super.close()
        relinquishFocus()
    }
    
    private func relinquishFocus() {
        window?.orderOut(nil)
        
        // Return app to accessory policy unless dock icon is configured to stay visible
        if !AppLifecycle.shared.isDockIconVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - NSWindowDelegate
    
    public func windowWillClose(_ notification: Notification) {
        relinquishFocus()
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    
    public func windowDidResignKey(_ notification: Notification) {
    }
}
