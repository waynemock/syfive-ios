import SwiftUI
import RealityKit
import UIKit

/// SwiftUI wrapper around the RealityKit dice scene.
/// Uses `.virtual` camera mode — no AR session, no camera permission needed.
struct DiceRKView: View {

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let diceRoller: DiceRoller

    var body: some View {
        RealityView { content in
            // Non-AR virtual camera mode
            content.camera = .virtual
            // .default lets the SwiftUI .background modifier control the scene background
            content.environment = .default

            addCamera(to: &content)
            addLights(to: &content)
            addTray(to: &content)
            diceRoller.setup(in: &content, theme: theme)
        } update: { _ in
            diceRoller.applyTheme(theme)
        }
        .background(theme.backgroundColor)
        .onAppear {
            diceRoller.applyTheme(theme)
        }
        .onChange(of: colorScheme) { _, _ in
            diceRoller.applyTheme(theme)
        }
        .onChange(of: theme.type) { _, _ in
            diceRoller.applyTheme(theme)
        }
    }

    // MARK: - Scene setup

    private func addCamera(to content: inout RealityViewCameraContent) {
        let camera = Entity()
        var camComponent = PerspectiveCameraComponent()
        camComponent.near = 0.001
        camComponent.far = 10
        camComponent.fieldOfViewInDegrees = 62
        camera.components.set(camComponent)
        // Overhead view angled slightly forward, framing the full tray floor
        camera.look(at: [0, 0.01, 0], from: [0, 0.34, 0.16], relativeTo: nil)
        content.add(camera)
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
