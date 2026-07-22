import RealityKit
import UIKit

/// Wraps a `ModelEntity` to add die-specific behaviour: face reading, held state, launch.
/// Uses composition instead of inheritance because `ModelEntity` is not open.
@MainActor
final class DiceEntity {
    private var palette: DiceTintPalette
    private var isPinnedForPresentation = false

    // MARK: - Constants

    static let dieSize: Float = 0.042
    /// Heuristic support radius used for rescue / proximity checks only.
    /// This is intentionally softer than the cube half-extent but not a full sphere.
    static let supportHeuristicRadius: Float = dieSize * 0.62
    /// Fuller radius used when deciding whether a tilted die is effectively crowding a tray wall.
    /// This is based on the die's containing sphere, not the softer support heuristic.
    static let wallHeuristicRadius: Float = dieSize * 0.8660254

    private var normalTint: UIColor { palette.normal }
    private var heldTint: UIColor { palette.held }
    private var nudgeableTint: UIColor { palette.nudgeable }
    private var stuckTint: UIColor { palette.stuck }
    private var pipTint: UIColor { palette.pip }

    /// Local-space face normals → pip value (standard Western die layout).
    static let faceNormals: [(normal: SIMD3<Float>, value: Int)] = [
        (.init(0,  1,  0), 1),   // +Y → 1
        (.init(0, -1,  0), 6),   // −Y → 6
        (.init(1,  0,  0), 2),   // +X → 2
        (.init(-1,  0,  0), 5),  // −X → 5
        (.init(0,  0,  1), 3),   // +Z → 3
        (.init(0,  0, -1), 4),   // −Z → 4
    ]

    // MARK: - Underlying entity

    /// The actual RealityKit entity added to the scene — carries physics, collision, and input target.
    /// Has no model; all rendering is done by the child `visualEntity`.
    let entity: ModelEntity

    /// Chamfered visual die mesh + pips — purely cosmetic, no physics. Child of `entity`.
    private let visualEntity = ModelEntity()

    // MARK: - State

    /// When held, switches the physics body to kinematic so it won't move.
    var isHeld: Bool = false {
        didSet { applyPhysicsMode() }
    }

    var isStuck: Bool = false {
        didSet { rebuildAppearance() }
    }

    var isNudgeable: Bool = false {
        didSet { rebuildAppearance() }
    }

    // MARK: - Computed

    /// Pip value of the face currently pointing most upward in world space.
    var topFaceValue: Int {
        topFaceMeasurement.value
    }

    /// The best upward-facing face and its alignment with world up.
    var topFaceMeasurement: (value: Int, alignment: Float) {
        let worldUp = SIMD3<Float>(0, 1, 0)
        let rot = entity.transform.rotation
        var bestDot: Float = -2
        var best = 1
        for (localNormal, value) in Self.faceNormals {
            let worldNormal = rot.act(localNormal)
            let d = simd_dot(worldNormal, worldUp)
            if d > bestDot { bestDot = d; best = value }
        }
        return (best, bestDot)
    }

    var linearSpeed: Float {
        simd_length(entity.physicsMotion?.linearVelocity ?? .zero)
    }

    var angularSpeed: Float {
        simd_length(entity.physicsMotion?.angularVelocity ?? .zero)
    }

    var topFaceAlignment: Float {
        topFaceMeasurement.alignment
    }

    /// Height of the die center above the tray floor plane.
    var centerHeightAboveTrayFloor: Float {
        entity.position.y
    }

    // MARK: - Init

    init(palette: DiceTintPalette) {
        self.palette = palette
        entity = ModelEntity()
        entity.addChild(visualEntity)
        buildMesh()
        buildPhysics()
        buildPips()
    }

    func updatePalette(_ palette: DiceTintPalette) {
        self.palette = palette
        rebuildAppearance()
    }

    // MARK: - Build

    private func buildMesh() {
        let s = Self.dieSize
        let mesh = MeshResource.generateBox(size: .init(s, s, s), cornerRadius: 0.005)
        visualEntity.model = ModelComponent(mesh: mesh, materials: [makeMaterial(held: false, stuck: false, nudgeable: false)])
    }

    private func makeMaterial(held: Bool, stuck: Bool, nudgeable: Bool) -> SimpleMaterial {
        var mat = SimpleMaterial()
        let tint: UIColor
        if stuck {
            tint = stuckTint
        } else if nudgeable {
            tint = nudgeableTint
        } else if held {
            tint = heldTint
        } else {
            tint = normalTint
        }
        mat.color = .init(tint: tint)
        mat.roughness = .float(held ? 0.15 : 0.35)
        mat.metallic  = .float(held ? 0.35 : 0.10)
        return mat
    }

    private func buildPhysics() {
        let s = Self.dieSize
        // Convex hull of the chamfered visual mesh: no sharp edges, so the physics engine
        // generates point contacts instead of edge-line contacts. Edge-line contacts created
        // artificial friction torque that held the die in stable tilted equilibria; point
        // contacts have no such torque and the die self-rights naturally.
        let chamferedMesh = MeshResource.generateBox(size: .init(s, s, s), cornerRadius: 0.005)
        let shape = ShapeResource.generateConvex(from: chamferedMesh)
        let physMat = PhysicsMaterialResource.generate(
            staticFriction: 0.30,
            dynamicFriction: 0.25,
            restitution: 0.30
        )
        var body = PhysicsBodyComponent(shapes: [shape], mass: 0.02, material: physMat, mode: .dynamic)
        body.angularDamping = 2.0
        body.linearDamping = 0.8
        entity.components.set(CollisionComponent(shapes: [shape]))
        entity.components.set(body)
        // Required for SpatialTapGesture to target this entity.
        entity.components.set(InputTargetComponent())
    }

    // MARK: - Pips

    /// Attaches flat dark disc child entities to each face in standard Western die pip layout.
    ///
    /// True concave indentations are impossible without modifying the die mesh (no CSG in
    /// RealityKit). Flat dark discs with `UnlitMaterial` are the standard 3D-game approach:
    /// the unlit near-black circles against the lit white die body read unmistakably as pips.
    /// Children have no collision/physics so they don't affect the simulation.
    private func buildPips() {
        let h = Self.dieSize / 2   // 0.021 m — distance from die center to face surface
        let pipRadius: Float = 0.0042
        let spread: Float = 0.0115

        // Unlit material → pure dark colour regardless of scene lighting.
        let pipMat = UnlitMaterial(color: pipTint)

        guard let pipMesh = try? Self.makePipDiscMesh(radius: pipRadius) else { return }

        // (face normal, tangent = local right on face, bitangent = local up on face, pip value)
        let faceAxes: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, Int)] = [
            (.init( 0,  1,  0), .init( 1,  0,  0), .init( 0,  0, -1), 1),
            (.init( 0, -1,  0), .init( 1,  0,  0), .init( 0,  0,  1), 6),
            (.init( 1,  0,  0), .init( 0,  0, -1), .init( 0,  1,  0), 2),
            (.init(-1,  0,  0), .init( 0,  0,  1), .init( 0,  1,  0), 5),
            (.init( 0,  0,  1), .init( 1,  0,  0), .init( 0,  1,  0), 3),
            (.init( 0,  0, -1), .init(-1,  0,  0), .init( 0,  1,  0), 4),
        ]

        for (normal, tangent, bitangent, value) in faceAxes {
            // Rotate disc so its face (+Y in mesh space) aligns with the die face normal.
            let orientation = Self.quaternionAligning(.init(0, 1, 0), to: normal)
            // Tiny offset above the face surface to prevent z-fighting with the die box.
            let faceOrigin = normal * (h + 0.0003)

            for (u, v) in Self.pipOffsets(for: value) {
                let pip = ModelEntity(mesh: pipMesh, materials: [pipMat])
                pip.position    = faceOrigin
                    + tangent   * (u * spread)
                    + bitangent * (v * spread)
                pip.orientation = orientation
                visualEntity.addChild(pip)
            }
        }
    }

    /// Flat circular disc in the XZ plane (normal = +Y). Used for pip rendering.
    private static func makePipDiscMesh(radius: Float) throws -> MeshResource {
        let slices = 20
        var positions: [SIMD3<Float>] = []
        var normals:   [SIMD3<Float>] = []
        var indices:   [UInt32] = []

        // Centre vertex
        positions.append(.zero)
        normals.append(.init(0, 1, 0))

        // Rim vertices
        for i in 0..<slices {
            let theta = (2 * Float.pi) * Float(i) / Float(slices)
            positions.append(.init(radius * cos(theta), 0, radius * sin(theta)))
            normals.append(.init(0, 1, 0))
        }

        // Fan from centre — CCW from +Y so normals face outward (toward viewer).
        // Order is [centre, rim[i+1], rim[i]] — reversing b/c gives the +Y outward normal.
        for i in 0..<UInt32(slices) {
            let b = 1 + i
            let c = 1 + (i + 1) % UInt32(slices)
            indices += [0, c, b]
        }

        var desc = MeshDescriptor()
        desc.positions  = MeshBuffer(positions)
        desc.normals    = MeshBuffer(normals)
        desc.primitives = .triangles(indices)
        return try MeshResource.generate(from: [desc])
    }

    /// Returns a quaternion rotating `from` onto `to`, handling the antiparallel edge case.
    private static func quaternionAligning(_ from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let d = simd_dot(from, to)
        if d > 0.9999 { return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
        if d < -0.9999 {
            var perp = simd_cross(from, SIMD3<Float>(1, 0, 0))
            if simd_length(perp) < 0.001 { perp = simd_cross(from, SIMD3<Float>(0, 0, 1)) }
            return simd_quatf(angle: .pi, axis: simd_normalize(perp))
        }
        return simd_quatf(from: from, to: to)
    }

    /// (u, v) unit offsets for each face value. Scaled by `spread` in `buildPips()`.
    private static func pipOffsets(for value: Int) -> [(Float, Float)] {
        switch value {
        case 1: return [(0, 0)]
        case 2: return [(-1,  1), ( 1, -1)]
        case 3: return [(-1,  1), ( 0,  0), ( 1, -1)]
        case 4: return [(-1,  1), ( 1,  1), (-1, -1), ( 1, -1)]
        case 5: return [(-1,  1), ( 1,  1), ( 0,  0), (-1, -1), ( 1, -1)]
        case 6: return [(-1,  1), ( 1,  1), (-1,  0), ( 1,  0), (-1, -1), ( 1, -1)]
        default: return []
        }
    }

    // MARK: - Launch

    /// Teleport die to `spawnPos`, apply a varied impulse + dual-axis torque.
    ///
    /// - Parameters:
    ///   - impulseRange: Scalar magnitude range for the launch impulse.
    ///   - torqueRange:  Scalar magnitude range for the primary spin torque.
    ///   - coneHalfAngle: Max angle (radians) the impulse direction deviates from straight up.
    ///                    Larger values → more sideways bounces. Suggested range: 0.35–0.80.
    @discardableResult
    func launch(
        at spawnPos: SIMD3<Float>,
        impulseRange: ClosedRange<Float> = 0.04...0.11,
        torqueRange:  ClosedRange<Float> = 0.05...0.15,
        coneHalfAngle: Float = 0.70,
        using rng: inout DiceRandSource
    ) -> DiceRollRecipe.DieLaunchParams {
        isPinnedForPresentation = false
        entity.position = spawnPos

        // Uniform random rotation via Shoemake (1992) — avoids the identity-clustering
        // bias that arises from (uniform angle, normalized-cube axis) parameterisation.
        let u1 = Float.random(in: 0..<1, using: &rng)
        let u2 = Float.random(in: 0..<1, using: &rng)
        let u3 = Float.random(in: 0..<1, using: &rng)
        entity.orientation = simd_quatf(
            ix: sqrt(1 - u1) * sin(2 * .pi * u2),
            iy: sqrt(1 - u1) * cos(2 * .pi * u2),
            iz: sqrt(u1)     * sin(2 * .pi * u3),
            r:  sqrt(u1)     * cos(2 * .pi * u3)
        )

        // Zero existing motion
        var motion = PhysicsMotionComponent()
        motion.linearVelocity = .zero
        motion.angularVelocity = .zero
        entity.components.set(motion)

        // Ensure dynamic
        if var body = entity.components[PhysicsBodyComponent.self] {
            body.mode = .dynamic
            entity.components.set(body)
        }

        // Cone-sampled impulse direction — uniform distribution on a spherical cap around +Y.
        // cosTheta is sampled in [cos(coneHalfAngle), 1], giving varying upward vs lateral split.
        let cosMax  = cos(coneHalfAngle)
        let cosTheta = Float.random(in: cosMax...1.0, using: &rng)
        let sinTheta = sqrt(max(0, 1 - cosTheta * cosTheta))
        let phi = Float.random(in: 0 ..< (.pi * 2), using: &rng)
        let impDir = SIMD3<Float>(sinTheta * cos(phi), cosTheta, sinTheta * sin(phi))
        let impMag = Float.random(in: impulseRange, using: &rng)
        let impulse = impDir * impMag

        // Dual-axis torque: primary spin + secondary wobble on a perpendicular axis.
        // Combines two independent random axes so tumbling is less predictable.
        let torqueMag1 = Float.random(in: torqueRange, using: &rng)
        let torqueMag2 = Float.random(in: (torqueRange.lowerBound * 0.4)...(torqueRange.upperBound * 0.5), using: &rng)
        let torque = randomUnitVector(using: &rng) * torqueMag1
                   + randomUnitVector(using: &rng) * torqueMag2

        entity.addForce(impulse, relativeTo: nil)
        entity.addTorque(torque, relativeTo: nil)

        return DiceRollRecipe.DieLaunchParams(
            spawnPosition: .init(spawnPos),
            impulse: .init(impulse),
            torque: .init(torque)
        )
    }

    func present(value: Int, at position: SIMD3<Float>, isHeld: Bool) {
        entity.isEnabled = true
        isPinnedForPresentation = true
        entity.position = position
        self.isStuck = false

        if let targetNormal = Self.faceNormals.first(where: { $0.value == value })?.normal {
            entity.orientation = Self.quaternionAligning(targetNormal, to: SIMD3<Float>(0, 1, 0))
        }

        var motion = PhysicsMotionComponent()
        motion.linearVelocity = .zero
        motion.angularVelocity = .zero
        entity.components.set(motion)

        self.isHeld = isHeld
        applyPhysicsMode()
    }

    // MARK: - Private helpers

    private func randomUnitVector(using rng: inout DiceRandSource) -> SIMD3<Float> {
        let raw = SIMD3<Float>(
            Float.random(in: -1...1, using: &rng),
            Float.random(in: -1...1, using: &rng),
            Float.random(in: -1...1, using: &rng)
        )
        return simd_length(raw) > 0.001 ? simd_normalize(raw) : .init(0, 1, 0)
    }

    func applyFlatnessRecovery() {
        let measurement = topFaceMeasurement
        let targetNormal = Self.faceNormals.first { $0.value == measurement.value }?.normal ?? SIMD3<Float>(0, 1, 0)
        let worldNormal = entity.transform.rotation.act(targetNormal)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let tiltAxis = simd_cross(worldNormal, worldUp)
        let tiltLength = simd_length(tiltAxis)

        let upwardBias: Float = 0.006
        let lateralBias: Float = 0.003

        entity.addForce(.init(0, upwardBias, 0), relativeTo: nil)

        guard tiltLength > 0.0001 else { return }

        let normalizedTiltAxis = tiltAxis / tiltLength
        let correctiveTorque = normalizedTiltAxis * 0.02
        let inwardDirection = safeNormalizedDirection(
            SIMD3<Float>(-entity.position.x, 0, -entity.position.z),
            fallback: SIMD3<Float>(0, 0, 1)
        )
        let inwardForce = inwardDirection * lateralBias

        applyVelocityKick(linear: SIMD3<Float>(0, upwardBias, 0) + inwardForce, angular: correctiveTorque)
    }

    func applyStackedRescue(separationDirection: SIMD3<Float>) {
        let upwardBias: Float = 0.000
        let lateralBias: Float = 0.010
        let fallback = SIMD3<Float>(entity.position.x, 0, entity.position.z)
        let safeDirection = safeNormalizedDirection(separationDirection, fallback: fallback)
        let linearKick = SIMD3<Float>(0, upwardBias, 0) + safeDirection * lateralBias
        let angularKick = SIMD3<Float>(safeDirection.z, 0, -safeDirection.x) * 0.015
        applyVelocityKick(linear: linearKick, angular: angularKick)
    }

    /// Returns the axis the die should rotate about to reach its nearest flat-face orientation.
    /// Called once per stuck episode — the caller stores the result and reuses it every frame
    /// so the direction stays fixed and doesn't oscillate as the die rocks.
    /// Returns nil if the die is already aligned. On a near-perfect balance tie, picks a random axis.
    func flatteningAxis(using rng: inout DiceRandSource) -> SIMD3<Float>? {
        let measurement = topFaceMeasurement
        guard let targetNormal = Self.faceNormals.first(where: { $0.value == measurement.value })?.normal else { return nil }
        let worldNormal = entity.transform.rotation.act(targetNormal)
        let tiltAxis = simd_cross(worldNormal, SIMD3<Float>(0, 1, 0))
        let tiltLength = simd_length(tiltAxis)

        if tiltLength < 0.05 {
            let angle = Float.random(in: 0 ..< (.pi * 2), using: &rng)
            return SIMD3<Float>(cos(angle), 0, sin(angle))
        }
        return tiltAxis / tiltLength
    }

    /// Applies a single angular impulse along a pre-computed axis toward flat.
    func applyFlatteningNudge(axis: SIMD3<Float>, magnitude: Float) {
        var motion = entity.physicsMotion ?? PhysicsMotionComponent()
        motion.angularVelocity += axis * magnitude
        entity.components.set(motion)
    }

    /// World-space normal of the face that is currently pointing most upward.
    /// Recomputed each call so it tracks the die as it tilts — use for per-frame force direction.
    func topFaceWorldNormal() -> SIMD3<Float>? {
        let measurement = topFaceMeasurement
        guard let targetNormal = Self.faceNormals.first(where: { $0.value == measurement.value })?.normal else { return nil }
        return entity.transform.rotation.act(targetNormal)
    }

    func applyFloorEdgeRescue(centerDirection: SIMD3<Float>, gentle: Bool) {
        let safeDirection = safeNormalizedDirection(centerDirection, fallback: SIMD3<Float>(0, 0, 1))
        let verticalKick: Float = gentle ? -0.100 : 0.500
        let lateralKick: Float = gentle ? 0.0000 : 0.000
        let rollKick: Float = gentle ? 0.0000 : 0.000
        let linearKick = SIMD3<Float>(0, verticalKick, 0) + safeDirection * lateralKick
        let angularKick = SIMD3<Float>(safeDirection.z, 0, -safeDirection.x) * rollKick
        if gentle {
            var motion = entity.physicsMotion ?? PhysicsMotionComponent()
            motion.linearVelocity += linearKick
            motion.angularVelocity += angularKick
            entity.components.set(motion)
            entity.addForce(linearKick, relativeTo: nil)
            entity.addTorque(angularKick, relativeTo: nil)
        } else {
            applyVelocityKick(linear: linearKick, angular: angularKick)
        }
    }

    private func safeNormalizedDirection(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        if simd_length_squared(vector) > 0.0001 {
            return simd_normalize(vector)
        }
        if simd_length_squared(fallback) > 0.0001 {
            return simd_normalize(fallback)
        }
        return SIMD3<Float>(1, 0, 0)
    }

    private func applyVelocityKick(linear: SIMD3<Float>, angular: SIMD3<Float>) {
        var motion = entity.physicsMotion ?? PhysicsMotionComponent()
        motion.linearVelocity += linear
        motion.angularVelocity += angular
        entity.components.set(motion)

        entity.addForce(linear, relativeTo: nil)
        entity.addTorque(angular, relativeTo: nil)
    }

    private func applyPhysicsMode() {
        if var body = entity.components[PhysicsBodyComponent.self] {
            body.mode = (isHeld || isPinnedForPresentation) ? .kinematic : .dynamic
            entity.components.set(body)
        }
        rebuildAppearance()
    }

    private func rebuildAppearance() {
        visualEntity.model?.materials = [makeMaterial(held: isHeld, stuck: isStuck, nudgeable: isNudgeable)]
        let currentPipTint = isHeld ? palette.heldPip : pipTint
        for child in visualEntity.children {
            guard let modelEntity = child as? ModelEntity else { continue }
            modelEntity.model?.materials = [UnlitMaterial(color: currentPipTint)]
        }
    }

}
