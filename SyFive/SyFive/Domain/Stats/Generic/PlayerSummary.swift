import Foundation

// Per-player summary across a set of completed matches.
// Input must be pre-filtered to .completed; the function is pure and does no filtering.

struct PlayerSummary: Sendable {
    var playerID: UUID
    var matchesPlayed: Int
    var wins: Int                           // sole rank-1 finishes (ties excluded)
    var winRate: Double                     // wins / matchesPlayed
    var podiumRate: Double                  // rank ≤ 3 finishes / matchesPlayed
    var placementDistribution: [Int: Int]   // rank → count
    var averageScore: Decimal
    var bestScore: Decimal
    var worstScore: Decimal
    var medianScore: Decimal
    var averageRank: Double
    var averageMarginToWinner: Decimal      // winner.finalScore − this.finalScore; 0 for wins and ties
    var firstPlayed: Date?
    var lastPlayed: Date?
    // Order-dependent — input must be sorted by startedAt.
    var currentStreak: Int                  // +N = N consecutive wins, −N = N consecutive losses
    var bestWinStreak: Int
    var worstLossStreak: Int                // stored as positive magnitude
}

// Computes a PlayerSummary for playerID across the provided matches.
// Matches must be .completed and sorted by startedAt (ascending) for
// streak calculations to be correct. Returns nil if the player appears
// in none of the matches.
func playerSummary(playerID: UUID, matches: [Match]) -> PlayerSummary? {
    typealias Entry = (match: Match, participant: Participant)
    let entries: [Entry] = matches.compactMap { match in
        guard let p = match.participants.first(where: { $0.playerID == playerID })
        else { return nil }
        return (match, p)
    }
    guard !entries.isEmpty else { return nil }

    let count = entries.count
    let scores = entries.map { $0.participant.finalScore }
    let ranks  = entries.map { $0.participant.rank }

    // -- Placement --
    var placementDist: [Int: Int] = [:]
    for rank in ranks { placementDist[rank, default: 0] += 1 }

    let wins = entries.filter { (match, participant) in
        participant.rank == 1 &&
        !match.participants.contains { $0.id != participant.id && $0.rank == 1 }
    }.count

    // -- Scores --
    let sortedScores = scores.sorted()
    let bestScore    = sortedScores.last!
    let worstScore   = sortedScores.first!
    let totalScore   = scores.reduce(Decimal(0), +)
    let averageScore = totalScore / Decimal(count)

    let medianScore: Decimal = {
        if count % 2 == 1 { return sortedScores[count / 2] }
        return (sortedScores[count / 2 - 1] + sortedScores[count / 2]) / 2
    }()

    // -- Rank averages --
    let avgRank = Double(ranks.reduce(0, +)) / Double(count)
    let podiumCount = ranks.filter { $0 <= 3 }.count
    let podiumRate  = Double(podiumCount) / Double(count)

    // -- Margin to winner --
    // For rank=1 participants (including ties), margin is 0.
    let totalMargin = entries.reduce(Decimal(0)) { acc, entry in
        guard entry.participant.rank > 1 else { return acc }
        let winnerScore = entry.match.participants
            .filter { $0.rank == 1 }
            .map    { $0.finalScore }
            .max() ?? entry.participant.finalScore
        return acc + (winnerScore - entry.participant.finalScore)
    }
    let avgMargin = totalMargin / Decimal(count)

    // -- Dates (entries sorted by startedAt) --
    let sorted      = entries.sorted { $0.match.startedAt < $1.match.startedAt }
    let firstPlayed = sorted.first?.match.startedAt
    let lastPlayed  = sorted.last?.match.startedAt

    // -- Streaks --
    let outcomes = sorted.map { matchOutcome(for: $0.participant, in: $0.match) }
    let streaks  = streakStats(from: outcomes)

    return PlayerSummary(
        playerID: playerID,
        matchesPlayed: count,
        wins: wins,
        winRate: Double(wins) / Double(count),
        podiumRate: podiumRate,
        placementDistribution: placementDist,
        averageScore: averageScore,
        bestScore: bestScore,
        worstScore: worstScore,
        medianScore: medianScore,
        averageRank: avgRank,
        averageMarginToWinner: avgMargin,
        firstPlayed: firstPlayed,
        lastPlayed: lastPlayed,
        currentStreak: streaks.current,
        bestWinStreak: streaks.bestWin,
        worstLossStreak: streaks.worstLoss
    )
}
