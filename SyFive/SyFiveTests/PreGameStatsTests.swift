import Foundation
import Testing
import SyLibScoring
@testable import SyFive

// PreGameStatsCard is main-actor isolated under the app target's default isolation, so the suite
// is too. 39 §2.5, Task 39.5.
@MainActor
struct PreGameStatsTests {

    private let me = UUID()

    /// A completed match on day `day`, `me` scoring `score` at `rank`, with one opponent per extra
    /// entry in `others` (rank, score). No `others` is a solo game.
    private func match(day: Int, score: Decimal, rank: Int = 1,
                       others: [(rank: Int, score: Decimal)] = []) -> Match {
        func participant(_ seat: Int, _ playerID: UUID, _ score: Decimal, _ rank: Int) -> Participant {
            Participant(id: UUID(), seat: seat, finalScore: score, rank: rank, bonusPoints: 0,
                        playerID: playerID, teamID: nil, displayName: "P\(seat)",
                        displayInitials: "P", displayThemeID: "", scoreEntries: [])
        }
        let start = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
        let opponents = others.enumerated().map { participant($0.offset + 1, UUID(), $0.element.score, $0.element.rank) }
        return Match(id: UUID(), gameID: UUID(), scoringSystemID: "yatzy", scoringSystemVersion: 1,
                     status: .completed, startedAt: start, completedAt: start.addingTimeInterval(600),
                     participants: [participant(0, me, score, rank)] + opponents, options: [:])
    }

    @Test("a solo table shows Games, Best and Avg from solo games only, with an insight from three or more")
    func soloUsesSoloGamesOnly() {
        let matches = [
            match(day: 1, score: 200),
            match(day: 2, score: 301, others: [(2, 150)]),   // multiplayer: ignored
            match(day: 3, score: 250),
            match(day: 4, score: 175),
            match(day: 5, score: 90, rank: 2, others: [(1, 320)]),   // multiplayer: ignored
        ]
        // 200 + 250 + 175 = 625, over 3 is 208.33…, shown whole; three solo games give an insight.
        guard case let .solo(games, best, average, insight) =
                PreGameStatsCard.content(playerID: me, playerCount: 1, matches: matches) else {
            Issue.record("expected a solo record")
            return
        }
        #expect(games == 3 && best == 250 && average == 208)
        #expect(insight != nil)

        // Two solo games: the record, and no insight, though there are multiplayer games too.
        let twoSolo = Array(matches.prefix(3))
        #expect(PreGameStatsCard.content(playerID: me, playerCount: 1, matches: twoSolo)
                == .solo(games: 2, best: 250, average: 225, insight: nil))
    }

    @Test("a three-player table shows Games, Wins and Win % from multiplayer games only")
    func threePlayerTableUsesMultiplayerGamesOnly() {
        let matches = [
            match(day: 1, score: 300),   // solo: ignored
            match(day: 2, score: 240, others: [(2, 200), (3, 150)]),
            match(day: 3, score: 180, rank: 2, others: [(1, 260), (3, 120)]),
            match(day: 4, score: 230, others: [(2, 210)]),
            match(day: 5, score: 310),   // solo: ignored
        ]
        // 2 wins in 3 multiplayer games is 66.6…%, shown whole as the profile does.
        #expect(PreGameStatsCard.content(playerID: me, playerCount: 3, matches: matches)
                == .table(games: 3, wins: 2, winPercent: 66))
    }

    @Test("a table with no games of its kind gives First game")
    func noGamesOfTheKindGiveFirstGame() {
        let multiplayerOnly = [
            match(day: 1, score: 240, others: [(2, 200)]),
            match(day: 2, score: 220, others: [(2, 210), (3, 150)]),
        ]
        let soloOnly = [match(day: 3, score: 180), match(day: 4, score: 210)]

        // A solo table with only multiplayer games, and the reverse; and no games at all.
        #expect(PreGameStatsCard.content(playerID: me, playerCount: 1, matches: multiplayerOnly) == .firstGame)
        #expect(PreGameStatsCard.content(playerID: me, playerCount: 3, matches: soloOnly) == .firstGame)
        #expect(PreGameStatsCard.content(playerID: me, playerCount: 4, matches: []) == .firstGame)
    }
}
