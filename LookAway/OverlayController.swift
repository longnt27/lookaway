import AppKit
import SwiftUI

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var remaining: Int
    @Published var shouldDismiss = false
    let duration: Int
    let message: String
    let settings: AppSettings

    init(duration: Int, message: String = "", settings: AppSettings = .defaults) {
        self.duration = max(0, duration)
        self.remaining = max(0, duration)
        self.message = message
        self.settings = settings.normalized
    }

    var readyDelayRemaining: Int {
        let delay = min(settings.readyDelay, max(0, duration - 1))
        return max(0, delay - (duration - remaining))
    }

    var canFinishEarly: Bool {
        settings.allowEarlyFinish && readyDelayRemaining == 0 && !shouldDismiss
    }
}

enum OverlayMode: Equatable {
    case breakSession(seconds: Int)
    case reminder(message: String, duration: Int)

    var duration: Int {
        switch self {
        case .breakSession(let seconds): return seconds
        case .reminder(_, let duration): return duration
        }
    }
}

/// Owns completion for the whole presentation, not for each display's view.
@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var viewModel: OverlayViewModel?
    private var timer: DispatchSourceTimer?
    private var dismissWorkItem: DispatchWorkItem?
    private var deadline: TimeInterval?
    private var onHideCallback: (() -> Void)?
    private var onTickCallback: ((Int) -> Void)?
    private let clock: () -> TimeInterval
    private let screens: () -> [NSScreen]
    private let pointer: () -> NSPoint
    private let dismissalDuration: TimeInterval
    private var presentationPointer = NSPoint.zero
    private var animated = true

    private(set) var presentationID: UUID?
    private(set) var currentMode: OverlayMode?

    init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         screens: @escaping () -> [NSScreen] = { NSScreen.screens },
         dismissalDuration: TimeInterval = 0.5,
         pointer: @escaping () -> NSPoint = { NSEvent.mouseLocation }) {
        self.clock = clock
        self.screens = screens
        self.pointer = pointer
        self.dismissalDuration = max(0, dismissalDuration)
    }

    var isShowingBreak: Bool {
        if case .breakSession = currentMode { return true }
        return false
    }

    var remainingSeconds: Int { viewModel?.remaining ?? 0 }

    func show(mode: OverlayMode, settings: AppSettings = .defaults,
              onHide: (() -> Void)? = nil,
              onTick: ((Int) -> Void)? = nil) {
        guard !isShowingBreak else { return }
        hide(cleanupOnly: true)
        let id = UUID()
        presentationID = id
        currentMode = mode
        onHideCallback = onHide
        onTickCallback = onTick
        presentationPointer = pointer()
        var snapshot = settings.normalized
        snapshot.animationsEnabled = snapshot.animationsEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        animated = snapshot.animationsEnabled
        let message: String
        if case .reminder(let text, _) = mode { message = text } else { message = "" }
        viewModel = OverlayViewModel(duration: mode.duration, message: message, settings: snapshot)
        deadline = clock() + TimeInterval(max(0, mode.duration))
        if mode.duration > 0 { createWindows() }
        tick()

        guard presentationID == id, viewModel?.shouldDismiss == false else { return }
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(50))
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer = source
        source.resume()
    }

    func tick() {
        guard let model = viewModel, let deadline = deadline,
              let id = presentationID, !model.shouldDismiss else { return }
        model.remaining = Int(ceil(max(0, deadline - clock())))
        onTickCallback?(model.remaining)
        if model.remaining == 0 { dismiss(presentationID: id) }
    }

    /// Enforce the early-finish preference in the controller as well as the visible button.
    func finishEarly(presentationID id: UUID) {
        guard presentationID == id, isShowingBreak, viewModel?.canFinishEarly == true else { return }
        dismiss(presentationID: id)
    }

    func dismiss(presentationID id: UUID) {
        guard presentationID == id, let model = viewModel, !model.shouldDismiss else { return }
        stopTimer()
        model.shouldDismiss = true
        guard !windows.isEmpty, animated, dismissalDuration > 0 else {
            hide()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self, self.presentationID == id else { return }
                self.hide()
            }
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissalDuration, execute: work)
    }

    func refreshScreens() {
        closeWindows()
        guard viewModel?.shouldDismiss == false else { return }
        createWindows()
    }

    func hide(cleanupOnly: Bool = false) {
        stopTimer()
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        let completion = onHideCallback
        presentationID = nil
        currentMode = nil
        deadline = nil
        onHideCallback = nil
        onTickCallback = nil
        viewModel = nil
        closeWindows()
        if !cleanupOnly { completion?() }
    }

    private func createWindows() {
        guard let model = viewModel, let mode = currentMode, let id = presentationID else { return }
        let settings = model.settings
        let selection = isShowingBreak ? settings.breakDisplays : settings.reminderDisplays
        for screen in DisplaySelector.select(selection, from: screens(), pointer: presentationPointer) {
            let compact = !isShowingBreak && settings.reminderStyle == .banner
            let frame = compact
                ? BannerLayout.frame(in: screen.visibleFrame, position: settings.bannerPosition)
                : screen.frame
            let view = OverlayView(viewModel: model, mode: mode, onDone: { [weak self] in
                self?.finishEarly(presentationID: id)
            })
            let window = OverlayWindow(contentRect: frame,
                                       styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
            window.configureForOverlay()
            window.level = compact ? .floating : .screenSaver
            window.hasShadow = compact
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            if case .reminder = mode { window.ignoresMouseEvents = true }
            window.contentViewController = NSHostingController(rootView: view)
            window.setFrame(frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func closeWindows() {
        for window in windows {
            window.orderOut(nil)
            window.contentViewController = nil
        }
        windows.removeAll()
    }
}
