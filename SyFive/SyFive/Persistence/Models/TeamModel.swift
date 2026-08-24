import Foundation
import SwiftData

// Frozen schema — SyFive 1.0 never instantiates a team; exists for ScoreIt v2 compatibility.
@Model final class TeamModel {
    var id: UUID = UUID()
    var name: String = ""
    var initials: String = ""
    var themeID: String = ""
    var rosterPlayerIDs: [UUID] = []
    var createdAt: Date = Date()
    var isArchived: Bool = false

    init() {}
}
