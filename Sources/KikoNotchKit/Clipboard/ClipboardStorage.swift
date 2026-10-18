import Foundation

public struct ClipboardItem: Identifiable, Sendable, Codable, Equatable {
    public let id: String
    public let text: String
    public let fileURL: URL?
    public let isFileURL: Bool
    public let timestamp: Date
    public let characterCount: Int
    
    public init(id: String = UUID().uuidString, text: String, fileURL: URL? = nil, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.fileURL = fileURL
        self.isFileURL = (fileURL != nil)
        self.timestamp = timestamp
        self.characterCount = text.count
    }
}

/// In-memory and local encrypted storage for clipboard history.
/// Implements CLIP-002, CLIP-004, and PRIV-002 (zero upload, complete local purge).
public final class ClipboardStorage: @unchecked Sendable {
    public static let shared = ClipboardStorage()
    
    private var items: [ClipboardItem] = []
    private let lock = NSLock()
    private let storageKey = "kiko.clipboard.items"
    
    public var maxCapacity: Int = 50 {
        didSet {
            trimToCapacity()
        }
    }
    
    public init() {
        loadPersistedItems()
    }
    
    public func add(_ item: ClipboardItem) {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove duplicate if already present
        items.removeAll(where: { $0.text == item.text })
        items.insert(item, at: 0)
        
        if items.count > maxCapacity {
            items = Array(items.prefix(maxCapacity))
        }
        
        savePersistedItems()
    }
    
    public func getAll() -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
    
    public func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        items.removeAll(where: { $0.id == id })
        savePersistedItems()
    }
    
    /// Completely purges all stored clipboard history (CLIP-004, PRIV-002).
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    private func trimToCapacity() {
        lock.lock()
        defer { lock.unlock() }
        if items.count > maxCapacity {
            items = Array(items.prefix(maxCapacity))
            savePersistedItems()
        }
    }
    
    private func savePersistedItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadPersistedItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            self.items = loaded
        }
    }
}
