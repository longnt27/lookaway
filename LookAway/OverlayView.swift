// OverlayView.swift

import SwiftUI

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    let mode: OverlayMode
    let onDone: ((() -> Void) -> Void)

    @State private var buttonDisabled = true
    @State private var skipCountdown = 3
    @State private var opacity = 0.0
    @State private var showContent = false
    @State private var scaleEffectValue: CGFloat = 0.8
    @State private var isDismissing = false

    let skipTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VisualEffectBlur()
                .edgesIgnoringSafeArea(.all)
                .opacity(opacity)
                .animation(.easeInOut(duration: 0.5), value: opacity)

            VStack(spacing: 20) {
                if case .breakSession = mode {
                    Text("Current time is: " + currentTime())
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                        .animation(.easeOut.delay(0.1), value: showContent)

                    Spacer()

                    Text("Look away from your screen 👀")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                        .animation(.easeOut.delay(0.15), value: showContent)

                    Text(timeString(from: viewModel.remaining))
                        .font(.system(size: 96, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 8, x: 0, y: 4)
                        .scaleEffect(scaleEffectValue)
                        .opacity(showContent ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2), value: showContent)

                    Spacer()

                    Button(action: {
                        if isDismissing { return }
                        isDismissing = true
                        startDismissAnimation {
                            onDone {
                                // Callback khi animation đóng xong
                            }
                        }
                    }) {
                        Text(buttonDisabled ? "I'm ready (\(skipCountdown))" : "I'm ready")
                            .frame(width: 200, height: 52)
                    }
                    .buttonStyle(ReadyButtonStyle(disabled: buttonDisabled))
                    .disabled(buttonDisabled)
                    .opacity(buttonDisabled ? 0.7 : 1)
                    .scaleEffect(buttonDisabled ? 0.95 : 1)
                    .animation(.easeInOut(duration: 0.3), value: buttonDisabled)
                    .onReceive(skipTimer) { _ in
                        guard buttonDisabled else { return }
                        if skipCountdown > 1 {
                            skipCountdown -= 1
                        } else {
                            buttonDisabled = false
                        }
                    }

                    Spacer()
                } else if case .reminder = mode {
                    Text(viewModel.message)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 3)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                        .animation(.easeOut, value: showContent)
                }
            }
            .padding(.top, 50)
        }
        .onAppear {
            opacity = 1.0
            showContent = true
            scaleEffectValue = 1.0
        }
        .onDisappear {
            opacity = 0.0
            showContent = false
            scaleEffectValue = 0.8
        }
        // ADD: Lắng nghe tín hiệu `shouldDismiss` từ ViewModel
        .onChange(of: viewModel.shouldDismiss) { newValue in
            // Khi controller ra lệnh đóng, chúng ta bắt đầu animation
            if newValue && !isDismissing {
                isDismissing = true
                startDismissAnimation {
                    // Gọi onDone để controller thực hiện việc dọn dẹp
                    onDone { }
                }
            }
        }
    }

    func startDismissAnimation(completion: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.5)) {
            opacity = 0.0
            showContent = false
            scaleEffectValue = 0.8
        }
        // Delay xíu để animation chạy xong rồi gọi completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion()
        }
    }

    private func currentTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private func timeString(from seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

struct ReadyButtonStyle: ButtonStyle {
    let disabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .background(disabled ? Color.white.opacity(0.15) : Color.white)
            .foregroundColor(disabled ? Color.white.opacity(0.5) : .black)
            .cornerRadius(12)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.2 : 0.4), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(disabled ? 0.7 : 1.0)
            .animation(.easeInOut, value: disabled)
    }
}
