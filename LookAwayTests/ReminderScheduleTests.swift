import XCTest
@testable import LookAway

final class ReminderScheduleTests: XCTestCase {
    private let a = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
    private let b = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!
    private let c = UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!

    private func configuration(
        work: Int = 1800,
        breakSeconds: Int = 30,
        warning: Int = 60,
        reminders: [(UUID, Int)]
    ) -> BreakConfiguration {
        BreakConfiguration(
            workSeconds: work,
            breakSeconds: breakSeconds,
            warningSeconds: warning,
            reminders: reminders.map { ReminderScheduleConfiguration(id: $0.0, intervalSeconds: $0.1) }
        )
    }

    func testArbitraryReminderIntervalsEmitIdEvents() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 120), (b, 180)]), now: 0)
        XCTAssertEqual(schedule.advance(at: 119), [])
        XCTAssertEqual(schedule.advance(at: 120), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 180), [.reminder(b)])
    }

    func testSimultaneousGenericRemindersAreReturnedInConfigurationOrder() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(b, 300), (a, 300), (c, 300)]), now: 0)
        XCTAssertEqual(schedule.advance(at: 300), [.reminder(b), .reminder(a), .reminder(c)])
    }

    func testReorderingRemindersDoesNotResetWorkOrReminderDeadlines() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 300), (b, 600)]), now: 0)
        _ = schedule.advance(at: 100)
        schedule.skipUpcomingBreak()
        schedule.updateConfiguration(configuration(reminders: [(b, 600), (a, 300)]), at: 100)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1700)
        XCTAssertTrue(schedule.skipsUpcomingBreak)
        XCTAssertEqual(schedule.advance(at: 299), [])
        XCTAssertEqual(schedule.advance(at: 300), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 600), [.reminder(b), .reminder(a)])
    }

    func testAddingReminderStartsOnlyThatReminderFromNow() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 300)]), now: 0)
        schedule.updateConfiguration(configuration(reminders: [(a, 300), (b, 120)]), at: 100)
        XCTAssertEqual(schedule.advance(at: 219), [])
        XCTAssertEqual(schedule.advance(at: 220), [.reminder(b)])
        XCTAssertEqual(schedule.advance(at: 300), [.reminder(a)])
    }

    func testRemovingReminderDropsItsDeadline() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 120), (b, 180)]), now: 0)
        schedule.updateConfiguration(configuration(reminders: [(b, 180)]), at: 60)
        XCTAssertEqual(schedule.advance(at: 120), [])
        XCTAssertEqual(schedule.advance(at: 180), [.reminder(b)])
    }

    func testChangingOneIntervalRestartsOnlyThatReminder() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 300), (b, 600)]), now: 0)
        schedule.updateConfiguration(configuration(reminders: [(a, 120), (b, 600)]), at: 100)
        XCTAssertEqual(schedule.advance(at: 219), [])
        XCTAssertEqual(schedule.advance(at: 220), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 600), [.reminder(b)])
    }

    func testReminderOnlyChangesDoNotResetPendingSkipOrWorkRemaining() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 300)]), now: 0)
        schedule.skipUpcomingBreak()
        schedule.updateConfiguration(configuration(reminders: [(a, 450), (b, 120)]), at: 100)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1700)
        XCTAssertTrue(schedule.skipsUpcomingBreak)
    }

    func testPauseAndResumePreserveGenericReminderRemainingTime() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 300), (b, 600)]), now: 0)
        schedule.pause(at: 100)
        XCTAssertEqual(schedule.advance(at: 9999), [])
        schedule.resume(at: 1000)
        XCTAssertEqual(schedule.advance(at: 1199), [])
        XCTAssertEqual(schedule.advance(at: 1200), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 1500), [.reminder(b), .reminder(a)])
    }

    func testSleepWakePreservesReminderTimeWithoutBacklog() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 300)]), now: 0)
        schedule.prepareForSleep(at: 100)
        XCTAssertEqual(schedule.advance(at: 10000), [])
        schedule.wake(at: 10000)
        XCTAssertEqual(schedule.advance(at: 10199), [])
        XCTAssertEqual(schedule.advance(at: 10200), [.reminder(a)])
    }

    func testFinishingBreakStartsFreshCyclesForAllEnabledReminders() {
        var schedule = BreakSchedule(configuration: configuration(work: 100, reminders: [(a, 30), (b, 50)]), now: 0)
        XCTAssertEqual(schedule.advance(at: 100), [.startBreak])
        schedule.finishBreak(at: 120)
        XCTAssertEqual(schedule.advance(at: 149), [])
        XCTAssertEqual(schedule.advance(at: 150), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 170), [.reminder(b)])
    }

    func testDelayedAdvanceEmitsOnceAndRearmsFromCurrentTime() {
        var schedule = BreakSchedule(configuration: configuration(reminders: [(a, 100), (b, 150)]), now: 0)
        XCTAssertEqual(schedule.advance(at: 500), [.reminder(a), .reminder(b)])
        XCTAssertEqual(schedule.advance(at: 501), [])
        XCTAssertEqual(schedule.advance(at: 600), [.reminder(a)])
        XCTAssertEqual(schedule.advance(at: 650), [.reminder(b)])
    }

    func testCoreTimingChangeStillStartsFreshWorkAndReminderSession() {
        var schedule = BreakSchedule(configuration: configuration(work: 1800, reminders: [(a, 300)]), now: 0)
        schedule.skipUpcomingBreak()
        schedule.updateConfiguration(configuration(work: 1200, reminders: [(a, 300)]), at: 100)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1200)
        XCTAssertFalse(schedule.skipsUpcomingBreak)
        XCTAssertEqual(schedule.advance(at: 399), [])
        XCTAssertEqual(schedule.advance(at: 400), [.reminder(a)])
    }

    func testWarningLeadChangeDoesNotRestartWorkOrDuplicateAnAlreadyEmittedWarning() {
        var schedule = BreakSchedule(configuration: configuration(work: 100, warning: 20, reminders: []), now: 0)
        XCTAssertEqual(schedule.advance(at: 80), [.warning])
        schedule.updateConfiguration(configuration(work: 100, warning: 30, reminders: []), at: 81)
        XCTAssertEqual(schedule.remainingSeconds(at: 81), 19)
        XCTAssertEqual(schedule.advance(at: 82), [])
    }
}
