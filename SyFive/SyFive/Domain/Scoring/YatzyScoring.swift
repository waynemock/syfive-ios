import Foundation

// A Yatzy scorecard maps each category to its scored value.
// Key presence = scored (even at Decimal(0) = deliberately scratched zero).
// Missing key = category is open and unscored.
typealias YatzyScorecard = [YatzyCategory: Decimal]

// MARK: - Tier 1: Face value (pure, dice-only)

// Returns the score a category would yield for the given dice,
// ignoring joker rules and any scorecard context. Returns 0 when
// the dice don't satisfy the category shape.
func faceValue(of category: YatzyCategory, dice: [Int]) -> Int {
    let counts = countByFace(dice)
    let sum = dice.reduce(0, +)
    switch category {
    case .ones:          return counts[1, default: 0] * 1
    case .twos:          return counts[2, default: 0] * 2
    case .threes:        return counts[3, default: 0] * 3
    case .fours:         return counts[4, default: 0] * 4
    case .fives:         return counts[5, default: 0] * 5
    case .sixes:         return counts[6, default: 0] * 6
    case .threeOfAKind:  return hasKind(of: 3, in: dice) ? sum : 0
    case .fourOfAKind:   return hasKind(of: 4, in: dice) ? sum : 0
    case .fullHouse:     return isFullHouse(dice) ? 25 : 0
    case .smallStraight: return isSmallStraight(dice) ? 30 : 0
    case .largeStraight: return isLargeStraight(dice) ? 40 : 0
    case .yahtzee:       return hasKind(of: 5, in: dice) ? 50 : 0
    case .chance:        return sum
    }
}

// MARK: - Tier 2: Legal categories (joker-aware placement)

// Returns the categories the current player may score given their dice and
// scorecard, applying Classic Hasbro joker forced-scoring where applicable.
// Returns an empty array when no categories remain open.
func legalCategories(dice: [Int], scorecard: YatzyScorecard) -> [YatzyCategory] {
    let open = YatzyCategory.allCases.filter { scorecard[$0] == nil }
    guard !open.isEmpty else { return [] }
    guard isJokerRoll(dice: dice, scorecard: scorecard) else { return open }
    guard let upper = matchingUpperCategory(for: dice) else { return open }

    // Priority 1: matching upper box if still open → forced there.
    if scorecard[upper] == nil { return [upper] }

    // Priority 2: any open lower category (with joker scoring applied).
    let openLower = open.filter { !$0.isUpperSection }
    if !openLower.isEmpty { return openLower }

    // Priority 3: forced into a remaining upper box (scores at face value, often 0).
    return open.filter { $0.isUpperSection }
}

// MARK: - Tier 2: Joker scoring (separate from faceValue — layered on top)

// Returns the joker-adjusted score for a category, or nil when joker rules
// don't apply. Only meaningful when legalCategories confirms the placement is valid.
func jokerValue(of category: YatzyCategory, dice: [Int], scorecard: YatzyScorecard) -> Int? {
    guard isJokerRoll(dice: dice, scorecard: scorecard) else { return nil }
    guard let upper = matchingUpperCategory(for: dice) else { return nil }

    if scorecard[upper] == nil {
        guard category == upper else { return nil }
        return dice.reduce(0, +)
    }

    let openLower = YatzyCategory.allCases.filter { !$0.isUpperSection && scorecard[$0] == nil }
    if !openLower.isEmpty {
        guard !category.isUpperSection else { return nil }
        return jokerLowerValue(of: category, dice: dice)
    }

    guard category.isUpperSection else { return nil }
    return 0
}

// MARK: - Tier 2: Totals and bonuses

func upperSubtotal(scorecard: YatzyScorecard) -> Int {
    YatzyCategory.allCases
        .filter { $0.isUpperSection }
        .compactMap { scorecard[$0] }
        .reduce(0) { $0 + NSDecimalNumber(decimal: $1).intValue }
}

func upperBonus(scorecard: YatzyScorecard) -> Int {
    upperSubtotal(scorecard: scorecard) >= 63 ? 35 : 0
}

// True when this roll qualifies for the +100 Yahtzee bonus:
// five of a kind AND the Yahtzee box holds a live 50 (not scratched 0).
func qualifiesForExtraYahtzeeBonus(dice: [Int], scorecard: YatzyScorecard) -> Bool {
    isYatzyRoll(dice) && scorecard[.yahtzee] == 50
}

func grandTotal(scorecard: YatzyScorecard, yahtzeeBonus: Int) -> Int {
    let base = scorecard.values.reduce(0) { $0 + NSDecimalNumber(decimal: $1).intValue }
    return base + upperBonus(scorecard: scorecard) + yahtzeeBonus
}

// A scorecard is complete when all 13 categories carry a non-nil value.
// Tests for key presence (non-nil), not value > 0 — a scratched zero
// is a valid scored state and must not block completion.
func isComplete(scorecard: YatzyScorecard) -> Bool {
    YatzyCategory.allCases.allSatisfy { scorecard[$0] != nil }
}

func winnerDirection() -> WinnerDirection { .highest }

// MARK: - Internal helpers (accessible from tests via @testable import)

func countByFace(_ dice: [Int]) -> [Int: Int] {
    dice.reduce(into: [:]) { $0[$1, default: 0] += 1 }
}

func hasKind(of n: Int, in dice: [Int]) -> Bool {
    countByFace(dice).values.contains { $0 >= n }
}

func isFullHouse(_ dice: [Int]) -> Bool {
    countByFace(dice).values.sorted() == [2, 3]
}

func isSmallStraight(_ dice: [Int]) -> Bool {
    let unique = Set(dice)
    return [[1,2,3,4],[2,3,4,5],[3,4,5,6]].contains { Set($0).isSubset(of: unique) }
}

func isLargeStraight(_ dice: [Int]) -> Bool {
    Set(dice) == [1,2,3,4,5] || Set(dice) == [2,3,4,5,6]
}

func isYatzyRoll(_ dice: [Int]) -> Bool {
    Set(dice).count == 1
}

func matchingUpperCategory(for dice: [Int]) -> YatzyCategory? {
    switch dice.first {
    case 1: return .ones
    case 2: return .twos
    case 3: return .threes
    case 4: return .fours
    case 5: return .fives
    case 6: return .sixes
    default: return nil
    }
}

// POISON FIX (§4.3 — DATAMODEL_DESIGN.md):
// The previous GameModel checked `scores[.yahtzee] != nil`, which incorrectly
// treated a scratched-0 Yahtzee as a "live" one and fired both joker placement
// and the +100 bonus. Only a live 50 enables either. This predicate is the fix.
func isJokerRoll(dice: [Int], scorecard: YatzyScorecard) -> Bool {
    isYatzyRoll(dice) && scorecard[.yahtzee] == 50
}

// MARK: - Private

fileprivate func jokerLowerValue(of category: YatzyCategory, dice: [Int]) -> Int {
    let sum = dice.reduce(0, +)
    switch category {
    case .threeOfAKind, .fourOfAKind, .chance: return sum
    case .fullHouse:     return 25
    case .smallStraight: return 30
    case .largeStraight: return 40
    case .yahtzee:       return 50
    default:             return 0
    }
}
