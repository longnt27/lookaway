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
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    private var buttonDisabled: Bool {
        viewModel.readyDelayRemaining > 0 || viewModel.shouldDismiss
    }

    var body: some View {
        ZStack {
            VisualEffectBlur().ignoresSafeArea()
            if case .breakSession = mode {
                VStack(spacing: 20) {
                    Text(Date(), style: .time)
                        .font(.system(size: 28, weight: .medium))
                    Spacer()
                    Text("Look away from your screen")
                        .font(.system(size: 24, weight: .semibold))
                    Text(timeString(viewModel.remaining))
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Break time remaining")
                        .accessibilityValue("\(viewModel.remaining) seconds")
                    Spacer()
                    Button(action: onDone) {
                        Text(viewModel.readyDelayRemaining > 0
                             ? "I'm ready (\(viewModel.readyDelayRemaining))"
                             : "I'm ready")
                            .frame(width: 200, height: 52)
                    }
                    .buttonStyle(ReadyButtonStyle(disabled: buttonDisabled))
                    .disabled(buttonDisabled)
                    .accessibilityIdentifier("finishBreak")
                    Spacer()
                }
                .padding(.top, 50)
            } else {
                Text(viewModel.message)
                    .font(.system(size: 48, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(40)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
        .opacity(isPresented ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                isPresented = true
            }
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
                isPresented = false
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

struct ReadyButtonStyle: ButtonStyle {
    let disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .background(disabled ? Color.white.opacity(0.15) : Color.white)
            .foregroundStyle(disabled ? Color.white.opacity(0.5) : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
