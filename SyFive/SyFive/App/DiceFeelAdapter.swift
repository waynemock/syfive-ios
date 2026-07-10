import Foundation

// App-layer adapter: conforms DiceAudioControlling → forwards to FeelDirector.
// Retained by DiceAreaView alongside diceRoller; see Stage 3 wiring in DiceAreaView.
// No Feel↔Dice dependency in either direction (D-053).
@MainActor final class DiceFeelAdapter: DiceAudioControlling {
    private unowned let director: FeelDirector

    init(director: FeelDirector) {
        self.director = director
    }

    func onDieSettled(index: Int, value: Int) {
        director.dieSettled(index: index)
    }

    func onAllDiceSettled(values: [Int]) {
        director.allDiceSettled(values: values)
    }

    // onDieLaunched / onDieHitFloor / onDieHitWall: reserved hooks — no-ops (§8.3)
}
