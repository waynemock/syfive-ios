import Foundation

/// Generates a formatted analysis report from in-memory DiceStatistics.
/// All computation is synchronous — data is already in memory, no I/O required.
struct DiceReportGenerator {

    static func generate(from stats: DiceStatistics) -> String {
        let records = stats.records
        guard !records.isEmpty else { return "No data recorded yet." }

        var lines: [String] = []

        // MARK: - Summary counts

        let heldCount       = records.filter { $0.held }.count
        let rescuedCount    = records.filter { $0.rescued }.count
        let escapeCount     = records.filter { $0.escapeRecovered }.count
        let nudgeCount      = records.filter { $0.stuckNudge }.count
        let rerollCount     = records.filter { $0.stuckReroll }.count
        let nudgeThenReroll = records.filter { $0.stuckNudge && $0.stuckReroll }.count

        var sourceCounts:      [String: Int] = [:]
        var rescueKindCounts:  [String: Int] = [:]
        var stuckReasonCounts: [String: Int] = [:]
        for r in records {
            sourceCounts[r.source.rawValue, default: 0] += 1
            if !r.rescueKind.isEmpty  { rescueKindCounts[r.rescueKind, default: 0] += 1 }
            if !r.stuckReason.isEmpty { stuckReasonCounts[r.stuckReason, default: 0] += 1 }
        }

        let totalRolls = Set(records.map { $0.rollID }).count

        // MARK: - Header

        lines.append("══ Dice Fairness Report ══")
        lines.append("Samples: \(stats.totalSamples)  Rolls: \(totalRolls)")
        let sourceStr = sourceCounts.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "  ")
        lines.append("Sources: \(sourceStr)")
        lines.append("Held: \(heldCount)  Rescued: \(rescuedCount)  Escape-recovered: \(escapeCount)")
        lines.append("Stuck-nudge: \(nudgeCount)  Stuck-reroll: \(rerollCount)")
        if nudgeCount > 0 {
            let nudgeSuccess = nudgeCount - nudgeThenReroll
            let rate = Double(nudgeSuccess) / Double(nudgeCount) * 100
            lines.append(String(format: "  nudge settled: %d  nudge→reroll: %d  (%.1f%% success)",
                                nudgeSuccess, nudgeThenReroll, rate))
        }
        if !rescueKindCounts.isEmpty {
            let s = rescueKindCounts.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "  ")
            lines.append("Rescue kinds: \(s)")
        }
        if !stuckReasonCounts.isEmpty {
            let s = stuckReasonCounts.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "  ")
            lines.append("Stuck reasons: \(s)")
        }

        // Snap detection: floor rescue + no stuck reason = silently snapped
        let snappedCount  = records.filter { $0.rescueKind.contains("floor") && $0.stuckReason.isEmpty }.count
        let floorRerolled = stuckReasonCounts["floor-stuck-timeout"] ?? 0
        let totalFloor    = snappedCount + floorRerolled
        if totalFloor > 0 {
            let snapRate = Double(snappedCount) / Double(totalFloor) * 100
            lines.append(String(format: "Floor-stuck outcomes — snapped: %d  rerolled: %d  total: %d  snap rate: %.1f%%",
                                snappedCount, floorRerolled, totalFloor, snapRate))
        }

        // Per-die stuck counts
        var perDieStuck: [Int: Int] = [:]
        for r in records where !r.stuckReason.isEmpty { perDieStuck[r.dieIndex, default: 0] += 1 }
        if !perDieStuck.isEmpty {
            let totalStuck = perDieStuck.values.reduce(0, +)
            let stuckRate  = totalRolls > 0 ? Double(totalStuck) / Double(totalRolls) * 100 : 0
            let breakdown  = perDieStuck.sorted { $0.key < $1.key }.map { "d\($0.key):\($0.value)" }.joined(separator: "  ")
            lines.append(String(format: "Per-die stuck: %@  (total=%d, %.2f%% of rolls)",
                                breakdown, totalStuck, stuckRate))
        }

        // MARK: - Alignment analysis

        let nonZeroAligns = records.filter { $0.finalAlign > 0 }.map { Double($0.finalAlign) }
        if !nonZeroAligns.isEmpty {
            lines.append(String(format: "Avg final alignment (all): %.4f", avg(nonZeroAligns)))

            let settledAligns = records
                .filter { $0.stuckReason.isEmpty && $0.finalAlign > 0 }
                .map { Double($0.finalAlign) }
                .sorted()
            if !settledAligns.isEmpty {
                let p1  = percentile(settledAligns, 0.01)
                let p10 = percentile(settledAligns, 0.10)
                let p50 = percentile(settledAligns, 0.50)
                let below95 = settledAligns.filter { $0 < 0.95 }.count
                lines.append(String(format: "Settled alignment — p1: %.4f  p10: %.4f  median: %.4f  below 0.95: %d/%d",
                                    p1, p10, p50, below95, settledAligns.count))
            }

            let stuckRecords = records.filter { !$0.stuckReason.isEmpty }
            if !stuckRecords.isEmpty {
                let n          = stuckRecords.count
                let sAligns    = stuckRecords.map { Double($0.finalAlign) }
                let sUnsettled = stuckRecords.map { Double($0.unsettledSecs) }
                let sFst       = stuckRecords.filter { $0.floorStuckSecs > 0 }.map { Double($0.floorStuckSecs) }
                let sAngular   = stuckRecords.filter { $0.finalAngularSpeed > 0 }.map { Double($0.finalAngularSpeed) }
                let sLinear    = stuckRecords.filter { $0.finalLinearSpeed > 0 }.map { Double($0.finalLinearSpeed) }

                var stuckLine = String(format: "Avg final alignment (stuck only): %.4f  avg unsettled: %.2fs",
                                       avg(sAligns), avg(sUnsettled))
                if !sFst.isEmpty { stuckLine += String(format: "  avg floor_stuck: %.2fs", avg(sFst)) }
                lines.append(stuckLine)

                if !sAngular.isEmpty {
                    let spinning = sAngular.filter { $0 > 0.01 }.count
                    lines.append(String(format: "Stuck angular speed — avg: %.4f  max: %.4f  still spinning (w>0.01): %d/%d",
                                        avg(sAngular), sAngular.max()!, spinning, n))
                }
                if !sLinear.isEmpty {
                    lines.append(String(format: "Stuck linear  speed — avg: %.4f  max: %.4f",
                                        avg(sLinear), sLinear.max()!))
                }

                let xs = stuckRecords.map { Double($0.finalX) }
                let zs = stuckRecords.map { Double($0.finalZ) }
                lines.append(String(format: "Stuck positions — x: [%.3f, %.3f]  z: [%.3f, %.3f]",
                                    xs.min()!, xs.max()!, zs.min()!, zs.max()!))
                let hs = stuckRecords.filter { $0.finalHeight > 0 }.map { Double($0.finalHeight) }
                if !hs.isEmpty {
                    lines.append(String(format: "Stuck heights — min: %.4f  max: %.4f  avg: %.4f",
                                        hs.min()!, hs.max()!, avg(hs)))
                }

                if stuckReasonCounts.count > 1 && !sAngular.isEmpty {
                    lines.append("Stuck-reason breakdown:")
                    for reason in stuckReasonCounts.keys.sorted() {
                        let rr     = stuckRecords.filter { $0.stuckReason == reason }
                        let nr     = rr.count
                        let rAlign = avg(rr.map { Double($0.finalAlign) })
                        let rFst   = rr.filter { $0.floorStuckSecs > 0 }.map { Double($0.floorStuckSecs) }
                        let rAng   = rr.filter { $0.finalAngularSpeed > 0 }.map { Double($0.finalAngularSpeed) }
                        let fstStr = rFst.isEmpty ? "n/a" : String(format: "%.2fs", avg(rFst))
                        let angStr = rAng.isEmpty ? "n/a" : String(format: "%.4f", avg(rAng))
                        let spin   = rAng.filter { $0 > 0.01 }.count
                        lines.append("  \(reason) (n=\(nr)): align=\(String(format: "%.3f", rAlign))  fst=\(fstStr)  angular=\(angStr)  spinning=\(spin)/\(nr)")
                    }
                }
            }
        }

        // MARK: - Spawn heights

        let spawnYs = records.filter { $0.spawnY > 0 }.map { Double($0.spawnY) }
        if !spawnYs.isEmpty {
            lines.append(String(format: "Spawn heights — min: %.4f  max: %.4f  avg: %.4f",
                                spawnYs.min()!, spawnYs.max()!, avg(spawnYs)))
        }

        // MARK: - Roll durations

        var durationByRoll: [Int: Double] = [:]
        for r in records where r.rollDurationSecs > 0 { durationByRoll[r.rollID] = Double(r.rollDurationSecs) }
        if !durationByRoll.isEmpty {
            let sorted = durationByRoll.values.sorted()
            lines.append(String(format: "Roll durations — min: %.2fs  p50: %.2fs  p95: %.2fs  p99: %.2fs  max: %.2fs  avg: %.2fs",
                                sorted.first!, percentile(sorted, 0.50), percentile(sorted, 0.95),
                                percentile(sorted, 0.99), sorted.last!, avg(sorted)))
        }

        // MARK: - Yatzys

        var rollValuesMap: [Int: [Int]] = [:]
        for r in records { rollValuesMap[r.rollID, default: []].append(r.value) }
        let yatzyCount = rollValuesMap.values.filter { $0.count == 5 && Set($0).count == 1 }.count
        lines.append("Yatzys rolled: \(yatzyCount)")

        // MARK: - Fairness sections

        lines.append("")
        lines.append("── Overall ──")
        appendFairness(to: &lines, values: records.map { $0.value })

        lines.append("")
        lines.append("── Per die ──")
        for dieIdx in Set(records.map { $0.dieIndex }).sorted() {
            lines.append("  Die \(dieIdx)")
            appendFairness(to: &lines, values: records.filter { $0.dieIndex == dieIdx }.map { $0.value }, indent: "    ")
        }

        let freeVals = records.filter { !$0.held }.map { $0.value }
        let heldVals = records.filter { $0.held }.map { $0.value }
        if !freeVals.isEmpty {
            lines.append("")
            lines.append("── Free dice only ──")
            appendFairness(to: &lines, values: freeVals)
        }
        if !heldVals.isEmpty {
            lines.append("")
            lines.append("── Held dice only ──")
            appendFairness(to: &lines, values: heldVals)
        }

        let cleanVals   = records.filter { !$0.rescued }.map { $0.value }
        let rescuedVals = records.filter { $0.rescued }.map { $0.value }
        if !cleanVals.isEmpty {
            lines.append("")
            lines.append("── Clean samples ──")
            appendFairness(to: &lines, values: cleanVals)
        }
        if !rescuedVals.isEmpty {
            lines.append("")
            lines.append("── Rescued samples ──")
            appendFairness(to: &lines, values: rescuedVals)
        }

        let rerolledVals = records.filter { $0.stuckReroll }.map { $0.value }
        if !rerolledVals.isEmpty {
            lines.append("")
            lines.append("── Stuck-reroll samples ──")
            appendFairness(to: &lines, values: rerolledVals)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private static func appendFairness(to lines: inout [String], values: [Int], indent: String = "") {
        let n = values.count
        guard n > 0 else { return }
        var counts = [Int: Int]()
        for v in values { counts[v, default: 0] += 1 }
        let expected = Double(n) / 6.0
        let chi2 = (1...6).reduce(0.0) { sum, face in
            let obs = Double(counts[face] ?? 0)
            return sum + (obs - expected) * (obs - expected) / expected
        }
        let pVal    = chiSquarePValue(chi2, df: 5)
        let serialR = serialCorrelation(values)
        let runsZ   = runsTestZ(values)

        let countStr = (1...6).map { "\($0):\(counts[$0] ?? 0)" }.joined(separator: " ")
        let freqStr  = (1...6).map { String(format: "%.2f%%", Double(counts[$0] ?? 0) / Double(n) * 100) }.joined(separator: " ")

        lines.append("\(indent)samples: \(n)")
        lines.append("\(indent)counts:  \(countStr)")
        lines.append("\(indent)freqs:   \(freqStr)")
        lines.append(String(format: "\(indent)expected: %.3f", expected))
        lines.append(String(format: "\(indent)chi²: %.4f  p: %.6f  %@", chi2, pVal, pVal > 0.05 ? "PASS" : "BIAS?"))
        if n >= 2 {
            lines.append(String(format: "\(indent)serial r: %+.6f  %@", serialR, abs(serialR) < 0.1 ? "OK" : "CORR"))
            lines.append(String(format: "\(indent)runs Z:   %+.6f  %@", runsZ, abs(runsZ) < 2.0 ? "OK" : "STREAK"))
        }
    }

    private static func avg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let idx  = (Double(sorted.count) - 1) * p
        let lo   = Int(idx)
        let hi   = lo + 1
        let frac = idx - Double(lo)
        if hi >= sorted.count { return sorted[lo] }
        return sorted[lo] * (1 - frac) + sorted[hi] * frac
    }

    private static func chiSquarePValue(_ x: Double, df: Int) -> Double {
        let k = Double(df)
        let h = 1.0 - 2.0 / (9.0 * k)
        let t = pow(x / k, 1.0 / 3.0)
        let z = (t - h) / sqrt(2.0 / (9.0 * k))
        return 0.5 * erfc(z / sqrt(2.0))
    }

    private static func serialCorrelation(_ values: [Int]) -> Double {
        guard values.count >= 2 else { return 0 }
        let x  = values.dropLast().map(Double.init)
        let y  = Array(values.dropFirst()).map(Double.init)
        let n  = Double(x.count)
        let mX = x.reduce(0, +) / n
        let mY = y.reduce(0, +) / n
        let num = zip(x, y).reduce(0.0) { $0 + ($1.0 - mX) * ($1.1 - mY) }
        let dX  = x.reduce(0.0) { $0 + ($1 - mX) * ($1 - mX) }
        let dY  = y.reduce(0.0) { $0 + ($1 - mY) * ($1 - mY) }
        guard dX > 0, dY > 0 else { return 0 }
        return num / sqrt(dX * dY)
    }

    private static func runsTestZ(_ values: [Int]) -> Double {
        guard values.count >= 10 else { return 0 }
        let signs = values.map { $0 > 3 }
        var runs  = 1
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
}
