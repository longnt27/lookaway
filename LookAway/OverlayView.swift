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

struct OverlayBackground: View {
    let settings: AppSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency { Color.black } else { VisualEffectBlur() }
            Color.black.opacity(Double(settings.dimmingPercent) / 100)
        }
        .preferredColorScheme(.dark)
    }
}

/// Shared by the real overlay and the settings preview. This view owns no timers or windows.
struct BreakContent: View {
    let settings: AppSettings
    let remaining: Int
    let readyDelay: Int
    let canFinish: Bool
    let onDone: () -> Void
    var preview = false

    private var scale: CGFloat { CGFloat(settings.textSizePercent) / 100 }

    var body: some View {
        VStack(spacing: preview ? 12 : 24) {
            if settings.showClock {
                Text(Date(), style: .time)
                    .font(.system(size: (preview ? 16 : 28) * scale, weight: .medium))
            }
            Text(settings.breakMessage)
                .font(.system(size: (preview ? 18 : 24) * scale, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            if settings.showBreakCountdown {
                Text(CountdownText.format(remaining, showsSeconds: true))
                    .font(.system(size: (preview ? 42 : 96) * scale, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Break time remaining")
                    .accessibilityValue("\(remaining) seconds")
            }
            if settings.allowEarlyFinish {
                Button(action: onDone) {
                    Text(readyDelay > 0 ? "I'm ready (\(readyDelay))" : "I'm ready")
                        .padding(.horizontal, 24)
                        .padding(.vertical, preview ? 8 : 14)
                }
                .buttonStyle(ReadyButtonStyle(disabled: !canFinish, compact: preview))
                .disabled(!canFinish || preview)
                .accessibilityIdentifier("finishBreak")
            }
        }
        .padding(preview ? 16 : 32)
        .frame(maxWidth: preview ? 420 : 760)
        .foregroundStyle(.white)
    }
}

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    let mode: OverlayMode
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    private var isCompact: Bool {
        if case .reminder = mode { return viewModel.settings.reminderStyle == .banner }
        return false
    }

    private var animate: Bool { viewModel.settings.animationsEnabled && !reduceMotion }

    var body: some View {
        ZStack {
            OverlayBackground(settings: viewModel.settings).ignoresSafeArea()
            if case .breakSession = mode {
                BreakContent(settings: viewModel.settings, remaining: viewModel.remaining,
                             readyDelay: viewModel.readyDelayRemaining,
                             canFinish: viewModel.canFinishEarly, onDone: onDone)
            } else {
                Text(viewModel.message)
                    .font(.system(size: (isCompact ? 20 : 48) * CGFloat(viewModel.settings.textSizePercent) / 100,
                                  weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(isCompact ? 4 : 6)
                    .minimumScaleFactor(0.6)
                    .padding(isCompact ? 20 : 40)
            }
        }
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 16 : 0))
        .opacity(isPresented ? 1 : 0)
        .onAppear {
            withAnimation(animate ? .easeOut(duration: 0.3) : nil) { isPresented = true }
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            withAnimation(animate ? .easeOut(duration: 0.5) : nil) { isPresented = false }
        }
    }
}

struct ReadyButtonStyle: ButtonStyle {
    let disabled: Bool
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 14 : 20, weight: .semibold))
            .background(disabled ? Color.white.opacity(0.15) : Color.white)
            .foregroundStyle(disabled ? Color.white.opacity(0.5) : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
