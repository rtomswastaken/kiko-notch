import Foundation
import SwiftUI

/// Feature Module Identifier enum matching the master specification
public enum KikoFeatureID: String, CaseIterable, Codable, Sendable {
    case media = "feature.media"
    case fileShelf = "feature.fileShelf"
    case systemHUD = "feature.systemHUD"
    case battery = "feature.battery"
    case bluetooth = "feature.bluetooth"
    case calendar = "feature.calendar"
    case reminders = "feature.reminders"
    case notifications = "feature.notifications"
    case weather = "feature.weather"
    case downloads = "feature.downloads"
    case clipboard = "feature.clipboard"
    case aiDashboard = "feature.aiDashboard"
    case customActions = "feature.customActions"
    case systemMetrics = "feature.systemMetrics"
}

/// Pluggable Extension & Module Interface
@MainActor
public protocol KikoModule: AnyObject {
    var id: KikoFeatureID { get }
    var displayName: String { get }
    var isEnabled: Bool { get set }
    func start()
    func stop()
}
