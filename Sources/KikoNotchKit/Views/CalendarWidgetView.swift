import SwiftUI
import AppKit

/// Calendar and Reminders widget in expanded island.
/// Implements PROD-001, PROD-002, PROD-003, and PROD-004.
public struct CalendarWidgetView: View {
    @ObservedObject public var calendarService: CalendarService
    @ObservedObject public var reminderService: ReminderService
    
    public init(
        calendarService: CalendarService? = nil,
        reminderService: ReminderService? = nil
    ) {
        self.calendarService = calendarService ?? CalendarService.shared
        self.reminderService = reminderService ?? ReminderService.shared
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Label("Today's Schedule", systemImage: "calendar")
                    .font(.system(size: 13, weight: .bold))
                
                Spacer()
                
                if let countdown = calendarService.nextEventCountdown {
                    Text(countdown)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                        .foregroundColor(.blue)
                }
            }
            
            // Calendar Permission Check
            if calendarService.authStatus == .denied || calendarService.authStatus == .restricted {
                permissionNotice(title: "Calendar Access Denied", subtitle: "Enable Calendar in System Settings to view your agenda.")
            } else if calendarService.authStatus == .notDetermined {
                requestPermissionButton(title: "Connect Calendar") {
                    Task { await calendarService.requestAccess() }
                }
            } else if calendarService.events.isEmpty {
                emptyAgendaView
            } else {
                VStack(spacing: 6) {
                    ForEach(calendarService.events.prefix(3)) { event in
                        eventRow(event)
                    }
                }
            }
            
            // Reminders Section
            if reminderService.authStatus == .authorized && !reminderService.reminders.isEmpty {
                Divider().opacity(0.3)
                
                HStack {
                    Label("\(reminderService.reminders.count) Reminders", systemImage: "checklist")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Open Reminders") {
                        if let url = URL(string: "x-apple-reminderkit://") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    private var emptyAgendaView: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
            Text("No more events scheduled for today.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func eventRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(formatTimeRange(start: event.startDate, end: event.endDate, isAllDay: event.isAllDay))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let loc = event.location, !loc.isEmpty {
                        Text("• \(loc)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
    }
    
    private func permissionNotice(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
    }
    
    private func requestPermissionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "lock.shield")
                Text(title)
            }
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
    
    private func formatTimeRange(start: Date, end: Date, isAllDay: Bool) -> String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
