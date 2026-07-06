import RealityKit
import UIKit

/// A container entity that forms the physical dice tray: a floor and four walls.
/// All children are static physics bodies so dice can bounce and stay contained.
@MainActor
final class DiceTrayEntity: Entity {

    // MARK: - Dimensions (meters)

    /// Half the interior tray width / depth.
    static let halfSize: Float = 0.14           // 0.28 m interior
    /// Height of the visible rendered walls.
    static let visibleWallHeight: Float = 0.06
    /// Height of the invisible collision walls (and lid height) — keeps dice fully contained.
    static let collisionWallHeight: Float = visibleWallHeight * 4
    static let wallThickness: Float = 0.010
    static let floorThickness: Float = 0.006

    // MARK: - Init

    required init() {
        super.init()
        buildTray()
    }

    // MARK: - Private build

    private func buildTray() {
        addFloor()
        addVisibleWalls()
        addInvisibleWalls()
        addWallChamfers()
        addCornerChamfers()
        addLid()
    }

    private func addFloor() {
        let half = Self.halfSize
        let t = Self.floorThickness
        let extra = Self.wallThickness / 2
        let size = SIMD3<Float>(half * 2 + extra, t, half * 2 + extra)

        let mesh = MeshResource.generateBox(size: size, cornerRadius: 0.002)
        var mat = SimpleMaterial()
        mat.color = .init(tint: UIColor(red: 0.13, green: 0.11, blue: 0.17, alpha: 1))
        mat.roughness = .float(0.85)
        mat.metallic = .float(0.05)

        let floor = ModelEntity(mesh: mesh, materials: [mat])
        floor.position = [0, -t / 2, 0]
        attachStaticPhysics(
            to: floor,
            size: size,
            friction: (static: 0.60, dynamic: 0.50),
            restitution: 0.20
        )
        addChild(floor)
    }

    /// Short visible walls that give the tray its look.
    private func addVisibleWalls() {
        let half = Self.halfSize
        let h = Self.visibleWallHeight
        let t = Self.wallThickness
        let interior = half * 2

        var mat = SimpleMaterial()
        mat.color = .init(tint: UIColor(red: 0.10, green: 0.08, blue: 0.13, alpha: 1))
        mat.roughness = .float(0.80)
        mat.metallic = .float(0.05)

        // Front / back walls
        let fbSize = SIMD3<Float>(interior + t * 2, h, t)
        let fbMesh = MeshResource.generateBox(size: fbSize, cornerRadius: 0.001)
        for z in [half + t / 2, -(half + t / 2)] {
            addVisibleWall(mesh: fbMesh, size: fbSize, position: [0, h / 2, z], material: mat)
        }

        // Left / right walls
        let lrSize = SIMD3<Float>(t, h, interior)
        let lrMesh = MeshResource.generateBox(size: lrSize, cornerRadius: 0.001)
        for x in [half + t / 2, -(half + t / 2)] {
            addVisibleWall(mesh: lrMesh, size: lrSize, position: [x, h / 2, 0], material: mat)
        }
    }

    /// Tall invisible collision walls that fully contain bouncing dice.
    private func addInvisibleWalls() {
        let half = Self.halfSize
        let h = Self.collisionWallHeight
        let t = Self.wallThickness
        let interior = half * 2

        // Front / back
        let fbSize = SIMD3<Float>(interior + t * 2, h, t)
        for z in [half + t / 2, -(half + t / 2)] {
            addInvisibleCollider(size: fbSize, position: [0, h / 2, z])
        }

        // Left / right
        let lrSize = SIMD3<Float>(t, h, interior)
        for x in [half + t / 2, -(half + t / 2)] {
            addInvisibleCollider(size: lrSize, position: [x, h / 2, 0])
        }
    }

    /// Invisible ceiling that stops dice from flying upward out of the tray.
    private func addLid() {
        let half = Self.halfSize
        let t = Self.wallThickness
        let lidY = Self.collisionWallHeight
        let size = SIMD3<Float>(half * 2 + t * 2, t, half * 2 + t * 2)
        addInvisibleCollider(size: size, position: [0, lidY + t / 2, 0])
    }

    private func addVisibleWall(
        mesh: MeshResource,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) {
        let wall = ModelEntity(mesh: mesh, materials: [material])
        wall.position = position
        attachStaticPhysics(
            to: wall,
            size: size,
            friction: (static: 0.0, dynamic: 0.0),
            restitution: 0.40
        )
        addChild(wall)
    }

    private func addInvisibleCollider(
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    ) {
        let collider = Entity()
        collider.position = position
        collider.orientation = rotation
        let shape = ShapeResource.generateBox(size: size)
        let physMat = PhysicsMaterialResource.generate(
            staticFriction: 0.0,
            dynamicFriction: 0.0,
            restitution: 0.40
        )
        collider.components.set(CollisionComponent(shapes: [shape]))
        collider.components.set(PhysicsBodyComponent(shapes: [shape], mass: 1, material: physMat, mode: .static))
        addChild(collider)
    }

    /// Invisible 45° ramps along the base of all four walls so a die resting
    /// against a flat wall face gets deflected inward and upward.
    private func addWallChamfers() {
        let half = Self.halfSize
        let interior = half * 2
        let s: Float = 0.030

        // Front / back walls (run along X)
        for (z, angle) in [(half, Float.pi / 4), (-half, -Float.pi / 4)] as [(Float, Float)] {
            addInvisibleCollider(
                size: SIMD3<Float>(interior, s, s),
                position: SIMD3<Float>(0, s / 2, z),
                rotation: simd_quatf(angle: angle, axis: [1, 0, 0])
            )
        }

        // Left / right walls (run along Z)
        for (x, angle) in [(half, -Float.pi / 4), (-half, Float.pi / 4)] as [(Float, Float)] {
            addInvisibleCollider(
                size: SIMD3<Float>(s, s, interior),
                position: SIMD3<Float>(x, s / 2, 0),
                rotation: simd_quatf(angle: angle, axis: [0, 0, 1])
            )
        }
    }

    /// Invisible 45° wedges in all four corners to deflect dice toward the centre
    /// instead of letting them lodge in the 90° corner gap.
    private func addCornerChamfers() {
        let half = Self.halfSize
        let h = Self.collisionWallHeight
        let chamferSize = SIMD3<Float>(0.030, h, 0.030)
        let rot45 = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])

        for (cx, cz) in [(half, half), (-half, half), (half, -half), (-half, -half)] as [(Float, Float)] {
            addInvisibleCollider(size: chamferSize, position: [cx, h / 2, cz], rotation: rot45)
        }
    }

    private func attachStaticPhysics(
        to entity: ModelEntity,
        size: SIMD3<Float>,
        friction: (static: Float, dynamic: Float),
        restitution: Float
    ) {
        let shape = ShapeResource.generateBox(size: size)
        let physMat = PhysicsMaterialResource.generate(
            staticFriction: friction.static,
            dynamicFriction: friction.dynamic,
            restitution: restitution
        )
        entity.components.set(CollisionComponent(shapes: [shape]))
        entity.components.set(
            PhysicsBodyComponent(shapes: [shape], mass: 1, material: physMat, mode: .static)
        )
    }
}
