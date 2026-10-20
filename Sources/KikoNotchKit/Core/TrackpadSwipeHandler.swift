import Foundation
import AppKit
import SwiftUI

/// Native macOS Trackpad Swipe Navigation Handler.
/// Recognizes horizontal two-finger trackpad swipes to navigate cleanly between valid pages.
/// Ensures vertical scrolling inside pages (e.g. System Activity, lists) is never hijacked,
/// rejects inertial momentum events, and enforces a single page switch per physical gesture.
public final class TrackpadSwipeHandler: @unchecked Sendable {
    public static let shared = TrackpadSwipeHandler()
    
    // Configuration thresholds
    public var horizontalThreshold: CGFloat = 32.0
    public var verticalLockoutThreshold: CGFloat = 12.0
    public var directionDominanceRatio: CGFloat = 1.3
    
    // Gesture tracking state
    private var accumulatedX: CGFloat = 0.0
    private var accumulatedY: CGFloat = 0.0
    private var hasTriggeredForCurrentGesture: Bool = false
    private var isLockedToVertical: Bool = false
    
    public init() {}
    
    /// Processes a scrollWheel event from the trackpad.
    /// Returns true if a page change was triggered.
    @discardableResult
    public func handleScrollWheel(
        event: NSEvent,
        navigation: IslandNavigationModel = .shared,
        interaction: InteractionManager = .shared
    ) -> Bool {
        handleScrollDelta(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            phase: event.phase,
            momentumPhase: event.momentumPhase,
            hasPreciseDeltas: event.hasPreciseScrollingDeltas,
            isDirectionInverted: event.isDirectionInvertedFromDevice,
            navigation: navigation,
            interaction: interaction
        )
    }

    /// Core gesture evaluation pipeline taking raw deltas and phases.
    /// Allows direct, deterministic unit testing without requiring live WindowServer events.
    @discardableResult
    public func handleScrollDelta(
        deltaX: CGFloat,
        deltaY: CGFloat,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase = [],
        hasPreciseDeltas: Bool = true,
        isDirectionInverted: Bool = true,
        navigation: IslandNavigationModel = .shared,
        interaction: InteractionManager = .shared
    ) -> Bool {
        // Only active when expanded or pinned
        guard interaction.currentState == .expanded || interaction.currentState == .pinned else {
            return false
        }
        
        // Only trackpad gestures with precise deltas are eligible
        guard hasPreciseDeltas else {
            return false
        }
        
        // Ignore inertial momentum scroll events to prevent multiple page changes from one flick
        guard momentumPhase == [] else {
            return false
        }
        
        switch phase {
        case .began:
            accumulatedX = 0.0
            accumulatedY = 0.0
            hasTriggeredForCurrentGesture = false
            isLockedToVertical = false
            return false
            
        case .changed:
            accumulatedX += deltaX
            accumulatedY += deltaY
            
            // 1. Check if user is scrolling vertically (e.g. through System Activity)
            if abs(accumulatedY) >= verticalLockoutThreshold &&
               abs(accumulatedY) > abs(accumulatedX) * directionDominanceRatio {
                isLockedToVertical = true
                return false
            }
            
            // 2. If locked to vertical, do not allow page switching
            if isLockedToVertical {
                return false
            }
            
            // 3. Check for intentional horizontal swipe threshold
            if !hasTriggeredForCurrentGesture &&
               abs(accumulatedX) >= horizontalThreshold &&
               abs(accumulatedX) > abs(accumulatedY) * directionDominanceRatio {
                
                // Distinguish left vs right swipe:
                // With macOS Natural Scrolling enabled (isDirectionInverted == true):
                //   Moving fingers right-to-left (swipe left) produces negative deltaX.
                // With standard scrolling (isDirectionInverted == false):
                //   Moving fingers right-to-left (swipe left) produces positive deltaX.
                let isSwipeLeft = isDirectionInverted ? (accumulatedX < 0) : (accumulatedX > 0)
                
                hasTriggeredForCurrentGesture = true
                
                if Thread.isMainThread {
                    _ = withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        if isSwipeLeft {
                            navigation.goToNextPage()
                        } else {
                            navigation.goToPreviousPage()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        _ = withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                            if isSwipeLeft {
                                navigation.goToNextPage()
                            } else {
                                navigation.goToPreviousPage()
                            }
                        }
                    }
                }
                return true
            }
            return false
            
        case .ended, .cancelled:
            accumulatedX = 0.0
            accumulatedY = 0.0
            hasTriggeredForCurrentGesture = false
            isLockedToVertical = false
            return false
            
        default:
            return false
        }
    }
    
    /// Resets internal gesture state
    public func reset() {
        accumulatedX = 0.0
        accumulatedY = 0.0
        hasTriggeredForCurrentGesture = false
        isLockedToVertical = false
    }
}
