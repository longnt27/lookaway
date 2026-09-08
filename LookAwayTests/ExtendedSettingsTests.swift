import AppKit
import XCTest
@testable import LookAway

@MainActor
final class ExtendedSettingsTests: XCTestCase {
    func testNewFeaturesAreOptInAndOriginalTimingIsUnchanged() {
        let s = AppSettings.defaults
        XCTAssertEqual(s.breakConfiguration, BreakConfiguration())
        XCTAssertFalse(s.startPaused)
        XCTAssertFalse(s.activeHoursEnabled)
        XCTAssertTrue(s.allowSkip)
        XCTAssertTrue(s.allowEarlyFinish)
        XCTAssertEqual(s.snoozeMinutes, 5)
        XCTAssertEqual(s.readyDelay, 3)
        XCTAssertEqual(s.breakDisplays, .all)
        XCTAssertEqual(s.reminderStyle, .overlay)
        for event in SoundEvent.allCases { XCTAssertFalse(event.isEnabled(in: s)) }
    }

    func testEveryNewPreferenceRoundTrips() throws {
        var s = AppSettings.defaults
        s.startPaused = true
        s.showCountdownSeconds = false
        s.allowSkip = false
        s.snoozeMinutes = 17
        s.warningDuration = 21
        s.allowEarlyFinish = false
        s.readyDelay = 12
        s.showClock = false
        s.showBreakCountdown = false
        s.breakMessage = "Take a breath"
        s.blinkMessage = "Blink slowly"
        s.postureMessage = "Relax your shoulders"
        s.breakDisplays = .primary
        s.reminderDisplays = .pointer
        s.reminderStyle = .banner
        s.bannerPosition = .bottom
        s.appearance = .dark
        s.dimmingPercent = 70
        s.textSizePercent = 125
        s.animationsEnabled = false
        s.soundOnWarning = true
        s.soundOnBreakStart = true
        s.soundOnBreakEnd = true
        s.soundOnReminder = true
        s.sound = .purr
        s.volumePercent = 65
        s.activeHoursEnabled = true
        s.activeWeekdays = [1, 3, 7]
        s.activeStartMinute = 22 * 60
        s.activeEndMinute = 6 * 60
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(restored, s)
        XCTAssertEqual(restored.normalized, s)
    }

    func testV1PreferencesKeepTheirValuesAndGainSafeDefaults() throws {
        let data = Data("{\"workMinutes\":42,\"breakSeconds\":90,\"showCountdown\":false}".utf8)
        let s = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(s.workMinutes, 42)
        XCTAssertEqual(s.breakSeconds, 90)
        XCTAssertFalse(s.showCountdown)
        XCTAssertEqual(s.snoozeMinutes, 5)
        XCTAssertTrue(s.allowEarlyFinish)
        XCTAssertFalse(s.activeHoursEnabled)
        XCTAssertFalse(s.soundOnBreakStart)
    }

    func testUnknownEnumCasesDoNotDiscardKnownPreferences() throws {
        let data = Data("{\"workMinutes\":42,\"breakDisplays\":\"future\",\"reminderDisplays\":\"future\",\"reminderStyle\":\"future\",\"appearance\":\"future\",\"bannerPosition\":\"future\",\"sound\":\"future\"}".utf8)
        let s = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(s.workMinutes, 42)
        XCTAssertEqual(s.breakDisplays, .all)
        XCTAssertEqual(s.reminderDisplays, .all)
        XCTAssertEqual(s.reminderStyle, .overlay)
        XCTAssertEqual(s.appearance, .system)
        XCTAssertEqual(s.bannerPosition, .top)
        XCTAssertEqual(s.sound, .glass)
    }

    func testExtendedNumericBoundsCannotOverflow() {
        var s = AppSettings.defaults
        s.snoozeMinutes = .max
        s.warningDuration = .min
        s.readyDelay = .max
        s.breakSeconds = .min
        s.dimmingPercent = .max
        s.textSizePercent = .min
        s.volumePercent = .min
        s.activeStartMinute = .min
        s.activeEndMinute = .max
        s.activeWeekdays = [.min, 2, 2, 7, 8, .max]
        let n = s.normalized
        XCTAssertEqual(n.snoozeMinutes, 60)
        XCTAssertEqual(n.warningDuration, 3)
        XCTAssertEqual(n.readyDelay, 4)
        XCTAssertEqual(n.dimmingPercent, 90)
        XCTAssertEqual(n.textSizePercent, 80)
        XCTAssertEqual(n.volumePercent, 0)
        XCTAssertEqual(n.activeStartMinute, 0)
        XCTAssertEqual(n.activeEndMinute, 1439)
        XCTAssertEqual(n.activeWeekdays, [2, 7])
        XCTAssertEqual(n.normalized, n)
        XCTAssertTrue(n.breakConfiguration.isValid)
    }

    func testInverseExtendedBoundsAreNormalized() {
        var s = AppSettings.defaults
        s.snoozeMinutes = .min
        s.warningDuration = .max
        s.readyDelay = .min
        s.dimmingPercent = .min
        s.textSizePercent = .max
        s.volumePercent = .max
        let n = s.normalized
        XCTAssertEqual(n.snoozeMinutes, 1)
        XCTAssertEqual(n.warningDuration, 30)
        XCTAssertEqual(n.readyDelay, 0)
        XCTAssertEqual(n.dimmingPercent, 0)
        XCTAssertEqual(n.textSizePercent, 150)
        XCTAssertEqual(n.volumePercent, 100)
    }

    func testMessagesAreBoundedAndWhitespaceIsCleaned() {
        var s = AppSettings.defaults
        s.breakMessage = "  Take\n a\t breath  "
        s.blinkMessage = String(repeating: "a", count: 500)
        s.postureMessage = " \n\t "
        let n = s.normalized
        XCTAssertEqual(n.breakMessage, "Take a breath")
        XCTAssertEqual(n.blinkMessage.count, 120)
        XCTAssertEqual(n.postureMessage, AppSettings.defaults.postureMessage)
        XCTAssertEqual(n.normalized, n)
    }

    func testUnicodeMessagesPreserveWholeCharacters() {
        var s = AppSettings.defaults
        s.breakMessage = String(repeating: "\u{1F331}", count: 121)
        XCTAssertEqual(s.normalized.breakMessage.count, 120)
        XCTAssertEqual(s.normalized.breakMessage, String(repeating: "\u{1F331}", count: 120))
    }

    func testPresetsOnlyChangeTimingAndDependentBounds() {
        var s = AppSettings.defaults
        s.blinkEnabled = false
        s.volumePercent = 77
        s.reminderStyle = .banner
        s.activeHoursEnabled = true
        for preset in TimingPreset.allCases {
            let n = s.applying(preset)
            XCTAssertEqual(n.workMinutes, preset.timing.work)
            XCTAssertEqual(n.breakSeconds, preset.timing.rest)
            XCTAssertFalse(n.blinkEnabled)
            XCTAssertEqual(n.volumePercent, 77)
            XCTAssertEqual(n.reminderStyle, .banner)
            XCTAssertTrue(n.activeHoursEnabled)
            XCTAssertTrue(n.breakConfiguration.isValid)
        }
    }

    func testPresetAndRestoreAreDraftOnly() {
        var calls = 0
        let editor = SettingsEditor(settings: .defaults) { _ in calls += 1 }
        editor.draft = editor.draft.applying(.focus)
        XCTAssertTrue(editor.hasChanges)
        XCTAssertEqual(editor.saved, .defaults)
        editor.restoreDefaults()
        XCTAssertFalse(editor.hasChanges)
        XCTAssertEqual(calls, 0)
    }

    func testAppearanceSoundAndHoursDoNotResetTheWorkSession() {
        var schedule = BreakSchedule(now: 0)
        schedule.skipUpcomingBreak()
        var s = AppSettings.defaults
        s.appearance = .dark
        s.dimmingPercent = 80
        s.textSizePercent = 150
        s.breakMessage = "Rest"
        s.readyDelay = 20
        s.snoozeMinutes = 30
        s.allowSkip = false
        s.activeHoursEnabled = true
        s.soundOnReminder = true
        schedule.updateConfiguration(s.breakConfiguration, at: 123)
        XCTAssertEqual(schedule.remainingSeconds(at: 123), 1677)
        XCTAssertTrue(schedule.skipsUpcomingBreak)
    }

    func testExtendedSettingsPersistWithoutTouchingUnrelatedDefaults() throws {
        let name = "LookAwayTests.extended.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("keep", forKey: "unrelated")
        var s = AppSettings.defaults
        s.startPaused = true
        s.activeHoursEnabled = true
        s.activeWeekdays = [7, 2, 2]
        s.reminderStyle = .banner
        s.snoozeMinutes = 15
        s.breakDisplays = .pointer
        try SettingsStore(defaults: defaults).save(s)
        XCTAssertEqual(SettingsStore(defaults: defaults).value, s.normalized)
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
        let data = try XCTUnwrap(defaults.data(forKey: SettingsStore.storageKey))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["launchAtLogin"], "The system registration is not a persisted preference")
    }

    func testCountdownCanShowSecondsOrRoundedUpMinutes() {
        XCTAssertEqual(CountdownText.format(61, showsSeconds: true), "01:01")
        XCTAssertEqual(CountdownText.format(-1, showsSeconds: true), "00:00")
        XCTAssertEqual(CountdownText.format(0, showsSeconds: false), "0 min")
        XCTAssertEqual(CountdownText.format(1, showsSeconds: false), "1 min")
        XCTAssertEqual(CountdownText.format(60, showsSeconds: false), "1 min")
        XCTAssertEqual(CountdownText.format(61, showsSeconds: false), "2 min")
        XCTAssertFalse(CountdownText.format(.max, showsSeconds: false).isEmpty)
    }

    func testEachSoundEventIsIndependent() {
        var s = AppSettings.defaults
        s.soundOnBreakStart = true
        XCTAssertTrue(SoundEvent.breakStart.isEnabled(in: s))
        XCTAssertFalse(SoundEvent.breakEnd.isEnabled(in: s))
        XCTAssertFalse(SoundEvent.warning.isEnabled(in: s))
        XCTAssertFalse(SoundEvent.reminder.isEnabled(in: s))
        s.soundOnWarning = true
        s.soundOnBreakEnd = true
        s.soundOnReminder = true
        for event in SoundEvent.allCases { XCTAssertTrue(event.isEnabled(in: s)) }
    }

    func testSilentSoundSettingsDoNotRequireAnAudioDevice() {
        let player = SoundPlayer()
        XCTAssertFalse(player.play(event: .warning, settings: .defaults))
        var s = AppSettings.defaults
        s.volumePercent = 0
        XCTAssertTrue(player.preview(settings: s))
        player.stop()
    }
}

@MainActor
final class ExtendedPresentationTests: XCTestCase {
    func testEarlyFinishWaitsForTheConfiguredDelay() throws {
        var now: TimeInterval = 0
        var s = AppSettings.defaults
        s.readyDelay = 10
        let overlay = OverlayController(clock: { now }, screens: { [] }, dismissalDuration: 0)
        var completed = 0
        overlay.show(mode: .breakSession(seconds: 30), settings: s, onHide: { completed += 1 })
        defer { overlay.hide(cleanupOnly: true) }
        let id = try XCTUnwrap(overlay.presentationID)
        now = 9
        overlay.tick()
        overlay.finishEarly(presentationID: id)
        XCTAssertEqual(completed, 0)
        now = 10
        overlay.tick()
        overlay.finishEarly(presentationID: id)
        overlay.finishEarly(presentationID: id)
        XCTAssertEqual(completed, 1)
    }

    func testDisabledEarlyFinishStillCompletesAutomatically() throws {
        var now: TimeInterval = 0
        var s = AppSettings.defaults
        s.allowEarlyFinish = false
        let overlay = OverlayController(clock: { now }, screens: { [] }, dismissalDuration: 0)
        var completed = 0
        overlay.show(mode: .breakSession(seconds: 30), settings: s, onHide: { completed += 1 })
        let id = try XCTUnwrap(overlay.presentationID)
        now = 20
        overlay.tick()
        overlay.finishEarly(presentationID: id)
        XCTAssertEqual(completed, 0)
        now = 30
        overlay.tick()
        XCTAssertEqual(completed, 1)
        XCTAssertNil(overlay.presentationID)
    }

    func testZeroDelayAllowsImmediateEarlyFinish() throws {
        var s = AppSettings.defaults
        s.readyDelay = 0
        let overlay = OverlayController(screens: { [] }, dismissalDuration: 0)
        overlay.show(mode: .breakSession(seconds: 30), settings: s)
        overlay.finishEarly(presentationID: try XCTUnwrap(overlay.presentationID))
        XCTAssertNil(overlay.presentationID)
    }

    func testPresentationRetainsItsOriginalSettingsSnapshot() {
        var s = AppSettings.defaults
        s.readyDelay = 10
        s.breakMessage = "Original"
        let model = OverlayViewModel(duration: 30, settings: s)
        s.readyDelay = 0
        s.breakMessage = "Changed"
        XCTAssertEqual(model.settings.breakMessage, "Original")
        XCTAssertEqual(model.readyDelayRemaining, 10)
        XCTAssertFalse(model.canFinishEarly)
    }

    func testHiddenClockAndCountdownDoNotDisableCompletion() {
        var now: TimeInterval = 0
        var s = AppSettings.defaults
        s.showClock = false
        s.showBreakCountdown = false
        s.allowEarlyFinish = false
        s.animationsEnabled = false
        let overlay = OverlayController(clock: { now }, screens: { [] })
        overlay.show(mode: .breakSession(seconds: 30), settings: s)
        now = 30
        overlay.tick()
        XCTAssertNil(overlay.presentationID)
    }

    func testCompactReminderUsesTheSameLifecycleAndCannotInterruptBreaks() {
        var now: TimeInterval = 0
        var s = AppSettings.defaults
        s.reminderStyle = .banner
        let overlay = OverlayController(clock: { now }, screens: { [] })
        overlay.show(mode: .reminder(message: "Custom", duration: 2), settings: s)
        XCTAssertFalse(overlay.isShowingBreak)
        now = 2
        overlay.tick()
        XCTAssertNil(overlay.presentationID)
        overlay.show(mode: .breakSession(seconds: 30), settings: s)
        let id = overlay.presentationID
        overlay.show(mode: .reminder(message: "Custom", duration: 2), settings: s)
        XCTAssertEqual(overlay.presentationID, id)
        overlay.hide(cleanupOnly: true)
    }

    func testStaleEarlyFinishCannotCloseANewPresentation() throws {
        var s = AppSettings.defaults
        s.readyDelay = 0
        let overlay = OverlayController(screens: { [] }, dismissalDuration: 0)
        overlay.show(mode: .breakSession(seconds: 30), settings: s)
        let old = try XCTUnwrap(overlay.presentationID)
        overlay.hide()
        overlay.show(mode: .breakSession(seconds: 30), settings: s)
        overlay.finishEarly(presentationID: old)
        XCTAssertTrue(overlay.isShowingBreak)
        overlay.hide(cleanupOnly: true)
    }

    func testDisplaySelectionUsesPrimaryAndPointerWithSafeFallbacks() {
        let frames = [NSRect(x: 0, y: 0, width: 1000, height: 800), NSRect(x: -800, y: 200, width: 800, height: 600)]
        let point = NSPoint(x: -100, y: 300)
        XCTAssertEqual(DisplaySelector.indices(for: .all, frames: frames, pointer: point), [0, 1])
        XCTAssertEqual(DisplaySelector.indices(for: .primary, frames: frames, pointer: point), [0])
        XCTAssertEqual(DisplaySelector.indices(for: .pointer, frames: frames, pointer: point), [1])
        XCTAssertEqual(DisplaySelector.indices(for: .pointer, frames: frames, pointer: NSPoint(x: 2000, y: 2000)), [0])
        for selection in DisplaySelection.allCases {
            XCTAssertEqual(DisplaySelector.indices(for: selection, frames: [], pointer: point), [])
        }
    }

    func testEveryBannerPositionStaysWithinVisibleFrames() {
        for frame in [NSRect(x: -1400, y: 300, width: 1400, height: 900), NSRect(x: 20, y: -100, width: 100, height: 80)] {
            for position in BannerPosition.allCases {
                let result = BannerLayout.frame(in: frame, position: position)
                XCTAssertTrue(frame.contains(result))
                XCTAssertEqual(result.midX, frame.midX)
                if position == .center { XCTAssertEqual(result.midY, frame.midY) }
            }
        }
    }

    func testInvalidWarningDurationsDoNotCreatePresentations() {
        let banner = PopupBannerController(screens: { [] })
        for duration in [0.0, -1.0, Double.infinity, Double.nan] {
            banner.show(message: "Test", onKnow: {}, onSkipBreak: {}, onAddFiveMinutes: {}, duration: duration)
            XCTAssertNil(banner.presentationID)
        }
    }
}
