import SwiftUI
import Observation

struct DiceAreaView: View {
    @Bindable var model: GameModel

    var body: some View {
        VStack(spacing: 20) {
            header
            Spacer(minLength: 0)
            diceRow
            Spacer(minLength: 0)
            rollControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(spacing: 6) {
            if model.isGameOver {
                Text("Winner: \(model.winnerNames.joined(separator: ", "))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button("New Game") {
                    model.resetGame()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var diceRow: some View {
        let isDiceInteractive = model.rollsRemaining < 3 && !model.isGameOver
        return Group {
            if model.hasStarted && model.rollsRemaining < 3 {
                diceGrid(isDiceInteractive: isDiceInteractive)
            }
        }
    }

    private func diceGrid(isDiceInteractive: Bool) -> some View {
        let spacing: CGFloat = 12
        return VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                dicePill(at: 0, isDiceInteractive: isDiceInteractive)
                Spacer(minLength: 0)
                dicePill(at: 1, isDiceInteractive: isDiceInteractive)
            }
            HStack(spacing: spacing) {
                Spacer(minLength: 0)
                dicePill(at: 2, isDiceInteractive: isDiceInteractive)
                Spacer(minLength: 0)
            }
            HStack(spacing: spacing) {
                dicePill(at: 3, isDiceInteractive: isDiceInteractive)
                Spacer(minLength: 0)
                dicePill(at: 4, isDiceInteractive: isDiceInteractive)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .opacity(isDiceInteractive ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isDiceInteractive)
    }

    private func dicePill(at index: Int, isDiceInteractive: Bool) -> some View {
        DicePill(
            value: model.diceValues[index],
            isHeld: model.held[index],
            isEnabled: isDiceInteractive
        ) {
            model.toggleHold(at: index)
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
                    if model.rollsRemaining == 3, let label = leadingPlayerLabel {
                        Text(label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
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
            if model.playerCount == 1 {
                return "Start game with 1 player"
            }
            return "Start game with \(model.playerCount) players"
        }
        if model.rollsRemaining == 3 {
            return "Start Turn"
        }
        return model.rollsRemaining > 0 ? "Roll (\(model.rollsRemaining) left)" : "Roll"
    }

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
