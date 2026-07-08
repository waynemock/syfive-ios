import SwiftUI
import Observation

struct PlayerScoreCardView: View {
    @Bindable var model: MatchController
    let playerIndex: Int
    let scoreColumnWidth: CGFloat
    let scoreRowHeight: CGFloat
    let headerRowHeight: CGFloat
    let scoreSectionSpacing: CGFloat
    let scoreRowSpacing: CGFloat
    var horizontalPadding: CGFloat = 16
    var sectionGap: CGFloat = 14

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var isWinnerHighlightExpanded = false

    var body: some View {
        guard model.playerScores.indices.contains(playerIndex) else {
            return AnyView(EmptyView())
        }

        let isCurrentPlayer = playerIndex == model.currentPlayerIndex
        let totalScore = model.totalScore(for: playerIndex)
        let isWinner = model.isWinner(playerIndex)
        let theme = Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme)

        return AnyView(
            VStack(alignment: .leading, spacing: scoreSectionSpacing) {
                header(theme: theme, isCurrentPlayer: isCurrentPlayer, totalScore: totalScore)
                if !model.canEditPlayers {
                    scoreContent(theme: theme)
                } else {
                    statsContent(theme: theme)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
            .tint(theme.primaryAccent)
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(theme.cellBackgroundColor)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .fill(cardHighlightColor(isWinner: isWinner, isCurrentPlayer: isCurrentPlayer, theme: theme))
                )
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 16,
                        style: .continuous
                    )
                    .fill(theme.primaryAccent.opacity(0.18))
                    .frame(height: headerRowHeight + 20)
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle()
                            Spacer(minLength: 0)
                        }
                    )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.primaryAccent, lineWidth: 2)
                )
            )
            .onAppear {
                updateWinnerHighlightAnimation(isWinner: isWinner)
            }
            .onChange(of: isWinner) { _, newValue in
                updateWinnerHighlightAnimation(isWinner: newValue)
            }
        )
    }

    private func header(theme: Theme, isCurrentPlayer: Bool, totalScore: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            initialsCircle(theme: theme)

            HStack(alignment: .center, spacing: 6) {
                Text(model.playerNames[playerIndex])
                    .font(.title3)
                    .lineLimit(1)
                if isCurrentPlayer && model.playerCount > 1 && model.hasStarted && !model.isGameOver {
                    Image(systemName: "dice.fill")
                }
            }

            Spacer(minLength: 8)

            if model.hasStarted {
                HStack(spacing: 6) {
                    Text("Total \(totalScore)")
                    if model.playerCount > 1 && model.leaderIndices.contains(playerIndex) {
                        Image(systemName: "trophy")
                    }
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            }
            
            if model.canEditPlayers {
                Button {
                    model.removePlayer(at: playerIndex)
                } label: {
                    Image(systemName: "x.circle.fill")
                        .font(.title)
                        .foregroundStyle(theme.secondaryAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func initialsCircle(theme: Theme) -> some View {
        ZStack {
            Circle().fill(theme.primaryAccent)
            Text(model.playerInitials(for: playerIndex))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().stroke(colorButtonBorder, lineWidth: 1.5))
        .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private func scoreContent(theme: Theme) -> some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(alignment: .leading, spacing: scoreSectionSpacing) {
                scoreSection(title: "Upper", isUpper: true, categories: upperCategories, theme: theme)
                scoreSection(title: "Lower", isUpper: false, categories: lowerCategories, theme: theme)
            }
        } else {
            HStack(alignment: .top, spacing: sectionGap) {
                scoreSection(title: "Upper", isUpper: true, categories: upperCategories, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
                scoreSection(title: "Lower", isUpper: false, categories: lowerCategories, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func statsContent(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: scoreSectionSpacing) {
            Text("PvP stats will go here")
        }
        
    }
    
    private func scoreSection(
        title: String,
        isUpper: Bool,
        categories: [YatzyCategory],
        theme: Theme
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.localizedUppercase)
                .font(.headline.weight(.semibold))
                .frame(height: headerRowHeight, alignment: .leading)

            VStack(alignment: .leading, spacing: scoreRowSpacing) {
                ForEach(categories) { category in
                    scoreRow(for: category)
                }

                if isUpper {
                    summaryRow(title: "Subtotal", value: upperSectionSubtotal)
                    summaryRow(title: "Bonus", value: model.upperBonus(for: playerIndex))
                    summaryRow(title: "Total", value: upperSectionTotal)
                } else {
                    summaryRow(title: "Subtotal", value: lowerSectionSubtotal)
                    summaryRow(title: "Yatzy Bonus", value: model.yahtzeeBonus(for: playerIndex))
                    summaryRow(title: "Total", value: lowerSectionTotal)
                }
            }
        }
    }

    private var upperCategories: [YatzyCategory] {
        YatzyCategory.allCases.filter(\.isUpperSection)
    }

    private var lowerCategories: [YatzyCategory] {
        YatzyCategory.allCases.filter { !$0.isUpperSection }
    }

    private func scoreRow(for category: YatzyCategory) -> some View {
        HStack(spacing: 2) {
            Text(category.displayName)
                .font(.subheadline)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundStyle(.primary)
            Spacer()
            ScoreRow(
                players: [playerCell(for: category)],
                theme: Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
                columnWidth: scoreColumnWidth,
                rowHeight: scoreRowHeight,
                rowAction: rowAction(for: category)
            )
        }
        .frame(height: scoreRowHeight)
    }

    private func summaryRow(title: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value, format: .number)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: scoreColumnWidth, height: scoreRowHeight)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
        }
        .frame(height: scoreRowHeight)
    }

    private var upperSectionSubtotal: Int {
        model.upperSubtotal(for: playerIndex)
    }

    private var upperSectionTotal: Int {
        upperSectionSubtotal + model.upperBonus(for: playerIndex)
    }

    private var lowerSectionSubtotal: Int {
        model.scores(for: playerIndex)
            .compactMap { entry in
                entry.key.isUpperSection ? nil : entry.value
            }
            .reduce(0, +)
    }

    private var lowerSectionTotal: Int {
        lowerSectionSubtotal + model.yahtzeeBonus(for: playerIndex)
    }

    private func playerCell(for category: YatzyCategory) -> ScoreRow.PlayerCell {
        let assignedScore = model.scores(for: playerIndex)[category]
        let suggested = model.suggestedScores(for: playerIndex)[category] ?? 0
        let isCurrentPlayer = playerIndex == model.currentPlayerIndex
        let canScore = model.canScore(category: category, for: playerIndex)

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

    private func rowAction(for category: YatzyCategory) -> (() -> Void)? {
        let cell = playerCell(for: category)
        return (cell.isAvailable && cell.canScore) ? cell.onSelect : nil
    }

    private func cardHighlightColor(isWinner: Bool, isCurrentPlayer: Bool, theme: Theme) -> Color {
        if isWinner {
            return theme.primaryAccent.opacity(isWinnerHighlightExpanded ? 0.38 : 0.22)
        }
        if isCurrentPlayer {
            return theme.primaryAccent.opacity(0.12)
        }
        return Color.clear
    }

    private func updateWinnerHighlightAnimation(isWinner: Bool) {
        guard isWinner else {
            withAnimation(.none) {
                isWinnerHighlightExpanded = false
            }
            return
        }

        isWinnerHighlightExpanded = false
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            isWinnerHighlightExpanded = true
        }
    }

    private var themeBinding: Binding<Theme.ThemeType> {
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
#Preview("Editable Player Card") {
    PlayerScoreCardPreviewContainer()
        .padding()
        .frame(width: 320)
}

private struct PlayerScoreCardPreviewContainer: View {
    @State private var model = PlayerScoreCardPreviewContainer.makePreviewModel()

    var body: some View {
        ScrollView {
            PlayerScoreCardView(
                model: model,
                playerIndex: 1,
                scoreColumnWidth: 64,
                scoreRowHeight: 32,
                headerRowHeight: 28,
                scoreSectionSpacing: 14,
                scoreRowSpacing: 6,
                horizontalPadding: 14,
                sectionGap: 12
            )
        }
    }

    fileprivate static func makePreviewModel() -> MatchController {
        let model = MatchController()
        model.addPlayer()
        model.setTheme(.forest, for: 1)

        model.beginRoll()
        model.receiveDiceResults([6, 6, 6, 2, 2])
        model.score(category: .fullHouse)

        model.beginRoll()
        model.receiveDiceResults([1, 1, 1, 4, 5])
        model.score(category: .threeOfAKind)

        model.beginRoll()
        model.receiveDiceResults([2, 2, 2, 2, 2])

        return model
    }
}

#Preview("Compact Player Card") {
    PlayerScoreCardCompactPreviewContainer()
        .padding()
        .frame(width: 460)
}

private struct PlayerScoreCardCompactPreviewContainer: View {
    @State private var model = PlayerScoreCardPreviewContainer.makePreviewModel()

    var body: some View {
        ScrollView {
            PlayerScoreCardView(
                model: model,
                playerIndex: 1,
                scoreColumnWidth: 64,
                scoreRowHeight: 32,
                headerRowHeight: 28,
                scoreSectionSpacing: 14,
                scoreRowSpacing: 6,
                horizontalPadding: 10,
                sectionGap: 10
            )
        }
    }
}
