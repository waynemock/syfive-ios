import Foundation

// Upper-section aggregate stats for one player across completed matches.
// Calls upperSubtotal() from YatzyScoring — Tier 2 per the architecture.

struct UpperSectionStats: Sendable {
    var averageUpperTotal: Decimal                    // mean upper subtotal per match
    var bonusRate: Double                             // fraction reaching the 63 threshold
    var averageByFace: [YatzyCategory: Decimal]       // avg per upper category
}

// Computes upper-section stats for playerID.
// Returns nil if the player appears in none of the matches or has no upper entries.
func upperSectionStats(playerID: UUID, matches: [Match]) -> UpperSectionStats? {
    let participants = matches.compactMap { match in
        match.participants.first(where: { $0.playerID == playerID })
    }
    guard !participants.isEmpty else { return nil }

    let upperCategories = YatzyCategory.allCases.filter { $0.isUpperSection }
    var bonusCount = 0
    var totalUpperScore = Decimal(0)
    var totalByFace: [YatzyCategory: Decimal] = [:]

    for participant in participants {
        let scorecard = yatzyScorecard(from: participant)
        let subtotal  = Decimal(upperSubtotal(scorecard: scorecard))
        totalUpperScore += subtotal
        if subtotal >= 63 { bonusCount += 1 }
        for category in upperCategories {
            totalByFace[category, default: 0] += scorecard[category] ?? 0
        }
    }

    let count = participants.count
    let avgByFace = upperCategories.reduce(into: [YatzyCategory: Decimal]()) { dict, cat in
        dict[cat] = totalByFace[cat, default: 0] / Decimal(count)
    }

    return UpperSectionStats(
        averageUpperTotal: totalUpperScore / Decimal(count),
        bonusRate: Double(bonusCount) / Double(count),
        averageByFace: avgByFace
    )
}

// Builds a YatzyScorecard from a participant's score entries.
// Used by Tier 2 stats to call the existing pure scoring functions.
// Entries with nil values or unrecognised slotKeys are silently skipped.
func yatzyScorecard(from participant: Participant) -> YatzyScorecard {
    participant.scoreEntries.reduce(into: YatzyScorecard()) { scorecard, entry in
        guard let category = YatzyCategory(rawValue: entry.slotKey),
              let value    = entry.value
        else { return }
        scorecard[category] = value
    }
}
