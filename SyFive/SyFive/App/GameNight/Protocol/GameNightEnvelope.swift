import Foundation
import SyLibGameNight
import SyLibGameNightMatch

/// SyFive's 6 app-layer message kinds. These are game-specific and are NOT part
/// of the package — the session forwards anything it does not own to the controller.
/// Raw values must not change — they are on the wire.
/// The seven match-layer kinds (matchStart, matchState, matchComplete, matchAbandoned,
/// historyManifest, historyRequest, historyResponse) are owned by `GameNightMatchKind`
/// in `SyLibGameNightMatch` and must not be redeclared here.
enum GameNightMessageKind: String, Sendable {
    case rollBegan
    case rollResult
    case holdToggled
    case scoreChosen
    case undoRequest
    case commentary

    /// App message schema version. Bump this (independently of the transport version)
    /// when any SyFive payload struct changes shape.
    static let appProtocolVersion = 1
}

// Convenience send overload so `GameNightSession` call sites in SyFive can use
// `.rollBegan` syntax unchanged without the session knowing about SyFive kinds.
extension GameNightSession {
    func send<P: Encodable>(_ kind: GameNightMessageKind, payload: P) {
        send(kind.rawValue, payload: payload)
    }
}
