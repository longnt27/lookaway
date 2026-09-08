import AppKit
import SwiftUI

struct BannerLayout {
    static func frame(in visibleFrame: NSRect, position: BannerPosition = .top) -> NSRect {
        let width = min(380, max(0, visibleFrame.width - 32))
        let height = min(180, max(0, visibleFrame.height - 32))
        let y: CGFloat
        switch position {
        case .top: y = max(visibleFrame.minY, visibleFrame.maxY - height - 20)
        case .center: y = visibleFrame.midY - height / 2
        case .bottom: y = min(visibleFrame.maxY - height, visibleFrame.minY + 20)
        }
        return NSRect(x: visibleFrame.midX - width / 2, y: y, width: width, height: height)
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
              duration: TimeInterval? = nil,
              settings: AppSettings = .defaults) {
        hide()
        let value = settings.normalized
        let delay = duration ?? TimeInterval(value.warningDuration)
        guard delay.isFinite, delay > 0 else { return }
        let id = UUID()
        presentationID = id
        for screen in DisplaySelector.select(value.breakDisplays, from: screens(), pointer: NSEvent.mouseLocation) {
            let view = PopupBannerView(
                message: message,
                onKnow: { [weak self] in self?.performAction(for: id, onKnow) },
                onSkipBreak: { [weak self] in self?.performAction(for: id, onSkipBreak) },
                onAddFiveMinutes: { [weak self] in self?.performAction(for: id, onAddFiveMinutes) },
                settings: value
            )
            let frame = BannerLayout.frame(in: screen.visibleFrame, position: value.bannerPosition)
            let window = OverlayWindow(contentRect: frame,
                                       styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
            window.configureForOverlay()
            window.level = .floating
            window.hasShadow = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            window.contentViewController = NSHostingController(rootView: view)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

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
