import Foundation
import SyLibFeel

// The SyFive-specific recipe values. These numbers ARE the spec (07_AUDIO_HAPTICS_DESIGN §5).
// The shared recipes now come from SyLib's FeelCatalog.syzygy; only SyFive's celebration is here.
// Change nothing here without going through the feel board → freeze cycle described in §9.
// Changing any field invalidates exactly that sound's cache entry; the renderer re-renders on next launch.
extension FeelCatalog {
    static let syFive = FeelCatalog.syzygy.merging(FeelCatalog(
        sounds: [
            // §5.6 — Yatzy moment: rising bloom D4→A4→D5
            "celebration": SoundRecipe(
                id: "celebration",
                durationMs: 950,
                layers: [
                    .tone(.init(freqHz: 293.66, levelDb: -18, startMs:   0, attackMs: 6, decayTauMs: 300)),
                    .tone(.init(freqHz: 440.00, levelDb: -18, startMs:  90, attackMs: 6, decayTauMs: 300)),
                    .tone(.init(freqHz: 587.33, levelDb: -16, startMs: 180, attackMs: 6, decayTauMs: 340)),
                ]
            ),
        ],

        rattles: [:],

        haptics: [
            // §5.6 — 200 ms continuous swell aligned with D5 arrival (D-119)
            "celebration": HapticRecipe(
                id: "celebration",
                events: [.init(timeMs: 180, kind: .continuous, intensity: 0.55, sharpness: 0.15, durationMs: 200)]
            ),
        ]
    ))
}
