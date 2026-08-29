import Foundation
import SyLibGameNightMatch
import SyLibScoring
import SyLibYatzy
import Observation

/// Guest-side render model. Adopts MatchPresenting so views can bind it without
/// knowing which authority they're reading. Populated from MatchStatePayload
/// messages in Phase 4; returns empty defaults until then.
@Observable
final class TableReplica: MatchPresenting {
    private(set) var playerCount: Int = 0
    private(set) var playerNames: [String] = []
    private(set) var playerIDs: [UUID?] = []
    private(set) var slotIDs: [UUID] = []
    private(set) var currentPlayerIndex: Int = 0
    private(set) var hasStarted: Bool = false
    private(set) var canEditPlayers: Bool = false
    private(set) var isGameOver: Bool = false
    private(set) var canScore: Bool = false
    private(set) var totalRounds: Int = YatzyCategory.allCases.count
    private(set) var currentRound: Int = 1
    private(set) var winnerIndices: [Int] = []
    private(set) var winnerNames: [String] = []
    private(set) var leaderIndices: [Int] = []
    private(set) var leadingPlayerLabel: String? = nil

    private var initialsStore: [String] = []
    private var themeTypeStore: [Theme.ThemeType] = []
    private var scoresStore: [[YatzyCategory: Int]] = []
    private var totalScoresStore: [Int] = []
    private var upperSubtotalsStore: [Int] = []
    private var upperBonusesStore: [Int] = []
    private var yatzyBonusesStore: [Int] = []
    private var winnerSet: Set<Int> = []

    func playerInitials(for playerIndex: Int) -> String {
        initialsStore.indices.contains(playerIndex) ? initialsStore[playerIndex] : ""
    }
    func themeType(for playerIndex: Int) -> Theme.ThemeType {
        themeTypeStore.indices.contains(playerIndex) ? themeTypeStore[playerIndex] : .midnight
    }
    func scores(for playerIndex: Int) -> [YatzyCategory: Int] {
        scoresStore.indices.contains(playerIndex) ? scoresStore[playerIndex] : [:]
    }
    func totalScore(for playerIndex: Int) -> Int {
        totalScoresStore.indices.contains(playerIndex) ? totalScoresStore[playerIndex] : 0
    }
    func upperSubtotal(for playerIndex: Int) -> Int {
        upperSubtotalsStore.indices.contains(playerIndex) ? upperSubtotalsStore[playerIndex] : 0
    }
    func upperBonus(for playerIndex: Int) -> Int {
        upperBonusesStore.indices.contains(playerIndex) ? upperBonusesStore[playerIndex] : 0
    }
    func yatzyBonus(for playerIndex: Int) -> Int {
        yatzyBonusesStore.indices.contains(playerIndex) ? yatzyBonusesStore[playerIndex] : 0
    }
    func isWinner(_ playerIndex: Int) -> Bool { winnerSet.contains(playerIndex) }
    func canScore(category: YatzyCategory, for playerIndex: Int) -> Bool { false }
    func suggestedCategory(for playerIndex: Int) -> YatzyCategory? { nil }
    func suggestedScores(for playerIndex: Int) -> [YatzyCategory: Int] { [:] }

    // MARK: - Phase 4: populated from MatchStatePayload

    func applyMatchState(_ payload: MatchStatePayload) {
        // Implemented in Phase 4
    }
}
