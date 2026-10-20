import Foundation
import AppKit
import UniformTypeIdentifiers

/// Supported File Transfer Destination Types
public enum SendDestinationType: String, CaseIterable, Codable, Sendable {
    case airDrop = "AirDrop"
    case blip = "Blip"
    case customApp = "Custom Application"
}

/// Metadata describing a resolved transfer destination
public struct SendDestinationInfo: Sendable {
    public let type: SendDestinationType
    public let name: String
    public let icon: NSImage
    public let systemSymbolName: String?
    public let isAvailable: Bool
    public let statusDescription: String
    public let appURL: URL?
    
    public init(
        type: SendDestinationType,
        name: String,
        icon: NSImage,
        systemSymbolName: String? = nil,
        isAvailable: Bool = true,
        statusDescription: String = "Available",
        appURL: URL? = nil
    ) {
        self.type = type
        self.name = name
        self.icon = icon
        self.systemSymbolName = systemSymbolName
        self.isAvailable = isAvailable
        self.statusDescription = statusDescription
        self.appURL = appURL
    }
}

/// Errors occurring during file dispatch or validation
public enum FileSenderError: LocalizedError, Equatable {
    case emptyFileList
    case fileNotFound(String)
    case destinationUnavailable(String)
    case transferFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyFileList:
            return "No files were selected for transfer."
        case .fileNotFound(let path):
            return "File could not be found or accessed: \(path)"
        case .destinationUnavailable(let reason):
            return "Destination unavailable: \(reason)"
        case .transferFailed(let reason):
            return "Transfer failed: \(reason)"
        }
    }
}

/// Native macOS file handoff and transfer coordinator
public final class FileSenderService: ObservableObject, @unchecked Sendable {
    public static let shared = FileSenderService()
    
    @Published public private(set) var lastTransferStatus: String?
    @Published public private(set) var lastTransferError: FileSenderError?
    
    private init() {}
    
    // MARK: - Destination Resolution
    
    /// Resolves destination metadata based on configured settings
    public func resolveDestination(
        type: SendDestinationType,
        customAppURL: URL?
    ) -> SendDestinationInfo {
        switch type {
        case .airDrop:
            let symbol = "airdrop"
            let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: "AirDrop")
                ?? NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "AirDrop")
                ?? NSWorkspace.shared.icon(for: .folder)
            
            return SendDestinationInfo(
                type: .airDrop,
                name: "AirDrop",
                icon: icon,
                systemSymbolName: symbol,
                isAvailable: true,
                statusDescription: "Ready to share via AirDrop"
            )
            
        case .blip:
            if let blipURL = findBlipApplication() {
                let icon = NSWorkspace.shared.icon(forFile: blipURL.path)
                return SendDestinationInfo(
                    type: .blip,
                    name: "Blip",
                    icon: icon,
                    systemSymbolName: nil,
                    isAvailable: true,
                    statusDescription: "Handoff to Blip",
                    appURL: blipURL
                )
            } else {
                let fallbackIcon = NSImage(systemSymbolName: "paperplane.circle.fill", accessibilityDescription: "Blip")
                    ?? NSWorkspace.shared.icon(for: .application)
                return SendDestinationInfo(
                    type: .blip,
                    name: "Blip",
                    icon: fallbackIcon,
                    systemSymbolName: "exclamationmark.triangle",
                    isAvailable: false,
                    statusDescription: "Blip is not installed on this Mac",
                    appURL: nil
                )
            }
            
        case .customApp:
            if let customURL = customAppURL, FileManager.default.fileExists(atPath: customURL.path) {
                let appName = (try? customURL.resourceValues(forKeys: [.localizedNameKey]).localizedName)
                    ?? customURL.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: customURL.path)
                return SendDestinationInfo(
                    type: .customApp,
                    name: appName,
                    icon: icon,
                    systemSymbolName: nil,
                    isAvailable: true,
                    statusDescription: "Open in \(appName)",
                    appURL: customURL
                )
            } else {
                let fallbackIcon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "Custom Application")
                    ?? NSWorkspace.shared.icon(for: .application)
                return SendDestinationInfo(
                    type: .customApp,
                    name: "Custom App",
                    icon: fallbackIcon,
                    systemSymbolName: "exclamationmark.triangle",
                    isAvailable: false,
                    statusDescription: "Application not configured in Settings",
                    appURL: nil
                )
            }
        }
    }
    
    /// Checks for standard or custom locations of Blip.app
    public func findBlipApplication() -> URL? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.blip.macos") {
            return appURL
        }
        let standardPath = "/Applications/Blip.app"
        if FileManager.default.fileExists(atPath: standardPath) {
            return URL(fileURLWithPath: standardPath)
        }
        let userPath = ("~/Applications/Blip.app" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: userPath) {
            return URL(fileURLWithPath: userPath)
        }
        return nil
    }
    
    // MARK: - Sending Workflow
    
    /// Sends the provided URLs to the target destination
    public func send(
        urls: [URL],
        destination: SendDestinationInfo,
        from view: NSView? = nil,
        rect: NSRect? = nil,
        completion: (@Sendable (Result<Int, FileSenderError>) -> Void)? = nil
    ) {
        guard !urls.isEmpty else {
            let error = FileSenderError.emptyFileList
            DispatchQueue.main.async {
                self.lastTransferError = error
                self.lastTransferStatus = error.localizedDescription
                completion?(.failure(error))
            }
            return
        }
        
        // 1. Validate all files exist and are accessible
        for url in urls {
            let path = url.path
            guard FileManager.default.fileExists(atPath: path) else {
                let error = FileSenderError.fileNotFound(path)
                DispatchQueue.main.async {
                    self.lastTransferError = error
                    self.lastTransferStatus = error.localizedDescription
                    completion?(.failure(error))
                }
                return
            }
        }
        
        // 2. Validate destination availability
        guard destination.isAvailable else {
            let error = FileSenderError.destinationUnavailable(destination.statusDescription)
            DispatchQueue.main.async {
                self.lastTransferError = error
                self.lastTransferStatus = error.localizedDescription
                completion?(.failure(error))
            }
            return
        }
        
        // 3. Initiate native handoff mechanism based on destination type
        switch destination.type {
        case .airDrop:
            sendViaAirDrop(urls: urls, from: view, rect: rect, completion: completion)
            
        case .blip:
            if let blipURL = destination.appURL {
                sendViaApplication(urls: urls, appURL: blipURL, appName: "Blip", completion: completion)
            } else {
                let error = FileSenderError.destinationUnavailable("Blip.app location could not be determined.")
                DispatchQueue.main.async {
                    self.lastTransferError = error
                    self.lastTransferStatus = error.localizedDescription
                    completion?(.failure(error))
                }
            }
            
        case .customApp:
            if let appURL = destination.appURL {
                sendViaApplication(urls: urls, appURL: appURL, appName: destination.name, completion: completion)
            } else {
                let error = FileSenderError.destinationUnavailable("Selected application path is invalid.")
                DispatchQueue.main.async {
                    self.lastTransferError = error
                    self.lastTransferStatus = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Native Sharing Implementations
    
    private func sendViaAirDrop(
        urls: [URL],
        from view: NSView?,
        rect: NSRect?,
        completion: (@Sendable (Result<Int, FileSenderError>) -> Void)?
    ) {
        DispatchQueue.main.async {
            // Attempt direct NSSharingService AirDrop handoff
            if let airDropService = NSSharingService(named: .sendViaAirDrop),
               airDropService.canPerform(withItems: urls) {
                airDropService.perform(withItems: urls)
                self.lastTransferError = nil
                self.lastTransferStatus = "AirDrop initiated for \(urls.count) file(s)"
                completion?(.success(urls.count))
            } else if let view = view {
                // Fallback to NSSharingServicePicker anchored to view
                let picker = NSSharingServicePicker(items: urls)
                let anchorRect = rect ?? view.bounds
                picker.show(relativeTo: anchorRect, of: view, preferredEdge: .minY)
                self.lastTransferError = nil
                self.lastTransferStatus = "AirDrop picker presented"
                completion?(.success(urls.count))
            } else {
                // Perform generic sharing service if view anchor unavailable
                let picker = NSSharingServicePicker(items: urls)
                if let keyWindow = NSApplication.shared.keyWindow?.contentView {
                    picker.show(relativeTo: keyWindow.bounds, of: keyWindow, preferredEdge: .minY)
                    self.lastTransferError = nil
                    self.lastTransferStatus = "AirDrop picker presented"
                    completion?(.success(urls.count))
                } else {
                    let error = FileSenderError.transferFailed("Unable to present AirDrop sharing interface.")
                    self.lastTransferError = error
                    self.lastTransferStatus = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }
    
    private func sendViaApplication(
        urls: [URL],
        appURL: URL,
        appName: String,
        completion: (@Sendable (Result<Int, FileSenderError>) -> Void)?
    ) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config) { app, error in
            DispatchQueue.main.async {
                if let error = error {
                    let sendErr = FileSenderError.transferFailed("Failed to open files in \(appName): \(error.localizedDescription)")
                    self.lastTransferError = sendErr
                    self.lastTransferStatus = sendErr.localizedDescription
                    completion?(.failure(sendErr))
                } else {
                    self.lastTransferError = nil
                    let count = urls.count
                    let msg = "Handed off \(count) item(s) to \(appName)"
                    self.lastTransferStatus = msg
                    completion?(.success(count))
                }
            }
        }
    }
}
