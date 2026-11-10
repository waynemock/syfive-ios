import Foundation
import SwiftData
import SwiftUI
import Testing
import SyLibGameNight
import SyLibScoringData
@testable import SyFive

// ContentView is main-actor isolated under the app target's default isolation, so the suite is
// too. 37 §2.4, Task 37.3.
@MainActor
struct RememberedSeatLookupTests {

    @Test("The remembered-seat lookup finds an active player, and nothing for an archived or missing one, or during a host resume")
    func lookupFindsOnlyAnActivePlayer() throws {
        let container = try makeInMemoryScoringContainer(additionalModels: [AppSettingsModel.self])
        let context = container.mainContext

        let ada = PlayerModel()
        ada.name = "Ada"
        ada.initials = "A"
        ada.themeID = "forest"
        let bo = PlayerModel()
        bo.name = "Bo"
        bo.initials = "B"
        bo.isArchived = true
        context.insert(ada)
        context.insert(bo)
        try context.save()

        func lookup(_ id: UUID, resumePending: Bool = false) -> SeatRosterEntryFields? {
            ContentView.rememberedSeatEntry(for: id, in: context, colorScheme: .light,
                                            hostResumePending: resumePending)
                .map { SeatRosterEntryFields(id: $0.id, name: $0.name, initials: $0.initials, themeID: $0.themeID) }
        }

        #expect(lookup(ada.id) == SeatRosterEntryFields(id: ada.id, name: "Ada", initials: "A", themeID: "forest"))
        #expect(lookup(bo.id) == nil)          // archived
        #expect(lookup(UUID()) == nil)         // missing
        #expect(lookup(ada.id, resumePending: true) == nil)
    }
}

/// SeatRosterEntry's comparable fields (its accent colour is resolved from the theme, as the sheet does).
private struct SeatRosterEntryFields: Equatable {
    let id: UUID
    let name: String
    let initials: String
    let themeID: String
}
