import SwiftUI
import AppKit

/// Expanded multi-tab interactive dashboard for Kiko Notch Island
public struct IslandExpandedView: View {
    @ObservedObject public var interactionManager = InteractionManager.shared
    @ObservedObject public var navigation = IslandNavigationModel.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    
    private var customIsPinned: Binding<Bool>?
    private var onCollapse: (() -> Void)?
    private var onOpenSettings: (() -> Void)?
    
    public init(
        isPinned: Binding<Bool>? = nil,
        onCollapse: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.customIsPinned = isPinned
        self.onCollapse = onCollapse
        self.onOpenSettings = onOpenSettings
    }
    
    private var isPinnedBinding: Binding<Bool> {
        customIsPinned ?? $interactionManager.isPinned
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Horizontal Navigation Bar
            IslandNavigationBar(
                isPinned: isPinnedBinding,
                onCollapse: {
                    if let collapse = onCollapse {
                        collapse()
                    } else {
                        interactionManager.transition(to: .collapsed)
                    }
                }
            )
            
            // Tab Content Body
            ZStack {
                switch navigation.activeTab {
                case .home:
                    HomeTabView()
                case .fileShelf:
                    FileShelfTabView()
                case .aiUsage:
                    AIUsageTabView()
                case .nowPlaying:
                    NowPlayingTabView()
                case .calendar:
                    ProductivityTabView()
                case .system:
                    SystemTabView()
                case .weather:
                    WeatherTabView()
                case .settings:
                    SettingsTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .onExitCommand {
            // Escape key dismisses island when unpinned (ACC-002)
            if !isPinnedBinding.wrappedValue {
                if let collapse = onCollapse {
                    collapse()
                } else {
                    interactionManager.transition(to: .collapsed)
                }
            }
        }
    }
}
