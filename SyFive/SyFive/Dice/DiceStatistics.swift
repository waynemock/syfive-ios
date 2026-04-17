import Foundation
import Observation

/// Accumulates individual die roll results and computes fairness statistics.
///
/// Feed results via `add(_:)` after every roll. All computed properties are
/// derived lazily from `history`, so they update automatically when the history
/// changes and `DiceStatistics` is observed via `@Observable`.
@Observable
final class DiceStatistics {

    // MARK: - History

    private(set) var history: [Int] = []

    /// Total individual die samples collected (5 per roll).
    var totalSamples: Int { history.count }
    /// Approximate number of full 5-die rolls recorded.
    var totalRolls: Int { totalSamples / 5 }

    // MARK: - Distribution

    var faceCounts: [Int: Int] {
        var c = [Int: Int]()
        for v in history { c[v, default: 0] += 1 }
        return c
    }

    var faceFrequencies: [Int: Double] {
        guard totalSamples > 0 else { return [:] }
        return faceCounts.mapValues { Double($0) / Double(totalSamples) }
    }

    // MARK: - Chi-square

    /// Chi-square test statistic vs uniform distribution (5 degrees of freedom).
    var chiSquare: Double {
        guard totalSamples >= 30 else { return 0 }
        let expected = Double(totalSamples) / 6.0
        return (1...6).reduce(0.0) { sum, face in
            let obs = Double(faceCounts[face] ?? 0)
            return sum + (obs - expected) * (obs - expected) / expected
        }
    }

    /// p-value for the chi-square test (Wilson-Hilferty approximation, df = 5).
    /// Values > 0.05 indicate no statistically significant bias.
    var pValue: Double {
        guard totalSamples >= 30 else { return 1.0 }
        return chiSquarePValue(chiSquare, df: 5)
    }

    var pValuePasses: Bool { pValue > 0.05 }

    // MARK: - Serial correlation

    /// Pearson correlation between consecutive results.
    /// Near 0 = no sequential dependency; |r| > 0.1 warrants attention.
    var serialCorrelation: Double {
        guard history.count >= 2 else { return 0 }
        let n  = Double(history.count - 1)
        let x  = history.dropLast().map(Double.init)
        let y  = Array(history.dropFirst()).map(Double.init)
        let mX = x.reduce(0, +) / n
        let mY = y.reduce(0, +) / n
        let num = zip(x, y).reduce(0.0) { $0 + ($1.0 - mX) * ($1.1 - mY) }
        let dX  = x.reduce(0.0) { $0 + ($1 - mX) * ($1 - mX) }
        let dY  = y.reduce(0.0) { $0 + ($1 - mY) * ($1 - mY) }
        guard dX > 0, dY > 0 else { return 0 }
        return num / sqrt(dX * dY)
    }

    // MARK: - Runs test

    /// Wald-Wolfowitz runs test Z-score (above / below median 3.5).
    /// |Z| < 2 indicates no detectable streak pattern.
    var runsTestZ: Double {
        guard history.count >= 10 else { return 0 }
        let signs = history.map { $0 > 3 }
        var runs = 1
        for i in 1..<signs.count where signs[i] != signs[i - 1] { runs += 1 }
        let n1 = Double(signs.filter { $0 }.count)
        let n2 = Double(signs.filter { !$0 }.count)
        let n  = n1 + n2
        guard n1 > 0, n2 > 0 else { return 0 }
        let mu = 2 * n1 * n2 / n + 1
        let vr = 2 * n1 * n2 * (2 * n1 * n2 - n) / (n * n * (n - 1))
        guard vr > 0 else { return 0 }
        return (Double(runs) - mu) / sqrt(vr)
    }

    // MARK: - Mutation

    func add(_ values: [Int]) {
        history.append(contentsOf: values)
        // Cap at 10 k samples to bound memory
        if history.count > 10_000 { history.removeFirst(history.count - 10_000) }
    }

    func reset() { history = [] }

    // MARK: - Export

    func csvString() -> String {
        var lines = ["index,value"]
        for (i, v) in history.enumerated() { lines.append("\(i),\(v)") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private maths

    /// Chi-square survival function (P > x for df degrees of freedom).
    /// Uses the Wilson-Hilferty cube-root normal approximation.
    private func chiSquarePValue(_ x: Double, df: Int) -> Double {
        let k = Double(df)
        let h = 1.0 - 2.0 / (9.0 * k)
        let t = pow(x / k, 1.0 / 3.0)
        let z = (t - h) / sqrt(2.0 / (9.0 * k))
        return 0.5 * erfc(z / sqrt(2.0))   // P(Z > z)
    }
}
