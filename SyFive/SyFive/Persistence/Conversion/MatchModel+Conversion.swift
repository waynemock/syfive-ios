import Foundation
import SwiftData

extension MatchModel {
    func toDomain() -> Match {
        Match(
            id: id,
            gameID: gameID,
            scoringSystemID: scoringSystemID,
            scoringSystemVersion: scoringSystemVersion,
            status: status,
            startedAt: startedAt,
            completedAt: completedAt,
            participants: participants.sorted { $0.seat < $1.seat }.map { $0.toDomain() }
        )
    }

    // Reconciles the model graph by id — never blind-rebuilds, to preserve SwiftData identity.
    func hydrate(from match: Match, context: ModelContext) {
        id = match.id
        gameID = match.gameID
        scoringSystemID = match.scoringSystemID
        scoringSystemVersion = match.scoringSystemVersion
        status = match.status
        startedAt = match.startedAt
        completedAt = match.completedAt

        let existingByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let incomingIDs = Set(match.participants.map { $0.id })

        // Remove participants no longer in the domain value
        for removed in participants where !incomingIDs.contains(removed.id) {
            context.delete(removed)
        }
        participants.removeAll { !incomingIDs.contains($0.id) }

        // Update existing or insert new
        for p in match.participants {
            if let existing = existingByID[p.id] {
                existing.hydrate(from: p)
            } else {
                let model = ParticipantModel()
                model.hydrate(from: p)
                participants.append(model)
            }
        }
    }
}
