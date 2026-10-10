import SwiftUI
import SyLibCore
import SyLibGameNight
import SyLibScoring
import SyLibScoringData
import SwiftData

// MARK: - Game Night UI

extension ContentView {

    /// Where this device stands with Game Night, read from `body` so the menu and the leading
    /// control follow the session (17 §4.8).
    var gameNightEntry: GameNightEntryState { GameNightEntryState(session: gameNight.session) }

    /// Leading nav bar button. SyLib's Game Night control when the state has one (D-140);
    /// otherwise SyFive's Play Again for a host whose match is over, or the standard
    /// new-game / reset button.
    @ViewBuilder
    var leadingNavButton: some View {
        if let control = gameNightEntry.leadingControl {
            GameNightLeadingControlButton(control) {
                switch control {
                case .start:
                    gameNight.beginHosting(
                        onNeedsConversation: { showsInviteInstructions = true },
                        onReadyToSeat: { presentGameNightSheetOrAlert() }
                    )
                case .inviteSent: showsGameNightPendingSheet = true
                case .setup:      showsGameNight = true
                case .end:        gnAlerts.showsCancelSession = true
                case .active:     break   // drawn as a status; never called
                }
            }
        } else if gameNight.isSessionActive && gameNight.role == .host && gameNight.phase == .completed {
            Button {
                startGameNightRematch()
            } label: {
                Image(systemName: "arrow.clockwise.circle")
            }
            .accessibilityLabel("Play Again")
        } else if model.hasGameActivity && !model.isGameOver {
            // Active game — reset button opens the pause/delete alert.
            Button { showsResetAlert = true } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("New Game")
        } else if model.isGameOver {
            // Game finished — one-tap play again with same players.
            Button {
                model.abandonMatch(in: modelContext)
                model.resetGame()
                celebrationCoordinator.clearWinnerAnnouncement()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Play Again")
        }
    }

    /// The Game Night items of the main menu: SyLib's section (D-140), with SyFive's Play Again
    /// in the app slot for a host whose match is over.
    @ViewBuilder
    var gameNightMenuSection: some View {
        GameNightMenuSection(
            state: gameNightEntry,
            onStart: {
                gameNight.beginHosting(
                    onNeedsConversation: { showsInviteInstructions = true },
                    onReadyToSeat: { presentGameNightSheetOrAlert() })
            },
            onCancelInvite: { gnAlerts.showsCancelSession = true },
            onOpenSetup: { showsGameNight = true },
            onEnd: { gnAlerts.showsCancelSession = true },
            onShowHelp: { showsGameNightHelp = true }
        ) {
            if gameNight.isSessionActive && gameNight.role == .host && gameNight.phase == .completed {
                Button { startGameNightRematch() } label: {
                    Label("Play Again", systemImage: "arrow.clockwise.circle")
                }
            }
        }
    }

    var gameNightHelpContext: GameNightHelpSheet.Context {
        if gameNight.isSessionPending || (gameNight.isSessionActive && gameNight.role == .host) {
            return .hosting
        } else if gameNight.isSessionActive && gameNight.role != .host {
            return .joined
        } else {
            return .preSession
        }
    }

    func presentGameNightSheetOrAlert() {
        if model.hasStarted && !model.isGameOver && !model.isGameNight {
            showsGameNightLocalConflictAlert = true
        } else {
            showsGameNight = true
        }
    }

    /// Creates PlayerModel records for any remote participants whose playerID doesn't
    /// exist in local storage yet. Called when a Game Night match goes .inProgress so
    /// every device has a full player roster for stats and future merge UI.
    /// The name-and-initials rule is SyLib's (`upsertGameNightRoster`, D-137): a remote player
    /// with the same name and initials as a local one is remapped onto it, except that a local
    /// player seated at this table never captures one, and one local player captures at most
    /// one incoming player per call.
    func upsertGameNightPlayerModels() {
        guard gameNight.isSessionActive else { return }
        var players: [GameNightRosterPlayer] = []
        for i in 0..<model.playerCount {
            guard let playerID = model.playerIDs[i] else { continue }
            players.append(GameNightRosterPlayer(
                id: playerID,
                name: model.playerDisplayNames[i],
                initials: model.playerDisplayInitials[i],
                themeID: model.playerThemes[i].rawValue))
        }
        let seated = Set(model.playerIDs.compactMap { $0 })
            .union(gameNight.seats.compactMap { $0.playerID })
        do {
            let changes = try upsertGameNightRoster(players, seatedPlayerIDs: seated, in: modelContext)
            if !changes.isEmpty {
                logger.info(self, "roster upsert: inserted \(changes.insertedIDs.count), remapped \(changes.remapped.count)")
            }
        } catch { logger.error(self, "roster upsert failed: \(error)") }
    }

    func startGameNightRematch() {
        let yatzyID = ScoringSystemID.yatzy.rawValue
        let descriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == yatzyID }
        )
        guard let gameID = (try? modelContext.fetch(descriptor))?.first?.id else { return }
        celebrationCoordinator.clearWinnerAnnouncement()
        gameNight.broadcastRematch(gameID: gameID)
    }
}

// MARK: - Game Night Alerts

extension ContentView {
    func fetchHostReconnectIDs() -> (matchID: UUID, gameID: UUID)? {
        var matchDesc = FetchDescriptor<MatchModel>(
            predicate: #Predicate { $0.statusRaw == "inProgress" },
            sortBy: [SortDescriptor(\MatchModel.startedAt, order: .reverse)]
        )
        matchDesc.fetchLimit = 1
        guard let match = (try? modelContext.fetch(matchDesc))?.first,
              match.isGameNight,
              gameNight.gnWasHost(for: match.id) else { return nil }

        let yatzyID = ScoringSystemID.yatzy.rawValue
        let gameDesc = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == yatzyID }
        )
        guard let gameID = (try? modelContext.fetch(gameDesc))?.first?.id else { return nil }
        return (match.id, gameID)
    }
}
