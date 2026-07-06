import Foundation

// Per-match join record — a Player or Team made uniform within a Match.
// displayName/displayInitials/displayThemeID are copied at match creation;
// rendering never depends on playerID/teamID refs so deleted players leave
// fully intact match history behind.
struct Participant: Codable, Hashable, Sendable, Identifiable {
    var id: UUID

    var seat: Int
    var finalScore: Decimal        // denormalized; resolved at completion
    var rank: Int                  // 1 = winner; ties share rank; 0 = unresolved
    var yahtzeeBonus: Int          // cumulative +100 per extra Yahtzee beyond first

    // Exactly one must be non-nil — enforced by factory inits and validate().
    var playerID: UUID?
    var teamID: UUID?

    // Frozen at match creation; survives roster edits and deletes.
    var displayName: String
    var displayInitials: String
    var displayThemeID: String

    var scoreEntries: [ScoreEntry]

    // MARK: - Factory inits

    static func individual(
        id: UUID = UUID(),
        playerID: UUID,
        seat: Int,
        displayName: String,
        displayInitials: String,
        displayThemeID: String
    ) -> Participant {
        Participant(
            id: id,
            seat: seat,
            finalScore: 0,
            rank: 0,
            yahtzeeBonus: 0,
            playerID: playerID,
            teamID: nil,
            displayName: displayName,
            displayInitials: displayInitials,
            displayThemeID: displayThemeID,
            scoreEntries: []
        )
    }

    static func team(
        id: UUID = UUID(),
        teamID: UUID,
        seat: Int,
        displayName: String,
        displayInitials: String,
        displayThemeID: String
    ) -> Participant {
        Participant(
            id: id,
            seat: seat,
            finalScore: 0,
            rank: 0,
            yahtzeeBonus: 0,
            playerID: nil,
            teamID: teamID,
            displayName: displayName,
            displayInitials: displayInitials,
            displayThemeID: displayThemeID,
            scoreEntries: []
        )
    }

    // MARK: - Validation

    func validate() -> ValidationResult {
        switch (playerID, teamID) {
        case (.some, .none), (.none, .some):
            return .valid
        case (.none, .none):
            return .invalid(reason: "Participant requires exactly one identity; both playerID and teamID are nil.")
        case (.some, .some):
            return .invalid(reason: "Participant requires exactly one identity; both playerID and teamID are set.")
        }
    }
}
