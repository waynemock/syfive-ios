import SwiftUI
import Observation

struct ScorecardView: View {
    @Bindable var model: GameModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var availableWidth: CGFloat = 0
    @State private var addPlayerMinY: CGFloat = 0

    private let scoreColumnWidth: CGFloat = 72
    private let scoreRowHeight: CGFloat = 32
    private let headerRowHeight: CGFloat = 28
    private let scoreSectionSpacing: CGFloat = 14
    private let scoreRowSpacing: CGFloat = 6
    private let cardEdgeInset: CGFloat = 24

    var body: some View {
        let cardWidth = singleCardWidth(for: availableWidth)
        ScrollView(.vertical, showsIndicators: false) {
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(0..<model.playerCount, id: \.self) { index in
                            playerScoreCard(for: index)
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
            }
        }
        .coordinateSpace(name: "scorecardVertical")
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ScorecardWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(ScorecardWidthKey.self) { width in
            availableWidth = width
        }
        .onPreferenceChange(AddPlayerMinYKey.self) { minY in
            addPlayerMinY = minY
        }
    }

    private func playerScoreCard(for playerIndex: Int) -> some View {
        let isCurrentPlayer = playerIndex == model.currentPlayerIndex
        let totalScore = model.totalScore(for: playerIndex)
        let isWinner = model.isWinner(playerIndex)
        let theme = Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme)

        return VStack(alignment: .leading, spacing: scoreSectionSpacing) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.playerNames[playerIndex])
                        .font(.headline)
                    Text("Total \(totalScore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCurrentPlayer && model.playerCount > 1 {
                    Text("Current")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.secondary)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.primaryAccent.opacity(0.15))
                        )
                }
                if model.canEditPlayers {
                    Menu {
                        Picker("Card Color", selection: themeBinding(for: playerIndex)) {
                            ForEach(Theme.ThemeType.allCases, id: \.self) { type in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(colorSwatch(for: type))
                                        .frame(width: 12, height: 12)
                                    Text(type.displayName)
                                }
                                .foregroundStyle(colorSwatch(for: type))
                                .tag(type)
                            }
                        }
                    } label: {
                        Circle()
                            .fill(theme.primaryAccent)
                            .overlay(
                                Circle()
                                    .stroke(colorButtonBorder, lineWidth: 1.5)
                            )
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                if model.canEditPlayers && playerIndex > 0 {
                    Button {
                        model.removePlayer(at: playerIndex)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(theme.cellBackgroundColor)
                            )
                            .overlay(
                                Circle()
                                    .stroke(colorButtonBorder, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            scoreSection(
                title: "Upper",
                categories: GameModel.ScoreCategory.allCases.filter { $0.isUpperSection },
                playerIndex: playerIndex
            )
            scoreSection(
                title: "Lower",
                categories: GameModel.ScoreCategory.allCases.filter { !$0.isUpperSection },
                playerIndex: playerIndex
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(16)
        .tint(theme.primaryAccent)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cellBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(cardHighlightColor(isWinner: isWinner, isCurrentPlayer: isCurrentPlayer, theme: theme))
                )
        )
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

    private func scoreSection(
        title: String,
        categories: [GameModel.ScoreCategory],
        playerIndex: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: scoreRowSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(height: headerRowHeight, alignment: .leading)

            ForEach(categories) { category in
                scoreRow(for: playerIndex, category: category)
            }
        }
    }

    private func scoreRow(for playerIndex: Int, category: GameModel.ScoreCategory) -> some View {
        HStack(spacing: 12) {
            Text(category.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            ScoreRow(
                players: [playerCell(for: category, playerIndex: playerIndex)],
                columnWidth: scoreColumnWidth,
                rowHeight: scoreRowHeight
            )
        }
        .frame(height: scoreRowHeight)
    }

    private func playerCell(for category: GameModel.ScoreCategory, playerIndex: Int) -> ScoreRow.PlayerCell {
        let assignedScore = model.scores(for: playerIndex)[category]
        let suggested = model.suggestedScores(for: playerIndex)[category] ?? 0
        let isCurrentPlayer = playerIndex == model.currentPlayerIndex
        let canScore = model.canScore && isCurrentPlayer
        return ScoreRow.PlayerCell(
            id: playerIndex,
            value: assignedScore,
            suggested: suggested,
            isAvailable: assignedScore == nil,
            canScore: canScore,
            isCurrentPlayer: isCurrentPlayer,
            isWinner: model.isWinner(playerIndex)
        ) {
            model.score(category: category)
        }
    }

    private func scrollToCurrentPlayer(using proxy: ScrollViewProxy) {
        guard model.playerCount > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(model.currentPlayerIndex, anchor: .center)
        }
    }

    private func cardHighlightColor(isWinner: Bool, isCurrentPlayer: Bool, theme: Theme) -> Color {
        if isWinner {
            return theme.successColor.opacity(0.18)
        }
        if isCurrentPlayer {
            return theme.primaryAccent.opacity(0.12)
        }
        return Color.clear
    }

    private func singleCardWidth(for availableWidth: CGFloat) -> CGFloat {
        let resolvedWidth = availableWidth == 0 ? 320 : availableWidth
        let usableWidth = max(0, resolvedWidth - (cardEdgeInset * 2))
        let isLargeType = sizeCategory.isAccessibilityCategory
        if model.canEditPlayers {
            return max(220, (usableWidth - 16) / 2)
        }
        if isLargeType || model.playerCount == 1 {
            return max(220, usableWidth)
        }
        return max(220, (usableWidth - 16) / 2)
    }

    private func themeBinding(for playerIndex: Int) -> Binding<Theme.ThemeType> {
        Binding(
            get: { model.themeType(for: playerIndex) },
            set: { model.setTheme($0, for: playerIndex) }
        )
    }

    private func colorSwatch(for type: Theme.ThemeType) -> Color {
        Theme(type: type, colorScheme: colorScheme).primaryAccent
    }

    private var colorButtonBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.18)
    }

}

private struct ScorecardWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AddPlayerMinYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


#Preview {
    ScorecardView(model: GameModel())
}
