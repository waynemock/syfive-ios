import SwiftUI
import Observation

struct ScorecardView: View {
    @Bindable var model: MatchController
    let availableWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var addPlayerMinY: CGFloat = 0

    private let scoreColumnWidth: CGFloat = 64
    private let scoreRowHeight: CGFloat = 32
    private let headerRowHeight: CGFloat = 28
    private let scoreSectionSpacing: CGFloat = 14
    private let scoreRowSpacing: CGFloat = 6
    private let cardEdgeInset: CGFloat = 24
    private let logger = AppLogger(category: "ScorecardView")

    var body: some View {
        let cardWidth = singleCardWidth(for: availableWidth)
        ScrollViewReader { verticalProxy in
            ScrollView(.vertical, showsIndicators: false) {
                Color.clear
                    .frame(height: 0)
                    .id("scorecard-top")
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(0..<model.playerCount, id: \.self) { index in
                                PlayerScoreCardView(
                                    model: model,
                                    playerIndex: index,
                                    scoreColumnWidth: scoreColumnWidth,
                                    scoreRowHeight: scoreRowHeight,
                                    headerRowHeight: headerRowHeight,
                                    scoreSectionSpacing: scoreSectionSpacing,
                                    scoreRowSpacing: scoreRowSpacing,
                                    layoutMode: playerCardLayoutMode(for: cardWidth)
                                )
                                    .frame(width: cardWidth)
                                    .id(index)
                            }
                            if model.canEditPlayers {
                                addPlayerCard
                                    .offset(y: max(0, -addPlayerMinY))
                                    .background(
                                        GeometryReader { proxy in
                                            Color.clear
                                                .preference(
                                                    key: AddPlayerMinYKey.self,
                                                    value: proxy.frame(in: .named("scorecardVertical")).minY
                                                )
                                        }
                                    )
                                    .id("add-player")
                            }
                        }
                        .padding(.horizontal, cardEdgeInset)
                    }
                    .onAppear {
                        scrollToCurrentPlayer(using: scrollProxy)
                    }
                    .onChange(of: model.currentPlayerIndex) {
                        scrollToCurrentPlayer(using: scrollProxy)
                    }
                    .onChange(of: model.isGameOver) { _, isGameOver in
                        guard isGameOver else { return }
                        celebrateWinningPlayer(using: scrollProxy, verticalProxy: verticalProxy)
                    }
                }
            }
            .onChange(of: model.currentPlayerIndex) {
                let delay = 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        verticalProxy.scrollTo("scorecard-top", anchor: .top)
                    }
                }
            }
        }
        .coordinateSpace(name: "scorecardVertical")
        .onChange(of: availableWidth) { _, width in
            let computed = singleCardWidth(for: width)
            logger.debug(
                self,
                "width update: available=\(width), computed=\(computed), players=\(model.playerCount), canEdit=\(model.canEditPlayers), sizeCategory=\(sizeCategory)"
            )
        }
        .onPreferenceChange(AddPlayerMinYKey.self) { minY in
            addPlayerMinY = minY
        }
    }

    private var addPlayerCard: some View {
        let theme = Theme(type: model.nextPlayerThemeType, colorScheme: colorScheme)
        return Button {
            model.addPlayer()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add Player")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.primaryAccent)
        .contentShape(Rectangle())
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cellBackgroundColor)
        )
    }

    private func scrollToCurrentPlayer(using proxy: ScrollViewProxy) {
        guard model.playerCount > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(model.currentPlayerIndex, anchor: .center)
        }
    }

    private func celebrateWinningPlayer(using horizontalProxy: ScrollViewProxy, verticalProxy: ScrollViewProxy) {
        guard let winningPlayerIndex = model.winnerIndices.first else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            verticalProxy.scrollTo("scorecard-top", anchor: .top)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                horizontalProxy.scrollTo(winningPlayerIndex, anchor: .center)
            }
        }
    }

    private func singleCardWidth(for availableWidth: CGFloat) -> CGFloat {
        let resolvedWidth = availableWidth == 0 ? 320 : availableWidth
        let usableWidth = max(0, resolvedWidth - (cardEdgeInset * 2))
        let isLargeType = sizeCategory.isAccessibilityCategory
        let computed: CGFloat
        let reason: String

        if model.canEditPlayers {
            computed = max(220, (usableWidth - 16) / 2)
            reason = "canEditPlayers"
        } else if isLargeType || model.playerCount == 1 {
            computed = max(220, usableWidth)
            reason = "largeTypeOrSinglePlayer"
        } else {
            computed = max(220, ((usableWidth - 16) / 2) * 1.5)
            reason = "default"
        }

        logger.debug(
            self,
            "singleCardWidth: available=\(availableWidth), resolved=\(resolvedWidth), usable=\(usableWidth), isLargeType=\(isLargeType), players=\(model.playerCount), canEdit=\(model.canEditPlayers), reason=\(reason), result=\(computed)"
        )

        return computed
    }

    private func playerCardLayoutMode(for cardWidth: CGFloat) -> PlayerScoreCardView.LayoutMode {
        guard !sizeCategory.isAccessibilityCategory else { return .stacked }
        return cardWidth >= 320 ? .sideBySide : .stacked
    }

}

private struct AddPlayerMinYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


#Preview {
    ScorecardView(model: MatchController(), availableWidth: 360)
}
