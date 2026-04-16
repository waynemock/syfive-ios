import SwiftUI
import Observation

struct ScorecardView: View {
    @Bindable var model: GameModel
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

    private func playerScoreCard(for playerIndex: Int) -> some View {
        let isCurrentPlayer = playerIndex == model.currentPlayerIndex
        let totalScore = model.totalScore(for: playerIndex)
        let isWinner = model.isWinner(playerIndex)
        let theme = Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme)

        return VStack(alignment: .leading, spacing: scoreSectionSpacing) {
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
                playerIndex: playerIndex,
                theme: theme
            )
            .padding(.top, 8)
            scoreSection(
                title: "Lower",
                categories: GameModel.ScoreCategory.allCases.filter { !$0.isUpperSection },
                playerIndex: playerIndex,
                theme: theme
            )
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
        playerIndex: Int,
        theme: Theme
    ) -> some View {
        VStack(alignment: .leading, spacing: scoreRowSpacing) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(height: headerRowHeight, alignment: .leading)

            ForEach(categories) { category in
                scoreRow(for: playerIndex, category: category)
            }

            if title == "Upper" {
                summaryRow(title: "Subtotal", value: model.upperSubtotal(for: playerIndex))
                summaryRow(title: "Bonus", value: model.upperBonus(for: playerIndex))
            } else {
                summaryRow(title: "Subtotal", value: lowerSubtotal(for: playerIndex))
            }
        }
    }

    private func scoreRow(for playerIndex: Int, category: GameModel.ScoreCategory) -> some View {
        HStack(spacing: 2) {
            Text(category.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            ScoreRow(
                players: [playerCell(for: category, playerIndex: playerIndex)],
                columnWidth: scoreColumnWidth,
                rowHeight: scoreRowHeight,
                rowAction: rowAction(for: category, playerIndex: playerIndex)
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

    private func lowerSubtotal(for playerIndex: Int) -> Int {
        model.scores(for: playerIndex)
            .compactMap { entry in
                entry.key.isUpperSection ? nil : entry.value
            }
            .reduce(0, +)
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

    private func rowAction(for category: GameModel.ScoreCategory, playerIndex: Int) -> (() -> Void)? {
        let cell = playerCell(for: category, playerIndex: playerIndex)
        return (cell.isAvailable && cell.canScore) ? cell.onSelect : nil
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

private struct AddPlayerMinYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


#Preview {
    ScorecardView(model: GameModel(), availableWidth: 360)
}
