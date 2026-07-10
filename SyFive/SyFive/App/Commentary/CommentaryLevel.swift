import Foundation

enum CommentaryLevel: String, CaseIterable, Codable {
    case celebrations = "celebrations"
    case highlights = "highlights"
    case playByPlay = "playByPlay"

    var displayName: String {
        switch self {
        case .celebrations: "Celebrations"
        case .highlights: "Highlights"
        case .playByPlay: "Play-by-Play"
        }
    }
}
