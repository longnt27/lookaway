// OverlayController.swift

import SwiftUI
import AppKit

public final class OverlayViewModel: ObservableObject {
    @Published public var remaining: Int
    @Published public var message: String
    @Published public var shouldDismiss: Bool = false // ADD: Cờ hiệu để ra lệnh cho View tự đóng
    
    public init(_ remaining: Int, message: String = "") {
        self.remaining = remaining
        self.message = message
    }
}

enum OverlayMode {
    case breakSession(seconds: Int)
    case reminder(message: String, duration: Int)
}

final class OverlayController: ObservableObject {
    private struct Entry {
        let window: OverlayWindow
        let hosting: NSHostingController<OverlayView>
    }

    private var entries: [Entry] = []
    private var vm: OverlayViewModel?
    private var timer: DispatchSourceTimer?
    private var onHideCallback: (() -> Void)?
    private var onTickCallback: ((Int) -> Void)?

    func show(mode: OverlayMode,
              onHide: (() -> Void)? = nil,
              onTick: ((Int) -> Void)? = nil) {
        hide(cleanupOnly: true)

        self.onHideCallback = onHide
        self.onTickCallback = onTick

        switch mode {
        case .breakSession(let seconds):
            let viewModel = OverlayViewModel(seconds)
            self.vm = viewModel
            createOverlayWindows(with: viewModel)
            startTimer(countdown: true)

        case .reminder(let message, let duration):
            let viewModel = OverlayViewModel(duration, message: message)
            self.vm = viewModel
            createOverlayWindows(with: viewModel)
            startTimer(countdown: false)
        }
    }

    private func createOverlayWindows(with viewModel: OverlayViewModel) {
            for screen in NSScreen.screens {
                let view = OverlayView(
                    viewModel: viewModel,
                    mode: modeFromVM(viewModel),
                    onDone: { completion in
                        completion() // gọi animation xong
                        // FIX: Logic hide() được chuyển vào đây, sẽ được gọi bởi View
                        // sau khi animation kết thúc.
                        self.hide(cleanupOnly: false)
                    }
                )

                let hosting = NSHostingController(rootView: view)

                let screenFrame = screen.frame
                let window = OverlayWindow(
                    contentRect: screenFrame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )

                window.isOpaque = false
                window.hasShadow = false
                window.backgroundColor = .clear
                window.level = .screenSaver
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

                window.contentViewController = hosting

                if let cv = window.contentView {
                    hosting.view.frame = cv.bounds
                    hosting.view.autoresizingMask = [.width, .height]
                }

                window.setFrame(screenFrame, display: true)
                window.makeKeyAndOrderFront(nil)

                entries.append(Entry(window: window, hosting: hosting))
            }

            NSApp.activate(ignoringOtherApps: true)
        }


    private func modeFromVM(_ vm: OverlayViewModel) -> OverlayMode {
        if vm.message.isEmpty {
            return .breakSession(seconds: vm.remaining)
        } else {
            return .reminder(message: vm.message, duration: vm.remaining)
        }
    }

    private func startTimer(countdown: Bool) {
        if let t = timer {
            t.cancel()
            timer = nil
        }

        guard let vm = vm else { return }

        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)

        if countdown {
            timer?.schedule(deadline: .now() + 1, repeating: 1.0)
            timer?.setEventHandler { [weak self] in
                guard let self = self, let vm = self.vm else { return }
                vm.remaining -= 1
                self.onTickCallback?(vm.remaining)
                if vm.remaining <= 0 {
                    // FIX: Thay vì gọi hide() trực tiếp, chúng ta ra lệnh cho View bắt đầu đóng.
                    // View sẽ gọi lại onDone (chứa hàm hide()) sau khi animation hoàn tất.
                    DispatchQueue.main.async {
                        vm.shouldDismiss = true
                        self.stopTimer() // Dừng timer ngay lập tức
                    }
                }
            }
        } else { // Reminder timer
            timer?.schedule(deadline: .now() + .seconds(vm.remaining))
            timer?.setEventHandler { [weak self] in
                guard let self = self, let vm = self.vm else { return }
                // FIX: Tương tự như trên, ra lệnh cho View đóng.
                DispatchQueue.main.async {
                    vm.shouldDismiss = true
                    self.stopTimer()
                }
            }
        }

        timer?.resume()
    }
    
    // ADD: Hàm helper để dừng timer
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    func hide(cleanupOnly: Bool = false) {
        // FIX: Đổi tên hàm stopTimer() để tránh nhầm lẫn
        stopTimer()

        for e in entries {
            // Đảm bảo rằng window được đóng một cách an toàn trên main thread
            DispatchQueue.main.async {
                e.window.orderOut(nil)
            }
        }
        entries.removeAll()

        if !cleanupOnly {
            onHideCallback?()
        }

        onHideCallback = nil
        onTickCallback = nil
        vm = nil
    }
}
