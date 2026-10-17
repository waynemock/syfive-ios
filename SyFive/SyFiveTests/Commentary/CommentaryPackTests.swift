import Foundation
import Testing
import SyLibCommentary
@testable import SyFive

// SyLibCommentary has a protocol of the same name; this is SyFive's enum.
private typealias Kind = SyFive.CommentaryEventKind

// The packs and Kind.allCases are main-actor isolated under the app target's
// default isolation, so the suite is too.
@MainActor
struct CommentaryPackTests {

    /// The tokens each kind's factory in CommentaryEvent+SyFive.swift supplies.
    ///
    /// `runnerUp` is listed for winnerDeclared and leadChange even though their factories add it
    /// only when there is a runner-up: after D-133 neither kind is emitted with fewer than two
    /// players (a solo game ends on soloFinished and never emits leadChange), so a runner-up
    /// always exists when either is spoken.
    private func suppliedTokens(for kind: Kind) -> Set<String> {
        switch kind {
        case .winnerDeclared:                 return ["winner", "score", "margin", "runnerUp"]
        case .winnerTie:                      return ["winner", "score"]
        case .soloFinished:                   return ["player", "score"]
        case .leadChange:                     return ["leader", "runnerUp"]
        case .bigTurn, .categoryScored:       return ["player", "category", "value"]
        case .categoryScratched:              return ["player", "category"]
        case .yatzyRolled, .yatzyBonusEarned, .upperBonusEarned, .yatzyScratched, .turnStart:
            return ["player"]
        }
    }

    private func tokens(in line: String) -> Set<String> {
        var found: Set<String> = []
        var rest = line[...]
        while let open = rest.firstIndex(of: "{"),
              let close = rest[open...].firstIndex(of: "}") {
            found.insert(String(rest[rest.index(after: open)..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return found
    }

    @Test("every pack has a line for every event kind, and twenty for soloFinished")
    func everyPackHasALineForEveryKind() {
        for pack in CommentaryPersonality<Kind>.all {
            for kind in Kind.allCases {
                let lines = pack.lines[kind.key] ?? []
                #expect(!lines.isEmpty, "\(pack.id) has no lines for \(kind.key)")
            }
            #expect((pack.lines[Kind.soloFinished.key] ?? []).count >= 20,
                    "\(pack.id) has fewer than 20 soloFinished lines (09 §13)")
        }
    }

    @Test("every token in every line is one its kind's factory supplies")
    func everyTokenIsSuppliedByItsFactory() {
        for pack in CommentaryPersonality<Kind>.all {
            for kind in Kind.allCases {
                let supplied = suppliedTokens(for: kind)
                for line in pack.lines[kind.key] ?? [] {
                    let unsupplied = tokens(in: line).subtracting(supplied)
                    #expect(unsupplied.isEmpty,
                            "\(pack.id).\(kind.key) uses \(unsupplied.sorted()) in: \(line)")
                }
            }
        }
    }
}
