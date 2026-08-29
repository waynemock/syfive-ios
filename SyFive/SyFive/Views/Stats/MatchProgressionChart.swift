import SwiftUI
import SyLibScoring
import SyLibYatzy
import Charts

/// Multi-line race chart showing all participants' running totals across a match.
/// Accepts a pre-computed `MatchProgression` and a participantID → display name map.
/// Colors are assigned automatically per participant by the Charts framework.
struct MatchProgressionChart: View {
    let progression: MatchProgression
    let playerNames: [UUID: String]    // participantID → display name
    let playerColors: [UUID: Color]    // participantID → theme primaryAccent

    // Parallel arrays for chartForegroundStyleScale(domain:range:).
    private var colorScaleDomain: [String] {
        progression.participants.map { playerNames[$0.participantID] ?? "Player" }
    }
    private var colorScaleRange: [Color] {
        progression.participants.map { playerColors[$0.participantID] ?? .accentColor }
    }

    var body: some View {
        if progression.participants.allSatisfy({ $0.points.isEmpty }) {
            ContentUnavailableView("No progression data", systemImage: "chart.line.uptrend.xyaxis")
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(progression.participants, id: \.participantID) { prog in
                let name = playerNames[prog.participantID] ?? "Player"
                ForEach(Array(prog.points.enumerated()), id: \.offset) { _, step in
                    LineMark(
                        x: .value("Time", step.at),
                        y: .value("Score", NSDecimalNumber(decimal: step.runningTotal).doubleValue)
                    )
                    .foregroundStyle(by: .value("Player", name))
                    .interpolationMethod(.stepEnd)
                }
            }
        }
        .chartForegroundStyleScale(domain: colorScaleDomain, range: colorScaleRange)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(position: .bottom, alignment: .center)
    }
}

#Preview {
    let id1 = UUID()
    let id2 = UUID()
    let base = Date()
    let sampleProgression = MatchProgression(
        matchID: UUID(),
        participants: [
            ParticipantProgression(participantID: id1, points: [
                ProgressionStep(at: base.addingTimeInterval(-1800), category: .ones,         runningTotal: 3),
                ProgressionStep(at: base.addingTimeInterval(-1500), category: .sixes,        runningTotal: 68),
                ProgressionStep(at: base.addingTimeInterval(-1200), category: .threeOfAKind, runningTotal: 88),
                ProgressionStep(at: base.addingTimeInterval(-900),  category: .yatzy,      runningTotal: 138),
                ProgressionStep(at: base.addingTimeInterval(-600),  category: .chance,       runningTotal: 164),
            ]),
            ParticipantProgression(participantID: id2, points: [
                ProgressionStep(at: base.addingTimeInterval(-1750), category: .ones,         runningTotal: 2),
                ProgressionStep(at: base.addingTimeInterval(-1450), category: .sixes,        runningTotal: 56),
                ProgressionStep(at: base.addingTimeInterval(-1150), category: .threeOfAKind, runningTotal: 74),
                ProgressionStep(at: base.addingTimeInterval(-850),  category: .yatzy,      runningTotal: 124),
                ProgressionStep(at: base.addingTimeInterval(-550),  category: .chance,       runningTotal: 148),
            ]),
        ],
        leadChanges: 0,
        largestLead: nil,
        comebackFrom: nil
    )
    MatchProgressionChart(
        progression: sampleProgression,
        playerNames: [id1: "Alex", id2: "Sam"],
        playerColors: [id1: Theme(type: .midnight, colorScheme: .dark).primaryAccent,
                       id2: Theme(type: .blossom, colorScheme: .dark).primaryAccent]
    )
    .frame(height: 260)
    .padding()
    .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
    .preferredColorScheme(.dark)
}
