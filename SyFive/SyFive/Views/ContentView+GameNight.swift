import SwiftUI
import SyLibCore
import SyLibGameNight
import SyLibScoring
import SyLibScoringData
import SwiftData

// MARK: - Game Night UI

extension ContentView {

    /// Leading nav bar button — tracks Game Night state when a session is active or pending,
    /// otherwise shows the standard new-game / reset button.
    @ViewBuilder
    var leadingNavButton: some View {
        if gameNight.isSessionPending {
            // Invite sent. With Messages SharePlay the host's session only arrives when
            // they tap the system SharePlay banner — explain that rather than just cancelling.
            Button {
                showsGameNightPendingSheet = true
            } label: {
                Image(systemName: "person.3.fill")
            }
            .accessibilityLabel("Game Night Invite Sent")
            .tint(Color.green)
        } else if gameNight.isSessionActive {
            if gameNight.phase == .settingTable {
                Button { showsGameNight = true } label: {
                    Image(systemName: "person.3.fill")
                }
                .accessibilityLabel("Game Night Setup")
                .tint(Color.green)
            } else if gameNight.phase == .inProgress && gameNight.role == .host {
                Button {
                    gnAlerts.showsCancelSession = true
                } label: {
                    Image(systemName: "person.3.fill")
                }
                .accessibilityLabel("End Game Night")
                .tint(Color.green)
            } else if gameNight.phase == .completed && gameNight.role == .host {
                Button {
                    startGameNightRematch()
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                }
                .accessibilityLabel("Play Again")
            } else {
                // Guest during active session — green indicator, non-interactive.
                Image(systemName: "person.3.fill")
                    .foregroundStyle(Color.green)
            }
        } else if gameNight.session.isEligibleForGroupSession {
            // Active FaceTime/iMessage call — promote Game Night as the primary action.
            Button {
                gameNight.beginHosting(
                    onNeedsConversation: { showsInviteInstructions = true },
                    onReadyToSeat: { presentGameNightSheetOrAlert() }
                )
            } label: {
                Image(systemName: "person.3.fill")
            }
            .accessibilityLabel("Game Night")
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

    /// Context-aware Game Night section for the main menu. Never calls activate()
    /// when a session is already live — prevents the iOS "Replace?" conflict dialog
    /// that appears when a second device tries to start while the host's session is
    /// still propagating via GroupActivities.
    @ViewBuilder
    var gameNightMenuSection: some View {
        if !gameNight.isSessionActive && !gameNight.isSessionPending {
            // No session and no pending invite — offer to start one as host.
            Button {
                gameNight.beginHosting(
                    onNeedsConversation: { showsInviteInstructions = true },
                    onReadyToSeat: { presentGameNightSheetOrAlert() }
                )
            } label: {
                Label("Start Game Night", systemImage: "person.3.fill")
            }
            Button { showsGameNightHelp = true } label: {
                Label("Game Night Help", systemImage: "questionmark.circle")
            }
        } else if gameNight.isSessionPending {
            // Invite sent — waiting for recipients to accept. Block a second invite.
            Button(role: .destructive) {
                gnAlerts.showsCancelSession = true
            } label: {
                Label("Cancel Game Night Invite", systemImage: "xmark.circle")
            }
            Button { showsGameNightHelp = true } label: {
                Label("Game Night Help", systemImage: "questionmark.circle")
            }
        } else {
            // Active session — show phase-appropriate actions; never re-activate.
            if gameNight.phase == .settingTable {
                Button { showsGameNight = true } label: {
                    Label("Game Night Setup", systemImage: "person.3.fill")
                }
            }
            if gameNight.role == .host {
                if gameNight.phase == .inProgress {
                    Button(role: .destructive) {
                        gnAlerts.showsCancelSession = true
                    } label: {
                        Label("End Game Night", systemImage: "xmark.circle")
                    }
                }
                if gameNight.phase == .completed {
                    Button {
                        startGameNightRematch()
                    } label: {
                        Label("Play Again", systemImage: "arrow.clockwise.circle")
                    }
                }
            } else if gameNight.phase == .settingTable {
                // Escape hatch: when both devices relaunch as guests with no host,
                // let a non-host end the broken session from the menu.
                Button(role: .destructive) {
                    gnAlerts.showsCancelSession = true
                } label: {
                    Label("End Game Night", systemImage: "xmark.circle")
                }
            } else if gameNight.role != .host && gameNight.phase == .inProgress {
                // Guest during active game — green status indicator, no action.
                Button { } label: {
                    Label("Game Night Active", systemImage: "person.3.fill")
                }
                .tint(Color.green)
            }
            Button { showsGameNightHelp = true } label: {
                Label("Game Night Help", systemImage: "questionmark.circle")
            }
        }
    }

    /// True when the leading area is showing a Game Night action (not the plain + / ↺ button).
    /// Controls visibility of the help (?) button that sits to the right of it.
    var showsGameNightHelpButton: Bool {
        (gameNight.session.isEligibleForGroupSession && !gameNight.isSessionActive && !gameNight.isSessionPending) ||
        gameNight.isSessionPending ||
        (gameNight.isSessionActive && gameNight.phase == .settingTable)
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
    /// Applies the same name+initials collision check as ensurePlayerModels() — if a local
    /// roster player already exists, all participants are remapped immediately rather than
    /// creating a duplicate gameNight-sourced entry.
    func upsertGameNightPlayerModels() {
        guard gameNight.isSessionActive else { return }
        var changed = false
        for i in 0..<model.playerCount {
            guard let playerID = model.playerIDs[i] else { continue }

            var byID = FetchDescriptor<PlayerModel>(predicate: #Predicate { $0.id == playerID })
            byID.fetchLimit = 1
            if (try? modelContext.fetch(byID))?.first != nil { continue }

            let pName = model.playerDisplayNames[i]
            let pInitials = model.playerDisplayInitials[i]
            let localSource = PlayerSource.local.rawValue
            var byName = FetchDescriptor<PlayerModel>(
                predicate: #Predicate { $0.name == pName && $0.initials == pInitials && $0.sourceRaw == localSource }
            )
            byName.fetchLimit = 1
            if let canonical = (try? modelContext.fetch(byName))?.first {
                let allParticipants = (try? modelContext.fetch(FetchDescriptor<ParticipantModel>())) ?? []
                for participant in allParticipants where participant.playerID == playerID {
                    participant.playerID = canonical.id
                }
                logger.info(self, "upsertGameNightPlayerModels: remapped '\(pName)' \(playerID) → \(canonical.id)")
                changed = true
                continue
            }

            let newPM = PlayerModel()
            newPM.id = playerID
            newPM.name = pName
            newPM.initials = pInitials
            newPM.themeID = model.playerThemes[i].rawValue
            newPM.source = PlayerSource.gameNight
            modelContext.insert(newPM)
            changed = true
        }
        if changed { try? modelContext.save() }
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
