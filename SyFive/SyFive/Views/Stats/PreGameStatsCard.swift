import SwiftUI
import SwiftData
import SyLibScoring
import SyLibScoringData
import SyLibUI
import SyLibYatzy

/// Pre-game stats in a player card's foot (39 §2.5, §2.7, §2.8, D-211): the player's record for the
/// table they're at, from completed games. Fetches its own completed-match data via @Query, as
/// `HeadToHeadCard`.
/// - Solo table: solo games, Games / Best / Avg, then "Score to beat", then the profile's opening
///   sentence from the solo games, when there is one. The insight is for a solo table only.
/// - Three or four: multiplayer games, Games / Wins / Win %.
/// - No games of the table's kind: "First game, no stats yet."
/// A two-player table shows `HeadToHeadCard` instead.
struct PreGameStatsCard: View {
    let playerID: UUID
    let playerCount: Int
    let theme: SyTheme

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedRows: [MatchModel]
    /// One row per match id, so a game two devices both stored counts once (34 §2.8).
    private var completedModels: [MatchModel] { completedRows.onePerMatchID() }

    /// The row the card draws.
    enum Record: Equatable {
        /// `insight`: `plainLanguageRead` over the solo games; nil under three games or when
        /// there's nothing to say.
        case solo(games: Int, best: Int, average: Int, insight: String?)
        case table(games: Int, wins: Int, winPercent: Int)
        /// No games of the table's kind yet.
        case firstGame
    }

    /// Chooses the card's record. Solo games are those with one participant, multiplayer games
    /// more than one, as the profile splits them; the figures are the profile's (`playerSummary`)
    /// over the table's kind, and a solo record's insight is the profile's sentence over the same
    /// solo games (39 §2.8). Internal for tests. `matches` sorted by `startedAt`, as the profile's.
    static func content(playerID: UUID, playerCount: Int, matches: [Match]) -> Record {
        let isSolo = playerCount == 1
        let games = matches.filter { isSolo ? $0.participants.count == 1 : $0.participants.count > 1 }
        guard let summary = playerSummary(playerID: playerID, matches: games) else { return .firstGame }
        return isSolo
            ? .solo(games: summary.matchesPlayed, best: summary.bestScore.displayInt,
                    average: summary.averageScore.displayInt,
                    insight: playerInsights(playerID: playerID, matches: games).flatMap { plainLanguageRead($0) })
            : .table(games: summary.matchesPlayed, wins: summary.wins,
                     winPercent: Int(summary.winRate * 100))
    }

    private var record: Record {
        Self.content(playerID: playerID, playerCount: playerCount,
                     matches: completedModels.map { $0.toDomain() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch record {
            case let .solo(games, best, average, insight):
                figures([("Games", "\(games)"), ("Best", "\(best)"), ("Avg", "\(average)")])
                Text("Score to beat: \(best)")
                    .font(.subheadline)
                if let insight {
                    Text(insight)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case let .table(games, wins, winPercent):
                figures([("Games", "\(games)"), ("Wins", "\(wins)"), ("Win %", "\(winPercent)%")])
            case .firstGame:
                Text("First game, no stats yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// One row of three figures, smaller than the profile's badges.
    private func figures(_ items: [(title: String, value: String)]) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.title) { item in
                VStack(spacing: 2) {
                    Text(item.value).font(.headline.weight(.bold)).foregroundStyle(theme.secondaryAccent)
                    Text(item.title).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cellBackgroundColor))
                // One VoiceOver element per figure: "Games, 12".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.title), \(item.value)")
            }
        }
    }
}

// MARK: - Decimal display helper

private extension Decimal {
    // As the profile's `displayInt`: Int(truncating: fractionalDecimal as NSDecimalNumber) returns
    // 0 for values produced by division (Foundation bug), so an average would show 0. Routing
    // through doubleValue is reliable for the small integer ranges used in game scores.
    var displayInt: Int { Int((self as NSDecimalNumber).doubleValue) }
}

#Preview("Pre-game stats – no games") {
    PreGameStatsCard(playerID: UUID(), playerCount: 1,
                     theme: SyTheme(type: .midnight, colorScheme: .dark))
        .padding()
        .modelContainer(for: MatchModel.self, inMemory: true)
}
