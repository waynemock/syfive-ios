import Foundation
import SwiftData
import Testing
import SyLibScoring
import SyLibScoringData
@testable import SyFive

// MatchController and NewGameSheet are main-actor isolated under the app target's default
// isolation, so the suite is too. 38 §2.3, Task 38.2.
@MainActor
struct NewGameSetupTests {

    private func makePlayer(_ name: String, archived: Bool = false, in context: ModelContext) -> PlayerModel {
        let player = PlayerModel()
        player.name = name
        player.initials = String(name.prefix(1))
        player.isArchived = archived
        context.insert(player)
        return player
    }

    /// A completed match finished at `completedAt`, its seats in `seats` order (given out of seat
    /// order on purpose).
    private func makeMatch(completedAt: Date, isGameNight: Bool, seats: [(seat: Int, playerID: UUID)],
                           in context: ModelContext) {
        let match = MatchModel()
        match.statusRaw = "completed"
        match.completedAt = completedAt
        match.isGameNight = isGameNight
        context.insert(match)
        match.participants = seats.map { seat, playerID in
            let participant = ParticipantModel()
            participant.seat = seat
            participant.playerID = playerID
            context.insert(participant)
            return participant
        }
    }

    @Test("Last time is the latest non-Game Night game's players, in seat order, without archived or missing players")
    func lastTimeIsTheLatestLocalGameInSeatOrder() throws {
        let container = try makeInMemoryScoringContainer(additionalModels: [AppSettingsModel.self])
        let context = container.mainContext
        let ada = makePlayer("Ada", in: context)
        let bo = makePlayer("Bo", archived: true, in: context)
        let cy = makePlayer("Cy", in: context)
        let now = Date()

        // An older local game, and a later Game Night game: neither is "last time".
        makeMatch(completedAt: now.addingTimeInterval(-7200), isGameNight: false,
                  seats: [(0, ada.id)], in: context)
        makeMatch(completedAt: now, isGameNight: true,
                  seats: [(0, cy.id)], in: context)
        // The latest local game: Cy, Ada, archived Bo and a player no longer stored, given out of order.
        makeMatch(completedAt: now.addingTimeInterval(-60), isGameNight: false,
                  seats: [(1, ada.id), (3, UUID()), (0, cy.id), (2, bo.id)], in: context)
        try context.save()

        let matches = try context.fetch(FetchDescriptor<MatchModel>())
        let roster = try context.fetch(FetchDescriptor<PlayerModel>())
        #expect(NewGameSheet.lastTimePlayerIDs(matches: matches, roster: roster) == [cy.id, ada.id])
        #expect(NewGameSheet.lastTimePlayerIDs(matches: [], roster: roster).isEmpty)
    }

    @Test("setPlayers seats exactly the players given, in order, and refuses once the game has started")
    func setPlayersMatchesTheListUntilTheGameStarts() {
        func player(_ name: String) -> Player {
            Player(id: UUID(), name: name, initials: String(name.prefix(1)), themeID: "",
                   createdAt: Date(), isArchived: false, source: .local)
        }
        let ada = player("Ada"), bo = player("Bo"), cy = player("Cy")
        let controller = MatchController()
        controller.addPlayer(from: ada)
        controller.addPlayer(from: bo)

        // Reorder and add.
        controller.setPlayers([bo, ada, cy])
        #expect(controller.playerIDs == [bo.id, ada.id, cy.id])
        #expect(controller.playerNames == ["Bo", "Ada", "Cy"])
        #expect(controller.playerCount == 3)

        // The same ids in the same order change nothing, the seats' identities included.
        let slots = controller.slotIDs
        controller.setPlayers([bo, ada, cy])
        #expect(controller.slotIDs == slots)

        // Remove.
        controller.setPlayers([cy])
        #expect(controller.playerIDs == [cy.id])
        #expect(controller.playerCount == 1)

        // Once the first roll has started the game, the seats are fixed.
        controller.beginRoll()
        #expect(!controller.canEditPlayers)
        controller.setPlayers([ada, bo])
        #expect(controller.playerIDs == [cy.id])
    }
}
