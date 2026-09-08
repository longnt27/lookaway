import AppKit
import XCTest
@testable import LookAway

@MainActor
final class SettingsTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "LookAwayTests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    func testDefaultsMatchOriginalSchedule() {
        XCTAssertEqual(AppSettings.defaults.breakConfiguration, BreakConfiguration())
        XCTAssertEqual(AppSettings.defaults.normalized, .defaults)
        XCTAssertTrue(AppSettings.defaults.showCountdown)
    }

    func testUserUnitsAndTogglesConvertToSchedulerConfiguration() {
        var settings = AppSettings.defaults
        settings.workMinutes = 45
        settings.breakSeconds = 90
        settings.blinkMinutes = 7
        settings.postureMinutes = 12
        settings.blinkEnabled = false
        settings.warningEnabled = false
        let config = settings.breakConfiguration
        XCTAssertEqual(config.workSeconds, 2700)
        XCTAssertEqual(config.breakSeconds, 90)
        XCTAssertEqual(config.blinkSeconds, 420)
        XCTAssertEqual(config.postureSeconds, 720)
        XCTAssertFalse(config.blinkEnabled)
        XCTAssertTrue(config.postureEnabled)
        XCTAssertEqual(config.warningSeconds, 0)
    }

    func testExtremeValuesAreClampedBeforeArithmetic() {
        var settings = AppSettings.defaults
        settings.workMinutes = .max
        settings.breakSeconds = .min
        settings.blinkMinutes = .min
        settings.postureMinutes = .max
        settings.warningSeconds = .max
        settings.reminderSeconds = .min
        let value = settings.normalized
        XCTAssertEqual(value.workMinutes, 180)
        XCTAssertEqual(value.breakSeconds, 5)
        XCTAssertEqual(value.blinkMinutes, 1)
        XCTAssertEqual(value.postureMinutes, 120)
        XCTAssertEqual(value.warningSeconds, 300)
        XCTAssertEqual(value.reminderSeconds, 1)
        XCTAssertTrue(settings.breakConfiguration.isValid)
        settings.workMinutes = .min
        XCTAssertEqual(settings.normalized.workMinutes, 1)
        XCTAssertEqual(settings.warningSecondsRange.upperBound, 59)
    }

    func testUpperAndLowerBoundsAndNormalizationAreStable() {
        var settings = AppSettings.defaults
        settings.workMinutes = 1
        settings.breakSeconds = 600
        settings.blinkMinutes = 120
        settings.postureMinutes = 1
        settings.reminderSeconds = 15
        settings.warningSeconds = 0
        let value = settings.normalized
        XCTAssertEqual(value.warningSeconds, 5)
        XCTAssertEqual(value.normalized, value)
        XCTAssertEqual(value.breakSeconds, 600)
        XCTAssertEqual(value.reminderSeconds, 15)
    }

    func testWarningAlwaysPrecedesWorkDeadline() {
        var settings = AppSettings.defaults
        settings.workMinutes = 1
        settings.warningSeconds = 300
        XCTAssertEqual(settings.normalized.warningSeconds, 59)
        let config = settings.breakConfiguration
        XCTAssertLessThan(config.warningSeconds, config.workSeconds)
    }

    func testMissingFieldsKeepDefaultsAndKnownValues() throws {
        let data = Data("{\"workMinutes\":45,\"showCountdown\":false,\"futureField\":123}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.workMinutes, 45)
        XCTAssertFalse(settings.showCountdown)
        XCTAssertEqual(settings.breakSeconds, 30)
        XCTAssertTrue(settings.blinkEnabled)
        XCTAssertTrue(settings.warningEnabled)
    }

    func testStoreUsesDefaultsWithoutWritingOnFirstLaunch() throws {
        try withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            XCTAssertEqual(store.value, .defaults)
            XCTAssertNil(defaults.object(forKey: SettingsStore.storageKey))
        }
    }

    func testStoreRecoversFromCorruptAndWrongTypeData() throws {
        try withDefaults { defaults in
            for data in [Data("not JSON".utf8), Data("{\"workMinutes\":\"invalid\"}".utf8)] {
                defaults.set(data, forKey: SettingsStore.storageKey)
                XCTAssertEqual(SettingsStore(defaults: defaults).value, .defaults)
            }
            defaults.set("unexpected storage type", forKey: SettingsStore.storageKey)
            XCTAssertEqual(SettingsStore(defaults: defaults).value, .defaults)
        }
    }

    func testStoredOutOfRangeValuesAreNormalizedOnLoad() throws {
        try withDefaults { defaults in
            var settings = AppSettings.defaults
            settings.workMinutes = .min
            settings.warningSeconds = .max
            defaults.set(try JSONEncoder().encode(settings), forKey: SettingsStore.storageKey)
            let store = SettingsStore(defaults: defaults)
            XCTAssertEqual(store.value.workMinutes, 1)
            XCTAssertEqual(store.value.warningSeconds, 59)
            XCTAssertTrue(store.value.breakConfiguration.isValid)
        }
    }

    func testAllPreferencesSurviveStoreRecreation() throws {
        try withDefaults { defaults in
            var settings = AppSettings.defaults
            settings.workMinutes = 42
            settings.breakSeconds = 75
            settings.blinkEnabled = false
            settings.blinkMinutes = 8
            settings.postureEnabled = false
            settings.postureMinutes = 14
            settings.warningEnabled = false
            settings.warningSeconds = 20
            settings.reminderSeconds = 4
            settings.showCountdown = false
            let store = SettingsStore(defaults: defaults)
            XCTAssertTrue(try store.save(settings))
            XCTAssertEqual(SettingsStore(defaults: defaults).value, settings)
        }
    }

    func testUnchangedSaveDoesNotWritePreferences() throws {
        try withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            XCTAssertFalse(try store.save(.defaults))
            XCTAssertNil(defaults.object(forKey: SettingsStore.storageKey))
        }
    }

    func testSaveNormalizesBeforePersistingAndPreservesOtherKeys() throws {
        try withDefaults { defaults in
            defaults.set("keep me", forKey: "unrelated.preference")
            var settings = AppSettings.defaults
            settings.breakSeconds = .max
            let store = SettingsStore(defaults: defaults)
            try store.save(settings)
            XCTAssertEqual(store.value.breakSeconds, 600)
            XCTAssertEqual(SettingsStore(defaults: defaults).value, settings.normalized)
            try store.save(.defaults)
            XCTAssertEqual(SettingsStore(defaults: defaults).value, .defaults)
            XCTAssertEqual(defaults.string(forKey: "unrelated.preference"), "keep me")
        }
    }

    func testDraftEditsAndRestoreDoNotApplyUntilSaved() {
        var settings = AppSettings.defaults
        settings.workMinutes = 45
        var calls = 0
        let editor = SettingsEditor(settings: settings) { _ in calls += 1 }
        editor.draft.breakSeconds = 60
        XCTAssertEqual(editor.saved, settings)
        XCTAssertTrue(editor.hasChanges)
        editor.restoreDefaults()
        XCTAssertEqual(editor.draft, .defaults)
        XCTAssertEqual(editor.saved, settings)
        XCTAssertEqual(calls, 0)
    }

    func testEditorAppliesOnceAndAcceptsNormalizedValues() {
        var applied: [AppSettings] = []
        let editor = SettingsEditor(settings: .defaults) { applied.append($0) }
        editor.draft.workMinutes = .max
        XCTAssertTrue(editor.apply())
        XCTAssertEqual(applied.count, 1)
        XCTAssertEqual(applied.first?.workMinutes, 180)
        XCTAssertFalse(editor.hasChanges)
        XCTAssertTrue(editor.apply())
        XCTAssertEqual(applied.count, 1)
    }

    func testEditorFailureKeepsDraftAndAllowsRetry() {
        enum SaveError: Error { case failed }
        var fail = true
        let editor = SettingsEditor(settings: .defaults) { _ in
            if fail { throw SaveError.failed }
        }
        editor.draft.workMinutes = 45
        XCTAssertFalse(editor.apply())
        XCTAssertEqual(editor.saved, .defaults)
        XCTAssertEqual(editor.draft.workMinutes, 45)
        XCTAssertNotNil(editor.errorMessage)
        XCTAssertTrue(editor.hasChanges)
        fail = false
        XCTAssertTrue(editor.apply())
        XCTAssertNil(editor.errorMessage)
        XCTAssertFalse(editor.hasChanges)
    }

    func testDisabledReminderRetainsItsChosenInterval() throws {
        try withDefaults { defaults in
            var settings = AppSettings.defaults
            settings.blinkMinutes = 8
            settings.blinkEnabled = false
            let store = SettingsStore(defaults: defaults)
            try store.save(settings)
            var restored = SettingsStore(defaults: defaults).value
            restored.blinkEnabled = true
            XCTAssertEqual(restored.breakConfiguration.blinkSeconds, 480)
        }
    }

    func testSettingsWindowIsReusableAndDoesNotReleaseOnClose() throws {
        let controller = SettingsWindowController(settings: { .defaults }, onApply: { _ in })
        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.title, "LookAway Settings")
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertNil(controller.editor)
        controller.showSettings()
        defer { controller.close() }
        let first = try XCTUnwrap(controller.editor)
        first.draft.workMinutes = 45
        controller.showSettings()
        XCTAssertTrue(controller.editor === first)
        XCTAssertTrue(controller.window === window)
        controller.close()
        XCTAssertNil(controller.editor)
        controller.showSettings()
        XCTAssertEqual(controller.editor?.draft, .defaults)
        XCTAssertTrue(controller.window === window)
    }

    func testSettingsWindowReopensWithLastSavedValues() throws {
        var stored = AppSettings.defaults
        let controller = SettingsWindowController(settings: { stored }, onApply: { stored = $0 })
        controller.showSettings()
        defer { controller.close() }
        let editor = try XCTUnwrap(controller.editor)
        editor.draft.workMinutes = 45
        XCTAssertTrue(editor.apply())
        controller.close()
        controller.showSettings()
        XCTAssertEqual(controller.editor?.draft.workMinutes, 45)
        controller.editor?.restoreDefaults()
        controller.close()
        controller.showSettings()
        XCTAssertEqual(controller.editor?.draft.workMinutes, 45)
    }
}

@MainActor
final class SchedulerSettingsTests: XCTestCase {
    func testBothRemindersCanBeDisabledWithoutDisablingBreaks() {
        var config = BreakConfiguration()
        config.blinkEnabled = false
        config.postureEnabled = false
        var schedule = BreakSchedule(configuration: config, now: 0)
        XCTAssertEqual(schedule.advance(at: 600), [])
        XCTAssertEqual(schedule.advance(at: 1800), [.startBreak])
    }

    func testReminderTogglesAreIndependent() {
        for disableBlink in [true, false] {
            var config = BreakConfiguration()
            config.blinkEnabled = !disableBlink
            config.postureEnabled = disableBlink
            var schedule = BreakSchedule(configuration: config, now: 0)
            XCTAssertEqual(schedule.advance(at: 600), disableBlink ? [.postureReminder] : [.blinkReminder])
        }
    }

    func testWarningCanBeDisabledAndReenabled() {
        var config = BreakConfiguration()
        config.warningSeconds = 0
        config.blinkEnabled = false
        config.postureEnabled = false
        var schedule = BreakSchedule(configuration: config, now: 0)
        XCTAssertEqual(schedule.advance(at: 1740), [])
        config.warningSeconds = 30
        schedule.updateConfiguration(config, at: 1740)
        XCTAssertEqual(schedule.advance(at: 3509), [])
        XCTAssertEqual(schedule.advance(at: 3510), [.warning])
    }

    func testCustomReminderIntervalsAreUsed() {
        let settings = AppSettings(workMinutes: 20, blinkMinutes: 2, postureMinutes: 3)
        var schedule = BreakSchedule(configuration: settings.breakConfiguration, now: 0)
        XCTAssertEqual(schedule.advance(at: 119), [])
        XCTAssertEqual(schedule.advance(at: 120), [.blinkReminder])
        XCTAssertEqual(schedule.advance(at: 180), [.postureReminder])
    }

    func testTimingChangeStartsFreshWorkAndClearsPendingSkip() {
        var schedule = BreakSchedule(now: 0)
        schedule.skipUpcomingBreak()
        var config = BreakConfiguration()
        config.workSeconds = 1200
        schedule.updateConfiguration(config, at: 100)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1200)
        XCTAssertFalse(schedule.skipsUpcomingBreak)
        XCTAssertEqual(schedule.advance(at: 399), [])
        XCTAssertEqual(schedule.advance(at: 400), [.blinkReminder])
    }

    func testUnchangedOrDisplayOnlySettingsDoNotResetWorkOrSkip() {
        var schedule = BreakSchedule(now: 0)
        schedule.skipUpcomingBreak()
        var settings = AppSettings.defaults
        settings.showCountdown = false
        schedule.updateConfiguration(settings.breakConfiguration, at: 100)
        XCTAssertEqual(schedule.remainingSeconds(at: 100), 1700)
        XCTAssertTrue(schedule.skipsUpcomingBreak)
    }

    func testUnchangedSettingsDoNotRearmWarning() {
        var schedule = BreakSchedule(now: 0)
        XCTAssertTrue(schedule.advance(at: 1740).contains(.warning))
        schedule.updateConfiguration(BreakConfiguration(), at: 1741)
        XCTAssertFalse(schedule.advance(at: 1742).contains(.warning))
    }

    func testChangingTimingWhilePausedDoesNotResumeTimer() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 100)
        var config = BreakConfiguration()
        config.workSeconds = 1200
        schedule.updateConfiguration(config, at: 500)
        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertEqual(schedule.remainingSeconds(at: 1000), 1200)
        XCTAssertEqual(schedule.advance(at: 1000), [])
        schedule.resume(at: 1000)
        XCTAssertEqual(schedule.remainingSeconds(at: 1001), 1199)
        XCTAssertEqual(schedule.advance(at: 1299), [])
        XCTAssertEqual(schedule.advance(at: 1300), [.blinkReminder])
    }

    func testChangingSettingsDuringSleepPreservesAutoResume() {
        var schedule = BreakSchedule(now: 0)
        schedule.prepareForSleep(at: 100)
        var config = BreakConfiguration()
        config.workSeconds = 1200
        schedule.updateConfiguration(config, at: 200)
        XCTAssertTrue(schedule.isSleeping)
        XCTAssertEqual(schedule.phase, .paused)
        schedule.wake(at: 1000)
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: 1000), 1200)
    }

    func testChangingSettingsDuringSleepPreservesManualPause() {
        var schedule = BreakSchedule(now: 0)
        schedule.pause(at: 50)
        schedule.prepareForSleep(at: 100)
        var config = BreakConfiguration()
        config.workSeconds = 1200
        schedule.updateConfiguration(config, at: 200)
        schedule.wake(at: 1000)
        XCTAssertEqual(schedule.phase, .paused)
        XCTAssertEqual(schedule.remainingSeconds(at: 1000), 1200)
    }

    func testActiveBreakKeepsItsCountdownAndUsesNewSettingsAfterCompletion() {
        var now: TimeInterval = 0
        var schedule = BreakSchedule(now: now)
        schedule.startBreakNow()
        let overlay = OverlayController(clock: { now }, screens: { [] }, dismissalDuration: 0)
        overlay.show(mode: .breakSession(seconds: schedule.configuration.breakSeconds),
                     onHide: { schedule.finishBreak(at: now) })
        defer { overlay.hide(cleanupOnly: true) }
        let id = overlay.presentationID
        now = 10
        var config = BreakConfiguration()
        config.workSeconds = 600
        config.breakSeconds = 60
        schedule.updateConfiguration(config, at: now)
        overlay.tick()
        XCTAssertEqual(schedule.phase, .onBreak)
        XCTAssertEqual(overlay.presentationID, id)
        XCTAssertEqual(overlay.remainingSeconds, 20)
        now = 30
        overlay.tick()
        XCTAssertEqual(schedule.phase, .working)
        XCTAssertEqual(schedule.remainingSeconds(at: now), 600)
        XCTAssertEqual(schedule.configuration.breakSeconds, 60)
    }

    func testReenablingRemindersStartsTheirIntervalsWithoutBacklog() {
        var config = BreakConfiguration()
        config.blinkEnabled = false
        var schedule = BreakSchedule(configuration: config, now: 0)
        _ = schedule.advance(at: 900)
        config.blinkEnabled = true
        schedule.updateConfiguration(config, at: 900)
        XCTAssertEqual(schedule.advance(at: 901), [])
        XCTAssertEqual(schedule.advance(at: 1200), [.blinkReminder])
    }
}
