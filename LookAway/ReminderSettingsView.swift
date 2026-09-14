import SwiftUI

struct NewReminderDraft: Equatable {
    var name = ""
    var message = ""
    var intervalMinutes = 5
    var enabled = true

    var canAdd: Bool {
        !cleaned(name).isEmpty && !cleaned(message).isEmpty
    }

    func reminder() -> Reminder {
        Reminder(
            name: cleaned(name),
            message: String(cleaned(message).prefix(120)),
            intervalMinutes: min(max(intervalMinutes, AppSettings.reminderMinutesRange.lowerBound), AppSettings.reminderMinutesRange.upperBound),
            enabled: enabled
        )
    }

    private func cleaned(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }
}

@MainActor
struct ReminderSettingsView: View {
    @ObservedObject var editor: SettingsEditor
    @State private var isAddingReminder = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Reminders")
                        .font(.headline)
                    Spacer()
                    Button("Add Reminder", systemImage: "plus") {
                        isAddingReminder = true
                    }
                    .accessibilityIdentifier("addReminder")
                }
                .frame(maxWidth: SettingsLayout.pageWidth)

                if editor.draft.reminders.isEmpty {
                    Text("No reminders")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: SettingsLayout.pageWidth, minHeight: 80, alignment: .center)
                } else {
                    ForEach($editor.draft.reminders) { $reminder in
                        ReminderCard(
                            reminder: $reminder,
                            onDelete: { editor.removeReminder(id: reminder.id) },
                            onMoveBefore: { draggedID in
                                editor.moveReminder(id: draggedID, before: reminder.id)
                            }
                        )
                    }

                    Color.clear
                        .frame(maxWidth: SettingsLayout.pageWidth, minHeight: 14)
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { items, _ in
                            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                            editor.moveReminderToEnd(id: id)
                            return true
                        }
                }
            }
            .padding(SettingsLayout.pagePadding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(isPresented: $isAddingReminder) {
            AddReminderSheet(
                onCancel: { isAddingReminder = false },
                onAdd: { reminder in
                    editor.addReminder(reminder)
                    isAddingReminder = false
                }
            )
        }
    }
}

private struct ReminderCard: View {
    @Binding var reminder: Reminder
    let onDelete: () -> Void
    let onMoveBefore: (UUID) -> Void

    private var normalizedNameIsEmpty: Bool {
        reminder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var normalizedMessageIsEmpty: Bool {
        reminder.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                    .contentShape(Rectangle())
                    .draggable(reminder.id.uuidString)
                    .accessibilityLabel("Reorder \(reminder.name)")

                Toggle("", isOn: $reminder.enabled)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel("Enable \(reminder.name)")

                TextField("Reminder name", text: $reminder.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .accessibilityLabel("Reminder name")

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete reminder")
                .accessibilityLabel("Delete \(reminder.name)")
            }

            SettingsTextRow(label: "Message", text: $reminder.message)
            SettingsNumericRow(
                "Remind every",
                value: $reminder.intervalMinutes,
                range: AppSettings.reminderMinutesRange,
                unit: "min"
            )

            if normalizedNameIsEmpty {
                Text("Reminder name is required.")
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if normalizedMessageIsEmpty {
                Text("Reminder message is required.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(SettingsLayout.cardPadding)
        .frame(maxWidth: SettingsLayout.pageWidth, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let draggedID = UUID(uuidString: raw) else { return false }
            onMoveBefore(draggedID)
            return true
        }
    }
}

private struct AddReminderSheet: View {
    @State private var draft = NewReminderDraft()
    let onCancel: () -> Void
    let onAdd: (Reminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Reminder")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: SettingsLayout.rowGap) {
                SettingsTextRow(label: "Name", text: $draft.name)
                SettingsTextRow(label: "Message", text: $draft.message)
                SettingsNumericRow(
                    "Remind every",
                    value: $draft.intervalMinutes,
                    range: AppSettings.reminderMinutesRange,
                    unit: "min"
                )
                SettingsToggleRow("Enabled", isOn: $draft.enabled)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Add") { onAdd(draft.reminder()) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.canAdd)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
