import XCTest
@testable import LookAway

@MainActor
final class ReminderEditorTests: XCTestCase {
    func testEditorBlocksSaveForInvalidReminder() {
        var applied = 0
        let editor = SettingsEditor(settings: .defaults) { _ in applied += 1 }
        editor.draft.reminders[0].message = "   "
        XCTAssertEqual(editor.validationMessage, "Reminder message is required.")
        XCTAssertFalse(editor.canSave)
        XCTAssertFalse(editor.apply())
        XCTAssertEqual(applied, 0)
        XCTAssertEqual(editor.errorMessage, "Reminder message is required.")
    }

    func testEditorAddsDeletesAndReordersReminderDraftsOnly() {
        let editor = SettingsEditor(settings: .defaults) { _ in }
        let custom = Reminder(name: "Water", message: "Drink", intervalMinutes: 20, enabled: true)
        editor.addReminder(custom)
        XCTAssertEqual(editor.draft.reminders.last, custom)

        editor.moveReminder(id: custom.id, before: Reminder.blinkID)
        XCTAssertEqual(editor.draft.reminders.first?.id, custom.id)

        editor.moveReminderToEnd(id: custom.id)
        XCTAssertEqual(editor.draft.reminders.last?.id, custom.id)

        editor.removeReminder(id: custom.id)
        XCTAssertFalse(editor.draft.reminders.contains { $0.id == custom.id })
        XCTAssertEqual(editor.saved, .defaults)
    }

    func testCanSaveRequiresAChangeAndValidReminderDrafts() {
        let editor = SettingsEditor(settings: .defaults) { _ in }
        XCTAssertFalse(editor.canSave)
        editor.draft.workMinutes = 45
        XCTAssertTrue(editor.canSave)
        editor.draft.reminders[1].name = "\n"
        XCTAssertFalse(editor.canSave)
    }
}
