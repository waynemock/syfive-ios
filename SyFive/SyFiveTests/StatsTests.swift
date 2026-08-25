import Foundation
import Testing
@testable import SyFive

// Stats unit tests.
// Stage 1: fixture integrity.
// Stage 2: PlayerSummary, HeadToHead, LineupRecord, RecordsBoard.

struct StatsTests {

    // MARK: - Stage 1: Fixture integrity

    @Test func allFixturesAreCompleted() {
        for match in StatsFixtures.all {
            #expect(match.status == .completed)
        }
    }

    @Test func allFixturesHaveParticipants() {
        for match in StatsFixtures.all {
            #expect(!match.participants.isEmpty)
        }
    }

    @Test func allRanksAreNonZeroInCompletedMatches() {
        for match in StatsFixtures.all {
            for p in match.participants {
                #expect(p.rank > 0, "rank must be resolved (>0) in completed matches")
            }
        }
    }

    @Test func allFixturesSortedChronologically() {
        let dates = StatsFixtures.all.map { $0.startedAt }
        #expect(dates == dates.sorted())
    }

    @Test func headsUpMatchesHaveTwoParticipants() {
        for match in StatsFixtures.headsUpAB {
            #expect(match.participants.count == 2)
        }
    }

    @Test func threewayMatchesHaveThreeParticipants() {
        for match in StatsFixtures.threeway {
            #expect(match.participants.count == 3)
        }
    }

    @Test func scorecardMatchHasAllThirteenCategories() {
        let allKeys = Set(YatzyCategory.allCases.map { $0.slotKey })
        for participant in StatsFixtures.scorecardMatch.participants {
            let scoredKeys = Set(participant.scoreEntries.map { $0.slotKey })
            #expect(scoredKeys == allKeys,
                "\(participant.displayName) is missing scorecard entries")
        }
    }

    @Test func scorecardEntriesHaveRecordedAt() {
        for participant in StatsFixtures.scorecardMatch.participants {
            for entry in participant.scoreEntries {
                #expect(entry.recordedAt != nil,
                    "\(participant.displayName) entry \(entry.slotKey) missing recordedAt")
            }
        }
    }

    @Test func scorecardEntriesAreChronologicallyOrdered() {
        for participant in StatsFixtures.scorecardMatch.participants {
            let timestamps = participant.scoreEntries.compactMap { $0.recordedAt }
            #expect(timestamps == timestamps.sorted(),
                "\(participant.displayName) scorecard entries are not in chronological order")
        }
    }

    // Scratch = value is Decimal(0), not nil. Verify the fixture encodes this correctly.
    @Test func scratchEntriesHaveZeroNotNil() {
        let fourOfAKind_A = StatsFixtures.aScorecard.first { $0.slotKey == YatzyCategory.fourOfAKind.slotKey }
        #expect(fourOfAKind_A?.value == Decimal(0), "A's 4oaK scratch must be Decimal(0), not nil")

        let fullHouse_B = StatsFixtures.bScorecard.first { $0.slotKey == YatzyCategory.fullHouse.slotKey }
        #expect(fullHouse_B?.value == Decimal(0), "B's FH scratch must be Decimal(0), not nil")
    }

    // Verify the hand-authored grand totals match the scoring functions.
    @Test func aFinalScoreMatchesScoringFunctions() throws {
        let scorecard = scorecardFromEntries(StatsFixtures.aScorecard)
        let computed = grandTotal(scorecard: scorecard, yatzyBonus: 0)
        #expect(computed == 296, "A's computed grand total should be 296")
    }

    @Test func bFinalScoreMatchesScoringFunctions() throws {
        let scorecard = scorecardFromEntries(StatsFixtures.bScorecard)
        let computed = grandTotal(scorecard: scorecard, yatzyBonus: 0)
        #expect(computed == 164, "B's computed grand total should be 164")
    }

    // MARK: - Stage 2: PlayerSummary
    //
    // Fixtures used: StatsFixtures.all (7 matches, chronological)
    // Player A outcomes in date order:
    //   day 0 h2h_1   : win  (rank=1 sole)
    //   day 1 h2h_2   : loss (rank=2)
    //   day 2 h2h_3   : win  (rank=1 sole)
    //   day 3 h2h_4   : tie  (rank=1 shared)
    //   day 4 three_1 : win  (rank=1 sole)
    //   day 5 three_2 : loss (rank=2)
    //   day 6 scorecard: win (rank=1 sole)
    // Expected: wins=4, matchesPlayed=7, placementDist={1:5,2:2},
    //           bestScore=330, worstScore=220, medianScore=296,
    //           currentStreak=+1, bestWin=1, worstLoss=1

    @Test func playerSummary_matchesPlayed() {
        let summary = playerSummary(playerID: FixtureID.playerA, matches: StatsFixtures.all)
        #expect(summary?.matchesPlayed == 7)
    }

    @Test func playerSummary_winsExcludesTies() {
        let summary = playerSummary(playerID: FixtureID.playerA, matches: StatsFixtures.all)
        // 4 sole wins; h2h_4_tie is shared rank=1 and must NOT count as a win.
        #expect(summary?.wins == 4)
    }

    @Test func playerSummary_bestAndWorstScore() {
        let summary = playerSummary(playerID: FixtureID.playerA, matches: StatsFixtures.all)
        #expect(summary?.bestScore  == 330)
        #expect(summary?.worstScore == 220)
    }

    @Test func playerSummary_medianScore() {
        // A's scores sorted: [220,270,295,296,310,320,330] — 7 values, middle = 296.
        let summary = playerSummary(playerID: FixtureID.playerA, matches: StatsFixtures.all)
        #expect(summary?.medianScore == 296)
    }

    @Test func playerSummary_placementDistribution() {
        let summary = playerSummary(playerID: FixtureID.playerA, matches: StatsFixtures.all)
        // rank=1 in h2h_1,h2h_3,h2h_4_tie,three_1,scorecardMatch (5 matches, including the tie).
        // rank=2 in h2h_2,three_2.
        #expect(summary?.placementDistribution[1] == 5)
        #expect(summary?.placementDistribution[2] == 2)
    }

    @Test func playerSummary_streaks() {
        let summary = playerSummary(playerID: FixtureID.playerA, matches: StatsFixtures.all)
        // Outcome sequence: W L W T W L W → streak ends on W → +1
        #expect(summary?.currentStreak  ==  1)
        #expect(summary?.bestWinStreak  ==  1)
        #expect(summary?.worstLossStreak == 1)
    }

    @Test func playerSummary_returnsNilForUnknownPlayer() {
        let unknown = UUID()
        let summary = playerSummary(playerID: unknown, matches: StatsFixtures.all)
        #expect(summary == nil)
    }

    // MARK: - Stage 2: HeadToHead
    //
    // H2H(A,B) across all 7 matches (all have both A and B).
    // Match wins:    A=4 (h2h_1,h2h_3,three_1,scorecard)  B=2 (h2h_2,three_2)  ties=1 (h2h_4)
    // Pairwise:      aheadA=4   aheadB=2   ties=1
    // currentStreakA: outcomes W,L,W,T,W,L,W → ends on W → +1

    @Test func headToHead_sharedMatchCount() {
        let h2h = headToHead(playerA: FixtureID.playerA, playerB: FixtureID.playerB,
                             matches: StatsFixtures.all)
        #expect(h2h.sharedMatches == 7)
    }

    @Test func headToHead_matchWins() {
        let h2h = headToHead(playerA: FixtureID.playerA, playerB: FixtureID.playerB,
                             matches: StatsFixtures.all)
        #expect(h2h.matchWinsA  == 4)
        #expect(h2h.matchWinsB  == 2)
        #expect(h2h.sharedTies  == 1)
    }

    @Test func headToHead_pairwise() {
        let h2h = headToHead(playerA: FixtureID.playerA, playerB: FixtureID.playerB,
                             matches: StatsFixtures.all)
        #expect(h2h.pairwiseAheadA == 4)
        #expect(h2h.pairwiseAheadB == 2)
        #expect(h2h.pairwiseTies   == 1)
    }

    @Test func headToHead_currentStreakA() {
        let h2h = headToHead(playerA: FixtureID.playerA, playerB: FixtureID.playerB,
                             matches: StatsFixtures.all)
        #expect(h2h.currentStreakA == 1)
    }

    @Test func headToHead_isSymmetricForMatchCounts() {
        // Swapping A and B should flip win columns but preserve totals.
        let ab = headToHead(playerA: FixtureID.playerA, playerB: FixtureID.playerB,
                            matches: StatsFixtures.all)
        let ba = headToHead(playerA: FixtureID.playerB, playerB: FixtureID.playerA,
                            matches: StatsFixtures.all)
        #expect(ab.matchWinsA  == ba.matchWinsB)
        #expect(ab.matchWinsB  == ba.matchWinsA)
        #expect(ab.sharedTies  == ba.sharedTies)
        #expect(ab.sharedMatches == ba.sharedMatches)
    }

    // MARK: - Stage 2: LineupRecord
    //
    // {A,B} exact lineup: h2h_1..h2h_4_tie + scorecardMatch = 5 matches
    //   A wins: h2h_1, h2h_3, scorecardMatch (3)
    //   B wins: h2h_2 (1)
    //   tie: h2h_4_tie (0 wins for either)
    //   groupHighScore = 330 (A in h2h_3)
    //
    // {A,B,C} exact lineup: three_1, three_2 = 2 matches
    //   groupHighScore = 320 (A in three_1)

    @Test func lineupRecord_headsUpTimesPlayed() {
        let record = lineupRecord(
            playerIDs: [FixtureID.playerA, FixtureID.playerB],
            matches: StatsFixtures.all
        )
        #expect(record?.timesPlayed == 5)
    }

    @Test func lineupRecord_headsUpWins() {
        let record = lineupRecord(
            playerIDs: [FixtureID.playerA, FixtureID.playerB],
            matches: StatsFixtures.all
        )
        #expect(record?.winsByPlayer[FixtureID.playerA] == 3)
        #expect(record?.winsByPlayer[FixtureID.playerB] == 1)
        // Tie match contributes no win to either.
        #expect(record?.winsByPlayer[FixtureID.playerC] == nil)
    }

    @Test func lineupRecord_headsUpGroupHighScore() {
        let record = lineupRecord(
            playerIDs: [FixtureID.playerA, FixtureID.playerB],
            matches: StatsFixtures.all
        )
        #expect(record?.groupHighScore == 330)
    }

    @Test func lineupRecord_threewayTimesPlayed() {
        let record = lineupRecord(
            playerIDs: [FixtureID.playerA, FixtureID.playerB, FixtureID.playerC],
            matches: StatsFixtures.all
        )
        #expect(record?.timesPlayed == 2)
    }

    @Test func lineupRecord_threewayGroupHighScore() {
        let record = lineupRecord(
            playerIDs: [FixtureID.playerA, FixtureID.playerB, FixtureID.playerC],
            matches: StatsFixtures.all
        )
        #expect(record?.groupHighScore == 320)
    }

    @Test func lineupRecord_unknownLineupReturnsNil() {
        let record = lineupRecord(
            playerIDs: [FixtureID.playerA, FixtureID.playerC],  // never played heads-up
            matches: StatsFixtures.headsUpAB
        )
        #expect(record == nil)
    }

    // MARK: - Stage 2: RecordsBoard
    //
    // All 7 matches, all under yatzyGame.
    // allTimeHigh         = 330  (A in h2h_3)
    // highestLosingScore  = 295  (A rank=2 in three_2)
    // lowestWinningScore  = 285  (B rank=1 in h2h_2)
    // biggestBlowout      = 132  (scorecardMatch: 296−164)
    // narrowestWin        = 10   (three_2: 305−295)

    @Test func recordsBoard_allTimeHigh() {
        let board = recordsBoard(gameID: FixtureID.yatzyGame, matches: StatsFixtures.all)
        #expect(board.allTimeHigh?.score == 330)
        #expect(board.allTimeHigh?.playerID == FixtureID.playerA)
    }

    @Test func recordsBoard_highestLosingScore() {
        let board = recordsBoard(gameID: FixtureID.yatzyGame, matches: StatsFixtures.all)
        #expect(board.highestLosingScore?.score == 295)
        #expect(board.highestLosingScore?.playerID == FixtureID.playerA)
    }

    @Test func recordsBoard_lowestWinningScore() {
        let board = recordsBoard(gameID: FixtureID.yatzyGame, matches: StatsFixtures.all)
        #expect(board.lowestWinningScore?.score == 285)
        #expect(board.lowestWinningScore?.playerID == FixtureID.playerB)
    }

    @Test func recordsBoard_biggestBlowout() {
        let board = recordsBoard(gameID: FixtureID.yatzyGame, matches: StatsFixtures.all)
        #expect(board.biggestBlowout?.margin == 132)
    }

    @Test func recordsBoard_narrowestWin() {
        let board = recordsBoard(gameID: FixtureID.yatzyGame, matches: StatsFixtures.all)
        #expect(board.narrowestWin?.margin == 10)
    }

    @Test func recordsBoard_wrongGameIDReturnsEmpty() {
        let board = recordsBoard(gameID: UUID(), matches: StatsFixtures.all)
        #expect(board.allTimeHigh        == nil)
        #expect(board.highestLosingScore == nil)
        #expect(board.lowestWinningScore == nil)
        #expect(board.biggestBlowout     == nil)
        #expect(board.narrowestWin       == nil)
    }

    @Test func recordsBoard_tiedMatchExcludedFromBlowoutAndLowestWin() {
        // h2h_4_tie has both players at rank=1. It should not appear in
        // lowestWinningScore or blowout since there is no sole winner.
        let board = recordsBoard(gameID: FixtureID.yatzyGame, matches: [StatsFixtures.h2h_4_tie])
        #expect(board.lowestWinningScore == nil)
        #expect(board.biggestBlowout     == nil)
        #expect(board.narrowestWin       == nil)
        // But both rank=1 participants should NOT count as "losers" either.
        #expect(board.highestLosingScore == nil)
    }

    // MARK: - Stage 3: CategoryStats
    //
    // Fixtures used: StatsFixtures.withScorecards (scorecardMatch only)
    // Player A: fourOfAKind=0(scratch), fullHouse=25, yatzy=50, chance=26
    // Player B: fullHouse=0(scratch), largeStraight=0(scratch), yatzy=50, chance=22

    @Test func categoryStats_scratchCountsAsZeroNotNil() {
        // fourOfAKind is scratched (value=0). Must appear in timesFilled, not be dropped.
        let stats = categoryStats(category: .fourOfAKind, playerID: FixtureID.playerA,
                                  matches: StatsFixtures.withScorecards)
        #expect(stats?.timesFilled  == 1)
        #expect(stats?.timesZeroed  == 1)
        #expect(stats?.scratchRate  == 1.0)
        #expect(stats?.averageValue == 0)
        #expect(stats?.bestValue    == 0)
    }

    @Test func categoryStats_unscratchedCategoryHasZeroScratchRate() {
        let stats = categoryStats(category: .fullHouse, playerID: FixtureID.playerA,
                                  matches: StatsFixtures.withScorecards)
        #expect(stats?.timesFilled  == 1)
        #expect(stats?.timesZeroed  == 0)
        #expect(stats?.scratchRate  == 0.0)
        #expect(stats?.averageValue == 25)
        #expect(stats?.bestValue    == 25)
    }

    @Test func categoryStats_yatzyA() {
        let stats = categoryStats(category: .yatzy, playerID: FixtureID.playerA,
                                  matches: StatsFixtures.withScorecards)
        #expect(stats?.scratchRate  == 0.0)
        #expect(stats?.bestValue    == 50)
        #expect(stats?.averageValue == 50)
    }

    @Test func categoryStats_bFullHouseScratchRate() {
        let stats = categoryStats(category: .fullHouse, playerID: FixtureID.playerB,
                                  matches: StatsFixtures.withScorecards)
        #expect(stats?.timesZeroed == 1)
        #expect(stats?.scratchRate == 1.0)
    }

    @Test func categoryStats_bLargeStraightScratchRate() {
        let stats = categoryStats(category: .largeStraight, playerID: FixtureID.playerB,
                                  matches: StatsFixtures.withScorecards)
        #expect(stats?.timesZeroed == 1)
        #expect(stats?.scratchRate == 1.0)
    }

    @Test func categoryStats_bYatzyNotScratched() {
        let stats = categoryStats(category: .yatzy, playerID: FixtureID.playerB,
                                  matches: StatsFixtures.withScorecards)
        #expect(stats?.scratchRate == 0.0)
        #expect(stats?.bestValue   == 50)
    }

    @Test func categoryStats_returnsNilForUnknownPlayer() {
        let stats = categoryStats(category: .yatzy, playerID: UUID(),
                                  matches: StatsFixtures.withScorecards)
        #expect(stats == nil)
    }

    // MARK: - Stage 3: UpperSectionStats
    //
    // A: upper=3+8+9+12+20+18=70 → bonus earned, bonusRate=1.0
    // B: upper=2+6+6+8+10+12=44 → no bonus, bonusRate=0.0

    @Test func upperSectionStats_aAverageUpperTotal() {
        let stats = upperSectionStats(playerID: FixtureID.playerA,
                                      matches: StatsFixtures.withScorecards)
        #expect(stats?.averageUpperTotal == 70)
    }

    @Test func upperSectionStats_aBonusRate() {
        let stats = upperSectionStats(playerID: FixtureID.playerA,
                                      matches: StatsFixtures.withScorecards)
        #expect(stats?.bonusRate == 1.0)
    }

    @Test func upperSectionStats_aAverageByFace() {
        let stats = upperSectionStats(playerID: FixtureID.playerA,
                                      matches: StatsFixtures.withScorecards)
        #expect(stats?.averageByFace[.sixes]  == 18)
        #expect(stats?.averageByFace[.fives]  == 20)
        #expect(stats?.averageByFace[.ones]   == 3)
    }

    @Test func upperSectionStats_bNoBonusEarned() {
        let stats = upperSectionStats(playerID: FixtureID.playerB,
                                      matches: StatsFixtures.withScorecards)
        #expect(stats?.averageUpperTotal == 44)
        #expect(stats?.bonusRate == 0.0)
    }

    // MARK: - Stage 3: YatzyStats
    //
    // Both A and B scored Yatzy=50 in scorecardMatch, yatzyBonus=0 each.
    // A: chance=26, B: chance=22

    @Test func yatzyStats_aHitRate() {
        let stats = yatzyStats(playerID: FixtureID.playerA, matches: StatsFixtures.withScorecards)
        #expect(stats?.yatzyHitRate        == 1.0)
        #expect(stats?.careerYatzyCount    == 1)
        #expect(stats?.multiYatzyMatches   == 0)
        #expect(stats?.mostYatziesInOneMatch == 1)
    }

    @Test func yatzyStats_aAverageChance() {
        let stats = yatzyStats(playerID: FixtureID.playerA, matches: StatsFixtures.withScorecards)
        #expect(stats?.averageChance == 26)
    }

    @Test func yatzyStats_bAverageChance() {
        let stats = yatzyStats(playerID: FixtureID.playerB, matches: StatsFixtures.withScorecards)
        #expect(stats?.averageChance == 22)
    }

    @Test func yatzyStats_returnsNilForUnknownPlayer() {
        let stats = yatzyStats(playerID: UUID(), matches: StatsFixtures.withScorecards)
        #expect(stats == nil)
    }

    // MARK: - Stage 4: MatchProgression
    //
    // scorecardMatch timestamps: A scores at min2,4,6...26 / B at min3,5,7...27.
    // A leads wire-to-wire. Largest lead at min24 (A scores Yatzy):
    //   currentTotals: A=270, B=92 → margin=178.
    // Final: A=296, B=164.

    @Test func matchProgression_nilTimestampEntryReturnsNil() {
        let entry = ScoreEntry(slotKey: YatzyCategory.chance.slotKey, value: Decimal(26),
                               metadata: nil, recordedAt: nil)
        let participant = Participant(
            id: UUID(), seat: 0, finalScore: 26, rank: 1, bonusPoints: 0,
            playerID: FixtureID.playerA, teamID: nil,
            displayName: "A", displayInitials: "A", displayThemeID: "midnight",
            scoreEntries: [entry]
        )
        let match = Match(
            id: UUID(), gameID: FixtureID.yatzyGame, scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1, status: .completed,
            startedAt: FixtureID.epoch,
            completedAt: FixtureID.epoch.addingTimeInterval(1800),
            participants: [participant]
        )
        #expect(matchProgression(from: match) == nil)
    }

    @Test func matchProgression_scorecardMatchLeadStats() throws {
        let progression = try #require(matchProgression(from: StatsFixtures.scorecardMatch))
        #expect(progression.leadChanges == 0)
        #expect(progression.comebackFrom == nil)
        #expect(progression.largestLead?.margin == 178)
        #expect(progression.largestLead?.playerID == FixtureID.playerA)
    }

    @Test func matchProgression_finalRunningTotals() throws {
        let progression = try #require(matchProgression(from: StatsFixtures.scorecardMatch))
        let aID = try #require(
            StatsFixtures.scorecardMatch.participants.first { $0.playerID == FixtureID.playerA }?.id
        )
        let bID = try #require(
            StatsFixtures.scorecardMatch.participants.first { $0.playerID == FixtureID.playerB }?.id
        )
        let aPoints = try #require(progression.participants.first { $0.participantID == aID }?.points)
        let bPoints = try #require(progression.participants.first { $0.participantID == bID }?.points)
        #expect(aPoints.count == 13)
        #expect(bPoints.count == 13)
        #expect(aPoints.last?.runningTotal == 296)
        #expect(bPoints.last?.runningTotal == 164)
    }

    @Test func matchProgression_stepsAreChronological() throws {
        let progression = try #require(matchProgression(from: StatsFixtures.scorecardMatch))
        for prog in progression.participants {
            let dates = prog.points.map { $0.at }
            #expect(dates == dates.sorted())
        }
    }
}

// MARK: - Helpers

// Converts a [ScoreEntry] back to a YatzyScorecard for passing to scoring functions.
// Only entries with non-nil values and a recognised YatzyCategory slotKey are included.
private func scorecardFromEntries(_ entries: [ScoreEntry]) -> YatzyScorecard {
    var scorecard = YatzyScorecard()
    for entry in entries {
        guard let category = YatzyCategory(rawValue: entry.slotKey),
              let value = entry.value else { continue }
        scorecard[category] = value
    }
    return scorecard
}
