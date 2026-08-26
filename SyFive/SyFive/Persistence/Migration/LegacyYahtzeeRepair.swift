import Foundation
import SyLibScoring
import SwiftData
import SyLibCore

// Runs on every launch to repair ParticipantModel records broken by the yahtzee → yatzy field
// rename in the "Expunged yahtzee" commit. CloudKit treats a rename as field deletion + addition,
// so old records arrive with the legacy names and SwiftData defaults the new fields to 0 / empty.
//
// Fix 1 — scoreEntries slotKey: renames "yahtzee" → "yatzy" in the JSON blob.
// Fix 2 — bonusPoints (née yatzyBonus, née yahtzeeBonus): infers the correct value as
//          finalScore − cardSum − upperBonus. Exact because finalScore was denormalized at
//          completion using the in-memory bonus (correct at save time). Handles both the
//          yahtzeeBonus→yatzyBonus rename and the yatzyBonus→bonusPoints rename; old CloudKit
//          records arrive with the prior field name, SwiftData defaults bonusPoints to 0, and
//          this repair reconstructs it. gap % 100 == 0 guard prevents false positives.
//
// Both fixes are idempotent and safe to re-run. Converges once CloudKit propagates the
// corrected fields to all devices (subsequent runs find no candidates and exit immediately).
enum LegacyYahtzeeRepair {
    private static let logger = AppLogger(category: "LegacyYahtzeeRepair")

    static func run(in context: ModelContext) {
        let participants = (try? context.fetch(FetchDescriptor<ParticipantModel>())) ?? []

        var slotKeyCount = 0
        var bonusCount = 0

        for p in participants {
            // Fix 1: rename "yahtzee" slotKey in scoreEntries
            var entries = p.scoreEntries
            var slotKeyChanged = false
            for i in entries.indices where entries[i].slotKey == "yahtzee" {
                entries[i].slotKey = "yatzy"
                slotKeyChanged = true
                slotKeyCount += 1
            }
            if slotKeyChanged {
                p.scoreEntries = entries
            }

            // Fix 2: infer yatzyBonus from finalScore gap
            guard p.bonusPoints == 0, p.finalScore > 0 else { continue }
            let cardSum = entries.compactMap { $0.value }.reduce(Decimal(0), +)
            let upperSum = entries
                .filter { YatzyCategory(rawValue: $0.slotKey)?.isUpperSection == true }
                .compactMap { $0.value }
                .reduce(Decimal(0), +)
            let upperBonusPts: Decimal = upperSum >= 63 ? 35 : 0
            let gap = NSDecimalNumber(decimal: p.finalScore - cardSum - upperBonusPts).intValue
            guard gap > 0, gap % 100 == 0 else { continue }
            p.bonusPoints = gap
            bonusCount += 1
        }

        guard slotKeyCount > 0 || bonusCount > 0 else {
            logger.debug(Self.self, "nothing to repair, skipping")
            return
        }

        logger.info(Self.self, "repaired slotKeys=\(slotKeyCount) bonuses=\(bonusCount)")
        do {
            try context.save()
        } catch {
            logger.error(Self.self, "save failed: \(error)")
        }
    }
}
