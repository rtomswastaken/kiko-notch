import Foundation

/// Monitor for keyboard backlight changes.
/// Implements SYS-003.
public final class KeyboardBacklightMonitor: @unchecked Sendable {
    public static let shared = KeyboardBacklightMonitor()
    
    public var onBacklightChange: (@Sendable (Float) -> Void)?
    private var isListening: Bool = false
    private var currentLevel: Float = 0.5
    
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
        onBacklightChange?(currentLevel)
    }
    
    public func setSimulatedBacklight(_ level: Float) {
        currentLevel = max(0.0, min(1.0, level))
        onBacklightChange?(currentLevel)
    }
}
