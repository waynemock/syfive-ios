import Foundation
import Observation
import SwiftUI
import SwiftData

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
    private(set) var playerDisplayNames: [String]
    private(set) var playerDisplayInitials: [String]
    // UUID of the roster Player behind each slot; nil for anonymous/default players.
    private(set) var playerIDs: [UUID?]
    // Stable identity per slot — survives reorder and reset; used for ForEach animation.
    private(set) var slotIDs: [UUID]
    // Stable identity per participant across incremental saves; refreshed on resetGame.
    private(set) var participantIDs: [UUID]
    // Set when first persisted; nil before first save or after reset.
    private(set) var persistedMatchID: UUID?
    private var matchStartedAt: Date?
    private var matchCompletedAt: Date?
    private(set) var currentPlayerIndex: Int
    /// True while physics dice are mid-roll (between beginRoll and receiveDiceResults).
    private(set) var isRolling: Bool = false
    private var lastScoreSnapshot: LastScoreSnapshot?

    init() {
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        playerScores = []
        playerYahtzeeBonuses = []
        playerThemes = []
        playerDisplayNames = []
        playerDisplayInitials = []
        playerIDs = []
        slotIDs = []
        participantIDs = []
        persistedMatchID = nil
        matchStartedAt = nil
        matchCompletedAt = nil
        currentPlayerIndex = 0
    }

    var playerCount: Int { playerScores.count }

    var playerNames: [String] { playerDisplayNames }

    var currentPlayerName: String {
        guard playerDisplayNames.indices.contains(currentPlayerIndex) else { return "" }
        return playerDisplayNames[currentPlayerIndex]
    }

    var hasStarted: Bool {
        rollsRemaining < rollsPerTurn || playerScores.contains { !$0.isEmpty }
    }

    var canEditPlayers: Bool { !hasStarted }

    var isGameOver: Bool {
        (0..<playerCount).allSatisfy { isComplete(scorecard: yatzyScorecard(for: $0)) }
    }

    var winnerIndices: [Int] {
        guard isGameOver else { return [] }
        let totals = (0..<playerCount).map { totalScore(for: $0) }
        guard let maxScore = totals.max() else { return [] }
        return totals.enumerated().compactMap { index, score in score == maxScore ? index : nil }
    }

    var winnerNames: [String] { winnerIndices.map { playerDisplayNames[$0] } }

    var winnerScore: Int? {
        guard isGameOver else { return nil }
        return winnerIndices.first.map { totalScore(for: $0) }
    }

    var leaderIndices: [Int] {
        let totals = (0..<playerCount).map { totalScore(for: $0) }
        guard let maxScore = totals.max(), maxScore > 0 else { return [] }
        return totals.enumerated().compactMap { index, score in score == maxScore ? index : nil }
    }

    var leaderNames: [String] { leaderIndices.map { playerDisplayNames[$0] } }

    var leaderScore: Int? { leaderIndices.first.map { totalScore(for: $0) } }

    var leadingPlayerLabel: String? {
        let names = leaderNames.joined(separator: ", ")
        guard playerCount > 1 && !names.isEmpty else { return nil }
        return leaderIndices.count > 1 ? "\(names) tied" : "\(names) winning"
    }

    var canScore: Bool {
        rollsRemaining < rollsPerTurn && !isGameOver && !isRolling
    }

    var totalRounds: Int { YatzyCategory.allCases.count }

    var currentRound: Int {
        let scoredCount = scores(for: currentPlayerIndex).count
        return min(scoredCount + 1, totalRounds)
    }

    var isLastRound: Bool { currentRound == totalRounds }

    var nextPlayerThemeType: Theme.ThemeType {
        Self.defaultTheme(for: playerCount)
    }

    var canUndoLastScore: Bool { lastScoreSnapshot != nil }

    var undoPlayerIndex: Int? { lastScoreSnapshot?.currentPlayerIndex }

    var undoThemeType: Theme.ThemeType? { undoPlayerIndex.map { themeType(for: $0) } }

    func playerInitials(for playerIndex: Int) -> String {
        guard playerDisplayInitials.indices.contains(playerIndex) else { return "" }
        return playerDisplayInitials[playerIndex]
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

    func isWinner(_ playerIndex: Int) -> Bool { winnerIndices.contains(playerIndex) }

    // Adds a roster player to the current match, snapshotting display fields.
    func addPlayer(from player: Player) {
        guard canEditPlayers else { return }
        clearUndoState()
        let newIndex = playerScores.count
        let theme = Theme.ThemeType(rawValue: player.themeID) ?? Self.defaultTheme(for: newIndex)
        playerScores.append([:])
        playerYahtzeeBonuses.append(0)
        playerThemes.append(theme)
        playerDisplayNames.append(player.name)
        playerDisplayInitials.append(player.initials)
        playerIDs.append(player.id)
        slotIDs.append(UUID())
        participantIDs.append(UUID())
    }

    // Adds an anonymous player (no roster record) — used for solo/default play.
    func addPlayer() {
        guard canEditPlayers else { return }
        clearUndoState()
        let newIndex = playerScores.count
        let n = newIndex + 1
        playerScores.append([:])
        playerYahtzeeBonuses.append(0)
        playerThemes.append(Self.defaultTheme(for: newIndex))
        playerDisplayNames.append("Player \(n)")
        playerDisplayInitials.append("P\(n)")
        playerIDs.append(nil)
        slotIDs.append(UUID())
        participantIDs.append(UUID())
    }

    func removePlayer(at index: Int) {
        guard canEditPlayers, playerScores.indices.contains(index) else { return }
        clearUndoState()
        playerScores.remove(at: index)
        playerYahtzeeBonuses.remove(at: index)
        playerDisplayNames.remove(at: index)
        playerDisplayInitials.remove(at: index)
        playerIDs.remove(at: index)
        if slotIDs.indices.contains(index) { slotIDs.remove(at: index) }
        if participantIDs.indices.contains(index) { participantIDs.remove(at: index) }
        if playerThemes.indices.contains(index) { playerThemes.remove(at: index) }
        if currentPlayerIndex >= playerScores.count {
            currentPlayerIndex = max(0, playerScores.count - 1)
        }
    }

    func movePlayer(from source: Int, to destination: Int) {
        guard canEditPlayers, source != destination else { return }
        guard playerScores.indices.contains(source) && playerScores.indices.contains(destination) else { return }

        func reorder<T>(in array: inout [T]) {
            let item = array.remove(at: source)
            array.insert(item, at: destination)
        }

        reorder(in: &playerScores)
        reorder(in: &playerYahtzeeBonuses)
        reorder(in: &playerThemes)
        reorder(in: &playerDisplayNames)
        reorder(in: &playerDisplayInitials)
        reorder(in: &playerIDs)
        reorder(in: &slotIDs)
        reorder(in: &participantIDs)
    }

    // Resets scores only — player identity (names, initials, themes) persists for a rematch.
    func resetGame() {
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        playerScores = Array(repeating: [:], count: playerCount)
        playerYahtzeeBonuses = Array(repeating: 0, count: playerCount)
        currentPlayerIndex = 0
        isRolling = false
        // Fresh participant IDs so the new game doesn't collide with the previous one.
        participantIDs = (0..<playerCount).map { _ in UUID() }
        persistedMatchID = nil
        matchStartedAt = nil
        matchCompletedAt = nil
        clearUndoState()
    }

    func updatePlayer(at index: Int, name: String, initials: String, themeType: Theme.ThemeType) {
        guard playerDisplayNames.indices.contains(index) else { return }
        playerDisplayNames[index] = name
        playerDisplayInitials[index] = initials
        if playerThemes.indices.contains(index) {
            playerThemes[index] = themeType
        }
    }

    /// Re-adds a player from a completed match's participant data without a full PlayerModel lookup.
    /// Used to pre-populate the next game with the previous game's roster.
    func restorePlayer(displayName: String, displayInitials: String, themeID: String, playerID: UUID?) {
        guard canEditPlayers else { return }
        clearUndoState()
        let themeType = Theme.ThemeType(rawValue: themeID) ?? Self.defaultTheme(for: playerScores.count)
        playerScores.append([:])
        playerYahtzeeBonuses.append(0)
        playerThemes.append(themeType)
        playerDisplayNames.append(displayName)
        playerDisplayInitials.append(displayInitials)
        playerIDs.append(playerID)
        slotIDs.append(UUID())
        participantIDs.append(UUID())
    }

    // MARK: - Persistence

    /// Writes the current match state to SwiftData. Creates a new row on first call;
    /// subsequent calls update the same row using its UUID. Safe to call on every score.
    func save(to context: ModelContext, gameID: UUID) {
        guard playerCount > 0 else { return }

        let matchModel: MatchModel
        if let mid = persistedMatchID {
            let descriptor = FetchDescriptor<MatchModel>(predicate: #Predicate { $0.id == mid })
            matchModel = (try? context.fetch(descriptor))?.first ?? {
                let m = MatchModel(); context.insert(m); return m
            }()
        } else {
            matchModel = MatchModel()
            context.insert(matchModel)
            persistedMatchID = matchModel.id
        }

        if matchStartedAt == nil { matchStartedAt = matchModel.startedAt }
        if isGameOver && matchCompletedAt == nil { matchCompletedAt = Date() }

        let match = Match(
            id: matchModel.id,
            gameID: gameID,
            scoringSystemID: "yatzy",
            scoringSystemVersion: 1,
            status: isGameOver ? .completed : .inProgress,
            startedAt: matchStartedAt ?? Date(),
            completedAt: isGameOver ? matchCompletedAt : nil,
            participants: buildParticipants()
        )
        matchModel.hydrate(from: match, context: context)
    }

    /// Restores match state from a persisted MatchModel in-place, preserving view identity.
    func load(from matchModel: MatchModel) {
        playerScores = []
        playerYahtzeeBonuses = []
        playerThemes = []
        playerDisplayNames = []
        playerDisplayInitials = []
        playerIDs = []
        participantIDs = []
        slotIDs = []

        persistedMatchID = matchModel.id
        matchStartedAt = matchModel.startedAt
        matchCompletedAt = matchModel.completedAt

        for p in matchModel.participants.sorted(by: { $0.seat < $1.seat }) {
            let themeType = Theme.ThemeType(rawValue: p.displayThemeID) ?? .midnight
            let scores: [YatzyCategory: Int] = Dictionary(
                uniqueKeysWithValues: p.scoreEntries.compactMap { entry in
                    guard let cat = YatzyCategory(rawValue: entry.slotKey),
                          let val = entry.value else { return nil }
                    return (cat, NSDecimalNumber(decimal: val).intValue)
                }
            )
            playerScores.append(scores)
            playerYahtzeeBonuses.append(p.yahtzeeBonus)
            playerThemes.append(themeType)
            playerDisplayNames.append(p.displayName)
            playerDisplayInitials.append(p.displayInitials)
            playerIDs.append(p.playerID)
            participantIDs.append(p.id)
            slotIDs.append(UUID())
        }

        // Derive whose turn it is: seat with fewest scored categories wins ties by seat order.
        let minScored = playerScores.map(\.count).min() ?? 0
        currentPlayerIndex = playerScores.firstIndex(where: { $0.count == minScored }) ?? 0
        rollsRemaining = rollsPerTurn
        held = Array(repeating: false, count: diceCount)
        diceValues = Array(repeating: 1, count: diceCount)
        isRolling = false
        clearUndoState()
    }

    /// Marks the current match as abandoned (or deletes it if no scoring has occurred).
    /// Call before resetGame() when the user explicitly starts a new game.
    func abandonMatch(in context: ModelContext) {
        guard let mid = persistedMatchID else { return }
        let descriptor = FetchDescriptor<MatchModel>(predicate: #Predicate { $0.id == mid })
        if let match = (try? context.fetch(descriptor))?.first, !isGameOver {
            if hasStarted {
                match.status = .abandoned
                match.completedAt = Date()
            } else {
                context.delete(match)
            }
        }
        try? context.save()
        persistedMatchID = nil
        matchStartedAt = nil
        matchCompletedAt = nil
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
            if i < values.count { diceValues[i] = values[i] }
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
        if !isGameOver { beginNextTurn() }
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

    private func buildParticipants() -> [Participant] {
        (0..<playerCount).map { i in
            let entries = playerScores[i].map { (cat, val) in
                ScoreEntry(slotKey: cat.slotKey, value: Decimal(val), metadata: nil, recordedAt: nil)
            }
            return Participant(
                id: participantIDs[i],
                seat: i,
                finalScore: Decimal(totalScore(for: i)),
                rank: isGameOver ? computeRank(for: i) : 0,
                yahtzeeBonus: playerYahtzeeBonuses[i],
                playerID: playerIDs[i],
                teamID: nil,
                displayName: playerDisplayNames[i],
                displayInitials: playerDisplayInitials[i],
                displayThemeID: playerThemes[i].rawValue,
                scoreEntries: entries
            )
        }
    }

    private func computeRank(for playerIndex: Int) -> Int {
        let myScore = totalScore(for: playerIndex)
        let betterCount = (0..<playerCount).filter { totalScore(for: $0) > myScore }.count
        return betterCount + 1
    }

    private func beginNextTurn() {
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        currentPlayerIndex = (currentPlayerIndex + 1) % playerCount
    }

    private func clearUndoState() { lastScoreSnapshot = nil }

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

    static func defaultTheme(for index: Int) -> Theme.ThemeType {
        let order: [Theme.ThemeType] = [
            .midnight, .blossom, .ember, .forest, .ocean, .sunset, .paper
        ]
        return order[index % order.count]
    }
}
