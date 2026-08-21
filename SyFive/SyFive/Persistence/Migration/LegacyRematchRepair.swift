import Foundation
import SwiftData

// Runs on every launch to repair or remove stale MatchModel records.
//
// Strategy 1 (ID-based): Multiple records share the same `id` UUID. Keeps the completed/later
// record and deletes the rest.
//
// Strategy 2 (Abandoned): Deletes all records with statusRaw == "abandoned". The app no longer
// saves abandoned games; these are leftover from earlier builds.
//
// Strategy 3 (GN startedAt-based): For completed GN matches, groups by
// (startedAt unix-seconds | sorted names | sorted scores). Within each group:
//   1. Filter out records where completedAt < startedAt — definitively invalid, created after
//      the game ended with startedAt stamped to insertion time by the history-sync handler.
//   2. Among remaining valid records, keep the earliest completedAt (the original host save).
//      Delete the rest (history-sync artifacts with a drifted completedAt).
//   Safety valve: skip any group whose completedAt spread exceeds 20 minutes.
enum LegacyRematchRepair {
    private static let logger = AppLogger(category: "LegacyRematchRepair")

    static func run(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<MatchModel>())) ?? []
        let completed = all.filter { $0.statusRaw == "completed" }

        logger.info(Self.self, "found \(all.count) total MatchModels, \(completed.count) completed")
        for m in all.sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) {
            let parts = m.participants
                .sorted { $0.seat < $1.seat }
                .map { "\($0.displayName):\($0.finalScore)" }
                .joined(separator: ", ")
            let gn = m.isGameNight ? "GN" : "local"
            logger.info(Self.self, "  id=\(m.id.uuidString.prefix(8)) \(gn) \(m.statusRaw) startedAt=\(m.startedAt) completedAt=\(m.completedAt?.description ?? "nil") [\(parts)]")
        }

        // --- Strategy 1: ID-based dedup ---
        var byID: [UUID: [MatchModel]] = [:]
        for m in all { byID[m.id, default: []].append(m) }
        let idGroups = byID.values.filter { $0.count > 1 }

        // --- Strategy 2: Abandoned records ---
        let abandoned = all.filter { $0.statusRaw == "abandoned" }

        // --- Strategy 3: GN startedAt-based dedup ---
        let gnCompleted = completed.filter { $0.isGameNight }
        var byGNContent: [String: [MatchModel]] = [:]
        for m in gnCompleted { byGNContent[GNMatchIdentity.fingerprint(for: m), default: []].append(m) }
        let gnGroups = byGNContent.values.filter { $0.count > 1 }

        guard !idGroups.isEmpty || !abandoned.isEmpty || !gnGroups.isEmpty else {
            logger.info(Self.self, "nothing to repair")
            return
        }

        var deleted = 0
        var deletedIDs = Set<ObjectIdentifier>()

        for group in idGroups {
            let sorted = group.sorted { a, b in
                if (a.statusRaw == "completed") != (b.statusRaw == "completed") { return a.statusRaw == "completed" }
                return (a.completedAt ?? .distantPast) > (b.completedAt ?? .distantPast)
            }
            for dup in sorted.dropFirst() {
                let oid = ObjectIdentifier(dup)
                guard !deletedIDs.contains(oid) else { continue }
                deletedIDs.insert(oid)
                logger.info(Self.self, "strategy1 deleted: id=\(dup.id.uuidString.prefix(8)) \(dup.statusRaw) completedAt=\(dup.completedAt?.description ?? "nil")")
                context.delete(dup)
                deleted += 1
            }
        }

        for m in abandoned {
            let oid = ObjectIdentifier(m)
            guard !deletedIDs.contains(oid) else { continue }
            deletedIDs.insert(oid)
            logger.info(Self.self, "strategy2 deleted: id=\(m.id.uuidString.prefix(8)) abandoned startedAt=\(m.startedAt)")
            context.delete(m)
            deleted += 1
        }

        for group in gnGroups {
            // Safety valve: skip if completedAt spread exceeds 20 minutes.
            let allCompletedAt = group.compactMap { $0.completedAt }
            guard allCompletedAt.count == group.count,
                  let earliest = allCompletedAt.min(),
                  let latest = allCompletedAt.max(),
                  latest.timeIntervalSince(earliest) <= GNMatchIdentity.dupSpreadLimit else {
                logger.info(Self.self, "strategy3 skip (spread > 20min or nil completedAt): \(GNMatchIdentity.fingerprint(for: group[0]))")
                continue
            }

            // Drop records where completedAt < startedAt — definitively invalid.
            let valid = group.filter { ($0.completedAt ?? .distantPast) >= $0.startedAt }
            guard !valid.isEmpty else {
                logger.info(Self.self, "strategy3 skip (all records invalid): \(GNMatchIdentity.fingerprint(for: group[0]))")
                continue
            }

            // Keep the valid record with the earliest completedAt.
            let keeper = valid.min(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) })!
            let toDelete = group.filter { $0 !== keeper }

            logger.info(Self.self, "strategy3 group: \(GNMatchIdentity.fingerprint(for: group[0]))")
            logger.info(Self.self, "  keeper: id=\(keeper.id.uuidString.prefix(8)) completedAt=\(keeper.completedAt!)")
            for dup in toDelete {
                let oid = ObjectIdentifier(dup)
                guard !deletedIDs.contains(oid) else { continue }
                deletedIDs.insert(oid)
                let validity = (dup.completedAt ?? .distantPast) >= dup.startedAt ? "valid" : "INVALID(completedAt<startedAt)"
                logger.info(Self.self, "  deleted: id=\(dup.id.uuidString.prefix(8)) completedAt=\(dup.completedAt?.description ?? "nil") [\(validity)]")
                context.delete(dup)
                deleted += 1
            }
        }

        logger.info(Self.self, "repaired: deleted \(deleted) record(s) — \(idGroups.count) id-group(s), \(abandoned.count) abandoned, \(gnGroups.count) GN-group(s)")
        do {
            try context.save()
        } catch {
            logger.error(Self.self, "save failed: \(error)")
        }
    }
}
