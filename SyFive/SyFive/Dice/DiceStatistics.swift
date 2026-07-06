import Foundation
import Observation

/// Accumulates individual die roll results and computes fairness statistics.
///
/// All properties accessed by the HUD are O(1) stored counters maintained
/// incrementally in addRoll(). Expensive sequential stats (serial correlation,
/// runs test) are recomputed at most once per 500 new samples so they never
/// block the main thread during batch rolling.
@Observable
final class DiceStatistics {

    enum SampleSource: String {
        case gameplay
        case batch
        case preview
    }

    struct SampleRecord {
        let sampleIndex: Int
        let rollID: Int
        let dieIndex: Int
        let value: Int
        let held: Bool
        let source: SampleSource
        let rescued: Bool
        let rescueKind: String
        let escapeRecovered: Bool
        let stuckReroll: Bool
        let stuckNudge: Bool
        let stuckReason: String
        let finalAlign: Float
        let unsettledSecs: Float
        let finalX: Float
        let finalZ: Float
        let finalHeight: Float
        let spawnX: Float
        let spawnY: Float
        let spawnZ: Float
        let rollDurationSecs: Float
    }

    // MARK: - Windowed history (for chi-square and sequential tests)

    private(set) var history: [Int] = []
    private(set) var records: [SampleRecord] = []
    private var nextRollID: Int = 1

    /// Samples in the current window (max ~10 k).
    var totalSamples: Int { history.count }

    /// Cumulative rolls ever processed (all-time, never decremented on trim).
    private(set) var totalRolls: Int = 0

    // MARK: - O(1) distribution counters (window-matched, decremented on trim)

    /// Face counts matching the current history window. Used for chi-square and the chart.
    private(set) var faceCounts: [Int: Int] = [:]

    var faceFrequencies: [Int: Double] {
        guard totalSamples > 0 else { return [:] }
        let n = Double(totalSamples)
        return faceCounts.mapValues { Double($0) / n }
    }

    // MARK: - O(1) rescue counters (cumulative, all-time)

    private(set) var totalRescues: Int = 0
    private(set) var totalNudges: Int = 0
    private(set) var totalStuckRerolls: Int = 0
    private(set) var rescueCountsPerDie: [Int: Int] = [:]
    private(set) var nudgeCountsPerDie: [Int: Int] = [:]
    private(set) var stuckRerollCountsPerDie: [Int: Int] = [:]

    // MARK: - Chi-square (O(6) — uses stored faceCounts)

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
    var pValue: Double {
        guard totalSamples >= 30 else { return 1.0 }
        return chiSquarePValue(chiSquare, df: 5)
    }

    var pValuePasses: Bool { pValue > 0.05 }

    // MARK: - Sequential stats (O(n) but throttled — recomputed at most every 500 samples)

    private var _cachedSerialCorr: Double = 0
    private var _cachedRunsZ: Double = 0
    private var _cacheComputedAt: Int = -1

    /// Pearson correlation between consecutive results.
    var serialCorrelation: Double {
        refreshSequentialCacheIfNeeded()
        return _cachedSerialCorr
    }

    /// Wald-Wolfowitz runs test Z-score (above / below median 3.5).
    var runsTestZ: Double {
        refreshSequentialCacheIfNeeded()
        return _cachedRunsZ
    }

    private func refreshSequentialCacheIfNeeded() {
        let n = history.count
        guard n >= 2, n - _cacheComputedAt >= 500 else { return }
        _cacheComputedAt = n
        _cachedSerialCorr = computeSerialCorrelation()
        _cachedRunsZ = computeRunsTestZ()
    }

    private func computeSerialCorrelation() -> Double {
        guard history.count >= 2 else { return 0 }
        let n = Double(history.count - 1)
        let x = history.dropLast().map(Double.init)
        let y = Array(history.dropFirst()).map(Double.init)
        let mX = x.reduce(0, +) / n
        let mY = y.reduce(0, +) / n
        let num = zip(x, y).reduce(0.0) { $0 + ($1.0 - mX) * ($1.1 - mY) }
        let dX = x.reduce(0.0) { $0 + ($1 - mX) * ($1 - mX) }
        let dY = y.reduce(0.0) { $0 + ($1 - mY) * ($1 - mY) }
        guard dX > 0, dY > 0 else { return 0 }
        return num / sqrt(dX * dY)
    }

    private func computeRunsTestZ() -> Double {
        guard history.count >= 10 else { return 0 }
        let signs = history.map { $0 > 3 }
        var runs = 1
        for i in 1..<signs.count where signs[i] != signs[i - 1] { runs += 1 }
        let n1 = Double(signs.filter { $0 }.count)
        let n2 = Double(signs.filter { !$0 }.count)
        let n = n1 + n2
        guard n1 > 0, n2 > 0 else { return 0 }
        let mu = 2 * n1 * n2 / n + 1
        let vr = 2 * n1 * n2 * (2 * n1 * n2 - n) / (n * n * (n - 1))
        guard vr > 0 else { return 0 }
        return (Double(runs) - mu) / sqrt(vr)
    }

    // MARK: - Mutation

    func add(_ values: [Int]) {
        addRoll(
            values,
            source: .preview,
            held: Array(repeating: false, count: values.count),
            rescueKinds: Array(repeating: "", count: values.count),
            escapeRecovered: Array(repeating: false, count: values.count),
            stuckReroll: Array(repeating: false, count: values.count),
            stuckNudge: Array(repeating: false, count: values.count),
            stuckReasons: Array(repeating: "", count: values.count),
            finalAligns: Array(repeating: 0, count: values.count),
            unsettledSecs: Array(repeating: 0, count: values.count),
            finalXs: Array(repeating: 0, count: values.count),
            finalZs: Array(repeating: 0, count: values.count),
            finalHeights: Array(repeating: 0, count: values.count),
            spawnPositions: Array(repeating: .zero, count: values.count),
            rollDurationSecs: 0
        )
    }

    func addRoll(
        _ values: [Int],
        source: SampleSource,
        held: [Bool],
        rescueKinds: [String],
        escapeRecovered: [Bool],
        stuckReroll: [Bool],
        stuckNudge: [Bool],
        stuckReasons: [String],
        finalAligns: [Float],
        unsettledSecs: [Float],
        finalXs: [Float],
        finalZs: [Float],
        finalHeights: [Float],
        spawnPositions: [SIMD3<Float>],
        rollDurationSecs: Float
    ) {
        let rollID = nextRollID
        nextRollID += 1
        totalRolls += 1
        let startingSampleIndex = history.count

        history.append(contentsOf: values)

        for (dieIndex, value) in values.enumerated() {
            let rescueKind = dieIndex < rescueKinds.count ? rescueKinds[dieIndex] : ""
            let isRescued = !rescueKind.isEmpty
            let isNudge = dieIndex < stuckNudge.count && stuckNudge[dieIndex]
            let isReroll = dieIndex < stuckReroll.count && stuckReroll[dieIndex]
            let spawn = dieIndex < spawnPositions.count ? spawnPositions[dieIndex] : .zero

            // Update O(1) counters incrementally.
            faceCounts[value, default: 0] += 1
            if isRescued {
                totalRescues += 1
                rescueCountsPerDie[dieIndex, default: 0] += 1
            }
            if isNudge {
                totalNudges += 1
                nudgeCountsPerDie[dieIndex, default: 0] += 1
            }
            if isReroll {
                totalStuckRerolls += 1
                stuckRerollCountsPerDie[dieIndex, default: 0] += 1
            }

            records.append(
                SampleRecord(
                    sampleIndex: startingSampleIndex + dieIndex,
                    rollID: rollID,
                    dieIndex: dieIndex,
                    value: value,
                    held: dieIndex < held.count ? held[dieIndex] : false,
                    source: source,
                    rescued: isRescued,
                    rescueKind: rescueKind,
                    escapeRecovered: dieIndex < escapeRecovered.count ? escapeRecovered[dieIndex] : false,
                    stuckReroll: isReroll,
                    stuckNudge: isNudge,
                    stuckReason: dieIndex < stuckReasons.count ? stuckReasons[dieIndex] : "",
                    finalAlign: dieIndex < finalAligns.count ? finalAligns[dieIndex] : 0,
                    unsettledSecs: dieIndex < unsettledSecs.count ? unsettledSecs[dieIndex] : 0,
                    finalX: dieIndex < finalXs.count ? finalXs[dieIndex] : 0,
                    finalZ: dieIndex < finalZs.count ? finalZs[dieIndex] : 0,
                    finalHeight: dieIndex < finalHeights.count ? finalHeights[dieIndex] : 0,
                    spawnX: spawn.x,
                    spawnY: spawn.y,
                    spawnZ: spawn.z,
                    rollDurationSecs: rollDurationSecs
                )
            )
        }

        // Trim the window in large batches (11k→10k) rather than 5 elements per roll.
        // removeFirst on a 10k array is O(n) — batching reduces that to ~once per 200 rolls.
        // Decrement faceCounts for trimmed values so chi-square stays accurate.
        let maxWindow = 11_000
        let targetWindow = 10_000
        if history.count > maxWindow {
            let overflow = history.count - targetWindow
            for value in history.prefix(overflow) {
                if let count = faceCounts[value] {
                    if count > 1 { faceCounts[value] = count - 1 }
                    else { faceCounts.removeValue(forKey: value) }
                }
            }
            history.removeFirst(overflow)
            records.removeFirst(min(overflow, records.count))
            _cacheComputedAt = -1  // history changed significantly, invalidate sequential cache
        }
    }

    func reset() {
        history = []
        records = []
        nextRollID = 1
        totalRolls = 0
        faceCounts = [:]
        totalRescues = 0
        totalNudges = 0
        totalStuckRerolls = 0
        rescueCountsPerDie = [:]
        nudgeCountsPerDie = [:]
        stuckRerollCountsPerDie = [:]
        _cachedSerialCorr = 0
        _cachedRunsZ = 0
        _cacheComputedAt = -1
    }

    // MARK: - Export

    func csvString() -> String {
        var lines = ["sample_index,roll_id,die_index,value,held,source,rescued,rescue_kind,escape_recovered,stuck_reroll,stuck_nudge,stuck_reason,final_align,unsettled_secs,final_x,final_z,final_height,spawn_x,spawn_y,spawn_z,roll_duration_secs"]
        for record in records {
            lines.append(
                "\(record.sampleIndex),\(record.rollID),\(record.dieIndex),\(record.value)," +
                "\(record.held),\(record.source.rawValue),\(record.rescued),\(record.rescueKind)," +
                "\(record.escapeRecovered),\(record.stuckReroll),\(record.stuckNudge),\(record.stuckReason)," +
                String(format: "%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f",
                       record.finalAlign, record.unsettledSecs,
                       record.finalX, record.finalZ, record.finalHeight,
                       record.spawnX, record.spawnY, record.spawnZ,
                       record.rollDurationSecs)
            )
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private maths

    private func chiSquarePValue(_ x: Double, df: Int) -> Double {
        let k = Double(df)
        let h = 1.0 - 2.0 / (9.0 * k)
        let t = pow(x / k, 1.0 / 3.0)
        let z = (t - h) / sqrt(2.0 / (9.0 * k))
        return 0.5 * erfc(z / sqrt(2.0))
    }
}
