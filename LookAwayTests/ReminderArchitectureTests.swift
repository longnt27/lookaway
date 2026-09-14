import Foundation
import XCTest
@testable import LookAway

final class ReminderArchitectureTests: XCTestCase {
    func testRuntimeDoesNotDependOnHardcodedBlinkPostureFieldsOrEvents() throws {
        let runtime = try source("LookAway/BreakSchedule.swift")
            + source("LookAway/AppDelegate.swift")
            + source("LookAway/PresentationSupport.swift")
            + source("LookAway/SettingsView.swift")

        for forbidden in [
            "blinkEnabled", "blinkMinutes", "blinkMessage",
            "postureEnabled", "postureMinutes", "postureMessage",
            ".blinkReminder", ".postureReminder"
        ] {
            XCTAssertFalse(runtime.contains(forbidden), "Runtime still contains hardcoded reminder symbol: \(forbidden)")
        }
    }

    func testSchedulerDoesNotOwnReminderPresentationDuration() throws {
        let source = try source("LookAway/BreakSchedule.swift")
        XCTAssertFalse(source.contains("reminderSeconds"))
    }

    func testLegacyReminderNamesOnlyRemainAsMigrationKeysInAppSettings() throws {
        let source = try source("LookAway/AppSettings.swift")
        XCTAssertTrue(source.contains("LegacyReminderKeys"))
        XCTAssertFalse(source.contains("var blinkEnabled"))
        XCTAssertFalse(source.contains("var postureEnabled"))
        XCTAssertFalse(source.contains("var blinkMinutes"))
        XCTAssertFalse(source.contains("var postureMinutes"))
    }

    private func source(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
