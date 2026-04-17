import Foundation
import Observation
import SwiftUI

@Observable
final class GameModel {
    struct UndoRestoration {
        let diceValues: [Int]
        let held: [Bool]
    }

    private struct LastScoreSnapshot {
        let diceValues: [Int]
        let held: [Bool]
        let rollsRemaining: Int
        let playerScores: [[ScoreCategory: Int]]
        let playerYahtzeeBonuses: [Int]
        let currentPlayerIndex: Int
        let isRolling: Bool
    }

    enum ScoreCategory: String, CaseIterable, Identifiable {
        case ones
        case twos
        case threes
        case fours
        case fives
        case sixes
        case threeOfAKind
        case fourOfAKind
        case fullHouse
        case smallStraight
        case largeStraight
        case yahtzee
        case chance

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .ones: return "Ones"
            case .twos: return "Twos"
            case .threes: return "Threes"
            case .fours: return "Fours"
            case .fives: return "Fives"
            case .sixes: return "Sixes"
            case .threeOfAKind: return "3 of a Kind"
            case .fourOfAKind: return "4 of a Kind"
            case .fullHouse: return "Full House"
            case .smallStraight: return "Small Straight"
            case .largeStraight: return "Large Straight"
            case .yahtzee: return "Yatzy"
            case .chance: return "Chance"
            }
        }

        var isUpperSection: Bool {
            switch self {
            case .ones, .twos, .threes, .fours, .fives, .sixes:
                return true
            default:
                return false
            }
        }
    }

    private let diceCount = 5
    private let sides = 6
    private let rollsPerTurn = 3

    private let upperBonusThreshold = 63
    private let upperBonusValue = 35

    private(set) var diceValues: [Int]
    private(set) var held: [Bool]
    private(set) var rollsRemaining: Int
    private(set) var playerScores: [[ScoreCategory: Int]]
    private(set) var playerYahtzeeBonuses: [Int]
    private(set) var playerThemes: [Theme.ThemeType]
    private(set) var currentPlayerIndex: Int
    /// True while physics dice are mid-roll (between beginRoll and receiveDiceResults).
    private(set) var isRolling: Bool = false
    private var lastScoreSnapshot: LastScoreSnapshot?

    init() {
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        playerScores = [[:]  ]
        playerYahtzeeBonuses = [0]
        playerThemes = [Self.defaultTheme(for: 0)]
        currentPlayerIndex = 0
    }

    var playerCount: Int {
        playerScores.count
    }

    var playerNames: [String] {
        (0..<playerCount).map { "P\($0 + 1)" }
    }

    var currentPlayerName: String {
        playerNames[currentPlayerIndex]
    }

    var hasStarted: Bool {
        rollsRemaining < rollsPerTurn || playerScores.contains { !$0.isEmpty }
    }

    var canEditPlayers: Bool {
        !hasStarted
    }

    var isGameOver: Bool {
        playerScores.allSatisfy { $0.count == ScoreCategory.allCases.count }
    }

    var winnerIndices: [Int] {
        guard isGameOver else { return [] }
        let totals = (0..<playerCount).map { totalScore(for: $0) }
        guard let maxScore = totals.max() else { return [] }
        return totals.enumerated().compactMap { index, score in
            score == maxScore ? index : nil
        }
    }

    var winnerNames: [String] {
        winnerIndices.map { "P\($0 + 1)" }
    }

    var winnerScore: Int? {
        guard isGameOver else { return nil }
        if let first = winnerIndices.first {
            return totalScore(for: first)
        }
        return nil
    }
    
    var canScore: Bool {
        rollsRemaining < rollsPerTurn && !isGameOver && !isRolling
    }

    var totalRounds: Int {
        ScoreCategory.allCases.count
    }

    var currentRound: Int {
        let scoredCount = scores(for: currentPlayerIndex).count
        return min(scoredCount + 1, totalRounds)
    }

    var isLastRound: Bool {
        currentRound == totalRounds
    }

    var nextPlayerThemeType: Theme.ThemeType {
        Self.defaultTheme(for: playerCount)
    }

    var canUndoLastScore: Bool {
        lastScoreSnapshot != nil
    }

    var undoPlayerIndex: Int? {
        lastScoreSnapshot?.currentPlayerIndex
    }

    var undoThemeType: Theme.ThemeType? {
        guard let playerIndex = undoPlayerIndex else { return nil }
        return themeType(for: playerIndex)
    }

    func scores(for playerIndex: Int) -> [ScoreCategory: Int] {
        guard playerScores.indices.contains(playerIndex) else { return [:] }
        return playerScores[playerIndex]
    }

    func themeType(for playerIndex: Int) -> Theme.ThemeType {
        guard playerThemes.indices.contains(playerIndex) else { return .midnight }
        return playerThemes[playerIndex]
    }

    func upperSubtotal(for playerIndex: Int) -> Int {
        scores(for: playerIndex).compactMap { entry in
            guard entry.key.isUpperSection else { return nil }
            return entry.value
        }.reduce(0, +)
    }

    func upperBonus(for playerIndex: Int) -> Int {
        upperSubtotal(for: playerIndex) >= upperBonusThreshold ? upperBonusValue : 0
    }

    func totalScore(for playerIndex: Int) -> Int {
        let base = scores(for: playerIndex).values.reduce(0, +)
        return base + upperBonus(for: playerIndex) + yahtzeeBonus(for: playerIndex)
    }

    func isWinner(_ playerIndex: Int) -> Bool {
        winnerIndices.contains(playerIndex)
    }

    func addPlayer() {
        guard canEditPlayers else { return }
        clearUndoState()
        let newIndex = playerScores.count
        playerScores.append([:])
        playerYahtzeeBonuses.append(0)
        playerThemes.append(Self.defaultTheme(for: newIndex))
    }

    func removePlayer(at index: Int) {
        guard canEditPlayers, playerScores.count > 1, index > 0 else { return }
        clearUndoState()
        playerScores.remove(at: index)
        playerYahtzeeBonuses.remove(at: index)
        if playerThemes.indices.contains(index) {
            playerThemes.remove(at: index)
        }
        if currentPlayerIndex >= playerScores.count {
            currentPlayerIndex = max(0, playerScores.count - 1)
        }
    }

    func resetGame() {
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        playerScores = Array(repeating: [:], count: playerCount)
        playerYahtzeeBonuses = Array(repeating: 0, count: playerCount)
        currentPlayerIndex = 0
        isRolling = false
        clearUndoState()
    }

    func setTheme(_ theme: Theme.ThemeType, for playerIndex: Int) {
        guard canEditPlayers, playerThemes.indices.contains(playerIndex) else { return }
        playerThemes[playerIndex] = theme
    }

    func toggleHold(at index: Int) {
        guard diceValues.indices.contains(index), !isGameOver, canScore else { return }
        held[index].toggle()
    }

    // MARK: - Physics roll interface

    /// Call before launching physics dice. Decrements rollsRemaining and marks isRolling.
    func beginRoll() {
        guard rollsRemaining > 0, !isGameOver, !isRolling else { return }
        clearUndoState()
        rollsRemaining -= 1
        isRolling = true
    }

    /// Call when physics dice have settled. Updates diceValues for non-held positions.
    /// `values` must have one entry per die (5 total); held dice entries are ignored.
    func receiveDiceResults(_ values: [Int]) {
        guard isRolling else { return }
        for i in diceValues.indices where !held[i] {
            if i < values.count {
                diceValues[i] = values[i]
            }
        }
        isRolling = false
    }

    func score(category: ScoreCategory) {
        guard playerScores.indices.contains(currentPlayerIndex) else { return }
        guard playerScores[currentPlayerIndex][category] == nil else { return }
        lastScoreSnapshot = LastScoreSnapshot(
            diceValues: diceValues,
            held: held,
            rollsRemaining: rollsRemaining,
            playerScores: playerScores,
            playerYahtzeeBonuses: playerYahtzeeBonuses,
            currentPlayerIndex: currentPlayerIndex,
            isRolling: isRolling
        )
        if qualifiesForExtraYahtzeeBonus(for: currentPlayerIndex) {
            playerYahtzeeBonuses[currentPlayerIndex] += 100
        }
        playerScores[currentPlayerIndex][category] = scoreValue(for: category)
        if !isGameOver {
            beginNextTurn()
        }
    }

    @discardableResult
    func undoLastScore() -> UndoRestoration? {
        guard let snapshot = lastScoreSnapshot else { return nil }

        diceValues = snapshot.diceValues
        held = snapshot.held
        rollsRemaining = snapshot.rollsRemaining
        playerScores = snapshot.playerScores
        playerYahtzeeBonuses = snapshot.playerYahtzeeBonuses
        currentPlayerIndex = snapshot.currentPlayerIndex
        isRolling = snapshot.isRolling
        lastScoreSnapshot = nil

        return UndoRestoration(diceValues: snapshot.diceValues, held: snapshot.held)
    }

    func suggestedScores(for playerIndex: Int) -> [ScoreCategory: Int] {
        guard playerScores.indices.contains(playerIndex) else { return [:] }
        var result: [ScoreCategory: Int] = [:]
        for category in ScoreCategory.allCases where playerScores[playerIndex][category] == nil {
            result[category] = scoreValue(for: category)
        }
        return result
    }

    func yahtzeeBonus(for playerIndex: Int) -> Int {
        guard playerYahtzeeBonuses.indices.contains(playerIndex) else { return 0 }
        return playerYahtzeeBonuses[playerIndex]
    }

    private func beginNextTurn() {
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        currentPlayerIndex = (currentPlayerIndex + 1) % playerCount
    }

    private func clearUndoState() {
        lastScoreSnapshot = nil
    }

    private func qualifiesForExtraYahtzeeBonus(for playerIndex: Int) -> Bool {
        guard isYahtzeeRoll else { return false }
        guard scores(for: playerIndex)[.yahtzee] == 50 else { return false }
        return true
    }

    private static func defaultTheme(for index: Int) -> Theme.ThemeType {
        let order: [Theme.ThemeType] = [
            .midnight, .blossom, .ember, .forest, .ocean, .sunset, .paper
        ]
        return order[index % order.count]
    }

    private func scoreValue(for category: ScoreCategory) -> Int {
        let counts = countByFace()
        let sum = diceValues.reduce(0, +)

        switch category {
        case .ones: return counts[1, default: 0] * 1
        case .twos: return counts[2, default: 0] * 2
        case .threes: return counts[3, default: 0] * 3
        case .fours: return counts[4, default: 0] * 4
        case .fives: return counts[5, default: 0] * 5
        case .sixes: return counts[6, default: 0] * 6
        case .threeOfAKind:
            return hasKind(of: 3, counts: counts) ? sum : 0
        case .fourOfAKind:
            return hasKind(of: 4, counts: counts) ? sum : 0
        case .fullHouse:
            return isFullHouse(counts: counts) ? 25 : 0
        case .smallStraight:
            return isSmallStraight() ? 30 : 0
        case .largeStraight:
            return isLargeStraight() ? 40 : 0
        case .yahtzee:
            return hasKind(of: 5, counts: counts) ? 50 : 0
        case .chance:
            return sum
        }
    }

    private func countByFace() -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for value in diceValues {
            counts[value, default: 0] += 1
        }
        return counts
    }

    private func hasKind(of size: Int, counts: [Int: Int]) -> Bool {
        counts.values.contains { $0 >= size }
    }

    private func isFullHouse(counts: [Int: Int]) -> Bool {
        let values = counts.values.sorted()
        return values == [2, 3]
    }

    private func isSmallStraight() -> Bool {
        let unique = Set(diceValues)
        let sequences: [Set<Int>] = [[1, 2, 3, 4], [2, 3, 4, 5], [3, 4, 5, 6]]
        return sequences.contains { $0.isSubset(of: unique) }
    }

    private func isLargeStraight() -> Bool {
        let unique = Set(diceValues)
        return unique == [1, 2, 3, 4, 5] || unique == [2, 3, 4, 5, 6]
    }

    private var isYahtzeeRoll: Bool {
        Set(diceValues).count == 1
    }
}
