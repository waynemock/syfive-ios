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
        /// Runs `SyFiveApp.initializeCloudKitSchema` at launch, before the store opens: pushes
        /// every record type and field to CloudKit Development (D-026). Flip to true, run once
        /// on a device signed into iCloud, verify in CloudKit Console, then flip back.
        static let runSchemaExercise = false
    }

    struct DebugGameNight {
        /// Capture Game Night logs per session and surface a "Game Night Logs" button
        /// at the bottom of each GN match detail sheet. Flip to false before shipping.
        static let showLogs = false
    }
}
