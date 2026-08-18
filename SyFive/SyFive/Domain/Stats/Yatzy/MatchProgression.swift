import Foundation

struct MatchProgression: Sendable {
    var matchID: UUID
    var participants: [ParticipantProgression]
    var leadChanges: Int
    var largestLead: (playerID: UUID, margin: Decimal)?
    var comebackFrom: Decimal?             // largest deficit the eventual winner overcame
}

struct ParticipantProgression: Sendable {
    var participantID: UUID
    var points: [ProgressionStep]          // chronological; maps directly to a race-chart line series
}

struct ProgressionStep: Sendable {
    var at: Date
    var category: YatzyCategory
    var runningTotal: Decimal
}

/// Replays a completed match's scorecard entries in `recordedAt` order, computing
/// per-participant running totals using the existing pure scoring functions at each step.
///
/// Returns `nil` if any `ScoreEntry` is missing a `recordedAt` timestamp — this is the
/// legacy-data signal. The caller should fall back to showing the final scorecard without
/// a progression chart. New matches (after `recordedAt` hardening) always replay cleanly.
func matchProgression(from match: Match) -> MatchProgression? {
    guard match.status == .completed, !match.participants.isEmpty else { return nil }

    // Reject if any entry is missing a timestamp.
    for p in match.participants {
        for entry in p.scoreEntries where entry.recordedAt == nil { return nil }
    }

    // Build per-participant sorted progression steps.
    var participantProgressions: [ParticipantProgression] = []

    for p in match.participants {
        let sortedEntries: [(YatzyCategory, Decimal, Date)] = p.scoreEntries
            .compactMap { entry in
                guard let cat = YatzyCategory(rawValue: entry.slotKey),
                      let val = entry.value,
                      let at  = entry.recordedAt else { return nil }
                return (cat, val, at)
            }
            .sorted { $0.2 < $1.2 }

        var partialScorecard: YatzyScorecard = [:]
        var steps: [ProgressionStep] = []

        for (cat, val, at) in sortedEntries {
            partialScorecard[cat] = val
            // Attribute the entire yatzyBonus from the moment the Yatzy box is filled —
            // the earliest we can credit it without per-bonus timestamps.
            let bonus = partialScorecard[.yatzy] != nil ? p.yatzyBonus : 0
            let total = Decimal(grandTotal(scorecard: partialScorecard, yatzyBonus: bonus))
            steps.append(ProgressionStep(at: at, category: cat, runningTotal: total))
        }

        participantProgressions.append(ParticipantProgression(participantID: p.id, points: steps))
    }

    // Build a global timeline for lead-change and record metrics.
    struct TimelinePoint {
        let at: Date
        let participantID: UUID
        let runningTotal: Decimal
    }

    let timeline: [TimelinePoint] = participantProgressions
        .flatMap { prog in
            prog.points.map { step in
                TimelinePoint(at: step.at, participantID: prog.participantID, runningTotal: step.runningTotal)
            }
        }
        .sorted { $0.at < $1.at }

    // Seed every participant at 0 before any scoring.
    var currentTotals: [UUID: Decimal] = Dictionary(
        uniqueKeysWithValues: participantProgressions.map { ($0.participantID, Decimal(0)) }
    )

    var prevSoleLeader: UUID? = nil
    var leadChanges = 0
    var largestLeadMargin: Decimal = 0
    var largestLeadParticipantID: UUID? = nil

    // Sole winner for comeback detection (nil for tied games).
    let soleWinners = match.participants.filter { $0.rank == 1 }
    let soleWinnerParticipantID: UUID? = soleWinners.count == 1 ? soleWinners[0].id : nil
    var winnerMaxDeficit: Decimal = 0

    for point in timeline {
        currentTotals[point.participantID] = point.runningTotal

        let maxTotal = currentTotals.values.max() ?? 0
        let leaders = currentTotals.filter { $0.value == maxTotal }.map { $0.key }
        let newSoleLeader: UUID? = leaders.count == 1 ? leaders[0] : nil

        // Count a change only when a *different* sole leader takes over.
        if let prev = prevSoleLeader, let new = newSoleLeader, prev != new {
            leadChanges += 1
        }
        prevSoleLeader = newSoleLeader

        // Largest lead: margin from leader to runner-up (sole-leader moments only).
        if let leader = newSoleLeader {
            let sortedTotals = currentTotals.values.sorted(by: >)
            if sortedTotals.count >= 2 {
                let margin = sortedTotals[0] - sortedTotals[1]
                if margin > largestLeadMargin {
                    largestLeadMargin = margin
                    largestLeadParticipantID = leader
                }
            }
        }

        // Comeback: track the winner's largest deficit at any point.
        if let winnerID = soleWinnerParticipantID {
            let winnerTotal  = currentTotals[winnerID] ?? 0
            let opponentMax  = currentTotals.filter { $0.key != winnerID }.values.max() ?? 0
            let deficit      = opponentMax - winnerTotal
            if deficit > winnerMaxDeficit { winnerMaxDeficit = deficit }
        }
    }

    // Resolve largest-lead participantID to a playerID (with participantID as fallback for anonymous players).
    let largestLead: (playerID: UUID, margin: Decimal)? = largestLeadParticipantID.flatMap { pid in
        guard largestLeadMargin > 0 else { return nil }
        let playerID = match.participants.first { $0.id == pid }?.playerID ?? pid
        return (playerID: playerID, margin: largestLeadMargin)
    }

    let comebackFrom: Decimal? = (soleWinnerParticipantID != nil && winnerMaxDeficit > 0)
        ? winnerMaxDeficit : nil

    return MatchProgression(
        matchID: match.id,
        participants: participantProgressions,
        leadChanges: leadChanges,
        largestLead: largestLead,
        comebackFrom: comebackFrom
    )
}
