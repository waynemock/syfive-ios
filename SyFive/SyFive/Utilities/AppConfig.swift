import Foundation

struct AppConfig {
    struct DebugLayout {
        static let isEnabled = false
    }

    struct DebugFeel {
        /// Show the feel board in SettingsView for on-device recipe tuning (§9).
        static let showFeelBoard = false
    }

    struct DebugDice {
        /// Show physics tuning sliders in `DiceAreaView`. Flip to `true` to tune feel.
        static let showPhysicsSliders = false
        /// Show the Phase 4 fairness HUD (distribution chart, stats, batch roll, replay).
        static let showHarness = false
        /// Emit verbose diagnostics for roll lifecycle, stuck states, and rescue behavior.
        static let logRollDiagnostics = false
    }

    struct DebugCloudKit {
        /// Inserts and immediately deletes one dummy row for every registered model type,
        /// forcing CloudKit to JIT-create all record types and fields in Development.
        /// Flip to true, run once on device, verify in CloudKit Console, then flip back.
        static let runSchemaExercise = false
    }
}
