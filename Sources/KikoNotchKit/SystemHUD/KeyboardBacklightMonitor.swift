import Foundation
import Combine
import SwiftUI

/// Monitor for keyboard backlight changes.
/// Implements SYS-003.
public final class KeyboardBacklightMonitor: ObservableObject, @unchecked Sendable {
    public static let shared = KeyboardBacklightMonitor()
    
    @Published public var currentBacklight: Float = 0.5
    public var onBacklightChange: (@Sendable (Float) -> Void)?
    private var isListening: Bool = false
    
    public init() {}
    
    public func start() {
        guard !isListening else { return }
        isListening = true
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleBacklightNotification),
            name: NSNotification.Name("com.apple.keyboardBacklightEvent"),
            object: nil
        )
    }
    
    public func stop() {
        guard isListening else { return }
        isListening = false
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    @objc private func handleBacklightNotification(_ notification: Notification) {
        onBacklightChange?(currentBacklight)
    }
    
    public func setSimulatedBacklight(_ level: Float) {
        let clamped = max(0.0, min(1.0, level))
        self.currentBacklight = clamped
        onBacklightChange?(clamped)
    }
}
