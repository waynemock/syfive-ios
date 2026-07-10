import Foundation
import Observation

// Drives visual celebrations — Yatzy rising motes and game-over slow-fall.
// Injected via .environment(_:) in ContentView; triggered by DiceAreaView (Yatzy)
// and ContentView (game-over); consumed by CelebrationView.
@MainActor @Observable
final class CelebrationCoordinator {
    struct YatzyEvent: Identifiable {
        let id = UUID()
        let playerIndex: Int
    }

    // Replaced (not stacked) on rapid-fire Yatzy succession — §2.4.
    var yatzyEvent: YatzyEvent? = nil
    var isGameOverActive = false
    var winnerIndices: [Int] = []

    func triggerYatzy(playerIndex: Int) {
        yatzyEvent = YatzyEvent(playerIndex: playerIndex)
    }

    func triggerGameOver(winnerIndices: [Int]) {
        guard !isGameOverActive else { return }
        self.winnerIndices = winnerIndices
        isGameOverActive = true
    }

    func clearYatzy() { yatzyEvent = nil }

    func clearGameOver() {
        isGameOverActive = false
        winnerIndices = []
    }
}
