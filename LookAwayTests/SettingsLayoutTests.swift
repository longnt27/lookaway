import Foundation
import XCTest
@testable import LookAway

final class SettingsLayoutTests: XCTestCase {
    func testSettingsAvoidAdaptiveFormLabelLayout() throws {
        let source = try source("LookAway/SettingsView.swift") + source("LookAway/SettingsComponents.swift")
        XCTAssertFalse(source.contains("Form {"), "Settings must not use macOS Form column sizing")
        XCTAssertFalse(source.contains("LabeledContent("), "Rows must own a stable shared label column")
    }

    func testSettingsUseFiveTabsWithWorkingHoursInGeneral() throws {
        let source = try source("LookAway/SettingsView.swift")
        XCTAssertTrue(source.contains("general.tabItem"))
        XCTAssertTrue(source.contains("breaks.tabItem"))
        XCTAssertTrue(source.contains("reminders.tabItem"))
        XCTAssertTrue(source.contains("appearance.tabItem"))
        XCTAssertTrue(source.contains("sounds.tabItem"))
        XCTAssertFalse(source.contains("schedule.tabItem"))
        XCTAssertFalse(source.contains("private var schedule"))
        XCTAssertTrue(source.contains("settingsSection(\"Working hours\")"))
    }

    func testReminderPresentationLivesInAppearanceNotReminderCards() throws {
        let settings = try source("LookAway/SettingsView.swift")
        let reminders = try source("LookAway/ReminderSettingsView.swift")
        XCTAssertTrue(settings.contains("settingsSection(\"Reminder presentation\")"))
        XCTAssertFalse(reminders.contains("Reminder presentation"))
        XCTAssertFalse(reminders.contains("settingsSection(\"Presentation\")"))
    }

    func testSettingsUseSharedCompactRows() throws {
        let settings = try source("LookAway/SettingsView.swift")
        let components = try source("LookAway/SettingsComponents.swift")
        XCTAssertTrue(components.contains("struct SettingsRow"))
        XCTAssertTrue(components.contains("static let labelWidth"))
        XCTAssertTrue(components.contains("struct SettingsNumericRow"))
        XCTAssertTrue(components.contains("struct SettingsPickerRow"))
        XCTAssertTrue(settings.contains("SettingsNumericRow("))
        XCTAssertTrue(settings.contains("SettingsPickerRow("))
        XCTAssertFalse(settings.contains("private let labelWidth"))
    }

    func testRemindersAreObjectDrivenCardsWithAddSheetAndDragHandle() throws {
        let source = try source("LookAway/ReminderSettingsView.swift")
        XCTAssertTrue(source.contains("ForEach($editor.draft.reminders)"))
        XCTAssertTrue(source.contains("Add Reminder"))
        XCTAssertTrue(source.contains(".sheet"))
        XCTAssertTrue(source.contains("draggable"))
        XCTAssertTrue(source.contains("dropDestination"))
        XCTAssertFalse(source.contains("settingsSection(\"Blink\")"))
        XCTAssertFalse(source.contains("settingsSection(\"Posture\")"))
    }

    func testSettingsDoNotContainExplanatoryHelperParagraphs() throws {
        let settings = try source("LookAway/SettingsView.swift")
        XCTAssertFalse(settings.contains("private func note("))
        XCTAssertFalse(settings.contains("note(\""))
    }

    private func source(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
