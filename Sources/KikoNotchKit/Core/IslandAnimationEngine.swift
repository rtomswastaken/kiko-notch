import Foundation
import AppKit
import SwiftUI

/// Coordinates smooth transitions, spring curves, and reduced-motion adaptation for island geometry
public final class IslandAnimationEngine {
    
    public struct AnimationParameters {
        public var duration: TimeInterval
        public var timingFunction: CAMediaTimingFunction
        
        public static let standardSpring = AnimationParameters(
            duration: 0.28,
            timingFunction: CAMediaTimingFunction(controlPoints: 0.25, 1.1, 0.45, 1.0)
        )
        
        public static let collapse = AnimationParameters(
            duration: 0.22,
            timingFunction: CAMediaTimingFunction(name: .easeInEaseOut)
        )
        
        public static let peek = AnimationParameters(
            duration: 0.18,
            timingFunction: CAMediaTimingFunction(name: .easeOut)
        )
        
        public static let reducedMotion = AnimationParameters(
            duration: 0.1,
            timingFunction: CAMediaTimingFunction(name: .linear)
        )
    }
    
    /// Returns the animation duration for a given state
    public static func animationDuration(for state: IslandDisplayState, reducedMotion: Bool) -> Double {
        if reducedMotion {
            return 0.1
        }
        switch state {
        case .peek:
            return AnimationParameters.peek.duration
        case .collapsed:
            return AnimationParameters.collapse.duration
        case .expanded, .pinned:
            return AnimationParameters.standardSpring.duration
        }
    }
    
    /// Returns a SwiftUI Animation matching the display state and reduced motion preference
    public static func animation(for state: IslandDisplayState, reducedMotion: Bool) -> Animation {
        if reducedMotion {
            return .linear(duration: 0.1)
        }
        switch state {
        case .peek:
            return .easeOut(duration: 0.18)
        case .expanded, .pinned:
            return .spring(response: 0.32, dampingFraction: 0.82, blendDuration: 0)
        case .collapsed:
            return .easeInOut(duration: 0.22)
        }
    }
    
    /// Animates an NSWindow or NSPanel from its current frame to the target frame
    public static func animate(
        window: NSWindow,
        to targetFrame: CGRect,
        for state: IslandDisplayState,
        completion: (() -> Void)? = nil
    ) {
        let isReduced = ThemeManager.shared.isReducedMotion
        
        if isReduced {
            // Reduced motion: immediate or subtle minimal transition
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = AnimationParameters.reducedMotion.duration
                context.timingFunction = AnimationParameters.reducedMotion.timingFunction
                context.allowsImplicitAnimation = true
                window.animator().setFrame(targetFrame, display: true)
            }, completionHandler: completion)
            return
        }
        
        let params: AnimationParameters
        switch state {
        case .peek:
            params = .peek
        case .expanded, .pinned:
            params = .standardSpring
        case .collapsed:
            params = .collapse
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = params.duration
            context.timingFunction = params.timingFunction
            context.allowsImplicitAnimation = true
            window.animator().setFrame(targetFrame, display: true)
        }, completionHandler: completion)
    }
}
