import SwiftUI
import SyLibScoring
import Charts

/// Bar chart showing how often a player finishes in each place.
/// Accepts pre-computed `Distribution` from `placementSeries(playerID:matches:)`.
struct PlacementDistributionChart: View {
    let distribution: Distribution

    @Environment(\.theme) private var theme

    private struct PlacementEntry: Identifiable {
        let rank: Int
        let count: Int
        var id: Int { rank }
        var label: String {
            switch rank {
            case 1: return "1st"
            case 2: return "2nd"
            case 3: return "3rd"
            case 4: return "4th"
            default: return "\(rank)th"
            }
        }
    }

    private var entries: [PlacementEntry] {
        distribution.bins
            .sorted { $0.key < $1.key }
            .map { PlacementEntry(rank: $0.key, count: $0.value) }
    }

    var body: some View {
        if distribution.isEmpty {
            ContentUnavailableView("No games yet", systemImage: "chart.bar")
                .foregroundStyle(theme.primaryAccent)
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Place", entry.label),
                    y: .value("Games", entry.count)
                )
                .foregroundStyle(theme.secondaryAccent)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
    }
}

#Preview("Placement — Dark") {
    PlacementDistributionChart(distribution: Distribution(bins: [1: 5, 2: 2, 3: 1]))
        .frame(height: 200)
        .padding()
        .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
        .preferredColorScheme(.dark)
}

#Preview("Placement — Light") {
    PlacementDistributionChart(distribution: Distribution(bins: [1: 2, 2: 4]))
        .frame(height: 200)
        .padding()
        .environment(\.theme, Theme(type: .forest, colorScheme: .light))
}
