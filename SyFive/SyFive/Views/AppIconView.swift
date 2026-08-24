import SwiftUI

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let uiImage = Bundle.main.icon {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.9))
                    Text("SyFive")
                        .font(.system(size: size * 0.22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(radius: 10, y: 6)
        .accessibilityHidden(true)
    }

    private var cornerRadius: CGFloat {
        size * 0.2237  // matches iOS icon corner ratio
    }
}
