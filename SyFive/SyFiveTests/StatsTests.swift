import Foundation
import Testing
@testable import SyFive

// Stats unit tests. Stage 1 verifies fixtures are well-formed.
// Stage 2+ will add PlayerSummary, HeadToHead, RecordsBoard assertions.

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
        let computed = grandTotal(scorecard: scorecard, yahtzeeBonus: 0)
        #expect(computed == 296, "A's computed grand total should be 296")
    }

    @Test func bFinalScoreMatchesScoringFunctions() throws {
        let scorecard = scorecardFromEntries(StatsFixtures.bScorecard)
        let computed = grandTotal(scorecard: scorecard, yahtzeeBonus: 0)
        #expect(computed == 164, "B's computed grand total should be 164")
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
