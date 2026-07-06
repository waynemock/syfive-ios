import Foundation
import SwiftData

@Model final class ParticipantModel {
    var id: UUID = UUID()
    var seat: Int = 0
    var finalScore: Decimal = 0
    var rank: Int = 0
    var yahtzeeBonus: Int = 0
    var playerID: UUID? = nil
    var teamID: UUID? = nil
    var displayName: String = ""
    var displayInitials: String = ""
    var displayThemeID: String = ""
    // [ScoreEntry] encoded as a JSON blob — always read and written as a whole unit.
    var scoreEntriesData: Data = Data()

    var match: MatchModel?

    var scoreEntries: [ScoreEntry] {
        get { (try? JSONDecoder().decode([ScoreEntry].self, from: scoreEntriesData)) ?? [] }
        set { scoreEntriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init() {}
}
