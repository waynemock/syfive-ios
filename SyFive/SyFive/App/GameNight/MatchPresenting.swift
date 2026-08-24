import Foundation

/// Read-only interface shared by MatchController (host authority) and TableReplica
/// (guest-side render model). Views that need to work in both pass-and-play and
/// Game Night will bind either type; mutation paths route by role via GameNightController.
protocol MatchPresenting: AnyObject {
    var playerCount: Int { get }
    var playerNames: [String] { get }
    var playerIDs: [UUID?] { get }
    var slotIDs: [UUID] { get }
    var currentPlayerIndex: Int { get }
    var hasStarted: Bool { get }
    var canEditPlayers: Bool { get }
    var isGameOver: Bool { get }
    var canScore: Bool { get }
    var totalRounds: Int { get }
    var currentRound: Int { get }
    var winnerIndices: [Int] { get }
    var winnerNames: [String] { get }
    var leaderIndices: [Int] { get }
    var leadingPlayerLabel: String? { get }

    func playerInitials(for playerIndex: Int) -> String
    func themeType(for playerIndex: Int) -> Theme.ThemeType
    func scores(for playerIndex: Int) -> [YatzyCategory: Int]
    func totalScore(for playerIndex: Int) -> Int
    func upperSubtotal(for playerIndex: Int) -> Int
    func upperBonus(for playerIndex: Int) -> Int
    func yatzyBonus(for playerIndex: Int) -> Int
    func isWinner(_ playerIndex: Int) -> Bool
    func canScore(category: YatzyCategory, for playerIndex: Int) -> Bool
    func suggestedCategory(for playerIndex: Int) -> YatzyCategory?
    func suggestedScores(for playerIndex: Int) -> [YatzyCategory: Int]
}

extension MatchController: MatchPresenting {}
