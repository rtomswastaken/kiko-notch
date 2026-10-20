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
        expandedHeight: 350.0,
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

    @Published public var openOnHover: Bool {
        didSet { UserDefaults.standard.set(openOnHover, forKey: "kiko.openOnHover") }
    }

    @Published public var hoverDelayMs: Int {
        didSet { UserDefaults.standard.set(hoverDelayMs, forKey: "kiko.hoverDelayMs") }
    }

    public var hoverDelay: Double {
        Double(hoverDelayMs) / 1000.0
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

    // Configurable token limits for AI quota windows
    @Published public var aiQuota5hLimit: Double {
        didSet { UserDefaults.standard.set(aiQuota5hLimit, forKey: "kiko.aiQuota5hLimit") }
    }
    @Published public var aiQuotaWeeklyLimit: Double {
        didSet { UserDefaults.standard.set(aiQuotaWeeklyLimit, forKey: "kiko.aiQuotaWeeklyLimit") }
    }
    @Published public var aiQuotaMonthlyLimit: Double {
        didSet { UserDefaults.standard.set(aiQuotaMonthlyLimit, forKey: "kiko.aiQuotaMonthlyLimit") }
    }

    @Published public var preferredScreenIndex: Int {
        didSet { UserDefaults.standard.set(preferredScreenIndex, forKey: "kiko.preferredScreenIndex") }
    }

    @Published public var sendDestinationType: SendDestinationType {
        didSet { UserDefaults.standard.set(sendDestinationType.rawValue, forKey: "kiko.sendDestinationType") }
    }

    @Published public var customSendAppURL: URL? {
        didSet {
            if let url = customSendAppURL {
                UserDefaults.standard.set(url.path, forKey: "kiko.customSendAppURL")
            } else {
                UserDefaults.standard.removeObject(forKey: "kiko.customSendAppURL")
            }
        }
    }

    public var currentSendDestination: SendDestinationInfo {
        FileSenderService.shared.resolveDestination(type: sendDestinationType, customAppURL: customSendAppURL)
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

        self.openOnHover = UserDefaults.standard.object(forKey: "kiko.openOnHover") as? Bool ?? true
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

        let stored5h = UserDefaults.standard.double(forKey: "kiko.aiQuota5hLimit")
        self.aiQuota5hLimit = stored5h > 0 ? stored5h : 5_000_000.0

        let storedWeekly = UserDefaults.standard.double(forKey: "kiko.aiQuotaWeeklyLimit")
        self.aiQuotaWeeklyLimit = storedWeekly > 0 ? storedWeekly : 50_000_000.0

        let storedMonthly = UserDefaults.standard.double(forKey: "kiko.aiQuotaMonthlyLimit")
        self.aiQuotaMonthlyLimit = storedMonthly > 0 ? storedMonthly : 100_000_000.0

        self.preferredScreenIndex = UserDefaults.standard.integer(forKey: "kiko.preferredScreenIndex")

        let storedDest = UserDefaults.standard.string(forKey: "kiko.sendDestinationType")
            .flatMap { SendDestinationType(rawValue: $0) } ?? .airDrop
        self.sendDestinationType = storedDest

        if let storedAppPath = UserDefaults.standard.string(forKey: "kiko.customSendAppURL") {
            self.customSendAppURL = URL(fileURLWithPath: storedAppPath)
        } else {
            self.customSendAppURL = nil
        }
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
        sendDestinationType = .airDrop
        customSendAppURL = nil
    }
}
