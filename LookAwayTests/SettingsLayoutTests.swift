import Foundation
import XCTest
@testable import LookAway

final class SettingsLayoutTests: XCTestCase {
    func testSettingsAvoidAdaptiveFormLabelLayout() throws {
        let source = try settingsViewSource()

        XCTAssertFalse(source.contains("Form {"), "Settings must not use macOS Form column sizing, which can collapse labels into narrow wrapping columns")
        XCTAssertFalse(source.contains("LabeledContent("), "Numeric setting rows must own their label width instead of inheriting adaptive form columns")
    }

    func testSettingsDoNotContainExplanatoryHelperParagraphs() throws {
        let source = try settingsViewSource()

        XCTAssertFalse(source.contains("private func note("), "Settings should keep only actionable warnings and errors, not explanatory helper paragraphs")
        XCTAssertFalse(source.contains("note(\""), "Settings should not ship gray helper copy")
    }

    private func settingsViewSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let settingsFile = repositoryRoot.appendingPathComponent("LookAway/SettingsView.swift")
        return try String(contentsOf: settingsFile, encoding: .utf8)
    }
}
