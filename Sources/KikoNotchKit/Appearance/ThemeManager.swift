import Foundation
import SwiftUI
import AppKit

/// Central Appearance and Theme coordinator for Kiko Notch
public final class ThemeManager: ObservableObject, @unchecked Sendable {
    public static let shared = ThemeManager()
    
    @Published public var currentTheme: AppTheme {
        didSet {
            SettingsManager.shared.theme = currentTheme
            applyThemePreset(currentTheme)
        }
    }
    
    @Published public var colors: IslandColorConfig {
        didSet {
            SettingsManager.shared.colors = colors
        }
    }
    
    @Published public var geometry: IslandGeometryConfig {
        didSet {
            SettingsManager.shared.geometry = geometry
        }
    }
    
    @Published public var layout: LayoutConfiguration {
        didSet {
            ThemeStorage.saveLayout(layout)
        }
    }
    
    @Published public var isReducedMotion: Bool
    
    private var workspaceObserver: NSObjectProtocol?
    
    private init() {
        let savedTheme = SettingsManager.shared.theme
        self.currentTheme = savedTheme
        self.colors = SettingsManager.shared.colors
        self.geometry = SettingsManager.shared.geometry
        self.layout = ThemeStorage.loadLayout()
        
        let systemReducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let userReducedMotion = UserDefaults.standard.bool(forKey: "kiko.reducedMotion")
        self.isReducedMotion = systemReducedMotion || userReducedMotion
        
        // Listen to system accessibility reduced motion changes
        self.workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let sys = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let usr = UserDefaults.standard.bool(forKey: "kiko.reducedMotion")
            self.isReducedMotion = sys || usr
        }
    }
    
    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    public func setReducedMotionPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "kiko.reducedMotion")
        isReducedMotion = enabled || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    /// Applies predefined colors and parameters for selected theme
    public func applyThemePreset(_ theme: AppTheme) {
        switch theme {
        case .dark:
            colors = IslandColorConfig(
                accentHex: "#0A84FF",
                secondaryHex: "#5E5CE6",
                borderHex: "#FFFFFF15",
                blurIntensity: 0.9,
                backgroundOpacity: 0.95,
                frostIntensity: 0.2
            )
        case .light:
            colors = IslandColorConfig(
                accentHex: "#007AFF",
                secondaryHex: "#5856D6",
                borderHex: "#00000015",
                blurIntensity: 0.9,
                backgroundOpacity: 0.92,
                frostIntensity: 0.2
            )
        case .automatic:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                applyThemePreset(.dark)
            } else {
                applyThemePreset(.light)
            }
        case .liquidGlassDark:
            colors = IslandColorConfig(
                accentHex: "#007AFF",
                secondaryHex: "#5AC8FA",
                borderHex: "#FFFFFF28",
                blurIntensity: 0.85,
                backgroundOpacity: 0.78,
                frostIntensity: 0.8
            )
        case .liquidGlassLight:
            colors = IslandColorConfig(
                accentHex: "#007AFF",
                secondaryHex: "#32ADE6",
                borderHex: "#00000020",
                blurIntensity: 0.85,
                backgroundOpacity: 0.75,
                frostIntensity: 0.8
            )
        case .custom:
            // Keep existing custom colors
            break
        }
    }
    
    /// Returns active effective foreground color for texts (crisp pure white for dark notch background)
    public var primaryTextColor: Color {
        Color.white
    }
    
    /// Returns secondary label color (light white for high legibility on dark glass)
    public var secondaryTextColor: Color {
        Color.white.opacity(0.70)
    }

    /// Dynamic multi-color accent palette coordinated by AccentThemeManager
    public var accentPalette: AccentPalette {
        AccentThemeManager.shared.currentPalette
    }

    /// Dynamic multi-color linear gradient
    public var accentGradient: LinearGradient {
        AccentThemeManager.shared.linearGradient
    }
    
    /// Returns current theme profile
    public func currentProfile() -> ThemeProfile {
        ThemeProfile(
            name: currentTheme.rawValue,
            theme: currentTheme,
            colors: colors,
            geometry: geometry,
            layout: layout
        )
    }
    
    /// Loads an imported profile
    public func loadProfile(_ profile: ThemeProfile) {
        self.currentTheme = profile.theme
        self.colors = profile.colors
        self.geometry = profile.geometry
        self.layout = profile.layout
    }
    
    /// Resets all appearance preferences to defaults
    public func resetToDefaults() {
        SettingsManager.shared.resetToDefaults()
        currentTheme = .liquidGlassDark
        colors = .standard
        geometry = .standard
        layout = .standard
        setReducedMotionPreference(false)
    }
}
