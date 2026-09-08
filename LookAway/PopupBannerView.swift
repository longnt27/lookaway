import SwiftUI

struct PopupBannerView: View {
    let message: String
    let onKnow: () -> Void
    let onSkipBreak: () -> Void
    let onAddFiveMinutes: () -> Void
    var settings: AppSettings = .defaults
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: onKnow) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss break warning")
            }
            HStack(spacing: 12) {
                Image(systemName: "timer").font(.system(size: 24, weight: .medium))
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            HStack(spacing: 10) {
                Button("I Know", action: onKnow).buttonStyle(BannerButtonStyle())
                if settings.allowSkip {
                    Button("Skip Break", action: onSkipBreak)
                        .buttonStyle(BannerButtonStyle())
                        .accessibilityIdentifier("skipUpcomingBreak")
                }
                Button(action: onAddFiveMinutes) {
                    Label("\(settings.snoozeMinutes) min", systemImage: "plus.circle.fill")
                }
                .buttonStyle(BannerButtonStyle(isPrimary: true))
                .accessibilityLabel("Postpone break by \(settings.snoozeMinutes) minutes")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background { OverlayBackground(settings: settings) }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isPresented ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion || !settings.animationsEnabled ? nil : .easeOut(duration: 0.2)) {
                isPresented = true
            }
        }
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
