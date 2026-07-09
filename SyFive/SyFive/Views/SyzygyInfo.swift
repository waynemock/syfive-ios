import SwiftUI

struct SyzygyInfo: View {
    @Environment(\.theme) private var theme
    
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text("Crafted by humans and AI")
                Text("Arvada, Colorado, USA, Earth")
                Button {
                    action?()
                } label: {
                    HStack(spacing: 4) {
                        Text("© 2026 Syzygy Softwerks LLC")
                        if action != nil {
                            Image(systemName: "arrow.up.right")
                                .imageScale(.small)
                        }
                    }
                }
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(theme.primaryAccent)
        .padding(.vertical, 8)
        .background(theme.backgroundColor)
    }
}
