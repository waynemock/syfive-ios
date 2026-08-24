import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(type: .midnight, colorScheme: colorScheme) }
    @State private var isSafariPresented = false

    // TODO: replace with real App Store ID before submission
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id000000000")!

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 36)

                        AppIconView(size: 180)

                        Spacer().frame(height: 24)

                        VStack(spacing: 6) {
                            Text("SyFive")
                                .font(.title.bold())
                                .foregroundStyle(theme.primaryAccent)

                            Text("The classic dice game, elevated.")
                                .font(.subheadline)
                                .foregroundStyle(theme.primaryText)

                            Text("Version \(Bundle.main.appVersion)")
                                .font(.footnote)
                                .foregroundStyle(theme.primaryAccent)
                                .padding(.top, 4)
                        }

                        Spacer().frame(height: 32)

                        Text("SyFive brings Yatzy to life with full 3D physics dice, per-player themes, and a rich stats layer that tracks your game history, head-to-head records, and scoring style over time.")
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)

                        Spacer().frame(height: 32)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SyzygyInfo(theme: theme) {
                    isSafariPresented = true
                }
            }
            .sheet(isPresented: $isSafariPresented) {
                if let url = URL(string: "https://www.syzygysoftwerks.com") {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: Self.appStoreURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Dark") {
    AboutView()
        .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
}

#Preview("Light") {
    AboutView()
        .environment(\.theme, Theme(type: .midnight, colorScheme: .light))
}
