import AppKit

/// NSScreen.screens is ordered with the menu-bar/primary display first.
/// A missing pointer display falls back to the primary display, never an invisible overlay.
enum DisplaySelector {
    static func indices(for selection: DisplaySelection, frames: [NSRect], pointer: NSPoint) -> [Int] {
        guard !frames.isEmpty else { return [] }
        switch selection {
        case .all: return Array(frames.indices)
        case .primary: return [0]
        case .pointer: return [frames.firstIndex(where: { $0.contains(pointer) }) ?? 0]
        }
    }

    static func select(_ selection: DisplaySelection, from screens: [NSScreen], pointer: NSPoint) -> [NSScreen] {
        indices(for: selection, frames: screens.map(\.frame), pointer: pointer).map { screens[$0] }
    }
}

enum SoundEvent: CaseIterable {
    case warning, breakStart, breakEnd, reminder

    func isEnabled(in settings: AppSettings) -> Bool {
        switch self {
        case .warning: return settings.soundOnWarning
        case .breakStart: return settings.soundOnBreakStart
        case .breakEnd: return settings.soundOnBreakEnd
        case .reminder: return settings.soundOnReminder
        }
    }

    /// Select at most one enabled sound; a muted warning must not suppress a reminder sound.
    static func selected(for events: [BreakSchedule.Event], settings: AppSettings) -> SoundEvent? {
        if events.contains(.warning), settings.soundOnWarning { return .warning }
        if settings.soundOnReminder,
           events.contains(.blinkReminder) || events.contains(.postureReminder) { return .reminder }
        return nil
    }
}

@MainActor
final class SoundPlayer {
    private var current: NSSound?

    @discardableResult
    func play(event: SoundEvent, settings: AppSettings) -> Bool {
        guard event.isEnabled(in: settings) else { return false }
        return preview(settings: settings)
    }

    @discardableResult
    func preview(settings: AppSettings) -> Bool {
        stop()
        let value = settings.normalized
        guard value.volumePercent > 0 else { return true }
        // Copy the named sound so its volume does not mutate AppKit's shared cached instance.
        guard let sound = NSSound(named: NSSound.Name(value.sound.rawValue))?.copy() as? NSSound else {
            return false
        }
        sound.volume = Float(value.volumePercent) / 100
        current = sound
        return sound.play()
    }

    func stop() {
        current?.stop()
        current = nil
    }
}
