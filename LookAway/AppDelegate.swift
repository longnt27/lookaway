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
    private var settingsWindowController: SettingsWindowController?
    private var heartbeat: DispatchSourceTimer?
    private var schedule = BreakSchedule(now: ProcessInfo.processInfo.systemUptime)

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillSleep(_:)),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake(_:)),
                              name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged(_:)),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        schedule = BreakSchedule(configuration: settingsStore.value.breakConfiguration, now: now)
        startHeartbeat()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tearDown()
    }

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
        // A screen-covering break would obscure the settings window.
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
        if configuration != schedule.configuration {
            schedule.updateConfiguration(configuration, at: now)
            popupBanner.hide()
            // Never dismiss or restart a break already in progress.
            if schedule.phase != .onBreak { overlayController.hide(cleanupOnly: true) }
            startHeartbeat()
        } else {
            // Display-only changes preserve elapsed time and a pending skip/warning.
            updateStatusBar()
        }
    }

    private func startHeartbeat() {
        stopHeartbeat()
        tick()
        guard schedule.phase == .working, !schedule.isSleeping else { return }
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
        let events = schedule.advance(at: now)
        if events.contains(.startBreak) {
            presentBreak()
            return
        }
        if events.contains(.skippedBreak) { popupBanner.hide() }
        if events.contains(.warning) { showWarningPopup() }

        var reminders: [String] = []
        if events.contains(.blinkReminder) { reminders.append("Blink your eyes") }
        if events.contains(.postureReminder) { reminders.append("Adjust your posture") }
        if !reminders.isEmpty {
            // Reminders due together share a presentation instead of replacing one another.
            overlayController.show(mode: .reminder(message: reminders.joined(separator: "\n"),
                                                   duration: schedule.configuration.reminderSeconds))
        }
        updateStatusBar()
    }

    private func showWarningPopup() {
        popupBanner.show(
            message: "Break starts in \(schedule.remainingSeconds(at: now)) seconds.",
            onKnow: {},
            onSkipBreak: { [weak self] in
                guard let self = self else { return }
                self.schedule.skipUpcomingBreak()
                self.tick()
            },
            onAddFiveMinutes: { [weak self] in
                guard let self = self else { return }
                self.schedule.postponeBreak(at: self.now)
                self.tick()
            }
        )
    }

    private func presentBreak() {
        stopHeartbeat()
        popupBanner.hide()
        overlayController.show(
            mode: .breakSession(seconds: schedule.configuration.breakSeconds),
            onHide: { [weak self] in
                guard let self = self, self.schedule.phase == .onBreak else { return }
                self.schedule.finishBreak(at: self.now)
                self.startHeartbeat()
            },
            onTick: { [weak self] _ in self?.updateStatusBar() }
        )
        updateStatusBar()
    }

    @objc private func forceShowBreak() {
        guard schedule.startBreakNow() else { return }
        presentBreak()
    }

    @objc private func toggleMainTimer() {
        switch schedule.phase {
        case .onBreak:
            return
        case .working:
            schedule.pause(at: now)
            stopHeartbeat()
            popupBanner.hide()
            overlayController.hide(cleanupOnly: true)
        case .paused:
            schedule.resume(at: now)
            startHeartbeat()
        }
        updateStatusBar()
    }

    private func updateStatusBar() {
        let text: String
        let icon: String
        switch schedule.phase {
        case .working:
            text = formatTime(schedule.remainingSeconds(at: now))
            icon = schedule.skipsUpcomingBreak ? "forward.end" : "timer"
        case .paused:
            text = "Paused " + formatTime(schedule.remainingSeconds(at: now))
            icon = "pause.circle.fill"
        case .onBreak:
            text = "Break " + formatTime(overlayController.remainingSeconds)
            icon = "cup.and.saucer.fill"
        }
        if let button = statusItem?.button {
            button.title = settingsStore.value.showCountdown ? " " + text : ""
            button.imagePosition = settingsStore.value.showCountdown ? .imageLeading : .imageOnly
            button.setAccessibilityLabel("LookAway: " + text)
            let image = NSImage(systemSymbolName: icon, accessibilityDescription: text)
            image?.isTemplate = true
            button.image = image
            button.toolTip = schedule.skipsUpcomingBreak
                ? "LookAway: " + text + ". The next scheduled break will be skipped."
                : "LookAway: " + text
        }
        pauseItem?.title = schedule.phase == .paused ? "Resume Timer" : "Pause Timer"
        pauseItem?.isEnabled = schedule.phase != .onBreak && !schedule.isSleeping
        breakItem?.isEnabled = schedule.phase != .onBreak && !schedule.isSleeping
        settingsItem?.isEnabled = schedule.phase != .onBreak && !schedule.isSleeping
    }

    private func formatTime(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        schedule.prepareForSleep(at: now)
        stopHeartbeat()
        popupBanner.hide()
        overlayController.hide(cleanupOnly: true)
        updateStatusBar()
    }

    @objc private func systemDidWake(_ notification: Notification) {
        schedule.wake(at: now)
        startHeartbeat()
    }

    @objc private func screensChanged(_ notification: Notification) {
        overlayController.refreshScreens()
        // A warning on a disconnected display must not leave an invisible action alive.
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
        settingsWindowController?.close()
    }
}
