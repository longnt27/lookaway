import Foundation

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

    var warningSecondsRange: ClosedRange<Int> {
        // Clamp before multiplying: preferences can contain arbitrary integers.
        let minutes = min(max(workMinutes, Self.workMinutesRange.lowerBound),
                          Self.workMinutesRange.upperBound)
        return 5...min(300, minutes * 60 - 1)
    }

    var normalized: AppSettings {
        var result = self
        result.workMinutes = Self.clamp(workMinutes, to: Self.workMinutesRange)
        result.breakSeconds = Self.clamp(breakSeconds, to: Self.breakSecondsRange)
        result.blinkMinutes = Self.clamp(blinkMinutes, to: Self.reminderMinutesRange)
        result.postureMinutes = Self.clamp(postureMinutes, to: Self.reminderMinutesRange)
        result.warningSeconds = Self.clamp(warningSeconds, to: result.warningSecondsRange)
        result.reminderSeconds = Self.clamp(reminderSeconds, to: Self.reminderSecondsRange)
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

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private enum CodingKeys: String, CodingKey {
        case workMinutes, breakSeconds, blinkEnabled, blinkMinutes
        case postureEnabled, postureMinutes, warningEnabled, warningSeconds
        case reminderSeconds, showCountdown
    }
}

extension AppSettings {
    // Missing fields use defaults, so adding a preference does not discard older settings.
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        workMinutes = try values.decodeIfPresent(Int.self, forKey: .workMinutes) ?? workMinutes
        breakSeconds = try values.decodeIfPresent(Int.self, forKey: .breakSeconds) ?? breakSeconds
        blinkEnabled = try values.decodeIfPresent(Bool.self, forKey: .blinkEnabled) ?? blinkEnabled
        blinkMinutes = try values.decodeIfPresent(Int.self, forKey: .blinkMinutes) ?? blinkMinutes
        postureEnabled = try values.decodeIfPresent(Bool.self, forKey: .postureEnabled) ?? postureEnabled
        postureMinutes = try values.decodeIfPresent(Int.self, forKey: .postureMinutes) ?? postureMinutes
        warningEnabled = try values.decodeIfPresent(Bool.self, forKey: .warningEnabled) ?? warningEnabled
        warningSeconds = try values.decodeIfPresent(Int.self, forKey: .warningSeconds) ?? warningSeconds
        reminderSeconds = try values.decodeIfPresent(Int.self, forKey: .reminderSeconds) ?? reminderSeconds
        showCountdown = try values.decodeIfPresent(Bool.self, forKey: .showCountdown) ?? showCountdown
    }
}

/// Stores only LookAway preferences; never resets the application's defaults domain.
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
        // Encode before changing in-memory state. One key avoids partially saved fields.
        let data = try JSONEncoder().encode(next)
        defaults.set(data, forKey: Self.storageKey)
        value = next
        return true
    }
}
