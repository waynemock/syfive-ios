import Foundation
import Observation
import SwiftUI

@Observable
final class MatchController {
    struct UndoRestoration {
        let diceValues: [Int]
        let held: [Bool]
    }

    private struct LastScoreSnapshot {
        let diceValues: [Int]
        let held: [Bool]
        let rollsRemaining: Int
        let playerScores: [[YatzyCategory: Int]]
        let playerYahtzeeBonuses: [Int]
        let currentPlayerIndex: Int
        let isRolling: Bool
    }

    private let diceCount = 5
    private let rollsPerTurn = 3

    private(set) var diceValues: [Int]
    private(set) var held: [Bool]
    private(set) var rollsRemaining: Int
    private(set) var playerScores: [[YatzyCategory: Int]]
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
        playerScores = [[:]]
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
        (0..<playerCount).allSatisfy { isComplete(scorecard: yatzyScorecard(for: $0)) }
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
        return winnerIndices.first.map { totalScore(for: $0) }
    }

    var leaderIndices: [Int] {
        let totals = (0..<playerCount).map { totalScore(for: $0) }
        guard let maxScore = totals.max(), maxScore > 0 else { return [] }
        return totals.enumerated().compactMap { index, score in
            score == maxScore ? index : nil
        }
    }

    var leaderNames: [String] {
        leaderIndices.map { "P\($0 + 1)" }
    }

    var leaderScore: Int? {
        leaderIndices.first.map { totalScore(for: $0) }
    }

    var leadingPlayerLabel: String? {
        let names = leaderNames.joined(separator: ", ")
        guard playerCount > 1 && !names.isEmpty else { return nil }
        return leaderIndices.count > 1 ? "\(names) tied" : "\(names) winning"
    }

    var canScore: Bool {
        rollsRemaining < rollsPerTurn && !isGameOver && !isRolling
    }

    var totalRounds: Int {
        YatzyCategory.allCases.count
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
        undoPlayerIndex.map { themeType(for: $0) }
    }

    func canScore(category: YatzyCategory, for playerIndex: Int) -> Bool {
        guard canScore else { return false }
        guard playerIndex == currentPlayerIndex else { return false }
        return legalScoreCategories(for: playerIndex).contains(category)
    }

    func scores(for playerIndex: Int) -> [YatzyCategory: Int] {
        guard playerScores.indices.contains(playerIndex) else { return [:] }
        return playerScores[playerIndex]
    }

    func themeType(for playerIndex: Int) -> Theme.ThemeType {
        guard playerThemes.indices.contains(playerIndex) else { return .midnight }
        return playerThemes[playerIndex]
    }

    func upperSubtotal(for playerIndex: Int) -> Int {
        // Inline to avoid base-name collision with domain free function upperSubtotal(scorecard:)
        let sc = yatzyScorecard(for: playerIndex)
        return YatzyCategory.allCases
            .filter { $0.isUpperSection }
            .compactMap { sc[$0] }
            .reduce(0) { $0 + NSDecimalNumber(decimal: $1).intValue }
    }

    func upperBonus(for playerIndex: Int) -> Int {
        upperSubtotal(for: playerIndex) >= 63 ? 35 : 0
    }

    func totalScore(for playerIndex: Int) -> Int {
        grandTotal(scorecard: yatzyScorecard(for: playerIndex), yahtzeeBonus: yahtzeeBonus(for: playerIndex))
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

    func score(category: YatzyCategory) {
        guard playerScores.indices.contains(currentPlayerIndex) else { return }
        guard playerScores[currentPlayerIndex][category] == nil else { return }
        guard legalScoreCategories(for: currentPlayerIndex).contains(category) else { return }
        lastScoreSnapshot = LastScoreSnapshot(
            diceValues: diceValues,
            held: held,
            rollsRemaining: rollsRemaining,
            playerScores: playerScores,
            playerYahtzeeBonuses: playerYahtzeeBonuses,
            currentPlayerIndex: currentPlayerIndex,
            isRolling: isRolling
        )
        if qualifiesForExtraYahtzeeBonus(dice: diceValues, scorecard: yatzyScorecard(for: currentPlayerIndex)) {
            playerYahtzeeBonuses[currentPlayerIndex] += 100
        }
        playerScores[currentPlayerIndex][category] = scoreValue(for: category, playerIndex: currentPlayerIndex)
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

    func suggestedScores(for playerIndex: Int) -> [YatzyCategory: Int] {
        guard playerScores.indices.contains(playerIndex) else { return [:] }
        return legalScoreCategories(for: playerIndex).reduce(into: [:]) { result, category in
            result[category] = scoreValue(for: category, playerIndex: playerIndex)
        }
    }

    func yahtzeeBonus(for playerIndex: Int) -> Int {
        guard playerYahtzeeBonuses.indices.contains(playerIndex) else { return 0 }
        return playerYahtzeeBonuses[playerIndex]
    }

    // MARK: - Private

    private func beginNextTurn() {
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        currentPlayerIndex = (currentPlayerIndex + 1) % playerCount
    }

    private func clearUndoState() {
        lastScoreSnapshot = nil
    }

    private func yatzyScorecard(for playerIndex: Int) -> YatzyScorecard {
        guard playerScores.indices.contains(playerIndex) else { return [:] }
        return playerScores[playerIndex].mapValues { Decimal($0) }
    }

    private func scoreValue(for category: YatzyCategory, playerIndex: Int) -> Int {
        let scorecard = yatzyScorecard(for: playerIndex)
        if let joker = jokerValue(of: category, dice: diceValues, scorecard: scorecard) {
            return joker
        }
        return faceValue(of: category, dice: diceValues)
    }

    private func legalScoreCategories(for playerIndex: Int) -> [YatzyCategory] {
        legalCategories(dice: diceValues, scorecard: yatzyScorecard(for: playerIndex))
    }

    private static func defaultTheme(for index: Int) -> Theme.ThemeType {
        let order: [Theme.ThemeType] = [
            .midnight, .blossom, .ember, .forest, .ocean, .sunset, .paper
        ]
        return order[index % order.count]
    }
}
