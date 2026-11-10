import SwiftUI
import SyLibUI
import Observation
import SyLibCore
import SyLibFeel
import SyLibYatzy
import SyLibYatzyUI

struct ScorecardView: View {
    @Bindable var model: MatchController
    let availableWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.syTheme) private var theme
    @Environment(FeelDirector.self) private var director
    @Environment(\.suggestedMoveEnabled) private var suggestedMoveEnabled
    @State private var showsPlayerPicker = false

    private let logger = AppLogger(category: "ScorecardView")

    var body: some View {
        Group {
            if model.canEditPlayers {
                PreGameGridView(model: model) {
                    showsPlayerPicker = true
                }
            } else {
                // The pager follows currentIndex; at game over that is the winner, so it
                // scrolls to them as the in-game view did (26 §5, Task 26.10).
                YatzyScorecardPager(cards: cards, currentIndex: pagerIndex)
            }
        }
        .sheet(isPresented: $showsPlayerPicker) {
            NewGameSheet(model: model)
                .environment(\.syTheme, theme)
                .sheetTextSizeCeiling()
        }
    }

    private var pagerIndex: Int {
        model.isGameOver ? (model.winnerIndices.first ?? model.currentPlayerIndex) : model.currentPlayerIndex
    }

    /// One card per seat, every input read from the controller (26 §5, Task 26.10).
    private var cards: [YatzyScorecardCard] {
        model.slotIDs.indices.map { i in
            YatzyScorecardCard(
                name: model.playerNames[i],
                initials: model.playerInitials(for: i),
                palette: model.themeType(for: i),
                scorecard: model.scores(for: i),
                yatzyBonus: model.yatzyBonus(for: i),
                isCurrentTurn: i == model.currentPlayerIndex && model.playerCount > 1
                    && model.hasStarted && !model.isGameOver,
                isWinner: model.isWinner(i) && model.isGameOver,
                isLeading: model.playerCount > 1 && model.leaderIndices.contains(i),
                // Only the current player's card can score.
                canScore: model.canScore && i == model.currentPlayerIndex,
                // Today's per-cell rule, joker and strict-poison placement included (D-161).
                scorableCategories: Set(YatzyCategory.allCases.filter { model.canScore(category: $0, for: i) }),
                suggestedValues: model.suggestedScores(for: i),
                // Suggested values always show; the setting controls only the pulse (D-161).
                pulsesBestSuggestion: suggestedMoveEnabled,
                onSelect: { category in
                    model.score(category: category)
                    if model.isGameOver { director.gameEnded() } else { director.scoreConfirmed() }
                }
            )
        }
    }
}

#Preview {
    ScorecardView(model: MatchController(), availableWidth: 360)
        .environment(FeelDirector(catalog: .syFive))
}
