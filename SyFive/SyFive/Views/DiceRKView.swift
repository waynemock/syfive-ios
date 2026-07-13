import SwiftUI
import RealityKit
import UIKit

extension Theme {
    /// Converts App-layer Theme into the palette `Dice/` accepts (D-013).
    var dicePalette: DiceTintPalette {
        DiceTintPalette(
            normal: UIColor(primaryAccent),
            held: UIColor(heldAccent),
            nudgeable: UIColor(stuckColor),
            stuck: UIColor(errorColor),
            pip: UIColor(pipColor)
        )
    }
}

/// SwiftUI wrapper around the RealityKit dice scene.
/// Uses `.virtual` camera mode — no AR session, no camera permission needed.
struct DiceRKView: View {

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let diceRoller: DiceRoller
    /// Current rendered size of this view — used to compute the camera FOV.
    var viewSize: CGSize = .zero

    // Persisted camera entity so the update closure can adjust FOV.
    @State private var cameraEntity = Entity()

    var body: some View {
        #if DEBUG
        // RealityView crashes Xcode's preview agent when rendering static variant snapshots.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] != nil {
            previewPlaceholder
        } else {
            realityContent
        }
        #else
        realityContent
        #endif
    }

    @ViewBuilder private var realityContent: some View {
        RealityView { content in
            // Non-AR virtual camera mode
            content.camera = .virtual
            // .default lets the SwiftUI .background modifier control the scene background
            content.environment = .default

            addCamera(to: &content)
            addLights(to: &content)
            addTray(to: &content)
            diceRoller.setup(in: &content, palette: theme.dicePalette)
        } update: { _ in
            updateCameraFOV()
            diceRoller.applyPalette(theme.dicePalette)
        }
        .background(theme.backgroundColor)
        .onAppear {
            diceRoller.applyPalette(theme.dicePalette)
        }
        .onChange(of: colorScheme) { _, _ in
            diceRoller.applyPalette(theme.dicePalette)
        }
        .onChange(of: theme.type) { _, _ in
            diceRoller.applyPalette(theme.dicePalette)
        }
    }

    #if DEBUG
    private var previewPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.backgroundColor)
            .overlay(
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(theme.primaryAccent.opacity(0.35))
            )
    }
    #endif

    // MARK: - Scene setup

    private func addCamera(to content: inout RealityViewCameraContent) {
        var comp = PerspectiveCameraComponent()
        comp.near = 0.001
        comp.far  = 10
        comp.fieldOfViewInDegrees = trayFOV
        cameraEntity.components.set(comp)
        // Overhead view angled slightly forward, framing the full tray floor.
        cameraEntity.look(at: [0, 0.01, 0], from: [0, 0.34, 0.16], relativeTo: nil)
        content.add(cameraEntity)
    }

    private func updateCameraFOV() {
        guard var comp = cameraEntity.components[PerspectiveCameraComponent.self] else { return }
        comp.fieldOfViewInDegrees = trayFOV
        cameraEntity.components.set(comp)
    }

    /// Vertical FOV (degrees) that frames the tray to fill ~90 % of the shorter
    /// viewport dimension. Accounts for non-square aspect ratios automatically.
    ///
    /// Strategy: project all four tray floor corners into camera space, find the
    /// largest required vertical half-FOV tan that keeps every corner in frame,
    /// then back out the full-angle FOV with a fill factor applied.
    private var trayFOV: Float {
        let camPos: SIMD3<Float>  = [0, 0.34, 0.16]
        let lookAt: SIMD3<Float>  = [0, 0.01,  0.00]
        let half = DiceTrayEntity.halfSize

        let fwd   = normalize(lookAt - camPos)
        let right = normalize(cross(fwd, SIMD3<Float>(0, 1, 0)))
        let up    = cross(right, fwd)

        let aspect: Float = (viewSize.width > 0 && viewSize.height > 0)
            ? Float(viewSize.width / viewSize.height) : 1

        let corners: [SIMD3<Float>] = [
            [-half, 0, -half], [ half, 0, -half],
            [-half, 0,  half], [ half, 0,  half],
        ]

        var maxHalfTan: Float = 0
        for c in corners {
            let v = c - camPos
            let d = dot(v, fwd)
            guard d > 0 else { continue }
            // Required vertical half-FOV tan: the larger of the vertical
            // projection and the horizontal projection normalised by aspect.
            let req = max(abs(dot(v, up))    / d,
                         abs(dot(v, right)) / (d * aspect))
            maxHalfTan = max(maxHalfTan, req)
        }

        guard maxHalfTan > 0 else { return 62 }

        // fillFactor < 1 leaves a small margin around the tray edges.
        let fillFactor: Float = 0.88
        return 2 * atan(maxHalfTan / fillFactor) * (180 / .pi)
    }

    private func addLights(to content: inout RealityViewCameraContent) {
        // Key light — warm white, upper right, casts shadow
        let key = DirectionalLight()
        key.light.intensity = 2200
        key.light.color = .white
        key.shadow = DirectionalLightComponent.Shadow()
        key.look(at: .zero, from: [0.5, 1.2, 0.8], relativeTo: nil)
        content.add(key)

        // Fill light — cool blue, opposite side
        let fill = DirectionalLight()
        fill.light.intensity = 700
        fill.light.color = UIColor(red: 0.80, green: 0.85, blue: 1.00, alpha: 1)
        fill.look(at: .zero, from: [-0.7, 0.5, -0.3], relativeTo: nil)
        content.add(fill)

        // Rim light — purple tint, from behind
        let rim = DirectionalLight()
        rim.light.intensity = 500
        rim.light.color = UIColor(red: 0.65, green: 0.60, blue: 0.95, alpha: 1)
        rim.look(at: .zero, from: [-0.2, 0.3, -0.9], relativeTo: nil)
        content.add(rim)
    }

    private func addTray(to content: inout RealityViewCameraContent) {
        let tray = DiceTrayEntity()
        content.add(tray)
    }
}

#Preview {
    DiceRKView(diceRoller: DiceRoller())
        .aspectRatio(1, contentMode: .fit)
}
