import AppKit
import XCTest
@testable import LookAway

@MainActor
final class BreakAndSettingsPolishTests: XCTestCase {
    func testWarningSkipConsumesImmediatelyAndStartsFreshWorkInterval() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertTrue(schedule.advance(at: 1740).contains(.warning))

        schedule.skipUpcomingBreak()
        XCTAssertEqual(schedule.advance(at: 1740), [.skippedBreak])
        XCTAssertEqual(schedule.remainingSeconds(at: 1740), 1800)

        XCTAssertEqual(schedule.advance(at: 1800), [])
        XCTAssertEqual(schedule.remainingSeconds(at: 1800), 1740)
        XCTAssertEqual(schedule.advance(at: 3540), [.startBreak])
    }

    func testBreakOverlayDoesNotExposeSkipBreakActionDuringActiveBreak() throws {
        let source = try repositorySource("LookAway/OverlayView.swift")
        XCTAssertFalse(source.contains("Button(\"Skip Break\""))
        XCTAssertFalse(source.contains("accessibilityIdentifier(\"skipBreak\")"))
    }

    func testOverlayControllerDoesNotWireAnActiveBreakSkipAction() throws {
        let source = try repositorySource("LookAway/OverlayController.swift")
        XCTAssertFalse(source.contains("onSkip:"))
    }

    func testSettingsWindowStaysCompactAfterContentIsMounted() throws {
        let login = LoginItemController(
            readStatus: { .enabled },
            register: {},
            unregister: {},
            openSystemSettings: {}
        )
        let controller = SettingsWindowController(
            settings: { .defaults },
            onApply: { _ in },
            login: login
        )
        defer { controller.close() }

        controller.showSettings()
        let window = try XCTUnwrap(controller.window)

        XCTAssertLessThanOrEqual(window.frame.width, 600)
        XCTAssertLessThanOrEqual(window.contentMinSize.width, 560)
    }

    func testSettingsDoNotShowApprovalWarningAfterLoginItemRegistration() throws {
        let source = try repositorySource("LookAway/SettingsView.swift")
        XCTAssertFalse(source.contains("Approval is needed in System Settings before LookAway can start at login."))
    }

    private func repositorySource(_ path: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(path),
            encoding: .utf8
        )
    }
}
