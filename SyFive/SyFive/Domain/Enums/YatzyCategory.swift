import Foundation

enum YatzyCategory: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
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
    case yatzy
    case chance

    var id: String { rawValue }
    var slotKey: String { rawValue }

    var isUpperSection: Bool {
        switch self {
        case .ones, .twos, .threes, .fours, .fives, .sixes: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .ones:         return "Ones"
        case .twos:         return "Twos"
        case .threes:       return "Threes"
        case .fours:        return "Fours"
        case .fives:        return "Fives"
        case .sixes:        return "Sixes"
        case .threeOfAKind: return "3 of a Kind"
        case .fourOfAKind:  return "4 of a Kind"
        case .fullHouse:    return "Full House"
        case .smallStraight: return "Small Straight"
        case .largeStraight: return "Large Straight"
        case .yatzy:      return "Yatzy"
        case .chance:       return "Chance"
        }
    }
}
