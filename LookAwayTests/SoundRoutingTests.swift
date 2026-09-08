import XCTest
@testable import LookAway

final class SoundRoutingTests: XCTestCase {
    func testMutedWarningDoesNotSuppressAnEnabledReminderSound() {
        var settings = AppSettings.defaults
        settings.soundOnReminder = true
        XCTAssertEqual(SoundEvent.selected(for: [.warning, .blinkReminder], settings: settings), .reminder)
    }

    func testSimultaneousEnabledSoundsChooseOnlyTheWarning() {
        var settings = AppSettings.defaults
        settings.soundOnWarning = true
        settings.soundOnReminder = true
        XCTAssertEqual(SoundEvent.selected(for: [.warning, .blinkReminder, .postureReminder], settings: settings), .warning)
        XCTAssertEqual(SoundEvent.selected(for: [.blinkReminder, .postureReminder], settings: settings), .reminder)
    }

    func testNoEnabledMatchingEventProducesNoSound() {
        XCTAssertNil(SoundEvent.selected(for: [.warning, .blinkReminder], settings: .defaults))
        var settings = AppSettings.defaults
        settings.soundOnWarning = true
        settings.soundOnReminder = true
        XCTAssertNil(SoundEvent.selected(for: [], settings: settings))
        XCTAssertNil(SoundEvent.selected(for: [.skippedBreak], settings: settings))
    }
}
