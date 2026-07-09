import Foundation

enum Variability: String, Sendable {
    case steady   // stdDev ≤ 30
    case swingy   // stdDev > 30
}

struct ConsistencyProfile: Sendable {
    var gameCount: Int
    var scoreSpread: (min: Decimal, median: Decimal, max: Decimal)
    var stdDev: Decimal
    var variability: Variability
}

// Requires ≥ 2 completed matches for the player; returns nil otherwise.
func consistencyProfile(playerID: UUID, matches: [Match]) -> ConsistencyProfile? {
    let scores = matches
        .filter { $0.status == .completed }
        .compactMap { $0.participants.first { $0.playerID == playerID }?.finalScore }
        .sorted()
    guard scores.count >= 2 else { return nil }
    let n = scores.count
    let median: Decimal = n % 2 == 1
        ? scores[n / 2]
        : (scores[n / 2 - 1] + scores[n / 2]) / 2
    let mean = scores.reduce(.zero, +) / Decimal(n)
    let variance = scores.reduce(.zero) { acc, s in let d = s - mean; return acc + d * d } / Decimal(n)
    let stdDev = Decimal(sqrt(Double(truncating: variance as NSDecimalNumber)))
    return ConsistencyProfile(
        gameCount: n,
        scoreSpread: (min: scores[0], median: median, max: scores[n - 1]),
        stdDev: stdDev,
        variability: stdDev > 30 ? .swingy : .steady
    )
}
