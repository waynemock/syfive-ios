import Foundation
import SyLibScoring

extension PlayerModel {
    func toDomain() -> Player {
        Player(
            id: id,
            name: name,
            initials: initials,
            themeID: themeID,
            createdAt: createdAt,
            isArchived: isArchived,
            source: source
        )
    }

    func hydrate(from player: Player) {
        id = player.id
        name = player.name
        initials = player.initials
        themeID = player.themeID
        createdAt = player.createdAt
        isArchived = player.isArchived
        sourceRaw = player.source.rawValue
    }
}
