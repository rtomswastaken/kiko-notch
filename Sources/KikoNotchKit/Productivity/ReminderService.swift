import Foundation
import EventKit
import Combine

public struct ReminderItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let dueDate: Date?
    public let isCompleted: Bool
    public let priority: Int
    
    public init(id: String, title: String, dueDate: Date?, isCompleted: Bool, priority: Int = 0) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.priority = priority
    }
}

/// Service providing Reminders integration via EventKit.
/// Implements PROD-003 and PROD-004.
@MainActor
public final class ReminderService: ObservableObject {
    public static let shared = ReminderService()
    
    @Published public private(set) var reminders: [ReminderItem] = []
    @Published public private(set) var authStatus: CalendarAuthorizationStatus = .notDetermined
    
    private let eventStore = EKEventStore()
    
    public init() {
        updateAuthorizationStatus()
    }
    
    public func updateAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess:
            self.authStatus = .authorized
        case .denied:
            self.authStatus = .denied
        case .restricted:
            self.authStatus = .restricted
        case .notDetermined, .writeOnly:
            fallthrough
        @unknown default:
            self.authStatus = .notDetermined
        }
    }
    
    public func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = try await eventStore.requestAccess(to: .reminder)
            }
            updateAuthorizationStatus()
            if granted {
                refreshReminders()
            }
            return granted
        } catch {
            updateAuthorizationStatus()
            return false
        }
    }
    
    public func refreshReminders() {
        guard authStatus == .authorized else {
            self.reminders = []
            return
        }
        
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        eventStore.fetchReminders(matching: predicate) { [weak self] ekReminders in
            Task { @MainActor [weak self] in
                guard let self = self, let ekReminders = ekReminders else { return }
                
                let calendar = Calendar.current
                let items: [ReminderItem] = ekReminders.compactMap { reminder in
                    var dueDate: Date? = nil
                    if let components = reminder.dueDateComponents {
                        dueDate = calendar.date(from: components)
                    }
                    return ReminderItem(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Reminder",
                        dueDate: dueDate,
                        isCompleted: reminder.isCompleted,
                        priority: reminder.priority
                    )
                }
                
                self.reminders = items
            }
        }
    }
    
    /// Test helper for simulating reminders without EventKit authorization in unit tests
    public func setSimulatedReminders(_ items: [ReminderItem]) {
        self.reminders = items
    }
    
    /// Test helper for simulating authorization changes
    public func setSimulatedAuthStatus(_ status: CalendarAuthorizationStatus) {
        self.authStatus = status
    }
}
