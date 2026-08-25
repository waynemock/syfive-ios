import SwiftUI
import SyLibUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(type: .midnight, colorScheme: colorScheme) }

    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/syfive/id6759580429")!

    var body: some View {
        SyLibUI.AboutView(
            appName: "SyFive",
            tagline: "The classic dice game, elevated.",
            description: "SyFive brings Yatzy to life with full 3D physics dice, per-player themes, and a rich stats layer that tracks your game history, head-to-head records, and scoring style over time.",
            appStoreURL: Self.appStoreURL,
            accentColor: theme.primaryAccent,
            backgroundColor: theme.backgroundColor
        )
    }
}

#Preview("Dark") {
    AboutView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    AboutView()
        .preferredColorScheme(.light)
}
