import XCTest
@testable import LookAway

final class ReminderSettingsTests: XCTestCase {
    func testFreshDefaultsSeedBlinkAndPostureAsOrdinaryReminders() {
        let reminders = AppSettings.defaults.reminders
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.map(\.name), ["Blink", "Posture"])
        XCTAssertEqual(reminders.map(\.message), ["Blink your eyes", "Adjust your posture"])
        XCTAssertEqual(reminders.map(\.intervalMinutes), [5, 10])
        XCTAssertEqual(reminders.map(\.enabled), [true, true])
    }

    func testEmptyReminderCollectionRoundTripsWithoutReseedingDefaults() throws {
        var settings = AppSettings.defaults
        settings.reminders = []
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.reminders, [])
    }

    func testReminderNormalizationPreservesIdsAndOrder() {
        let first = Reminder(id: UUID(), name: "  Water  ", message: "  Drink\nwater  ", intervalMinutes: 999, enabled: true)
        let second = Reminder(id: UUID(), name: "  Stretch ", message: String(repeating: "x", count: 200), intervalMinutes: -3, enabled: false)
        var settings = AppSettings.defaults
        settings.reminders = [first, second]
        let value = settings.normalized
        XCTAssertEqual(value.reminders.map(\.id), [first.id, second.id])
        XCTAssertEqual(value.reminders.map(\.name), ["Water", "Stretch"])
        XCTAssertEqual(value.reminders.map(\.message), ["Drink water", String(repeating: "x", count: 120)])
        XCTAssertEqual(value.reminders.map(\.intervalMinutes), [120, 1])
    }

    func testBlankReminderFieldsAreInvalidInsteadOfReceivingInventedFallbacks() {
        var settings = AppSettings.defaults
        settings.reminders = [Reminder(name: "   ", message: "Drink", intervalMinutes: 5, enabled: true)]
        XCTAssertEqual(settings.normalized.reminderValidationMessage, "Reminder name is required.")
        settings.reminders[0].name = "Water"
        settings.reminders[0].message = " \n "
        XCTAssertEqual(settings.normalized.reminderValidationMessage, "Reminder message is required.")
    }

    func testLegacyBlinkAndPostureFieldsMigrateIntoReminders() throws {
        let data = Data(#"{"blinkEnabled":false,"blinkMinutes":8,"blinkMessage":"Slow blink","postureEnabled":true,"postureMinutes":17,"postureMessage":"Sit tall"}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.reminders.map(\.name), ["Blink", "Posture"])
        XCTAssertEqual(settings.reminders.map(\.enabled), [false, true])
        XCTAssertEqual(settings.reminders.map(\.intervalMinutes), [8, 17])
        XCTAssertEqual(settings.reminders.map(\.message), ["Slow blink", "Sit tall"])
    }

    func testStoredReminderArrayWinsOverLegacyFields() throws {
        let custom = Reminder(id: UUID(), name: "Water", message: "Drink", intervalMinutes: 20, enabled: true)
        let encodedReminder = try JSONEncoder().encode([custom])
        let remindersJSON = String(decoding: encodedReminder, as: UTF8.self)
        let data = Data("{\"reminders\":\(remindersJSON),\"blinkEnabled\":true,\"postureEnabled\":true}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.reminders, [custom])
    }

    func testEncodedSettingsDoNotPersistLegacyBlinkPostureKeys() throws {
        let data = try JSONEncoder().encode(AppSettings.defaults)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(object["reminders"])
        XCTAssertNil(object["blinkEnabled"])
        XCTAssertNil(object["blinkMinutes"])
        XCTAssertNil(object["blinkMessage"])
        XCTAssertNil(object["postureEnabled"])
        XCTAssertNil(object["postureMinutes"])
        XCTAssertNil(object["postureMessage"])
    }

    @MainActor
    func testStoreRejectsBlankReminderFields() throws {
        let name = "LookAwayTests.reminders.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.defaults
        settings.reminders[0].message = "   "
        XCTAssertThrowsError(try store.save(settings)) { error in
            XCTAssertEqual(error as? SettingsValidationError, .invalidReminder("Reminder message is required."))
        }
        XCTAssertNil(defaults.object(forKey: SettingsStore.storageKey))
    }
}
