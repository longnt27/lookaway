import AppKit
import XCTest
@testable import LookAway

@MainActor
final class PresentationTests: XCTestCase {
    func testReminderCannotReplaceAnActiveBreak() {
        let controller = OverlayController(screens: { [] })
        var completions = 0
        controller.show(mode: .breakSession(seconds: 30), onHide: { completions += 1 })
        controller.show(mode: .reminder(message: "Blink", duration: 2))
        XCTAssertTrue(controller.isShowingBreak)
        controller.hide()
        controller.hide()
        XCTAssertEqual(completions, 1)
    }

    func testRepeatedManualBreakDoesNotRestartPresentation() {
        let controller = OverlayController(screens: { [] })
        var first = 0
        var second = 0
        controller.show(mode: .breakSession(seconds: 10), onHide: { first += 1 })
        let id = controller.presentationID
        controller.show(mode: .breakSession(seconds: 30), onHide: { second += 1 })
        XCTAssertEqual(controller.presentationID, id)
        XCTAssertEqual(controller.remainingSeconds, 10)
        controller.hide()
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 0)
    }

    func testCleanupAndReplacementDoNotInvokeObsoleteCompletion() {
        let controller = OverlayController(screens: { [] })
        var obsolete = 0
        var current = 0
        controller.show(mode: .reminder(message: "Blink", duration: 2), onHide: { obsolete += 1 })
        controller.show(mode: .breakSession(seconds: 30), onHide: { current += 1 })
        controller.hide(cleanupOnly: true)
        controller.hide()
        XCTAssertEqual(obsolete, 0)
        XCTAssertEqual(current, 0)
    }

    func testOldDisplayCallbackCannotDismissNewPresentation() throws {
        let controller = OverlayController(screens: { [] })
        defer { controller.hide(cleanupOnly: true) }
        controller.show(mode: .reminder(message: "Blink", duration: 2))
        let oldID = try XCTUnwrap(controller.presentationID)
        controller.show(mode: .breakSession(seconds: 30))
        controller.dismiss(presentationID: oldID)
        XCTAssertTrue(controller.isShowingBreak)
        XCTAssertNotEqual(controller.presentationID, oldID)
    }

    func testCompletionCanCreateNewPresentationWithoutItBeingCleared() {
        let controller = OverlayController(screens: { [] })
        defer { controller.hide(cleanupOnly: true) }
        controller.show(mode: .breakSession(seconds: 30), onHide: {
            controller.show(mode: .reminder(message: "New session", duration: 2))
        })
        controller.hide()
        XCTAssertEqual(controller.currentMode, .reminder(message: "New session", duration: 2))
        XCTAssertNotNil(controller.presentationID)
    }

    func testCountdownCompletesWithoutDependingOnAViewOrDisplay() {
        var now: TimeInterval = 100
        let controller = OverlayController(clock: { now }, screens: { [] }, dismissalDuration: 0)
        var completions = 0
        var ticks: [Int] = []
        controller.show(mode: .breakSession(seconds: 30),
                        onHide: { completions += 1 }, onTick: { ticks.append($0) })
        XCTAssertEqual(ticks, [30])
        now = 110
        controller.tick()
        XCTAssertEqual(controller.remainingSeconds, 20)
        now = 140
        controller.tick()
        controller.tick()
        XCTAssertEqual(ticks, [30, 20, 0])
        XCTAssertEqual(completions, 1)
        XCTAssertNil(controller.presentationID)
    }

    func testZeroDurationCompletesOnceAndDoesNotStartAPresentation() {
        let controller = OverlayController(screens: { [] })
        var completions = 0
        controller.show(mode: .breakSession(seconds: 0), onHide: { completions += 1 })
        controller.tick()
        XCTAssertEqual(completions, 1)
        XCTAssertNil(controller.currentMode)
    }

    func testCountdownCallbackCannotDismissItsOwnReplacement() {
        var now: TimeInterval = 0
        let controller = OverlayController(clock: { now }, screens: { [] }, dismissalDuration: 0)
        defer { controller.hide(cleanupOnly: true) }
        controller.show(mode: .reminder(message: "Blink", duration: 2), onTick: { remaining in
            if remaining == 0 { controller.show(mode: .breakSession(seconds: 30)) }
        })
        now = 2
        controller.tick()
        XCTAssertTrue(controller.isShowingBreak)
        XCTAssertEqual(controller.remainingSeconds, 30)
    }

    func testScreenRefreshPreservesPresentationAndCountdown() {
        var now: TimeInterval = 0
        let controller = OverlayController(clock: { now }, screens: { [] })
        defer { controller.hide(cleanupOnly: true) }
        controller.show(mode: .breakSession(seconds: 30))
        let id = controller.presentationID
        now = 10
        controller.refreshScreens()
        controller.tick()
        XCTAssertEqual(controller.presentationID, id)
        XCTAssertEqual(controller.remainingSeconds, 20)
    }

    func testReadyButtonDelayUsesSharedElapsedTime() {
        let model = OverlayViewModel(duration: 30)
        XCTAssertEqual(model.readyDelayRemaining, 3)
        model.remaining = 29
        XCTAssertEqual(model.readyDelayRemaining, 2)
        model.remaining = 27
        XCTAssertEqual(model.readyDelayRemaining, 0)
        model.remaining = 0
        XCTAssertEqual(model.readyDelayRemaining, 0)
    }

    func testEmptyReminderMessageDoesNotBecomeABreak() {
        let controller = OverlayController(screens: { [] })
        defer { controller.hide(cleanupOnly: true) }
        controller.show(mode: .reminder(message: "", duration: 2))
        XCTAssertFalse(controller.isShowingBreak)
        XCTAssertEqual(controller.currentMode, .reminder(message: "", duration: 2))
    }

    func testBannerActionIsConsumedOnceAcrossDisplays() throws {
        let controller = PopupBannerController(screens: { [] })
        controller.show(message: "Soon", onKnow: {}, onSkipBreak: {}, onAddFiveMinutes: {})
        let id = try XCTUnwrap(controller.presentationID)
        var actions = 0
        controller.performAction(for: id) { actions += 1 }
        controller.performAction(for: id) { actions += 1 }
        XCTAssertEqual(actions, 1)
        XCTAssertNil(controller.presentationID)
    }

    func testStaleBannerActionCannotAffectReplacement() throws {
        let controller = PopupBannerController(screens: { [] })
        defer { controller.hide() }
        controller.show(message: "Old", onKnow: {}, onSkipBreak: {}, onAddFiveMinutes: {})
        let oldID = try XCTUnwrap(controller.presentationID)
        controller.show(message: "New", onKnow: {}, onSkipBreak: {}, onAddFiveMinutes: {})
        let newID = controller.presentationID
        var actions = 0
        controller.performAction(for: oldID) { actions += 1 }
        XCTAssertEqual(actions, 0)
        XCTAssertEqual(controller.presentationID, newID)
    }

    func testBannerActionMaySafelyShowAnotherBanner() throws {
        let controller = PopupBannerController(screens: { [] })
        defer { controller.hide() }
        controller.show(message: "Old", onKnow: {}, onSkipBreak: {}, onAddFiveMinutes: {})
        let oldID = try XCTUnwrap(controller.presentationID)
        controller.performAction(for: oldID) {
            controller.show(message: "New", onKnow: {}, onSkipBreak: {}, onAddFiveMinutes: {})
        }
        XCTAssertNotNil(controller.presentationID)
        XCTAssertNotEqual(controller.presentationID, oldID)
    }

    func testHiddenBannerCannotRunAnAction() throws {
        let controller = PopupBannerController(screens: { [] })
        controller.show(message: "Soon", onKnow: {}, onSkipBreak: {}, onAddFiveMinutes: {})
        let id = try XCTUnwrap(controller.presentationID)
        controller.hide()
        var actions = 0
        controller.performAction(for: id) { actions += 1 }
        XCTAssertEqual(actions, 0)
    }

    func testBannerLayoutRespectsPositiveAndNegativeDisplayOrigins() {
        let frames = [
            NSRect(x: 0, y: 23, width: 1440, height: 877),
            NSRect(x: 1920, y: 200, width: 1280, height: 1000),
            NSRect(x: -1280, y: -800, width: 1280, height: 800),
            NSRect(x: 0, y: 1080, width: 1920, height: 1080)
        ]
        for visibleFrame in frames {
            let banner = BannerLayout.frame(in: visibleFrame)
            XCTAssertEqual(banner.midX, visibleFrame.midX)
            XCTAssertEqual(banner.maxY, visibleFrame.maxY - 20)
            XCTAssertEqual(banner.size, NSSize(width: 380, height: 180))
            XCTAssertTrue(visibleFrame.contains(banner))
        }
    }

    func testBannerLayoutFitsSmallVisibleFrames() {
        let visibleFrame = NSRect(x: -100, y: 50, width: 100, height: 80)
        let banner = BannerLayout.frame(in: visibleFrame)
        XCTAssertTrue(visibleFrame.contains(banner))
        XCTAssertGreaterThan(banner.width, 0)
        XCTAssertGreaterThan(banner.height, 0)
    }

    func testPanelIsConfiguredNotToActivateTheApplication() {
        let panel = OverlayWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
        panel.configureForOverlay()
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertFalse(panel.hidesOnDeactivate)
        panel.close()
    }
}
