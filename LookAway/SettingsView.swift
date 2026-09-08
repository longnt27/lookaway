import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var editor: SettingsEditor
    @ObservedObject var login: LoginItemController
    let soundPlayer: SoundPlayer
    let onClose: () -> Void
    @State private var soundPreviewFailed = false

    private var colorScheme: ColorScheme? {
        switch editor.draft.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                general.tabItem { Label("General", systemImage: "gearshape") }
                breaks.tabItem { Label("Breaks", systemImage: "cup.and.saucer") }
                reminders.tabItem { Label("Reminders", systemImage: "bell") }
                schedule.tabItem { Label("Schedule", systemImage: "calendar") }
                appearance.tabItem { Label("Appearance", systemImage: "paintbrush") }
                sounds.tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
            }
            .padding(.top, 12)
            .onChange(of: editor.draft.workMinutes) { _, _ in
                editor.draft.warningSeconds = min(editor.draft.warningSeconds, editor.draft.warningSecondsRange.upperBound)
            }
            .onChange(of: editor.draft.breakSeconds) { _, _ in
                editor.draft.readyDelay = min(editor.draft.readyDelay, editor.draft.readyDelayRange.upperBound)
            }
            Divider()
            footer
        }
        .frame(minWidth: 620, minHeight: 580)
        .preferredColorScheme(colorScheme)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
        }
        .onDisappear { soundPlayer.stop() }
    }

    private var general: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(get: { login.isOn }, set: { login.setEnabled($0) }))
                    .accessibilityIdentifier("launchAtLogin")
                note("Managed by macOS. Changes to launch at login apply immediately, independently of Save or Cancel. Install LookAway in Applications first.")
                if login.status == .requiresApproval {
                    Text("Approval is needed in System Settings before LookAway can start at login.")
                        .foregroundStyle(.orange)
                }
                if login.status == .unavailable {
                    note("Login registration is unavailable for this build. Check that you are running an installed, locally signed app.")
                }
                if let message = login.errorMessage {
                    Text(message).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
                Button("Open Login Items Settings", action: login.manageInSystemSettings)
                Toggle("Start with the timer paused", isOn: $editor.draft.startPaused)
                note("Applies the next time LookAway launches. It does not pause the current session.")
            }
            Section("Menu bar") {
                Toggle("Show countdown", isOn: $editor.draft.showCountdown)
                Toggle("Include seconds", isOn: $editor.draft.showCountdownSeconds)
                    .disabled(!editor.draft.showCountdown)
                note("Without seconds, remaining minutes are rounded up. The icon and tooltip remain available when the countdown is hidden.")
            }
        }
        .formStyle(.grouped)
    }

    private var breaks: some View {
        Form {
            Section("Timing") {
                Menu("Apply a timing preset") {
                    ForEach(TimingPreset.allCases) { preset in
                        Button(preset.title) { editor.draft = editor.draft.applying(preset) }
                    }
                }
                interval("Break every", value: $editor.draft.workMinutes, range: AppSettings.workMinutesRange, unit: "min")
                interval("Break duration", value: $editor.draft.breakSeconds, range: AppSettings.breakSecondsRange, unit: "sec")
            }
            Section("Before a break") {
                Toggle("Advance warning", isOn: $editor.draft.warningEnabled)
                if editor.draft.warningEnabled {
                    interval("Warn before break", value: $editor.draft.warningSeconds,
                             range: editor.draft.warningSecondsRange, unit: "sec")
                    interval("Show warning for", value: $editor.draft.warningDuration, range: 3...30, unit: "sec")
                    Toggle("Allow skipping the next break", isOn: $editor.draft.allowSkip)
                    interval("Postpone by", value: $editor.draft.snoozeMinutes, range: 1...60, unit: "min")
                }
            }
            Section("During a break") {
                Toggle("Allow finishing early", isOn: $editor.draft.allowEarlyFinish)
                if editor.draft.allowEarlyFinish {
                    interval("Enable finish button after", value: $editor.draft.readyDelay,
                             range: editor.draft.readyDelayRange, unit: "sec")
                }
                note("With early finish off, the break ends automatically. LookAway can still be quit; this is not a device lock.")
            }
        }
        .formStyle(.grouped)
    }

    private var reminders: some View {
        Form {
            Section("Blink") {
                Toggle("Blink reminders", isOn: $editor.draft.blinkEnabled)
                if editor.draft.blinkEnabled {
                    interval("Remind every", value: $editor.draft.blinkMinutes,
                             range: AppSettings.reminderMinutesRange, unit: "min")
                    message("Blink message", text: $editor.draft.blinkMessage)
                }
            }
            Section("Posture") {
                Toggle("Posture reminders", isOn: $editor.draft.postureEnabled)
                if editor.draft.postureEnabled {
                    interval("Remind every", value: $editor.draft.postureMinutes,
                             range: AppSettings.reminderMinutesRange, unit: "min")
                    message("Posture message", text: $editor.draft.postureMessage)
                }
            }
            Section("Presentation") {
                Picker("Reminder style", selection: $editor.draft.reminderStyle) {
                    ForEach(ReminderStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Reminder displays", selection: $editor.draft.reminderDisplays) {
                    ForEach(DisplaySelection.allCases) { Text($0.title).tag($0) }
                }
                interval("Show reminders for", value: $editor.draft.reminderSeconds,
                         range: AppSettings.reminderSecondsRange, unit: "sec")
                note("Reminders let clicks pass through. Intervals restart after each break; choose an interval shorter than the work session. Display-under-pointer is selected when the reminder appears.")
            }
        }
        .formStyle(.grouped)
    }

    private var schedule: some View {
        Form {
            Section("Working hours") {
                Toggle("Only run during selected hours", isOn: $editor.draft.activeHoursEnabled)
                if editor.draft.activeHoursEnabled {
                    HStack {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            Toggle(Calendar.current.shortWeekdaySymbols[day - 1], isOn: weekday(day))
                                .toggleStyle(.button)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                        }
                    }
                    .padding(.vertical, 4)
                    DatePicker("From", selection: time($editor.draft.activeStartMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: time($editor.draft.activeEndMinute), displayedComponents: .hourAndMinute)
                    if editor.draft.activeWeekdays.isEmpty {
                        Text("No days selected: automatic breaks and reminders will stay paused.")
                            .foregroundStyle(.orange)
                    }
                    note("Uses your Mac's local time. Overnight hours belong to the starting day. Equal start and end times mean the entire selected day.")
                }
            }
            Section("Outside working hours") {
                note("The work and reminder countdowns pause and resume when working hours begin. A break already in progress finishes normally. Start Break Now is always available outside an active break.")
                note("Manual pauses never resume automatically. Use Keep Paused during a scheduled pause to stay paused when working hours begin, then Resume Timer during working hours.")
            }
        }
        .formStyle(.grouped)
    }

    private var appearance: some View {
        Form {
            Section("Window and displays") {
                Picker("Settings appearance", selection: $editor.draft.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                Picker("Break and warning displays", selection: $editor.draft.breakDisplays) {
                    ForEach(DisplaySelection.allCases) { Text($0.title).tag($0) }
                }
                Picker("Banner position", selection: $editor.draft.bannerPosition) {
                    ForEach(BannerPosition.allCases) { Text($0.title).tag($0) }
                }
                note("Banner position applies to advance warnings and compact reminders. Display-under-pointer is selected when a presentation begins.")
            }
            Section("Break screen") {
                message("Break message", text: $editor.draft.breakMessage)
                Toggle("Show clock", isOn: $editor.draft.showClock)
                Toggle("Show break countdown", isOn: $editor.draft.showBreakCountdown)
                interval("Background dimming", value: $editor.draft.dimmingPercent, range: 0...90, unit: "%")
                interval("Overlay text size", value: $editor.draft.textSizePercent, range: 80...150, unit: "%")
                Toggle("Animate overlays and warnings", isOn: $editor.draft.animationsEnabled)
                note("System Reduce Motion and Reduce Transparency are always respected. Overlay text remains white on a dark background.")
            }
            Section("Preview — does not start a break") {
                ZStack {
                    OverlayBackground(settings: editor.draft.normalized)
                    BreakContent(settings: editor.draft.normalized, remaining: editor.draft.normalized.breakSeconds,
                                 readyDelay: 0, canFinish: true, onDone: {}, preview: true)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Break screen preview")
            }
        }
        .formStyle(.grouped)
    }

    private var sounds: some View {
        Form {
            Section("Play a sound") {
                Toggle("Before a break", isOn: $editor.draft.soundOnWarning)
                Toggle("When a break starts", isOn: $editor.draft.soundOnBreakStart)
                Toggle("When a break ends", isOn: $editor.draft.soundOnBreakEnd)
                Toggle("With blink or posture reminders", isOn: $editor.draft.soundOnReminder)
            }
            Section("Sound and volume") {
                Picker("Sound", selection: $editor.draft.sound) {
                    ForEach(ReminderSound.allCases) { Text($0.rawValue).tag($0) }
                }
                interval("Volume", value: $editor.draft.volumePercent, range: 0...100, unit: "%")
                Button("Preview Sound") { soundPreviewFailed = !soundPlayer.preview(settings: editor.draft) }
                if soundPreviewFailed { Text("This sound is unavailable on this Mac.").foregroundStyle(.orange) }
                note("All sounds are off by default. Preview uses the draft volume; playback also depends on your Mac's output volume. Volume zero is silent.")
            }
        }
        .formStyle(.grouped)
        .onDisappear { soundPlayer.stop() }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            note("Saving timing changes starts a fresh work session. Paused timers stay paused; active breaks finish normally. Other preferences do not reset the timer.")
            if let error = editor.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red).accessibilityIdentifier("settingsSaveError")
            }
            HStack {
                Button("Restore Defaults", action: editor.restoreDefaults)
                    .accessibilityIdentifier("restoreSettingsDefaults")
                    .help("Reset the draft. Launch at login is managed separately by macOS.")
                Spacer()
                Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
                Button("Save") { if editor.apply() { onClose() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!editor.hasChanges)
                    .accessibilityIdentifier("saveSettings")
            }
        }
        .padding(20)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func interval(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        let bounded = Binding<Int>(get: { min(max(value.wrappedValue, range.lowerBound), range.upperBound) },
                                   set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) })
        return LabeledContent(title) {
            HStack(spacing: 8) {
                TextField(title, value: bounded, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .accessibilityLabel(title)
                Text(unit).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
                Stepper(title, value: bounded, in: range).labelsHidden()
            }
        }
    }

    private func message(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(120)) }))
            .textFieldStyle(.roundedBorder)
            .help("Up to 120 characters. An empty message uses the default when saved.")
    }

    private func weekday(_ day: Int) -> Binding<Bool> {
        Binding(get: { editor.draft.activeWeekdays.contains(day) }, set: { enabled in
            editor.draft.activeWeekdays.removeAll { $0 == day }
            if enabled { editor.draft.activeWeekdays.append(day) }
        })
    }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(get: {
            let value = min(max(minutes.wrappedValue, 0), 1439)
            return Calendar.current.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }
}
