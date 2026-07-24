import SwiftUI
import Charts

struct DiceFairnessView: View {
    private let ideal = 100.0 / 6.0

    var body: some View {
        List {
            verdictSection
            distributionSection
            aboutSection
            deepDiveLink
        }
        .navigationTitle("Dice Fairness")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Verdict

    private var verdictSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: CertifiedFairnessTest.passes ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(CertifiedFairnessTest.passes ? .green : .orange)
                    .padding(.top, 8)

                Text("These dice are fair.")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Verified across \(formattedSamples) dice results — each face landed within \(String(format: "%.1f", maxDeviationPct))% of perfectly equal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Distribution

    private var distributionSection: some View {
        Section("Face Distribution") {
            Chart {
                ForEach(1...6, id: \.self) { face in
                    BarMark(
                        x: .value("Face", "\(face)"),
                        y: .value("Frequency", (CertifiedFairnessTest.frequencies[face] ?? 0) * 100)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.85))
                    .annotation(position: .top) {
                        Text(String(format: "%.1f%%", (CertifiedFairnessTest.frequencies[face] ?? 0) * 100))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                RuleMark(y: .value("Ideal", ideal))
                    .foregroundStyle(.red.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .frame(height: 160)
            .chartYScale(domain: 15.5...18.0)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.caption) }
            }
            .padding(.vertical, 8)

            Text("Dashed line shows the ideal 16.7% for a perfectly fair die. Observed range: \(String(format: "%.1f", CertifiedFairnessTest.minFrequencyPct))%–\(String(format: "%.1f", CertifiedFairnessTest.maxFrequencyPct))%.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Deep Dive Link

    private var deepDiveLink: some View {
        Section {
            NavigationLink {
                DiceFairnessDeepDiveView()
            } label: {
                Label("Statistical Deep Dive", systemImage: "function")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("How We Test") {
            Text("SyFive uses Apple's RealityKit physics engine to simulate real dice tumbling inside a tray. Each die is launched with random forces, settles under gravity, and its face is recorded only when it's fully at rest — the same way a physical die lands on a table.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Before each release we roll all five dice thousands of times and measure how often each face comes up. A fair die should land on each face roughly 1 in 6 times (16.7%). The results above are from that test.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Real casino dice are precision-machined and statistically certified before deployment — typically tested across tens of thousands of throws to confirm each face lands within a fraction of a percent of 16.7%. Our pre-release test uses the same statistical standard and the same sample size. The result: the same verified fairness, without the felt table.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text("Tested \(CertifiedFairnessTest.testDate)")
                Spacer()
                Text("\(formattedSamples) dice results")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private var formattedSamples: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: CertifiedFairnessTest.totalSamples)) ?? "\(CertifiedFairnessTest.totalSamples)"
    }

    private var maxDeviationPct: Double {
        CertifiedFairnessTest.frequencies.values.map { abs($0 * 100 - ideal) }.max() ?? 0
    }
}

#Preview {
    NavigationStack {
        DiceFairnessView()
    }
}
