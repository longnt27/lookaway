import Foundation

// Temporary compatibility for existing tests while the scheduler/UI migrate to generic reminders.
extension AppSettings {
    init(workMinutes: Int, blinkMinutes: Int, postureMinutes: Int) {
        self.init()
        self.workMinutes = workMinutes
        self.blinkMinutes = blinkMinutes
        self.postureMinutes = postureMinutes
    }
}
