import Combine
import Foundation

/// A window edits a draft. Cancel/close never changes persisted settings or timers.
@MainActor
final class SettingsEditor: ObservableObject {
    @Published var draft: AppSettings
    @Published private(set) var saved: AppSettings
    @Published private(set) var errorMessage: String?
    private let onApply: (AppSettings) throws -> Void

    init(settings: AppSettings, onApply: @escaping (AppSettings) throws -> Void) {
        let value = settings.normalized
        draft = value
        saved = value
        self.onApply = onApply
    }

    var hasChanges: Bool { draft.normalized != saved }
    var validationMessage: String? { draft.normalized.reminderValidationMessage }
    var canSave: Bool { hasChanges && validationMessage == nil }

    func restoreDefaults() {
        draft = .defaults
        errorMessage = nil
    }

    func addReminder(_ reminder: Reminder) {
        draft.reminders.append(reminder)
        errorMessage = nil
    }

    func removeReminder(id: UUID) {
        draft.reminders.removeAll { $0.id == id }
        errorMessage = nil
    }

    func moveReminder(id: UUID, before targetID: UUID) {
        guard id != targetID,
              let sourceIndex = draft.reminders.firstIndex(where: { $0.id == id }) else { return }
        let reminder = draft.reminders.remove(at: sourceIndex)
        guard let targetIndex = draft.reminders.firstIndex(where: { $0.id == targetID }) else {
            draft.reminders.insert(reminder, at: min(sourceIndex, draft.reminders.count))
            return
        }
        draft.reminders.insert(reminder, at: targetIndex)
        errorMessage = nil
    }

    func moveReminderToEnd(id: UUID) {
        guard let sourceIndex = draft.reminders.firstIndex(where: { $0.id == id }) else { return }
        let reminder = draft.reminders.remove(at: sourceIndex)
        draft.reminders.append(reminder)
        errorMessage = nil
    }

    @discardableResult
    func apply() -> Bool {
        let next = draft.normalized
        if let message = next.reminderValidationMessage {
            errorMessage = message
            return false
        }
        guard next != saved else {
            errorMessage = nil
            return true
        }
        do {
            try onApply(next)
            saved = next
            draft = next
            errorMessage = nil
            return true
        } catch let error as SettingsValidationError {
            if case .invalidReminder(let message) = error {
                errorMessage = message
            }
            return false
        } catch {
            errorMessage = "Settings could not be saved. Please try again."
            return false
        }
    }
}
