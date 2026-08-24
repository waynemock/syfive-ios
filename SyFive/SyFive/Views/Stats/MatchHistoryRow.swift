import SwiftUI

struct MatchHistoryRow: View {
    let match: Match

    @Environment(\.colorScheme) private var colorScheme

    private var sortedParticipants: [Participant] {
        match.participants.sorted { $0.rank < $1.rank }
    }

    private var winners: [Participant] {
        sortedParticipants.filter { $0.rank == 1 }
    }

    private var winnerLabel: String {
        winners.map(\.displayName).joined(separator: " & ")
    }

    private var winnerTheme: Theme {
        let themeType = winners.first.flatMap { Theme.ThemeType(rawValue: $0.displayThemeID) } ?? .midnight
        return Theme(type: themeType, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.startedAt, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(winnerTheme.primaryAccent)
                Spacer()
                if !winnerLabel.isEmpty {
                    Label(winnerLabel, systemImage: "trophy.fill")
                        .font(.subheadline)
                        .foregroundStyle(winnerTheme.primaryAccent)
                }
            }
            Text(
                sortedParticipants
                    .map { "\($0.displayName) \(Int(truncating: $0.finalScore as NSDecimalNumber))" }
                    .joined(separator: " · ")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 2)
        .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
    }
}

#Preview {
    func makeMatch(daysAgo: Int = 0,
                   _ players: [(name: String, theme: String, score: Int, rank: Int)]) -> Match {
        let start = Date().addingTimeInterval(Double(-daysAgo) * 86_400)
        return Match(
            id: UUID(), gameID: UUID(),
            scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1, status: .completed,
            startedAt: start, completedAt: start.addingTimeInterval(1_800),
            participants: players.enumerated().map { i, p in
                Participant(
                    id: UUID(), seat: i,
                    finalScore: Decimal(p.score), rank: p.rank,
                    yatzyBonus: 0, playerID: nil, teamID: nil,
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
            // Wayne wins
            MatchHistoryRow(match: makeMatch([
                (name: "Wayne",   theme: "midnight", score: 310, rank: 1),
                (name: "Sherida", theme: "forest",   score: 245, rank: 2),
            ]))
            // Sherida wins the next day
            MatchHistoryRow(match: makeMatch(daysAgo: 1, [
                (name: "Sherida", theme: "forest",   score: 328, rank: 1),
                (name: "Wayne",   theme: "midnight", score: 271, rank: 2),
            ]))
            // Three players — two tied for first
            MatchHistoryRow(match: makeMatch(daysAgo: 2, [
                (name: "Sherida", theme: "forest",   score: 270, rank: 1),
                (name: "Wayne",   theme: "midnight", score: 270, rank: 1),
                (name: "Weston",  theme: "midnight", score: 198, rank: 2),
            ]))
            // Solo game
            MatchHistoryRow(match: makeMatch(daysAgo: 5, [
                (name: "Wayne", theme: "midnight", score: 290, rank: 1),
            ]))
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}
