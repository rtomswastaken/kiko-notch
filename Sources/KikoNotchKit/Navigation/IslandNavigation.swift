import Foundation
import SwiftUI
import Combine

/// Distinct navigable tabs within the expanded Kiko Notch Island
public enum IslandTab: String, CaseIterable, Identifiable, Sendable {
    case home = "Home"
    case fileShelf = "File Shelf"
    case aiUsage = "AI Usage"
    case nowPlaying = "Now Playing"
    case calendar = "Calendar"
    case system = "System"
    case weather = "Weather"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .calendar: return "Agenda"
        default: return rawValue
        }
    }
    
    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .fileShelf: return "tray.and.arrow.down.fill"
        case .aiUsage: return "sparkles"
        case .nowPlaying: return "music.note"
        case .calendar: return "calendar"
        case .system: return "slider.horizontal.3"
        case .weather: return "cloud.sun.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    public var shortLabel: String {
        switch self {
        case .home: return "Home"
        case .fileShelf: return "Shelf"
        case .aiUsage: return "AI"
        case .nowPlaying: return "Media"
        case .calendar: return "Events"
        case .system: return "System"
        case .weather: return "Weather"
        case .settings: return "Settings"
        }
    }
}

/// Shared navigation coordinator maintaining tab state across island expansions
public final class IslandNavigationModel: ObservableObject, @unchecked Sendable {
    public static let shared = IslandNavigationModel()
    
    @Published public var activeTab: IslandTab = .home
    @Published public var isPinned: Bool = false
    
    public var currentTab: IslandTab {
        get { activeTab }
        set { activeTab = newValue }
    }
    
    public init() {}
    
    public func togglePin() {
        isPinned.toggle()
    }
    
    public func selectTab(_ tab: IslandTab) {
        activeTab = tab
    }
    
    public func nextTab() {
        let all = IslandTab.allCases
        guard let index = all.firstIndex(of: activeTab) else { return }
        let nextIndex = (index + 1) % all.count
        activeTab = all[nextIndex]
    }
    
    public func previousTab() {
        let all = IslandTab.allCases
        guard let index = all.firstIndex(of: activeTab) else { return }
        let prevIndex = (index - 1 + all.count) % all.count
        activeTab = all[prevIndex]
    }
}
