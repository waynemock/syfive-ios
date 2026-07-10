import Foundation

// MARK: - SoundRecipe

struct SoundRecipe: Codable, Hashable {
    var id: String
    var durationMs: Double
    var renderSeed: UInt64 = 0x5EED
    var layers: [Layer]
    var variants: [Variant] = []

    enum Layer: Codable, Hashable {
        case tone(Tone)
        case noise(Noise)
    }

    struct Tone: Codable, Hashable {
        var freqHz: Double
        var levelDb: Double
        var startMs: Double = 0
        var attackMs: Double
        var decayTauMs: Double
        var bendCents: Double = 0
        var bendMs: Double = 0
    }

    struct Noise: Codable, Hashable {
        var bandLowHz: Double
        var bandHighHz: Double
        var levelDb: Double
        var startMs: Double = 0
        var attackMs: Double
        var decayTauMs: Double
    }

    // Whole-render transposition / trim applied at render time, not authoring time.
    struct Variant: Codable, Hashable {
        var pitchCents: Double
        var levelDb: Double
    }
}

// MARK: - RattleRecipe

struct RattleRecipe: Codable, Hashable {
    var id: String
    var durationMs: Double
    var grainBandsHz: [[Double]]        // [[low, high], ...] — seeded pick per grain
    var grainDurMs: Double
    var grainAttackMs: Double
    var grainDecayTauMs: Double
    var grainLevelDb: Double
    var grainLevelJitterDb: Double      // uniform [−|j|, 0], seeded
    var densityFloorPerSec: Double
    var densityPeakPerSec: Double
    var densityTauSec: Double           // λ(t) = floor + (peak − floor)·e^(−t/τ)
    var tailFadeMs: Double
    var seeds: [UInt64]                 // one cached variant per seed
}

// MARK: - HapticRecipe

struct HapticRecipe: Codable, Hashable {
    var id: String
    var events: [HEvent]

    struct HEvent: Codable, Hashable {
        var timeMs: Double
        var kind: Kind
        var intensity: Double
        var sharpness: Double
        var durationMs: Double? = nil
        var intensityCurve: [CurvePoint]? = nil
    }

    enum Kind: String, Codable { case transient, continuous }

    struct CurvePoint: Codable, Hashable {
        var timeMs: Double
        var value: Double
    }
}

// MARK: - FeelCatalog

struct FeelCatalog: Codable {
    var sounds: [String: SoundRecipe]
    var rattles: [String: RattleRecipe]
    var haptics: [String: HapticRecipe]
    var rootHz: Double = 146.83         // D3 — single family-tuning constant
}
