import Foundation

/// Baked-in summary from a certified pre-release dice fairness test.
///
/// To update after a fresh batch run:
///   1. Run a 10,000-roll batch in the debug HUD with all five dice free.
///   2. Tap Report — copy the six face counts from the "Overall" section.
///   3. Update faceCounts, testDate, and totalRolls below.
///   4. Commit the new DICE_FAIRNESS_RUN.csv alongside this change.
enum CertifiedFairnessTest {

    // MARK: - Test parameters (update after each certified run)

    static let testDate   = "July 2026"
    static let totalRolls = 2_161       // five-dice rounds in this dataset
    static let faceCounts: [Int: Int] = [
        1: 1_797,
        2: 1_778,
        3: 1_834,
        4: 1_811,
        5: 1_841,
        6: 1_744,
    ]

    /// Serial correlation and runs Z require the ordered roll sequence and cannot be
    /// recomputed from face counts alone. Update these from the Report output after each run.
    static let serialCorrelation: Double = +0.000442
    static let runsTestZ: Double         = -0.086436

    // MARK: - Derived (no need to update)

    static var totalSamples: Int { faceCounts.values.reduce(0, +) }

    static var frequencies: [Int: Double] {
        let n = Double(totalSamples)
        return faceCounts.mapValues { Double($0) / n }
    }

    static var minFrequencyPct: Double { (frequencies.values.min() ?? 0) * 100 }
    static var maxFrequencyPct: Double { (frequencies.values.max() ?? 0) * 100 }

    static var chiSquare: Double {
        let n = Double(totalSamples)
        let expected = n / 6.0
        return faceCounts.values.reduce(0.0) { sum, count in
            let obs = Double(count)
            return sum + (obs - expected) * (obs - expected) / expected
        }
    }

    static var passes: Bool { chiSquarePValue > 0.05 }

    static var chiSquarePValue: Double {
        let chi2 = chiSquare
        let k = 5.0
        let h = 1.0 - 2.0 / (9.0 * k)
        let t = pow(chi2 / k, 1.0 / 3.0)
        let z = (t - h) / sqrt(2.0 / (9.0 * k))
        return 0.5 * erfc(z / sqrt(2.0))
    }
}
