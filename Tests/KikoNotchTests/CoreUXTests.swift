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
        XCTAssertEqual(expandedRect.size, IslandGeometry.expandedSize)
        XCTAssertEqual(expandedRect.maxY, screenRect.maxY, accuracy: 0.1,
                       "The expanded island must remain physically attached to the display top edge")
    }

    func testIslandUsesFixedDimensionsRegardlessOfStoredPreference() {
        var config = IslandGeometryConfig.standard
        config.expandedWidth = 300
        config.expandedHeight = 160
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let mode = IslandPresentationMode.physicalNotch(notchRect: CGRect(x: 620, y: 868, width: 200, height: 32))

        let rect = IslandGeometry.targetRect(for: .expanded, mode: mode, screenFrame: screen, config: config)
        XCTAssertEqual(rect.size, IslandGeometry.expandedSize)
    }

    func testGlobalClickDismissalIgnoresClicksInsideIsland() {
        let manager = InteractionManager.shared
        manager.isPinned = false
        manager.transition(to: .expanded)

        XCTAssertFalse(manager.shouldCollapseForGlobalClick(isInsideIsland: true))
        XCTAssertTrue(manager.shouldCollapseForGlobalClick(isInsideIsland: false))

        manager.transition(to: .collapsed)
        XCTAssertFalse(manager.shouldCollapseForGlobalClick(isInsideIsland: false))
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

    @MainActor
    func testAppLifecycleInitializationAndPanelPersistence() {
        let lifecycle = AppLifecycle.shared
        // Initialize without blocking on NSApp.run()
        lifecycle.startApplication(runEventLoopIfNeeded: false)
        XCTAssertTrue(lifecycle.isApplicationRunning)

        // Calling again must be safe and idempotent
        lifecycle.startApplication(runEventLoopIfNeeded: false)
        XCTAssertTrue(lifecycle.isApplicationRunning)

        // Verify panel is created and strongly retained
        guard let panel = lifecycle.panel else {
            XCTFail("Island panel must be instantiated and non-nil after startApplication()")
            return
        }
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.level, .statusBar)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }

    @MainActor
    func testSettingsWindowControllerProperties() {
        let controller = SettingsWindowController.shared
        guard let window = controller.window else {
            XCTFail("Settings window should be instantiated")
            return
        }
        XCTAssertEqual(window.title, "Kiko Notch Settings")
        XCTAssertEqual(window.identifier?.rawValue, "KikoNotchSettingsWindow")
        XCTAssertTrue(window.collectionBehavior.contains(.managed))
        XCTAssertTrue(window.collectionBehavior.contains(.participatesInCycle))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))

        // Tab programmatic selection
        SettingsTabSelection.shared.selectedTab = .appearance
        XCTAssertEqual(SettingsTabSelection.shared.selectedTab, .appearance)
        SettingsTabSelection.shared.selectedTab = .general
        XCTAssertEqual(SettingsTabSelection.shared.selectedTab, .general)
    }

    func testDeterministicSettingsToggles() {
        let settings = SettingsManager.shared

        // Feature toggles
        settings.setFeatureEnabled(.media, enabled: true)
        XCTAssertTrue(settings.isFeatureEnabled(.media))
        settings.setFeatureEnabled(.media, enabled: false)
        XCTAssertFalse(settings.isFeatureEnabled(.media))
        settings.setFeatureEnabled(.media, enabled: true)
        XCTAssertTrue(settings.isFeatureEnabled(.media))

        // AI Provider toggles
        settings.setAIProviderEnabled(.codex, enabled: true)
        XCTAssertTrue(settings.isAIProviderEnabled(.codex))
        settings.setAIProviderEnabled(.codex, enabled: false)
        XCTAssertFalse(settings.isAIProviderEnabled(.codex))

        // Antigravity defaults
        settings.setAIProviderEnabled(.antigravity, enabled: true)
        XCTAssertTrue(settings.isAIProviderEnabled(.antigravity))
    }

    // MARK: - Section 21: Island Visual Verification & Notch Attachment

    @MainActor
    func testIslandRemainsAttachedToPhysicalNotchWhenExpanded() {
        let lifecycle = AppLifecycle.shared
        lifecycle.startApplication(runEventLoopIfNeeded: false)

        guard let panel = lifecycle.panel else {
            XCTFail("Panel must exist")
            return
        }

        let targetScreen = DisplayManager.shared.targetScreen
        let screenFrame = targetScreen.frame

        // In collapsed state: top edge touches screen top
        InteractionManager.shared.transition(to: .collapsed)
        XCTAssertEqual(panel.frame.maxY, screenFrame.maxY, accuracy: 1.0,
                       "Collapsed island must touch the top edge of the display")

        // In expanded state: top edge must REMAIN attached to display top edge (no gap)
        InteractionManager.shared.transition(to: .expanded)
        XCTAssertEqual(panel.frame.maxY, screenFrame.maxY, accuracy: 1.0,
                       "Expanded island must remain attached to top edge with zero gap")
        XCTAssertEqual(panel.frame.width, IslandGeometry.windowSize.width, accuracy: 1.0)
    }

    @MainActor
    func testSettingsWindowPresentsSeparately() {
        let nav = IslandNavigationModel.shared
        nav.selectTab(.home)
        XCTAssertEqual(nav.currentTab, .home)

        // Show settings window
        SettingsWindowController.shared.showSettings()
        guard let window = SettingsWindowController.shared.window else {
            XCTFail("Settings window must exist")
            return
        }
        XCTAssertTrue(window.isVisible, "Settings window must become visible")
        XCTAssertEqual(nav.currentTab, .home, "Active island tab must not be altered when Settings window opens")

        // Close settings window
        SettingsWindowController.shared.close()
    }

    @MainActor
    func testPageNavigationRetainsExpandedState() {
        let interaction = InteractionManager.shared
        let nav = IslandNavigationModel.shared

        interaction.transition(to: .expanded)
        XCTAssertEqual(interaction.currentState, .expanded)

        // Cycle through all 4 page tabs
        for tab in IslandTab.pageTabs {
            nav.selectTab(tab)
            XCTAssertEqual(nav.currentTab, tab)
            XCTAssertEqual(interaction.currentState, .expanded, "Switching to \(tab) must not collapse the island")
        }

        interaction.transition(to: .collapsed)
    }
}
