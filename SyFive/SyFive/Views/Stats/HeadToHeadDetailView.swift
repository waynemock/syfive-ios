import SwiftUI
import SyLibScoring
import SyLibScoringUI
import SwiftData
import SyLibScoringData

struct HeadToHeadDetailView: View {
    let profilePlayerName: String
    let profileAccent: Color
    let profileBackgroundColor: Color
    let profileCellBackgroundColor: Color
    let opponentName: String
    let opponentAccent: Color
    let h2h: HeadToHead

    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt, order: .reverse)
    private var completedModels: [MatchModel]

    private var sharedMatchModels: [MatchModel] {
        let aID = h2h.playerA
        let bID = h2h.playerB
        return completedModels.filter { m in
            let parts = m.participants
            return parts.contains { $0.playerID == aID } && parts.contains { $0.playerID == bID }
        }
    }

    private var sharedMatchesWithColors: [(match: Match, accentColor: Color)] {
        sharedMatchModels.map { model in
            let m = model.toDomain()
            let winner = m.participants.sorted { $0.rank < $1.rank }.first { $0.rank == 1 }
            return (m, Theme.accent(forParticipant: winner, colorScheme: colorScheme))
        }
    }

    var body: some View {
        HeadToHeadDetailContent(
            h2h: h2h,
            profilePlayerName: profilePlayerName,
            opponentName: opponentName,
            profileAccent: profileAccent,
            opponentAccent: opponentAccent,
            profileBackgroundColor: profileBackgroundColor,
            profileCellBackgroundColor: profileCellBackgroundColor,
            sharedMatches: sharedMatchesWithColors
        ) { match in
            if let model = sharedMatchModels.first(where: { $0.id == match.id }) {
                MatchDetailView(matchModel: model)
            }
        }
    }
}

#Preview {
    let h2h = HeadToHead(
        playerA: UUID(), playerB: UUID(),
        sharedMatches: 7, matchWinsA: 4, matchWinsB: 2, sharedTies: 0,
        pairwiseAheadA: 5, pairwiseAheadB: 2, pairwiseTies: 0,
        averageScoreA: 247, averageScoreB: 231,
        lastMeeting: Date(), currentStreakA: 2
    )
    HeadToHeadDetailView(
        profilePlayerName: "Wayne",
        profileAccent: Color(red: 0.60, green: 0.50, blue: 0.90),
        profileBackgroundColor: Color(red: 0.05, green: 0.05, blue: 0.08),
        profileCellBackgroundColor: Color(red: 0.10, green: 0.10, blue: 0.15),
        opponentName: "Sherida",
        opponentAccent: Color(red: 0.30, green: 0.70, blue: 0.45),
        h2h: h2h
    )
    .modelContainer(for: MatchModel.self, inMemory: true)
}
