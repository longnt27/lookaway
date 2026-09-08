import Foundation

enum DisplaySelection: String, Codable, CaseIterable, Identifiable {
    case all, primary, pointer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All displays"
        case .primary: return "Primary display"
        case .pointer: return "Display under pointer"
        }
    }
}

enum ReminderStyle: String, Codable, CaseIterable, Identifiable {
    case overlay, banner
    var id: String { rawValue }
    var title: String { self == .overlay ? "Full-screen overlay" : "Compact banner" }
}

enum BannerPosition: String, Codable, CaseIterable, Identifiable {
    case top, center, bottom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { self == .system ? "Follow system" : rawValue.capitalized }
}

enum ReminderSound: String, Codable, CaseIterable, Identifiable {
    case glass = "Glass", tink = "Tink", pop = "Pop", purr = "Purr"
    var id: String { rawValue }
}

enum TimingPreset: String, CaseIterable, Identifiable {
    case standard, frequent, focus, deepFocus
    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: return "Standard: 30 min / 30 sec"
        case .frequent: return "Frequent: 20 min / 20 sec"
        case .focus: return "Focus: 25 min / 5 min"
        case .deepFocus: return "Long focus: 50 min / 10 min"
        }
    }
    var timing: (work: Int, rest: Int) {
        switch self {
        case .standard: return (30, 30)
        case .frequent: return (20, 20)
        case .focus: return (25, 300)
        case .deepFocus: return (50, 600)
        }
    }
}

/// User-facing units are kept separate from the scheduler's seconds.
struct AppSettings: Codable, Equatable {
    static let defaults = AppSettings()
    static let workMinutesRange = 1...180
    static let breakSecondsRange = 5...600
    static let reminderMinutesRange = 1...120
    static let reminderSecondsRange = 1...15

    var workMinutes = 30
    var breakSeconds = 30
    var blinkEnabled = true
    var blinkMinutes = 5
    var postureEnabled = true
    var postureMinutes = 10
    var warningEnabled = true
    var warningSeconds = 60
    var reminderSeconds = 2
    var showCountdown = true

    var startPaused = false
    var showCountdownSeconds = true
    var allowSkip = true
    var snoozeMinutes = 5
    var warningDuration = 10
    var allowEarlyFinish = true
    var readyDelay = 3
    var showClock = true
    var showBreakCountdown = true
    var breakMessage = "Look away from your screen"
    var blinkMessage = "Blink your eyes"
    var postureMessage = "Adjust your posture"
    var breakDisplays: DisplaySelection = .all
    var reminderDisplays: DisplaySelection = .all
    var reminderStyle: ReminderStyle = .overlay
    var bannerPosition: BannerPosition = .top
    var appearance: AppAppearance = .system
    var dimmingPercent = 25
    var textSizePercent = 100
    var animationsEnabled = true
    var soundOnWarning = false
    var soundOnBreakStart = false
    var soundOnBreakEnd = false
    var soundOnReminder = false
    var sound: ReminderSound = .glass
    var volumePercent = 40
    var activeHoursEnabled = false
    // Calendar weekday numbers: Sunday = 1, Monday = 2, ... Saturday = 7.
    var activeWeekdays = [2, 3, 4, 5, 6]
    var activeStartMinute = 9 * 60
    var activeEndMinute = 17 * 60

    var warningSecondsRange: ClosedRange<Int> {
        let minutes = Self.clamp(workMinutes, to: Self.workMinutesRange)
        return 5...min(300, minutes * 60 - 1)
    }

    var readyDelayRange: ClosedRange<Int> {
        0...min(60, Self.clamp(breakSeconds, to: Self.breakSecondsRange) - 1)
    }

    var normalized: AppSettings {
        var result = self
        result.workMinutes = Self.clamp(workMinutes, to: Self.workMinutesRange)
        result.breakSeconds = Self.clamp(breakSeconds, to: Self.breakSecondsRange)
        result.blinkMinutes = Self.clamp(blinkMinutes, to: Self.reminderMinutesRange)
        result.postureMinutes = Self.clamp(postureMinutes, to: Self.reminderMinutesRange)
        result.warningSeconds = Self.clamp(warningSeconds, to: result.warningSecondsRange)
        result.reminderSeconds = Self.clamp(reminderSeconds, to: Self.reminderSecondsRange)
        result.snoozeMinutes = Self.clamp(snoozeMinutes, to: 1...60)
        result.warningDuration = Self.clamp(warningDuration, to: 3...30)
        result.readyDelay = Self.clamp(readyDelay, to: result.readyDelayRange)
        result.dimmingPercent = Self.clamp(dimmingPercent, to: 0...90)
        result.textSizePercent = Self.clamp(textSizePercent, to: 80...150)
        result.volumePercent = Self.clamp(volumePercent, to: 0...100)
        result.activeStartMinute = Self.clamp(activeStartMinute, to: 0...1439)
        result.activeEndMinute = Self.clamp(activeEndMinute, to: 0...1439)
        result.activeWeekdays = Array(Set(activeWeekdays.filter { (1...7).contains($0) })).sorted()
        result.breakMessage = Self.message(breakMessage, fallback: Self.defaults.breakMessage)
        result.blinkMessage = Self.message(blinkMessage, fallback: Self.defaults.blinkMessage)
        result.postureMessage = Self.message(postureMessage, fallback: Self.defaults.postureMessage)
        return result
    }

    var breakConfiguration: BreakConfiguration {
        let value = normalized
        return BreakConfiguration(workSeconds: value.workMinutes * 60,
                                  breakSeconds: value.breakSeconds,
                                  blinkSeconds: value.blinkMinutes * 60,
                                  postureSeconds: value.postureMinutes * 60,
                                  warningSeconds: value.warningEnabled ? value.warningSeconds : 0,
                                  reminderSeconds: value.reminderSeconds,
                                  blinkEnabled: value.blinkEnabled,
                                  postureEnabled: value.postureEnabled)
    }

    func applying(_ preset: TimingPreset) -> AppSettings {
        var value = self
        value.workMinutes = preset.timing.work
        value.breakSeconds = preset.timing.rest
        // Presets only change the two advertised durations, not other preferences.
        return value.normalized
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func message(_ value: String, fallback: String) -> String {
        let clean = value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        return clean.isEmpty ? fallback : String(clean.prefix(120))
    }

    private enum CodingKeys: String, CodingKey {
        case workMinutes, breakSeconds, blinkEnabled, blinkMinutes
        case postureEnabled, postureMinutes, warningEnabled, warningSeconds, reminderSeconds, showCountdown
        case startPaused, showCountdownSeconds, allowSkip, snoozeMinutes, warningDuration
        case allowEarlyFinish, readyDelay, showClock, showBreakCountdown
        case breakMessage, blinkMessage, postureMessage, breakDisplays, reminderDisplays
        case reminderStyle, bannerPosition, appearance, dimmingPercent, textSizePercent, animationsEnabled
        case soundOnWarning, soundOnBreakStart, soundOnBreakEnd, soundOnReminder, sound, volumePercent
        case activeHoursEnabled, activeWeekdays, activeStartMinute, activeEndMinute
    }
}

extension AppSettings {
    // Keep the v1 storage key and default missing fields: older preferences migrate in place.
    init(from decoder: Decoder) throws {
        self.init()
        let v = try decoder.container(keyedBy: CodingKeys.self)
        workMinutes = try v.decodeIfPresent(Int.self, forKey: .workMinutes) ?? workMinutes
        breakSeconds = try v.decodeIfPresent(Int.self, forKey: .breakSeconds) ?? breakSeconds
        blinkEnabled = try v.decodeIfPresent(Bool.self, forKey: .blinkEnabled) ?? blinkEnabled
        blinkMinutes = try v.decodeIfPresent(Int.self, forKey: .blinkMinutes) ?? blinkMinutes
        postureEnabled = try v.decodeIfPresent(Bool.self, forKey: .postureEnabled) ?? postureEnabled
        postureMinutes = try v.decodeIfPresent(Int.self, forKey: .postureMinutes) ?? postureMinutes
        warningEnabled = try v.decodeIfPresent(Bool.self, forKey: .warningEnabled) ?? warningEnabled
        warningSeconds = try v.decodeIfPresent(Int.self, forKey: .warningSeconds) ?? warningSeconds
        reminderSeconds = try v.decodeIfPresent(Int.self, forKey: .reminderSeconds) ?? reminderSeconds
        showCountdown = try v.decodeIfPresent(Bool.self, forKey: .showCountdown) ?? showCountdown
        startPaused = try v.decodeIfPresent(Bool.self, forKey: .startPaused) ?? startPaused
        showCountdownSeconds = try v.decodeIfPresent(Bool.self, forKey: .showCountdownSeconds) ?? showCountdownSeconds
        allowSkip = try v.decodeIfPresent(Bool.self, forKey: .allowSkip) ?? allowSkip
        snoozeMinutes = try v.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? snoozeMinutes
        warningDuration = try v.decodeIfPresent(Int.self, forKey: .warningDuration) ?? warningDuration
        allowEarlyFinish = try v.decodeIfPresent(Bool.self, forKey: .allowEarlyFinish) ?? allowEarlyFinish
        readyDelay = try v.decodeIfPresent(Int.self, forKey: .readyDelay) ?? readyDelay
        showClock = try v.decodeIfPresent(Bool.self, forKey: .showClock) ?? showClock
        showBreakCountdown = try v.decodeIfPresent(Bool.self, forKey: .showBreakCountdown) ?? showBreakCountdown
        breakMessage = try v.decodeIfPresent(String.self, forKey: .breakMessage) ?? breakMessage
        blinkMessage = try v.decodeIfPresent(String.self, forKey: .blinkMessage) ?? blinkMessage
        postureMessage = try v.decodeIfPresent(String.self, forKey: .postureMessage) ?? postureMessage
        // Unknown enum cases from a newer version fall back without losing known preferences.
        breakDisplays = (try? v.decode(DisplaySelection.self, forKey: .breakDisplays)) ?? breakDisplays
        reminderDisplays = (try? v.decode(DisplaySelection.self, forKey: .reminderDisplays)) ?? reminderDisplays
        reminderStyle = (try? v.decode(ReminderStyle.self, forKey: .reminderStyle)) ?? reminderStyle
        bannerPosition = (try? v.decode(BannerPosition.self, forKey: .bannerPosition)) ?? bannerPosition
        appearance = (try? v.decode(AppAppearance.self, forKey: .appearance)) ?? appearance
        dimmingPercent = try v.decodeIfPresent(Int.self, forKey: .dimmingPercent) ?? dimmingPercent
        textSizePercent = try v.decodeIfPresent(Int.self, forKey: .textSizePercent) ?? textSizePercent
        animationsEnabled = try v.decodeIfPresent(Bool.self, forKey: .animationsEnabled) ?? animationsEnabled
        soundOnWarning = try v.decodeIfPresent(Bool.self, forKey: .soundOnWarning) ?? soundOnWarning
        soundOnBreakStart = try v.decodeIfPresent(Bool.self, forKey: .soundOnBreakStart) ?? soundOnBreakStart
        soundOnBreakEnd = try v.decodeIfPresent(Bool.self, forKey: .soundOnBreakEnd) ?? soundOnBreakEnd
        soundOnReminder = try v.decodeIfPresent(Bool.self, forKey: .soundOnReminder) ?? soundOnReminder
        sound = (try? v.decode(ReminderSound.self, forKey: .sound)) ?? sound
        volumePercent = try v.decodeIfPresent(Int.self, forKey: .volumePercent) ?? volumePercent
        activeHoursEnabled = try v.decodeIfPresent(Bool.self, forKey: .activeHoursEnabled) ?? activeHoursEnabled
        activeWeekdays = try v.decodeIfPresent([Int].self, forKey: .activeWeekdays) ?? activeWeekdays
        activeStartMinute = try v.decodeIfPresent(Int.self, forKey: .activeStartMinute) ?? activeStartMinute
        activeEndMinute = try v.decodeIfPresent(Int.self, forKey: .activeEndMinute) ?? activeEndMinute
    }
}

@MainActor
final class SettingsStore {
    static let storageKey = "LookAway.settings.v1"
    private let defaults: UserDefaults
    private(set) var value: AppSettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            value = decoded.normalized
        } else {
            value = .defaults
        }
    }

    @discardableResult
    func save(_ candidate: AppSettings) throws -> Bool {
        let next = candidate.normalized
        guard next != value else { return false }
        let data = try JSONEncoder().encode(next)
        defaults.set(data, forKey: Self.storageKey)
        value = next
        return true
    }
}
