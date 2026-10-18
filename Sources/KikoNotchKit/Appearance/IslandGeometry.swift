import Foundation
import CoreGraphics

/// Geometry constraints and dimension calculations for Kiko Notch
public struct IslandGeometry {
    public static let minCollapsedWidth: CGFloat = 120.0
    public static let maxCollapsedWidth: CGFloat = 340.0
    public static let minCollapsedHeight: CGFloat = 24.0
    public static let maxCollapsedHeight: CGFloat = 44.0
    
    public static let minExpandedWidth: CGFloat = 300.0
    public static let maxExpandedWidth: CGFloat = 720.0
    public static let minExpandedHeight: CGFloat = 160.0
    public static let maxExpandedHeight: CGFloat = 600.0
    
    public static let minCornerRadius: CGFloat = 10.0
    public static let maxCornerRadius: CGFloat = 32.0
    
    public static let minNonNotchOffsetY: CGFloat = 0.0
    public static let maxNonNotchOffsetY: CGFloat = 40.0
    
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
            // Center horizontally on notch, hug top edge of screen
            let centerX = notchRect.midX
            let topY = screenFrame.maxY
            
            switch state {
            case .collapsed:
                let width = max(notchRect.width, safeConfig.collapsedWidth)
                let height = max(notchRect.height, safeConfig.collapsedHeight)
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .peek:
                let width = max(notchRect.width, safeConfig.collapsedWidth) + 30.0
                let height = max(notchRect.height, safeConfig.collapsedHeight) + 12.0
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .expanded, .pinned:
                let width = safeConfig.expandedWidth
                let height = safeConfig.expandedHeight
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            }
            
        case .nonNotchFloatingPill:
            // Center horizontally on screen, offset slightly below top bezel
            let centerX = screenFrame.midX
            let topY = screenFrame.maxY - safeConfig.nonNotchOffsetY
            
            switch state {
            case .collapsed:
                let width = safeConfig.collapsedWidth
                let height = safeConfig.collapsedHeight
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .peek:
                let width = safeConfig.collapsedWidth + 24.0
                let height = safeConfig.collapsedHeight + 10.0
                return CGRect(
                    x: centerX - (width / 2.0),
                    y: topY - height,
                    width: width,
                    height: height
                )
            case .expanded, .pinned:
                let width = safeConfig.expandedWidth
                let height = safeConfig.expandedHeight
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
