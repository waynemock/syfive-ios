import SwiftUI
import SwiftData

struct PlayerProfileView: View {
    let playerID:  UUID
    let playerName: String
    let themeType: Theme.ThemeType

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedModels: [MatchModel]

    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { Theme(type: themeType, colorScheme: colorScheme) }
    private var matches: [Match] { completedModels.map { $0.toDomain() } }

    private var insights: PlayerInsights? { playerInsights(playerID: playerID, matches: matches) }
    private var summary: PlayerSummary?   { playerSummary(playerID: playerID, matches: matches) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if summary != nil || insights != nil {
                        profileContent
                    } else {
                        ContentUnavailableView(
                            "No games yet",
                            systemImage: "chart.bar.xaxis",
                            description: Text("Finish a game to see your stats.")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(theme.backgroundColor)
            .navigationTitle(playerName)
            .navigationBarTitleDisplayMode(.large)
        }
        .tint(theme.primaryAccent)
        .environment(\.theme, theme)
    }

    // MARK: - Main layout

    @ViewBuilder
    private var profileContent: some View {
        // §5.1: Lead with the sentence, not a number.
        if let sentence = insights.flatMap({ plainLanguageRead($0) }) {
            Text(sentence)
                .font(.title3.weight(.medium))
                .foregroundStyle(theme.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.cellBackgroundColor)
                )
        }

        // Summary badges — secondary beneath the sentence.
        if let s = summary { statBadges(s) }

        // §5.1: Decisions above outcomes.
        if let style = insights?.style { styleCard(style) }
        if let risk  = insights?.risk  { riskCard(risk) }
        if let clutch = insights?.clutch, clutch.matchesAnalyzed >= 2 { clutchCard(clutch) }

        // Outcomes.
        if let prof = insights?.proficiency { proficiencyCard(prof) }
        if let cons = insights?.consistency { consistencyCard(cons) }

        // Trajectory.
        let trendPoints = scoreTrend(playerID: playerID, matches: matches)
        if !trendPoints.isEmpty {
            statsCard(title: "Score Trend") {
                ScoreTrendChart(points: trendPoints).frame(height: 160)
            }
        }

        let dist = placementSeries(playerID: playerID, matches: matches)
        if !dist.bins.isEmpty {
            statsCard(title: "Placements") {
                PlacementDistributionChart(distribution: dist).frame(height: 140)
            }
        }
    }

    // MARK: - Cards

    private func statBadges(_ s: PlayerSummary) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                badge(title: "Games", value: "\(s.matchesPlayed)")
                badge(title: "Wins",  value: "\(s.wins)")
                badge(title: "Win %", value: "\(Int(s.winRate * 100))%")
                badge(title: "Avg",   value: "\(Int(truncating: s.averageScore as NSDecimalNumber))")
            }
        }
    }

    private func badge(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(theme.primaryAccent)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.cellBackgroundColor))
    }

    private func styleCard(_ style: StyleSignature) -> some View {
        statsCard(title: "Your Style") {
            VStack(alignment: .leading, spacing: 6) {
                insightRow(label: sectionLeanLabel(style.sectionOrder))
                insightRow(label: bonusApproachLabel(style.bonusApproach))
                if let turn = style.averageYatzyTurn {
                    insightRow(label: yatzyTurnLabel(turn))
                }
                if let cat = style.typicalOpening {
                    insightRow(label: "Usually opens with \(cat.displayName)")
                }
            }
        }
    }

    private func riskCard(_ risk: RiskProfile) -> some View {
        statsCard(title: "Scratch Habits") {
            VStack(alignment: .leading, spacing: 6) {
                insightRow(label: scratchRateLabel(risk.totalScratchRate))
                if risk.yatzyEverZeroed {
                    insightRow(label: "Has zeroed Yatzy (\(Int(risk.yatzyZeroRate * 100))% of the time)")
                } else {
                    insightRow(label: "Never zeros Yatzy")
                }
                if risk.matchesWithTimestamps >= 2 {
                    insightRow(label: risk.earlyZeroRate > 0.6
                        ? "Tends to zero categories early and strategically"
                        : "Zeros come late when forced")
                }
            }
        }
    }

    private func clutchCard(_ clutch: ClutchProfile) -> some View {
        statsCard(title: "Closing Strength") {
            VStack(alignment: .leading, spacing: 6) {
                insightRow(label: backHalfLabel(clutch.backHalfVsFront))
                if clutch.comebacksWon > 0 {
                    insightRow(label: "\(clutch.comebacksWon) comeback \(clutch.comebacksWon == 1 ? "win" : "wins") from behind")
                }
                if clutch.leadsSurrendered > 0 {
                    insightRow(label: "\(clutch.leadsSurrendered) lead\(clutch.leadsSurrendered == 1 ? "" : "s") surrendered late")
                }
            }
        }
    }

    private func proficiencyCard(_ prof: Proficiency) -> some View {
        statsCard(title: "Category Strengths") {
            VStack(alignment: .leading, spacing: 8) {
                if !prof.strongest.isEmpty {
                    categoryGroup(title: "Carrying the score:", categories: prof.strongest)
                }
                let cold = prof.coldest.filter { !prof.strongest.contains($0) }
                if !cold.isEmpty {
                    categoryGroup(title: "Room to grow:", categories: cold)
                }
                // Upper-pace notes for any category clearly above or below pace.
                let notable = prof.upperPaceNotes
                    .filter { _, v in abs(v.average - v.pace) >= 2 }
                    .sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { cat, note -> String in
                        let avg  = Int(truncating: note.average as NSDecimalNumber)
                        let pace = Int(truncating: note.pace as NSDecimalNumber)
                        let rel  = avg >= pace ? "on pace" : "\(pace - avg) below pace"
                        return "\(cat.displayName) avg \(avg) — \(rel) for bonus"
                    }
                ForEach(notable, id: \.self) { label in
                    insightRow(label: label)
                }
            }
        }
    }

    private func consistencyCard(_ cons: ConsistencyProfile) -> some View {
        statsCard(title: "Consistency") {
            VStack(alignment: .leading, spacing: 6) {
                let minS = Int(truncating: cons.scoreSpread.min as NSDecimalNumber)
                let maxS = Int(truncating: cons.scoreSpread.max as NSDecimalNumber)
                let medS = Int(truncating: cons.scoreSpread.median as NSDecimalNumber)
                insightRow(label: cons.variability == .steady
                    ? "Steady scorer (±\(Int(truncating: cons.stdDev as NSDecimalNumber)) pts)"
                    : "Swingy — big nights and quiet ones")
                insightRow(label: "Range \(minS)–\(maxS), median \(medS)")
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statsCard<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.horizontal, 2)
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.cellBackgroundColor))
    }

    private func insightRow(label: String) -> some View {
        Label(label, systemImage: "circle.fill")
            .font(.subheadline)
            .foregroundStyle(.primary)
            .symbolRenderingMode(.palette)
            .foregroundStyle(theme.primaryAccent, .primary)
            .labelStyle(InsightLabelStyle())
    }

    private func categoryGroup(title: String, categories: [YatzyCategory]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(categories.map(\.displayName).joined(separator: ", "))
                .font(.subheadline)
        }
    }

    // MARK: - Label formatters (neutral-to-affirming per §5.4)

    private func sectionLeanLabel(_ lean: SectionLean) -> String {
        switch lean {
        case .upperFirst: return "Upper-section focused"
        case .lowerFirst: return "Lower-section focused"
        case .balanced:   return "Balanced section approach"
        }
    }

    private func bonusApproachLabel(_ approach: BonusApproach) -> String {
        switch approach {
        case .lockEarly: return "Locks the upper bonus early in the game"
        case .backfill:  return "Builds the upper section through the game"
        case .neglect:   return "Focuses scoring in the lower section"
        }
    }

    private func yatzyTurnLabel(_ turn: Double) -> String {
        let t = String(format: "%.1f", turn)
        if turn < 6  { return "Secures Yatzy early (avg turn \(t))" }
        if turn < 10 { return "Plays Yatzy mid-game (avg turn \(t))" }
        return "Holds for Yatzy late (avg turn \(t))"
    }

    private func scratchRateLabel(_ rate: Double) -> String {
        let pct = Int(rate * 100)
        if rate < 0.04 { return "Rarely scratches (\(pct)%)" }
        if rate < 0.10 { return "Occasional scratches (\(pct)%)" }
        return "Uses zeros as a tool (\(pct)%)"
    }

    private func backHalfLabel(_ delta: Decimal) -> String {
        let d = Double(truncating: delta as NSDecimalNumber)
        if d > 2  { return "Strong closer — scores more in the back half" }
        if d < -2 { return "Front-loaded — builds leads early" }
        return "Scores evenly throughout the game"
    }
}

private struct InsightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 6) {
            configuration.icon.font(.system(size: 5)).padding(.top, 6)
            configuration.title
        }
    }
}

#Preview {
    PlayerProfileView(playerID: UUID(), playerName: "Wayne", themeType: .midnight)
        .modelContainer(for: MatchModel.self, inMemory: true)
}
