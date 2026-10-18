import Foundation

/// Complete exported theme profile for Kiko Notch
public struct ThemeProfile: Codable, Sendable, Equatable {
    public var name: String
    public var theme: AppTheme
    public var colors: IslandColorConfig
    public var geometry: IslandGeometryConfig
    public var layout: LayoutConfiguration
    public var version: String
    
    public init(
        name: String,
        theme: AppTheme,
        colors: IslandColorConfig,
        geometry: IslandGeometryConfig,
        layout: LayoutConfiguration = .standard,
        version: String = "1.0.0"
    ) {
        self.name = name
        self.theme = theme
        self.colors = colors
        self.geometry = geometry
        self.layout = layout
        self.version = version
    }
}

/// Manages serialization, import, export, and reset of theme profiles
public final class ThemeStorage {
    private static let userThemeKey = "kiko.userThemeProfile"
    private static let layoutKey = "kiko.layoutConfig"
    
    public static func loadLayout() -> LayoutConfiguration {
        if let data = UserDefaults.standard.data(forKey: layoutKey),
           let layout = try? JSONDecoder().decode(LayoutConfiguration.self, from: data) {
            return layout
        }
        return .standard
    }
    
    public static func saveLayout(_ layout: LayoutConfiguration) {
        if let data = try? JSONEncoder().encode(layout) {
            UserDefaults.standard.set(data, forKey: layoutKey)
        }
    }
    
    /// Exports current theme to JSON data
    public static func exportTheme(profile: ThemeProfile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(profile)
    }
    
    /// Imports theme from JSON data
    public static func importTheme(from data: Data) throws -> ThemeProfile {
        let decoder = JSONDecoder()
        return try decoder.decode(ThemeProfile.self, from: data)
    }
    
    /// Exports theme to a file URL
    public static func exportTheme(profile: ThemeProfile, to url: URL) throws {
        let data = try exportTheme(profile: profile)
        try data.write(to: url, options: .atomic)
    }
    
    /// Imports theme from a file URL
    public static func importTheme(from url: URL) throws -> ThemeProfile {
        let data = try Data(contentsOf: url)
        return try importTheme(from: data)
    }
}
