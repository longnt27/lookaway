import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var editor: SettingsEditor
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Screen breaks") {
                    interval("Break every", value: $editor.draft.workMinutes,
                             range: AppSettings.workMinutesRange, unit: "min")
                    interval("Break duration", value: $editor.draft.breakSeconds,
                             range: AppSettings.breakSecondsRange, unit: "sec")
                    Toggle("Advance warning", isOn: $editor.draft.warningEnabled)
                    if editor.draft.warningEnabled {
                        interval("Warn before break", value: $editor.draft.warningSeconds,
                                 range: editor.draft.warningSecondsRange, unit: "sec")
                    }
                }
                Section("Reminders") {
                    Toggle("Blink reminders", isOn: $editor.draft.blinkEnabled)
                    if editor.draft.blinkEnabled {
                        interval("Blink reminder every", value: $editor.draft.blinkMinutes,
                                 range: AppSettings.reminderMinutesRange, unit: "min")
                    }
                    Toggle("Posture reminders", isOn: $editor.draft.postureEnabled)
                    if editor.draft.postureEnabled {
                        interval("Posture reminder every", value: $editor.draft.postureMinutes,
                                 range: AppSettings.reminderMinutesRange, unit: "min")
                    }
                    interval("Show reminders for", value: $editor.draft.reminderSeconds,
                             range: AppSettings.reminderSecondsRange, unit: "sec")
                        .disabled(!editor.draft.blinkEnabled && !editor.draft.postureEnabled)
                    Text("Reminder intervals restart after each break. Choose an interval shorter than your work session to see reminders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Menu bar") {
                    Toggle("Show countdown", isOn: $editor.draft.showCountdown)
                    Text("When hidden, the status icon and its tooltip still show the timer state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .onChange(of: editor.draft.workMinutes) { _, _ in
                // Keep a warning strictly shorter than the selected work interval.
                editor.draft = editor.draft.normalized
            }

            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Saving timing changes starts a fresh work session. Paused timers stay paused; an active break finishes normally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = editor.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
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
                    .disabled(!editor.hasChanges)
                    .accessibilityIdentifier("saveSettings")
                }
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 480)
    }

    private func interval(_ title: String, value: Binding<Int>,
                          range: ClosedRange<Int>, unit: String) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue("\(value.wrappedValue) \(unit)")
    }
}
