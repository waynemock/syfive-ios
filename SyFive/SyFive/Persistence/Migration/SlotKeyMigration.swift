import Foundation
import SwiftData

// One-time migration: renames scoreEntry slotKey "yahtzee" → "yatzy" in the JSON blob
// stored on ParticipantModel.scoreEntriesData. Runs once per device (UserDefaults flag).
//
// Safe to remove once all beta users have installed this build and the four-person
// test group has confirmed their history data looks correct.
enum SlotKeyMigration {
    private static let doneKey = "slotKeyMigration_yatzy_v1"
    private static let logger = AppLogger(category: "SlotKeyMigration")

    static func runIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: doneKey) else {
            logger.debug(Self.self, "already ran, skipping")
            return
        }
        defer { UserDefaults.standard.set(true, forKey: doneKey) }

        logger.info(Self.self, "starting slotKey migration: 'yahtzee' → 'yatzy'")

        let participants = (try? context.fetch(FetchDescriptor<ParticipantModel>())) ?? []
        var migratedParticipants = 0
        var migratedEntries = 0

        for participant in participants {
            var entries = participant.scoreEntries
            var changed = false
            for i in entries.indices where entries[i].slotKey == "yahtzee" {
                entries[i].slotKey = "yatzy"
                changed = true
                migratedEntries += 1
            }
            if changed {
                participant.scoreEntries = entries
                migratedParticipants += 1
            }
        }

        if migratedParticipants > 0 {
            do {
                try context.save()
                logger.info(Self.self, "migration complete: \(migratedEntries) entries across \(migratedParticipants) participants")
            } catch {
                logger.error(Self.self, "save failed after migration: \(error)")
            }
        } else {
            logger.info(Self.self, "migration complete: no 'yahtzee' slotKeys found (clean install or already migrated via CloudKit sync)")
        }
    }
}
