import Foundation
import SwiftUI
import Combine

/// Distinct navigable tabs within the expanded Kiko Notch Island.
/// Weather, Now Playing, and Calendar have been removed as dedicated tabs
/// in favor of integrated Home widgets.
public enum IslandTab: String, CaseIterable, Identifiable, Sendable {
    case home = "Home"
    case system = "System"
    case fileShelf = "File Shelf"
    case aiUsage = "AI Usage"
    case settings = "Settings"

    public var id: String { rawValue }

    /// The visible, navigable page tabs within the expanded island.
    /// Settings is intentionally managed via a dedicated window/gear icon
    /// and is excluded from the in-island page switcher and swipe cycles.
    public static let pageTabs: [IslandTab] = [.home, .system, .fileShelf, .aiUsage]

    public var title: String {
        switch self {
        case .system: return "System Activity"
        default: return rawValue
        }
    }

    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .system: return "slider.horizontal.3"
        case .fileShelf: return "tray.and.arrow.down.fill"
        case .aiUsage: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }

    public var shortLabel: String {
        switch self {
        case .home: return "Home"
        case .system: return "System"
        case .fileShelf: return "Shelf"
        case .aiUsage: return "AI"
        case .settings: return "Settings"
        }
    }

    /// Safely resolves a tab from an arbitrary or legacy string identifier,
    /// cleanly falling back to .home if the identifier represents a removed
    /// destination (Weather, Now Playing, Calendar) or invalid route.
    public static func resolve(_ raw: String?) -> IslandTab {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .home
        }
        if let direct = IslandTab(rawValue: raw) {
            return direct
        }
        let clean = raw.lowercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
        if let match = IslandTab.allCases.first(where: {
            $0.rawValue.lowercased().filter { !$0.isWhitespace } == clean ||
            $0.shortLabel.lowercased().filter { !$0.isWhitespace } == clean ||
            $0.title.lowercased().filter { !$0.isWhitespace } == clean
        }) {
            return match
        }
        // Removed destinations or unknown routes fall back to Home
        return .home
    }
}

/// Shared navigation coordinator maintaining tab state across island expansions.
/// Authoritative source of truth updated by both click interactions and trackpad swipes.
public final class IslandNavigationModel: ObservableObject, @unchecked Sendable {
    public static let shared = IslandNavigationModel()

    @Published public var activeTab: IslandTab = .home
    @Published public var isPinned: Bool = false

    public var currentTab: IslandTab {
        get { activeTab }
        set { activeTab = newValue }
    }

    public var canGoNext: Bool {
        let all = IslandTab.pageTabs
        guard let index = all.firstIndex(of: activeTab) else { return false }
        return index < all.count - 1
    }

    public var canGoPrevious: Bool {
        let all = IslandTab.pageTabs
        guard let index = all.firstIndex(of: activeTab) else { return false }
        return index > 0
    }

    public init() {}

    public func togglePin() {
        isPinned.toggle()
    }

    public func selectTab(_ tab: IslandTab) {
        if tab == .settings {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showSettings()
            }
            return
        }
        activeTab = tab
    }

    public func selectTab(named name: String?) {
        let resolved = IslandTab.resolve(name)
        if resolved == .settings {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showSettings()
            }
            return
        }
        activeTab = resolved
    }

    /// Navigates to the next valid page.
    /// Stops at the last page without wrapping around.
    @discardableResult
    public func goToNextPage() -> Bool {
        let all = IslandTab.pageTabs
        guard let index = all.firstIndex(of: activeTab), index + 1 < all.count else {
            return false
        }
        activeTab = all[index + 1]
        return true
    }

    /// Navigates to the previous valid page.
    /// Stops at the first page without wrapping around.
    @discardableResult
    public func goToPreviousPage() -> Bool {
        let all = IslandTab.pageTabs
        guard let index = all.firstIndex(of: activeTab), index > 0 else {
            return false
        }
        activeTab = all[index - 1]
        return true
    }

    public func nextTab() {
        goToNextPage()
    }

    public func previousTab() {
        goToPreviousPage()
    }
}
