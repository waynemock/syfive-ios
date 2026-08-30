import Foundation
import SwiftData
import SyLibCore
import SyLibGameNightMatch
import SyLibScoringData

// Runs on every launch to repair or remove stale MatchModel records.
//
// Strategy 1 (ID-based): Multiple records share the same `id` UUID. Keeps the completed/later
// record and deletes the rest.
//
// Strategy 2 (Abandoned): Deletes all records with statusRaw == "abandoned". The app no longer
// saves abandoned games; these are leftover from earlier builds.
//
// Strategy 3 (startedAt-based dedup): For all completed matches, groups by
// (startedAt unix-seconds | sorted names | sorted scores). Within each group:
//   1. Filter out records where completedAt < startedAt — definitively invalid (e.g. startedAt
//      was stamped to insertion time by the history-sync handler).
//   2. Among remaining valid records, keep the earliest completedAt (the original save).
//      Delete the rest (CloudKit sync duplicates or history-sync artifacts).
//   Safety valve: skip any group whose completedAt spread exceeds 20 minutes.
//
// Strategy 4 (GN no solo-owner participant): Deletes completed GN matches where no participant
// has ever appeared in a solo (1-player) local match on this device. Only the device owner
// plays solo on their own device, so this identifies their UUID. Matches that belong on this
// device always include the owner. Matches synced from other devices (e.g. Wayne+BurnTest on
// Sherida's phone) don't include Sherida, who IS in her solo history.
// Safe fallback: if no solo local matches exist, the strategy is skipped entirely.
enum LegacyRematchRepair {
    private static let logger = AppLogger(category: "LegacyRematchRepair")

    static func run(in context: ModelContext) {
        // --- Orphan sweep: participants left behind by prior match deletes ---
        let orphanedParticipants = (try? context.fetch(
            FetchDescriptor<ParticipantModel>(predicate: #Predicate { $0.match == nil })
        )) ?? []
        if !orphanedParticipants.isEmpty {
            logger.info(Self.self, "orphan sweep: deleting \(orphanedParticipants.count) orphaned ParticipantModel(s)")
            orphanedParticipants.forEach { context.delete($0) }
            try? context.save()
        }

        let all = (try? context.fetch(FetchDescriptor<MatchModel>())) ?? []
        let completed = all.filter { $0.statusRaw == "completed" }

        logger.info(Self.self, "found \(all.count) total MatchModels, \(completed.count) completed")
//        for m in all.sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) {
//            let parts = m.participants
//                .sorted { $0.seat < $1.seat }
//                .map { "\($0.displayName):\($0.finalScore)" }
//                .joined(separator: ", ")
//            let gn = m.isGameNight ? "GN" : "local"
//            logger.info(Self.self, "  id=\(m.id.uuidString.prefix(8)) \(gn) \(m.statusRaw) startedAt=\(m.startedAt) completedAt=\(m.completedAt?.description ?? "nil") [\(parts)]")
//        }

        // --- Strategy 1: ID-based dedup ---
        var byID: [UUID: [MatchModel]] = [:]
        for m in all { byID[m.id, default: []].append(m) }
        let idGroups = byID.values.filter { $0.count > 1 }

        // --- Strategy 2: Abandoned records ---
        let abandoned = all.filter { $0.statusRaw == "abandoned" }

        // --- Strategy 4: GN matches with no solo-owner participant ---
        let soloPlayerIDs: Set<UUID> = {
            let soloLocalMatches = completed.filter { !$0.isGameNight && $0.participants.count == 1 }
            return Set(soloLocalMatches.compactMap { $0.participants.first?.playerID })
        }()
        logger.info(Self.self, "strategy4 solo-owner IDs: \(soloPlayerIDs.map { $0.uuidString.prefix(8) })")
        let gnCompleted = completed.filter { $0.isGameNight }
        let foreignGN: [MatchModel] = soloPlayerIDs.isEmpty ? [] : gnCompleted.filter { model in
            let pIDs = model.participants.compactMap { $0.playerID }
            guard !pIDs.isEmpty else { return false }
            return !pIDs.contains { soloPlayerIDs.contains($0) }
        }

        // --- Strategy 3: startedAt-based dedup (all completed) ---
        var byContent: [String: [MatchModel]] = [:]
        for m in completed { byContent[GNMatchIdentity.fingerprint(for: m), default: []].append(m) }
        let contentGroups = byContent.values.filter { $0.count > 1 }

        guard !idGroups.isEmpty || !abandoned.isEmpty || !foreignGN.isEmpty || !contentGroups.isEmpty else {
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
                dup.participants.forEach { context.delete($0) }
                context.delete(dup)
                deleted += 1
            }
        }

        for m in abandoned {
            let oid = ObjectIdentifier(m)
            guard !deletedIDs.contains(oid) else { continue }
            deletedIDs.insert(oid)
            logger.info(Self.self, "strategy2 deleted: id=\(m.id.uuidString.prefix(8)) abandoned startedAt=\(m.startedAt)")
            m.participants.forEach { context.delete($0) }
            context.delete(m)
            deleted += 1
        }

        for m in foreignGN {
            let oid = ObjectIdentifier(m)
            guard !deletedIDs.contains(oid) else { continue }
            deletedIDs.insert(oid)
            let participantIDs = m.participants.compactMap { $0.playerID }.map { $0.uuidString.prefix(8) }
            logger.info(Self.self, "strategy4 deleted: id=\(m.id.uuidString.prefix(8)) no-solo-owner GN startedAt=\(m.startedAt) participantIDs=\(participantIDs)")
            m.participants.forEach { context.delete($0) }
            context.delete(m)
            deleted += 1
        }

        for group in contentGroups {
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
                dup.participants.forEach { context.delete($0) }
                context.delete(dup)
                deleted += 1
            }
        }

        logger.info(Self.self, "repaired: deleted \(deleted) record(s) — \(idGroups.count) id-group(s), \(abandoned.count) abandoned, \(foreignGN.count) foreign-GN, \(contentGroups.count) content-group(s)")
        do {
            try context.save()
        } catch {
            logger.error(Self.self, "save failed: \(error)")
        }
    }
}
