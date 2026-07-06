import Foundation

// One played session of a Game. Snapshots scoringSystemID + version at creation
// so history renders correctly even if the Game template changes later.
struct Match: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var gameID: UUID
    var scoringSystemID: String
    var scoringSystemVersion: Int
    var status: MatchStatus
    var startedAt: Date
    var completedAt: Date?
    var participants: [Participant]
}
