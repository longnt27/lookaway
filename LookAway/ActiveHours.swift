import Foundation

extension AppSettings {
    /// Local calendar time. Overnight windows belong to the day on which they start.
    /// Equal start/end means the entire selected calendar day. No selected days means off.
    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard activeHoursEnabled else { return true }
        let value = normalized
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let day = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return false }
        let time = hour * 60 + minute
        let start = value.activeStartMinute
        let end = value.activeEndMinute
        if start == end { return value.activeWeekdays.contains(day) }
        if start < end {
            return value.activeWeekdays.contains(day) && time >= start && time < end
        }
        if time >= start { return value.activeWeekdays.contains(day) }
        let previousDay = day == 1 ? 7 : day - 1
        return time < end && value.activeWeekdays.contains(previousDay)
    }
}

/// Own only pauses caused by active hours. Never resume a user's manual pause.
struct ActiveHoursGate {
    private(set) var ownsPause = false

    mutating func reconcile(allowed: Bool, schedule: inout BreakSchedule, at now: TimeInterval) {
        guard !schedule.isSleeping, schedule.phase != .onBreak else { return }
        if allowed {
            if ownsPause { schedule.resume(at: now) }
            ownsPause = false
        } else if schedule.phase == .working {
            schedule.pause(at: now)
            ownsPause = true
        }
    }

    mutating func cancelAutomaticResume() { ownsPause = false }
}

struct CountdownText {
    static func format(_ seconds: Int, showsSeconds: Bool) -> String {
        let value = max(0, seconds)
        if showsSeconds { return String(format: "%02d:%02d", value / 60, value % 60) }
        // Avoid value + 59 overflow, even with corrupt input.
        return "\(value / 60 + (value % 60 == 0 ? 0 : 1)) min"
    }
}
