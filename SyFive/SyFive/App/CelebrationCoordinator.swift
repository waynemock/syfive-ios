import Foundation
import Observation
import SyLibCore
import SyLibYatzy

// Drives visual celebrations — Yatzy rising motes and game-over slow-fall.
// Injected via .environment(_:) in ContentView; triggered by DiceAreaView (Yatzy)
// and ContentView (game-over); consumed by CelebrationView.
@MainActor @Observable
final class CelebrationCoordinator {
    private let logger = AppLogger(category: "ScoreAnnouncement")
    struct YatzyEvent: Identifiable {
        let id = UUID()
        let playerIndex: Int
    }

    struct ScoreAnnouncement: Identifiable {
        let id = UUID()
        let playerIndex: Int
        let category: YatzyCategory
        let value: Int
    }

    struct WinnerAnnouncement: Identifiable {
        let id = UUID()
        let winnerIndices: [Int]
        let score: Int
    }

    struct UpperBonusEvent: Identifiable {
        let id = UUID()
        let playerIndex: Int
    }

    // Replaced (not stacked) on rapid-fire Yatzy succession — §2.4.
    var yatzyEvent: YatzyEvent? = nil
    var upperBonusEvent: UpperBonusEvent? = nil
    var isGameOverActive = false
    var winnerIndices: [Int] = []
    // Replaced on successive scores — only the latest score banner shows.
    var scoreAnnouncement: ScoreAnnouncement? = nil
    // Persists until a new game starts — not cleared by clearAll().
    var winnerAnnouncement: WinnerAnnouncement? = nil

    func triggerYatzy(playerIndex: Int) {
        yatzyEvent = YatzyEvent(playerIndex: playerIndex)
    }

    func triggerGameOver(winnerIndices: [Int]) {
        guard !isGameOverActive else { return }
        self.winnerIndices = winnerIndices
        isGameOverActive = true
    }

    func triggerScoreAnnouncement(playerIndex: Int, category: YatzyCategory, value: Int) {
        let announcement = ScoreAnnouncement(playerIndex: playerIndex, category: category, value: value)
        logger.debug(self, "trigger id=\(announcement.id.uuidString.prefix(8)) playerIndex=\(playerIndex) category=\(category.displayName) value=\(value) replacingExisting=\(scoreAnnouncement != nil)")
        scoreAnnouncement = announcement
    }

    func triggerWinnerAnnouncement(winnerIndices: [Int], score: Int) {
        winnerAnnouncement = WinnerAnnouncement(winnerIndices: winnerIndices, score: score)
    }

    func clearWinnerAnnouncement() { winnerAnnouncement = nil }

    func triggerUpperBonus(playerIndex: Int) {
        upperBonusEvent = UpperBonusEvent(playerIndex: playerIndex)
    }

    func clearYatzy() { yatzyEvent = nil }

    func clearUpperBonus() { upperBonusEvent = nil }

    func clearGameOver() {
        isGameOverActive = false
        winnerIndices = []
    }

    func clearScoreAnnouncement() {
        guard scoreAnnouncement != nil else { return }
        logger.debug(self, "clearScoreAnnouncement")
        scoreAnnouncement = nil
    }

    func clearAll() {
        clearYatzy()
        clearUpperBonus()
        clearScoreAnnouncement()
    }

    func clearScoreAnnouncementIfCurrent(id: UUID) {
        let id8 = id.uuidString.prefix(8)
        guard let current = scoreAnnouncement else {
            logger.debug(self, "clearScoreAnnouncement[\(id8)] skipped — already nil")
            return
        }
        guard current.id == id else {
            logger.debug(self, "clearScoreAnnouncement[\(id8)] skipped — stale (current=\(current.id.uuidString.prefix(8)))")
            return
        }
        logger.debug(self, "clearScoreAnnouncement[\(id8)]")
        scoreAnnouncement = nil
    }
}
