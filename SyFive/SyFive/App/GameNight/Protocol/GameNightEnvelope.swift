import Foundation
import SyLibGameNight

/// SyFive's 13 app-layer message kinds. These are game-specific and are NOT part
/// of the package — the session forwards anything it does not own to the controller.
/// Raw values must not change — they are on the wire.
enum GameNightMessageKind: String, Sendable {
    case matchStart
    case rollBegan
    case rollResult
    case holdToggled
    case scoreChosen
    case undoRequest
    case matchState
    case matchComplete
    case matchAbandoned
    case commentary
    case historyManifest
    case historyRequest
    case historyResponse

    /// App message schema version. Bump this (independently of the transport version)
    /// when any SyFive payload struct changes shape.
    static let appProtocolVersion = 1
}

// Convenience send overload so `GameNightSession` call sites in SyFive can use
// `.matchStart` syntax unchanged without the session knowing about SyFive kinds.
extension GameNightSession {
    func send<P: Encodable>(_ kind: GameNightMessageKind, payload: P) {
        send(kind.rawValue, payload: payload)
    }
}
