import SwiftUI
import SyLibScoring
import SyLibFeel

struct PreGameGridView: View {
    @Bindable var model: MatchController
    let onAddPlayer: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var useSingleColumn: Bool {
        true
//        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    private var gridColumns: [GridItem] {
        useSingleColumn
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 160, maximum: 200))]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Array(model.slotIDs.enumerated()), id: \.element) { index, _ in
                    PlayerScoreCardView(
                        model: model,
                        playerIndex: index,
                        scoreColumnWidth: 64,
                        scoreRowHeight: 32,
                        headerRowHeight: 28,
                        scoreSectionSpacing: 14,
                        scoreRowSpacing: 6,
                        horizontalPadding: 12,
                        sectionGap: 12
                    )
                }
                addPlayerCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var addPlayerCard: some View {
        let theme = Theme(type: model.nextPlayerThemeType, colorScheme: colorScheme)
        return Button(action: onAddPlayer) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                Text("Add Player")
                    .font(.title3)
                Spacer()
            }
            .padding(12)
            .foregroundStyle(theme.primaryAccent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cellBackgroundColor)
        )
    }
}

#Preview("Pre-Game Grid – Portrait") {
    PreGameGridView(model: {
        let m = MatchController()
        m.addPlayer()
        m.addPlayer()
        return m
    }(), onAddPlayer: {})
    .frame(width: 393)
    .environment(FeelDirector(catalog: .syFive))
}

#Preview("Pre-Game Grid – Landscape / iPad") {
    PreGameGridView(model: {
        let m = MatchController()
        m.addPlayer()
        m.addPlayer()
        m.addPlayer()
        return m
    }(), onAddPlayer: {})
    .environment(\.horizontalSizeClass, .regular)
    .environment(FeelDirector(catalog: .syFive))
    .frame(width: 744)
}
