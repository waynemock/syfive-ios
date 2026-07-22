import SwiftUI

struct PlayerInitialsCircle: View {
    let initials: String
    let themeType: Theme.ThemeType
    var opacity: Double = 1.0

    @ScaledMetric private var size: CGFloat = 28
    @ScaledMetric private var fontSize: CGFloat = 10
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = Theme(type: themeType, colorScheme: colorScheme)
        ZStack {
            Circle().fill(theme.primaryAccent.opacity(opacity))
            Text(initials)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
