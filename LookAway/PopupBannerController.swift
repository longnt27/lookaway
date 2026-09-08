import AppKit
import SwiftUI

struct BannerLayout {
    static func frame(in visibleFrame: NSRect) -> NSRect {
        let width = min(380, max(0, visibleFrame.width - 32))
        let height = min(180, max(0, visibleFrame.height - 32))
        return NSRect(x: visibleFrame.midX - width / 2,
                      y: max(visibleFrame.minY, visibleFrame.maxY - height - 20),
                      width: width, height: height)
    }
}

@MainActor
final class PopupBannerController {
    private var windows: [OverlayWindow] = []
    private var dismissWorkItem: DispatchWorkItem?
    private let screens: () -> [NSScreen]
    private(set) var presentationID: UUID?

    init(screens: @escaping () -> [NSScreen] = { NSScreen.screens }) {
        self.screens = screens
    }

    func show(message: String,
              onKnow: @escaping () -> Void,
              onSkipBreak: @escaping () -> Void,
              onAddFiveMinutes: @escaping () -> Void,
              duration: TimeInterval = 10) {
        hide()
        guard duration > 0 else { return }
        let id = UUID()
        presentationID = id

        for screen in screens() {
            let view = PopupBannerView(
                message: message,
                onKnow: { [weak self] in self?.performAction(for: id, onKnow) },
                onSkipBreak: { [weak self] in self?.performAction(for: id, onSkipBreak) },
                onAddFiveMinutes: { [weak self] in self?.performAction(for: id, onAddFiveMinutes) }
            )
            let frame = BannerLayout.frame(in: screen.visibleFrame)
            let window = OverlayWindow(contentRect: frame,
                                       styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
            window.configureForOverlay()
            window.level = .floating
            window.hasShadow = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            window.contentViewController = NSHostingController(rootView: view)
            // Set a global frame without a screen-relative initializer offset.
            window.setFrame(frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self, self.presentationID == id else { return }
                self.hide()
            }
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// A click on any display consumes the warning once. Clear the old presentation
    /// first, because the action may synchronously show a new warning or a break.
    func performAction(for id: UUID, _ action: () -> Void) {
        guard presentationID == id else { return }
        hide()
        action()
    }

    func hide() {
        presentationID = nil
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        for window in windows {
            window.orderOut(nil)
            window.contentViewController = nil
        }
        windows.removeAll()
    }
}
