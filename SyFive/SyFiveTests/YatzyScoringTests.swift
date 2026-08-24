import Foundation
import Testing
@testable import SyFive

struct YatzyScoringTests {

    // MARK: - Tier 1: faceValue

    @Test func ones_scoresFaceCount() {
        #expect(faceValue(of: .ones, dice: [1, 1, 3, 4, 5]) == 2)
    }

    @Test func sixes_scoresFaceCount() {
        #expect(faceValue(of: .sixes, dice: [6, 6, 6, 2, 3]) == 18)
    }

    @Test func threeOfAKind_scoresSum() {
        #expect(faceValue(of: .threeOfAKind, dice: [3, 3, 3, 1, 2]) == 12)
    }

    @Test func threeOfAKind_failsWithTwoPair() {
        #expect(faceValue(of: .threeOfAKind, dice: [2, 2, 3, 3, 1]) == 0)
    }

    @Test func fullHouse_scores25() {
        #expect(faceValue(of: .fullHouse, dice: [2, 2, 3, 3, 3]) == 25)
    }

    @Test func fullHouse_failsWithFiveOfAKind() {
        #expect(faceValue(of: .fullHouse, dice: [4, 4, 4, 4, 4]) == 0)
    }

    @Test func smallStraight_scores30_allThreeRuns() {
        #expect(faceValue(of: .smallStraight, dice: [1, 2, 3, 4, 6]) == 30)
        #expect(faceValue(of: .smallStraight, dice: [2, 3, 4, 5, 1]) == 30)
        #expect(faceValue(of: .smallStraight, dice: [3, 4, 5, 6, 6]) == 30)
    }

    @Test func largeStraight_scores40_bothRuns() {
        #expect(faceValue(of: .largeStraight, dice: [1, 2, 3, 4, 5]) == 40)
        #expect(faceValue(of: .largeStraight, dice: [2, 3, 4, 5, 6]) == 40)
    }

    @Test func largeStraight_failsWithSmallStraight() {
        #expect(faceValue(of: .largeStraight, dice: [1, 2, 3, 4, 6]) == 0)
    }

    @Test func yatzy_scores50_forFiveOfAKind() {
        #expect(faceValue(of: .yatzy, dice: [5, 5, 5, 5, 5]) == 50)
    }

    @Test func yatzy_scoresZero_forNonFiveOfAKind() {
        #expect(faceValue(of: .yatzy, dice: [5, 5, 5, 5, 4]) == 0)
    }

    @Test func chance_scoresSum() {
        #expect(faceValue(of: .chance, dice: [1, 2, 3, 4, 5]) == 15)
    }

    // MARK: - Upper bonus

    @Test func upperBonus_earnedAtExactThreshold() {
        let scorecard: YatzyScorecard = [
            .ones: 3, .twos: 6, .threes: 9, .fours: 12, .fives: 15, .sixes: 18
        ]
        #expect(upperSubtotal(scorecard: scorecard) == 63)
        #expect(upperBonus(scorecard: scorecard) == 35)
    }

    @Test func upperBonus_notEarnedBelowThreshold() {
        let scorecard: YatzyScorecard = [.ones: 1, .twos: 4]
        #expect(upperBonus(scorecard: scorecard) == 0)
    }

    // MARK: - Completeness

    @Test func isComplete_trueWhenAllCategoriesScored() {
        var scorecard: YatzyScorecard = [:]
        for category in YatzyCategory.allCases { scorecard[category] = 0 }
        #expect(isComplete(scorecard: scorecard))
    }

    @Test func isComplete_falseWhenOneCategoryMissing() {
        var scorecard: YatzyScorecard = [:]
        for category in YatzyCategory.allCases where category != .chance {
            scorecard[category] = 0
        }
        #expect(!isComplete(scorecard: scorecard))
    }

    @Test func isComplete_scratchedZeroCountsAsScored() {
        var scorecard: YatzyScorecard = [:]
        for category in YatzyCategory.allCases { scorecard[category] = 0 }  // all scratched
        #expect(isComplete(scorecard: scorecard))
    }

    // MARK: - Poison rule regression (§4.3 — the key fix)

    @Test("Scratched Yatzy (0) disables joker placement and +100 bonus")
    func poison_scratchedYatzyDisablesJoker() {
        let dice = [6, 6, 6, 6, 6]
        let scorecard: YatzyScorecard = [.yatzy: 0]   // scratched to zero

        // Joker must NOT fire
        #expect(!isJokerRoll(dice: dice, scorecard: scorecard))

        // +100 bonus must NOT qualify
        #expect(!qualifiesForExtraYatzyBonus(dice: dice, scorecard: scorecard))

        // All open categories freely available — no forced upper placement
        let legal = legalCategories(dice: dice, scorecard: scorecard)
        let open = YatzyCategory.allCases.filter { scorecard[$0] == nil }
        #expect(Set(legal) == Set(open))
    }

    @Test("Live Yatzy (50) enables joker placement and +100 bonus")
    func poison_liveYatzyEnablesJoker() {
        let dice = [6, 6, 6, 6, 6]
        let scorecard: YatzyScorecard = [.yatzy: 50, .sixes: 36]

        // Joker MUST fire
        #expect(isJokerRoll(dice: dice, scorecard: scorecard))

        // +100 bonus MUST qualify
        #expect(qualifiesForExtraYatzyBonus(dice: dice, scorecard: scorecard))

        // Sixes already used → must be forced to open lower categories
        let legal = legalCategories(dice: dice, scorecard: scorecard)
        #expect(!legal.isEmpty)
        #expect(legal.allSatisfy { !$0.isUpperSection })
    }

    // MARK: - Joker placement (normal cases)

    @Test("Joker forces matching upper box when open")
    func joker_forcesMatchingUpperWhenOpen() {
        let dice = [4, 4, 4, 4, 4]
        let scorecard: YatzyScorecard = [.yatzy: 50]
        #expect(legalCategories(dice: dice, scorecard: scorecard) == [.fours])
    }

    @Test("Joker allows open lower categories when matching upper is taken")
    func joker_allowsLowerWhenUpperTaken() {
        let dice = [4, 4, 4, 4, 4]
        let scorecard: YatzyScorecard = [.yatzy: 50, .fours: 20]
        let legal = legalCategories(dice: dice, scorecard: scorecard)
        #expect(!legal.isEmpty)
        #expect(legal.allSatisfy { !$0.isUpperSection })
    }

    // MARK: - Grand total

    @Test func grandTotal_includesUpperBonusAndYatzyBonus() {
        // Upper section summing to exactly 63 → earns +35
        let scorecard: YatzyScorecard = [
            .ones: 3, .twos: 6, .threes: 9, .fours: 12, .fives: 15, .sixes: 18,
            .fullHouse: 25
        ]
        // base = 88, upperBonus = 35, yatzyBonus = 100 → 223
        #expect(grandTotal(scorecard: scorecard, yatzyBonus: 100) == 223)
    }

    // MARK: - deriveInitials

    @Test func initials_twoWordName() {
        #expect(deriveInitials(from: "Wayne Mock") == "WM")
    }

    @Test func initials_singleWordFallsBackToFirstTwoChars() {
        #expect(deriveInitials(from: "Xander") == "XA")
    }

    @Test func initials_threeWords_takesFirstTwo() {
        #expect(deriveInitials(from: "Mary Ann Jones") == "MA")
    }

    @Test func initials_alwaysUppercase() {
        #expect(deriveInitials(from: "anne smith") == "AS")
    }
}
