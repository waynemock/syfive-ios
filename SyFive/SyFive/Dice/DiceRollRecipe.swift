import Foundation
import simd

/// Full snapshot of one roll for deterministic debug replay.
/// Held in memory as `lastRecipe` on `DiceRoller`; replay is in-session only.
struct DiceRollRecipe: Codable {
    let seed: UInt64
    let appVersion: String
    let timestamp: Date
    let dice: [DieLaunchParams]

    struct DieLaunchParams: Codable {
        let spawnPosition: Vec3
        let impulse: Vec3
        let torque: Vec3
    }

    /// Codable wrapper for SIMD3<Float>.
    struct Vec3: Codable {
        let x, y, z: Float
        init(_ v: SIMD3<Float>) { x = v.x; y = v.y; z = v.z }
        var simd: SIMD3<Float> { .init(x, y, z) }
    }
}
