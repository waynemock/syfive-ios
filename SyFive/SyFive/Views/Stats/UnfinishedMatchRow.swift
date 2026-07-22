import SwiftUI

struct UnfinishedMatchRow: View {
    let match: Match

    private var playerNames: String {
        let names = match.participants.map(\.displayName)
        return names.isEmpty ? "No players" : names.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(match.startedAt, style: .date)
                .font(.subheadline.weight(.semibold))
            Text(playerNames)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    func makeMatch(hoursAgo: Int = 0,
                   _ names: [(name: String, theme: String)]) -> Match {
        let start = Date().addingTimeInterval(Double(-hoursAgo) * 3_600)
        return Match(
            id: UUID(), gameID: UUID(),
            scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1, status: .inProgress,
            startedAt: start, completedAt: nil,
            participants: names.enumerated().map { i, p in
                Participant(
                    id: UUID(), seat: i,
                    finalScore: 0, rank: 0,
                    yahtzeeBonus: 0, playerID: nil, teamID: nil,
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
            UnfinishedMatchRow(match: makeMatch([
                (name: "Wayne",   theme: "midnight"),
                (name: "Sherida", theme: "forest"),
            ]))
            UnfinishedMatchRow(match: makeMatch(hoursAgo: 2, [
                (name: "Wayne",   theme: "midnight"),
                (name: "Sherida", theme: "forest"),
                (name: "Weston",  theme: "midnight"),
            ]))
            UnfinishedMatchRow(match: makeMatch(hoursAgo: 48, [
                (name: "Wayne", theme: "midnight"),
            ]))
        }
        .navigationTitle("Unfinished")
        .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}
