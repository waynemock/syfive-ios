import Foundation

// Typed metadata primitive — dormant in SyFive 1.0, used in ScoreIt v2
// for structured extras (bid/made/set, won/stolen). Three cases now; more
// can be added additively without reshaping the ScoreEntry contract.
enum ScoreValue: Codable, Hashable, Sendable {
    case number(Decimal)
    case flag(Bool)
    case text(String)
}
