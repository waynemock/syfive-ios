import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    diceRow
                    rollControls
                    scorecard
                }
                .padding(24)
            }
            .navigationTitle("Pentara")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Game") {
                        model.resetGame()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Score")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.totalScore, format: .number)
                .font(.system(size: 44, weight: .semibold, design: .serif))
            if model.isGameOver {
                Text("Game Over")
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
        return HStack(spacing: 12) {
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

    private var rollControls: some View {
        VStack(spacing: 8) {
            Button {
                model.roll()
            } label: {
                Text(model.rollsRemaining > 0 ? "Roll (\(model.rollsRemaining) left)" : "Roll")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.rollsRemaining == 0 || model.isGameOver)

            VStack(spacing: 4) {
                Text("Rolls remaining: \(model.rollsRemaining)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if model.canScore {
                    Text("Choose a category to score")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var scorecard: some View {
        VStack(spacing: 16) {
            scoreSection(title: "Upper", categories: GameModel.ScoreCategory.allCases.filter { $0.isUpperSection })
            scoreSection(title: "Lower", categories: GameModel.ScoreCategory.allCases.filter { !$0.isUpperSection })
        }
    }

    private func scoreSection(title: String, categories: [GameModel.ScoreCategory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ForEach(categories) { category in
                let assignedScore = model.scores[category]
                ScoreRow(
                    title: category.displayName,
                    value: assignedScore,
                    suggested: model.suggestedScores()[category] ?? 0,
                    isAvailable: assignedScore == nil,
                    canScore: model.canScore
                ) {
                    model.score(category: category)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}





#Preview {
    ContentView()
}
