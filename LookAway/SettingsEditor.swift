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

    func restoreDefaults() {
        draft = .defaults
        errorMessage = nil
    }

    @discardableResult
    func apply() -> Bool {
        let next = draft.normalized
        guard next != saved else { return true }
        do {
            try onApply(next)
            saved = next
            draft = next
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Settings could not be saved. Please try again."
            return false
        }
    }
}
