import Foundation
import SwiftData

@Model final class PlayerModel {
    var id: UUID = UUID()
    var name: String = ""
    var initials: String = ""
    var themeID: String = ""
    var createdAt: Date = Date()
    var isArchived: Bool = false
    /// "local" or "gameNight" — used to identify auto-created remote players for future merge UI.
    var sourceRaw: String = PlayerSource.local.rawValue
    var source: PlayerSource {
        get { PlayerSource(rawValue: sourceRaw) ?? .local }
        set { sourceRaw = newValue.rawValue }
    }

    init() {}
}
