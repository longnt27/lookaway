// AppDelegate.swift

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let overlayController = OverlayController()
    let popupBanner = PopupBannerController()

    private var mainTimer: DispatchSourceTimer?
    private var remainingSeconds: Int = 0
    private var isInBreak: Bool = false

    private var blinkTimer: DispatchSourceTimer?
    private var postureTimer: DispatchSourceTimer?

    // Configurable times in minutes/seconds
    let intervalMinutes = 30
    let breakSeconds = 30
    let blinkIntervalMinutes = 5
    let postureIntervalMinutes = 10
    let warningBeforeEndSeconds = 60 // 1 phút trước break

    private var skipNextBreak = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        startMainTimer(reset: true)
        startReminderTimers()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // FIX: Không chỉ set font mà còn set image position
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.imagePosition = .imageLeading // Đảm bảo icon luôn ở bên trái
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start Break Now", action: #selector(forceShowBreak), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Pause/Resume Timer", action: #selector(toggleMainTimer), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    // ADD: Hàm helper để cập nhật cả icon và text trên status bar
    func updateStatusBar(text: String, iconName: String?) {
        guard let button = statusItem.button else { return }
        
        // Luôn cập nhật text
        // Thêm một khoảng trắng nhỏ để text không dính vào icon
        button.title = " " + text
        
        if let iconName = iconName {
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: text)
            // isTemplate rất quan trọng để icon tự động đổi màu theo Light/Dark mode
            image?.isTemplate = true
            button.image = image
        } else {
            // Nếu không có icon name, xoá icon đi
            button.image = nil
        }
    }

    func startMainTimer(reset: Bool = true) {
        stopMainTimer()
        if reset {
            remainingSeconds = intervalMinutes * 60 + 2
        }
        isInBreak = false
        updateMenuTitle()

        mainTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        mainTimer?.schedule(deadline: .now() + 1, repeating: 1)
        mainTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.remainingSeconds -= 1

            if self.remainingSeconds == self.warningBeforeEndSeconds && !self.isInBreak {
                DispatchQueue.main.async {
                    self.showWarningPopup()
                }
            }

            if self.remainingSeconds <= 0 {
                self.triggerBreak()
            }
            self.updateMenuTitle()
        }
        mainTimer?.resume()
    }

    func stopMainTimer() {
        mainTimer?.cancel()
        mainTimer = nil
    }

    func startReminderTimers() {
        // ... (Không có thay đổi trong hàm này)
        stopReminderTimers()

        let blinkIntervalSeconds = blinkIntervalMinutes * 60
        blinkTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        blinkTimer?.schedule(deadline: .now() + .seconds(blinkIntervalSeconds), repeating: .seconds(blinkIntervalSeconds))
        blinkTimer?.setEventHandler { [weak self] in
            self?.showReminderOverlay(message: "Blink your eyes 👀", duration: 2)
        }
        blinkTimer?.resume()

        let postureIntervalSeconds = postureIntervalMinutes * 60
        postureTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        postureTimer?.schedule(deadline: .now() + .seconds(postureIntervalSeconds), repeating: .seconds(postureIntervalSeconds))
        postureTimer?.setEventHandler { [weak self] in
            self?.showReminderOverlay(message: "Adjust your posture 🪑", duration: 2)
        }
        postureTimer?.resume()
    }

    func stopReminderTimers() {
        // ... (Không có thay đổi trong hàm này)
        blinkTimer?.cancel()
        blinkTimer = nil
        postureTimer?.cancel()
        postureTimer = nil
    }

    private func showReminderOverlay(message: String, duration: Int) {
        // ... (Không có thay đổi trong hàm này)
        overlayController.show(
            mode: .reminder(message: message, duration: duration),
            onHide: nil,
            onTick: nil
        )
    }

    func showWarningPopup() {
        // ... (Không có thay đổi trong hàm này)
        popupBanner.show(
            message: "Break is coming in 1 minute.",
            onKnow: {
                // User saw warning, không làm gì thêm
            },
            onSkipBreak: {
                self.skipNextBreak = true
            },
            onAddFiveMinutes: {
                self.remainingSeconds += 5 * 60
                self.updateMenuTitle()
            }
        )
    }

    func triggerBreak() {
        stopMainTimer()
        if skipNextBreak {
            skipNextBreak = false
            startMainTimer(reset: false)
            return
        }
        isInBreak = true

        overlayController.show(
            mode: .breakSession(seconds: breakSeconds),
            onHide: { [weak self] in
                self?.startMainTimer(reset: true)
                self?.isInBreak = false
            },
            onTick: { [weak self] remaining in
                DispatchQueue.main.async {
                    // FIX: Sử dụng hàm helper để cập nhật status bar với icon break
                    let timeString = self?.formatTime(remaining) ?? ""
                    self?.updateStatusBar(text: "Break " + timeString, iconName: "cup.and.saucer.fill")
                }
            }
        )
    }

    @objc func toggleMainTimer() {
        if isInBreak { return }
        if mainTimer == nil {
            startMainTimer(reset: false)
        } else {
            stopMainTimer()
            // FIX: Sử dụng hàm helper để cập nhật status bar với icon pause
            updateStatusBar(text: "Paused " + formatTime(remainingSeconds), iconName: "pause.circle.fill")
        }
    }

    func updateMenuTitle() {
        DispatchQueue.main.async {
            if !self.isInBreak {
                // FIX: Sử dụng hàm helper để cập nhật status bar với icon timer
                self.updateStatusBar(text: self.formatTime(self.remainingSeconds), iconName: "timer")
            }
        }
    }

    func formatTime(_ totalSeconds: Int) -> String {
        // ... (Không có thay đổi trong hàm này)
        let s = max(0, totalSeconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    @objc func forceShowBreak() {
        triggerBreak()
    }

    @objc func quitApp() {
        // ... (Không có thay đổi trong hàm này)
        stopMainTimer()
        stopReminderTimers()
        overlayController.hide(cleanupOnly: true)
        NSApplication.shared.terminate(nil)
    }
}
