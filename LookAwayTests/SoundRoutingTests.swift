import XCTest
@testable import LookAway

final class SoundRoutingTests: XCTestCase {
    private let reminderID = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
    private let secondReminderID = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!

    func testMutedWarningDoesNotSuppressAnEnabledReminderSound() {
        var settings = AppSettings.defaults
        settings.soundOnReminder = true
        XCTAssertEqual(SoundEvent.selected(for: [.warning, .reminder(reminderID)], settings: settings), .reminder)
    }

    func testSimultaneousEnabledSoundsChooseOnlyTheWarning() {
        var settings = AppSettings.defaults
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

    func testNoEnabledMatchingEventProducesNoSound() {
        XCTAssertNil(SoundEvent.selected(for: [.warning, .reminder(reminderID)], settings: .defaults))
        var settings = AppSettings.defaults
        settings.soundOnWarning = true
        settings.soundOnReminder = true
        XCTAssertNil(SoundEvent.selected(for: [], settings: settings))
        XCTAssertNil(SoundEvent.selected(for: [.skippedBreak], settings: settings))
    }
}
