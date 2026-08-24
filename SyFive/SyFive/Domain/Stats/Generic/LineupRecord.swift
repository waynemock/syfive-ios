import Foundation

// Statistics for a specific group of players who played together.
// Keyed on the sorted player ID set — {A,B,C} matches regardless of seat order.

struct LineupRecord: Sendable {
    var playerIDs: [UUID]               // sorted by uuidString — the canonical group key
    var timesPlayed: Int
    var winsByPlayer: [UUID: Int]       // sole rank-1 wins per player in this lineup
    var groupHighScore: Decimal         // best finalScore any member posted in any group match
}

// Returns the lineup record for exactly this set of players.
// Matches where the participant set differs (extra or missing players) are excluded.
// Returns nil if no completed matches exist for this exact lineup.
func lineupRecord(playerIDs: [UUID], matches: [Match]) -> LineupRecord? {
    let targetSet = Set(playerIDs)

    let matching = matches.filter { match in
        Set(match.participants.compactMap { $0.playerID }) == targetSet
    }
    guard !matching.isEmpty else { return nil }

    var winsByPlayer: [UUID: Int] = [:]
    var groupHighScore = Decimal(0)

    for match in matching {
        // Solo wins only — ties credited to neither.
        let rank1 = match.participants.filter { $0.rank == 1 }
        if rank1.count == 1, let wID = rank1.first?.playerID {
            winsByPlayer[wID, default: 0] += 1
        }

        for p in match.participants {
            if p.finalScore > groupHighScore { groupHighScore = p.finalScore }
        }
    }

    return LineupRecord(
        playerIDs: playerIDs.sorted { $0.uuidString < $1.uuidString },
        timesPlayed: matching.count,
        winsByPlayer: winsByPlayer,
        groupHighScore: groupHighScore
    )
}
