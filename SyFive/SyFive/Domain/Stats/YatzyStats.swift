import Foundation
import SyLibScoring

// Yatzy and bonus statistics for one player across completed matches.
// Reads yatzyBonus (denormalized on Participant) and the Yatzy category entry.

struct YatzyStats: Sendable {
    var yatzyHitRate: Double        // matches where Yatzy box == 50 / total matches
    var careerYatzyCount: Int       // sum of (box-50 hits) + (yatzyBonus / 100) over career
    var multiYatzyMatches: Int      // matches where yatzyBonus > 0 (at least one bonus Yatzy)
    var mostYatziesInOneMatch: Int  // max(boxHit + yatzyBonus/100) in any single match
    var averageChance: Decimal      // avg Chance score — a raw dice-quality proxy
}

// Computes Yatzy-specific stats for playerID across the provided matches.
// Returns nil if the player appears in none of the matches.
func yatzyStats(playerID: UUID, matches: [Match]) -> YatzyStats? {
    let participants = matches.compactMap { match in
        match.participants.first(where: { $0.playerID == playerID })
    }
    guard !participants.isEmpty else { return nil }

    var yatzyHits      = 0
    var careerCount    = 0
    var multiMatches   = 0
    var mostInMatch    = 0
    var totalChance    = Decimal(0)
    var chanceCount    = 0

    for p in participants {
        // Yatzy box: scored 50 = hit, 0 = scratch, nil = shouldn't exist in completed match.
        let yatzyValue = p.scoreEntries.first { $0.slotKey == YatzyCategory.yatzy.slotKey }?.value
        let boxHit       = yatzyValue == Decimal(50) ? 1 : 0
        let bonusHits    = p.bonusPoints / 100

        yatzyHits   += boxHit
        careerCount += boxHit + bonusHits
        if bonusHits > 0 { multiMatches += 1 }

        let matchTotal = boxHit + bonusHits
        if matchTotal > mostInMatch { mostInMatch = matchTotal }

        if let chanceValue = p.scoreEntries
            .first(where: { $0.slotKey == YatzyCategory.chance.slotKey })?.value {
            totalChance += chanceValue
            chanceCount += 1
        }
    }

    let count = participants.count
    return YatzyStats(
        yatzyHitRate: Double(yatzyHits) / Double(count),
        careerYatzyCount: careerCount,
        multiYatzyMatches: multiMatches,
        mostYatziesInOneMatch: mostInMatch,
        averageChance: chanceCount > 0 ? totalChance / Decimal(chanceCount) : 0
    )
}
