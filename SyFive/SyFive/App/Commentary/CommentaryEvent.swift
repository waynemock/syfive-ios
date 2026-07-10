import Foundation

enum CommentaryEventKind: Hashable {
    case yatzyRolled
    case yahtzeeBonusEarned
    case winnerDeclared
    case winnerTie
    case upperBonusEarned
    case yatzyScratched
    case bigTurn
    case leadChange
    case turnStart
    case categoryScored
    case categoryScratched

    var tier: CommentaryEventTier {
        switch self {
        case .yatzyRolled, .yahtzeeBonusEarned, .winnerDeclared, .winnerTie:
            return .celebration
        case .upperBonusEarned, .yatzyScratched, .bigTurn, .leadChange:
            return .highlight
        case .turnStart, .categoryScored, .categoryScratched:
            return .playByPlay
        }
    }
}

enum CommentaryEventTier: Int, Comparable {
    case celebration = 0
    case highlight = 1
    case playByPlay = 2

    static func < (lhs: CommentaryEventTier, rhs: CommentaryEventTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CommentaryEvent {
    let kind: CommentaryEventKind
    var player: String? = nil
    var winner: String? = nil
    var runnerUp: String? = nil
    var leader: String? = nil
    var score: Int? = nil
    var margin: Int? = nil
    var category: String? = nil
    var value: Int? = nil
}
