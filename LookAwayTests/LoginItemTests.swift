import XCTest
@testable import LookAway

@MainActor
final class LoginItemTests: XCTestCase {
    func testReadingLoginSettingsNeverChangesRegistration() {
        var writes = 0
        let login = LoginItemController(readStatus: { .disabled }, register: { writes += 1 }, unregister: { writes += 1 })
        login.refresh()
        XCTAssertFalse(login.isOn)
        XCTAssertEqual(writes, 0)
    }

    func testEnableAndDisableAreIdempotent() {
        var status = LoginItemController.Status.disabled
        var registrations = 0
        var removals = 0
        let login = LoginItemController(readStatus: { status }, register: {
            registrations += 1
            status = .enabled
        }, unregister: {
            removals += 1
            status = .disabled
        })
        login.setEnabled(true)
        login.setEnabled(true)
        XCTAssertTrue(login.isOn)
        XCTAssertEqual(registrations, 1)
        login.setEnabled(false)
        login.setEnabled(false)
        XCTAssertFalse(login.isOn)
        XCTAssertEqual(removals, 1)
    }

    func testApprovalIsReportedRatherThanPretendingRegistrationIsEnabled() {
        var status = LoginItemController.Status.disabled
        let login = LoginItemController(readStatus: { status }, register: { status = .requiresApproval }, unregister: { status = .disabled })
        login.setEnabled(true)
        XCTAssertTrue(login.isOn)
        XCTAssertEqual(login.status, .requiresApproval)
        login.setEnabled(false)
        XCTAssertEqual(login.status, .disabled)
    }

    func testRegistrationFailureKeepsTheRealSystemStateAndAllowsRetry() {
        enum Failure: Error { case denied }
        var fail = true
        var status = LoginItemController.Status.disabled
        let login = LoginItemController(readStatus: { status }, register: {
            if fail { throw Failure.denied }
            status = .enabled
        }, unregister: {})
        login.setEnabled(true)
        XCTAssertFalse(login.isOn)
        XCTAssertNotNil(login.errorMessage)
        fail = false
        login.setEnabled(true)
        XCTAssertTrue(login.isOn)
        XCTAssertNil(login.errorMessage)
    }

    func testUnregisterFailureDoesNotClaimTheAppIsDisabled() {
        enum Failure: Error { case denied }
        let login = LoginItemController(readStatus: { .enabled }, register: {}, unregister: { throw Failure.denied })
        login.setEnabled(false)
        XCTAssertTrue(login.isOn)
        XCTAssertNotNil(login.errorMessage)
    }

    func testRefreshReflectsChangesMadeOutsideTheApp() {
        var status = LoginItemController.Status.enabled
        let login = LoginItemController(readStatus: { status }, register: {}, unregister: {})
        status = .disabled
        login.refresh()
        XCTAssertFalse(login.isOn)
    }

    func testManageLoginItemsIsAnExplicitAction() {
        var opens = 0
        let login = LoginItemController(readStatus: { .disabled }, register: {}, unregister: {}, openSystemSettings: { opens += 1 })
        XCTAssertEqual(opens, 0)
        login.manageInSystemSettings()
        XCTAssertEqual(opens, 1)
    }

    func testOpeningClosingAndRestoringTheWindowNeverRegistersLogin() {
        var writes = 0
        let login = LoginItemController(readStatus: { .disabled }, register: { writes += 1 }, unregister: { writes += 1 })
        let window = SettingsWindowController(settings: { .defaults }, onApply: { _ in }, login: login)
        window.showSettings()
        window.editor?.restoreDefaults()
        window.close()
        window.showSettings()
        window.close()
        XCTAssertEqual(writes, 0)
    }
}
