import SwiftUI
import SyLibUI
import SyLibScoring
import SyLibScoringUI
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
    private var completedRows: [MatchModel]
    /// One row per match id, so a game two devices both stored counts once (34 §2.8).
    private var completedModels: [MatchModel] { completedRows.onePerMatchID() }

    @Environment(\.syTheme) private var theme

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
    .environment(\.syTheme, SyTheme(type: .midnight, colorScheme: .dark))
    .modelContainer(for: MatchModel.self, inMemory: true)
}
