import Foundation

// Tier 1 concept (game-agnostic analysis on a score series), Tier 2 implementation
// because the progression replay calls YatzyScoring. Refactor to Tier 1 once
// ProgressionStep.category is made game-agnostic.
struct ClutchProfile: Sendable {
    var backHalfVsFront:  Decimal   // avg (back-6 pts/turn − front-7 pts/turn); >0 = closer
    var comebacksWon:     Int       // matches won after trailing by ≥ threshold mid-game
    var leadsSurrendered: Int       // matches lost while leading at own mid-game step
    var matchesAnalyzed:  Int       // matches with full timestamp data
}

private let comebackThreshold = Decimal(15)

func clutchProfile(playerID: UUID, matches: [Match]) -> ClutchProfile? {
    let completed = matches.filter { $0.status == .completed }
    guard !completed.isEmpty else { return nil }

    var backHalfDeltas   = [Decimal]()
    var comebacksWon     = 0
    var leadsSurrendered = 0

    for match in completed {
        guard let participant = match.participants.first(where: { $0.playerID == playerID })
        else { continue }

        // Back-half vs front-half: sort this player's fills by timestamp.
        let sortedEntries = participant.scoreEntries
            .compactMap { entry -> (value: Decimal, at: Date)? in
                guard let v = entry.value, let t = entry.recordedAt else { return nil }
                return (v, t)
            }
            .sorted { $0.at < $1.at }

        guard sortedEntries.count == 13 else { continue }

        let frontRate = sortedEntries.prefix(7).map(\.value).reduce(.zero, +) / 7
        let backRate  = sortedEntries.suffix(6).map(\.value).reduce(.zero, +) / 6
        backHalfDeltas.append(backRate - frontRate)

        // Comebacks and surrendered leads from progression replay.
        guard let prog = matchProgression(from: match) else { continue }

        let isSoleWinner = participant.rank == 1 &&
            !match.participants.contains { $0.id != participant.id && $0.rank == 1 }

        if isSoleWinner, let deficit = prog.comebackFrom, deficit >= comebackThreshold {
            comebacksWon += 1
        }

        if !isSoleWinner,
           let playerProg = prog.participants.first(where: { $0.participantID == participant.id }),
           playerProg.points.count >= 7 {
            let midStep  = playerProg.points[6]
            let midTotal = midStep.runningTotal
            let othersAtMid = prog.participants
                .filter { $0.participantID != participant.id }
                .compactMap { $0.points.last(where: { $0.at <= midStep.at })?.runningTotal }
            if !othersAtMid.isEmpty && othersAtMid.allSatisfy({ midTotal > $0 }) {
                leadsSurrendered += 1
            }
        }
    }

    guard !backHalfDeltas.isEmpty else { return nil }

    return ClutchProfile(
        backHalfVsFront:  backHalfDeltas.reduce(.zero, +) / Decimal(backHalfDeltas.count),
        comebacksWon:     comebacksWon,
        leadsSurrendered: leadsSurrendered,
        matchesAnalyzed:  backHalfDeltas.count
    )
}
