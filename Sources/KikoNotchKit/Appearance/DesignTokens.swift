import Foundation
import SwiftUI
import AppKit

/// Centralized design tokens for Kiko Notch and the AI Dashboard.
/// Ensures consistent monochrome aesthetic with a configurable accent color (defaulting to white).
public struct DesignTokens {
    
    // MARK: - Colors
    
    /// Primary background color (deep black for Kiko Notch)
    public static var surfaceBackground: Color {
        Color.black
    }
    
    /// Secondary card and widget container background
    public static var cardBackground: Color {
        Color.white.opacity(0.04)
    }
    
    /// Subtle border for containers, cards, and dividers
    public static var subtleBorder: Color {
        Color.white.opacity(0.08)
    }
    
    /// Muted divider color
    public static var dividerColor: Color {
        Color.white.opacity(0.07)
    }
    
    /// Primary text color (defaults to crisp white)
    public static var primaryText: Color {
        ThemeManager.shared.primaryTextColor
    }
    
    /// Secondary text color (muted neutral gray)
    public static var secondaryText: Color {
        ThemeManager.shared.secondaryTextColor
    }
    
    /// Inactive track color for gauges and unselected items
    public static var trackBackground: Color {
        Color.white.opacity(0.08)
    }
    
    /// Dynamic multi-color gradient accent (defaults to white-to-gray, adapts to media artwork)
    public static var accentGradient: LinearGradient {
        AccentThemeManager.shared.linearGradient
    }

    /// Horizontal accent gradient helper
    public static var horizontalAccentGradient: LinearGradient {
        AccentThemeManager.shared.horizontalGradient
    }

    /// Subtle background gradient for cards and badges
    public static var subtleAccentGradient: LinearGradient {
        AccentThemeManager.shared.subtleBackgroundGradient
    }
    
    /// Active primary accent color (dynamically driven by media artwork or crisp white fallback)
    public static var accentColor: Color {
        if !AccentThemeManager.shared.isDefaultWhite {
            return AccentThemeManager.shared.primaryAccent
        }
        let hex = ThemeManager.shared.colors.accentHex
        if !hex.isEmpty && hex != "#007AFF" {
            return ColorPalette.color(fromHex: hex)
        }
        return Color.white
    }
    
    /// Secondary accent color from the dynamic multi-color palette
    public static var secondaryAccentColor: Color {
        AccentThemeManager.shared.secondaryAccent
    }
    
    /// Computes activity intensity shade from the configured accent color.
    /// Level 0: Inactive / no activity (subtle neutral track)
    /// Level 1: Light activity (25% accent opacity)
    /// Level 2: Moderate activity (50% accent opacity)
    /// Level 3: High activity (75% accent opacity)
    /// Level 4: Peak activity (100% accent opacity)
    public static func intensityColor(level: Int, isMissing: Bool = false) -> Color {
        if isMissing {
            return Color.white.opacity(0.03)
        }
        switch level {
        case 0:
            return Color.white.opacity(0.06)
        case 1:
            return accentColor.opacity(0.28)
        case 2:
            return accentColor.opacity(0.52)
        case 3:
            return accentColor.opacity(0.76)
        case 4...:
            return accentColor.opacity(1.0)
        default:
            return Color.white.opacity(0.06)
        }
    }
    
    // MARK: - Typography & Spacing
    
    public static let titleFont: Font = .system(size: 11, weight: .bold, design: .rounded)
    public static let sectionHeaderFont: Font = .system(size: 9, weight: .bold, design: .default)
    public static let statValueFont: Font = .system(size: 13, weight: .semibold, design: .rounded)
    public static let statLabelFont: Font = .system(size: 8.5, weight: .medium, design: .default)
    public static let captionFont: Font = .system(size: 8, weight: .regular, design: .default)
    public static let ringPercentFont: Font = .system(size: 11.5, weight: .bold, design: .rounded)
}
