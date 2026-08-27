import Foundation
import SyLibCommentary

extension CommentaryEvent where Kind == CommentaryEventKind {

    static func winnerDeclared(winner: String, runnerUp: String?, score: Int, margin: Int) -> Self {
        var tokens: [String: String] = ["winner": winner, "score": "\(score)", "margin": "\(margin)"]
        if let ru = runnerUp { tokens["runnerUp"] = ru }
        return .init(kind: .winnerDeclared, tokens: tokens)
    }

    static func winnerTie(winner: String, score: Int) -> Self {
        .init(kind: .winnerTie, tokens: ["winner": winner, "score": "\(score)"])
    }

    static func yatzyBonusEarned(player: String) -> Self {
        .init(kind: .yatzyBonusEarned, tokens: ["player": player])
    }

    static func yatzyRolled(player: String) -> Self {
        .init(kind: .yatzyRolled, tokens: ["player": player])
    }

    static func yatzyScratched(player: String) -> Self {
        .init(kind: .yatzyScratched, tokens: ["player": player])
    }

    static func categoryScratched(player: String, category: String) -> Self {
        .init(kind: .categoryScratched, tokens: ["player": player, "category": category])
    }

    static func bigTurn(player: String, category: String, value: Int) -> Self {
        .init(kind: .bigTurn, tokens: ["player": player, "category": category, "value": "\(value)"])
    }

    static func categoryScored(player: String, category: String, value: Int) -> Self {
        .init(kind: .categoryScored, tokens: ["player": player, "category": category, "value": "\(value)"])
    }

    static func upperBonusEarned(player: String) -> Self {
        .init(kind: .upperBonusEarned, tokens: ["player": player])
    }

    static func leadChange(leader: String, runnerUp: String?) -> Self {
        var tokens: [String: String] = ["leader": leader]
        if let ru = runnerUp { tokens["runnerUp"] = ru }
        return .init(kind: .leadChange, tokens: tokens)
    }

    static func turnStart(player: String) -> Self {
        .init(kind: .turnStart, tokens: ["player": player])
    }
}
