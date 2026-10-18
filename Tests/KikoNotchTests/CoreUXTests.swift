import XCTest
@testable import KikoNotchKit
import AppKit
import SwiftUI

final class CoreUXTests: XCTestCase {
    
    // MARK: - Section 1: CORE-001 through CORE-010
    
    func testIslandGeometryCalculations() {
        let config = IslandGeometryConfig.standard
        let screenRect = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let notchRect = CGRect(x: 620, y: 868, width: 200, height: 32)
        let mode = IslandPresentationMode.physicalNotch(notchRect: notchRect)
        
        let collapsedRect = IslandGeometry.targetRect(for: .collapsed, mode: mode, screenFrame: screenRect, config: config)
        XCTAssertEqual(collapsedRect.midX, notchRect.midX, accuracy: 0.1)
        XCTAssertEqual(collapsedRect.maxY, screenRect.maxY, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(collapsedRect.width, notchRect.width)
        
        let expandedRect = IslandGeometry.targetRect(for: .expanded, mode: mode, screenFrame: screenRect, config: config)
        XCTAssertEqual(expandedRect.width, config.expandedWidth)
        XCTAssertEqual(expandedRect.height, config.expandedHeight)
    }
    
    func testScreenRecordingExclusionSetting() {
        let settings = SettingsManager.shared
        settings.hideFromScreenCapture = true
        XCTAssertTrue(settings.hideFromScreenCapture)
        
        settings.hideFromScreenCapture = false
        XCTAssertFalse(settings.hideFromScreenCapture)
    }
    
    func testInteractionManagerStateTransitions() {
        let manager = InteractionManager.shared
        manager.transition(to: .collapsed)
        XCTAssertEqual(manager.currentState, .collapsed)
        
        manager.transition(to: .expanded)
        XCTAssertEqual(manager.currentState, .expanded)
        
        manager.isPinned = true
        XCTAssertTrue(manager.isPinned)
        XCTAssertEqual(manager.currentState, .expanded)
        
        manager.isPinned = false
        manager.transition(to: .collapsed)
        XCTAssertEqual(manager.currentState, .collapsed)
    }
    
    func testSwipeGestureDelta() {
        let manager = InteractionManager.shared
        manager.transition(to: .collapsed)
        
        // Downward swipe (negative deltaY in scrollingDeltaY) expands
        manager.handleScrollWheel(deltaY: -10.0)
        XCTAssertEqual(manager.currentState, .expanded)
        
        // Upward swipe collapses
        manager.handleScrollWheel(deltaY: 10.0)
        XCTAssertEqual(manager.currentState, .collapsed)
    }
    
    // MARK: - Section 2: NOTCH-001 through NOTCH-004
    
    func testNonNotchMacDetection() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let mode = DisplayManager.detectPresentationMode(for: screen)
        switch mode {
        case .nonNotchFloatingPill(let pillRect):
            XCTAssertGreaterThan(pillRect.width, 0)
            XCTAssertGreaterThan(pillRect.height, 0)
        case .physicalNotch:
            break
        }
    }
    
    func testNonNotchPillOffsetClamping() {
        var config = IslandGeometryConfig.standard
        config.nonNotchOffsetY = -5.0
        let clampedMin = IslandGeometry.clamp(config)
        XCTAssertGreaterThanOrEqual(clampedMin.nonNotchOffsetY, IslandGeometry.minNonNotchOffsetY)
        
        config.nonNotchOffsetY = 150.0
        let clampedMax = IslandGeometry.clamp(config)
        XCTAssertLessThanOrEqual(clampedMax.nonNotchOffsetY, IslandGeometry.maxNonNotchOffsetY)
    }
    
    // MARK: - Section 3: DISP-001 through DISP-003
    
    func testDisplayManagerSelection() {
        let displayManager = DisplayManager.shared
        guard !displayManager.availableScreens.isEmpty else {
            return
        }
        displayManager.selectScreen(at: 0)
        XCTAssertEqual(SettingsManager.shared.preferredScreenIndex, 0)
        XCTAssertNotNil(displayManager.targetScreen)
    }
    
    // MARK: - Section 20: SET-001 through SET-004, SET-006
    
    func testBrandAssetsMonochrome() {
        XCTAssertEqual(BrandAssets.appName, "Kiko Notch")
        XCTAssertFalse(BrandAssets.appVersion.isEmpty)
        XCTAssertFalse(BrandAssets.copyrightNotice.isEmpty)
    }
    
    func testDockPresenceToggle() {
        let lifecycle = AppLifecycle.shared
        lifecycle.showInDock = false
        XCTAssertFalse(lifecycle.showInDock)
        lifecycle.showInDock = true
        XCTAssertTrue(lifecycle.showInDock)
        lifecycle.showInDock = false
    }
}
