import Foundation
import Security

/// Thread-safe helper for macOS Keychain Services.
/// Adheres to SEC-001: Encrypted storage for AI API keys and tokens. Zero plaintext logging or disk writes.
public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()
    
    private let serviceName = "com.kikonotch.apikeys"
    private let lock = NSLock()
    
    private init() {}
    
    /// Saves or updates a secret key in the macOS Keychain.
    @discardableResult
    public func save(key: String, value: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let data = value.data(using: .utf8) else { return false }
        
        // Remove existing item before adding
        _ = deleteItem(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Reads a secret key from the macOS Keychain.
    public func read(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Deletes a key from the macOS Keychain.
    @discardableResult
    public func delete(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return deleteItem(forKey: key)
    }
    
    private func deleteItem(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
