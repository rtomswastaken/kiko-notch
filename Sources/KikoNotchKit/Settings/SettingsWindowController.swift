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

/// SwiftUI multi-tab settings root view
public struct SettingsRootView: View {
    @State private var selectedTab: SettingsTab = .general
    
    public init(initialTab: SettingsTab = .general) {
        self._selectedTab = State(initialValue: initialTab)
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.iconName)
                }
                .tag(SettingsTab.general)
            
            AppearanceSettingsView()
                .tabItem {
                    Label(SettingsTab.appearance.rawValue, systemImage: SettingsTab.appearance.iconName)
                }
                .tag(SettingsTab.appearance)
            
            DisplaySettingsView()
                .tabItem {
                    Label(SettingsTab.displays.rawValue, systemImage: SettingsTab.displays.iconName)
                }
                .tag(SettingsTab.displays)
            
            MediaSettingsView()
                .tabItem {
                    Label(SettingsTab.media.rawValue, systemImage: SettingsTab.media.iconName)
                }
                .tag(SettingsTab.media)
            
            HUDSettingsView()
                .tabItem {
                    Label(SettingsTab.hud.rawValue, systemImage: SettingsTab.hud.iconName)
                }
                .tag(SettingsTab.hud)
            
            AIProvidersSettingsView()
                .tabItem {
                    Label(SettingsTab.ai.rawValue, systemImage: SettingsTab.ai.iconName)
                }
                .tag(SettingsTab.ai)
            
            WeatherSettingsView()
                .tabItem {
                    Label(SettingsTab.weather.rawValue, systemImage: SettingsTab.weather.iconName)
                }
                .tag(SettingsTab.weather)
            
            ClipboardSettingsView()
                .tabItem {
                    Label(SettingsTab.clipboard.rawValue, systemImage: SettingsTab.clipboard.iconName)
                }
                .tag(SettingsTab.clipboard)
            
            FeatureToggleSettingsView()
                .tabItem {
                    Label(SettingsTab.features.rawValue, systemImage: SettingsTab.features.iconName)
                }
                .tag(SettingsTab.features)
            
            AboutSettingsView()
                .tabItem {
                    Label(SettingsTab.about.rawValue, systemImage: SettingsTab.about.iconName)
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 580, height: 500)
    }
}

/// Window controller managing the native Settings window
public final class SettingsWindowController: NSWindowController, @unchecked Sendable {
    public static let shared = SettingsWindowController()
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(BrandAssets.appName) Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: SettingsRootView())
        window.contentView = hostingView
        
        super.init(window: window)
        
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
    
    public func showSettings() {
        guard let window = self.window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
