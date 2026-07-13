import Foundation
import SwiftData

@Model final class MatchModel {
    var id: UUID = UUID()
    // Denormalized from Game at creation — history renders correctly even if catalog changes.
    var gameID: UUID = UUID()
    var scoringSystemID: String = ""
    var scoringSystemVersion: Int = 1
    // MatchStatus stored as rawValue String for graceful unknown-case handling across versions.
    var statusRaw: String = MatchStatus.inProgress.rawValue
    var startedAt: Date = Date()
    var completedAt: Date? = nil
    var isGameNight: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \ParticipantModel.match)
    var participants: [ParticipantModel] = []

    var status: MatchStatus {
        get { MatchStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    init() {}
}
