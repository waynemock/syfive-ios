import Foundation

/// Seeded linear congruential random number generator conforming to `RandomNumberGenerator`.
/// The same seed produces the same sequence — enables deterministic roll replay for debugging.
struct DiceRandSource: RandomNumberGenerator {

    private var state: UInt64

    /// Creates a source from a fixed seed (for deterministic replay).
    init(seed: UInt64) {
        self.state = seed
    }

    /// Creates a source seeded from the current time (for normal play).
    init() {
        self.state = UInt64(bitPattern: Int64(Date().timeIntervalSinceReferenceDate * 1_000_000))
    }

    /// Snapshot of the current state — use as a seed to replay an identical sequence.
    var currentSeed: UInt64 { state }

    mutating func next() -> UInt64 {
        // Knuth multiplicative LCG
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
