import Foundation

struct AppConfig {
    struct DebugLayout {
        static let isEnabled = false
    }

    struct DebugDice {
        /// Show physics tuning sliders in `DiceAreaView`. Flip to `true` to tune feel.
        static let showPhysicsSliders = false
        /// Show the Phase 4 fairness HUD (distribution chart, stats, batch roll, replay).
        static let showHarness = false
    }
}
