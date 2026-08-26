import Foundation
import SyLibScoring
@testable import SyFive

// Synthetic completed Match values for unit-testing Domain/Stats/.
// Numbers are hand-authored so Stage 2+ tests can assert exact values
// without re-running live game logic.
//
// Tier 1 fixtures: finalScore + rank set; scoreEntries empty.
//   Used for PlayerSummary, HeadToHead, RecordsBoard, streaks.
//
// Tier 2 fixture: full 13-category scorecards with recordedAt stamps.
//   Used for CategoryStats, UpperSectionStats, YatzyStats, progression.

// MARK: - Stable identifiers

enum FixtureID {
    static let playerA  = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let playerB  = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    static let playerC  = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    static let yatzyGame = UUID(uuidString: "59A71E00-0000-0000-0000-000000000001")!
    // Anchor: 2025-01-01 00:00:00 UTC — no DST drift.
    static let epoch = Date(timeIntervalSince1970: 1_735_689_600)
    static func date(daysAfter n: Int) -> Date {
        epoch.addingTimeInterval(Double(n) * 86_400)
    }
}

// MARK: - Fixtures

enum StatsFixtures {

    // MARK: Tier 1 — Heads-up A vs B (4 matches, no scorecards)
    //
    // Known outcomes for Stage 2 H2H(A,B) assertions over these 4:
    //   matchWinsA=2 (h2h_1, h2h_3)   matchWinsB=1 (h2h_2)   sharedTies=1 (h2h_4_tie)
    //   pairwiseAheadA=2   pairwiseAheadB=1   pairwiseTies=1
    //   averageScoreA=(310+220+330+270)/4=282.5
    //   averageScoreB=(240+285+255+270)/4=262.5

    static let h2h_1 = makeMatch(
        startedAt: FixtureID.date(daysAfter: 0),
        participants: [
            makeParticipant(playerID: FixtureID.playerA, seat: 0, finalScore: 310, rank: 1),
            makeParticipant(playerID: FixtureID.playerB, seat: 1, finalScore: 240, rank: 2)
        ]
    )

    static let h2h_2 = makeMatch(
        startedAt: FixtureID.date(daysAfter: 1),
        participants: [
            makeParticipant(playerID: FixtureID.playerA, seat: 0, finalScore: 220, rank: 2),
            makeParticipant(playerID: FixtureID.playerB, seat: 1, finalScore: 285, rank: 1)
        ]
    )

    static let h2h_3 = makeMatch(
        startedAt: FixtureID.date(daysAfter: 2),
        participants: [
            makeParticipant(playerID: FixtureID.playerA, seat: 0, finalScore: 330, rank: 1),
            makeParticipant(playerID: FixtureID.playerB, seat: 1, finalScore: 255, rank: 2)
        ]
    )

    // Tie — both share rank 1. Credited to neither's win column.
    static let h2h_4_tie = makeMatch(
        startedAt: FixtureID.date(daysAfter: 3),
        participants: [
            makeParticipant(playerID: FixtureID.playerA, seat: 0, finalScore: 270, rank: 1),
            makeParticipant(playerID: FixtureID.playerB, seat: 1, finalScore: 270, rank: 1)
        ]
    )

    // MARK: Tier 1 — Three-player A vs B vs C (2 matches, no scorecards)
    //
    //   three_1: A wins, B 2nd, C last
    //   three_2: B wins, A 2nd, C last
    //
    // Player A across all 6 Tier 1 matches:
    //   matchesPlayed=6, wins=3 (h2h_1, h2h_3, three_1)
    //   scores=[310,220,330,270,320,295] → avg≈290.83, best=330, worst=220
    //   placement dist: {1:4, 2:2}  (rank=1 includes tie in h2h_4)
    //
    // Player C across 2 matches: matchesPlayed=2, wins=0, rank always=3

    static let three_1 = makeMatch(
        startedAt: FixtureID.date(daysAfter: 4),
        participants: [
            makeParticipant(playerID: FixtureID.playerA, seat: 0, finalScore: 320, rank: 1),
            makeParticipant(playerID: FixtureID.playerB, seat: 1, finalScore: 260, rank: 2),
            makeParticipant(playerID: FixtureID.playerC, seat: 2, finalScore: 190, rank: 3)
        ]
    )

    static let three_2 = makeMatch(
        startedAt: FixtureID.date(daysAfter: 5),
        participants: [
            makeParticipant(playerID: FixtureID.playerA, seat: 0, finalScore: 295, rank: 2),
            makeParticipant(playerID: FixtureID.playerB, seat: 1, finalScore: 305, rank: 1),
            makeParticipant(playerID: FixtureID.playerC, seat: 2, finalScore: 210, rank: 3)
        ]
    )

    // MARK: Tier 2 — Complete scorecards (A vs B), with recordedAt stamps
    //
    // Player A (finalScore=296, upper bonus earned):
    //   ones=3, twos=8, threes=9, fours=12, fives=20, sixes=18 → upper=70 ≥63 → bonus=35
    //   3oaK=20, 4oaK=0(scratch), FH=25, SS=30, LS=40, Y=50, Chance=26
    //   base=261 → grand=296
    //
    // Player B (finalScore=164, no upper bonus, three scratches):
    //   ones=2, twos=6, threes=6, fours=8, fives=10, sixes=12 → upper=44 <63 → no bonus
    //   3oaK=18, 4oaK=0(scratch), FH=0(scratch), SS=30, LS=0(scratch), Y=50, Chance=22
    //   base=164 → grand=164
    //
    // Stage 3 assertions:
    //   A scratchRate(.fourOfAKind)=1.0,  A scratchRate(.fullHouse)=0.0
    //   B scratchRate(.fullHouse)=1.0,    B scratchRate(.largeStraight)=1.0
    //   upperBonusRate: A=1.0, B=0.0
    //   yatzyHitRate: both=1.0 (scored 50)

    static let scorecardMatch = makeMatch(
        startedAt: FixtureID.date(daysAfter: 6),
        participants: [
            makeParticipant(
                playerID: FixtureID.playerA, seat: 0,
                finalScore: 296, rank: 1,
                scoreEntries: aScorecard
            ),
            makeParticipant(
                playerID: FixtureID.playerB, seat: 1,
                finalScore: 164, rank: 2,
                scoreEntries: bScorecard
            )
        ]
    )

    // MARK: - Collections

    /// All completed fixtures, sorted chronologically for order-dependent stats.
    static var all: [Match] {
        [h2h_1, h2h_2, h2h_3, h2h_4_tie, three_1, three_2, scorecardMatch]
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// Heads-up A vs B only (4 matches, no scorecards).
    static var headsUpAB: [Match] { [h2h_1, h2h_2, h2h_3, h2h_4_tie] }

    /// Three-player matches only.
    static var threeway: [Match] { [three_1, three_2] }

    /// Matches that carry full 13-category scorecards.
    static var withScorecards: [Match] { [scorecardMatch] }

    // MARK: - Private builders

    private static func makeMatch(
        startedAt: Date,
        participants: [Participant]
    ) -> Match {
        Match(
            id: UUID(),
            gameID: FixtureID.yatzyGame,
            scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1,
            status: .completed,
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(1800),
            participants: participants
        )
    }

    private static func makeParticipant(
        playerID: UUID,
        seat: Int,
        finalScore: Decimal,
        rank: Int,
        bonusPoints: Int = 0,
        scoreEntries: [ScoreEntry] = []
    ) -> Participant {
        let label = [0: "A", 1: "B", 2: "C"][seat] ?? "?"
        return Participant(
            id: UUID(),
            seat: seat,
            finalScore: finalScore,
            rank: rank,
            bonusPoints: bonusPoints,
            playerID: playerID,
            teamID: nil,
            displayName: "Player \(label)",
            displayInitials: label,
            displayThemeID: "midnight",
            scoreEntries: scoreEntries
        )
    }

    // MARK: - Scorecards

    // One entry every 2 minutes from match start.
    private static let scorecardStart = FixtureID.date(daysAfter: 6)

    private static func entry(
        _ category: YatzyCategory,
        _ value: Decimal,
        minutesIn: Int
    ) -> ScoreEntry {
        ScoreEntry(
            slotKey: category.slotKey,
            value: value,
            metadata: nil,
            recordedAt: scorecardStart.addingTimeInterval(Double(minutesIn) * 60)
        )
    }

    // Player A: earns upper bonus, one scratch (4oaK).
    static let aScorecard: [ScoreEntry] = [
        entry(.ones,          3,  minutesIn:  2),
        entry(.twos,          8,  minutesIn:  4),
        entry(.threes,        9,  minutesIn:  6),
        entry(.fours,         12, minutesIn:  8),
        entry(.fives,         20, minutesIn: 10),
        entry(.sixes,         18, minutesIn: 12),
        entry(.threeOfAKind,  20, minutesIn: 14),
        entry(.fourOfAKind,   0,  minutesIn: 16),  // scratch
        entry(.fullHouse,     25, minutesIn: 18),
        entry(.smallStraight, 30, minutesIn: 20),
        entry(.largeStraight, 40, minutesIn: 22),
        entry(.yatzy,       50, minutesIn: 24),
        entry(.chance,        26, minutesIn: 26),
    ]

    // Player B: no upper bonus, three scratches (4oaK, FH, LS).
    static let bScorecard: [ScoreEntry] = [
        entry(.ones,          2,  minutesIn:  3),
        entry(.twos,          6,  minutesIn:  5),
        entry(.threes,        6,  minutesIn:  7),
        entry(.fours,         8,  minutesIn:  9),
        entry(.fives,         10, minutesIn: 11),
        entry(.sixes,         12, minutesIn: 13),
        entry(.threeOfAKind,  18, minutesIn: 15),
        entry(.fourOfAKind,   0,  minutesIn: 17),  // scratch
        entry(.fullHouse,     0,  minutesIn: 19),  // scratch
        entry(.smallStraight, 30, minutesIn: 21),
        entry(.largeStraight, 0,  minutesIn: 23),  // scratch
        entry(.yatzy,       50, minutesIn: 25),
        entry(.chance,        22, minutesIn: 27),
    ]
}
