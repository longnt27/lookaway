import SwiftUI
import AppKit

final class PopupBannerController {
    private struct Entry {
        let window: OverlayWindow
        let hosting: NSHostingController<PopupBannerView>
    }

    private var entries: [Entry] = []
    private var dismissWorkItem: DispatchWorkItem?

    func show(
        message: String,
        onKnow: @escaping () -> Void,
        onSkipBreak: @escaping () -> Void,
        onAddFiveMinutes: @escaping () -> Void,
        duration: TimeInterval = 10
    ) {
        hide(cleanupOnly: true)

        for screen in NSScreen.screens {
            let view = PopupBannerView(
                message: message,
                onKnow: {
                    onKnow()
                    self.hide()
                },
                onSkipBreak: {
                    onSkipBreak()
                    self.hide()
                },
                onAddFiveMinutes: {
                    onAddFiveMinutes()
                    self.hide()
                }
            )

            let hosting = NSHostingController(rootView: view)
            hosting.view.wantsLayer = true
            hosting.view.layer?.cornerRadius = 12
            hosting.view.layer?.masksToBounds = true

            let screenFrame = screen.frame
            let bannerWidth: CGFloat = 360
            let bannerHeight: CGFloat = 200
            let xPos = (screenFrame.width - bannerWidth) / 2
            let yPos = screenFrame.height - bannerHeight - 50

            let window = OverlayWindow(
                contentRect: NSRect(x: xPos, y: yPos, width: bannerWidth, height: bannerHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.hasShadow = true
            window.collectionBehavior = [.canJoinAllSpaces, .transient]

            window.contentViewController = hosting
            if let cv = window.contentView {
                hosting.view.frame = cv.bounds
                hosting.view.autoresizingMask = [.width, .height]
            }

            window.makeKeyAndOrderFront(nil)

            entries.append(Entry(window: window, hosting: hosting))
        }

        NSApp.activate(ignoringOtherApps: true)

        // Tự ẩn sau duration giây
        dismissWorkItem = DispatchWorkItem {
            self.hide()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismissWorkItem!)
    }

    func hide(cleanupOnly: Bool = false) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        for entry in entries {
            entry.window.orderOut(nil)
        }
        entries.removeAll()
    }
}
