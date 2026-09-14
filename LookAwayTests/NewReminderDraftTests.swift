import XCTest
@testable import LookAway

final class NewReminderDraftTests: XCTestCase {
    func testDefaultsAreEnabledAtFiveMinutes() {
        let draft = NewReminderDraft()
        XCTAssertEqual(draft.intervalMinutes, 5)
        XCTAssertTrue(draft.enabled)
        XCTAssertFalse(draft.canAdd)
    }

    func testBlankNameOrMessageCannotBeAdded() {
        XCTAssertFalse(NewReminderDraft(name: " ", message: "Drink", intervalMinutes: 5, enabled: true).canAdd)
        XCTAssertFalse(NewReminderDraft(name: "Water", message: "\n", intervalMinutes: 5, enabled: true).canAdd)
        XCTAssertTrue(NewReminderDraft(name: "Water", message: "Drink", intervalMinutes: 5, enabled: true).canAdd)
    }

    func testConversionCleansTextAndClampsInterval() {
        let reminder = NewReminderDraft(
            name: "  Water break ",
            message: "  Drink\n some water  ",
            intervalMinutes: 999,
            enabled: false
        ).reminder()
        XCTAssertEqual(reminder.name, "Water break")
        XCTAssertEqual(reminder.message, "Drink some water")
        XCTAssertEqual(reminder.intervalMinutes, 120)
        XCTAssertFalse(reminder.enabled)
    }
}
