import Foundation
import SwiftData

@Model final class PlayerModel {
    var id: UUID = UUID()
    var name: String = ""
    var initials: String = ""
    var themeID: String = ""
    var createdAt: Date = Date()
    var isArchived: Bool = false

    init() {}
}
