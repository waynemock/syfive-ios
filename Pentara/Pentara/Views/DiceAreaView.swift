import SwiftUI
import Observation

struct DiceAreaView: View {
    @Bindable var model: GameModel

    var body: some View {
        VStack(spacing: 20) {
            header
            Spacer(minLength: 0)
            diceRow
            rollControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Score")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.totalScore(for: model.currentPlayerIndex), format: .number)
                .font(.system(size: 44, weight: .semibold, design: .serif))
            if model.isGameOver {
                Text("Winner: \(model.winnerNames.joined(separator: ", "))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button("New Game") {
                    model.resetGame()
                }
                .buttonStyle(.bordered)
            } else {
                Text("Turn: \(model.currentPlayerName)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var diceRow: some View {
        let isDiceInteractive = model.rollsRemaining < 3 && !model.isGameOver
        return Group {
            if model.hasStarted {
                HStack(spacing: 12) {
                    ForEach(model.diceValues.indices, id: \.self) { index in
                        DicePill(
                            value: model.diceValues[index],
                            isHeld: model.held[index],
                            isEnabled: isDiceInteractive
                        ) {
                            model.toggleHold(at: index)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(isDiceInteractive ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.2), value: isDiceInteractive)
            }
        }
    }

    private var rollControls: some View {
        VStack(spacing: 8) {
            Button {
                model.roll()
            } label: {
                Text(rollButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.rollsRemaining == 0 || model.isGameOver)

            VStack(spacing: 4) {
                if model.hasStarted {
                    if model.canScore {
                        Text("Choose a category to score")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var rollButtonTitle: String {
        if !model.hasStarted {
            return "Start Game"
        }
        return model.rollsRemaining > 0 ? "Roll (\(model.rollsRemaining) left)" : "Roll"
    }
}

#Preview {
    DiceAreaView(model: GameModel())
}
