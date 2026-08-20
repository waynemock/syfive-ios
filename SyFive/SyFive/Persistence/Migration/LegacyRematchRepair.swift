import Foundation
import SwiftData

// Runs on every launch to repair MatchModel records duplicated by the pre-fix rematch save bug.
//
// Strategy 1 (ID-based): Multiple records share the same `id` UUID. Keeps the completed/later
// record and deletes the rest.
//
// Strategy 2 (Content-based): Records share the same completedAt timestamp, sorted final scores,
// and sorted player names — but have different id values or different isGameNight flags. This
// happens when onMatchComplete creates one row while saveMatch() simultaneously overwrites a
// prior game's row with the same match content, or when a GN match also gets saved as a local
// non-GN record. Keep the GN-flagged record when available; otherwise the completed/later one.
enum LegacyRematchRepair {
    private static let logger = AppLogger(category: "LegacyRematchRepair")

    static func run(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<MatchModel>())) ?? []
        let completed = all.filter { $0.statusRaw == "completed" }

        logger.debug(Self.self, "found \(all.count) total MatchModels, \(completed.count) completed")

        // --- Strategy 1: ID-based dedup ---
        var byID: [UUID: [MatchModel]] = [:]
        for m in all {
            byID[m.id, default: []].append(m)
        }
        let idGroups = byID.values.filter { $0.count > 1 }

        // --- Strategy 2: Content fingerprint across ALL completed matches ---
        // Fingerprint = "<completedAt-unix-seconds>|<sorted names>|<sorted scores>"
        // Matches the same game saved twice (as GN and local, or with different IDs).
        func fingerprint(_ m: MatchModel) -> String {
            let ts = m.completedAt.map { String(Int($0.timeIntervalSince1970)) } ?? "nil"
            let names = m.participants.map { $0.displayName }.sorted().joined(separator: "|")
            let scores = m.participants.map { "\($0.finalScore)" }.sorted().joined(separator: "|")
            return "\(ts)|\(names)|\(scores)"
        }
        var byContent: [String: [MatchModel]] = [:]
        for m in completed {
            byContent[fingerprint(m), default: []].append(m)
        }
        let contentGroups = byContent.values.filter { $0.count > 1 }

        guard !idGroups.isEmpty || !contentGroups.isEmpty else {
            logger.info(Self.self, "nothing to repair")
            return
        }

        var deleted = 0
        var deletedIDs = Set<ObjectIdentifier>()

        // Dedup by ID (strategy 1).
        for group in idGroups {
            let sorted = group.sorted { a, b in
                if (a.statusRaw == "completed") != (b.statusRaw == "completed") {
                    return a.statusRaw == "completed"
                }
                return (a.completedAt ?? .distantPast) > (b.completedAt ?? .distantPast)
            }
            for dup in sorted.dropFirst() {
                let oid = ObjectIdentifier(dup)
                guard !deletedIDs.contains(oid) else { continue }
                deletedIDs.insert(oid)
                context.delete(dup)
                deleted += 1
            }
        }

        // Dedup by content (strategy 2).
        for group in contentGroups {
            let remaining = group.filter { !deletedIDs.contains(ObjectIdentifier($0)) }
            guard remaining.count > 1 else { continue }
            logger.info(Self.self, "content-dedup: \(remaining.count) records with fingerprint '\(fingerprint(remaining[0]))'")
            // Prefer GN-flagged records; break ties by keeping the one whose id sorts first.
            let sorted = remaining.sorted { a, b in
                if a.isGameNight != b.isGameNight { return a.isGameNight }
                return a.id.uuidString < b.id.uuidString
            }
            for dup in sorted.dropFirst() {
                let oid = ObjectIdentifier(dup)
                guard !deletedIDs.contains(oid) else { continue }
                deletedIDs.insert(oid)
                context.delete(dup)
                deleted += 1
            }
        }

        logger.info(Self.self, "repaired: deleted \(deleted) duplicate(s) from \(idGroups.count) id-group(s), \(contentGroups.count) content-group(s)")
        do {
            try context.save()
        } catch {
            logger.error(Self.self, "save failed: \(error)")
        }
    }
}
