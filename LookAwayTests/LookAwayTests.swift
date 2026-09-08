import XCTest
@testable import LookAway

final class LookAwayTests: XCTestCase {
    func testInitialWorkIntervalHasNoExtraSeconds() {
        let schedule = BreakSchedule(now: 100)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1800)
    }

    func testDelayedTicksUseElapsedTimeRatherThanTickCount() {
        var schedule = BreakSchedule(now: 100)
        _ = schedule.advance(at: 110)
        XCTAssertEqual(schedule.remainingSeconds(at: 110), 1790)
        XCTAssertEqual(schedule.remainingSeconds(at: 110.25), 1790)
    }

    func testWarningIsEmittedWhenThresholdIsCrossed() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertFalse(schedule.advance(at: 1739).contains(.warning))
        XCTAssertTrue(schedule.advance(at: 1741).contains(.warning))
        XCTAssertFalse(schedule.advance(at: 1742).contains(.warning))
    }

    func testOverdueBreakTakesPriorityOverWarningAndReminders() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertEqual(schedule.advance(at: 2000), [.startBreak])
        XCTAssertEqual(schedule.phase, .onBreak)
        XCTAssertEqual(schedule.advance(at: 2500), [])
    }

    func testSkipStartsAFullWorkIntervalAndIsConsumedExactlyOnce() {
        var schedule = BreakSchedule(now: 0)
        schedule.skipUpcomingBreak()
        XCTAssertEqual(schedule.advance(at: 1800), [.skippedBreak])
        XCTAssertEqual(schedule.remainingSeconds(at: 1800), 1800)
        XCTAssertFalse(schedule.skipsUpcomingBreak)
        XCTAssertEqual(schedule.advance(at: 1801), [])
        XCTAssertEqual(schedule.advance(at: 3600), [.startBreak])
    }

    func testSkippedBreakDoesNotEmitAnotherWarning() {
        var schedule = BreakSchedule(now: 0)
        schedule.skipUpcomingBreak()
        XCTAssertFalse(schedule.advance(at: 1750).contains(.warning))
    }

    func testManualBreakOverridesPendingSkip() {
        var schedule = BreakSchedule(now: 0)
        schedule.skipUpcomingBreak()
        XCTAssertTrue(schedule.startBreakNow())
        XCTAssertEqual(schedule.phase, .onBreak)
        XCTAssertFalse(schedule.skipsUpcomingBreak)
        XCTAssertFalse(schedule.startBreakNow())
    }

    func testManualBreakCanStartWhilePaused() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100)
        XCTAssertTrue(schedule.startBreakNow())
        schedule.finishBreak(at: 200)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 200), 1800)
    }

    func testFinishingBreakResetsWorkAndReminderIntervals() {
        var schedule = BreakSchedule(now: 0)
        _ = schedule.advance(at: 1800)
        schedule.finishBreak(at: 1830)
        XCTAssertEqual(schedule.remainingSeconds(at: 1830), 1800)
        XCTAssertEqual(schedule.advance(at: 2129), [])
        XCTAssertEqual(schedule.advance(at: 2130), [.blinkReminder])
    }

    func testDuplicateCompletionCannotResetNewWorkSession() {
        var schedule = BreakSchedule(now: 0)
        schedule.startBreakNow()
        schedule.finishBreak(at: 30)
        schedule.finishBreak(at: 130)
        XCTAssertEqual(schedule.remainingSeconds(at: 130), 1700)
    }

    func testPauseFreezesWorkAndReminders() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100)
        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertEqual(schedule.advance(at: 9000), [])
        XCTAssertEqual(schedule.remainingSeconds(at: 9000), 1700)
        schedule.resume(at: 10000)
        XCTAssertEqual(schedule.remainingSeconds(at: 10000), 1700)
        XCTAssertEqual(schedule.advance(at: 10199), [])
        XCTAssertEqual(schedule.advance(at: 10200), [.blinkReminder])
    }

    func testPausePreservesFractionalTime() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100.5)
        schedule.resume(at: 10000)
        XCTAssertEqual(schedule.remainingSeconds(at: 10000), 1700)
        XCTAssertEqual(schedule.remainingSeconds(at: 10000.5), 1699)
    }

    func testRepeatedPauseAndResumeAreIdempotent() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100)
        schedule.pause(at: 900)
        schedule.resume(at: 1000)
        schedule.resume(at: 1100)
        XCTAssertEqual(schedule.remainingSeconds(at: 1100), 1600)
    }

    func testPauseAtDeadlineResumesIntoBreakWithoutNegativeCountdown() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 1800)
        schedule.resume(at: 5000)
        XCTAssertEqual(schedule.remainingSeconds(at: 5000), 0)
        XCTAssertEqual(schedule.advance(at: 5000), [.startBreak])
    }

    func testBreakCannotBePausedOrReceiveWarningActions() {
        var schedule = BreakSchedule(now: 0)
        schedule.startBreakNow()
        schedule.pause(at: 10)
        schedule.skipUpcomingBreak()
        XCTAssertFalse(schedule.postponeBreak(at: 10))
        XCTAssertEqual(schedule.phase, .onBreak)
        XCTAssertFalse(schedule.skipsUpcomingBreak)
    }

    func testSimultaneousRemindersAreBothReturned() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertEqual(schedule.advance(at: 300), [.blinkReminder])
        XCTAssertEqual(schedule.advance(at: 600), [.blinkReminder, .postureReminder])
    }

    func testDelayedReminderDoesNotReplayABacklog() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertEqual(schedule.advance(at: 1000), [.blinkReminder, .postureReminder])
        XCTAssertEqual(schedule.advance(at: 1001), [])
        XCTAssertEqual(schedule.advance(at: 1300), [.blinkReminder])
    }

    func testPostponementAddsFiveMinutesAndRearmsWarning() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertTrue(schedule.advance(at: 1740).contains(.warning))
        XCTAssertTrue(schedule.postponeBreak(at: 1740))
        XCTAssertEqual(schedule.remainingSeconds(at: 1740), 360)
        XCTAssertFalse(schedule.advance(at: 2039).contains(.warning))
        XCTAssertTrue(schedule.advance(at: 2040).contains(.warning))
        XCTAssertEqual(schedule.advance(at: 2100), [.startBreak])
    }

    func testLateOrInvalidPostponementCannotResurrectAnExpiredSession() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertFalse(schedule.postponeBreak(by: 0, at: 10))
        XCTAssertFalse(schedule.postponeBreak(by: -10, at: 10))
        XCTAssertFalse(schedule.postponeBreak(at: 1800))
        XCTAssertEqual(schedule.advance(at: 1800), [.startBreak])
    }

    func testPausedWarningActionsAreIgnored() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100)
        schedule.skipUpcomingBreak()
        XCTAssertFalse(schedule.postponeBreak(at: 100))
        XCTAssertFalse(schedule.skipsUpcomingBreak)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1700)
    }

    func testSleepFreezesWorkAndReminderTime() {
        var schedule = BreakSchedule(now: 0)
        schedule.prepareForSleep(at: 100)
        XCTAssertTrue(schedule.isSleeping)
        XCTAssertEqual(schedule.advance(at: 9000), [])
        XCTAssertFalse(schedule.startBreakNow())
        schedule.wake(at: 10000)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 10000), 1700)
        XCTAssertEqual(schedule.advance(at: 10199), [])
        XCTAssertEqual(schedule.advance(at: 10200), [.blinkReminder])
    }

    func testUserPauseIsPreservedAfterSleep() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100)
        schedule.prepareForSleep(at: 200)
        schedule.wake(at: 10000)
        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertEqual(schedule.remainingSeconds(at: 10000), 1700)
    }

    func testSleepDuringBreakStartsFreshWorkOnWake() {
        var schedule = BreakSchedule(now: 0)
        schedule.startBreakNow()
        schedule.prepareForSleep(at: 10)
        schedule.wake(at: 10000)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 10000), 1800)
    }

    func testDuplicateSleepAndWakeNotificationsDoNotChangeRemainingTime() {
        var schedule = BreakSchedule(now: 0)
        schedule.prepareForSleep(at: 100)
        schedule.prepareForSleep(at: 200)
        schedule.wake(at: 1000)
        schedule.wake(at: 1100)
        XCTAssertEqual(schedule.remainingSeconds(at: 1100), 1600)
    }

    func testConfigurationDrivesAllDeadlines() {
        let config = BreakConfiguration(workSeconds: 100, breakSeconds: 5,
                                        blinkSeconds: 10, postureSeconds: 20,
                                        warningSeconds: 15, reminderSeconds: 1)
        var schedule = BreakSchedule(configuration: config, now: 0)
        XCTAssertEqual(schedule.remainingSeconds(at: 0), 100)
        XCTAssertEqual(schedule.advance(at: 10), [.blinkReminder])
        XCTAssertEqual(schedule.advance(at: 20), [.blinkReminder, .postureReminder])
        XCTAssertTrue(schedule.advance(at: 86).contains(.warning))
        XCTAssertEqual(schedule.advance(at: 100), [.startBreak])
    }
}
