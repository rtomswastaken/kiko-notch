import SwiftUI
import AppKit

/// Root container view for Kiko Notch Island managing presentation transitions and liquid glass styling
public struct IslandContainerView: View {
    @ObservedObject public var interactionManager = InteractionManager.shared
    @ObservedObject public var displayManager = DisplayManager.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            switch interactionManager.currentState {
            case .collapsed:
                if case .nonNotchFloatingPill = displayManager.presentationMode {
                    NonNotchPillView(
                        isHovered: false,
                        isPlaying: MediaController.shared.currentMedia.isPlaying
                    )
                } else {
                    IslandCollapsedView()
                }
            case .peek:
                if case .nonNotchFloatingPill = displayManager.presentationMode {
                    NonNotchPillView(
                        isHovered: true,
                        isPlaying: MediaController.shared.currentMedia.isPlaying
                    )
                } else {
                    IslandCollapsedView()
                }
            case .expanded, .pinned:
                IslandExpandedView()
            }
        }
        .liquidGlass(
            cornerRadius: themeManager.geometry.cornerRadius,
            blurIntensity: themeManager.colors.blurIntensity,
            backgroundOpacity: themeManager.colors.backgroundOpacity,
            borderHex: themeManager.colors.borderHex
        )
        .animation(.easeInOut(duration: 0.2), value: interactionManager.currentState)
    }
}
