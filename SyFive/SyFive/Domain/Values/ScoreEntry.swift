import Foundation

// nil value = category open/unscored.
// Decimal(0) = deliberately scratched (a real strategic zero).
// These are different game states — completeness tests non-nil, never > 0.
// metadata is nil for all SyFive 1.0 categories; reserved for ScoreIt v2.
// Shape is frozen after release — additive changes only, never reshape.
struct ScoreEntry: Codable, Hashable, Sendable {
    var slotKey: String
    var value: Decimal?
    var metadata: [String: ScoreValue]?
    var recordedAt: Date?
}
