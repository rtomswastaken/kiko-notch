import XCTest
@testable import KikoNotchKit
import AppKit
import SwiftUI

final class ThemeTests: XCTestCase {
    
    // MARK: - Section 14: CUSTOM-001 through CUSTOM-007 & ACC-003
    
    func testColorPaletteHexConversion() {
        let hex = "#007AFF"
        let color = ColorPalette.color(fromHex: hex)
        XCTAssertNotNil(color)
        
        let blue = NSColor(srgbRed: 0.0, green: 122.0 / 255.0, blue: 1.0, alpha: 1.0)
        let hexOut = ColorPalette.hexString(from: blue)
        XCTAssertEqual(hexOut.uppercased(), "#007AFF")
    }
    
    func testWCAGContrastRatio() {
        let white = NSColor.white
        let black = NSColor.black
        let ratio = ColorPalette.contrastRatio(foreground: white, background: black)
        XCTAssertGreaterThan(ratio, 20.0) // Maximum contrast is 21:1
        XCTAssertTrue(ColorPalette.meetsWCAGAA(foreground: white, background: black))
    }
    
    func testThemePresets() {
        let manager = ThemeManager.shared
        manager.applyThemePreset(.dark)
        XCTAssertGreaterThan(manager.colors.backgroundOpacity, 0.9)
        
        manager.applyThemePreset(.liquidGlassDark)
        XCTAssertEqual(manager.colors.frostIntensity, 0.8, accuracy: 0.05)
    }
    
    func testGeometryClamping() {
        var config = IslandGeometryConfig.standard
        config.cornerRadius = 5.0
        let clampedMin = IslandGeometry.clamp(config)
        XCTAssertEqual(clampedMin.cornerRadius, IslandGeometry.minCornerRadius)
        
        config.cornerRadius = 100.0
        let clampedMax = IslandGeometry.clamp(config)
        XCTAssertEqual(clampedMax.cornerRadius, IslandGeometry.maxCornerRadius)
    }
    
    func testLayoutConfigurationReordering() {
        var layout = LayoutConfiguration.standard
        let originalFirst = layout.visibleModules[0]
        layout.moveModule(from: 0, to: 2)
        XCTAssertNotEqual(layout.visibleModules[0], originalFirst)
        
        // Toggle visibility
        let countBefore = layout.visibleModules.count
        layout.toggleVisibility(for: .media)
        XCTAssertEqual(layout.visibleModules.count, countBefore - 1)
        layout.toggleVisibility(for: .media)
        XCTAssertEqual(layout.visibleModules.count, countBefore)
    }
    
    func testThemeStorageSerialization() throws {
        let profile = ThemeProfile(
            name: "Test Theme",
            theme: .liquidGlassDark,
            colors: .standard,
            geometry: .standard,
            layout: .standard
        )
        
        let data = try ThemeStorage.exportTheme(profile: profile)
        XCTAssertFalse(data.isEmpty)
        
        let decoded = try ThemeStorage.importTheme(from: data)
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.theme, profile.theme)
        XCTAssertEqual(decoded.colors, profile.colors)
        XCTAssertEqual(decoded.geometry, profile.geometry)
    }
    
    func testReducedMotionPreference() {
        let manager = ThemeManager.shared
        manager.setReducedMotionPreference(true)
        XCTAssertTrue(manager.isReducedMotion)
        
        let anim = IslandAnimationEngine.animation(for: .expanded, reducedMotion: true)
        XCTAssertNotNil(anim)
        
        let duration = IslandAnimationEngine.animationDuration(for: .expanded, reducedMotion: true)
        XCTAssertEqual(duration, 0.1)
        
        manager.setReducedMotionPreference(false)
    }
}
