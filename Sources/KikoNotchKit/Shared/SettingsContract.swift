import Foundation
import SwiftUI

/// Supported App Themes
public enum AppTheme: String, CaseIterable, Codable, Sendable {
    case dark = "Dark"
    case light = "Light"
    case automatic = "Automatic"
    case liquidGlassDark = "Liquid Glass Dark"
    case liquidGlassLight = "Liquid Glass Light"
    case custom = "Custom"
}

/// Dynamic Island Layout Configuration & Dimensions
public struct IslandGeometryConfig: Codable, Sendable, Equatable {
    public var collapsedWidth: CGFloat
    public var collapsedHeight: CGFloat
    public var expandedWidth: CGFloat
    public var expandedHeight: CGFloat
    public var cornerRadius: CGFloat
    public var nonNotchOffsetY: CGFloat
    
    public static let standard = IslandGeometryConfig(
        collapsedWidth: 185.0,
        collapsedHeight: 32.0,
        expandedWidth: 460.0,
        expandedHeight: 280.0,
        cornerRadius: 18.0,
        nonNotchOffsetY: 8.0
    )
}

/// Color Palette Configuration for Kiko Notch
public struct IslandColorConfig: Codable, Sendable, Equatable {
    public var accentHex: String
    public var secondaryHex: String
    public var borderHex: String
    public var blurIntensity: Double // 0.0 to 1.0
    public var backgroundOpacity: Double // 0.0 to 1.0
    public var frostIntensity: Double // 0.0 to 1.0
    
    public static let standard = IslandColorConfig(
        accentHex: "#007AFF",
        secondaryHex: "#5AC8FA",
        borderHex: "#FFFFFF20",
        blurIntensity: 0.8,
        backgroundOpacity: 0.85,
        frostIntensity: 0.75
    )
}

/// Central App Settings Store
public final class SettingsManager: ObservableObject, @unchecked Sendable {
    public static let shared = SettingsManager()
    
    @Published public var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "kiko.theme") }
    }
    
    @Published public var geometry: IslandGeometryConfig {
        didSet {
            if let data = try? JSONEncoder().encode(geometry) {
                UserDefaults.standard.set(data, forKey: "kiko.geometry")
            }
        }
    }
    
    @Published public var colors: IslandColorConfig {
        didSet {
            if let data = try? JSONEncoder().encode(colors) {
                UserDefaults.standard.set(data, forKey: "kiko.colors")
            }
        }
    }
    
    @Published public var hoverDelayMs: Int {
        didSet { UserDefaults.standard.set(hoverDelayMs, forKey: "kiko.hoverDelayMs") }
    }
    
    @Published public var collapseDelayMs: Int {
        didSet { UserDefaults.standard.set(collapseDelayMs, forKey: "kiko.collapseDelayMs") }
    }
    
    @Published public var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "kiko.launchAtLogin") }
    }
    
    @Published public var hideFromScreenCapture: Bool {
        didSet { UserDefaults.standard.set(hideFromScreenCapture, forKey: "kiko.hideFromScreenCapture") }
    }
    
    @Published public var enabledFeatures: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledFeatures), forKey: "kiko.enabledFeatures")
        }
    }
    
    @Published public var enabledAIProviders: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledAIProviders), forKey: "kiko.enabledAIProviders")
        }
    }
    
    @Published public var preferredScreenIndex: Int {
        didSet { UserDefaults.standard.set(preferredScreenIndex, forKey: "kiko.preferredScreenIndex") }
    }
    
    private init() {
        let storedTheme = UserDefaults.standard.string(forKey: "kiko.theme")
            .flatMap { AppTheme(rawValue: $0) } ?? .liquidGlassDark
        self.theme = storedTheme
        
        if let geomData = UserDefaults.standard.data(forKey: "kiko.geometry"),
           let decoded = try? JSONDecoder().decode(IslandGeometryConfig.self, from: geomData) {
            self.geometry = decoded
        } else {
            self.geometry = .standard
        }
        
        if let colData = UserDefaults.standard.data(forKey: "kiko.colors"),
           let decoded = try? JSONDecoder().decode(IslandColorConfig.self, from: colData) {
            self.colors = decoded
        } else {
            self.colors = .standard
        }
        
        self.hoverDelayMs = UserDefaults.standard.object(forKey: "kiko.hoverDelayMs") as? Int ?? 200
        self.collapseDelayMs = UserDefaults.standard.object(forKey: "kiko.collapseDelayMs") as? Int ?? 350
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "kiko.launchAtLogin")
        self.hideFromScreenCapture = UserDefaults.standard.bool(forKey: "kiko.hideFromScreenCapture")
        
        let storedFeatures = UserDefaults.standard.stringArray(forKey: "kiko.enabledFeatures")
        if let storedFeatures = storedFeatures {
            self.enabledFeatures = Set(storedFeatures)
        } else {
            // Default: all enabled
            self.enabledFeatures = Set(KikoFeatureID.allCases.map { $0.rawValue })
        }
        
        let storedProviders = UserDefaults.standard.stringArray(forKey: "kiko.enabledAIProviders")
        if let storedProviders = storedProviders {
            self.enabledAIProviders = Set(storedProviders)
        } else {
            // Default: Antigravity enabled, Codex & Claude disabled
            self.enabledAIProviders = [AIProviderID.antigravity.rawValue]
        }
        
        self.preferredScreenIndex = UserDefaults.standard.integer(forKey: "kiko.preferredScreenIndex")
    }
    
    public func isFeatureEnabled(_ id: KikoFeatureID) -> Bool {
        enabledFeatures.contains(id.rawValue)
    }
    
    public func setFeatureEnabled(_ id: KikoFeatureID, enabled: Bool) {
        if enabled {
            enabledFeatures.insert(id.rawValue)
        } else {
            enabledFeatures.remove(id.rawValue)
        }
    }
    
    public func toggleFeature(_ id: KikoFeatureID) {
        if enabledFeatures.contains(id.rawValue) {
            enabledFeatures.remove(id.rawValue)
        } else {
            enabledFeatures.insert(id.rawValue)
        }
    }
    
    public func isAIProviderEnabled(_ id: AIProviderID) -> Bool {
        enabledAIProviders.contains(id.rawValue)
    }
    
    public func setAIProviderEnabled(_ id: AIProviderID, enabled: Bool) {
        if enabled {
            enabledAIProviders.insert(id.rawValue)
        } else {
            enabledAIProviders.remove(id.rawValue)
        }
    }
    
    public func toggleAIProvider(_ id: AIProviderID) {
        if enabledAIProviders.contains(id.rawValue) {
            enabledAIProviders.remove(id.rawValue)
        } else {
            enabledAIProviders.insert(id.rawValue)
        }
    }
    
    public func resetToDefaults() {
        theme = .liquidGlassDark
        geometry = .standard
        colors = .standard
        hoverDelayMs = 200
        collapseDelayMs = 350
        enabledFeatures = Set(KikoFeatureID.allCases.map { $0.rawValue })
        enabledAIProviders = [AIProviderID.antigravity.rawValue]
        preferredScreenIndex = 0
    }
}
