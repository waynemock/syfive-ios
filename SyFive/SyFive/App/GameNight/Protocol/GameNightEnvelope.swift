import Foundation

/// Versioned outer wrapper for every Game Night wire message.
/// The `kind` string is matched against `GameNightMessageKind`; unknown kinds
/// are ignored silently (forward compatibility within a protocol version).
/// Version is checked at `hello` and only there — mid-session version mismatch
/// cannot occur because mis-versioned joiners are declined a seat at `hello`.
struct GameNightEnvelope: Codable, Sendable {
    static let currentProtocolVersion = 1

    var protocolVersion: Int
    var kind: String
    var payload: Data
}

enum GameNightMessageKind: String, Sendable {
    case hello
    case tableState
    case seatClaim
    case matchStart
    case rollBegan
    case rollResult
    case holdToggled
    case scoreChosen
    case undoRequest
    case matchState
    case matchComplete
    case matchAbandoned
    case seatRelease
    case commentary
    case historyManifest   // list of recent completed GN match IDs this device has
    case historyRequest    // request specific match IDs from any peer that has them
    case historyResponse   // full Match values delivered in response to historyRequest
}

extension GameNightEnvelope {
    /// Encode a typed payload into an envelope.
    init<P: Encodable>(kind: GameNightMessageKind, payload: P) throws {
        let data = try JSONEncoder().encode(payload)
        self.init(
            protocolVersion: Self.currentProtocolVersion,
            kind: kind.rawValue,
            payload: data
        )
    }

    /// Decode the payload into a typed struct.
    func decode<P: Decodable>(_ type: P.Type) throws -> P {
        try JSONDecoder().decode(type, from: payload)
    }

    /// Returns nil for unknown kind strings — the caller should ignore the message.
    var messageKind: GameNightMessageKind? {
        GameNightMessageKind(rawValue: kind)
    }

    var isCurrentProtocolVersion: Bool {
        protocolVersion == Self.currentProtocolVersion
    }
}
