import XCTest
@testable import KikoNotchKit

// File-level test classes to avoid nested type scoping issues with XCTest macros
@MainActor
private final class BaseTestModule: KikoModule {
    let id: KikoFeatureID = .systemHUD
    let displayName: String = "Base HUD"
    var isEnabled: Bool = false
    func start() {}
    func stop() {}
}

@MainActor
private final class DependentTestModule: KikoModule {
    let id: KikoFeatureID = .battery
    let displayName: String = "Dependent Battery"
    var isEnabled: Bool = false
    func start() {}
    func stop() {}
}

@MainActor
private final class FaultyTestModule: KikoModule {
    let id: KikoFeatureID = .customActions
    let displayName: String = "Faulty Test Module"
    var isEnabled: Bool = true
    func start() {}
    func stop() {}
}

private struct TestModuleError: Error, LocalizedError {
    var errorDescription: String? { "Deliberate test failure" }
}

final class ExtensionAndFeatureTests: XCTestCase {
    
    // MARK: - Feature Registry Tests (EXT-001, SET-005)
    
    @MainActor
    func testFeatureRegistryDefaultModulesAndMetadata() {
        let registry = FeatureRegistry.shared
        
        // Ensure all core system features are registered
        XCTAssertNotNil(registry.module(for: .battery))
        XCTAssertNotNil(registry.module(for: .bluetooth))
        XCTAssertNotNil(registry.module(for: .calendar))
        XCTAssertNotNil(registry.module(for: .reminders))
        XCTAssertNotNil(registry.module(for: .weather))
        XCTAssertNotNil(registry.module(for: .downloads))
        XCTAssertNotNil(registry.module(for: .clipboard))
        XCTAssertNotNil(registry.module(for: .aiDashboard))
        XCTAssertNotNil(registry.module(for: .systemHUD))
        XCTAssertNotNil(registry.module(for: .notifications))
        
        let weatherMeta = registry.metadata(for: .weather)
        XCTAssertNotNil(weatherMeta)
        XCTAssertEqual(weatherMeta?.name, "Weather & Forecast")
        XCTAssertTrue(weatherMeta?.requiredPermissions.contains("NSLocationWhenInUseUsageDescription") ?? false)
    }
    
    @MainActor
    func testFeatureEnableAndDisable() {
        let registry = FeatureRegistry.shared
        
        registry.setModuleEnabled(.weather, enabled: false)
        XCTAssertFalse(registry.module(for: .weather)?.isEnabled ?? true)
        
        registry.setModuleEnabled(.weather, enabled: true)
        XCTAssertTrue(registry.module(for: .weather)?.isEnabled ?? false)
    }
    
    @MainActor
    func testDependencyValidation() {
        let registry = FeatureRegistry(registerDefaults: false)
        
        registry.register(BaseTestModule(), metadata: FeatureMetadata(
            id: .systemHUD,
            name: "Base HUD",
            summary: "Base"
        ))
        
        registry.register(DependentTestModule(), metadata: FeatureMetadata(
            id: .battery,
            name: "Dependent Battery",
            summary: "Requires Base HUD",
            dependencies: [.systemHUD]
        ))
        
        // Ensure .systemHUD is disabled in SettingsManager
        let wasEnabled = SettingsManager.shared.isFeatureEnabled(.systemHUD)
        if wasEnabled {
            SettingsManager.shared.toggleFeature(.systemHUD)
        }
        defer {
            if wasEnabled != SettingsManager.shared.isFeatureEnabled(.systemHUD) {
                SettingsManager.shared.toggleFeature(.systemHUD)
            }
        }
        
        let missing = registry.validateDependencies(for: .battery)
        XCTAssertTrue(missing.contains(.systemHUD))
    }
    
    // MARK: - Extension Manager Fault Isolation (EXT-003)
    
    @MainActor
    func testExtensionManagerCrashProtectionAndDeactivation() {
        let registry = FeatureRegistry(registerDefaults: false)
        registry.register(FaultyTestModule())
        let manager = ExtensionManager(registry: registry)
        
        // Execute throwing action inside fault boundary
        manager.safelyExecute(id: .customActions) { _ in
            throw TestModuleError()
        }
        
        // Verify module was deactivated cleanly without crashing the test runner or app
        XCTAssertNotNil(manager.deactivatedModules[.customActions])
        XCTAssertEqual(manager.deactivatedModules[.customActions], "Deliberate test failure")
        XCTAssertFalse(registry.module(for: .customActions)?.isEnabled ?? true)
        
        // Recover module
        manager.recoverModule(.customActions)
        XCTAssertNil(manager.deactivatedModules[.customActions])
    }
    
    // MARK: - Keychain Security Helper Tests (SEC-001)
    
    func testKeychainHelperCRUD() {
        let keychain = KeychainHelper.shared
        let testKey = "test_ai_token_\(UUID().uuidString)"
        let secretValue = "sk-test-secret-value-12345"
        
        // 1. Save secret
        let saved = keychain.save(key: testKey, value: secretValue)
        XCTAssertTrue(saved)
        
        // 2. Read secret
        let retrieved = keychain.read(key: testKey)
        XCTAssertEqual(retrieved, secretValue)
        
        // 3. Delete secret
        let deleted = keychain.delete(key: testKey)
        XCTAssertTrue(deleted)
        
        // 4. Verify gone
        XCTAssertNil(keychain.read(key: testKey))
    }
}
