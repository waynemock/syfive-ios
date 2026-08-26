import Foundation
import SyLibScoring

struct PlayerInsights: Sendable {
    var playerID:     UUID
    var matchesPlayed: Int
    var consistency:  ConsistencyProfile?
    var proficiency:  Proficiency?
    var style:        StyleSignature?
    var risk:         RiskProfile?
    var clutch:       ClutchProfile?
}

func playerInsights(playerID: UUID, matches: [Match]) -> PlayerInsights? {
    let sorted = matches
        .filter { $0.status == .completed && $0.participants.contains { $0.playerID == playerID } }
        .sorted { $0.startedAt < $1.startedAt }
    guard !sorted.isEmpty else { return nil }
    return PlayerInsights(
        playerID:     playerID,
        matchesPlayed: sorted.count,
        consistency:  consistencyProfile(playerID: playerID, matches: sorted),
        proficiency:  proficiency(playerID: playerID, matches: sorted),
        style:        styleSignature(playerID: playerID, matches: sorted),
        risk:         riskProfile(playerID: playerID, matches: sorted),
        clutch:       clutchProfile(playerID: playerID, matches: sorted)
    )
}

// Composes a neutral-to-affirming plain-language read.
// Per §6, sentence generation is first-pass — thresholds may need calibration
// once real player distributions are available.
// Returns nil if there are fewer than 3 games (insufficient for a reliable read).
func plainLanguageRead(_ insights: PlayerInsights) -> String? {
    guard insights.matchesPlayed >= 3 else { return nil }

    var parts: [String] = []

    // 1. Identity + bonus approach (from style)
    if let style = insights.style {
        let noun: String
        switch style.sectionOrder {
        case .upperFirst: noun = "an upper-section specialist"
        case .lowerFirst: noun = "a lower-section player"
        case .balanced:   noun = "a balanced all-around player"
        }
        let bonus: String
        switch style.bonusApproach {
        case .lockEarly: bonus = "who locks the upper bonus early"
        case .backfill:  bonus = "who backfills the upper section"
        case .neglect:   bonus = "who plays for the lower section"
        }
        parts.append("\(noun) \(bonus)")
    } else {
        parts.append("a steady player")
    }

    // 2. Risk appetite
    if let risk = insights.risk {
        if risk.yatzyEverZeroed && risk.yatzyZeroRate > 0.25 {
            parts.append("takes big swings on Yatzy")
        } else if risk.totalScratchRate < 0.04 {
            parts.append("rarely scratches")
        } else if risk.earlyZeroRate > 0.7 && risk.totalScratchRate > 0.04 {
            parts.append("zeroes early when needed")
        }
    }

    // 3. Closing strength
    if let clutch = insights.clutch, clutch.matchesAnalyzed >= 3 {
        if clutch.backHalfVsFront > 2 {
            parts.append("closes strong")
        } else if clutch.backHalfVsFront < -2 {
            parts.append("builds dominant early leads")
        }
    }

    // Assemble: "An upper-section specialist..., rarely scratches, and closes strong."
    guard parts.count >= 1 else { return nil }
    let first = parts[0].capitalizedFirstLetter
    if parts.count == 1 { return "\(first)." }
    if parts.count == 2 { return "\(first) \(parts[1])." }
    let middle = parts[1..<parts.count - 1].joined(separator: ", ")
    let last   = parts[parts.count - 1]
    return "\(first) \(middle), and \(last)."
}

private extension String {
    var capitalizedFirstLetter: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
}
