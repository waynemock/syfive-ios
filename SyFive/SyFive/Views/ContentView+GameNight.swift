import SwiftUI
import SyLibUI
import SyLibCore
import SyLibGameNight
import SyLibScoring
import SyLibScoringData
import SwiftData

// MARK: - Game Night UI

extension ContentView {

    /// The remembered Game Night player for auto-seat (37 §2.4): the player with `id`, if one row
    /// of that id isn't archived, as `SyFiveSeatClaimSheet` builds its roster entries. Nil for an
    /// archived or missing player, and nil while a host resume is pending: the host's auto-seat runs
    /// when the session is configured, before a resume replaces the seats (37.1). Internal for tests.
    static func rememberedSeatEntry(for id: UUID, in context: ModelContext, colorScheme: ColorScheme,
                                    hostResumePending: Bool) -> SeatRosterEntry? {
        guard !hostResumePending else { return nil }
        let descriptor = FetchDescriptor<PlayerModel>(predicate: #Predicate { $0.id == id })
        guard let pm = (try? context.fetch(descriptor))?.first(where: { !$0.isArchived }) else { return nil }
        return SeatRosterEntry(
            id: pm.id,
            name: pm.name,
            initials: pm.initials,
            themeID: pm.themeID,
            accentColor: SyTheme.accent(forThemeID: pm.themeID, colorScheme: colorScheme)
        )
    }

    /// Where this device stands with Game Night, read from `body` so the menu and the leading
    /// control follow the session (17 §4.8).
    var gameNightEntry: GameNightEntryState { GameNightEntryState(session: gameNight.session) }

    /// Which control the leading nav bar shows. The conditions live here, in one place, so
    /// leadingNavButton draws from it and its changes can be logged (18 §4.6). The order is
    /// the order the branches have always had.
    var leadingNavSlot: LeadingNavSlot {
        if gameNightEntry.leadingControl != nil {
            return .gameNight
        } else if gameNight.isSessionActive && gameNight.role == .host && gameNight.phase == .completed {
            return .hostRematch
        } else if model.hasGameActivity && !model.isGameOver {
            return .newGame
        } else if model.isGameOver {
            return .playAgain
        } else {
            return .empty
        }
    }

    /// Leading nav bar button. SyLib's Game Night control when the state has one (D-140);
    /// otherwise SyFive's Play Again for a host whose match is over, or the standard
    /// new-game / reset button.
    @ViewBuilder
    var leadingNavButton: some View {
        switch leadingNavSlot {
        case .gameNight:
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
            }
        case .hostRematch:
            IconButton("arrow.clockwise.circle", context: .toolbar) {
                startGameNightRematch()
            }
            .accessibilityLabel("Play Again")
        case .newGame:
            // Active game — reset button opens the pause/delete alert.
            IconButton("arrow.clockwise", context: .toolbar) { showsResetAlert = true }
                .accessibilityLabel("New Game")
        case .playAgain:
            // Game finished — one-tap play again with same players.
            IconButton("plus", context: .toolbar) {
                logModelState("playAgain(toolbar) before")
                model.abandonMatch(in: modelContext)
                model.resetGame()
                celebrationCoordinator.clearWinnerAnnouncement()
                logModelState("playAgain(toolbar) after")
            }
            .accessibilityLabel("Play Again")
        case .empty:
            EmptyView()
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

/// The control in the leading nav bar slot (18 §4.6). Its changes are logged, to diagnose a
/// restart button that went missing mid-game.
enum LeadingNavSlot: Equatable {
    case gameNight, hostRematch, newGame, playAgain, empty
}
