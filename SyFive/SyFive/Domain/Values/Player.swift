import Foundation

struct Player: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    // Derived by deriveInitials(from:); stored so collisions ("B" vs "B") can be hand-resolved.
    var initials: String
     // Theme.ThemeType.rawValue — String keeps Domain Foundation-only.
    var themeID: String
    var createdAt: Date
    var isArchived: Bool
    var source: PlayerSource
}
