import AppKit
import XCTest
@testable import LookAway

@MainActor
final class BreakAndSettingsPolishTests: XCTestCase {
    func testActiveBreakCanBeSkippedWhenSkippingIsEnabled() throws {
        var settings = AppSettings.defaults
        settings.allowSkip = true
        settings.allowEarlyFinish = false

        let overlay = OverlayController(screens: { [] }, dismissalDuration: 0)
        var completed = 0
        overlay.show(
            mode: .breakSession(seconds: 30),
            settings: settings,
            onHide: { completed += 1 }
        )

        let id = try XCTUnwrap(overlay.presentationID)
        overlay.skipBreak(presentationID: id)

        XCTAssertNil(overlay.presentationID)
        XCTAssertEqual(completed, 1)
    }

    func testActiveBreakCannotBeSkippedWhenSkippingIsDisabled() throws {
        var settings = AppSettings.defaults
        settings.allowSkip = false
        settings.allowEarlyFinish = false

        let overlay = OverlayController(screens: { [] }, dismissalDuration: 0)
        var completed = 0
        overlay.show(
            mode: .breakSession(seconds: 30),
            settings: settings,
            onHide: { completed += 1 }
        )
        defer { overlay.hide(cleanupOnly: true) }

        let id = try XCTUnwrap(overlay.presentationID)
        overlay.skipBreak(presentationID: id)

        XCTAssertEqual(overlay.presentationID, id)
        XCTAssertEqual(completed, 0)
    }

    func testBreakOverlayExposesSkipBreakAction() throws {
        let source = try repositorySource("LookAway/OverlayView.swift")
        XCTAssertTrue(source.contains("Button(\"Skip Break\""))
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
