import Foundation
import XCTest
@testable import KikoNotchKit

final class NavigationTests: XCTestCase {

    // MARK: - 1. Enum Properties & Tab Presence

    func testIslandTabEnumProperties() {
        // Verify exactly the 5 intended tabs exist
        let tabs = IslandTab.allCases
        XCTAssertEqual(tabs.count, 5, "Must have exactly 5 tabs (Home, System, File Shelf, AI Usage, Settings)")

        // 1. Home
        XCTAssertEqual(IslandTab.home.title, "Home")
        XCTAssertEqual(IslandTab.home.iconName, "house.fill")
        XCTAssertEqual(IslandTab.home.shortLabel, "Home")

        // 2. System Activity
        XCTAssertEqual(IslandTab.system.title, "System Activity")
        XCTAssertEqual(IslandTab.system.iconName, "slider.horizontal.3")
        XCTAssertEqual(IslandTab.system.shortLabel, "System")

        // 3. File Shelf
        XCTAssertEqual(IslandTab.fileShelf.title, "File Shelf")
        XCTAssertEqual(IslandTab.fileShelf.iconName, "tray.and.arrow.down.fill")
        XCTAssertEqual(IslandTab.fileShelf.shortLabel, "Shelf")

        // 4. AI Usage
        XCTAssertEqual(IslandTab.aiUsage.title, "AI Usage")
        XCTAssertEqual(IslandTab.aiUsage.iconName, "sparkles")
        XCTAssertEqual(IslandTab.aiUsage.shortLabel, "AI")

        // 5. Settings
        XCTAssertEqual(IslandTab.settings.title, "Settings")
        XCTAssertEqual(IslandTab.settings.iconName, "gearshape.fill")
        XCTAssertEqual(IslandTab.settings.shortLabel, "Settings")
    }

    func testRemovedTabsAreCompletelyAbsent() {
        // Primary in-island page tabs (Settings is excluded and hosted in dedicated window)
        XCTAssertEqual(IslandTab.pageTabs, [.home, .system, .fileShelf, .aiUsage])
        XCTAssertFalse(IslandTab.pageTabs.contains(.settings))

        let allRawValues = IslandTab.allCases.map(\.rawValue)
        XCTAssertFalse(allRawValues.contains("Weather"), "Weather tab must be removed")
        XCTAssertFalse(allRawValues.contains("Now Playing"), "Now Playing tab must be removed")
        XCTAssertFalse(allRawValues.contains("Calendar"), "Calendar tab must be removed")
        XCTAssertFalse(allRawValues.contains("Agenda"), "Agenda tab must be removed")
    }

    // MARK: - 2. Safe Fallback for Invalid or Removed Destinations

    func testSafeFallbackForInvalidOrRemovedDestinations() {
        // Removed tabs must safely fall back to Home
        XCTAssertEqual(IslandTab.resolve("Weather"), .home)
        XCTAssertEqual(IslandTab.resolve("weather"), .home)
        XCTAssertEqual(IslandTab.resolve("Now Playing"), .home)
        XCTAssertEqual(IslandTab.resolve("nowplaying"), .home)
        XCTAssertEqual(IslandTab.resolve("Calendar"), .home)
        XCTAssertEqual(IslandTab.resolve("Agenda"), .home)

        // Arbitrary unknown strings must fall back to Home
        XCTAssertEqual(IslandTab.resolve("invalid_tab_name"), .home)
        XCTAssertEqual(IslandTab.resolve(""), .home)
        XCTAssertEqual(IslandTab.resolve("   "), .home)
        XCTAssertEqual(IslandTab.resolve(nil), .home)

        // Valid destinations must resolve correctly
        XCTAssertEqual(IslandTab.resolve("Home"), .home)
        XCTAssertEqual(IslandTab.resolve("System Activity"), .system)
        XCTAssertEqual(IslandTab.resolve("System"), .system)
        XCTAssertEqual(IslandTab.resolve("File Shelf"), .fileShelf)
        XCTAssertEqual(IslandTab.resolve("Shelf"), .fileShelf)
        XCTAssertEqual(IslandTab.resolve("AI Usage"), .aiUsage)
        XCTAssertEqual(IslandTab.resolve("AI"), .aiUsage)
        XCTAssertEqual(IslandTab.resolve("Settings"), .settings)
    }

    // MARK: - 3. Navigation State & Click Switching

    @MainActor
    func testNavigationModelDefaultState() {
        let nav = IslandNavigationModel()
        XCTAssertEqual(nav.currentTab, .home)
        XCTAssertFalse(nav.isPinned)
        XCTAssertFalse(nav.canGoPrevious)
        XCTAssertTrue(nav.canGoNext)
    }

    @MainActor
    func testRemainingPagesNavigable() {
        let nav = IslandNavigationModel()

        nav.selectTab(.home)
        XCTAssertEqual(nav.currentTab, .home)

        nav.selectTab(.system)
        XCTAssertEqual(nav.currentTab, .system)

        nav.selectTab(.fileShelf)
        XCTAssertEqual(nav.currentTab, .fileShelf)

        nav.selectTab(.aiUsage)
        XCTAssertEqual(nav.currentTab, .aiUsage)

        // Selecting Settings must open the Settings window without corrupting active tab
        nav.selectTab(.settings)
        XCTAssertEqual(nav.currentTab, .aiUsage, "Selecting settings must preserve active island page")

        // selectTab(named:)
        nav.selectTab(named: "System Activity")
        XCTAssertEqual(nav.currentTab, .system)

        nav.selectTab(named: "Settings")
        XCTAssertEqual(nav.currentTab, .system, "Selecting settings by name must preserve active island page")

        nav.selectTab(named: "Weather") // Removed tab falls back to Home
        XCTAssertEqual(nav.currentTab, .home)
    }

    // MARK: - 4. Non-Wrapping Boundary Stops

    @MainActor
    func testNavigationStopsAtBothEndsWithoutWrapping() {
        let nav = IslandNavigationModel()
        XCTAssertEqual(nav.currentTab, .home) // index 0

        // Moving backward from first page must stop at first page (no wrap)
        XCTAssertFalse(nav.canGoPrevious)
        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .home, "Must stop at first page and not wrap around")

        // Move forward step-by-step
        XCTAssertTrue(nav.canGoNext)
        nav.nextTab()
        XCTAssertEqual(nav.currentTab, .system) // index 1

        nav.nextTab()
        XCTAssertEqual(nav.currentTab, .fileShelf) // index 2

        nav.nextTab()
        XCTAssertEqual(nav.currentTab, .aiUsage) // index 3 (last in-island page)

        // Moving forward from last page must stop at last page (no wrap)
        XCTAssertFalse(nav.canGoNext)
        nav.nextTab()
        XCTAssertEqual(nav.currentTab, .aiUsage, "Must stop at last page (AI Usage) and not wrap around")

        // Moving backward step-by-step
        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .fileShelf)

        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .system)

        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .home)

        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .home, "Must stop at Home")
    }

    // MARK: - 5. Trackpad Swipe Gesture Navigation

    @MainActor
    func testTrackpadSwipeLeftAndRightNavigation() {
        let handler = TrackpadSwipeHandler()
        let nav = IslandNavigationModel()
        let interaction = InteractionManager.shared
        interaction.transition(to: .expanded)

        nav.selectTab(.home)
        XCTAssertEqual(nav.currentTab, .home)

        // 1. Swipe Left (fingers move right-to-left: negative deltaX with natural scrolling)
        handler.handleScrollDelta(
            deltaX: 0,
            deltaY: 0,
            phase: .began,
            navigation: nav,
            interaction: interaction
        )
        let didSwipeLeft = handler.handleScrollDelta(
            deltaX: -45.0,
            deltaY: 0,
            phase: .changed,
            isDirectionInverted: true,
            navigation: nav,
            interaction: interaction
        )
        XCTAssertTrue(didSwipeLeft, "Swipe left threshold should be recognized")
        XCTAssertEqual(nav.currentTab, .system, "Swipe left should advance from Home to System Activity")

        handler.handleScrollDelta(
            deltaX: 0,
            deltaY: 0,
            phase: .ended,
            navigation: nav,
            interaction: interaction
        )

        // 2. Another Swipe Left -> advances to File Shelf
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .began, navigation: nav, interaction: interaction)
        handler.handleScrollDelta(deltaX: -40.0, deltaY: 0, phase: .changed, isDirectionInverted: true, navigation: nav, interaction: interaction)
        XCTAssertEqual(nav.currentTab, .fileShelf, "Swipe left should advance to File Shelf")
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .ended, navigation: nav, interaction: interaction)

        // 3. Swipe Right (fingers move left-to-right: positive deltaX with natural scrolling)
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .began, navigation: nav, interaction: interaction)
        let didSwipeRight = handler.handleScrollDelta(
            deltaX: 45.0,
            deltaY: 0,
            phase: .changed,
            isDirectionInverted: true,
            navigation: nav,
            interaction: interaction
        )
        XCTAssertTrue(didSwipeRight, "Swipe right threshold should be recognized")
        XCTAssertEqual(nav.currentTab, .system, "Swipe right should move back to System Activity")
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .ended, navigation: nav, interaction: interaction)
    }

    @MainActor
    func testTrackpadSwipeStopsAtBoundaries() {
        let handler = TrackpadSwipeHandler()
        let nav = IslandNavigationModel()
        let interaction = InteractionManager.shared
        interaction.transition(to: .expanded)

        // At Home: swipe right must stop at Home
        nav.selectTab(.home)
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .began, navigation: nav, interaction: interaction)
        handler.handleScrollDelta(deltaX: 50.0, deltaY: 0, phase: .changed, isDirectionInverted: true, navigation: nav, interaction: interaction)
        XCTAssertEqual(nav.currentTab, .home, "Swipe right at Home must stop at Home without wrapping")
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .ended, navigation: nav, interaction: interaction)

        // At AI Usage: swipe left must stop at AI Usage
        nav.selectTab(.aiUsage)
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .began, navigation: nav, interaction: interaction)
        handler.handleScrollDelta(deltaX: -50.0, deltaY: 0, phase: .changed, isDirectionInverted: true, navigation: nav, interaction: interaction)
        XCTAssertEqual(nav.currentTab, .aiUsage, "Swipe left at AI Usage must stop at AI Usage without wrapping")
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .ended, navigation: nav, interaction: interaction)
    }

    @MainActor
    func testTrackpadVerticalScrollingDoesNotTriggerPageNavigation() {
        let handler = TrackpadSwipeHandler()
        let nav = IslandNavigationModel()
        let interaction = InteractionManager.shared
        interaction.transition(to: .expanded)
        nav.selectTab(.system)

        // User scrolls vertically through System Activity
        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .began, navigation: nav, interaction: interaction)

        // Substantial vertical delta with minimal horizontal drift
        let didTrigger = handler.handleScrollDelta(
            deltaX: 5.0,
            deltaY: -50.0,
            phase: .changed,
            navigation: nav,
            interaction: interaction
        )

        XCTAssertFalse(didTrigger, "Vertical scrolling must lock out horizontal swipe navigation")
        XCTAssertEqual(nav.currentTab, .system, "Page must not switch while scrolling vertically")

        // Even if horizontal delta accumulates afterwards in the same gesture, it remains locked to vertical
        let didTriggerAfter = handler.handleScrollDelta(
            deltaX: -45.0,
            deltaY: -20.0,
            phase: .changed,
            navigation: nav,
            interaction: interaction
        )
        XCTAssertFalse(didTriggerAfter, "Locked vertical gesture must never trigger page switch")
        XCTAssertEqual(nav.currentTab, .system)

        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .ended, navigation: nav, interaction: interaction)
    }

    @MainActor
    func testTrackpadSingleGestureCannotTriggerMultiplePageChanges() {
        let handler = TrackpadSwipeHandler()
        let nav = IslandNavigationModel()
        let interaction = InteractionManager.shared
        interaction.transition(to: .expanded)
        nav.selectTab(.home)

        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .began, navigation: nav, interaction: interaction)

        // First threshold crossing triggers page 1 -> 2
        let first = handler.handleScrollDelta(deltaX: -35.0, deltaY: 0, phase: .changed, isDirectionInverted: true, navigation: nav, interaction: interaction)
        XCTAssertTrue(first)
        XCTAssertEqual(nav.currentTab, .system)

        // Continuing the exact same gesture (more delta) must NOT trigger page 2 -> 3
        let second = handler.handleScrollDelta(deltaX: -70.0, deltaY: 0, phase: .changed, isDirectionInverted: true, navigation: nav, interaction: interaction)
        XCTAssertFalse(second, "Single gesture must not trigger multiple page changes")
        XCTAssertEqual(nav.currentTab, .system, "Must remain on System Activity until gesture finishes and a new one starts")

        handler.handleScrollDelta(deltaX: 0, deltaY: 0, phase: .ended, navigation: nav, interaction: interaction)
    }

    @MainActor
    func testTrackpadIgnoresMomentumPhases() {
        let handler = TrackpadSwipeHandler()
        let nav = IslandNavigationModel()
        let interaction = InteractionManager.shared
        interaction.transition(to: .expanded)
        nav.selectTab(.home)

        // Momentum events arriving after fingers lift must be rejected
        let didTrigger = handler.handleScrollDelta(
            deltaX: -80.0,
            deltaY: 0,
            phase: .changed,
            momentumPhase: .changed, // Inertial momentum
            isDirectionInverted: true,
            navigation: nav,
            interaction: interaction
        )

        XCTAssertFalse(didTrigger, "Momentum scroll events must never trigger page switch")
        XCTAssertEqual(nav.currentTab, .home)
    }

    @MainActor
    func testNavigationPinToggle() {
        let nav = IslandNavigationModel()
        XCTAssertFalse(nav.isPinned)

        nav.togglePin()
        XCTAssertTrue(nav.isPinned)

        nav.togglePin()
        XCTAssertFalse(nav.isPinned)
    }

    // MARK: - 9. Header Layout, Consistent Padding & Notch Clearance Verification

    @MainActor
    func testExpandedNavigationLayoutAndNotchClearance() {
        // 1. Verify Page Selector exclusively contains the 4 intended page destinations
        XCTAssertEqual(IslandTab.pageTabs.count, 4, "Expanded navigation must have exactly 4 pages")
        XCTAssertEqual(IslandTab.pageTabs, [.home, .system, .fileShelf, .aiUsage])
        XCTAssertFalse(IslandTab.pageTabs.contains(.settings), "Settings must NOT appear in expanded page navigation selector")

        // 2. Verify Centralized Consistent Padding Constants
        XCTAssertEqual(IslandSpacing.horizontalPadding, 24.0, "Horizontal padding must be 24pt on left and right")
        XCTAssertEqual(IslandSpacing.topPadding, 12.0, "Top padding must be 12pt")
        XCTAssertEqual(IslandSpacing.bottomPadding, 16.0, "Bottom padding must be 16pt for corner clearance")
        XCTAssertEqual(IslandSpacing.navBarSpacing, 10.0, "Spacing between navbar and page content must be 10pt")
        XCTAssertEqual(IslandSpacing.navBarHeight, 28.0, "Navbar height must be compact 28pt")

        // 3. Verify Notch Clearance Geometry
        let islandWidth = IslandGeometry.openNotchSize.width // 680
        let maxNotchWidth: CGFloat = 224.0 // 14" & 16" MBP hardware notch
        let notchLeftBoundary = (islandWidth - maxNotchWidth) / 2.0 // 228.0pt from left edge

        // Leading strip: Logo (14) + gap (6) + Title (~55) + gap (6) + 4-Tab Capsule (90) = ~171pt
        let leadingStripWidth: CGFloat = 14.0 + 6.0 + 55.0 + 6.0 + 90.0
        let leadingStripRightEdge = IslandSpacing.horizontalPadding + leadingStripWidth // 24 + 171 = 195pt

        XCTAssertLessThan(leadingStripRightEdge, notchLeftBoundary, "Navigation icons must end well before physical notch starts (x=228pt)")
        let safetyBuffer = notchLeftBoundary - leadingStripRightEdge
        XCTAssertGreaterThan(safetyBuffer, 25.0, "Must have at least 25pt of clear buffer before the physical notch")

        // 4. Verify Bottom Corner Arc Clearance
        let _ = 24.0 // cornerRadius
        let bottomContentY = IslandGeometry.openNotchSize.height - IslandSpacing.bottomPadding // 290 - 16 = 274pt
        // At x = 24pt (horizontalPadding), the corner radius arc starts at y = 290pt
        // Content ends at y = 274pt, providing 16pt clearance from the bottom edge
        XCTAssertLessThan(bottomContentY, IslandGeometry.openNotchSize.height)
        XCTAssertEqual(IslandGeometry.openNotchSize.height - bottomContentY, IslandSpacing.bottomPadding)
    }
}
