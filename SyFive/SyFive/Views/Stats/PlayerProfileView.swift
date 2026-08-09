import SwiftUI
import SwiftData

struct PlayerProfileView: View {
    let playerID:  UUID
    let playerName: String
    let themeType: Theme.ThemeType


    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedModels: [MatchModel]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var profileMode: ProfileMode = .pvp

    private enum ProfileMode: Hashable { case pvp, solo }

    private var theme: Theme { Theme(type: themeType, colorScheme: colorScheme) }
    private var matches: [Match] { completedModels.map { $0.toDomain() } }

    private var pvpMatches: [Match]  { matches.filter { $0.participants.count > 1 } }
    private var soloMatches: [Match] { matches.filter { $0.participants.count == 1 } }

    /// True only when both PvP and solo data exist — drives picker visibility.
    private var showsModePicker: Bool { !pvpMatches.isEmpty && !soloMatches.isEmpty }

    /// Resolved match set: falls back to whichever kind has data when there's no choice.
    private var activeMatches: [Match] {
        if pvpMatches.isEmpty  { return soloMatches }
        if soloMatches.isEmpty { return pvpMatches }
        return profileMode == .pvp ? pvpMatches : soloMatches
    }

    /// True when `activeMatches` resolves to solo games (controls badge set and chart visibility).
    private var showingSoloStats: Bool {
        !soloMatches.isEmpty && (pvpMatches.isEmpty || profileMode == .solo)
    }

    private var opponentRecords: [OpponentRecord] {
        var latestInfo: [UUID: (name: String, initials: String, themeType: Theme.ThemeType, date: Date)] = [:]
        for match in pvpMatches {
            for p in match.participants {
                guard let oid = p.playerID, oid != playerID else { continue }
                let pThemeType = Theme.ThemeType(rawValue: p.displayThemeID) ?? .midnight
                if let existing = latestInfo[oid], existing.date >= match.startedAt { continue }
                latestInfo[oid] = (p.displayName, p.displayInitials, pThemeType, match.startedAt)
            }
        }
        return latestInfo.map { oid, info in
            OpponentRecord(
                opponentID: oid,
                opponentName: info.name,
                opponentInitials: info.initials,
                opponentThemeType: info.themeType,
                h2h: headToHead(playerA: playerID, playerB: oid, matches: pvpMatches)
            )
        }
        .filter { $0.h2h.sharedMatches > 0 }
        .sorted { ($0.h2h.lastMeeting ?? .distantPast) > ($1.h2h.lastMeeting ?? .distantPast) }
    }

    private var insights: PlayerInsights? { playerInsights(playerID: playerID, matches: activeMatches) }
    private var summary: PlayerSummary?   { playerSummary(playerID: playerID, matches: activeMatches) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showsModePicker {
                        Picker("Mode", selection: $profileMode) {
                            Text("PvP").tag(ProfileMode.pvp)
                            Text("Solo").tag(ProfileMode.solo)
                        }
                        .pickerStyle(.segmented)
                    }

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
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

        // PvP badges: Games / Wins / Win% / Avg
        // Solo badges: Games / Best / Avg / Median  (rank and win-rate are meaningless solo)
        if let s = summary {
            if showingSoloStats {
                soloBadges(s)
            } else {
                statBadges(s)
            }
        }

        // §5.1: Decisions above outcomes.
        if let style = insights?.style { styleCard(style) }
        if let risk  = insights?.risk  { riskCard(risk) }
        if let clutch = insights?.clutch, clutch.matchesAnalyzed >= 2 { clutchCard(clutch) }

        // Outcomes.
        if let prof = insights?.proficiency { proficiencyCard(prof) }
        if let cons = insights?.consistency { consistencyCard(cons) }

        // Trajectory.
        let trendPoints = scoreTrend(playerID: playerID, matches: activeMatches)
        if !trendPoints.isEmpty {
            statsCard(title: "Score Trend") {
                ScoreTrendChart(points: trendPoints).frame(height: 160)
            }
        }

        // Placement distribution is only meaningful for competitive games —
        // solo always places 1st, so the histogram is a single full bar.
        let dist = placementSeries(playerID: playerID, matches: activeMatches)
        if !showingSoloStats && !dist.bins.isEmpty {
            statsCard(title: "Placements") {
                PlacementDistributionChart(distribution: dist).frame(height: 140)
            }
        }

        // Per-opponent head-to-head breakdown.
        if !showingSoloStats {
            opponentsSection
        }
    }

    // MARK: - Cards

    private func statBadges(_ s: PlayerSummary) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                badge(title: "Games", value: "\(s.matchesPlayed)")
                badge(title: "Wins",  value: "\(s.wins)")
                if s.ties > 0 {
                    badge(title: "Tied", value: "\(s.ties)")
                }
                badge(title: "Win %", value: "\(Int(s.winRate * 100))%")
            }
            GridRow {
                badge(title: "Best",   value: "\(s.bestScore.displayInt)")
                badge(title: "Avg",    value: "\(s.averageScore.displayInt)")
                badge(title: "Median", value: "\(s.medianScore.displayInt)")
            }
        }
    }

    private func soloBadges(_ s: PlayerSummary) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                badge(title: "Games",  value: "\(s.matchesPlayed)")
                badge(title: "Best",   value: "\(s.bestScore.displayInt)")
                badge(title: "Avg",    value: "\(s.averageScore.displayInt)")
                badge(title: "Median", value: "\(s.medianScore.displayInt)")
            }
        }
    }

    private func badge(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(theme.secondaryAccent)
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
                    insightRow(label: clutch.comebacksWon == 1
                        ? "1 comeback win from behind"
                        : "\(clutch.comebacksWon) comeback wins from behind")
                }
                if clutch.leadsSurrendered > 0 {
                    insightRow(label: clutch.leadsSurrendered == 1
                        ? "1 lead surrendered late"
                        : "\(clutch.leadsSurrendered) leads surrendered late")
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
                        let avg  = note.average.displayInt
                        let pace = note.pace.displayInt
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
                let minS = cons.scoreSpread.min.displayInt
                let maxS = cons.scoreSpread.max.displayInt
                let medS = cons.scoreSpread.median.displayInt
                insightRow(label: cons.variability == .steady
                    ? "Steady scorer (±\(cons.stdDev.displayInt) pts)"
                    : "Swingy — big nights and quiet ones")
                insightRow(label: "Range \(minS)–\(maxS), median \(medS)")
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var opponentsSection: some View {
        if !opponentRecords.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Opponents")
                    .font(.headline)
                    .padding(.horizontal, 2)
                ForEach(opponentRecords) { record in
                    OpponentSummaryRow(
                        profilePlayerName: playerName,
                        profileThemeType: themeType,
                        record: record
                    )
                }
            }
        }
    }

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

// MARK: - Decimal display helper

private extension Decimal {
    // Int(truncating: fractionalDecimal as NSDecimalNumber) returns 0 for values
    // produced by division (Foundation bug). Routing through doubleValue is reliable
    // for the small integer ranges used in game scores.
    var displayInt: Int { Int((self as NSDecimalNumber).doubleValue) }
}

private struct InsightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        InsightLabelBody(configuration: configuration)
    }

    private struct InsightLabelBody: View {
        let configuration: LabelStyleConfiguration
        @ScaledMetric private var iconSize: CGFloat = 5

        var body: some View {
            HStack(alignment: .top, spacing: 6) {
                configuration.icon.font(.system(size: iconSize)).padding(.top, 6)
                configuration.title
            }
        }
    }
}

#Preview {
    PlayerProfileView(playerID: UUID(), playerName: "Wayne", themeType: .midnight)
        .modelContainer(for: MatchModel.self, inMemory: true)
}
