import Foundation

// App-layer adapter: conforms DiceAudioControlling → forwards to FeelDirector.
// Retained by DiceAreaView alongside diceRoller; see Stage 3 wiring in DiceAreaView.
// No Feel↔Dice dependency in either direction (D-053).
@MainActor final class DiceFeelAdapter: DiceAudioControlling {
    private unowned let director: FeelDirector

    // Set true while a spectator replay is running (11 §2).
    // Audio events are forwarded; haptics are suppressed.
    var isTheaterMode: Bool = false

    // Mirror of the user's "Theater sound on this device" UserDefaults flag (11 §4).
    // When false in theater mode, all audio and haptic forwarding is skipped.
    var theaterAudioEnabled: Bool = false

    init(director: FeelDirector) {
        self.director = director
    }

    func onDieSettled(index: Int, value: Int) {
        if isTheaterMode {
            guard theaterAudioEnabled else { return }
            withHapticsDisabled { director.dieSettled(index: index) }
        } else {
            director.dieSettled(index: index)
        }
    }

    func onAllDiceSettled(values: [Int]) {
        if isTheaterMode {
            guard theaterAudioEnabled else { return }
            withHapticsDisabled { director.allDiceSettled(values: values) }
        } else {
            director.allDiceSettled(values: values)
        }
    }

    // Save/restore is safe: all dice hooks arrive on MainActor synchronously.
    private func withHapticsDisabled(_ body: () -> Void) {
        let saved = director.hapticsEnabled
        director.hapticsEnabled = false
        body()
        director.hapticsEnabled = saved
    }

    // onDieLaunched / onDieHitFloor / onDieHitWall: reserved hooks — no-ops (§8.3)
}
