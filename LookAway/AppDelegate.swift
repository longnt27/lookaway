import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var pauseItem: NSMenuItem?
    private var breakItem: NSMenuItem?
    private var settingsItem: NSMenuItem?
    private let overlayController = OverlayController()
    private let popupBanner = PopupBannerController()
    private let settingsStore = SettingsStore()
    private let soundPlayer = SoundPlayer()
    private var settingsWindowController: SettingsWindowController?
    private var heartbeat: DispatchSourceTimer?
    private var schedule = BreakSchedule(now: ProcessInfo.processInfo.systemUptime)
    private var activeHours = ActiveHoursGate()

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var allowedNow: Bool { settingsStore.value.isActive(at: Date()) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillSleep(_:)),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake(_:)),
                              name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged(_:)),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        schedule = BreakSchedule(configuration: settingsStore.value.breakConfiguration, now: now)
        if settingsStore.value.startPaused { schedule.pause(at: now) }
        startHeartbeat()
    }

    func applicationWillTerminate(_ notification: Notification) { tearDown() }

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.imagePosition = .imageLeading
        statusItem = item
        let menu = NSMenu()
        menu.autoenablesItems = false
        let start = NSMenuItem(title: "Start Break Now", action: #selector(forceShowBreak), keyEquivalent: "s")
        start.target = self
        menu.addItem(start)
        breakItem = start
        let pause = NSMenuItem(title: "Pause Timer", action: #selector(toggleMainTimer), keyEquivalent: "p")
        pause.target = self
        menu.addItem(pause)
        pauseItem = pause
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        settingsItem = settings
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit LookAway", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
    }

    @objc func showSettings() {
        guard schedule.phase != .onBreak, !schedule.isSleeping else { return }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settings: { [weak self] in self?.settingsStore.value ?? .defaults },
                onApply: { [weak self] value in try self?.applySettings(value) })
        }
        settingsWindowController?.showSettings()
    }

    private func applySettings(_ value: AppSettings) throws {
        guard try settingsStore.save(value) else { return }
        let configuration = settingsStore.value.breakConfiguration
        if configuration != schedule.configuration { schedule.updateConfiguration(configuration, at: now) }
        // A visible banner must not retain obsolete skip/snooze actions after saving.
        popupBanner.hide()
        if schedule.phase != .onBreak { overlayController.hide(cleanupOnly: true) }
        // Active breaks retain a presentation snapshot. Non-timing changes preserve the schedule.
        startHeartbeat()
    }

    private func startHeartbeat() {
        stopHeartbeat()
        tick()
        guard !schedule.isSleeping, schedule.phase != .onBreak,
              schedule.phase == .working || settingsStore.value.activeHoursEnabled else { return }
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(50))
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.tick() }
        }
        heartbeat = source
        source.resume()
    }

    private func stopHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
    }

    private func tick() {
        let wasWorking = schedule.phase == .working
        activeHours.reconcile(allowed: allowedNow, schedule: &schedule, at: now)
        guard schedule.phase == .working, !schedule.isSleeping else {
            if wasWorking {
                popupBanner.hide()
                overlayController.hide(cleanupOnly: true)
            }
            updateStatusBar()
            return
        }
        let events = schedule.advance(at: now)
        if events.contains(.startBreak) {
            presentBreak()
            return
        }
        if events.contains(.skippedBreak) { popupBanner.hide() }
        if events.contains(.warning) { showWarningPopup() }
        let settings = settingsStore.value
        var reminders: [String] = []
        if events.contains(.blinkReminder) { reminders.append(settings.blinkMessage) }
        if events.contains(.postureReminder) { reminders.append(settings.postureMessage) }
        if !reminders.isEmpty {
            overlayController.show(mode: .reminder(message: reminders.joined(separator: "\n"),
                                                   duration: schedule.configuration.reminderSeconds), settings: settings)
        }
        if let event = SoundEvent.selected(for: events, settings: settings) {
            soundPlayer.play(event: event, settings: settings)
        }
        updateStatusBar()
    }

    private func showWarningPopup() {
        let settings = settingsStore.value
        popupBanner.show(
            message: "Break starts in \(schedule.remainingSeconds(at: now)) seconds.",
            onKnow: {},
            onSkipBreak: { [weak self] in
                guard let self = self, self.settingsStore.value.allowSkip else { return }
                self.schedule.skipUpcomingBreak()
                self.tick()
            },
            onAddFiveMinutes: { [weak self] in
                guard let self = self else { return }
                self.schedule.postponeBreak(by: self.settingsStore.value.snoozeMinutes * 60, at: self.now)
                self.tick()
            }, settings: settings
        )
    }

    private func presentBreak() {
        stopHeartbeat()
        popupBanner.hide()
        let settings = settingsStore.value
        overlayController.show(
            mode: .breakSession(seconds: schedule.configuration.breakSeconds), settings: settings,
            onHide: { [weak self] in
                guard let self = self, self.schedule.phase == .onBreak else { return }
                self.schedule.finishBreak(at: self.now)
                self.soundPlayer.play(event: .breakEnd, settings: self.settingsStore.value)
                self.startHeartbeat()
            }, onTick: { [weak self] _ in self?.updateStatusBar() }
        )
        soundPlayer.play(event: .breakStart, settings: settings)
        updateStatusBar()
    }

    @objc private func forceShowBreak() {
        guard schedule.startBreakNow() else { return }
        activeHours.cancelAutomaticResume()
        presentBreak()
    }

    @objc private func toggleMainTimer() {
        guard !schedule.isSleeping else { return }
        switch schedule.phase {
        case .onBreak: return
        case .working:
            schedule.pause(at: now)
            activeHours.cancelAutomaticResume()
            popupBanner.hide()
            overlayController.hide(cleanupOnly: true)
        case .paused:
            if activeHours.ownsPause {
                // "Keep Paused" turns an automatic pause into a manual pause.
                activeHours.cancelAutomaticResume()
            } else if allowedNow {
                schedule.resume(at: now)
            }
        }
        startHeartbeat()
    }

    private func updateStatusBar() {
        let settings = settingsStore.value
        let text: String
        let icon: String
        let time = CountdownText.format(schedule.remainingSeconds(at: now), showsSeconds: settings.showCountdownSeconds)
        switch schedule.phase {
        case .working:
            text = time
            icon = schedule.skipsUpcomingBreak ? "forward.end" : "timer"
        case .paused:
            text = activeHours.ownsPause ? "Outside hours" : "Paused " + time
            icon = activeHours.ownsPause ? "calendar" : "pause.circle.fill"
        case .onBreak:
            text = "Break " + CountdownText.format(overlayController.remainingSeconds, showsSeconds: settings.showCountdownSeconds)
            icon = "cup.and.saucer.fill"
        }
        if let button = statusItem?.button {
            button.title = settings.showCountdown ? " " + text : ""
            button.imagePosition = settings.showCountdown ? .imageLeading : .imageOnly
            button.setAccessibilityLabel("LookAway: " + text)
            let image = NSImage(systemSymbolName: icon, accessibilityDescription: text)
            image?.isTemplate = true
            button.image = image
            button.toolTip = schedule.skipsUpcomingBreak
                ? "LookAway: " + text + ". The next scheduled break will be skipped."
                : "LookAway: " + text
        }
        pauseItem?.title = activeHours.ownsPause ? "Keep Paused" : (schedule.phase == .paused ? "Resume Timer" : "Pause Timer")
        pauseItem?.isEnabled = schedule.phase != .onBreak && !schedule.isSleeping
            && (schedule.phase == .working || activeHours.ownsPause || allowedNow)
        breakItem?.isEnabled = schedule.phase != .onBreak && !schedule.isSleeping
        settingsItem?.isEnabled = schedule.phase != .onBreak && !schedule.isSleeping
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        schedule.prepareForSleep(at: now)
        stopHeartbeat()
        popupBanner.hide()
        overlayController.hide(cleanupOnly: true)
        soundPlayer.stop()
        updateStatusBar()
    }

    @objc private func systemDidWake(_ notification: Notification) {
        schedule.wake(at: now)
        startHeartbeat()
    }

    @objc private func screensChanged(_ notification: Notification) {
        overlayController.refreshScreens()
        popupBanner.hide()
    }

    @objc private func quitApp() {
        tearDown()
        NSApplication.shared.terminate(nil)
    }

    private func tearDown() {
        stopHeartbeat()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        popupBanner.hide()
        overlayController.hide(cleanupOnly: true)
        soundPlayer.stop()
        settingsWindowController?.close()
    }
}
