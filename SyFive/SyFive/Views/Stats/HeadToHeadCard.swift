import SwiftUI
import SyLibScoring
import SyLibUI
import SwiftData
import SyLibScoringData

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
        HeadToHeadCardContent(
            h2h: h2h,
            playerAName: playerAName,
            playerBName: playerBName,
            showsMeta: showsMeta,
            accent: theme.primaryAccent
        )
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
