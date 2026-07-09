import Foundation

// All-time records for one game definition. All entries use rank + finalScore
// only — no scorecard semantics — so this is fully generic (Tier 1).
// Yatzy-specific records (mostYatziesInOneMatch etc.) live in Tier 2.

struct RecordsBoard: Sendable {
    var gameID: UUID
    var allTimeHigh: RecordEntry?
    var highestLosingScore: RecordEntry?    // best score among rank > 1 participants
    var lowestWinningScore: RecordEntry?    // worst score among sole rank-1 winners
    var biggestBlowout: BlowoutEntry?       // largest winner − runner-up margin
    var narrowestWin: BlowoutEntry?         // smallest winner − runner-up margin
}

struct RecordEntry: Sendable {
    var playerID: UUID
    var score: Decimal
    var matchID: UUID
}

struct BlowoutEntry: Sendable {
    var matchID: UUID
    var margin: Decimal                     // winner.finalScore − runner-up.finalScore
}

// Computes the records board for a given game across all provided completed matches.
// Input must already be filtered to .completed; gameID filtering is applied internally
// so a caller can safely pass their full completed-match list.
func recordsBoard(gameID: UUID, matches: [Match]) -> RecordsBoard {
    let gameMatches = matches.filter { $0.gameID == gameID }

    var allTimeHigh: RecordEntry? = nil
    var highestLosingScore: RecordEntry? = nil
    var lowestWinningScore: RecordEntry? = nil
    var biggestBlowout: BlowoutEntry? = nil
    var narrowestWin: BlowoutEntry? = nil

    for match in gameMatches {
        for p in match.participants {
            guard let pID = p.playerID else { continue }

            // All-time high (any participant, any rank).
            if allTimeHigh == nil || p.finalScore > allTimeHigh!.score {
                allTimeHigh = RecordEntry(playerID: pID, score: p.finalScore, matchID: match.id)
            }

            // Highest losing score — rank > 1 only.
            if p.rank > 1 {
                if highestLosingScore == nil || p.finalScore > highestLosingScore!.score {
                    highestLosingScore = RecordEntry(playerID: pID, score: p.finalScore, matchID: match.id)
                }
            }
        }

        // Blowout / narrowest and lowest winning score:
        // Only computed for matches with exactly one rank-1 winner.
        let winners   = match.participants.filter { $0.rank == 1 }
        let runnerUps = match.participants.filter { $0.rank == 2 }

        guard winners.count == 1,
              let winner = winners.first,
              let wID = winner.playerID,
              let runnerUp = runnerUps.max(by: { $0.finalScore < $1.finalScore })
        else { continue }

        // Lowest winning score.
        if lowestWinningScore == nil || winner.finalScore < lowestWinningScore!.score {
            lowestWinningScore = RecordEntry(playerID: wID, score: winner.finalScore, matchID: match.id)
        }

        // Blowout margin = winner − best runner-up.
        let margin = winner.finalScore - runnerUp.finalScore
        if biggestBlowout == nil || margin > biggestBlowout!.margin {
            biggestBlowout = BlowoutEntry(matchID: match.id, margin: margin)
        }
        if narrowestWin == nil || margin < narrowestWin!.margin {
            narrowestWin = BlowoutEntry(matchID: match.id, margin: margin)
        }
    }

    return RecordsBoard(
        gameID: gameID,
        allTimeHigh: allTimeHigh,
        highestLosingScore: highestLosingScore,
        lowestWinningScore: lowestWinningScore,
        biggestBlowout: biggestBlowout,
        narrowestWin: narrowestWin
    )
}
