import Foundation

// A reusable game definition (catalog entry), not a played session.
// SyFive seeds exactly one: Yatzy. Winner direction is declared by the
// scoring system at runtime — not stored here so it cannot go stale.
struct Game: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var scoringSystemID: String
    var scoringSystemVersion: Int
    var isBuiltIn: Bool
    var supportsTeams: Bool
    var maxParticipants: Int
    var rulesURL: String?
    var sortOrder: Int
    var createdAt: Date
}
