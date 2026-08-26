import SwiftUI
import SyLibScoring
import Charts

/// Line chart showing a player's final score across matches over time.
/// Accepts pre-computed `[DatedPoint]` from `scoreTrend(playerID:matches:)`.
struct ScoreTrendChart: View {
    let points: [DatedPoint]

    @Environment(\.theme) private var theme

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No games yet", systemImage: "chart.line.uptrend.xyaxis")
                .foregroundStyle(theme.primaryAccent)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                let score = NSDecimalNumber(decimal: point.value).doubleValue
                LineMark(
                    x: .value("Date", point.at),
                    y: .value("Score", score)
                )
                .foregroundStyle(theme.secondaryAccent)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.at),
                    y: .value("Score", score)
                )
                .foregroundStyle(theme.secondaryAccent)
                .symbolSize(36)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
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

#Preview("Score Trend — Dark") {
    ScoreTrendChart(points: [
        DatedPoint(at: Date().addingTimeInterval(-86400 * 6), value: 220),
        DatedPoint(at: Date().addingTimeInterval(-86400 * 5), value: 285),
        DatedPoint(at: Date().addingTimeInterval(-86400 * 4), value: 310),
        DatedPoint(at: Date().addingTimeInterval(-86400 * 3), value: 248),
        DatedPoint(at: Date().addingTimeInterval(-86400 * 2), value: 330),
        DatedPoint(at: Date().addingTimeInterval(-86400 * 1), value: 296),
    ])
    .frame(height: 220)
    .padding()
    .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
    .preferredColorScheme(.dark)
}

#Preview("Score Trend — Empty") {
    ScoreTrendChart(points: [])
        .frame(height: 220)
        .padding()
        .environment(\.theme, Theme(type: .ocean, colorScheme: .light))
}
