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

struct Reminder: Codable, Equatable, Identifiable {
    static let blinkID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    static let postureID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!

    static let defaultBlink = Reminder(
        id: blinkID,
        name: "Blink",
        message: "Blink your eyes",
        intervalMinutes: 5,
        enabled: true
    )
    static let defaultPosture = Reminder(
        id: postureID,
        name: "Posture",
        message: "Adjust your posture",
        intervalMinutes: 10,
        enabled: true
    )

    var id: UUID = UUID()
    var name: String
    var message: String
    var intervalMinutes: Int
    var enabled: Bool
}

enum SettingsValidationError: Error, Equatable {
    case invalidReminder(String)
}

/// User-facing units are kept separate from the scheduler's seconds.
struct AppSettings: Codable, Equatable {
    static let defaults = AppSettings()
    static let workMinutesRange = 1...180
    static let breakSecondsRange = 5...600
    static let reminderMinutesRange = 1...120
    static let reminderSecondsRange = 1...15
    static let breakQuotes = [
        "Look far away and let your eyes reset.",
        "Relax your shoulders and unclench your jaw.",
        "Give your eyes a moment to focus on something distant.",
        "Stand up, breathe slowly, and reset your posture.",
        "Small pauses keep long sessions sustainable.",
        "Your next task can wait for one quiet minute.",
        "Blink slowly and let your eyes rehydrate.",
        "Move a little now so your body complains less later.",
        "Rest is part of the work, not a detour from it.",
        "Notice something outside the screen.",
        "Take a slow breath and soften your gaze.",
        "Let your attention wander somewhere farther than this display."
    ]

    var workMinutes = 30
    var breakSeconds = 30
    var reminders: [Reminder] = [.defaultBlink, .defaultPosture]
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
    var randomBreakQuoteEnabled = false
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

    // Temporary source-compatibility accessors while the UI migrates to reminders.
    // They are computed, never encoded, and are removed once all callers use reminders directly.
    var blinkEnabled: Bool {
        get { reminder(id: Reminder.blinkID)?.enabled ?? false }
        set { updateSeedReminder(.defaultBlink) { $0.enabled = newValue } }
    }

    var blinkMinutes: Int {
        get { reminder(id: Reminder.blinkID)?.intervalMinutes ?? Reminder.defaultBlink.intervalMinutes }
        set { updateSeedReminder(.defaultBlink) { $0.intervalMinutes = newValue } }
    }

    var blinkMessage: String {
        get { reminder(id: Reminder.blinkID)?.message ?? Reminder.defaultBlink.message }
        set { updateSeedReminder(.defaultBlink) { $0.message = newValue } }
    }

    var postureEnabled: Bool {
        get { reminder(id: Reminder.postureID)?.enabled ?? false }
        set { updateSeedReminder(.defaultPosture) { $0.enabled = newValue } }
    }

    var postureMinutes: Int {
        get { reminder(id: Reminder.postureID)?.intervalMinutes ?? Reminder.defaultPosture.intervalMinutes }
        set { updateSeedReminder(.defaultPosture) { $0.intervalMinutes = newValue } }
    }

    var postureMessage: String {
        get { reminder(id: Reminder.postureID)?.message ?? Reminder.defaultPosture.message }
        set { updateSeedReminder(.defaultPosture) { $0.message = newValue } }
    }

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
        result.reminders = reminders.map { reminder in
            var value = reminder
            value.name = Self.cleanedText(reminder.name, limit: 120)
            value.message = Self.cleanedText(reminder.message, limit: 120)
            value.intervalMinutes = Self.clamp(reminder.intervalMinutes, to: Self.reminderMinutesRange)
            return value
        }
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
        return result
    }

    var reminderValidationMessage: String? {
        for reminder in normalized.reminders {
            if reminder.name.isEmpty { return "Reminder name is required." }
            if reminder.message.isEmpty { return "Reminder message is required." }
        }
        return nil
    }

    var resolvedBreakMessage: String {
        let value = normalized
        guard value.randomBreakQuoteEnabled else { return value.breakMessage }
        return Self.breakQuotes.randomElement() ?? value.breakMessage
    }

    var breakConfiguration: BreakConfiguration {
        let value = normalized
        return BreakConfiguration(
            workSeconds: value.workMinutes * 60,
            breakSeconds: value.breakSeconds,
            warningSeconds: value.warningEnabled ? value.warningSeconds : 0,
            reminders: value.reminders.filter(\.enabled).map {
                ReminderScheduleConfiguration(id: $0.id, intervalSeconds: $0.intervalMinutes * 60)
            },
            reminderSeconds: value.reminderSeconds
        )
    }

    func applying(_ preset: TimingPreset) -> AppSettings {
        var value = self
        value.workMinutes = preset.timing.work
        value.breakSeconds = preset.timing.rest
        return value.normalized
    }

    private func reminder(id: UUID) -> Reminder? {
        reminders.first { $0.id == id }
    }

    private mutating func updateSeedReminder(_ fallback: Reminder, _ update: (inout Reminder) -> Void) {
        if let index = reminders.firstIndex(where: { $0.id == fallback.id }) {
            update(&reminders[index])
        } else {
            var reminder = fallback
            update(&reminder)
            reminders.append(reminder)
        }
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func cleanedText(_ value: String, limit: Int) -> String {
        let clean = value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        return String(clean.prefix(limit))
    }

    private static func message(_ value: String, fallback: String) -> String {
        let clean = cleanedText(value, limit: 120)
        return clean.isEmpty ? fallback : clean
    }

    private enum CodingKeys: String, CodingKey {
        case workMinutes, breakSeconds, reminders
        case warningEnabled, warningSeconds, reminderSeconds, showCountdown
        case startPaused, showCountdownSeconds, allowSkip, snoozeMinutes, warningDuration
        case allowEarlyFinish, readyDelay, showClock, showBreakCountdown
        case breakMessage, randomBreakQuoteEnabled, breakDisplays, reminderDisplays
        case reminderStyle, bannerPosition, appearance, dimmingPercent, textSizePercent, animationsEnabled
        case soundOnWarning, soundOnBreakStart, soundOnBreakEnd, soundOnReminder, sound, volumePercent
        case activeHoursEnabled, activeWeekdays, activeStartMinute, activeEndMinute
    }

    private enum LegacyReminderKeys: String, CodingKey {
        case blinkEnabled, blinkMinutes, blinkMessage
        case postureEnabled, postureMinutes, postureMessage
    }
}

extension AppSettings {
    // Keep the v1 storage key and migrate legacy Blink/Posture fields in place.
    init(from decoder: Decoder) throws {
        self.init()
        let v = try decoder.container(keyedBy: CodingKeys.self)
        workMinutes = try v.decodeIfPresent(Int.self, forKey: .workMinutes) ?? workMinutes
        breakSeconds = try v.decodeIfPresent(Int.self, forKey: .breakSeconds) ?? breakSeconds

        if v.contains(.reminders) {
            reminders = try v.decode([Reminder].self, forKey: .reminders)
        } else {
            let legacy = try decoder.container(keyedBy: LegacyReminderKeys.self)
            var blink = Reminder.defaultBlink
            blink.enabled = try legacy.decodeIfPresent(Bool.self, forKey: .blinkEnabled) ?? blink.enabled
            blink.intervalMinutes = try legacy.decodeIfPresent(Int.self, forKey: .blinkMinutes) ?? blink.intervalMinutes
            blink.message = try legacy.decodeIfPresent(String.self, forKey: .blinkMessage) ?? blink.message

            var posture = Reminder.defaultPosture
            posture.enabled = try legacy.decodeIfPresent(Bool.self, forKey: .postureEnabled) ?? posture.enabled
            posture.intervalMinutes = try legacy.decodeIfPresent(Int.self, forKey: .postureMinutes) ?? posture.intervalMinutes
            posture.message = try legacy.decodeIfPresent(String.self, forKey: .postureMessage) ?? posture.message
            reminders = [blink, posture]
        }

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
        randomBreakQuoteEnabled = try v.decodeIfPresent(Bool.self, forKey: .randomBreakQuoteEnabled) ?? randomBreakQuoteEnabled
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
        if let message = next.reminderValidationMessage {
            throw SettingsValidationError.invalidReminder(message)
        }
        guard next != value else { return false }
        let data = try JSONEncoder().encode(next)
        defaults.set(data, forKey: Self.storageKey)
        value = next
        return true
    }
}
