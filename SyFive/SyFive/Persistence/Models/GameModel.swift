import Foundation
import SyLibScoring
import SwiftData

// Persistence twin of Domain.Game — a reusable game catalog entry.
// SyFive 1.0 holds exactly one row: Yatzy, seeded at launch.
@Model final class GameModel {
    var id: UUID = UUID()
    var name: String = ""
    var scoringSystemID: String = ""
    var scoringSystemVersion: Int = 1
    var isBuiltIn: Bool = true
    var supportsTeams: Bool = false
    var maxParticipants: Int = 0
    var rulesURL: String? = nil
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init() {}
}
