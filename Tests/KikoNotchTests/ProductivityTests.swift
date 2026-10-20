import XCTest
@testable import KikoNotchKit

final class ProductivityTests: XCTestCase {

    // MARK: - Calendar Tests (PROD-001, PROD-002, PROD-004)

    @MainActor
    func testCalendarEventItemAndCountdown() {
        let now = Date()
        let inFifteenMin = now.addingTimeInterval(15 * 60)
        let inFortyFiveMin = inFifteenMin.addingTimeInterval(30 * 60)

        let event = CalendarEventItem(
            id: "evt-1",
            title: "Sprint Planning",
            startDate: inFifteenMin,
            endDate: inFortyFiveMin,
            isAllDay: false,
            location: "Room 402"
        )

        XCTAssertEqual(event.title, "Sprint Planning")
        XCTAssertEqual(event.location, "Room 402")
        XCTAssertFalse(event.isAllDay)
        XCTAssertTrue(event.countdownDescription.contains("In 15m") || event.countdownDescription.contains("In 14m"))
    }

    @MainActor
    func testCalendarOngoingEventCountdown() {
        let now = Date()
        let startedTenAgo = now.addingTimeInterval(-10 * 60)
        let endsInTwenty = now.addingTimeInterval(20 * 60)

        let event = CalendarEventItem(
            id: "evt-ongoing",
            title: "Team Standup",
            startDate: startedTenAgo,
            endDate: endsInTwenty,
            isAllDay: false
        )

        XCTAssertEqual(event.countdownDescription, "Now: Team Standup")
    }

    @MainActor
    func testCalendarServiceSimulatedEventsAndEmptyState() {
        let service = CalendarService()

        // 1. Empty calendar
        service.setSimulatedEvents([])
        XCTAssertTrue(service.events.isEmpty)
        XCTAssertNil(service.nextEventCountdown)

        // 2. Multiple upcoming events
        let now = Date()
        let ev1 = CalendarEventItem(
            id: "1",
            title: "1:1 with Manager",
            startDate: now.addingTimeInterval(25 * 60),
            endDate: now.addingTimeInterval(55 * 60),
            isAllDay: false
        )
        let ev2 = CalendarEventItem(
            id: "2",
            title: "All Hands",
            startDate: now.addingTimeInterval(120 * 60),
            endDate: now.addingTimeInterval(180 * 60),
            isAllDay: false
        )
        service.setSimulatedEvents([ev1, ev2])

        XCTAssertEqual(service.events.count, 2)
        XCTAssertNotNil(service.nextEventCountdown)
        XCTAssertTrue(service.nextEventCountdown?.contains("1:1 with Manager") ?? false)
    }

    @MainActor
    func testCalendarAuthorizationStates() {
        let service = CalendarService()

        service.setSimulatedAuthStatus(.denied)
        XCTAssertEqual(service.authStatus, .denied)

        service.setSimulatedAuthStatus(.authorized)
        XCTAssertEqual(service.authStatus, .authorized)

        service.setSimulatedAuthStatus(.restricted)
        XCTAssertEqual(service.authStatus, .restricted)
    }

    // MARK: - Reminders Tests (PROD-003, PROD-004)

    @MainActor
    func testReminderItemProperties() {
        let dueDate = Date().addingTimeInterval(3600)
        let reminder = ReminderItem(
            id: "rem-1",
            title: "Submit PR Review",
            dueDate: dueDate,
            isCompleted: false,
            priority: 1
        )

        XCTAssertEqual(reminder.id, "rem-1")
        XCTAssertEqual(reminder.title, "Submit PR Review")
        XCTAssertEqual(reminder.dueDate, dueDate)
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertEqual(reminder.priority, 1)
    }

    @MainActor
    func testReminderServiceSimulatedReminders() {
        let service = ReminderService()

        let rem1 = ReminderItem(id: "r1", title: "Update documentation", dueDate: nil, isCompleted: false)
        let rem2 = ReminderItem(id: "r2", title: "Deploy build", dueDate: nil, isCompleted: false)

        service.setSimulatedReminders([rem1, rem2])
        XCTAssertEqual(service.reminders.count, 2)
        XCTAssertEqual(service.reminders.first?.title, "Update documentation")

        service.setSimulatedAuthStatus(.denied)
        XCTAssertEqual(service.authStatus, .denied)
    }

    // MARK: - Monthly Calendar Date Calculations & Filtering

    @MainActor
    func testCalendarMonthlyFilteringAndLeapYearCalculations() {
        let service = CalendarService()
        let cal = Calendar.current

        var leapComponents = DateComponents()
        leapComponents.year = 2024
        leapComponents.month = 2
        leapComponents.day = 29
        leapComponents.hour = 14
        leapComponents.minute = 0
        guard let leapDate = cal.date(from: leapComponents) else {
            XCTFail("Failed to construct leap date")
            return
        }

        var marchComponents = DateComponents()
        marchComponents.year = 2024
        marchComponents.month = 3
        marchComponents.day = 1
        marchComponents.hour = 10
        guard let marchDate = cal.date(from: marchComponents) else {
            XCTFail("Failed to construct march date")
            return
        }

        let leapEvt = CalendarEventItem(
            id: "leap-1",
            title: "Leap Day Retrospective",
            startDate: leapDate,
            endDate: leapDate.addingTimeInterval(3600),
            isAllDay: false
        )
        let marchEvt = CalendarEventItem(
            id: "march-1",
            title: "Monthly Kickoff",
            startDate: marchDate,
            endDate: marchDate.addingTimeInterval(3600),
            isAllDay: false
        )

        service.setSimulatedEvents([leapEvt, marchEvt])

        // Filter for Feb 29
        let febEvents = service.events(for: leapDate)
        XCTAssertEqual(febEvents.count, 1)
        XCTAssertEqual(febEvents.first?.title, "Leap Day Retrospective")
        XCTAssertTrue(service.hasEvents(on: leapDate))

        // Filter for March 1
        let marEvents = service.events(for: marchDate)
        XCTAssertEqual(marEvents.count, 1)
        XCTAssertEqual(marEvents.first?.title, "Monthly Kickoff")
        XCTAssertTrue(service.hasEvents(on: marchDate))

        // Day with no events
        var emptyComponents = DateComponents()
        emptyComponents.year = 2024
        emptyComponents.month = 2
        emptyComponents.day = 28
        if let emptyDate = cal.date(from: emptyComponents) {
            XCTAssertTrue(service.events(for: emptyDate).isEmpty)
            XCTAssertFalse(service.hasEvents(on: emptyDate))
        }
    }
}
