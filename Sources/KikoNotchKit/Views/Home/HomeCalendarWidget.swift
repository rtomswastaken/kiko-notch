//
//  HomeCalendarWidget.swift
//  KikoNotchKit
//
//  Redesigned two-column Calendar widget for the Home page right column:
//  - Left: Interactive monthly calendar with date selection, month navigation, and event indicators.
//  - Right: Synchronized events panel for the selected date with authorization handling.
//

import SwiftUI
import AppKit

public struct HomeCalendarWidget: View {
    @ObservedObject public var calendarService = CalendarService.shared
    @ObservedObject public var navigation = IslandNavigationModel.shared
    @ObservedObject public var themeManager = ThemeManager.shared

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()

    public init() {}

    private var calendar: Calendar {
        Calendar.current
    }

    private var selectedDayEvents: [CalendarEventItem] {
        calendarService.events(for: selectedDate)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Widget Header Row
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(themeManager.secondaryTextColor)

                Text("CALENDAR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.85))
                    .tracking(0.6)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let today = Date()
                        displayedMonth = today
                        selectedDate = today
                    }
                }) {
                    Text("TODAY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(calendar.isDateInToday(selectedDate) ? .white : themeManager.secondaryTextColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(calendar.isDateInToday(selectedDate) ? 0.16 : 0.05))
                        )
                }
                .buttonStyle(.plain)
                .help("Jump to Today")
            }

            // Two-Column Body: Monthly Calendar (Left) + Events (Right)
            HStack(alignment: .top, spacing: 10) {
                // Left Column: Interactive Month Grid
                monthlyCalendarView
                    .frame(width: 148)

                // Subtle Vertical Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)

                // Right Column: Events List for Selected Date
                eventsPanelView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer Shortcut to Calendar Application
            HStack {
                Spacer()
                Button(action: {
                    if let url = URL(string: "calshow:") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Open Calendar")
                            .font(.system(size: 8.5, weight: .medium))
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 7.5, weight: .semibold))
                    }
                    .foregroundColor(Color.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Open macOS Calendar Application")
            }
        }
        .padding(.horizontal, IslandSpacing.cardPaddingHorizontal)
        .padding(.vertical, IslandSpacing.cardPaddingVertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IslandSpacing.cardCornerRadius)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IslandSpacing.cardCornerRadius)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        .onAppear {
            calendarService.fetchEvents(forMonthContaining: displayedMonth)
        }
    }

    // MARK: - Monthly Calendar View (Left Column)

    @ViewBuilder
    private var monthlyCalendarView: some View {
        VStack(spacing: 4) {
            // Month Header with Prev/Next Navigation
            HStack(spacing: 4) {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Previous Month")

                Spacer()

                Text(monthYearString(from: displayedMonth))
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white)
                    .lineLimit(1)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Next Month")
            }
            .padding(.bottom, 2)

            // Weekday Headers (M T W T F S S)
            HStack(spacing: 0) {
                ForEach(weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                }
            }

            // Month Dates Grid
            let days = daysInDisplayedMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, dayDate in
                    if let date = dayDate {
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)
                        let hasEvents = !calendarService.events(for: date).isEmpty

                        Button(action: {
                            selectedDate = date
                        }) {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(Color.white.opacity(0.28))
                                } else if isToday {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                                }

                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 8.5, weight: isToday || isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected || isToday ? Color.white : Color.white.opacity(0.85))

                                if hasEvents && !isSelected {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.8))
                                        .frame(width: 2.5, height: 2.5)
                                        .offset(y: 6.5)
                                }
                            }
                            .frame(height: 16)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Empty slot for padding leading days
                        Color.clear
                            .frame(height: 16)
                    }
                }
            }
        }
    }

    // MARK: - Events Panel View (Right Column)

    @ViewBuilder
    private var eventsPanelView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Selected Day Label
            Text(selectedDateLabel())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
                .tracking(0.4)

            switch calendarService.authStatus {
            case .authorized:
                if selectedDayEvents.isEmpty {
                    VStack(spacing: 3) {
                        Spacer(minLength: 4)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.5))
                        Text("No Events Scheduled")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.9))
                        Text("Schedule is clear")
                            .font(.system(size: 8))
                            .foregroundColor(Color.white.opacity(0.65))
                        Spacer(minLength: 4)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(selectedDayEvents) { event in
                                HStack(alignment: .center, spacing: 5) {
                                    Text(event.formattedStartTime)
                                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color.white)
                                        .frame(width: 38, alignment: .leading)

                                    Circle()
                                        .fill(Color.white.opacity(0.6))
                                        .frame(width: 3, height: 3)

                                    Text(event.title)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.95))
                                        .lineLimit(1)

                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }

            case .notDetermined:
                VStack(spacing: 4) {
                    Spacer(minLength: 4)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.75))
                    Text("Connect Calendar")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color.white)

                    Button(action: {
                        Task {
                            _ = await calendarService.requestAccess()
                        }
                    }) {
                        Text(calendarService.isRequestingAccess ? "Connecting..." : "Allow Access")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(Color.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(calendarService.isRequestingAccess)

                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity)

            case .denied, .restricted:
                VStack(spacing: 3) {
                    Spacer(minLength: 4)
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 15))
                        .foregroundColor(.yellow.opacity(0.85))
                    Text("Calendar Access Denied")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)

                    Button(action: {
                        calendarService.openSystemSettings()
                    }) {
                        Text("Open System Settings")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(themeManager.primaryTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Date Helpers

    private func monthYearString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: date).uppercased()
    }

    private func selectedDateLabel() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: selectedDate).uppercased()
    }

    private func weekdaySymbols() -> [String] {
        // Return 1-letter symbols: M, T, W, T, F, S, S (locale-aware)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1 // 1-indexed in Calendar
        return Array(symbols[firstWeekday...] + symbols[..<firstWeekday])
    }

    private func daysInDisplayedMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = monthInterval.start

        // Calculate leading weekday offset
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let firstWeekday = calendar.firstWeekday
        let leadingSpaces = (weekdayOfFirst - firstWeekday + 7) % 7

        var items: [Date?] = Array(repeating: nil, count: leadingSpaces)

        guard let daysRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return items }
        for day in daysRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                items.append(date)
            }
        }
        return items
    }

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
            calendarService.fetchEvents(forMonthContaining: newMonth)
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
            calendarService.fetchEvents(forMonthContaining: newMonth)
        }
    }
}
