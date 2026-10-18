import Foundation

/// Fault-isolated extension runner and supervisor.
/// Implements EXT-003 (crash protection and graceful deactivation).
@MainActor
public final class ExtensionManager: ObservableObject {
    public static let shared = ExtensionManager()
    
    @Published public private(set) var deactivatedModules: [KikoFeatureID: String] = [:]
    
    private let registry: FeatureRegistry
    
    public init(registry: FeatureRegistry? = nil) {
        self.registry = registry ?? FeatureRegistry.shared
    }
    
    /// Safely executes an operation on a module with fault boundary.
    public func safelyExecute(id: KikoFeatureID, action: (any KikoModule) throws -> Void) {
        guard let module = registry.module(for: id) else { return }
        
        do {
            try action(module)
        } catch {
            NSLog("[ExtensionManager] ERROR: Module '\(module.displayName)' threw exception: \(error.localizedDescription). Safely deactivating.")
            deactivateFaultyModule(id, reason: error.localizedDescription)
        }
    }
    
    /// Safely starts a module with error isolation.
    public func safelyStart(id: KikoFeatureID) {
        safelyExecute(id: id) { module in
            module.start()
        }
    }
    
    /// Safely stops a module.
    public func safelyStop(id: KikoFeatureID) {
        safelyExecute(id: id) { module in
            module.stop()
        }
    }
    
    /// Deactivates a failing module without terminating Kiko Notch.
    public func deactivateFaultyModule(_ id: KikoFeatureID, reason: String) {
        guard let module = registry.module(for: id) else { return }
        module.stop()
        module.isEnabled = false
        deactivatedModules[id] = reason
    }
    
    public func recoverModule(_ id: KikoFeatureID) {
        deactivatedModules.removeValue(forKey: id)
        safelyStart(id: id)
    }
}
