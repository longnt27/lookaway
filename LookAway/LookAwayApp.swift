import SwiftUI

@main
struct LookAwayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView() // Không cần settings view ở đây
        }
    }
}
