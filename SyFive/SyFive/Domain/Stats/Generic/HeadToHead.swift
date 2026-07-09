import Foundation

// Head-to-head record between two players across completed shared matches.
// The "signature moment": shown on the pre-game card before a match starts.

struct HeadToHead: Sendable {
    var playerA: UUID
    var playerB: UUID
    var sharedMatches: Int                  // completed matches both participated in

    // HEADLINE — who won the match outright
    var matchWinsA: Int                     // A sole rank-1 wins
    var matchWinsB: Int                     // B sole rank-1 wins
    var sharedTies: Int                     // both share rank 1

    // SECOND LINE — who placed higher (relevant in 3+ player games)
    var pairwiseAheadA: Int                 // A rank < B rank
    var pairwiseAheadB: Int                 // B rank < A rank
    var pairwiseTies: Int                   // equal rank

    var averageScoreA: Decimal              // A's avg finalScore in shared matches
    var averageScoreB: Decimal              // B's avg finalScore in shared matches
    var lastMeeting: Date?
    var currentStreakA: Int                 // A's H2H streak vs B (+win / −loss)
}

// Computes the head-to-head record between playerA and playerB.
// Considers every completed match where both participated. Input must be
// sorted by startedAt for currentStreakA to be correct.
func headToHead(playerA: UUID, playerB: UUID, matches: [Match]) -> HeadToHead {
    let shared = matches
        .filter { m in
            m.participants.contains { $0.playerID == playerA } &&
            m.participants.contains { $0.playerID == playerB }
        }
        .sorted { $0.startedAt < $1.startedAt }

    var matchWinsA = 0, matchWinsB = 0, sharedTies = 0
    var pairwiseAheadA = 0, pairwiseAheadB = 0, pairwiseTies = 0
    var totalA = Decimal(0), totalB = Decimal(0)
    var h2hOutcomes: [MatchOutcome] = []

    for match in shared {
        guard
            let partA = match.participants.first(where: { $0.playerID == playerA }),
            let partB = match.participants.first(where: { $0.playerID == playerB })
        else { continue }

        totalA += partA.finalScore
        totalB += partB.finalScore

        // Match-win determination (A's perspective for streak).
        if partA.rank == 1 && partB.rank > 1 {
            matchWinsA += 1
            h2hOutcomes.append(.win)
        } else if partB.rank == 1 && partA.rank > 1 {
            matchWinsB += 1
            h2hOutcomes.append(.loss)
        } else if partA.rank == 1 && partB.rank == 1 {
            // Tied at rank 1 — credited to neither's win column.
            sharedTies += 1
            h2hOutcomes.append(.tie)
        } else {
            // Both rank > 1 (third player won) — no match win for either,
            // treat as neutral for the H2H streak.
            h2hOutcomes.append(.tie)
        }

        // Pairwise placement.
        if partA.rank < partB.rank       { pairwiseAheadA += 1 }
        else if partA.rank > partB.rank  { pairwiseAheadB += 1 }
        else                             { pairwiseTies   += 1 }
    }

    let count   = shared.count
    let streaks = streakStats(from: h2hOutcomes)

    return HeadToHead(
        playerA: playerA,
        playerB: playerB,
        sharedMatches: count,
        matchWinsA: matchWinsA,
        matchWinsB: matchWinsB,
        sharedTies: sharedTies,
        pairwiseAheadA: pairwiseAheadA,
        pairwiseAheadB: pairwiseAheadB,
        pairwiseTies: pairwiseTies,
        averageScoreA: count > 0 ? totalA / Decimal(count) : 0,
        averageScoreB: count > 0 ? totalB / Decimal(count) : 0,
        lastMeeting: shared.last?.startedAt,
        currentStreakA: streaks.current
    )
}
