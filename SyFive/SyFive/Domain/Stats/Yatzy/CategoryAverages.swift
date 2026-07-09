import Foundation

/// Average score per Yatzy category across completed matches for a player.
/// x = category index (0–12), y = average value, label = display name.
/// Categories with no data are omitted.
func categoryAverageSeries(playerID: UUID, matches: [Match]) -> [SeriesPoint] {
    YatzyCategory.allCases.enumerated().compactMap { index, category in
        guard let stats = categoryStats(category: category, playerID: playerID, matches: matches) else {
            return nil
        }
        return SeriesPoint(x: Decimal(index), y: stats.averageValue, label: category.displayName)
    }
}
