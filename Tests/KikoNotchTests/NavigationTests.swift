import Foundation
import XCTest
@testable import KikoNotchKit

final class NavigationTests: XCTestCase {
    
    func testIslandTabEnumProperties() {
        // Verify all 8 required tabs exist and have titles & system icons
        let tabs = IslandTab.allCases
        XCTAssertEqual(tabs.count, 8)
        
        XCTAssertEqual(IslandTab.home.title, "Home")
        XCTAssertEqual(IslandTab.home.iconName, "house.fill")
        
        XCTAssertEqual(IslandTab.fileShelf.title, "File Shelf")
        XCTAssertEqual(IslandTab.fileShelf.iconName, "tray.and.arrow.down.fill")
        
        XCTAssertEqual(IslandTab.aiUsage.title, "AI Usage")
        XCTAssertEqual(IslandTab.aiUsage.iconName, "sparkles")
        
        XCTAssertEqual(IslandTab.nowPlaying.title, "Now Playing")
        XCTAssertEqual(IslandTab.nowPlaying.iconName, "music.note")
        
        XCTAssertEqual(IslandTab.calendar.title, "Agenda")
        XCTAssertEqual(IslandTab.calendar.iconName, "calendar")
        
        XCTAssertEqual(IslandTab.system.title, "System")
        XCTAssertEqual(IslandTab.system.iconName, "slider.horizontal.3")
        
        XCTAssertEqual(IslandTab.weather.title, "Weather")
        XCTAssertEqual(IslandTab.weather.iconName, "cloud.sun.fill")
        
        XCTAssertEqual(IslandTab.settings.title, "Settings")
        XCTAssertEqual(IslandTab.settings.iconName, "gearshape.fill")
    }
    
    @MainActor
    func testNavigationModelDefaultState() {
        let nav = IslandNavigationModel()
        XCTAssertEqual(nav.currentTab, .home)
        XCTAssertFalse(nav.isPinned)
    }
    
    @MainActor
    func testNavigationModelTabSelection() {
        let nav = IslandNavigationModel()
        
        nav.selectTab(.aiUsage)
        XCTAssertEqual(nav.currentTab, .aiUsage)
        
        nav.selectTab(.fileShelf)
        XCTAssertEqual(nav.currentTab, .fileShelf)
        
        nav.selectTab(.settings)
        XCTAssertEqual(nav.currentTab, .settings)
    }
    
    @MainActor
    func testNavigationModelCycling() {
        let nav = IslandNavigationModel()
        XCTAssertEqual(nav.currentTab, .home) // index 0
        
        nav.nextTab()
        XCTAssertEqual(nav.currentTab, .fileShelf) // index 1
        
        nav.nextTab()
        XCTAssertEqual(nav.currentTab, .aiUsage) // index 2
        
        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .fileShelf) // index 1
        
        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .home) // index 0
        
        // Wrap around backward
        nav.previousTab()
        XCTAssertEqual(nav.currentTab, .settings) // index 7 (last)
        
        // Wrap around forward
        nav.nextTab()
        XCTAssertEqual(nav.currentTab, .home) // index 0 (first)
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
}
