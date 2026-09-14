import XCTest
@testable import LookAway

final class SoundRoutingTests: XCTestCase {
    private let reminderID = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
    private let secondReminderID = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!

    private func settingsWithCustomReminders() -> AppSettings {
        var settings = AppSettings.defaults
        settings.reminders = [
            Reminder(id: reminderID, name: "One", message: "One", intervalMinutes: 5, enabled: true),
            Reminder(id: secondReminderID, name: "Two", message: "Two", intervalMinutes: 10, enabled: true)
        ]
        return settings
    }

    func testMutedWarningDoesNotSuppressAnEnabledReminderSound() {
        var settings = settingsWithCustomReminders()
        settings.soundOnReminder = true
        XCTAssertEqual(SoundEvent.selected(for: [.warning, .reminder(reminderID)], settings: settings), .reminder)
    }

    func testSimultaneousEnabledSoundsChooseOnlyTheWarning() {
        var settings = settingsWithCustomReminders()
        settings.soundOnWarning = true
        settings.soundOnReminder = true
        XCTAssertEqual(
            SoundEvent.selected(for: [.warning, .reminder(reminderID), .reminder(secondReminderID)], settings: settings),
            .warning
        )
        XCTAssertEqual(
            SoundEvent.selected(for: [.reminder(reminderID), .reminder(secondReminderID)], settings: settings),
            .reminder
        )
    }

    func testDeletedDisabledAndUnknownReminderEventsProduceNoSound() {
        var settings = settingsWithCustomReminders()
        settings.soundOnReminder = true
        settings.reminders[1].enabled = false

        XCTAssertNil(SoundEvent.selected(for: [.reminder(secondReminderID)], settings: settings))
        XCTAssertNil(SoundEvent.selected(for: [.reminder(UUID())], settings: settings))

        settings.reminders.removeAll { $0.id == reminderID }
        XCTAssertNil(SoundEvent.selected(for: [.reminder(reminderID)], settings: settings))
    }

    func testNoEnabledMatchingEventProducesNoSound() {
        XCTAssertNil(SoundEvent.selected(for: [.warning, .reminder(reminderID)], settings: .defaults))
        var settings = settingsWithCustomReminders()
        settings.soundOnWarning = true
        settings.soundOnReminder = true
        XCTAssertNil(SoundEvent.selected(for: [], settings: settings))
        XCTAssertNil(SoundEvent.selected(for: [.skippedBreak], settings: settings))
    }
}
