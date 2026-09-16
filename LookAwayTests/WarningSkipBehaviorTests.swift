import XCTest
@testable import LookAway

final class WarningSkipBehaviorTests: XCTestCase {
    func testWarningSkipRestartsFullWorkIntervalImmediately() {
        var schedule = BreakSchedule(now: 0)

        XCTAssertTrue(schedule.advance(at: 1740).contains(.warning))
        schedule.skipUpcomingBreak()

        XCTAssertEqual(schedule.remainingSeconds(at: 1740), 1800)
        XCTAssertEqual(schedule.advance(at: 1800), [])
        XCTAssertEqual(schedule.remainingSeconds(at: 1800), 1740)
        XCTAssertEqual(schedule.advance(at: 3540), [.startBreak])
    }

    func testWarningSkipIsIgnoredWhilePaused() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100)

        schedule.skipUpcomingBreak()

        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1700)
    }

    @MainActor
    func testWarningSkipPassesCurrentTimeToScheduler() throws {
        let source = try repositorySource("LookAway/AppDelegate.swift")
        XCTAssertTrue(source.contains("skipUpcomingBreak(at: self.now)"))
    }

    @MainActor
    func testActiveBreakOverlayDoesNotExposeSkipBreak() throws {
        let viewSource = try repositorySource("LookAway/OverlayView.swift")
        let controllerSource = try repositorySource("LookAway/OverlayController.swift")

        XCTAssertFalse(viewSource.contains("Button(\"Skip Break\""))
        XCTAssertFalse(viewSource.contains("accessibilityIdentifier(\"skipBreak\")"))
        XCTAssertFalse(controllerSource.contains("onSkip:"))
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
