import Foundation

struct ReminderScheduleConfiguration: Equatable, Identifiable {
    let id: UUID
    let intervalSeconds: Int
}

/// Scheduler configuration in seconds. AppSettings converts user-facing preferences.
struct BreakConfiguration: Equatable {
    var workSeconds: Int
    var breakSeconds: Int
    var warningSeconds: Int
    var reminders: [ReminderScheduleConfiguration]

    // Temporary presentation compatibility. Removed when AppDelegate reads reminder duration from AppSettings.
    var reminderSeconds: Int

    init(
        workSeconds: Int = 30 * 60,
        breakSeconds: Int = 30,
        warningSeconds: Int = 60,
        reminders: [ReminderScheduleConfiguration] = [
            ReminderScheduleConfiguration(id: Reminder.blinkID, intervalSeconds: 5 * 60),
            ReminderScheduleConfiguration(id: Reminder.postureID, intervalSeconds: 10 * 60)
        ],
        reminderSeconds: Int = 2
    ) {
        self.workSeconds = workSeconds
        self.breakSeconds = breakSeconds
        self.warningSeconds = warningSeconds
        self.reminders = reminders
        self.reminderSeconds = reminderSeconds
    }

    // Transitional initializer for old tests/callers while they migrate to reminder IDs.
    init(
        workSeconds: Int,
        breakSeconds: Int,
        blinkSeconds: Int,
        postureSeconds: Int,
        warningSeconds: Int,
        reminderSeconds: Int,
        blinkEnabled: Bool = true,
        postureEnabled: Bool = true
    ) {
        self.workSeconds = workSeconds
        self.breakSeconds = breakSeconds
        self.warningSeconds = warningSeconds
        self.reminderSeconds = reminderSeconds
        var schedules: [ReminderScheduleConfiguration] = []
        if blinkEnabled {
            schedules.append(.init(id: Reminder.blinkID, intervalSeconds: blinkSeconds))
        }
        if postureEnabled {
            schedules.append(.init(id: Reminder.postureID, intervalSeconds: postureSeconds))
        }
        reminders = schedules
    }

    var isValid: Bool {
        let ids = reminders.map(\.id)
        return workSeconds > 0 && breakSeconds > 0 && warningSeconds >= 0 && reminderSeconds > 0
            && reminders.allSatisfy { $0.intervalSeconds > 0 }
            && Set(ids).count == ids.count
    }

    // Temporary source compatibility for the old two-reminder tests. Runtime scheduling is generic.
    var blinkSeconds: Int {
        get { reminders.first { $0.id == Reminder.blinkID }?.intervalSeconds ?? 5 * 60 }
        set { setLegacyReminder(id: Reminder.blinkID, intervalSeconds: newValue, enabled: blinkEnabled) }
    }

    var postureSeconds: Int {
        get { reminders.first { $0.id == Reminder.postureID }?.intervalSeconds ?? 10 * 60 }
        set { setLegacyReminder(id: Reminder.postureID, intervalSeconds: newValue, enabled: postureEnabled) }
    }

    var blinkEnabled: Bool {
        get { reminders.contains { $0.id == Reminder.blinkID } }
        set { setLegacyReminder(id: Reminder.blinkID, intervalSeconds: blinkSeconds, enabled: newValue) }
    }

    var postureEnabled: Bool {
        get { reminders.contains { $0.id == Reminder.postureID } }
        set { setLegacyReminder(id: Reminder.postureID, intervalSeconds: postureSeconds, enabled: newValue) }
    }

    private mutating func setLegacyReminder(id: UUID, intervalSeconds: Int, enabled: Bool) {
        reminders.removeAll { $0.id == id }
        if enabled {
            let item = ReminderScheduleConfiguration(id: id, intervalSeconds: intervalSeconds)
            if id == Reminder.blinkID {
                reminders.insert(item, at: 0)
            } else {
                reminders.append(item)
            }
        }
    }
}

/// A clock-driven state machine. Callers supply monotonic time, so delayed timer
/// callbacks and changes to the system clock cannot stretch a work session.
struct BreakSchedule {
    enum Phase: Equatable {
        case working, paused, onBreak
    }

    enum Event: Equatable {
        case warning, startBreak, skippedBreak
        case reminder(UUID)

        // Temporary source compatibility while older tests and presentation routing migrate.
        static var blinkReminder: Event { .reminder(Reminder.blinkID) }
        static var postureReminder: Event { .reminder(Reminder.postureID) }
    }

    private(set) var configuration: BreakConfiguration
    private(set) var phase: Phase = .working
    private(set) var skipsUpcomingBreak = false
    private(set) var isSleeping = false

    private var workDeadline: TimeInterval
    private var reminderDeadlines: [UUID: TimeInterval]
    private var pausedWork: TimeInterval = 0
    private var pausedReminderRemaining: [UUID: TimeInterval] = [:]
    private var hasWarned = false
    private var resumesAfterSleep = false

    init(configuration: BreakConfiguration = BreakConfiguration(), now: TimeInterval) {
        precondition(configuration.isValid)
        self.configuration = configuration
        workDeadline = now + TimeInterval(configuration.workSeconds)
        reminderDeadlines = Dictionary(uniqueKeysWithValues: configuration.reminders.map {
            ($0.id, now + TimeInterval($0.intervalSeconds))
        })
    }

    /// Core work/break timing changes start a fresh work session. Reminder-only
    /// changes reconcile by ID so unrelated reminder clocks and work time survive.
    mutating func updateConfiguration(_ next: BreakConfiguration, at now: TimeInterval) {
        precondition(next.isValid)
        guard next != configuration else { return }

        let previous = configuration
        let coreTimingChanged = previous.workSeconds != next.workSeconds
            || previous.breakSeconds != next.breakSeconds
        configuration = next

        // A running break owns its original presentation countdown. The new
        // configuration becomes the fresh session when the break finishes.
        guard phase != .onBreak else { return }

        if coreTimingChanged {
            if phase == .paused {
                pausedWork = TimeInterval(next.workSeconds)
                pausedReminderRemaining = Dictionary(uniqueKeysWithValues: next.reminders.map {
                    ($0.id, TimeInterval($0.intervalSeconds))
                })
                skipsUpcomingBreak = false
                hasWarned = false
            } else {
                startWork(at: now)
            }
            return
        }

        reconcileReminders(from: previous.reminders, to: next.reminders, at: now)

        // Disabling warnings rearms future warning behavior if they are enabled later.
        // Changing one nonzero lead after a warning has fired does not duplicate it.
        if next.warningSeconds == 0 {
            hasWarned = false
        }
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
        if configuration.warningSeconds > 0, !hasWarned, !skipsUpcomingBreak,
           workDeadline - now <= TimeInterval(configuration.warningSeconds) {
            hasWarned = true
            events.append(.warning)
        }

        for reminder in configuration.reminders {
            guard let deadline = reminderDeadlines[reminder.id], now >= deadline else { continue }
            // Rearm from now instead of replaying delayed intervals as a backlog.
            reminderDeadlines[reminder.id] = now + TimeInterval(reminder.intervalSeconds)
            events.append(.reminder(reminder.id))
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
        pausedReminderRemaining = Dictionary(uniqueKeysWithValues: configuration.reminders.map { reminder in
            let deadline = reminderDeadlines[reminder.id] ?? now + TimeInterval(reminder.intervalSeconds)
            return (reminder.id, max(0, deadline - now))
        })
        phase = .paused
    }

    mutating func resume(at now: TimeInterval) {
        guard phase == .paused, !isSleeping else { return }
        workDeadline = now + pausedWork
        reminderDeadlines = Dictionary(uniqueKeysWithValues: configuration.reminders.map { reminder in
            let remaining = pausedReminderRemaining[reminder.id] ?? TimeInterval(reminder.intervalSeconds)
            return (reminder.id, now + remaining)
        })
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

    private mutating func reconcileReminders(
        from previous: [ReminderScheduleConfiguration],
        to next: [ReminderScheduleConfiguration],
        at now: TimeInterval
    ) {
        let oldByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0.intervalSeconds) })
        let newIDs = Set(next.map(\.id))

        reminderDeadlines = reminderDeadlines.filter { newIDs.contains($0.key) }
        pausedReminderRemaining = pausedReminderRemaining.filter { newIDs.contains($0.key) }

        for reminder in next {
            let intervalChanged = oldByID[reminder.id] != reminder.intervalSeconds
            switch phase {
            case .working:
                if intervalChanged || reminderDeadlines[reminder.id] == nil {
                    reminderDeadlines[reminder.id] = now + TimeInterval(reminder.intervalSeconds)
                }
            case .paused:
                if intervalChanged || pausedReminderRemaining[reminder.id] == nil {
                    pausedReminderRemaining[reminder.id] = TimeInterval(reminder.intervalSeconds)
                }
            case .onBreak:
                break
            }
        }
    }

    private mutating func startWork(at now: TimeInterval) {
        phase = .working
        workDeadline = now + TimeInterval(configuration.workSeconds)
        reminderDeadlines = Dictionary(uniqueKeysWithValues: configuration.reminders.map {
            ($0.id, now + TimeInterval($0.intervalSeconds))
        })
        pausedReminderRemaining = [:]
        skipsUpcomingBreak = false
        hasWarned = false
    }
}
