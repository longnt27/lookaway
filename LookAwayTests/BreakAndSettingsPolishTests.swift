import AppKit
import XCTest
@testable import LookAway

@MainActor
final class BreakAndSettingsPolishTests: XCTestCase {
    func testWarningPopupExposesSkipBreakActionWhenSkippingIsAllowed() throws {
        let source = try repositorySource("LookAway/PopupBannerView.swift")
        XCTAssertTrue(source.contains("if settings.allowSkip"))
        XCTAssertTrue(source.contains("Button(\"Skip Break\""))
        XCTAssertTrue(source.contains("accessibilityIdentifier(\"skipUpcomingBreak\")"))
    }

    func testActiveBreakOverlayDoesNotExposeSkipBreakAction() throws {
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
