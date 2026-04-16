import SwiftUI

struct SafeAreaDebugView: View {
    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            ZStack(alignment: .topLeading) {
                if insets.top > 0 {
                    Color.orange.opacity(0.25)
                        .frame(height: insets.top)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                if insets.bottom > 0 {
                    Color.orange.opacity(0.25)
                        .frame(height: insets.bottom)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .offset(y: proxy.size.height - insets.bottom)
                }
                if insets.leading > 0 {
                    Color.orange.opacity(0.25)
                        .frame(width: insets.leading)
                        .frame(maxHeight: .infinity, alignment: .leading)
                }
                if insets.trailing > 0 {
                    Color.orange.opacity(0.25)
                        .frame(width: insets.trailing)
                        .frame(maxHeight: .infinity, alignment: .trailing)
                        .offset(x: proxy.size.width - insets.trailing)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    SafeAreaDebugView()
}
