import SwiftUI

// Một enum để định nghĩa vai trò của các nút, giúp style linh hoạt hơn.
enum PopupButtonRole {
    case primary
    case secondary
}

// ButtonStyle mới, linh hoạt hơn, có thể áp dụng cho các vai trò khác nhau.
struct ModernPopupButtonStyle: ButtonStyle {
    var role: PopupButtonRole = .secondary

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundView(for: configuration))
        .foregroundColor(role == .primary ? .white : .primary.opacity(0.9))
        .cornerRadius(10)
        .scaleEffect(configuration.isPressed ? 0.96 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: configuration.isPressed)
    }

    @ViewBuilder
    private func backgroundView(for configuration: Configuration) -> some View {
        switch role {
        case .primary:
            // Nút chính, nổi bật với màu xanh
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        case .secondary:
            // Nút phụ, dùng hiệu ứng trong mờ
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(configuration.isPressed ? 0.3 : 0.2))
        }
    }
}


struct PopupBannerView: View {
    // MARK: - Properties
    let message: String
    let onKnow: () -> Void
    let onSkipBreak: () -> Void
    let onAddFiveMinutes: () -> Void

    // State để điều khiển animation
    @State private var isPresented = false
    @State private var isExiting = false

    private let bannerWidth: CGFloat = 360
    private let bannerHeight: CGFloat = 180

    // MARK: - Body
    var body: some View {
        VStack {
            // Nội dung chính của banner
            mainContentView
        }
        .frame(width: bannerWidth, height: bannerHeight)
        .background(
            // Hiệu ứng nền kính mờ (frosted glass) cao cấp hơn
            VisualEffectBlur()
                .overlay(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 25, y: 10)
        .opacity(isPresented ? 1 : 0)
        .offset(y: isPresented ? 0 : -30) // Trượt từ trên xuống
        .onAppear(perform: show)
    }

    // MARK: - Subviews
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Nút đóng nhanh (X)
            HStack {
                Spacer()
                Button(action: { dismiss(with: onKnow) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
                .padding()
            }
            .frame(height: 40)
            
            // Icon và thông báo
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                Text(message)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
            }

            Spacer()

            // Dãy các nút hành động
            HStack(spacing: 12) {
                Button("I Know") { dismiss(with: onKnow) }
                    .buttonStyle(ModernPopupButtonStyle(role: .secondary))

                Button("Skip Break") { dismiss(with: onSkipBreak) }
                    .buttonStyle(ModernPopupButtonStyle(role: .secondary))
                
                // Nút hành động chính được làm nổi bật
                Button {
                    dismiss(with: onAddFiveMinutes)
                } label: {
                    Image(systemName: "plus.circle.fill")
                    Text("5 Minutes")
                }
                .buttonStyle(ModernPopupButtonStyle(role: .primary))
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Methods
    
    // Hàm kích hoạt animation hiển thị
    private func show() {
        // Tránh chạy lại animation nếu view xuất hiện lại
        guard !isPresented else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
            isPresented = true
        }

        // Tự động đóng sau một khoảng thời gian
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            // Chỉ tự động đóng nếu người dùng chưa tương tác
            if !isExiting {
                dismiss(with: onKnow)
            }
        }
    }

    // Hàm kích hoạt animation đóng và thực thi hành động
    private func dismiss(with action: @escaping () -> Void) {
        guard !isExiting else { return }
        isExiting = true

        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
        
        // Thực thi hành động sau khi animation đóng kết thúc
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            action()
        }
    }
}

