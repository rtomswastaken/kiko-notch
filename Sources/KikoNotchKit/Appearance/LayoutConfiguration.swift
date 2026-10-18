import Foundation

/// Module layout order and visibility preferences
public struct LayoutConfiguration: Codable, Sendable, Equatable {
    public enum ModuleSlot: String, CaseIterable, Codable, Sendable {
        case media = "Media"
        case fileShelf = "File Shelf"
        case quickActions = "Quick Actions"
        case aiStatus = "AI Dashboard"
        case systemStatus = "System Status"
    }
    
    public var visibleModules: [ModuleSlot]
    public var compactMode: Bool
    
    public static let standard = LayoutConfiguration(
        visibleModules: [
            .media,
            .fileShelf,
            .quickActions,
            .aiStatus,
            .systemStatus
        ],
        compactMode: false
    )
    
    public mutating func moveModule(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < visibleModules.count, destinationIndex <= visibleModules.count else { return }
        let module = visibleModules.remove(at: sourceIndex)
        visibleModules.insert(module, at: destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex)
    }
    
    public mutating func toggleVisibility(for slot: ModuleSlot) {
        if let idx = visibleModules.firstIndex(of: slot) {
            visibleModules.remove(at: idx)
        } else {
            visibleModules.append(slot)
        }
    }
}
