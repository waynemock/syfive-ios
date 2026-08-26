import Foundation
import SyLibScoring

extension ParticipantModel {
    func toDomain() -> Participant {
        Participant(
            id: id,
            seat: seat,
            finalScore: finalScore,
            rank: rank,
            bonusPoints: bonusPoints,
            playerID: playerID,
            teamID: teamID,
            displayName: displayName,
            displayInitials: displayInitials,
            displayThemeID: displayThemeID,
            scoreEntries: scoreEntries
        )
    }

    func hydrate(from participant: Participant) {
        id = participant.id
        seat = participant.seat
        finalScore = participant.finalScore
        rank = participant.rank
        bonusPoints = participant.bonusPoints
        playerID = participant.playerID
        teamID = participant.teamID
        displayName = participant.displayName
        displayInitials = participant.displayInitials
        displayThemeID = participant.displayThemeID
        scoreEntries = participant.scoreEntries
    }
}
