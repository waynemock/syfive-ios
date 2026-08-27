import Foundation
import SyLibScoring
import SyLibDice
import SyLibGameNight

// GameNightPhase, SeatSnapshot, SeatMapping, HelloPayload, TableStatePayload,
// SeatClaimPayload, SeatReleasePayload are imported from SyLibGameNight.

// MARK: - App settings (opaque to the session layer)

/// Commentary and other session-scoped app preferences, transmitted as opaque bytes
/// in `TableStatePayload.appSettings`. The session neither reads nor interprets these.
///
/// commentaryEnabled/PackID/LevelRaw are deliberately NOT reset on teardown.
/// They are the host's session-scoped preference and should carry into the next
/// Game Night rather than silently reverting to defaults. Not an omission.
struct GameNightAppSettings: Codable, Sendable {
    var commentaryEnabled: Bool
    var commentaryPackID: String
    var commentaryLevelRaw: String
}

// MARK: - App-layer payload structs (SyFive only)

/// Locks the table. Carries the initial `Match` (no scores yet) plus the
/// mapping from pre-lock `seatClaimID`s to the `participantID`s inside it.
/// Each device uses this mapping to discover its own `participantID`.
/// On a resume, `match` carries the mid-game snapshot and `currentSeatIndex`
/// points to the interrupted turn's player.
struct MatchStartPayload: Codable, Sendable {
    let match: Match
    let seatMappings: [SeatMapping]
    let currentSeatIndex: Int
}

/// Sent by the roller at the moment dice are launched. Spectators replay the
/// recipe through their own physics engine.
struct RollBeganPayload: Codable, Sendable {
    let participantID: UUID
    /// Roll within the turn: 1, 2, or 3.
    let rollIndex: Int
    let recipe: DiceRollRecipe
    /// Held mask at roll time — self-contained so spectators don't race `holdToggled`.
    let heldMask: [Bool]
}

/// Sent by the roller when all dice have settled. Spectators compare each die's
/// replay face against these authoritative values and apply a silent correction
/// wobble for any mismatch.
struct RollResultPayload: Codable, Sendable {
    let participantID: UUID
    /// Five values, ordered by die index (0–4). Each value is 1–6.
    let faceValues: [Int]
}

/// Sent by the roller whenever a die's held state changes. Mirrors the
/// kinematic held line to spectator trays in real time.
struct HoldToggledPayload: Codable, Sendable {
    let participantID: UUID
    let dieIndex: Int
    let isHeld: Bool
}

/// Sent by the active scorer to propose a category. The host validates via
/// Layer 1 and applies. `diceValues` carries the roller's settled face values
/// so the host can run the same pure scoring functions without a separate dice-
/// state stream. In Phase 5 this will be superseded by `rollResult`.
struct ScoreChosenPayload: Codable, Sendable {
    let participantID: UUID
    let category: YatzyCategory
    /// Roller's settled face values at scoring time (5 values, 1–6).
    let diceValues: [Int]
}

/// Sent by the scorer to undo the most recent score entry, before the next
/// `rollBegan`. Host applies the existing `LastScoreSnapshot` undo path and
/// broadcasts `matchState`.
struct UndoRequestPayload: Codable, Sendable {
    let participantID: UUID
}

/// Full match snapshot broadcast after every applied action (score, undo, turn
/// advance). Normally transient dice state is omitted; spectators derive roll
/// count from the `rollBegan` stream. Exception: undo broadcasts include
/// `diceValues`/`rollsRemaining` so the undone player can rescore immediately.
struct MatchStatePayload: Codable, Sendable {
    let match: Match
    /// Index into `match.participants` for the seat whose turn it is.
    let currentSeatIndex: Int
    /// Pre-scoring dice values, present only in undo broadcasts.
    var diceValues: [Int]? = nil
    /// Rolls remaining for the seat, present only in undo broadcasts (always 0).
    var rollsRemaining: Int? = nil
}

/// Broadcast when the match completes. Every guest device upserts this `Match`
/// by UUID into its own local store — the single guest write of the session.
struct MatchCompletePayload: Codable, Sendable {
    let match: Match
}

/// Broadcast when the host abandons the session. Devices close gracefully.
/// Intentionally empty — the message kind is sufficient.
struct MatchAbandonedPayload: Codable, Sendable {}

/// Broadcast by the host when the commentary engine speaks a line.
/// Guests speak the same text verbatim using their local voice, so all
/// devices produce identical commentary chosen by the host's settings.
struct CommentaryPayload: Codable, Sendable {
    let text: String
    /// Raw value of `CommentaryEventTier` — determines interrupt priority on the guest.
    let tierRaw: Int
}

// MARK: - Match history sync (post-matchStart background repair)

/// Broadcast by every device immediately after matchStart. Lists the IDs of its
/// last N completed Game Night matches so peers can spot gaps and request missing data.
struct HistoryManifestPayload: Codable, Sendable {
    let matchIDs: [UUID]
}

/// Broadcast when a device finds match IDs in a peer's manifest that it does not have
/// locally. Any peer that holds those matches will respond with historyResponse.
struct HistoryRequestPayload: Codable, Sendable {
    let matchIDs: [UUID]
}

/// Sent in response to historyRequest. Contains the full Match values for whichever
/// requested IDs the sender has locally. Receivers upsert each match by wire UUID.
struct HistoryResponsePayload: Codable, Sendable {
    let matches: [Match]
}
