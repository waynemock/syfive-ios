import SwiftUI
import Observation
import RealityKit

struct DiceAreaView: View {
    @Bindable var model: GameModel
    @State private var diceRoller = DiceRoller()
    @State private var traySize: CGSize = .zero
    @State private var suppressNextPlayerChangeDiceClear = false
    @Environment(\.colorScheme) private var colorScheme
    private let rollControlHeight: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            header
            trayView
            rollControls
            #if DEBUG
            if AppConfig.DebugDice.showPhysicsSliders {
                physicsDebugPanel
            }
            if AppConfig.DebugDice.showHarness {
                DiceDebugHUD(diceRoller: diceRoller)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: model.currentPlayerIndex) { _, _ in
            if suppressNextPlayerChangeDiceClear {
                suppressNextPlayerChangeDiceClear = false
                return
            }
            guard model.playerCount > 1 else { return }
            diceRoller.clearDice()
        }
    }

    // MARK: - Subviews

    private var winnerScore: String {
        if let winner = model.winnerScore {
            return " \(winner)"
        } else {
            return ""
        }
    }

    private var winnerLabel: String {
        let names = model.winnerNames
        if names.count == 1 {
            return "Winner: \(names.first!)\(winnerScore)"
        }
        return "Winners: \(names.joined(separator: ", ")) tied!\(winnerScore)"
    }

    private var header: some View {
        VStack(spacing: 6) {
            if model.isGameOver {
                Text("Winner: \(model.winnerNames.joined(separator: ", "))\(winnerScore)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("New Game") {
                    model.resetGame()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 3D RealityKit tray — square, fills available width dynamically.
    private var trayView: some View {
        Color.clear
            .overlay {
                DiceRKView(diceRoller: diceRoller)
                    .gesture(
                        SpatialTapGesture()
                            .targetedToAnyEntity()
                            .onEnded { value in
                                handleDiceTap(value.entity)
                            }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var rollControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    model.beginRoll()
                    Task {
                        await diceRoller.roll(held: model.held) { values in
                            model.receiveDiceResults(values)
                        }
                    }
                } label: {
                    Text(rollButtonTitle)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: rollControlHeight)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRoll)

                if model.canUndoLastScore {
                    Button {
                        suppressNextPlayerChangeDiceClear = true
                        if let restoration = model.undoLastScore() {
                            diceRoller.restoreDice(values: restoration.diceValues, held: restoration.held)
                        } else {
                            suppressNextPlayerChangeDiceClear = false
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: rollControlHeight)
                            .frame(minHeight: rollControlHeight)
                    }
                    .buttonStyle(.bordered)
                    .tint(undoButtonTint)
                    .accessibilityLabel("Undo last score")
                }
            }

            VStack(spacing: 4) {
                if model.canScore {
                    Text("Choose a category to score")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !model.isGameOver && model.rollsRemaining == 0 {
                    Text("No rolls remaining — choose a category")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("M") // keep space for this row of text
                        .font(.footnote)
                        .foregroundColor(.clear)
                }

                if let label = leadingPlayerLabel, !model.isGameOver {
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if model.playerCount > 1 {
                    Text("M") // keep space for this row of text
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.clear)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleDiceTap(_ entity: Entity) {
        guard model.canScore else { return }
        guard let diceIndex = diceRoller.index(of: entity) else { return }
        model.toggleHold(at: diceIndex)
        diceRoller.setHeld(model.held)
    }

    // MARK: - Helpers

    private var canRoll: Bool {
        model.rollsRemaining > 0 && !model.isGameOver && !model.isRolling
    }

    private var rollButtonTitle: String {
        if !model.hasStarted {
            return model.playerCount == 1
                ? "Start game with 1 player"
                : "Start game with \(model.playerCount) players"
        }
        if model.isRolling { return "Rolling…" }
        if model.rollsRemaining == 3 { return "Start Turn" }
        return model.rollsRemaining > 0 ? "Roll (\(model.rollsRemaining) left)" : "No rolls remaining"
    }

    private var undoButtonTint: Color {
        guard let undoThemeType = model.undoThemeType else { return .accentColor }
        return Theme(type: undoThemeType, colorScheme: colorScheme).primaryAccent
    }

    // MARK: - Debug

    #if DEBUG
    /// Physics tuning sliders — only visible when `AppConfig.DebugDice.showPhysicsSliders == true`.
    private var physicsDebugPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Physics Tuning")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                debugSlider(
                    label: "Impulse max \(String(format: "%.2f", diceRoller.config.impulseMax))",
                    value: Binding(
                        get: { diceRoller.config.impulseMax },
                        set: { diceRoller.config.impulseMax = $0 }
                    ),
                    in: 0.03...0.25
                )
                debugSlider(
                    label: "Torque max \(String(format: "%.2f", diceRoller.config.torqueMax))",
                    value: Binding(
                        get: { diceRoller.config.torqueMax },
                        set: { diceRoller.config.torqueMax = $0 }
                    ),
                    in: 0.02...0.35
                )
                debugSlider(
                    label: "Cone angle \(String(format: "%.0f°", diceRoller.config.coneHalfAngle * 180 / .pi))",
                    value: Binding(
                        get: { diceRoller.config.coneHalfAngle },
                        set: { diceRoller.config.coneHalfAngle = $0 }
                    ),
                    in: 0.1...1.2
                )
                debugSlider(
                    label: "Spawn jitter \(String(format: "%.3f", diceRoller.config.spawnJitter))",
                    value: Binding(
                        get: { diceRoller.config.spawnJitter },
                        set: { diceRoller.config.spawnJitter = $0 }
                    ),
                    in: 0...0.04
                )
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func debugSlider(label: String, value: Binding<Float>, in range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Slider(value: value, in: range)
        }
    }
    #endif

    private var leadingPlayerLabel: String? {
        guard model.playerCount > 1 else { return nil }
        let totals = (0..<model.playerCount).map { model.totalScore(for: $0) }
        let maxScore = totals.max() ?? 0
        guard maxScore > 0 else { return nil }
        let leaders = totals.enumerated().compactMap { index, score in
            score == maxScore ? index : nil
        }
        if leaders.count > 1 {
            let names = leaders.map { "P\($0 + 1)" }.joined(separator: ", ")
            return "Tied: \(names) (\(maxScore))"
        }
        if let index = leaders.first {
            return "Leading: P\(index + 1) (\(maxScore))"
        }
        return nil
    }
}

#Preview {
    DiceAreaView(model: GameModel())
}
