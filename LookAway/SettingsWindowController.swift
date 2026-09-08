import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let currentSettings: () -> AppSettings
    private let onApply: (AppSettings) throws -> Void
    private let login: LoginItemController
    private let soundPlayer = SoundPlayer()
    private(set) var editor: SettingsEditor?

    init(settings: @escaping () -> AppSettings,
         onApply: @escaping (AppSettings) throws -> Void,
         login: LoginItemController? = nil) {
        currentSettings = settings
        self.onApply = onApply
        self.login = login ?? LoginItemController()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "LookAway Settings"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 620, height: 620)
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(settings:onApply:)") }

    func showSettings() {
        if editor == nil {
            let model = SettingsEditor(settings: currentSettings(), onApply: onApply)
            editor = model
            window?.contentViewController = NSHostingController(rootView:
                SettingsView(editor: model, login: login, soundPlayer: soundPlayer,
                             onClose: { [weak self] in self?.close() }))
        }
        login.refresh()
        NSApplication.shared.activate(ignoringOtherApps: true)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        soundPlayer.stop()
        window?.contentViewController = nil
        editor = nil
    }
}
