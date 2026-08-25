import SwiftUI
import Charts
import UniformTypeIdentifiers
import SyLibDice

/// Debug fairness HUD for the dice physics system.
/// Enable via `AppConfig.DebugDice.showHarness = true`.
///
/// Shows a live distribution bar chart, chi-square / serial correlation / runs test
/// statistics, batch roll controls, CSV export, and a last-roll replay button.
@MainActor
struct DiceDebugHUD: View {

    @Bindable var diceRoller: DiceRoller
    @State private var showsReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            distributionChart
            rescueRow
            statsGrid
            Divider()
            batchControls
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if diceRoller.isReplay {
                Text("REPLAY")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .padding(8)
            }
        }
        .padding(.horizontal, 12)
        .sheet(isPresented: $showsReport) {
            DiceReportSheet(report: DiceReportGenerator.generate(from: diceRoller.statistics))
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Dice Fairness")
                    .font(.subheadline.weight(.semibold))
                Text("\(stats.totalSamples) samples · \(stats.totalRolls) rolls")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset", role: .destructive) { stats.reset() }
                .font(.caption)
                .buttonStyle(.bordered)
            Button("Report") { showsReport = true }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(stats.totalSamples == 0)
            ShareLink(
                item: CSVExport(content: stats.csvString()),
                preview: SharePreview("Dice Fairness.csv")
            ) {
                Label("CSV", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(stats.totalSamples == 0)
        }
    }

    // MARK: - Distribution chart

    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Distribution")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(1...6, id: \.self) { face in
                    BarMark(
                        x: .value("Face", "\(face)"),
                        y: .value("Count", stats.faceCounts[face] ?? 0)
                    )
                    .foregroundStyle(barColor(face: face))
                    .annotation(position: .top) {
                        if stats.totalSamples > 0 {
                            Text(String(format: "%.2f%%",
                                        (stats.faceFrequencies[face] ?? 0) * 100))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Expected frequency line
                if stats.totalSamples >= 6 {
                    RuleMark(y: .value("Expected", Double(stats.totalSamples) / 6.0))
                        .foregroundStyle(.red.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("E").font(.system(size: 8)).foregroundStyle(.red)
                        }
                }
            }
            .frame(height: 100)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartYAxis(.hidden)
        }
    }

    // MARK: - Rescue row

    private var rescueRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rescues per die")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            rescueDieRow(label: "rescue", counts: stats.rescueCountsPerDie, total: stats.totalRescues, color: .orange)
            rescueDieRow(label: "nudge",  counts: stats.nudgeCountsPerDie,  total: stats.totalNudges,  color: .yellow)
            rescueDieRow(label: "reroll", counts: stats.stuckRerollCountsPerDie, total: stats.totalStuckRerolls, color: .red)
        }
    }

    private func rescueDieRow(label: String, counts: [Int: Int], total: Int, color: Color) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            ForEach(0..<5, id: \.self) { die in
                let count = counts[die] ?? 0
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(count > 0 ? color : .secondary)
                    .frame(maxWidth: .infinity)
            }
            Text("\(total)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(total > 0 ? color : .secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Statistics grid

    private var statsGrid: some View {
        VStack(spacing: 4) {
            statRow(
                label: "χ²",
                value: String(format: "%.2f", stats.chiSquare),
                detail: String(format: "p = %.3f", stats.pValue),
                passes: stats.pValuePasses,
                passLabel: "PASS", failLabel: "BIAS?"
            )
            statRow(
                label: "Serial r",
                value: String(format: "%+.3f", stats.serialCorrelation),
                detail: "|r| < 0.1",
                passes: abs(stats.serialCorrelation) < 0.1,
                passLabel: "OK", failLabel: "CORR"
            )
            statRow(
                label: "Runs Z",
                value: String(format: "%+.2f", stats.runsTestZ),
                detail: "|Z| < 2",
                passes: abs(stats.runsTestZ) < 2,
                passLabel: "OK", failLabel: "STREAK"
            )
        }
        .font(.caption.monospacedDigit())
    }

    private func statRow(
        label: String,
        value: String,
        detail: String,
        passes: Bool,
        passLabel: String,
        failLabel: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary).frame(width: 54, alignment: .leading)
            Text(value).frame(width: 60, alignment: .trailing)
            Text(detail).foregroundStyle(.secondary).frame(minWidth: 60, alignment: .leading)
            Spacer()
            if stats.totalSamples >= 30 {
                Text(passes ? passLabel : failLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(passes ? .green : .orange)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background((passes ? Color.green : Color.orange).opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Batch controls

    private var batchControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Batch roll").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if diceRoller.isBatchRunning {
                    Button("Stop", role: .cancel) { diceRoller.stopBatch() }
                        .font(.caption).buttonStyle(.bordered)
                } else {
                    Button("1000") { diceRoller.startBatch(count: 1_000) }
                        .font(.caption).buttonStyle(.bordered)
                        .disabled(diceRoller.isRolling)
                    Button("10000") { diceRoller.startBatch(count: 10_000) }
                        .font(.caption).buttonStyle(.bordered)
                        .disabled(diceRoller.isRolling)
                }
            }

            batchHoldControls

            if diceRoller.isBatchPaused {
                pausedStuckView
            } else if diceRoller.isBatchRunning {
                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(
                        value: Double(diceRoller.batchProgress),
                        total: Double(max(diceRoller.batchTotal, 1))
                    )
                    Text("\(diceRoller.batchProgress) / \(diceRoller.batchTotal)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            // Replay last roll / batch ETA
            HStack {
                if diceRoller.isBatchRunning, let eta = batchETA {
                    Text(eta)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await diceRoller.replayLast { _ in } }
                    } label: {
                        Label("Replay Last Roll", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(diceRoller.lastRecipe == nil || diceRoller.isRolling || diceRoller.isBatchRunning)
                }
                Spacer()
                if let recipe = diceRoller.lastRecipe {
                    Text("seed \(String(recipe.seed, radix: 16, uppercase: false).prefix(8))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var pausedStuckView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                let indices = diceRoller.stuckDieIndices.sorted()
                Text("Paused — die\(indices.count == 1 ? "" : "s") \(indices.map(String.init).joined(separator: ", ")) stuck")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button("Resume") { diceRoller.resumeBatch() }
                    .font(.caption).buttonStyle(.bordered)
                    .tint(.orange)
            }
            Text("Snapshot logged to console. Inspect the highlighted die, then tap Resume.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(diceRoller.batchProgress) / \(diceRoller.batchTotal) completed")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var batchHoldControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Auto-hold dice between rolls", isOn: $diceRoller.batchHoldModeEnabled)
                .font(.caption)
            if diceRoller.batchHoldModeEnabled {
                Text("Each roll adds one new random held die. After 4 are held, the pattern resets, runs one fully free roll, then starts over.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Toggle("Pause when stuck", isOn: $diceRoller.pauseWhenStuck)
                .font(.caption)
            if diceRoller.pauseWhenStuck {
                Text("Batch pauses on each stuck die and logs a full diagnostic snapshot to the console.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var stats: DiceStatistics { diceRoller.statistics }

    private var batchETA: String? {
        guard let start = diceRoller.batchStartDate,
              diceRoller.batchProgress > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let rate = Double(diceRoller.batchProgress) / elapsed
        guard rate > 0 else { return nil }
        let remaining = Double(diceRoller.batchTotal - diceRoller.batchProgress)
        let secs = Int(remaining / rate)
        if secs >= 3600 {
            return "~\(secs / 3600)h \((secs % 3600) / 60)m \(secs % 60)s remaining"
        }
        if secs >= 60 {
            return "~\(secs / 60)m \(secs % 60)s remaining"
        }
        return "~\(secs)s remaining"
    }

    private func barColor(face: Int) -> Color {
        guard stats.totalSamples >= 30 else { return .blue }
        let freq = stats.faceFrequencies[face] ?? 0
        let deviation = abs(freq - 1.0 / 6.0) / (1.0 / 6.0)
        return deviation > 0.15 ? .orange : .blue
    }
}

private struct CSVExport: Transferable {
    let content: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(export.content.utf8)
        }
        .suggestedFileName("Dice Fairness")
    }
}

#Preview {
    let roller = DiceRoller()
    // Seed the preview with some fake data
    roller.statistics.add([1, 2, 3, 4, 5, 6, 1, 1, 2, 3, 4, 5, 6, 6, 2])
    return DiceDebugHUD(diceRoller: roller)
        .padding()
}
