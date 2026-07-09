import Foundation

// Per-category statistics for one player across completed matches.
// Tier 2: reads YatzyCategory slotKey semantics. Compile-checks: Foundation only.

struct CategoryStats: Sendable {
    var category: YatzyCategory
    var timesFilled: Int               // entries with a non-nil value (always 13 in completed matches)
    var timesZeroed: Int               // value == Decimal(0) — a deliberate scratch
    var scratchRate: Double            // timesZeroed / timesFilled; 0.0 when timesFilled == 0
    var averageValue: Decimal          // mean over all filled instances, including zeros
    var averageWhenPositive: Decimal   // mean over value > 0 only; 0 when no positive entries
    var bestValue: Decimal
}

// Computes per-category stats for playerID across the provided matches.
// Each completed match contributes exactly one filled entry per category,
// so timesFilled equals the number of matches the player participated in.
// Returns nil if the player does not appear in any of the matches.
//
// The nil vs Decimal(0) distinction is load-bearing:
//   nil entry   = category wasn't recorded (shouldn't appear in completed matches)
//   Decimal(0)  = player deliberately scratched the category
// scratchRate tests value == Decimal(0), never < 0 or falsy.
func categoryStats(category: YatzyCategory, playerID: UUID, matches: [Match]) -> CategoryStats? {
    // Collect the scored value for this category from each match the player participated in.
    // compactMap drops matches where: (a) player not found, or (b) category entry value is nil.
    // A scratch (Decimal(0)) is kept because it is a legitimate scored value.
    let values: [Decimal] = matches.compactMap { match -> Decimal? in
        guard let p = match.participants.first(where: { $0.playerID == playerID }),
              let entry = p.scoreEntries.first(where: { $0.slotKey == category.slotKey })
        else { return nil }
        return entry.value  // Decimal? → compactMap strips nil, keeps Decimal(0)
    }

    guard !values.isEmpty else { return nil }

    let timesFilled = values.count
    let timesZeroed = values.filter { $0 == Decimal(0) }.count
    let total       = values.reduce(Decimal(0), +)

    let positives   = values.filter { $0 > 0 }
    let avgPositive: Decimal = positives.isEmpty
        ? Decimal(0)
        : positives.reduce(Decimal(0), +) / Decimal(positives.count)

    return CategoryStats(
        category: category,
        timesFilled: timesFilled,
        timesZeroed: timesZeroed,
        scratchRate: Double(timesZeroed) / Double(timesFilled),
        averageValue: total / Decimal(timesFilled),
        averageWhenPositive: avgPositive,
        bestValue: values.max() ?? Decimal(0)
    )
}
