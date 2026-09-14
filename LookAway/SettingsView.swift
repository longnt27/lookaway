import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var editor: SettingsEditor
    @ObservedObject var login: LoginItemController
    let soundPlayer: SoundPlayer
    let onPreview: (AppSettings) -> Void
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
                appearance.tabItem { Label("Appearance", systemImage: "paintbrush") }
                sounds.tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
            }
            .padding(.top, 8)
            .onChange(of: editor.draft.workMinutes) { _, _ in
                editor.draft.warningSeconds = min(editor.draft.warningSeconds, editor.draft.warningSecondsRange.upperBound)
            }
            .onChange(of: editor.draft.breakSeconds) { _, _ in
                editor.draft.readyDelay = min(editor.draft.readyDelay, editor.draft.readyDelayRange.upperBound)
            }

            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 430)
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
                SettingsToggleRow(
                    "Launch at login",
                    isOn: Binding(get: { login.isOn }, set: { login.setEnabled($0) })
                )
                .accessibilityIdentifier("launchAtLogin")

                SettingsToggleRow("Start with timer paused", isOn: $editor.draft.startPaused)

                if login.status == .requiresApproval {
                    warning("Approval is needed in System Settings before LookAway can start at login.")
                    SettingsRow("Login items") {
                        Button("Open System Settings", action: login.manageInSystemSettings)
                    }
                }
                if login.status == .unavailable {
                    warning("Login registration is unavailable for this build.")
                }
                if let message = login.errorMessage {
                    errorText(message)
                }
            }

            sectionDivider

            settingsSection("Menu bar") {
                SettingsToggleRow("Show countdown", isOn: $editor.draft.showCountdown)
                SettingsToggleRow("Include seconds", isOn: $editor.draft.showCountdownSeconds)
                    .disabled(!editor.draft.showCountdown)
            }

            sectionDivider

            settingsSection("Working hours") {
                SettingsToggleRow("Limit to working hours", isOn: $editor.draft.activeHoursEnabled)
                if editor.draft.activeHoursEnabled {
                    SettingsRow("Days") {
                        HStack(spacing: 4) {
                            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                                Toggle(Calendar.current.shortWeekdaySymbols[day - 1], isOn: weekday(day))
                                    .toggleStyle(.button)
                                    .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                            }
                        }
                    }
                    SettingsDateRow(label: "From", date: time($editor.draft.activeStartMinute))
                    SettingsDateRow(label: "Until", date: time($editor.draft.activeEndMinute))
                    if editor.draft.activeWeekdays.isEmpty {
                        warning("Select at least one working day.")
                    }
                }
            }
        }
    }

    private var breaks: some View {
        settingsPage {
            settingsSection("Timing") {
                SettingsRow("Preset") {
                    Menu("Choose Preset") {
                        ForEach(TimingPreset.allCases) { preset in
                            Button(preset.title) { editor.draft = editor.draft.applying(preset) }
                        }
                    }
                    .frame(width: SettingsLayout.pickerWidth, alignment: .leading)
                }
                SettingsNumericRow(
                    "Break every",
                    value: $editor.draft.workMinutes,
                    range: AppSettings.workMinutesRange,
                    unit: "min"
                )
                SettingsNumericRow(
                    "Break duration",
                    value: $editor.draft.breakSeconds,
                    range: AppSettings.breakSecondsRange,
                    unit: "sec"
                )
            }

            sectionDivider

            settingsSection("Before a break") {
                SettingsToggleRow("Advance warning", isOn: $editor.draft.warningEnabled)
                if editor.draft.warningEnabled {
                    SettingsNumericRow(
                        "Warn before break",
                        value: $editor.draft.warningSeconds,
                        range: editor.draft.warningSecondsRange,
                        unit: "sec"
                    )
                    SettingsNumericRow(
                        "Show warning for",
                        value: $editor.draft.warningDuration,
                        range: 3...30,
                        unit: "sec"
                    )
                    SettingsToggleRow("Allow skipping", isOn: $editor.draft.allowSkip)
                    SettingsNumericRow(
                        "Postpone by",
                        value: $editor.draft.snoozeMinutes,
                        range: 1...60,
                        unit: "min"
                    )
                }
            }

            sectionDivider

            settingsSection("During a break") {
                SettingsToggleRow("Allow finishing early", isOn: $editor.draft.allowEarlyFinish)
                if editor.draft.allowEarlyFinish {
                    SettingsNumericRow(
                        "Enable finish after",
                        value: $editor.draft.readyDelay,
                        range: editor.draft.readyDelayRange,
                        unit: "sec"
                    )
                }
            }
        }
    }

    private var reminders: some View {
        ReminderSettingsView(editor: editor)
    }

    private var appearance: some View {
        settingsPage {
            settingsSection("App appearance") {
                SettingsPickerRow("Settings appearance", selection: $editor.draft.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
            }

            sectionDivider

            settingsSection("Reminder presentation") {
                SettingsPickerRow("Style", selection: $editor.draft.reminderStyle) {
                    ForEach(ReminderStyle.allCases) { Text($0.title).tag($0) }
                }
                SettingsPickerRow("Displays", selection: $editor.draft.reminderDisplays) {
                    ForEach(DisplaySelection.allCases) { Text($0.title).tag($0) }
                }
                SettingsNumericRow(
                    "Duration",
                    value: $editor.draft.reminderSeconds,
                    range: AppSettings.reminderSecondsRange,
                    unit: "sec"
                )
                SettingsPickerRow("Banner position", selection: $editor.draft.bannerPosition) {
                    ForEach(BannerPosition.allCases) { Text($0.title).tag($0) }
                }
            }

            sectionDivider

            settingsSection("Break screen") {
                SettingsPickerRow("Displays", selection: $editor.draft.breakDisplays) {
                    ForEach(DisplaySelection.allCases) { Text($0.title).tag($0) }
                }
                SettingsToggleRow("Random break quote", isOn: $editor.draft.randomBreakQuoteEnabled)
                SettingsTextRow(label: "Break message", text: $editor.draft.breakMessage)
                    .disabled(editor.draft.randomBreakQuoteEnabled)
                SettingsToggleRow("Show clock", isOn: $editor.draft.showClock)
                SettingsToggleRow("Show countdown", isOn: $editor.draft.showBreakCountdown)
                SettingsNumericRow(
                    "Background dimming",
                    value: $editor.draft.dimmingPercent,
                    range: 0...90,
                    unit: "%"
                )
                SettingsNumericRow(
                    "Overlay text size",
                    value: $editor.draft.textSizePercent,
                    range: 80...150,
                    unit: "%"
                )
                SettingsToggleRow("Animate overlays", isOn: $editor.draft.animationsEnabled)
            }

            sectionDivider

            settingsSection("Preview") {
                SettingsRow("Break screen") {
                    Button("Preview") { onPreview(editor.draft) }
                        .accessibilityIdentifier("previewBreakScreen")
                }
            }
        }
    }

    private var sounds: some View {
        settingsPage {
            settingsSection("Play a sound") {
                SettingsToggleRow("Before a break", isOn: $editor.draft.soundOnWarning)
                SettingsToggleRow("When break starts", isOn: $editor.draft.soundOnBreakStart)
                SettingsToggleRow("When break ends", isOn: $editor.draft.soundOnBreakEnd)
                SettingsToggleRow("With reminders", isOn: $editor.draft.soundOnReminder)
            }

            sectionDivider

            settingsSection("Sound and volume") {
                SettingsPickerRow("Sound", selection: $editor.draft.sound) {
                    ForEach(ReminderSound.allCases) { Text($0.rawValue).tag($0) }
                }
                SettingsNumericRow(
                    "Volume",
                    value: $editor.draft.volumePercent,
                    range: 0...100,
                    unit: "%"
                )
                SettingsRow("Preview") {
                    Button("Play Sound") {
                        soundPreviewFailed = !soundPlayer.preview(settings: editor.draft)
                    }
                }
                if soundPreviewFailed {
                    warning("This sound is unavailable on this Mac.")
                }
            }
        }
        .onDisappear { soundPlayer.stop() }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = editor.errorMessage {
                errorText(error)
                    .accessibilityIdentifier("settingsSaveError")
            }
            HStack {
                Button("Restore Defaults", action: editor.restoreDefaults)
                    .accessibilityIdentifier("restoreSettingsDefaults")
                Spacer()
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if editor.apply() { onClose() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!editor.canSave)
                .accessibilityIdentifier("saveSettings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsLayout.sectionGap) {
                content()
            }
            .padding(SettingsLayout.pagePadding)
            .frame(width: SettingsLayout.pageWidth + SettingsLayout.pagePadding * 2, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SettingsLayout.rowGap) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: SettingsLayout.rowGap) {
                content()
            }
        }
        .frame(maxWidth: SettingsLayout.pageWidth, alignment: .leading)
    }

    private var sectionDivider: some View {
        Divider()
            .frame(width: SettingsLayout.pageWidth)
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: SettingsLayout.pageWidth, alignment: .leading)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: SettingsLayout.pageWidth, alignment: .leading)
    }

    private func weekday(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { editor.draft.activeWeekdays.contains(day) },
            set: { enabled in
                editor.draft.activeWeekdays.removeAll { $0 == day }
                if enabled { editor.draft.activeWeekdays.append(day) }
            }
        )
    }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                let value = min(max(minutes.wrappedValue, 0), 1439)
                return Calendar.current.date(
                    bySettingHour: value / 60,
                    minute: value % 60,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
