import Foundation
import Observation

@Observable
final class GameModel {
    enum ScoreCategory: String, CaseIterable, Identifiable {
        case ones
        case twos
        case threes
        case fours
        case fives
        case sixes
        case threeOfAKind
        case fourOfAKind
        case fullHouse
        case smallStraight
        case largeStraight
        case yahtzee
        case chance

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .ones: return "Ones"
            case .twos: return "Twos"
            case .threes: return "Threes"
            case .fours: return "Fours"
            case .fives: return "Fives"
            case .sixes: return "Sixes"
            case .threeOfAKind: return "3 of a Kind"
            case .fourOfAKind: return "4 of a Kind"
            case .fullHouse: return "Full House"
            case .smallStraight: return "Small Straight"
            case .largeStraight: return "Large Straight"
            case .yahtzee: return "Yahtzee"
            case .chance: return "Chance"
            }
        }

        var isUpperSection: Bool {
            switch self {
            case .ones, .twos, .threes, .fours, .fives, .sixes:
                return true
            default:
                return false
            }
        }
    }

    private let diceCount = 5
    private let sides = 6
    private let rollsPerTurn = 3

    private let upperBonusThreshold = 63
    private let upperBonusValue = 35

    private(set) var diceValues: [Int]
    private(set) var held: [Bool]
    private(set) var rollsRemaining: Int
    private(set) var scores: [ScoreCategory: Int]

    init() {
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        scores = [:]
    }

    var isGameOver: Bool {
        scores.count == ScoreCategory.allCases.count
    }

    var upperSubtotal: Int {
        scores.compactMap { entry in
            guard entry.key.isUpperSection else { return nil }
            return entry.value
        }.reduce(0, +)
    }

    var upperBonus: Int {
        upperSubtotal >= upperBonusThreshold ? upperBonusValue : 0
    }

    var totalScore: Int {
        let base = scores.values.reduce(0, +)
        return base + upperBonus
    }

    var canScore: Bool {
        rollsRemaining < rollsPerTurn && !isGameOver
    }

    func resetGame() {
        diceValues = Array(repeating: 1, count: diceCount)
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
        scores = [:]
    }

    func toggleHold(at index: Int) {
        guard diceValues.indices.contains(index), !isGameOver else { return }
        held[index].toggle()
    }

    func roll() {
        guard rollsRemaining > 0, !isGameOver else { return }
        for index in diceValues.indices where !held[index] {
            diceValues[index] = Int.random(in: 1...sides)
        }
        rollsRemaining -= 1
    }

    func score(category: ScoreCategory) {
        guard scores[category] == nil else { return }
        scores[category] = scoreValue(for: category)
        beginNextTurn()
    }

    func suggestedScores() -> [ScoreCategory: Int] {
        var result: [ScoreCategory: Int] = [:]
        for category in ScoreCategory.allCases where scores[category] == nil {
            result[category] = scoreValue(for: category)
        }
        return result
    }

    private func beginNextTurn() {
        held = Array(repeating: false, count: diceCount)
        rollsRemaining = rollsPerTurn
    }

    private func scoreValue(for category: ScoreCategory) -> Int {
        let counts = countByFace()
        let sum = diceValues.reduce(0, +)

        switch category {
        case .ones: return counts[1, default: 0] * 1
        case .twos: return counts[2, default: 0] * 2
        case .threes: return counts[3, default: 0] * 3
        case .fours: return counts[4, default: 0] * 4
        case .fives: return counts[5, default: 0] * 5
        case .sixes: return counts[6, default: 0] * 6
        case .threeOfAKind:
            return hasKind(of: 3, counts: counts) ? sum : 0
        case .fourOfAKind:
            return hasKind(of: 4, counts: counts) ? sum : 0
        case .fullHouse:
            return isFullHouse(counts: counts) ? 25 : 0
        case .smallStraight:
            return isSmallStraight() ? 30 : 0
        case .largeStraight:
            return isLargeStraight() ? 40 : 0
        case .yahtzee:
            return hasKind(of: 5, counts: counts) ? 50 : 0
        case .chance:
            return sum
        }
    }

    private func countByFace() -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for value in diceValues {
            counts[value, default: 0] += 1
        }
        return counts
    }

    private func hasKind(of size: Int, counts: [Int: Int]) -> Bool {
        counts.values.contains { $0 >= size }
    }

    private func isFullHouse(counts: [Int: Int]) -> Bool {
        let values = counts.values.sorted()
        return values == [2, 3]
    }

    private func isSmallStraight() -> Bool {
        let unique = Set(diceValues)
        let sequences: [Set<Int>] = [
            [1, 2, 3, 4],
            [2, 3, 4, 5],
            [3, 4, 5, 6]
        ]
        return sequences.contains { $0.isSubset(of: unique) }
    }

    private func isLargeStraight() -> Bool {
        let unique = Set(diceValues)
        return unique == [1, 2, 3, 4, 5] || unique == [2, 3, 4, 5, 6]
    }
}
