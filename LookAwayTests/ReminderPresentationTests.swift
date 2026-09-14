import XCTest
@testable import LookAway

final class ReminderPresentationTests: XCTestCase {
    func testDueReminderIdsResolveInSettingsOrder() {
        let first = Reminder(id: UUID(), name: "First", message: "One", intervalMinutes: 5, enabled: true)
        let second = Reminder(id: UUID(), name: "Second", message: "Two", intervalMinutes: 5, enabled: true)
        var settings = AppSettings.defaults
        settings.reminders = [second, first]
        let events: [BreakSchedule.Event] = [.reminder(first.id), .reminder(second.id)]
        XCTAssertEqual(ReminderPresentationResolver.message(for: events, settings: settings), "Two\nOne")
    }

    func testDeletedAndDisabledReminderIdsAreIgnored() {
        let active = Reminder(id: UUID(), name: "A", message: "Active", intervalMinutes: 5, enabled: true)
        let disabled = Reminder(id: UUID(), name: "B", message: "Disabled", intervalMinutes: 5, enabled: false)
        var settings = AppSettings.defaults
        settings.reminders = [active, disabled]
        let events: [BreakSchedule.Event] = [
            .reminder(disabled.id),
            .reminder(active.id),
            .reminder(UUID())
        ]
        XCTAssertEqual(ReminderPresentationResolver.message(for: events, settings: settings), "Active")
    }

    func testNoDueActiveReminderProducesNoPresentationMessage() {
        var settings = AppSettings.defaults
        settings.reminders = []
        XCTAssertNil(ReminderPresentationResolver.message(for: [.warning], settings: settings))
        XCTAssertNil(ReminderPresentationResolver.message(for: [.reminder(UUID())], settings: settings))
    }
}
