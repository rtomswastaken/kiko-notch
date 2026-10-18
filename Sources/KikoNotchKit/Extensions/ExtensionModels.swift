import Foundation

/// Metadata describing a modular Kiko Notch feature or extension.
/// Implements EXT-001 requirements for metadata, dependencies, and permission declarations.
public struct FeatureMetadata: Sendable, Codable, Equatable {
    public let id: KikoFeatureID
    public let name: String
    public let summary: String
    public let version: String
    public let author: String
    public let dependencies: [KikoFeatureID]
    public let requiredPermissions: [String]
    public let isAvailable: Bool
    
    public init(
        id: KikoFeatureID,
        name: String,
        summary: String,
        version: String = "1.0.0",
        author: String = "Kiko Team",
        dependencies: [KikoFeatureID] = [],
        requiredPermissions: [String] = [],
        isAvailable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.version = version
        self.author = author
        self.dependencies = dependencies
        self.requiredPermissions = requiredPermissions
        self.isAvailable = isAvailable
    }
}

/// Status representing lifecycle and runtime health of a registered module.
public enum ModuleExecutionStatus: Sendable, Equatable {
    case stopped
    case running
    case failed(reason: String)
    case missingDependency(KikoFeatureID)
}
