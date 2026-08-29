import Foundation
import SyLibCommentary
import SyLibGameNightMatch
import SyLibScoring
import SyLibDice
import SyLibGameNight
import SyLibYatzy

// GameNightPhase, SeatSnapshot, SeatMapping, HelloPayload, TableStatePayload,
// SeatClaimPayload, SeatReleasePayload are imported from SyLibGameNight.
// MatchStartPayload, MatchStatePayload, MatchCompletePayload, MatchAbandonedPayload,
// HistoryManifestPayload, HistoryRequestPayload, HistoryResponsePayload are imported
// from SyLibGameNightMatch.

// MARK: - App settings (opaque to the session layer)

/// Commentary and other session-scoped app preferences, transmitted as opaque bytes
/// in `TableStatePayload.appSettings`. The session neither reads nor interprets these.
///
/// commentaryEnabled/PackID/LevelRaw are not reset on teardown.
/// Host: re-seeded from personal appSettings at each session activation.
/// Guests: populated from the host's tableState broadcast; not reset so values survive reconnects.
struct GameNightAppSettings: Codable, Sendable {
    var commentaryEnabled: Bool
    var commentaryPackID: String
    var commentaryLevelRaw: String
}

// MARK: - SyFive-only app-layer payloads (roll theater and scoring)

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

// MARK: - Commentary

// CommentaryPayload is defined in SyLibCommentary and imported above.
