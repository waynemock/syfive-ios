import Foundation
import SyLibScoring
import SwiftData
import SyLibScoringData

/// Shared identity utilities for completed Game Night matches.
/// Single source of truth for the fingerprint algorithm and spread limit
/// used by both LegacyRematchRepair (cleanup) and the history-sync receiver (prevention).
enum GNMatchIdentity {

    /// Maximum completedAt spread between two records before they are treated as distinct
    /// rather than duplicate. Covers the largest observed drift (~8 min) with margin.
    static let dupSpreadLimit: TimeInterval = 20 * 60

    // MARK: - Fingerprint

    /// Fingerprint for a SwiftData MatchModel.
    static func fingerprint(for model: MatchModel) -> String {
        core(
            startedAt: model.startedAt,
            names: model.participants.map { $0.displayName },
            scores: model.participants.map { "\($0.finalScore)" }
        )
    }

    /// Fingerprint for a Match value type (wire / domain).
    static func fingerprint(for match: Match) -> String {
        core(
            startedAt: match.startedAt,
            names: match.participants.map { $0.displayName },
            scores: match.participants.map { "\($0.finalScore)" }
        )
    }

    // MARK: - Duplicate check

    /// Returns true if `context` already contains a completed GN MatchModel equivalent
    /// to `match` — checked first by wire UUID, then by fingerprint within `dupSpreadLimit`.
    /// Call before inserting a history-sync received match to prevent creating duplicates.
    static func duplicateExists(for match: Match, in context: ModelContext) -> Bool {
        guard match.status == .completed, let incomingCompletedAt = match.completedAt else {
            return false
        }

        // Level 1: exact wire UUID — fast path, catches all post-fix records.
        let mid = match.id
        var byID = FetchDescriptor<MatchModel>(predicate: #Predicate { $0.id == mid })
        byID.fetchLimit = 1
        if (try? context.fetch(byID))?.first != nil { return true }

        // Level 2: fingerprint + spread — catches pre-fix records saved with an auto-UUID.
        let fp = fingerprint(for: match)
        let gnCompleted = ((try? context.fetch(FetchDescriptor<MatchModel>())) ?? [])
            .filter { $0.statusRaw == "completed" && $0.isGameNight }
        return gnCompleted.contains { model in
            guard let modelCompletedAt = model.completedAt else { return false }
            let spread = abs(modelCompletedAt.timeIntervalSince(incomingCompletedAt))
            return spread <= dupSpreadLimit && fingerprint(for: model) == fp
        }
    }

    // MARK: - Private

    private static func core(startedAt: Date, names: [String], scores: [String]) -> String {
        let ts = String(Int(startedAt.timeIntervalSince1970))
        let sortedNames = names.sorted().joined(separator: "|")
        let sortedScores = scores.sorted().joined(separator: "|")
        return "\(ts)|\(sortedNames)|\(sortedScores)"
    }
}
