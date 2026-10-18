import SwiftUI
import AppKit

/// Dedicated Calendar & Reminders Productivity Tab View
public struct ProductivityTabView: View {
    @ObservedObject public var calendarService = CalendarService.shared
    @ObservedObject public var reminderService = ReminderService.shared
    @ObservedObject public var themeManager = ThemeManager.shared
    @State private var selectedSegment: Int = 0 // 0: Calendar, 1: Reminders
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Header Bar & Segment Selector
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: selectedSegment == 0 ? "calendar" : "checklist")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text(selectedSegment == 0 ? "Agenda & Events" : "Reminders")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Segment Toggle
                    HStack(spacing: 2) {
                        segmentButton(title: "Agenda", index: 0)
                        segmentButton(title: "Reminders", index: 1)
                    }
                    .padding(2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .padding(.horizontal, 4)
                
                if selectedSegment == 0 {
                    // Agenda Content
                    calendarSection
                } else {
                    // Reminders Content
                    remindersSection
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
    
    @ViewBuilder
    private func segmentButton(title: String, index: Int) -> some View {
        let isSelected = selectedSegment == index
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedSegment = index
            }
        }) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : themeManager.secondaryTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Group {
                        if isSelected {
                            Capsule().fill(Color.white.opacity(0.16))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var calendarSection: some View {
        VStack(spacing: 8) {
            // Permission State Check
            if calendarService.authStatus == .denied || calendarService.authStatus == .restricted {
                permissionNotice(title: "Calendar Access Denied", subtitle: "Enable Calendar in System Settings to display your daily schedule.")
            } else if calendarService.authStatus == .notDetermined {
                connectBanner(title: "Grant Calendar Access", subtitle: "View your Apple Calendar agenda and countdowns in Kiko Notch.") {
                    Task { await calendarService.requestAccess() }
                }
            } else if calendarService.events.isEmpty {
                emptyAgendaCard
            } else {
                // Live Countdown Banner if available
                if let countdown = calendarService.nextEventCountdown {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text("Next Event:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text(countdown)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.1)))
                }
                
                // Event Items
                ForEach(calendarService.events) { event in
                    eventRow(event)
                }
            }
        }
    }
    
    @ViewBuilder
    private var remindersSection: some View {
        VStack(spacing: 8) {
            if reminderService.authStatus == .denied || reminderService.authStatus == .restricted {
                permissionNotice(title: "Reminders Access Denied", subtitle: "Enable Reminders in System Settings to track your tasks.")
            } else if reminderService.authStatus == .notDetermined {
                connectBanner(title: "Grant Reminders Access", subtitle: "Sync Apple Reminders and task checklists inside Kiko Notch.") {
                    Task { await reminderService.requestAccess() }
                }
            } else if reminderService.reminders.isEmpty {
                emptyRemindersCard
            } else {
                ForEach(reminderService.reminders) { item in
                    reminderRow(item)
                }
            }
        }
    }
    
    @ViewBuilder
    private func eventRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 10) {
            // Calendar Color Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.calendarColor))
                .frame(width: 3, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(formatTimeRange(start: event.startDate, end: event.endDate, isAllDay: event.isAllDay))
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    if let location = event.location, !location.isEmpty {
                        Text("· \(location)")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func reminderRow(_ item: ReminderItem) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                Task { await reminderService.toggleCompleted(for: item.id) }
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(item.isCompleted ? .green : themeManager.secondaryTextColor)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? themeManager.secondaryTextColor : themeManager.primaryTextColor)
                    .lineLimit(1)
                
                if let due = item.dueDate {
                    let isOverdue = !item.isCompleted && due < Date()
                    HStack(spacing: 4) {
                        if isOverdue {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.red)
                        }
                        Text(formatDate(due))
                            .font(.system(size: 9))
                            .foregroundColor(isOverdue ? .red : themeManager.secondaryTextColor)
                    }
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private var emptyAgendaCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 22))
                .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
            Text("No Scheduled Events")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.primaryTextColor)
            Text("Your calendar is completely clear for the rest of today")
                .font(.system(size: 10))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    @ViewBuilder
    private var emptyRemindersCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
            Text("All Caught Up")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.primaryTextColor)
            Text("No pending or overdue reminders")
                .font(.system(size: 10))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    @ViewBuilder
    private func permissionNotice(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.system(size: 18))
                .foregroundColor(.yellow)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.primaryTextColor)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    @ViewBuilder
    private func connectBanner(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.primaryTextColor)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text("Grant Access")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
    
    private func formatTimeRange(start: Date, end: Date, isAllDay: Bool) -> String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
