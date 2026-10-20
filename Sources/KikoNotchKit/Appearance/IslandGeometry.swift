import Foundation
import CoreGraphics
import AppKit

/// Geometry constraints and dimension calculations for Kiko Notch
/// Built on the Boring Notch window geometry foundation.
public struct IslandGeometry {
    /// Boring Notch fixed canvas sizing
    public static let shadowPadding: CGFloat = 20
    public static let openNotchSize: CGSize = CGSize(width: 680, height: 290)
    public static let windowSize: CGSize = CGSize(width: openNotchSize.width, height: openNotchSize.height + shadowPadding)

    public static let cornerRadiusOpened: (top: CGFloat, bottom: CGFloat) = (top: 19, bottom: 24)
    public static let cornerRadiusClosed: (top: CGFloat, bottom: CGFloat) = (top: 6, bottom: 14)

    /// Deliberately fixed, Boring-Notch-inspired canvas sizes.
    public static let collapsedSize = CGSize(width: 185, height: 32)
    public static let peekSize = CGSize(width: 215, height: 44)
    public static let expandedSize = CGSize(width: 680, height: 290)

    public static let minCollapsedWidth: CGFloat = 120.0
    public static let maxCollapsedWidth: CGFloat = 340.0
    public static let minCollapsedHeight: CGFloat = 24.0
    public static let maxCollapsedHeight: CGFloat = 44.0

    public static let minExpandedWidth: CGFloat = 300.0
    public static let maxExpandedWidth: CGFloat = 720.0
    public static let minExpandedHeight: CGFloat = 160.0
    public static let maxExpandedHeight: CGFloat = 600.0

    public static let minCornerRadius: CGFloat = 6.0
    public static let maxCornerRadius: CGFloat = 32.0

    public static let minNonNotchOffsetY: CGFloat = 0.0
    public static let maxNonNotchOffsetY: CGFloat = 40.0

    /// Returns the detected hardware closed notch size for a given screen
    @MainActor
    public static func getClosedNotchSize(for screen: NSScreen? = nil) -> CGSize {
        let target = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let target = target else {
            return collapsedSize
        }

        var notchWidth: CGFloat = 185
        var notchHeight: CGFloat = 32

        if let topLeft = target.auxiliaryTopLeftArea?.width,
           let topRight = target.auxiliaryTopRightArea?.width,
           topLeft > 0, topRight > 0 {
            notchWidth = target.frame.width - topLeft - topRight + 4
        }

        if target.safeAreaInsets.top > 0 {
            notchHeight = target.safeAreaInsets.top
        } else {
            let menuBarHeight = target.frame.maxY - target.visibleFrame.maxY
            if menuBarHeight > 0 {
                notchHeight = menuBarHeight
            }
        }

        return CGSize(width: max(notchWidth, minCollapsedWidth), height: max(notchHeight, minCollapsedHeight))
    }

    /// Returns the detected hardware closed notch size for a given screen, expanding when media is playing
    /// or temporarily expanding vertically beneath the notch when a new track title banner is displayed.
    @MainActor
    public static func getClosedNotchSize(
        for screen: NSScreen? = nil,
        isPlayingMedia: Bool = false,
        isShowingTitleBanner: Bool = false
    ) -> CGSize {
        let base = getClosedNotchSize(for: screen)
        if isShowingTitleBanner && isPlayingMedia {
            let bannerWidth = min(max(base.width + 120.0, 380.0), 440.0)
            let bannerHeight = base.height + 28.0
            return CGSize(width: bannerWidth, height: bannerHeight)
        } else if isPlayingMedia {
            let expandedWidth = min(base.width + 96.0, maxCollapsedWidth)
            return CGSize(width: expandedWidth, height: base.height)
        }
        return base
    }

    /// Sanitizes and clamps geometry parameters to safe limits
    public static func clamp(_ config: IslandGeometryConfig) -> IslandGeometryConfig {
        var clamped = config
        clamped.collapsedWidth = min(max(config.collapsedWidth, minCollapsedWidth), maxCollapsedWidth)
        clamped.collapsedHeight = min(max(config.collapsedHeight, minCollapsedHeight), maxCollapsedHeight)
        clamped.expandedWidth = min(max(config.expandedWidth, minExpandedWidth), maxExpandedWidth)
        clamped.expandedHeight = min(max(config.expandedHeight, minExpandedHeight), maxExpandedHeight)
        clamped.cornerRadius = min(max(config.cornerRadius, minCornerRadius), maxCornerRadius)
        clamped.nonNotchOffsetY = min(max(config.nonNotchOffsetY, minNonNotchOffsetY), maxNonNotchOffsetY)
        return clamped
    }

    /// Calculates the dynamic target frame for the island based on display state and screen geometry
    public static func targetRect(
        for state: IslandDisplayState,
        mode: IslandPresentationMode,
        screenFrame: CGRect,
        config: IslandGeometryConfig
    ) -> CGRect {
        let safeConfig = clamp(config)

        switch mode {
        case .physicalNotch(let notchRect):
            let centerX = notchRect.midX
            let topY = screenFrame.maxY

            switch state {
            case .collapsed:
                let width = max(notchRect.width, collapsedSize.width)
                let height = max(notchRect.height, collapsedSize.height)
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .peek:
                let width = max(notchRect.width, peekSize.width)
                let height = max(notchRect.height, peekSize.height)
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .expanded, .pinned:
                let width = openNotchSize.width
                let height = openNotchSize.height
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            }

        case .nonNotchFloatingPill:
            let centerX = screenFrame.midX
            let topY = screenFrame.maxY - safeConfig.nonNotchOffsetY

            switch state {
            case .collapsed:
                let width = collapsedSize.width
                let height = collapsedSize.height
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .peek:
                let width = peekSize.width
                let height = peekSize.height
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .expanded, .pinned:
                let width = openNotchSize.width
                let height = openNotchSize.height
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            }
        }
    }
}

/// Centralized spacing and layout constants for the expanded Kiko Notch island
public struct IslandSpacing {
    /// Outer horizontal margin between the island boundary and content
    public static let horizontalPadding: CGFloat = 24.0

    /// Top padding from the top edge to the navigation bar container
    public static let topPadding: CGFloat = 12.0

    /// Fixed height of the shared top navigation bar container
    public static let navBarHeight: CGFloat = 28.0

    /// Spacing between navigation bar and page content viewport
    public static let navBarSpacing: CGFloat = 10.0

    /// Bottom padding below the page content viewport
    public static let bottomPadding: CGFloat = 16.0

    /// Standard horizontal padding inside internal cards and widget panels
    public static let cardPaddingHorizontal: CGFloat = 12.0

    /// Standard vertical padding inside internal cards and widget panels
    public static let cardPaddingVertical: CGFloat = 10.0

    /// Corner radius for internal cards and widget panels
    public static let cardCornerRadius: CGFloat = 10.0

    /// Standard vertical spacing between elements inside cards
    public static let sectionSpacing: CGFloat = 8.0
}
