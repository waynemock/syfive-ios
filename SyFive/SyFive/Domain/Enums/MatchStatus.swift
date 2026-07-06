import Foundation

enum MatchStatus: String, Codable, Sendable {
    case inProgress
    case completed
    case abandoned
}
