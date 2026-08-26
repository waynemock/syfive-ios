import Foundation
import SyLibScoring
import Observation
import SwiftUI
import SwiftData
import SyLibCore

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
        let playerYatzyBonuses: [Int]
        let playerScoreTimestamps: [[YatzyCategory: Date]]
        let currentPlayerIndex: Int
        let isRolling: Bool
    }

    private let diceCount = 5
    private let rollsPerTurn = 3
    private let logger = AppLogger(category: "MatchController")
    @ObservationIgnored private var lastLoggedSuggestion: YatzyCategory?

    private(set) var diceValues: [Int]
    private(set) var held: [Bool]
    private(set) var rollsRemaining: Int
    private(set) var playerScores: [[YatzyCategory: Int]]
    private var playerScoreTimestamps: [[YatzyCategory: Date]]
    private(set) var playerYatzyBonuses: [Int]
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
    /// True when the current match was started as or promoted to a Game Night match.
    /// Mirrors MatchModel.isGameNight so callers don't need a SwiftData fetch.
    var isGameNight: Bool = false
    private var matchStartedAt: Date?
    private var matchCompletedAt: Date?
    private(set) var currentPlayerIndex: Int
    /// True while physics dice are mid-roll (between beginRoll and receiveDiceResults).
    private(set) var isRolling: Bool = false
    private var lastScoreSnapshot: LastScoreSnapshot?
    var commentaryEventSink: ((CommentaryEvent) -> Void)?

    init() {
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        playerScores = []
        playerScoreTimestamps = []
        playerYatzyBonuses = []
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
        matchStartedAt != nil || rollsRemaining < rollsPerTurn || playerScores.contains { !$0.isEmpty }
    }

    /// True once at least one score category has been filled in. Used to gate SwiftData writes
    /// so pre-populated-but-unplayed games never produce orphan inProgress records.
    var hasGameActivity: Bool {
        playerScores.contains { !$0.isEmpty }
    }

    var canEditPlayers: Bool { !hasStarted }

    var isGameOver: Bool {
        playerCount > 0 && (0..<playerCount).allSatisfy { isComplete(scorecard: yatzyScorecard(for: $0)) }
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
        grandTotal(scorecard: yatzyScorecard(for: playerIndex), yatzyBonus: yatzyBonus(for: playerIndex))
    }

    func isWinner(_ playerIndex: Int) -> Bool { winnerIndices.contains(playerIndex) }

    // Adds a roster player to the current match, snapshotting display fields.
    func addPlayer(from player: Player) {
        guard canEditPlayers else { return }
        clearUndoState()
        let newIndex = playerScores.count
        let theme = Theme.ThemeType(rawValue: player.themeID) ?? Self.defaultTheme(for: newIndex)
        playerScores.append([:])
        playerScoreTimestamps.append([:])
        playerYatzyBonuses.append(0)
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
        playerScoreTimestamps.append([:])
        playerYatzyBonuses.append(0)
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
        if playerScoreTimestamps.indices.contains(index) { playerScoreTimestamps.remove(at: index) }
        playerYatzyBonuses.remove(at: index)
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
        reorder(in: &playerScoreTimestamps)
        reorder(in: &playerYatzyBonuses)
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
        playerScoreTimestamps = Array(repeating: [:], count: playerCount)
        playerYatzyBonuses = Array(repeating: 0, count: playerCount)
        currentPlayerIndex = 0
        isRolling = false
        // Fresh participant IDs so the new game doesn't collide with the previous one.
        participantIDs = (0..<playerCount).map { _ in UUID() }
        persistedMatchID = nil
        isGameNight = false
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
        playerScoreTimestamps.append([:])
        playerYatzyBonuses.append(0)
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
            if let existing = (try? context.fetch(descriptor))?.first {
                matchModel = existing
            } else {
                // Session UUID (wireUUID) didn't match any SwiftData row — first save for this
                // GN game. Stamp the row with the wire UUID before insert so onMatchComplete
                // can locate it by the same UUID and won't create a duplicate record.
                let m = MatchModel()
                m.id = mid
                context.insert(m)
                persistedMatchID = m.id
                matchModel = m
            }
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
            scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1,
            status: isGameOver ? .completed : .inProgress,
            startedAt: matchStartedAt ?? Date(),
            completedAt: isGameOver ? matchCompletedAt : nil,
            participants: buildParticipants()
        )
        matchModel.hydrate(from: match, context: context)
        matchModel.isGameNight = isGameNight
    }

    /// Restores match state from a persisted MatchModel in-place, preserving view identity.
    func load(from matchModel: MatchModel) {
        playerScores = []
        playerScoreTimestamps = []
        playerYatzyBonuses = []
        playerThemes = []
        playerDisplayNames = []
        playerDisplayInitials = []
        playerIDs = []
        participantIDs = []
        slotIDs = []

        persistedMatchID = matchModel.id
        isGameNight = matchModel.isGameNight
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
            playerYatzyBonuses.append(p.bonusPoints)
            playerThemes.append(themeType)
            playerDisplayNames.append(p.displayName)
            playerDisplayInitials.append(p.displayInitials)
            playerIDs.append(p.playerID)
            participantIDs.append(p.id)
            slotIDs.append(UUID())
            let timestamps: [YatzyCategory: Date] = Dictionary(
                uniqueKeysWithValues: p.scoreEntries.compactMap { entry in
                    guard let cat = YatzyCategory(rawValue: entry.slotKey),
                          let at = entry.recordedAt else { return nil }
                    return (cat, at)
                }
            )
            playerScoreTimestamps.append(timestamps)
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

    /// Severs the link between in-memory state and the current SwiftData row so the next
    /// save() creates a fresh record. Call before loadFromGameNightMatch() when starting a
    /// brand-new match (rematch) — not when reconnecting to the same ongoing game.
    func clearPersistedMatchBinding() {
        persistedMatchID = nil
        matchStartedAt = nil
    }

    /// Deletes the current in-progress match record. Call before resetGame() when the user
    /// explicitly discards a game. Completed games are never deleted here.
    func abandonMatch(in context: ModelContext) {
        guard let mid = persistedMatchID else { return }
        let descriptor = FetchDescriptor<MatchModel>(predicate: #Predicate { $0.id == mid })
        if let match = (try? context.fetch(descriptor))?.first, !isGameOver {
            context.delete(match)
        }
        try? context.save()
        persistedMatchID = nil
        isGameNight = false
        matchStartedAt = nil
        matchCompletedAt = nil
    }

    func setTheme(_ theme: Theme.ThemeType, for playerIndex: Int) {
        guard canEditPlayers, playerThemes.indices.contains(playerIndex) else { return }
        playerThemes[playerIndex] = theme
    }

    /// Propagates current PlayerModel theme colors into playerThemes[]. Only runs before
    /// the game starts so in-progress matches are not silently recolored mid-game.
    func syncPlayerThemes(from players: [PlayerModel]) {
        guard canEditPlayers else { return }
        for i in playerIDs.indices {
            guard let playerID = playerIDs[i],
                  let player = players.first(where: { $0.id == playerID }),
                  let themeType = Theme.ThemeType(rawValue: player.themeID),
                  playerThemes.indices.contains(i),
                  playerThemes[i] != themeType else { continue }
            playerThemes[i] = themeType
        }
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
        onRollStarted?()
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
            playerYatzyBonuses: playerYatzyBonuses,
            playerScoreTimestamps: playerScoreTimestamps,
            currentPlayerIndex: currentPlayerIndex,
            isRolling: isRolling
        )
        let scoringPlayerName = currentPlayerName
        let scoringPlayerIndex = currentPlayerIndex
        let previousLeaderIndices = leaderIndices
        let hadUpperBonus = upperBonus(for: currentPlayerIndex) > 0
        let earnedBonus = qualifiesForExtraYatzyBonus(dice: diceValues, scorecard: yatzyScorecard(for: currentPlayerIndex))
        if earnedBonus {
            playerYatzyBonuses[currentPlayerIndex] += 100
        }
        let scoreVal = scoreValue(for: category, playerIndex: currentPlayerIndex)
        let capturedDice = diceValues
        playerScores[currentPlayerIndex][category] = scoreVal
        playerScoreTimestamps[currentPlayerIndex][category] = Date()
        let gameJustEnded = isGameOver
        if !gameJustEnded { beginNextTurn() }
        if let sink = commentaryEventSink {
            emitCommentaryEvent(sink: sink, category: category, scoreVal: scoreVal,
                                scoringPlayerIndex: scoringPlayerIndex,
                                scoringPlayerName: scoringPlayerName,
                                previousLeaderIndices: previousLeaderIndices,
                                hadUpperBonus: hadUpperBonus,
                                earnedBonus: earnedBonus,
                                gameJustEnded: gameJustEnded)
        }
        onScoreApplied?(category, capturedDice)
        if !hadUpperBonus && upperBonus(for: scoringPlayerIndex) > 0 {
            onUpperBonusEarned?(scoringPlayerIndex)
        }
        if playerCount > 1 && !gameJustEnded {
            onScoreAnnounced?(scoringPlayerIndex, category, scoreVal)
        }
    }

    @discardableResult
    func undoLastScore() -> UndoRestoration? {
        guard let snapshot = lastScoreSnapshot else { return nil }
        diceValues = snapshot.diceValues
        held = snapshot.held
        rollsRemaining = snapshot.rollsRemaining
        playerScores = snapshot.playerScores
        playerYatzyBonuses = snapshot.playerYatzyBonuses
        playerScoreTimestamps = snapshot.playerScoreTimestamps
        currentPlayerIndex = snapshot.currentPlayerIndex
        isRolling = snapshot.isRolling
        lastScoreSnapshot = nil
        onUndone?()
        return UndoRestoration(diceValues: snapshot.diceValues, held: snapshot.held)
    }

    /// Called on guest devices after receiving an undo matchState broadcast.
    /// Overwrites the values that `loadFromGameNightMatch` reset, so the guest
    /// can see their pre-scoring dice and rescore without re-rolling.
    func restoreDiceStateAfterUndo(values: [Int], rollsRemaining: Int) {
        diceValues = values
        self.rollsRemaining = rollsRemaining
    }

    func suggestedScores(for playerIndex: Int) -> [YatzyCategory: Int] {
        guard playerScores.indices.contains(playerIndex) else { return [:] }
        return legalScoreCategories(for: playerIndex).reduce(into: [:]) { result, category in
            result[category] = scoreValue(for: category, playerIndex: playerIndex)
        }
    }

    /// Returns the highest-value legal scoring category for the current player.
    /// Returns nil when it is not this player's turn, before the first roll, or when no categories are available.
    func suggestedCategory(for playerIndex: Int) -> YatzyCategory? {
        guard playerIndex == currentPlayerIndex, canScore else { return nil }
        let scores = suggestedScores(for: playerIndex)
        guard let best = scores.max(by: { $0.value < $1.value }) else { return nil }
        if lastLoggedSuggestion != best.key {
            lastLoggedSuggestion = best.key
            logger.debug(self, "Suggested: \(best.key.displayName) (\(best.value)pts) for player \(playerIndex)")
        }
        return best.key
    }

    func yatzyBonus(for playerIndex: Int) -> Int {
        guard playerYatzyBonuses.indices.contains(playerIndex) else { return 0 }
        return playerYatzyBonuses[playerIndex]
    }

    // MARK: - Private

    private func buildParticipants() -> [Participant] {
        (0..<playerCount).map { i in
            let entries = playerScores[i].map { (cat, val) in
                ScoreEntry(slotKey: cat.slotKey, value: Decimal(val), metadata: nil,
                           recordedAt: playerScoreTimestamps[i][cat])
            }
            return Participant(
                id: participantIDs[i],
                seat: i,
                finalScore: Decimal(totalScore(for: i)),
                rank: isGameOver ? computeRank(for: i) : 0,
                bonusPoints: playerYatzyBonuses[i],
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
        lastLoggedSuggestion = nil
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

    private func emitCommentaryEvent(
        sink: (CommentaryEvent) -> Void,
        category: YatzyCategory,
        scoreVal: Int,
        scoringPlayerIndex: Int,
        scoringPlayerName: String,
        previousLeaderIndices: [Int],
        hadUpperBonus: Bool,
        earnedBonus: Bool,
        gameJustEnded: Bool
    ) {
        if gameJustEnded {
            guard let winScore = (0..<playerCount).map({ totalScore(for: $0) }).max() else { return }
            let winners = winnerIndices
            if winners.count == 1, let w = winners.first {
                let others = (0..<playerCount)
                    .filter { $0 != w }
                    .sorted { totalScore(for: $0) > totalScore(for: $1) }
                let secondScore = others.first.map { totalScore(for: $0) } ?? 0
                sink(CommentaryEvent(kind: .winnerDeclared,
                                     winner: playerDisplayNames[w],
                                     runnerUp: others.first.map { playerDisplayNames[$0] },
                                     score: winScore,
                                     margin: winScore - secondScore))
            } else {
                let names = winners.map { playerDisplayNames[$0] }.joined(separator: ", ")
                sink(CommentaryEvent(kind: .winnerTie, winner: names, score: winScore))
            }
            return
        }
        // Primary event for this scoring action
        if earnedBonus {
            sink(CommentaryEvent(kind: .yatzyBonusEarned, player: scoringPlayerName))
        } else if category == .yatzy && scoreVal == 50 {
            sink(CommentaryEvent(kind: .yatzyRolled, player: scoringPlayerName))
        } else if category == .yatzy && scoreVal == 0 {
            sink(CommentaryEvent(kind: .yatzyScratched, player: scoringPlayerName))
        } else if scoreVal == 0 {
            sink(CommentaryEvent(kind: .categoryScratched, player: scoringPlayerName, category: category.displayName))
        } else if scoreVal >= 25 {
            sink(CommentaryEvent(kind: .bigTurn, player: scoringPlayerName, category: category.displayName, value: scoreVal))
        } else {
            sink(CommentaryEvent(kind: .categoryScored, player: scoringPlayerName, category: category.displayName, value: scoreVal))
        }
        // Upper bonus just earned this turn
        if !hadUpperBonus && upperBonus(for: scoringPlayerIndex) > 0 {
            sink(CommentaryEvent(kind: .upperBonusEarned, player: scoringPlayerName))
        }
        // Lead change (sole new leader different from before)
        let newLeaders = leaderIndices
        if newLeaders.count == 1 && newLeaders != previousLeaderIndices, let leader = newLeaders.first {
            let byScore = (0..<playerCount).sorted { totalScore(for: $0) > totalScore(for: $1) }
            let runnerUpIdx = byScore.first { $0 != leader }
            sink(CommentaryEvent(kind: .leadChange,
                                 runnerUp: runnerUpIdx.map { playerDisplayNames[$0] },
                                 leader: playerDisplayNames[leader]))
        }
        // Turn start for the next player
        sink(CommentaryEvent(kind: .turnStart, player: currentPlayerName))
    }

    static func defaultTheme(for index: Int) -> Theme.ThemeType {
        let order: [Theme.ThemeType] = [
            .midnight, .blossom, .ember, .forest, .ocean, .sunset, .paper
        ]
        return order[index % order.count]
    }

    // MARK: - Game Night hooks

    /// Fires after every successful `score()` application, carrying the scored
    /// category and the dice values that were live at scoring time.
    /// GameNightController wires this: host → broadcastMatchState; guest → proposeScore.
    var onScoreApplied: ((YatzyCategory, [Int]) -> Void)?

    /// Fires after a successful `undoLastScore()`.
    /// GameNightController wires this: host → broadcastMatchState; guest → proposeUndo.
    var onUndone: (() -> Void)?

    /// Fires when `beginRoll()` succeeds.
    /// GameNightController wires this on the host to close the undo window.
    var onRollStarted: (() -> Void)?

    /// Fires from `score()` when a non-Yatzy score is applied in a multi-player game,
    /// before `beginNextTurn()` — carrying the scorer's index at time of scoring.
    /// ContentView wires this to the score announcement banner.
    var onScoreAnnounced: ((Int, YatzyCategory, Int) -> Void)?

    /// Fires from `score()` the moment the upper section bonus (35 pts) is first earned.
    /// ContentView wires this to the upper bonus celebration card.
    var onUpperBonusEarned: ((Int) -> Void)?

    // MARK: - Game Night state loading

    /// Replaces all match state from a Game Night wire snapshot. Used by:
    ///  • Host: initialise from the `matchStart` payload, preserving participantIDs.
    ///  • All devices: apply an incoming `matchState` (authoritative; guests never argue).
    /// Transient dice state is not on the wire and is reset to a fresh-turn baseline.
    func loadFromGameNightMatch(_ match: Match, currentSeatIndex: Int) {
        let sorted = match.participants.sorted(by: { $0.seat < $1.seat })

        playerScores = sorted.map { p in
            Dictionary(uniqueKeysWithValues: p.scoreEntries.compactMap { entry -> (YatzyCategory, Int)? in
                guard let cat = YatzyCategory(rawValue: entry.slotKey),
                      let val = entry.value else { return nil }
                return (cat, NSDecimalNumber(decimal: val).intValue)
            })
        }
        playerScoreTimestamps = sorted.map { _ in [:] }
        playerYatzyBonuses = sorted.map { $0.bonusPoints }
        playerThemes = sorted.map { Theme.ThemeType(rawValue: $0.displayThemeID) ?? .midnight }
        playerDisplayNames = sorted.map { $0.displayName }
        playerDisplayInitials = sorted.map { $0.displayInitials }
        playerIDs = sorted.map { $0.playerID }
        participantIDs = sorted.map { $0.id }

        // Keep slotIDs stable for view identity; rebuild only on count change.
        if slotIDs.count != sorted.count {
            slotIDs = sorted.map { _ in UUID() }
        }

        currentPlayerIndex = currentSeatIndex
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        isRolling = false
        // Bind to the wire UUID on first load so save() creates the row with the correct ID.
        // If persistedMatchID is already set (reconnect or subsequent matchState), leave it alone —
        // the row was already created for this game and the reference is still valid.
        if persistedMatchID == nil {
            persistedMatchID = match.id
        }
        matchStartedAt = match.startedAt
        isGameNight = true
        clearUndoState()
    }

    /// Like `loadFromGameNightMatch` but restores the undo snapshot afterward.
    /// Used on guest devices to keep the undo button alive through the host's echo.
    func loadFromGameNightMatchPreservingUndo(_ match: Match, currentSeatIndex: Int) {
        let saved = lastScoreSnapshot
        loadFromGameNightMatch(match, currentSeatIndex: currentSeatIndex)
        lastScoreSnapshot = saved
    }

    /// Clears the undo snapshot from outside MatchController.
    /// Called when another player begins rolling, closing the undo window on all devices.
    func clearUndoSnapshot() { clearUndoState() }

    // MARK: - Game Night host scoring

    /// Host-side: apply a guest's score using their reported dice values.
    /// Temporarily loads the remote dice so Layer 1's pure scoring functions
    /// (`legalScoreCategories`, `scoreValue`, `qualifiesForExtraYatzyBonus`)
    /// all see the correct state. Fires `onScoreApplied` on success.
    func applyRemoteScore(category: YatzyCategory, remoteValues: [Int], forParticipantID participantID: UUID) {
        guard let index = participantIDs.firstIndex(of: participantID),
              index == currentPlayerIndex else { return }
        let previousDice = diceValues
        let previousHeld = held
        diceValues = remoteValues
        held = Array(repeating: false, count: remoteValues.count)
        score(category: category)   // fires onScoreApplied if the category was legal
        // If score() didn't apply, restore dice state.
        if playerScores[index][category] == nil {
            diceValues = previousDice
            held = previousHeld
        }
    }

    // MARK: - Game Night match snapshot

    /// Builds a wire `Match` value from the current in-memory state.
    /// Called by the host to produce a `matchState` payload after every mutation.
    func buildMatchSnapshot(matchID: UUID, gameID: UUID) -> Match {
        Match(
            id: matchID,
            gameID: gameID,
            scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1,
            status: isGameOver ? .completed : .inProgress,
            startedAt: matchStartedAt ?? Date(),
            completedAt: isGameOver ? (matchCompletedAt ?? Date()) : nil,
            participants: buildParticipants()
        )
    }

#if DEBUG
    func seedScoresForPreview(_ scores: [YatzyCategory: Int], forPlayerIndex index: Int) {
        guard playerScores.indices.contains(index) else { return }
        playerScores[index] = scores
    }
#endif
}
