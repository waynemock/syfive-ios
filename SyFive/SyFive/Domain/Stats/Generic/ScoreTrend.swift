import Foundation

/// A player's final score in each completed match, sorted chronologically.
/// Maps directly to a line chart (x = date, y = score).
func scoreTrend(playerID: UUID, matches: [Match]) -> [DatedPoint] {
    matches
        .filter { $0.status == .completed }
        .sorted { $0.startedAt < $1.startedAt }
        .compactMap { match in
            guard let p = match.participants.first(where: { $0.playerID == playerID }) else { return nil }
            return DatedPoint(at: match.startedAt, value: p.finalScore)
        }
}

/// How often a player finishes in each place across completed matches.
/// Maps to a bar chart (x = rank, y = count).
func placementSeries(playerID: UUID, matches: [Match]) -> Distribution {
    var bins: [Int: Int] = [:]
    for match in matches where match.status == .completed {
        guard let p = match.participants.first(where: { $0.playerID == playerID }),
              p.rank > 0 else { continue }
        bins[p.rank, default: 0] += 1
    }
    return Distribution(bins: bins)
}
