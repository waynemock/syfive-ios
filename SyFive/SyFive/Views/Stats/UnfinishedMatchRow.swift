import SwiftUI
import SyLibScoring

struct UnfinishedMatchRow: View {
    let match: Match

    @Environment(\.colorScheme) private var colorScheme

    private var sortedByScore: [Participant] {
        match.participants.sorted { $0.finalScore > $1.finalScore }
    }

    private var leader: Participant? { sortedByScore.first }

    private var leaderTheme: Theme {
        let themeType = leader.flatMap { Theme.ThemeType(rawValue: $0.displayThemeID) } ?? .midnight
        return Theme(type: themeType, colorScheme: colorScheme)
    }

    private var hasScores: Bool {
        match.participants.contains { $0.finalScore > 0 }
    }

    private var participantSummary: String {
        if hasScores {
            return sortedByScore
                .map { "\($0.displayName) \(Int(truncating: $0.finalScore as NSDecimalNumber))" }
                .joined(separator: " · ")
        } else {
            return match.participants.map(\.displayName).joined(separator: " · ")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.startedAt, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(leaderTheme.primaryAccent)
                Spacer()
                if let leader, match.participants.count > 1, hasScores {
                    Label(leader.displayName, systemImage: "trophy.fill")
                        .font(.subheadline)
                        .foregroundStyle(leaderTheme.primaryAccent)
                }
            }
            Text(participantSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
    }
}

#Preview {
    func makeMatch(hoursAgo: Int = 0,
                   _ players: [(name: String, theme: String, score: Int)]) -> Match {
        let start = Date().addingTimeInterval(Double(-hoursAgo) * 3_600)
        return Match(
            id: UUID(), gameID: UUID(),
            scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1, status: .inProgress,
            startedAt: start, completedAt: nil,
            participants: players.enumerated().map { i, p in
                Participant(
                    id: UUID(), seat: i,
                    finalScore: Decimal(p.score), rank: 0,
                    bonusPoints: 0, playerID: nil, teamID: nil,
                    displayName: p.name,
                    displayInitials: String(p.name.prefix(1)),
                    displayThemeID: p.theme,
                    scoreEntries: []
                )
            }
        )
    }

    return NavigationStack {
        List {
            // Sherida leading
            UnfinishedMatchRow(match: makeMatch([
                (name: "Wayne",   theme: "midnight", score: 120),
                (name: "Sherida", theme: "forest",   score: 185),
            ]))
            // Wayne leading, three players
            UnfinishedMatchRow(match: makeMatch(hoursAgo: 2, [
                (name: "Wayne",   theme: "midnight", score: 210),
                (name: "Sherida", theme: "forest",   score: 165),
                (name: "Weston",  theme: "midnight", score: 88),
            ]))
            // Not started yet — no scores
            UnfinishedMatchRow(match: makeMatch(hoursAgo: 48, [
                (name: "Wayne",   theme: "midnight", score: 0),
                (name: "Sherida", theme: "forest",   score: 0),
            ]))
            // Solo
            UnfinishedMatchRow(match: makeMatch(hoursAgo: 72, [
                (name: "Wayne", theme: "midnight", score: 95),
            ]))
        }
        .navigationTitle("Unfinished")
        .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}
