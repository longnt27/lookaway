import Foundation

/// Timing defaults live here rather than being duplicated across UI controllers.
struct BreakConfiguration {
    var workSeconds = 30 * 60
    var breakSeconds = 30
    var blinkSeconds = 5 * 60
    var postureSeconds = 10 * 60
    var warningSeconds = 60
    var reminderSeconds = 2
}

/// A clock-driven state machine. Callers supply monotonic time, so delayed timer
/// callbacks and changes to the system clock cannot stretch a work session.
struct BreakSchedule {
    enum Phase: Equatable {
        case working, paused, onBreak
    }

    enum Event: Equatable {
        case warning, startBreak, skippedBreak, blinkReminder, postureReminder
    }

    let configuration: BreakConfiguration
    private(set) var phase: Phase = .working
    private(set) var skipsUpcomingBreak = false
    private(set) var isSleeping = false

    private var workDeadline: TimeInterval
    private var blinkDeadline: TimeInterval
    private var postureDeadline: TimeInterval
    private var pausedWork: TimeInterval = 0
    private var pausedBlink: TimeInterval = 0
    private var pausedPosture: TimeInterval = 0
    private var hasWarned = false
    private var resumesAfterSleep = false

    init(configuration: BreakConfiguration = BreakConfiguration(), now: TimeInterval) {
        precondition(configuration.workSeconds > 0 && configuration.breakSeconds > 0)
        precondition(configuration.blinkSeconds > 0 && configuration.postureSeconds > 0)
        precondition(configuration.warningSeconds >= 0 && configuration.reminderSeconds > 0)
        self.configuration = configuration
        workDeadline = now + TimeInterval(configuration.workSeconds)
        blinkDeadline = now + TimeInterval(configuration.blinkSeconds)
        postureDeadline = now + TimeInterval(configuration.postureSeconds)
    }

    func remainingSeconds(at now: TimeInterval) -> Int {
        switch phase {
        case .working:
            return Int(ceil(max(0, workDeadline - now)))
        case .paused:
            return Int(ceil(max(0, pausedWork)))
        case .onBreak:
            return 0
        }
    }

    mutating func advance(at now: TimeInterval) -> [Event] {
        guard phase == .working, !isSleeping else { return [] }

        // Breaks take priority over reminders due on the same tick.
        if now >= workDeadline {
            if skipsUpcomingBreak {
                startWork(at: now)
                return [.skippedBreak]
            }
            phase = .onBreak
            return [.startBreak]
        }

        var events: [Event] = []
        if !hasWarned, !skipsUpcomingBreak,
           workDeadline - now <= TimeInterval(configuration.warningSeconds) {
            hasWarned = true
            events.append(.warning)
        }
        if now >= blinkDeadline {
            // Do not replay a backlog of reminders after a delayed callback.
            blinkDeadline = now + TimeInterval(configuration.blinkSeconds)
            events.append(.blinkReminder)
        }
        if now >= postureDeadline {
            postureDeadline = now + TimeInterval(configuration.postureSeconds)
            events.append(.postureReminder)
        }
        return events
    }

    mutating func skipUpcomingBreak() {
        guard phase == .working, !isSleeping else { return }
        skipsUpcomingBreak = true
    }

    @discardableResult
    mutating func postponeBreak(by seconds: Int = 5 * 60, at now: TimeInterval) -> Bool {
        guard phase == .working, !isSleeping, now < workDeadline, seconds > 0 else {
            return false
        }
        workDeadline += TimeInterval(seconds)
        hasWarned = false
        return true
    }

    /// A manual break overrides a pending skip but never restarts an active break.
    @discardableResult
    mutating func startBreakNow() -> Bool {
        guard phase != .onBreak, !isSleeping else { return false }
        skipsUpcomingBreak = false
        phase = .onBreak
        return true
    }

    mutating func finishBreak(at now: TimeInterval) {
        guard phase == .onBreak else { return }
        startWork(at: now)
    }

    mutating func pause(at now: TimeInterval) {
        guard phase == .working, !isSleeping else { return }
        pausedWork = max(0, workDeadline - now)
        pausedBlink = max(0, blinkDeadline - now)
        pausedPosture = max(0, postureDeadline - now)
        phase = .paused
    }

    mutating func resume(at now: TimeInterval) {
        guard phase == .paused, !isSleeping else { return }
        workDeadline = now + pausedWork
        blinkDeadline = now + pausedBlink
        postureDeadline = now + pausedPosture
        phase = .working
    }

    /// Sleep freezes work/reminders. An active break counts as finished; a manual
    /// pause stays paused after waking. Repeated notifications are harmless.
    mutating func prepareForSleep(at now: TimeInterval) {
        guard !isSleeping else { return }
        resumesAfterSleep = phase != .paused
        if phase == .onBreak {
            finishBreak(at: now)
        }
        pause(at: now)
        isSleeping = true
    }

    mutating func wake(at now: TimeInterval) {
        guard isSleeping else { return }
        isSleeping = false
        if resumesAfterSleep {
            resume(at: now)
        }
        resumesAfterSleep = false
    }

    private mutating func startWork(at now: TimeInterval) {
        phase = .working
        workDeadline = now + TimeInterval(configuration.workSeconds)
        blinkDeadline = now + TimeInterval(configuration.blinkSeconds)
        postureDeadline = now + TimeInterval(configuration.postureSeconds)
        skipsUpcomingBreak = false
        hasWarned = false
    }
}
