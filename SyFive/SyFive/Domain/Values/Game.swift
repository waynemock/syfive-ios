import Foundation

// A reusable game definition (catalog entry), not a played session.
// SyFive seeds exactly one: Yatzy. Winner direction is declared by the
// scoring system at runtime — not stored here so it cannot go stale.
struct Game: Codable, Hashable, Sendable, Identifiable {
    // Well-known UUID for the built-in Yatzy catalog row. Fixed so every device seeds
    // the same CloudKit record — preventing duplicates on first sync.
    static let builtInYatzyID = UUID(uuidString: "BFB7F8F6-87D2-4700-9267-36A8ED4AC3C8")!

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
