import AppKit
import XCTest
@testable import LookAway

@MainActor
final class SettingsWindowLayoutTests: XCTestCase {
    func testSettingsWindowUsesCompactDefaultAndMinimumSize() throws {
        let controller = SettingsWindowController(settings: { .defaults }, onApply: { _ in })
        let window = try XCTUnwrap(controller.window)
        XCTAssertLessThanOrEqual(window.frame.width, 720)
        XCTAssertLessThanOrEqual(window.frame.height, 540)
        XCTAssertLessThanOrEqual(window.contentMinSize.width, 640)
        XCTAssertLessThanOrEqual(window.contentMinSize.height, 460)
        controller.close()
    }
}
