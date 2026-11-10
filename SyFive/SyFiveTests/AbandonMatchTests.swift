import Foundation
import SwiftData
import Testing
import SyLibScoring
import SyLibScoringData
@testable import SyFive

// MatchController is main-actor isolated under the app target's default isolation, so the suite
// is too. 34 §2.4, Task 34.3.
@MainActor
struct AbandonMatchTests {

    @Test("Ending a game in progress deletes its match and participants and keeps its players")
    func abandoningDeletesTheMatchAndItsParticipants() throws {
        let container = try makeInMemoryScoringContainer(additionalModels: [AppSettingsModel.self])
        let context = container.mainContext

        let ada = PlayerModel()
        ada.name = "Ada"
        ada.initials = "A"
        let bo = PlayerModel()
        bo.name = "Bo"
        bo.initials = "B"
        context.insert(ada)
        context.insert(bo)
        try context.save()

        let controller = MatchController()
        controller.addPlayer(from: ada.toDomain())
        controller.addPlayer(from: bo.toDomain())
        controller.save(to: context, gameID: Game.builtInYatzyID)
        try context.save()

        // The premise: a match in progress, stored with both players' participants.
        let stored = try context.fetch(FetchDescriptor<MatchModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.statusRaw == "inProgress")
        #expect(try context.fetchCount(FetchDescriptor<ParticipantModel>()) == 2)

        controller.abandonMatch(in: context)

        #expect(try context.fetchCount(FetchDescriptor<MatchModel>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ParticipantModel>()) == 0)
        let players = try context.fetch(FetchDescriptor<PlayerModel>())
        #expect(Set(players.map(\.id)) == [ada.id, bo.id])
    }

    // 34 §2.7, Task 34.8: Game Night's onMatchComplete can store the game as completed while this
    // device's controller is a score short.
    @Test("Abandoning never deletes a match stored as completed, and the controller still lets go")
    func abandoningKeepsAMatchStoredAsCompleted() throws {
        let container = try makeInMemoryScoringContainer(additionalModels: [AppSettingsModel.self])
        let context = container.mainContext

        let ada = PlayerModel()
        ada.name = "Ada"
        ada.initials = "A"
        let bo = PlayerModel()
        bo.name = "Bo"
        bo.initials = "B"
        context.insert(ada)
        context.insert(bo)
        try context.save()

        let controller = MatchController()
        controller.addPlayer(from: ada.toDomain())
        controller.addPlayer(from: bo.toDomain())
        controller.save(to: context, gameID: Game.builtInYatzyID)
        try context.save()

        // The stored row is completed, as onMatchComplete would leave it; the controller's
        // scorecards stay empty, so it doesn't think the game is over.
        let stored = try #require(try context.fetch(FetchDescriptor<MatchModel>()).first)
        stored.statusRaw = "completed"
        try context.save()
        #expect(!controller.isGameOver)
        #expect(controller.persistedMatchID == stored.id)

        controller.abandonMatch(in: context)

        let remaining = try context.fetch(FetchDescriptor<MatchModel>())
        #expect(remaining.map(\.id) == [stored.id])
        #expect(remaining.first?.statusRaw == "completed")
        #expect(try context.fetchCount(FetchDescriptor<ParticipantModel>()) == 2)
        #expect(controller.persistedMatchID == nil)
    }
}
