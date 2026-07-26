import SwiftUI

struct DiceFairnessDeepDiveView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            chiSquareSection
            independenceSection
            faceTableSection
            methodologySection
        }
        .navigationTitle("Statistical Deep Dive")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Chi-Square

    private var chiSquareSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    statPill(label: "χ²", value: String(format: "%.4f", CertifiedFairnessTest.chiSquare))
                    statPill(label: "df", value: "5")
                    statPill(label: "p-value", value: String(format: "%.4f", CertifiedFairnessTest.chiSquarePValue))
                    Spacer()
                    passFailBadge(CertifiedFairnessTest.passes)
                }

                Text("χ² = Σ (observed − expected)² / expected, summed across all six faces. With \(formattedSamples) total samples, each face has an expected count of \(String(format: "%.1f", Double(CertifiedFairnessTest.totalSamples) / 6.0)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("A p-value of \(String(format: "%.4f", CertifiedFairnessTest.chiSquarePValue)) means that if the die were perfectly fair, you'd see face counts at least this uneven \(String(format: "%.1f", CertifiedFairnessTest.chiSquarePValue * 100))% of the time just by chance. The conventional threshold for concern is p < 0.05 — we are well above it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Degrees of freedom = 5 because the six face counts must sum to a fixed total, which removes one degree of freedom. This is standard for a multinomial goodness-of-fit test.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Chi-Square Goodness-of-Fit")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Independence

    private var independenceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Serial Correlation (Pearson r)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        passFailBadge(abs(CertifiedFairnessTest.serialCorrelation) < 0.1)
                    }

                    HStack(spacing: 10) {
                        statPill(label: "r", value: String(format: "%+.6f", CertifiedFairnessTest.serialCorrelation))
                        statPill(label: "threshold", value: "|r| < 0.1")
                    }

                    Text("Pearson r measures whether one roll predicts the next. A perfectly random sequence has r = 0. A loaded or memory-biased mechanism (e.g., one face always following another) would show a value far from zero. Our r ≈ \(String(format: "%.4f", CertifiedFairnessTest.serialCorrelation)) is effectively indistinguishable from noise.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Wald-Wolfowitz Runs Test (Z)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        passFailBadge(abs(CertifiedFairnessTest.runsTestZ) < 2.0)
                    }

                    HStack(spacing: 10) {
                        statPill(label: "Z", value: String(format: "%+.6f", CertifiedFairnessTest.runsTestZ))
                        statPill(label: "threshold", value: "|Z| < 2.0")
                    }

                    Text("The runs test splits the sequence into \"above median\" and \"below median\" values and counts the number of runs — unbroken consecutive blocks of the same type. Too few runs indicates streaking (hot/cold dice); too many indicates alternating patterns. Both are signs of non-randomness. Z ≈ \(String(format: "%.4f", CertifiedFairnessTest.runsTestZ)) is essentially zero.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Roll Independence Tests")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Per-Face Table

    private var faceTableSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Face").frame(width: 40, alignment: .leading)
                    Text("Count").frame(width: 56, alignment: .trailing)
                    Text("Freq %").frame(width: 72, alignment: .trailing)
                    Text("Δ from ideal").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(1...6, id: \.self) { face in
                    let count = CertifiedFairnessTest.faceCounts[face] ?? 0
                    let freq  = Double(count) / Double(CertifiedFairnessTest.totalSamples) * 100
                    let delta = freq - (100.0 / 6.0)
                    HStack {
                        Text("⚀⚁⚂⚃⚄⚅".map(String.init)[face - 1])
                            .lineLimit(1)
                            .frame(width: 40, alignment: .leading)
                        Text("\(count)")
                            .lineLimit(1)
                            .frame(width: 56, alignment: .trailing)
                        Text(String(format: "%.3f%%", freq))
                            .lineLimit(1)
                            .frame(width: 72, alignment: .trailing)
                        Text(String(format: "%+.4fpp", delta))
                            .lineLimit(1)
                            .foregroundStyle(abs(delta) > 1.5 ? .orange : .secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.subheadline.monospacedDigit())
                }

                Text("Ideal frequency is 16.6̄% per face. pp = percentage points deviation. At this sample size, random variation routinely produces ±0.5–1.5pp swings — anything under ±2pp is unremarkable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Per-Face Results")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Methodology

    private var methodologySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("All three tests were applied to the same ordered roll sequence of \(formattedSamples) individual die results. The chi-square p-value is computed using the Wilson-Hilferty normal approximation to the chi-square CDF, which is accurate to within 0.1% for df ≥ 5.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Serial correlation and runs Z require the ordered sequence and cannot be recomputed from face counts alone. Both were computed from the full dataset at test time and stored as constants in the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Test date: \(CertifiedFairnessTest.testDate) · \(formattedSamples) dice results · \(CertifiedFairnessTest.totalRolls) rounds")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Methodology Notes")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Helpers

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit().weight(.medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func passFailBadge(_ passes: Bool) -> some View {
        Text(passes ? "PASS" : "FAIL")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(passes ? .green : .orange)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((passes ? Color.green : Color.orange).opacity(0.15))
            .clipShape(Capsule())
    }

    private var formattedSamples: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: CertifiedFairnessTest.totalSamples)) ?? "\(CertifiedFairnessTest.totalSamples)"
    }
}

#Preview {
    NavigationStack {
        DiceFairnessDeepDiveView()
    }
}
