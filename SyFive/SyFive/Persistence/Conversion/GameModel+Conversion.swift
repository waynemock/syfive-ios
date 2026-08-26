import Foundation
import SyLibScoring

extension GameModel {
    func toDomain() -> Game {
        Game(
            id: id,
            name: name,
            scoringSystemID: scoringSystemID,
            scoringSystemVersion: scoringSystemVersion,
            isBuiltIn: isBuiltIn,
            supportsTeams: supportsTeams,
            maxParticipants: maxParticipants,
            rulesURL: rulesURL,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }

    func hydrate(from game: Game) {
        id = game.id
        name = game.name
        scoringSystemID = game.scoringSystemID
        scoringSystemVersion = game.scoringSystemVersion
        isBuiltIn = game.isBuiltIn
        supportsTeams = game.supportsTeams
        maxParticipants = game.maxParticipants
        rulesURL = game.rulesURL
        sortOrder = game.sortOrder
        createdAt = game.createdAt
    }
}
