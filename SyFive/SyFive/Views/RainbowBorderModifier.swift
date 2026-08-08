import SwiftUI

private let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red]

struct RainbowBorderModifier: ViewModifier {
    let cornerRadius: CGFloat

    @State private var rotation: Double = 0
    @State private var lineWidth: CGFloat = 2.5

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: rainbowColors,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: lineWidth
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    lineWidth = 4.0
                }
            }
    }
}

extension View {
    func rainbowBorder(cornerRadius: CGFloat) -> some View {
        modifier(RainbowBorderModifier(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func rainbowBorderIfNeeded(_ apply: Bool, cornerRadius: CGFloat) -> some View {
        if apply {
            self.rainbowBorder(cornerRadius: cornerRadius)
        } else {
            self
        }
    }
}
