import Foundation
import SyLibScoring

struct RiskProfile: Sendable {
    var totalScratchRate:    Double          // zeros / total fills across all matches
    var earlyZeroRate:       Double          // zeros in first 7 turns / all zeros (timestamp matches only)
    var yatzyZeroRate:       Double          // fraction of Yatzy fills that were scratched
    var yatzyEverZeroed:     Bool
    var mostScratchedCategory: YatzyCategory?
    var matchesWithTimestamps: Int
}

func riskProfile(playerID: UUID, matches: [Match]) -> RiskProfile? {
    let completed = matches.filter { $0.status == .completed }
    guard !completed.isEmpty else { return nil }

    var totalFills  = 0
    var totalZeros  = 0
    var earlyZeros  = 0
    var timedZeros  = 0
    var scratchCount = [YatzyCategory: Int]()
    var yatzyFills  = 0
    var yatzyZeros  = 0
    var timestampMatches = 0

    for match in completed {
        guard let p = match.participants.first(where: { $0.playerID == playerID }) else { continue }

        for entry in p.scoreEntries {
            guard let value = entry.value else { continue }
            totalFills += 1
            if value == 0 {
                totalZeros += 1
                if let cat = YatzyCategory(rawValue: entry.slotKey) {
                    scratchCount[cat, default: 0] += 1
                }
            }
            if entry.slotKey == YatzyCategory.yatzy.slotKey {
                yatzyFills += 1
                if value == 0 { yatzyZeros += 1 }
            }
        }

        // Timing: only from matches where all entries have timestamps.
        let sortedByTime = p.scoreEntries
            .compactMap { entry -> (value: Decimal, at: Date)? in
                guard let v = entry.value, let t = entry.recordedAt else { return nil }
                return (v, t)
            }
            .sorted { $0.at < $1.at }

        guard sortedByTime.count == 13 else { continue }
        timestampMatches += 1

        for (i, entry) in sortedByTime.enumerated() where entry.value == 0 {
            timedZeros += 1
            if i < 7 { earlyZeros += 1 }
        }
    }

    guard totalFills > 0 else { return nil }

    return RiskProfile(
        totalScratchRate:    Double(totalZeros) / Double(totalFills),
        earlyZeroRate:       timedZeros > 0 ? Double(earlyZeros) / Double(timedZeros) : 0.5,
        yatzyZeroRate:       yatzyFills > 0 ? Double(yatzyZeros) / Double(yatzyFills) : 0,
        yatzyEverZeroed:     yatzyZeros > 0,
        mostScratchedCategory: scratchCount.max(by: { $0.value < $1.value })?.key,
        matchesWithTimestamps: timestampMatches
    )
}
