import Foundation
import SwiftUI
import AppKit

/// Color palette extensions and utilities for Kiko Notch
public struct ColorPalette {
    
    /// Converts a hex string (e.g. "#RRGGBB" or "#RRGGBBAA") into SwiftUI Color
    public static func color(fromHex hex: String) -> Color {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB / RGBA (32-bit: RRGGBBAA)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        return Color(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
    
    /// Converts SwiftUI Color or NSColor to a standard Hex string
    public static func hexString(from nsColor: NSColor) -> String {
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return "#000000"
        }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        let a = Int(round(rgbColor.alphaComponent * 255))
        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }
    
    /// Calculates relative luminance for WCAG contrast ratio calculation
    public static func luminance(of nsColor: NSColor) -> Double {
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return 0.0 }
        func channelLum(_ val: CGFloat) -> Double {
            let v = Double(val)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channelLum(rgb.redComponent) +
               0.7152 * channelLum(rgb.greenComponent) +
               0.0722 * channelLum(rgb.blueComponent)
    }
    
    /// Returns WCAG contrast ratio between two colors (e.g. 4.5:1 is AA standard)
    public static func contrastRatio(foreground: NSColor, background: NSColor) -> Double {
        let l1 = luminance(of: foreground)
        let l2 = luminance(of: background)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Verifies if text meets WCAG AA standards (minimum 4.5 for regular text)
    public static func meetsWCAGAA(foreground: NSColor, background: NSColor) -> Bool {
        return contrastRatio(foreground: foreground, background: background) >= 4.5
    }
}
