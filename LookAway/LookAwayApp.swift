import SwiftUI

@main
struct LookAwayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // AppDelegate owns the menu bar and the single AppKit-hosted settings window.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { appDelegate.showSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
