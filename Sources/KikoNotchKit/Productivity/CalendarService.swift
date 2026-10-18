import Foundation
import EventKit
import Combine
import AppKit

public struct CalendarEventItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    
    public var calendarColor: NSColor {
        .systemBlue
    }
    
    public var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    public var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endDate)
    }
    
    public init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
    }
    
    public var countdownDescription: String {
        let now = Date()
        if now >= startDate && now <= endDate {
            return "Now: \(title)"
        }
        
        let diffMinutes = Int(startDate.timeIntervalSince(now) / 60)
        if diffMinutes < 1 {
            return "Starting now: \(title)"
        } else if diffMinutes < 60 {
            return "In \(diffMinutes)m: \(title)"
        } else {
            let hours = diffMinutes / 60
            let mins = diffMinutes % 60
            if mins == 0 {
                return "In \(hours)h: \(title)"
            } else {
                return "In \(hours)h \(mins)m: \(title)"
            }
        }
    }
}

public enum CalendarAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Service providing Calendar integration via EventKit.
/// Implements PROD-001, PROD-002, and PROD-004.
@MainActor
public final class CalendarService: ObservableObject {
    public static let shared = CalendarService()
    
    @Published public private(set) var events: [CalendarEventItem] = []
    @Published public private(set) var nextEventCountdown: String?
    @Published public private(set) var authStatus: CalendarAuthorizationStatus = .notDetermined
    
    private let eventStore = EKEventStore()
    
    public init() {
        updateAuthorizationStatus()
    }
    
    public func updateAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
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
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            updateAuthorizationStatus()
            if granted {
                refreshEvents()
            }
            return granted
        } catch {
            updateAuthorizationStatus()
            return false
        }
    }
    
    public func refreshEvents() {
        guard authStatus == .authorized else {
            self.events = []
            self.nextEventCountdown = nil
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let rawEvents = eventStore.events(matching: predicate)
        
        let items = rawEvents
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEventItem(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? "Event",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    location: $0.location
                )
            }
        
        self.events = items
        
        // Find next upcoming or ongoing event
        let now = Date()
        if let next = items.first(where: { $0.endDate > now }) {
            self.nextEventCountdown = next.countdownDescription
        } else {
            self.nextEventCountdown = nil
        }
    }
    
    /// Test helper for simulating events without EventKit authorization in unit tests
    public func setSimulatedEvents(_ items: [CalendarEventItem]) {
        self.events = items
        let now = Date()
        if let next = items.first(where: { $0.endDate > now }) {
            self.nextEventCountdown = next.countdownDescription
        } else {
            self.nextEventCountdown = nil
        }
    }
    
    /// Test helper for simulating authorization changes
    public func setSimulatedAuthStatus(_ status: CalendarAuthorizationStatus) {
        self.authStatus = status
    }
}
