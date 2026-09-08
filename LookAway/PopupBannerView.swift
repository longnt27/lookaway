import SwiftUI

struct PopupBannerView: View {
    let message: String
    let onKnow: () -> Void
    let onSkipBreak: () -> Void
    let onAddFiveMinutes: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: onKnow) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss break warning")
            }
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.system(size: 24, weight: .medium))
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
            }
            Spacer(minLength: 4)
            HStack(spacing: 10) {
                Button("I Know", action: onKnow)
                    .buttonStyle(BannerButtonStyle())
                Button("Skip Break", action: onSkipBreak)
                    .buttonStyle(BannerButtonStyle())
                    .accessibilityIdentifier("skipUpcomingBreak")
                Button(action: onAddFiveMinutes) {
                    Label("5 Minutes", systemImage: "plus.circle.fill")
                }
                .buttonStyle(BannerButtonStyle(isPrimary: true))
                .accessibilityLabel("Postpone break by five minutes")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background {
            VisualEffectBlur()
                .overlay(Color.black.opacity(0.25))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isPresented ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                isPresented = true
            }
        }
        // The controller owns the sole timeout. Actions run immediately rather
        // than racing an independent view timer or a delayed exit animation.
    }
}

private struct BannerButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isPrimary ? Color.accentColor : Color.white.opacity(0.2))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
