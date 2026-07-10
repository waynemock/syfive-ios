import Foundation

// The SyFive-specific recipe values. These numbers ARE the spec (07_AUDIO_HAPTICS_DESIGN §5).
// Change nothing here without going through the feel board → freeze cycle described in §9.
// Changing any field invalidates exactly that sound's cache entry; the renderer re-renders on next launch.
extension FeelCatalog {
    static let syFive = FeelCatalog(
        sounds: [
            // §5.1 — per-die thunk; variant selected by die index (0–4)
            "settle_thunk": SoundRecipe(
                id: "settle_thunk",
                durationMs: 160,
                renderSeed: 24301,
                layers: [
                    .tone(.init(freqHz: 146.83, levelDb: -6,  startMs: 0, attackMs: 2, decayTauMs: 70,  bendCents: -15, bendMs: 30)),
                    .tone(.init(freqHz: 73.42,  levelDb: -14, startMs: 0, attackMs: 2, decayTauMs: 45,  bendCents: 0,   bendMs: 0)),
                    .noise(.init(bandLowHz: 300, bandHighHz: 1200, levelDb: -22, startMs: 0, attackMs: 1, decayTauMs: 4)),
                ],
                variants: [
                    .init(pitchCents: -38, levelDb: -0.6),
                    .init(pitchCents: -19, levelDb: -0.2),
                    .init(pitchCents:   0, levelDb:  0.0),
                    .init(pitchCents:  21, levelDb: -0.4),
                    .init(pitchCents:  40, levelDb: -0.8),
                ]
            ),

            // §5.3 — hold engage: rising D6 ping (latch metaphor)
            "hold_engage": SoundRecipe(
                id: "hold_engage",
                durationMs: 70,
                layers: [
                    .tone(.init(freqHz: 1174.66, levelDb: -14, startMs: 0, attackMs: 1, decayTauMs: 25)),
                    .noise(.init(bandLowHz: 1500, bandHighHz: 4000, levelDb: -24, startMs: 0, attackMs: 1, decayTauMs: 3)),
                ]
            ),

            // §5.3 — hold release: falling fifth A5 (release metaphor)
            "hold_release": SoundRecipe(
                id: "hold_release",
                durationMs: 60,
                layers: [
                    .tone(.init(freqHz: 880, levelDb: -16, startMs: 0, attackMs: 1, decayTauMs: 20)),
                    .noise(.init(bandLowHz: 1500, bandHighHz: 4000, levelDb: -26, startMs: 0, attackMs: 1, decayTauMs: 3)),
                ]
            ),

            // §5.4 — yellow stuck die nudge: A3 wood knock
            "die_nudge": SoundRecipe(
                id: "die_nudge",
                durationMs: 110,
                layers: [
                    .tone(.init(freqHz: 220, levelDb: -12, startMs: 0, attackMs: 1, decayTauMs: 40)),
                    .noise(.init(bandLowHz: 400, bandHighHz: 1600, levelDb: -20, startMs: 0, attackMs: 2, decayTauMs: 4)),
                ]
            ),

            // §5.4 — red stuck die reroll: heavier D3 knock
            "die_reroll": SoundRecipe(
                id: "die_reroll",
                durationMs: 120,
                layers: [
                    .tone(.init(freqHz: 146.83, levelDb: -11, startMs: 0, attackMs: 1, decayTauMs: 45)),
                    .noise(.init(bandLowHz: 350, bandHighHz: 1400, levelDb: -19, startMs: 0, attackMs: 2, decayTauMs: 5)),
                ]
            ),

            // §5.5 — score confirm: rolled D5+A5 dyad
            "score_confirm": SoundRecipe(
                id: "score_confirm",
                durationMs: 480,
                layers: [
                    .tone(.init(freqHz: 587.33, levelDb: -16, startMs:  0, attackMs: 4, decayTauMs: 180)),
                    .tone(.init(freqHz: 880.00, levelDb: -18, startMs: 60, attackMs: 4, decayTauMs: 160)),
                ]
            ),

            // §5.6 — Yatzy moment: rising bloom D4→A4→D5
            "yatzy_moment": SoundRecipe(
                id: "yatzy_moment",
                durationMs: 950,
                layers: [
                    .tone(.init(freqHz: 293.66, levelDb: -18, startMs:   0, attackMs: 6, decayTauMs: 300)),
                    .tone(.init(freqHz: 440.00, levelDb: -18, startMs:  90, attackMs: 6, decayTauMs: 300)),
                    .tone(.init(freqHz: 587.33, levelDb: -16, startMs: 180, attackMs: 6, decayTauMs: 340)),
                ]
            ),

            // §5.7 — game end: falling resolution D5→A4→D4
            "game_end": SoundRecipe(
                id: "game_end",
                durationMs: 1400,
                layers: [
                    .tone(.init(freqHz: 587.33, levelDb: -18, startMs:   0, attackMs: 8, decayTauMs: 420)),
                    .tone(.init(freqHz: 440.00, levelDb: -18, startMs: 150, attackMs: 8, decayTauMs: 460)),
                    .tone(.init(freqHz: 293.66, levelDb: -16, startMs: 300, attackMs: 8, decayTauMs: 520)),
                ]
            ),

            // §5.8 — undo: tiny D3 set-down tick (lean; see §11 open decision)
            "undo": SoundRecipe(
                id: "undo",
                durationMs: 70,
                layers: [
                    .tone(.init(freqHz: 146.83, levelDb: -20, startMs: 0, attackMs: 2, decayTauMs: 30)),
                ]
            ),
        ],

        rattles: [
            // §5.2 — Poisson grain bed; four seeded variants round-robined per roll
            "rattle_bed": RattleRecipe(
                id: "rattle_bed",
                durationMs: 1800,
                grainBandsHz: [[700, 1800], [900, 2600], [1200, 3200]],
                grainDurMs: 5,
                grainAttackMs: 0.5,
                grainDecayTauMs: 1.5,
                grainLevelDb: -26,
                grainLevelJitterDb: -3,
                densityFloorPerSec: 6,
                densityPeakPerSec: 28,
                densityTauSec: 0.45,
                tailFadeMs: 150,
                seeds: [0xD1CE0001, 0xD1CE0002, 0xD1CE0003, 0xD1CE0004]
            ),
        ],

        haptics: [
            // §5.1 — per-die settle (per-die option; §11 open decision)
            "settle_die": HapticRecipe(
                id: "settle_die",
                events: [.init(timeMs: 0, kind: .transient, intensity: 0.38, sharpness: 0.28)]
            ),

            // §5.1 — fallback single pulse on allDiceSettled
            "settle_all": HapticRecipe(
                id: "settle_all",
                events: [.init(timeMs: 0, kind: .transient, intensity: 0.50, sharpness: 0.30)]
            ),

            // §5.3
            "hold_engage": HapticRecipe(
                id: "hold_engage",
                events: [.init(timeMs: 0, kind: .transient, intensity: 0.45, sharpness: 0.70)]
            ),
            "hold_release": HapticRecipe(
                id: "hold_release",
                events: [.init(timeMs: 0, kind: .transient, intensity: 0.35, sharpness: 0.55)]
            ),

            // §5.4
            "die_nudge": HapticRecipe(
                id: "die_nudge",
                events: [.init(timeMs: 0, kind: .transient, intensity: 0.50, sharpness: 0.50)]
            ),
            "die_reroll": HapticRecipe(
                id: "die_reroll",
                events: [.init(timeMs: 0, kind: .transient, intensity: 0.55, sharpness: 0.45)]
            ),

            // §5.5 — mirrored roll: two transients
            "score_confirm": HapticRecipe(
                id: "score_confirm",
                events: [
                    .init(timeMs:  0, kind: .transient, intensity: 0.40, sharpness: 0.40),
                    .init(timeMs: 60, kind: .transient, intensity: 0.32, sharpness: 0.45),
                ]
            ),

            // §5.6 — canonical: soft tick aligned with D5 arrival
            "yatzy_moment": HapticRecipe(
                id: "yatzy_moment",
                events: [.init(timeMs: 180, kind: .transient, intensity: 0.50, sharpness: 0.25)]
            ),

            // §5.7
            "game_end": HapticRecipe(
                id: "game_end",
                events: [
                    .init(timeMs:   0, kind: .transient, intensity: 0.35, sharpness: 0.30),
                    .init(timeMs: 300, kind: .transient, intensity: 0.45, sharpness: 0.22),
                ]
            ),

            // §5.8
            "undo": HapticRecipe(
                id: "undo",
                events: [.init(timeMs: 0, kind: .transient, intensity: 0.25, sharpness: 0.35)]
            ),
        ]
    )
}
