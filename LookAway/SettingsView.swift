import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var editor: SettingsEditor
    @ObservedObject var login: LoginItemController
    let soundPlayer: SoundPlayer
    let onPreview: (AppSettings) -> Void
    let onClose: () -> Void
    @State private var soundPreviewFailed = false

    private let labelWidth: CGFloat = 220
    private let sectionWidth: CGFloat = 620

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
        .frame(minWidth: 700, minHeight: 580)
        .preferredColorScheme(colorScheme)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
        }
        .onDisappear { soundPlayer.stop() }
    }

    private var general: some View {
        settingsPage {
            settingsSection("Startup") {
                Toggle("Launch at login", isOn: Binding(get: { login.isOn }, set: { login.setEnabled($0) }))
                    .accessibilityIdentifier("launchAtLogin")
                if login.status == .requiresApproval {
                    warning("Approval is needed in System Settings before LookAway can start at login.")
                }
                if login.status == .unavailable {
                    warning("Login registration is unavailable for this build.")
                }
                if let message = login.errorMessage {
                    errorText(message)
                }
                Button("Open Login Items Settings", action: login.manageInSystemSettings)
                Toggle("Start with the timer paused", isOn: $editor.draft.startPaused)
            }
            sectionDivider
            settingsSection("Menu bar") {
                Toggle("Show countdown", isOn: $editor.draft.showCountdown)
                Toggle("Include seconds", isOn: $editor.draft.showCountdownSeconds)
                    .disabled(!editor.draft.showCountdown)
            }
        }
    }

    private var breaks: some View {
        settingsPage {
            settingsSection("Timing") {
                Menu("Apply a timing preset") {
                    ForEach(TimingPreset.allCases) { preset in
                        Button(preset.title) { editor.draft = editor.draft.applying(preset) }
                    }
                }
                interval("Break every", value: $editor.draft.workMinutes, range: AppSettings.workMinutesRange, unit: "min")
                interval("Break duration", value: $editor.draft.breakSeconds, range: AppSettings.breakSecondsRange, unit: "sec")
            }
            sectionDivider
            settingsSection("Before a break") {
                Toggle("Advance warning", isOn: $editor.draft.warningEnabled)
                if editor.draft.warningEnabled {
                    interval("Warn before break", value: $editor.draft.warningSeconds,
                             range: editor.draft.warningSecondsRange, unit: "sec")
                    interval("Show warning for", value: $editor.draft.warningDuration, range: 3...30, unit: "sec")
                    Toggle("Allow skipping the next break", isOn: $editor.draft.allowSkip)
                    interval("Postpone by", value: $editor.draft.snoozeMinutes, range: 1...60, unit: "min")
                }
            }
            sectionDivider
            settingsSection("During a break") {
                Toggle("Allow finishing early", isOn: $editor.draft.allowEarlyFinish)
                if editor.draft.allowEarlyFinish {
                    interval("Enable finish button after", value: $editor.draft.readyDelay,
                             range: editor.draft.readyDelayRange, unit: "sec")
                }
            }
        }
    }

    private var reminders: some View {
        settingsPage {
            settingsSection("Blink") {
                Toggle("Blink reminders", isOn: $editor.draft.blinkEnabled)
                if editor.draft.blinkEnabled {
                    interval("Remind every", value: $editor.draft.blinkMinutes,
                             range: AppSettings.reminderMinutesRange, unit: "min")
                    message("Blink message", text: $editor.draft.blinkMessage)
                }
            }
            sectionDivider
            settingsSection("Posture") {
                Toggle("Posture reminders", isOn: $editor.draft.postureEnabled)
                if editor.draft.postureEnabled {
                    interval("Remind every", value: $editor.draft.postureMinutes,
                             range: AppSettings.reminderMinutesRange, unit: "min")
                    message("Posture message", text: $editor.draft.postureMessage)
                }
            }
            sectionDivider
            settingsSection("Presentation") {
                Picker("Reminder style", selection: $editor.draft.reminderStyle) {
                    ForEach(ReminderStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Reminder displays", selection: $editor.draft.reminderDisplays) {
                    ForEach(DisplaySelection.allCases) { Text($0.title).tag($0) }
                }
                interval("Show reminders for", value: $editor.draft.reminderSeconds,
                         range: AppSettings.reminderSecondsRange, unit: "sec")
            }
        }
    }

    private var schedule: some View {
        settingsPage {
            settingsSection("Working hours") {
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
                        warning("No days selected: automatic breaks and reminders will stay paused.")
                    }
                }
            }
        }
    }

    private var appearance: some View {
        settingsPage {
            settingsSection("Window and displays") {
                Picker("Settings appearance", selection: $editor.draft.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                Picker("Break and warning displays", selection: $editor.draft.breakDisplays) {
                    ForEach(DisplaySelection.allCases) { Text($0.title).tag($0) }
                }
                Picker("Banner position", selection: $editor.draft.bannerPosition) {
                    ForEach(BannerPosition.allCases) { Text($0.title).tag($0) }
                }
            }
            sectionDivider
            settingsSection("Break screen") {
                Toggle("Use a random break quote", isOn: $editor.draft.randomBreakQuoteEnabled)
                message("Break message", text: $editor.draft.breakMessage)
                    .disabled(editor.draft.randomBreakQuoteEnabled)
                Toggle("Show clock", isOn: $editor.draft.showClock)
                Toggle("Show break countdown", isOn: $editor.draft.showBreakCountdown)
                interval("Background dimming", value: $editor.draft.dimmingPercent, range: 0...90, unit: "%")
                interval("Overlay text size", value: $editor.draft.textSizePercent, range: 80...150, unit: "%")
                Toggle("Animate overlays and warnings", isOn: $editor.draft.animationsEnabled)
            }
            sectionDivider
            settingsSection("Preview") {
                Button("Preview Break Screen") { onPreview(editor.draft) }
                    .accessibilityIdentifier("previewBreakScreen")
            }
        }
    }

    private var sounds: some View {
        settingsPage {
            settingsSection("Play a sound") {
                Toggle("Before a break", isOn: $editor.draft.soundOnWarning)
                Toggle("When a break starts", isOn: $editor.draft.soundOnBreakStart)
                Toggle("When a break ends", isOn: $editor.draft.soundOnBreakEnd)
                Toggle("With blink or posture reminders", isOn: $editor.draft.soundOnReminder)
            }
            sectionDivider
            settingsSection("Sound and volume") {
                Picker("Sound", selection: $editor.draft.sound) {
                    ForEach(ReminderSound.allCases) { Text($0.rawValue).tag($0) }
                }
                interval("Volume", value: $editor.draft.volumePercent, range: 0...100, unit: "%")
                Button("Preview Sound") { soundPreviewFailed = !soundPlayer.preview(settings: editor.draft) }
                if soundPreviewFailed {
                    warning("This sound is unavailable on this Mac.")
                }
            }
        }
        .onDisappear { soundPlayer.stop() }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = editor.errorMessage {
                errorText(error)
                    .accessibilityIdentifier("settingsSaveError")
            }
            HStack {
                Button("Restore Defaults", action: editor.restoreDefaults)
                    .accessibilityIdentifier("restoreSettingsDefaults")
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

    private func settingsPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: sectionWidth, alignment: .leading)
    }

    private var sectionDivider: some View {
        Divider()
            .frame(maxWidth: sectionWidth)
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func interval(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        let bounded = Binding<Int>(get: { min(max(value.wrappedValue, range.lowerBound), range.upperBound) },
                                   set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) })
        return HStack(spacing: 10) {
            Text(title)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            TextField(title, value: bounded, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .accessibilityLabel(title)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            Stepper(value: bounded, in: range) { EmptyView() }
                .labelsHidden()
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func message(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            TextField(title, text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(120)) }))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: 550, alignment: .leading)
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
