import Foundation

extension PlayerModel {
    func toDomain() -> Player {
        Player(
            id: id,
            name: name,
            initials: initials,
            themeID: themeID,
            createdAt: createdAt,
            isArchived: isArchived
        )
    }

    func hydrate(from player: Player) {
        id = player.id
        name = player.name
        initials = player.initials
        themeID = player.themeID
        createdAt = player.createdAt
        isArchived = player.isArchived
    }
}
