import Foundation
import SyLibScoring
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

    // CloudKit requires relationships to be optional; stored as optional and exposed via
    // a computed accessor so all existing call sites continue to receive [ParticipantModel].
    @Relationship(deleteRule: .nullify, inverse: \ParticipantModel.match)
    var participantsStorage: [ParticipantModel]? = nil

    var participants: [ParticipantModel] {
        get { participantsStorage ?? [] }
        set { participantsStorage = newValue }
    }

    var status: MatchStatus {
        get { MatchStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    init() {}
}
