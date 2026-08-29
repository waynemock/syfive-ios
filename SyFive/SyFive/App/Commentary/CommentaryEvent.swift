import Foundation
import SyLibCommentary

enum CommentaryEventKind: String, Sendable {
    case yatzyRolled
    case yatzyBonusEarned
    case winnerDeclared
    case winnerTie
    case upperBonusEarned
    case yatzyScratched
    case bigTurn
    case leadChange
    case turnStart
    case categoryScored
    case categoryScratched

    var key: String { rawValue }

    var tier: CommentaryEventTier {
        switch self {
        case .yatzyRolled, .yatzyBonusEarned, .winnerDeclared, .winnerTie:
            return .celebration
        case .upperBonusEarned, .yatzyScratched, .bigTurn, .leadChange:
            return .highlight
        case .turnStart, .categoryScored, .categoryScratched:
            return .playByPlay
        }
    }
}

extension CommentaryEventKind: SyLibCommentary.CommentaryEventKind {}
