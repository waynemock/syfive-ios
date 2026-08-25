import SwiftUI
import Observation
import SwiftData
import SyLibFeel

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

    static func metrics(for cardWidth: CGFloat) -> (horizontalPadding: CGFloat, sectionGap: CGFloat) {
        // Wider cards get slightly more breathing room.
        cardWidth > 340
            ? (horizontalPadding: 14, sectionGap: 12)
            : (horizontalPadding: 10, sectionGap: 10)
    }

    @Environment(FeelDirector.self) private var director
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.modelContext) private var modelContext
    @ScaledMetric private var initialsCircleSize: CGFloat = 28
    @ScaledMetric private var initialsFontSize: CGFloat = 11
    @State private var isWinnerHighlightExpanded = false
    @State private var showsProfile = false
    @State private var showsPlayerEdit: PlayerEditSheet.Mode? = nil
    @State private var displayedTotal: Int = 0

    var body: some View {
        guard model.playerScores.indices.contains(playerIndex) else {
            return AnyView(EmptyView())
        }

        let isCurrentPlayer = playerIndex == model.currentPlayerIndex
        let isWinner = model.isWinner(playerIndex)
        let rawTotal = model.totalScore(for: playerIndex)
        // Use animated count-up total for the winner at game-over; live total otherwise.
        let totalScore = (isWinner && model.isGameOver) ? displayedTotal : rawTotal
        let theme = Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme)
        let gameOverWinner = isWinner && model.isGameOver

        return AnyView(
            VStack(alignment: .leading, spacing: scoreSectionSpacing) {
                header(theme: theme, isCurrentPlayer: isCurrentPlayer, totalScore: totalScore)
                    .padding(.top, 12)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                        .fill(theme.primaryAccent.opacity(0.18))
                    )
                Group {
                    if !model.canEditPlayers {
                        scoreContent(theme: theme)
                    } else {
                        statsContent(theme: theme)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: .infinity, alignment: .top)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.primaryAccent, lineWidth: gameOverWinner ? 0 : 2.0)
                )
            )
            .rainbowBorderIfNeeded(gameOverWinner, cornerRadius: 16)
            .onAppear {
                updateWinnerHighlightAnimation(isWinner: isWinner)
                displayedTotal = rawTotal
            }
            .onChange(of: isWinner) { _, newValue in
                updateWinnerHighlightAnimation(isWinner: newValue)
            }
            .sheet(isPresented: $showsProfile) {
                if let pid = model.playerIDs[playerIndex] {
                    PlayerProfileView(
                        playerID: pid,
                        playerName: model.playerNames[playerIndex],
                        themeType: model.themeType(for: playerIndex)
                    )
                }
            }
            .sheet(item: $showsPlayerEdit) { mode in
                PlayerEditSheet(mode: mode, matchModel: model)
                    .environment(\.theme, theme)
            }
            .task(id: model.isGameOver && isWinner) {
                let finalTotal = model.totalScore(for: playerIndex)
                let gameIsOver = model.isGameOver
                let thisPlayerWon = model.isWinner(playerIndex)
                guard gameIsOver && thisPlayerWon else {
                    displayedTotal = finalTotal
                    return
                }
                // Skip count-up if already at final (e.g. resumed with a completed game).
                guard displayedTotal < finalTotal else { return }
                let steps = min(50, finalTotal)
                let startVal = max(0, finalTotal - steps)
                displayedTotal = startVal
                guard steps > 0 else { return }
                let intervalNs = UInt64(1_500_000_000 / steps)
                for v in startVal...finalTotal {
                    guard !Task.isCancelled else { return }
                    displayedTotal = v
                    if v < finalTotal { try? await Task.sleep(nanoseconds: intervalNs) }
                }
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
                if model.canEditPlayers {
                    Button {
                        showsPlayerEdit = fetchPlayerEditMode()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
                .font(.system(size: initialsFontSize, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().stroke(colorButtonBorder, lineWidth: 1.5))
        .frame(width: initialsCircleSize, height: initialsCircleSize)
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
        let viewerID = model.playerIDs[playerIndex]

        VStack(alignment: .leading, spacing: 10) {
            if model.playerCount == 2,
               let aID = viewerID,
               let bIndex = (0..<model.playerCount).first(where: { $0 != playerIndex }),
               let bID = model.playerIDs[bIndex] {
                HeadToHeadCard(
                    playerAID: aID,
                    playerAName: model.playerNames[playerIndex],
                    playerBID: bID,
                    playerBName: model.playerNames[bIndex]
                )
            }

            if viewerID != nil {
                Button {
                    showsProfile = true
                } label: {
                    HStack(spacing: 3) {
                        Text("View profile")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(theme.primaryAccent.opacity(0.8))
                }
                .buttonStyle(.plain)
            } else {
                Text("Add to roster for stats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                    summaryRow(title: "Yatzy Bonus", value: model.yatzyBonus(for: playerIndex))
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
        CategoryScoreRow(
            category: category,
            isBestSuggested: category == bestSuggestedCategory,
            cell: playerCell(for: category),
            theme: Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
            columnWidth: scoreColumnWidth,
            rowHeight: scoreRowHeight,
            rowAction: rowAction(for: category)
        )
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
        lowerSectionSubtotal + model.yatzyBonus(for: playerIndex)
    }

    private var bestSuggestedCategory: YatzyCategory? {
        model.suggestedCategory(for: playerIndex)
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
            isBestSuggested: category == bestSuggestedCategory,
            isAvailable: assignedScore == nil,
            canScore: canScore,
            isCurrentPlayer: isCurrentPlayer,
            isWinner: model.isWinner(playerIndex)
        ) {
            model.score(category: category)
            if model.isGameOver { director.gameEnded() } else { director.scoreConfirmed() }
        }
    }

    private func rowAction(for category: YatzyCategory) -> (() -> Void)? {
        let cell = playerCell(for: category)
        return (cell.isAvailable && cell.canScore) ? cell.onSelect : nil
    }

    private func cardHighlightColor(isWinner: Bool, isCurrentPlayer: Bool, theme: Theme) -> Color {
        if isWinner && model.isGameOver {
            return theme.primaryAccent.opacity(isWinnerHighlightExpanded ? 0.50 : 0.32)
        }
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

    private func fetchPlayerEditMode() -> PlayerEditSheet.Mode? {
        guard let playerID = model.playerIDs[playerIndex] else { return nil }
        var desc = FetchDescriptor<PlayerModel>(predicate: #Predicate { $0.id == playerID })
        desc.fetchLimit = 1
        guard let pm = (try? modelContext.fetch(desc))?.first else { return nil }
        return .edit(pm, matchSlot: playerIndex)
    }
}

private struct CategoryScoreRow: View {
    let category: YatzyCategory
    let isBestSuggested: Bool
    let cell: ScoreRow.PlayerCell
    let theme: Theme
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let rowAction: (() -> Void)?

    @Environment(\.suggestedMoveEnabled) private var suggestedMoveEnabled
    @State private var labelBright = false

    private var shouldPulse: Bool { isBestSuggested && suggestedMoveEnabled }

    var body: some View {
        HStack(spacing: 2) {
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(shouldPulse ? .bold : .regular)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundStyle(
                    shouldPulse
                        ? theme.secondaryAccent.opacity(labelBright ? 1.0 : 0.55)
                        : Color.primary
                )
            Spacer()
            ScoreRow(
                players: [cell],
                theme: theme,
                columnWidth: columnWidth,
                rowHeight: rowHeight,
                rowAction: rowAction
            )
        }
        .frame(height: rowHeight)
        // .task(id:) is cancelled and restarted whenever shouldPulse changes,
        // which reliably stops the previous animation cycle.
        .task(id: shouldPulse) {
            guard shouldPulse else {
                withAnimation(.easeInOut(duration: 0.25)) { labelBright = false }
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.4)) { labelBright = true }
                do { try await Task.sleep(for: .seconds(1.4)) } catch { break }
                withAnimation(.easeInOut(duration: 1.4)) { labelBright = false }
                do { try await Task.sleep(for: .seconds(1.4)) } catch { break }
            }
        }
    }
}

#Preview("Editable Player Card") {
    PlayerScoreCardPreviewContainer()
        .padding()
        .frame(width: 320)
        .environment(FeelDirector(catalog: .syFive))
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
            .environment(FeelDirector(catalog: .syFive))
        }
    }
}
