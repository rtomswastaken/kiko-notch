import Foundation
import Combine

public enum UpdateChannel: String, CaseIterable, Codable, Sendable {
    case stable = "Stable"
    case beta = "Beta"
}

public struct AppReleaseInfo: Sendable, Codable, Equatable {
    public let tagName: String
    public let name: String
    public let body: String
    public let htmlUrl: String
    public let isPrerelease: Bool
    public let publishedAt: Date
}

/// Update checker inspecting GitHub releases with channel selection.
/// Implements SET-007.
@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()
    
    @Published public var channel: UpdateChannel {
        didSet {
            UserDefaults.standard.set(channel.rawValue, forKey: "kiko.update.channel")
        }
    }
    
    @Published public private(set) var availableUpdate: AppReleaseInfo?
    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var lastCheckDate: Date?
    @Published public private(set) var statusMessage: String = "Up to date"
    
    private let urlSession: URLSession
    private let currentVersion = BrandAssets.appVersion
    
    public init(session: URLSession = .shared) {
        self.urlSession = session
        let stored = UserDefaults.standard.string(forKey: "kiko.update.channel")
            .flatMap { UpdateChannel(rawValue: $0) } ?? .stable
        self.channel = stored
    }
    
    public func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        
        lastCheckDate = Date()
        statusMessage = "Checking for updates..."
        
        guard let url = URL(string: "https://api.github.com/repos/antigravity/kiko-notch/releases") else {
            statusMessage = "Invalid update endpoint"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                statusMessage = "Unable to reach update server"
                return
            }
            
            guard let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                statusMessage = "Could not parse release information"
                return
            }
            
            for rel in releases {
                let tag = rel["tag_name"] as? String ?? ""
                let name = rel["name"] as? String ?? tag
                let body = rel["body"] as? String ?? ""
                let htmlUrl = rel["html_url"] as? String ?? ""
                let isPrerelease = rel["prerelease"] as? Bool ?? false
                
                // Filter by channel
                if channel == .stable && isPrerelease {
                    continue
                }
                
                let cleanTag = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                if isVersionNewer(candidate: cleanTag, current: currentVersion) {
                    let info = AppReleaseInfo(
                        tagName: tag,
                        name: name,
                        body: body,
                        htmlUrl: htmlUrl,
                        isPrerelease: isPrerelease,
                        publishedAt: Date()
                    )
                    self.availableUpdate = info
                    self.statusMessage = "New version \(tag) available!"
                    return
                }
            }
            
            self.availableUpdate = nil
            self.statusMessage = "Kiko Notch is up to date (v\(currentVersion))"
        } catch {
            statusMessage = "Update check failed: \(error.localizedDescription)"
        }
    }
    
    private func isVersionNewer(candidate: String, current: String) -> Bool {
        return candidate.compare(current, options: .numeric) == .orderedDescending
    }
}
