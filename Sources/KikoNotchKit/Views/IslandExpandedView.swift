import SwiftUI
import AppKit

/// Expanded multi-tab interactive dashboard for Kiko Notch Island.
/// Features a single, shared top navigation container positioned at fixed coordinates,
/// with the dedicated page content viewport cleanly positioned beneath it.
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
        VStack(spacing: 0) {
            // 1. Single Shared Navigation Container (Stationary at top across all pages)
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
            .padding(.horizontal, IslandSpacing.horizontalPadding)
            .padding(.top, IslandSpacing.topPadding)
            .padding(.bottom, IslandSpacing.navBarSpacing)

            // 2. Dedicated Page Content Viewport Region (Beneath the Navigation Selector)
            ZStack {
                switch navigation.activeTab {
                case .home:
                    HomeTabView()
                case .system:
                    SystemTabView()
                case .fileShelf:
                    FileShelfTabView()
                case .aiUsage:
                    AIUsageTabView()
                case .settings:
                    HomeTabView()
                        .onAppear {
                            SettingsWindowController.shared.showSettings()
                            navigation.selectTab(.home)
                        }
                }
            }
            .padding(.horizontal, IslandSpacing.horizontalPadding)
            .padding(.bottom, IslandSpacing.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(.white)
        .environment(\.colorScheme, .dark)
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
