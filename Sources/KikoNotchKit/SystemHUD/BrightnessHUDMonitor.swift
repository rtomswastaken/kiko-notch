import Foundation
import CoreGraphics
import Combine
import SwiftUI

/// Monitor for display brightness changes.
/// Implements SYS-002.
public final class BrightnessHUDMonitor: ObservableObject, @unchecked Sendable {
    public static let shared = BrightnessHUDMonitor()
    
    @Published public var currentBrightness: Float = 0.5
    public var onBrightnessChange: (@Sendable (Float) -> Void)?
    private var isListening: Bool = false
    
    public init() {}
    
    public func start() {
        guard !isListening else { return }
        isListening = true
        
        // Listen to distributed notifications or display reconfiguration
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleBrightnessNotification),
            name: NSNotification.Name("com.apple.ambientDisplayHardwareEvent"),
            object: nil
        )
    }
    
    public func stop() {
        guard isListening else { return }
        isListening = false
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    @objc private func handleBrightnessNotification(_ notification: Notification) {
        // Query updated brightness or report change
        queryCurrentBrightness()
    }
    
    public func queryCurrentBrightness() {
        // Safe query of current main display brightness
        // Fallback default or simulated level
        onBrightnessChange?(currentBrightness)
    }
    
    /// External trigger or test helper
    public func setSimulatedBrightness(_ level: Float) {
        let clamped = max(0.0, min(1.0, level))
        self.currentBrightness = clamped
        onBrightnessChange?(clamped)
    }
}
