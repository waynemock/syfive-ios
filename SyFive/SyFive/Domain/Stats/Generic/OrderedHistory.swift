import Foundation

// Substrate for all order-dependent stats (streaks, trends, Elo replay).
// Write once; reused by PlayerSummary, HeadToHead, and future Elo.
//
// Input matches must be .completed — callers are responsible for filtering.

// MARK: - Types

// A single match result from one player's perspective.
enum MatchOutcome: Sendable, Equatable {
    case win    // rank == 1, sole winner
    case tie    // rank == 1, co-winner (shared with ≥1 other participant)
    case loss   // rank > 1
}

// MARK: - Functions

// Returns (match, outcome) pairs for playerID, sorted chronologically.
// Matches where playerID is not a participant are silently skipped.
func orderedHistory(playerID: UUID, matches: [Match]) -> [(match: Match, outcome: MatchOutcome)] {
    matches
        .sorted { $0.startedAt < $1.startedAt }
        .compactMap { match -> (Match, MatchOutcome)? in
            guard let p = match.participants.first(where: { $0.playerID == playerID })
            else { return nil }
            return (match, matchOutcome(for: p, in: match))
        }
}

// Folds an ordered outcome sequence into streak statistics.
//   current:   +N = N consecutive wins, -N = N consecutive losses, 0 = last was a tie
//   bestWin:   longest consecutive win run (always ≥ 0)
//   worstLoss: longest consecutive loss run stored as positive magnitude
// Ties reset the running streak to 0.
func streakStats(
    from outcomes: [MatchOutcome]
) -> (current: Int, bestWin: Int, worstLoss: Int) {
    var current = 0, bestWin = 0, worstLoss = 0
    for outcome in outcomes {
        switch outcome {
        case .win:  current = current > 0 ? current + 1 : 1
        case .loss: current = current < 0 ? current - 1 : -1
        case .tie:  current = 0
        }
        if current > bestWin     { bestWin   = current }
        if -current > worstLoss  { worstLoss = -current }
    }
    return (current, bestWin, worstLoss)
}

// Resolves one participant's outcome within their match.
func matchOutcome(for participant: Participant, in match: Match) -> MatchOutcome {
    guard participant.rank == 1 else { return .loss }
    let hasCoWinner = match.participants.contains { $0.id != participant.id && $0.rank == 1 }
    return hasCoWinner ? .tie : .win
}
