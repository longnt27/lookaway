import Foundation
import XCTest
@testable import LookAway

final class ActiveHoursTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private var mondayOnly: AppSettings {
        var settings = AppSettings.defaults
        settings.activeHoursEnabled = true
        settings.activeWeekdays = [2]
        return settings
    }

    func testDisabledScheduleAllowsAnyDayAndTime() {
        XCTAssertTrue(AppSettings.defaults.isActive(at: date(6, 0), calendar: calendar))
        XCTAssertTrue(AppSettings.defaults.isActive(at: date(7, 23), calendar: calendar))
    }

    func testDaytimeWindowIncludesStartAndExcludesEnd() {
        let settings = mondayOnly
        XCTAssertFalse(settings.isActive(at: date(7, 8, 59), calendar: calendar))
        XCTAssertTrue(settings.isActive(at: date(7, 9), calendar: calendar))
        XCTAssertTrue(settings.isActive(at: date(7, 16, 59), calendar: calendar))
        XCTAssertFalse(settings.isActive(at: date(7, 17), calendar: calendar))
        XCTAssertFalse(settings.isActive(at: date(8, 10), calendar: calendar))
    }

    func testOvernightWindowBelongsToItsStartingDay() {
        var settings = mondayOnly
        settings.activeStartMinute = 22 * 60
        settings.activeEndMinute = 6 * 60
        XCTAssertFalse(settings.isActive(at: date(7, 5), calendar: calendar))
        XCTAssertFalse(settings.isActive(at: date(7, 21, 59), calendar: calendar))
        XCTAssertTrue(settings.isActive(at: date(7, 22), calendar: calendar))
        XCTAssertTrue(settings.isActive(at: date(8, 0), calendar: calendar))
        XCTAssertTrue(settings.isActive(at: date(8, 5, 59), calendar: calendar))
        XCTAssertFalse(settings.isActive(at: date(8, 6), calendar: calendar))
        XCTAssertFalse(settings.isActive(at: date(8, 22), calendar: calendar))
    }

    func testOvernightSaturdayWrapsIntoSunday() {
        var settings = mondayOnly
        settings.activeWeekdays = [7]
        settings.activeStartMinute = 22 * 60
        settings.activeEndMinute = 6 * 60
        XCTAssertTrue(settings.isActive(at: date(5, 23), calendar: calendar))
        XCTAssertTrue(settings.isActive(at: date(6, 5), calendar: calendar))
        XCTAssertFalse(settings.isActive(at: date(6, 6), calendar: calendar))
    }

    func testEqualTimesMeanTheSelectedCalendarDay() {
        var settings = mondayOnly
        settings.activeEndMinute = settings.activeStartMinute
        XCTAssertTrue(settings.isActive(at: date(7, 0), calendar: calendar))
        XCTAssertTrue(settings.isActive(at: date(7, 23, 59), calendar: calendar))
        XCTAssertFalse(settings.isActive(at: date(8, 0), calendar: calendar))
    }

    func testEmptyOrInvalidDaysKeepTheScheduleInactive() {
        var settings = mondayOnly
        settings.activeWeekdays = []
        XCTAssertFalse(settings.isActive(at: date(7, 10), calendar: calendar))
        settings.activeWeekdays = [-1, 0, 8, .max]
        XCTAssertFalse(settings.isActive(at: date(7, 10), calendar: calendar))
    }

    func testCalendarTimeZoneDeterminesTheLocalWindow() {
        var local = calendar
        local.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        XCTAssertTrue(mondayOnly.isActive(at: date(7, 2), calendar: local))
        XCTAssertFalse(mondayOnly.isActive(at: date(7, 1, 59), calendar: local))
        XCTAssertFalse(mondayOnly.isActive(at: date(7, 2), calendar: calendar))
    }

    func testRepeatedDSTHourRemainsInsideTheSameWindow() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var s = mondayOnly
        s.activeWeekdays = [1]
        s.activeStartMinute = 60
        s.activeEndMinute = 120
        let formatter = ISO8601DateFormatter()
        let first = try XCTUnwrap(formatter.date(from: "2026-11-01T05:30:00Z"))
        let second = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:00Z"))
        XCTAssertTrue(s.isActive(at: first, calendar: local))
        XCTAssertTrue(s.isActive(at: second, calendar: local))
    }

    func testGateFreezesRemainingTimeAndResumesOnlyItsOwnPause() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        gate.reconcile(allowed: false, schedule: &schedule, at: 100)
        XCTAssertTrue(gate.ownsPause)
        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertEqual(schedule.remainingSeconds(at: 1000), 1700)
        gate.reconcile(allowed: true, schedule: &schedule, at: 1000)
        XCTAssertFalse(gate.ownsPause)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 1001), 1699)
    }

    func testGateNeverResumesAManualPause() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        schedule.pause(at: 100)
        gate.reconcile(allowed: false, schedule: &schedule, at: 200)
        gate.reconcile(allowed: true, schedule: &schedule, at: 1000)
        XCTAssertFalse(gate.ownsPause)
        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertEqual(schedule.remainingSeconds(at: 1000), 1700)
    }

    func testRepeatedGateChecksDoNotResetTheCountdown() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        gate.reconcile(allowed: false, schedule: &schedule, at: 100)
        gate.reconcile(allowed: false, schedule: &schedule, at: 200)
        gate.reconcile(allowed: true, schedule: &schedule, at: 1000)
        gate.reconcile(allowed: true, schedule: &schedule, at: 1100)
        XCTAssertEqual(schedule.remainingSeconds(at: 1100), 1600)
    }

    func testKeepPausedCancelsAutomaticResume() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        gate.reconcile(allowed: false, schedule: &schedule, at: 100)
        gate.cancelAutomaticResume()
        gate.reconcile(allowed: true, schedule: &schedule, at: 1000)
        XCTAssertEqual(schedule.phase, .paused)
    }

    func testAutomaticPauseSurvivesSleepAndResumesWithinWorkingHours() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        gate.reconcile(allowed: false, schedule: &schedule, at: 100)
        schedule.prepareForSleep(at: 200)
        gate.reconcile(allowed: true, schedule: &schedule, at: 300)
        XCTAssertTrue(gate.ownsPause)
        schedule.wake(at: 1000)
        gate.reconcile(allowed: true, schedule: &schedule, at: 1000)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 1000), 1700)
    }

    func testManualPauseSurvivesSleepAndScheduleBoundaries() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        schedule.pause(at: 100)
        schedule.prepareForSleep(at: 200)
        schedule.wake(at: 1000)
        gate.reconcile(allowed: true, schedule: &schedule, at: 1000)
        XCTAssertEqual(schedule.phase, .paused)
    }

    func testActiveBreakFinishesBeforeTheHoursGatePausesWork() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        schedule.startBreakNow()
        gate.reconcile(allowed: false, schedule: &schedule, at: 100)
        XCTAssertEqual(schedule.phase, .onBreak)
        XCTAssertFalse(gate.ownsPause)
        schedule.finishBreak(at: 200)
        gate.reconcile(allowed: false, schedule: &schedule, at: 200)
        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertTrue(gate.ownsPause)
        XCTAssertEqual(schedule.remainingSeconds(at: 300), 1800)
    }

    func testTimingChangeDuringAutomaticPausePreservesResumeIntent() {
        var schedule = BreakSchedule(now: 0)
        var gate = ActiveHoursGate()
        gate.reconcile(allowed: false, schedule: &schedule, at: 100)
        var config = BreakConfiguration()
        config.workSeconds = 1200
        schedule.updateConfiguration(config, at: 200)
        gate.reconcile(allowed: true, schedule: &schedule, at: 1000)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 1000), 1200)
    }
}
