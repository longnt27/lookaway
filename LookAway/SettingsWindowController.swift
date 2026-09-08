import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let currentSettings: () -> AppSettings
    private let onApply: (AppSettings) throws -> Void
    private(set) var editor: SettingsEditor?

    init(settings: @escaping () -> AppSettings,
         onApply: @escaping (AppSettings) throws -> Void) {
        currentSettings = settings
        self.onApply = onApply
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 660),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "LookAway Settings"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 480, height: 520)
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(settings:onApply:)")
    }

    func showSettings() {
        // Repeated commands retain unsaved edits. Closing and reopening reloads saved values.
        if editor == nil {
            let model = SettingsEditor(settings: currentSettings(), onApply: onApply)
            editor = model
            window?.contentViewController = NSHostingController(rootView:
                SettingsView(editor: model, onClose: { [weak self] in self?.close() }))
        }
        // Only an explicit Settings command activates the app, never a reminder.
        NSApplication.shared.activate(ignoringOtherApps: true)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
        editor = nil
    }
}
