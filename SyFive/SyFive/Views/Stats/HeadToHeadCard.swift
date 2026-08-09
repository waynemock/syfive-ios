import SwiftUI
import SwiftData

/// The "signature moment" card — shown in pre-game player cards when two roster players
/// are about to face each other. Fetches its own completed-match data via @Query.
struct HeadToHeadCard: View {
    let playerAID: UUID
    let playerAName: String
    let playerBID: UUID
    let playerBName: String
    var showsMeta: Bool = true

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedModels: [MatchModel]

    @Environment(\.theme) private var theme

    private var h2h: HeadToHead {
        headToHead(playerA: playerAID, playerB: playerBID,
                   matches: completedModels.map { $0.toDomain() })
    }

    var body: some View {
        if h2h.sharedMatches == 0 {
            Label("First matchup — no history yet", systemImage: "flag.checkered")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                winsRow
                if showsMeta {
                    metaText
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var winsRow: some View {
        HStack(spacing: 0) {
            playerPill(name: playerAName, wins: h2h.matchWinsA,
                       isLeader: h2h.matchWinsA > h2h.matchWinsB)
            Text("–")
                .font(.title2.weight(.thin))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
            playerPill(name: playerBName, wins: h2h.matchWinsB,
                       isLeader: h2h.matchWinsB > h2h.matchWinsA)
        }
    }

    private func playerPill(name: String, wins: Int, isLeader: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(wins)")
                .font(.title2.weight(.bold))
                .foregroundStyle(isLeader ? theme.primaryAccent : Color.primary.opacity(0.55))
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var metaText: Text {
        var parts: [String] = [h2h.sharedMatches == 1 ? "1 game" : "\(h2h.sharedMatches) games"]
        if h2h.sharedTies > 0 {
            parts.append(h2h.sharedTies == 1 ? "1 tie" : "\(h2h.sharedTies) ties")
        }
        if let last = h2h.lastMeeting {
            parts.append("Last: \(last.formatted(date: .abbreviated, time: .omitted))")
        }
        return Text(parts.joined(separator: " · "))
    }
}

#Preview("H2H – First Matchup") {
    HeadToHeadCard(
        playerAID: UUID(),
        playerAName: "Wayne",
        playerBID: UUID(),
        playerBName: "Sherida"
    )
    .padding()
    .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
    .modelContainer(for: MatchModel.self, inMemory: true)
}
