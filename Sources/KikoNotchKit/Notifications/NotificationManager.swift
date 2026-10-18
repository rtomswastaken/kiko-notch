import Foundation
import UserNotifications
import Combine

public struct IslandBannerItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let systemImage: String
    public let isCritical: Bool
    public let timestamp: Date
    
    public init(id: String = UUID().uuidString, title: String, subtitle: String? = nil, systemImage: String, isCritical: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isCritical = isCritical
        self.timestamp = Date()
    }
}

/// Notification manager coordinating system notifications and in-island alerts.
/// Implements NOTIF-001, NOTIF-002, and NOTIF-003.
@MainActor
public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()
    
    @Published public private(set) var activeBanner: IslandBannerItem?
    @Published public private(set) var isFocusModeActive: Bool = false
    
    private var bannerQueue: [IslandBannerItem] = []
    private var dismissTimer: Timer?
    
    public init() {
        checkFocusMode()
    }
    
    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    /// Posts a native macOS Notification Center notification (NOTIF-001).
    public func postSystemNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        guard !isFocusModeActive else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[NotificationManager] System notification error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Posts an in-island alert banner (NOTIF-002) subject to Focus Mode awareness (NOTIF-003).
    public func postIslandBanner(_ banner: IslandBannerItem) {
        // If Focus Mode is active, only critical notifications (e.g. low battery) are displayed
        if isFocusModeActive && !banner.isCritical {
            return
        }
        
        if activeBanner == nil {
            presentBanner(banner)
        } else {
            bannerQueue.append(banner)
        }
    }
    
    private func presentBanner(_ banner: IslandBannerItem) {
        activeBanner = banner
        
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissActiveBanner()
            }
        }
    }
    
    public func dismissActiveBanner() {
        activeBanner = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        if !bannerQueue.isEmpty {
            let next = bannerQueue.removeFirst()
            presentBanner(next)
        }
    }
    
    public func setFocusModeActive(_ active: Bool) {
        self.isFocusModeActive = active
    }
    
    private func checkFocusMode() {
        // macOS Do Not Disturb state detection
        // Can be set manually or via system distributed notifications
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.notificationcenter.dndstatuschange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isFocusModeActive = false
            }
        }
    }
}
