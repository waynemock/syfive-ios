import Foundation

// Frozen schema for ScoreIt v2 team games (Bridge, Cornhole).
// SyFive 1.0 never instantiates a Team.
struct Team: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var initials: String
    var themeID: String
    var rosterPlayerIDs: [UUID]
    var createdAt: Date
    var isArchived: Bool
}
