import SwiftUI
import Observation

struct PlayerScoreCardView: View {
    enum LayoutMode {
        case stacked
        case sideBySide
    }

    @Bindable var model: GameModel
    let playerIndex: Int
    let scoreColumnWidth: CGFloat
    let scoreRowHeight: CGFloat
    let headerRowHeight: CGFloat
    let scoreSectionSpacing: CGFloat
    let scoreRowSpacing: CGFloat
    let layoutMode: LayoutMode

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isCurrentPlayer = playerIndex == model.currentPlayerIndex
        let totalScore = model.totalScore(for: playerIndex)
        let isWinner = model.isWinner(playerIndex)
        let theme = Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme)

        VStack(alignment: .leading, spacing: scoreSectionSpacing) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.playerNames[playerIndex])
                        .font(.title3)
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
                                .fill(theme.primaryAccent.opacity(0.2))
                        )
                }
                if model.canEditPlayers {
                    Menu {
                        Picker("Card Color", selection: themeBinding) {
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

            scoreContent(theme: theme)
                .padding(.top, 8)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 12)
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
                .frame(height: headerRowHeight + 32)
                .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                        Spacer(minLength: 0)
                    }
                )
            }
        )
    }

    @ViewBuilder
    private func scoreContent(theme: Theme) -> some View {
        switch layoutMode {
        case .stacked:
            VStack(alignment: .leading, spacing: scoreSectionSpacing) {
                scoreSection(
                    title: "Upper",
                    categories: upperCategories,
                    theme: theme
                )
                scoreSection(
                    title: "Lower",
                    categories: lowerCategories,
                    theme: theme
                )
            }
        case .sideBySide:
            HStack(alignment: .top, spacing: max(12, scoreSectionSpacing)) {
                scoreSection(
                    title: "Upper",
                    categories: upperCategories,
                    theme: theme
                )
                .fixedSize(horizontal: true, vertical: true)

                Spacer(minLength: 0)

                scoreSection(
                    title: "Lower",
                    categories: lowerCategories,
                    theme: theme
                )
                .fixedSize(horizontal: true, vertical: true)

                if model.playerCount == 1 {
                    Spacer(minLength: 0)
                }

            }
        }
    }

    private func scoreSection(
        title: String,
        categories: [GameModel.ScoreCategory],
        theme: Theme
    ) -> some View {
        VStack(alignment: .leading, spacing: scoreRowSpacing) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(height: headerRowHeight, alignment: .leading)

            ForEach(categories) { category in
                scoreRow(for: category)
            }

            if title == "Upper" {
                summaryRow(title: "Subtotal", value: model.upperSubtotal(for: playerIndex))
                summaryRow(title: "Bonus", value: model.upperBonus(for: playerIndex))
            } else {
                summaryRow(title: "Subtotal", value: lowerSubtotal)
                if model.yahtzeeBonus(for: playerIndex) > 0 {
                    summaryRow(title: "Yatzy Bonus", value: model.yahtzeeBonus(for: playerIndex))
                }
            }
        }
    }

    private var upperCategories: [GameModel.ScoreCategory] {
        GameModel.ScoreCategory.allCases.filter(\.isUpperSection)
    }

    private var lowerCategories: [GameModel.ScoreCategory] {
        GameModel.ScoreCategory.allCases.filter { !$0.isUpperSection }
    }

    private func scoreRow(for category: GameModel.ScoreCategory) -> some View {
        HStack(spacing: 2) {
            Text(category.displayName)
                .font(.subheadline)
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

    private var lowerSubtotal: Int {
        model.scores(for: playerIndex)
            .compactMap { entry in
                entry.key.isUpperSection ? nil : entry.value
            }
            .reduce(0, +)
    }

    private func playerCell(for category: GameModel.ScoreCategory) -> ScoreRow.PlayerCell {
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

    private func rowAction(for category: GameModel.ScoreCategory) -> (() -> Void)? {
        let cell = playerCell(for: category)
        return (cell.isAvailable && cell.canScore) ? cell.onSelect : nil
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
            layoutMode: .stacked
        )
    }
    }

    fileprivate static func makePreviewModel() -> GameModel {
        let model = GameModel()
        model.addPlayer()
        model.setTheme(.forest, for: 1)

        model.beginRoll()
        model.receiveDiceResults([6, 6, 6, 2, 2])
        model.score(category: .fullHouse)

        model.beginRoll()
        model.receiveDiceResults([1, 1, 1, 4, 5])
        model.score(category: .threeOfAKind)

        model.beginRoll()
        model.receiveDiceResults([2, 2, 2, 2, 5])

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
                scoreColumnWidth: 58,
                scoreRowHeight: 32,
                headerRowHeight: 28,
                scoreSectionSpacing: 14,
                scoreRowSpacing: 6,
                layoutMode: .sideBySide
            )
        }
    }
}
