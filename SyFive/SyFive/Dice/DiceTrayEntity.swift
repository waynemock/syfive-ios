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
    static let collisionWallHeight: Float = 1
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
            friction: (static: 0.50, dynamic: 0.40),
            restitution: 0.15
        )
        addChild(wall)
    }

    private func addInvisibleCollider(size: SIMD3<Float>, position: SIMD3<Float>) {
        let collider = Entity()
        collider.position = position
        let shape = ShapeResource.generateBox(size: size)
        let physMat = PhysicsMaterialResource.generate(
            staticFriction: 0.50,
            dynamicFriction: 0.40,
            restitution: 0.15
        )
        collider.components.set(CollisionComponent(shapes: [shape]))
        collider.components.set(PhysicsBodyComponent(shapes: [shape], mass: 1, material: physMat, mode: .static))
        addChild(collider)
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
