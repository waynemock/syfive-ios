import SwiftUI
import SwiftData

struct PlayerProfileView: View {
    let playerID: UUID
    let playerName: String
    let themeType: Theme.ThemeType

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedModels: [MatchModel]

    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { Theme(type: themeType, colorScheme: colorScheme) }
    private var matches: [Match] { completedModels.map { $0.toDomain() } }
    private var summary: PlayerSummary? { playerSummary(playerID: playerID, matches: matches) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let summary {
                        statBadges(summary)

                        let trendPoints = scoreTrend(playerID: playerID, matches: matches)
                        if !trendPoints.isEmpty {
                            statsCard(title: "Score Trend") {
                                ScoreTrendChart(points: trendPoints)
                                    .frame(height: 160)
                            }
                        }

                        let dist = placementSeries(playerID: playerID, matches: matches)
                        if !dist.bins.isEmpty {
                            statsCard(title: "Placements") {
                                PlacementDistributionChart(distribution: dist)
                                    .frame(height: 140)
                            }
                        }
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

    private func statBadges(_ summary: PlayerSummary) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                badge(title: "Games", value: "\(summary.matchesPlayed)")
                badge(title: "Wins", value: "\(summary.wins)")
                badge(title: "Win %", value: "\(Int(summary.winRate * 100))%")
                badge(title: "Avg Score", value: "\(Int(truncating: summary.averageScore as NSDecimalNumber))")
            }
        }
    }

    private func badge(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryAccent)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cellBackgroundColor)
        )
    }

    @ViewBuilder
    private func statsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 2)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cellBackgroundColor)
        )
    }
}

#Preview {
    PlayerProfileView(
        playerID: UUID(),
        playerName: "Wayne",
        themeType: .midnight
    )
    .modelContainer(for: MatchModel.self, inMemory: true)
}
