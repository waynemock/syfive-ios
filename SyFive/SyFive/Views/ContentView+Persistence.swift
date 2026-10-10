import SwiftUI
import SyLibCore
import SyLibGameNight
import SyLibGameNightMatch
import SyLibScoring
import SyLibScoringData
import SwiftData

extension ContentView {

    func loadMatchIfNeeded() {
        // Resume an in-progress match.
        var inProgress = FetchDescriptor<MatchModel>(
            predicate: #Predicate { $0.statusRaw == "inProgress" },
            sortBy: [SortDescriptor(\MatchModel.startedAt, order: .reverse)]
        )
        inProgress.fetchLimit = 1
        if let matchModel = (try? modelContext.fetch(inProgress))?.first,
           !matchModel.participants.isEmpty {
            model.load(from: matchModel)
            ensurePlayerModels(for: matchModel.participants)
            if matchModel.isGameNight && !gameNight.isSessionActive {
                let wasHost = gameNight.gnWasHost(for: matchModel.id)
                if wasHost {
                    // Host re-initiates the session from the reconnect alert.
                    gnAlerts.showsHostReconnect = true
                    let yatzyID = ScoringSystemID.yatzy.rawValue
                    let gameDesc = FetchDescriptor<GameModel>(
                        predicate: #Predicate { $0.scoringSystemID == yatzyID }
                    )
                    if let gameID = (try? modelContext.fetch(gameDesc))?.first?.id {
                        gameNight.coordinator.recordPendingHostResume(matchID: matchModel.id, gameID: gameID)
                    }
                } else {
                    // Guest (or host whose wasHost flag was lost): show a choice rather than
                    // silently blocking rolling. prepareForGuestReconnect is called only on opt-in.
                    gnAlerts.showsGuestReconnect = true
                    gnAlerts.pendingGuestReconnectMatchID = matchModel.id
                }
            }
            return
        }

        // No in-progress game — pre-populate players from the most recent completed game
        // so the user can start a rematch without re-selecting everyone.
        var completed = FetchDescriptor<MatchModel>(
            predicate: #Predicate { $0.statusRaw == "completed" },
            sortBy: [SortDescriptor(\MatchModel.startedAt, order: .reverse)]
        )
        completed.fetchLimit = 1
        guard let lastMatch = (try? modelContext.fetch(completed))?.first else { return }
        for p in lastMatch.participants.sorted(by: { $0.seat < $1.seat }) {
            model.restorePlayer(
                displayName: p.displayName,
                displayInitials: p.displayInitials,
                themeID: p.displayThemeID,
                playerID: p.playerID
            )
        }
        ensurePlayerModels(for: lastMatch.participants)
    }

    /// Detects orphaned participant UUIDs at launch and creates an archived PlayerModel for each
    /// one, so the identity split surfaces in PlayersView for the user to resolve via the Merge UI.
    /// No automatic name-matching is done — identity decisions are left to the user to prevent
    /// wrong auto-merges between different people who happen to share a name.
    func healOrphanedParticipants() {
        let allParticipants = (try? modelContext.fetch(FetchDescriptor<ParticipantModel>())) ?? []
        let allPlayers      = (try? modelContext.fetch(FetchDescriptor<PlayerModel>())) ?? []
        let playersByID     = Dictionary(allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if playersByID.count < allPlayers.count {
            logger.warning(self, "heal scan: \(allPlayers.count - playersByID.count) PlayerModel row(s) share an id with another row — kept the first of each")
        }
        let activePlayers   = allPlayers.filter { !$0.isArchived }

        let distinctIDs = Set(allParticipants.compactMap { $0.playerID })
        logger.debug(self, "heal scan: \(allParticipants.count) participants, \(distinctIDs.count) distinct playerIDs, \(allPlayers.count) PlayerModels (\(activePlayers.count) active, \(allPlayers.count - activePlayers.count) archived)")
        for id in distinctIDs {
            if let pm = playersByID[id] {
                logger.debug(self, "  \(id) → '\(pm.name)' source=\(pm.sourceRaw) archived=\(pm.isArchived)")
            } else {
                let snap = allParticipants.first { $0.playerID == id }
                logger.debug(self, "  \(id) → ORPHAN (displayName='\(snap?.displayName ?? "?")')")
            }
        }

        var changed = false

        // For each orphaned UUID, create an archived PlayerModel so the user can see it in the
        // Archived section of PlayersView and decide whether to merge it into another player.
        let orphanedIDs = distinctIDs.filter { playersByID[$0] == nil }
        for orphanID in orphanedIDs {
            guard let snap = allParticipants.first(where: { $0.playerID == orphanID }) else { continue }
            let placeholder = PlayerModel()
            placeholder.id = orphanID
            placeholder.name = snap.displayName
            placeholder.initials = snap.displayInitials
            placeholder.themeID = snap.displayThemeID
            placeholder.isArchived = true
            placeholder.source = .gameNight
            modelContext.insert(placeholder)
            logger.info(self, "heal: created archived entry for orphan '\(snap.displayName)' \(orphanID) — merge manually in Players")
            changed = true
        }

        if changed { try? modelContext.save() }
    }

    /// Ensures a PlayerModel exists locally for every participant with a non-nil playerID.
    /// Safe to call for any match type — local players already have entries (skip),
    /// and anonymous participants (playerID == nil) are skipped automatically.
    /// Used to recover missing Game Night remote player roster entries on app launch.
    /// The name-and-initials rule is SyLib's (`upsertGameNightRoster`, D-137): a participant with
    /// no local PlayerModel but the same name and initials as a local player is remapped onto
    /// it, except that a local player in this match never captures one, and one local player
    /// captures at most one participant per call.
    func ensurePlayerModels(for participants: [ParticipantModel]) {
        var players: [GameNightRosterPlayer] = []
        for p in participants {
            guard let playerID = p.playerID else { continue }
            players.append(GameNightRosterPlayer(
                id: playerID,
                name: p.displayName,
                initials: p.displayInitials,
                themeID: p.displayThemeID))
        }
        // The match's participants are its table.
        let seated = Set(participants.compactMap { $0.playerID })
        do {
            let changes = try upsertGameNightRoster(players, seatedPlayerIDs: seated, in: modelContext)
            if !changes.isEmpty {
                logger.info(self, "roster upsert: inserted \(changes.insertedIDs.count), remapped \(changes.remapped.count)")
            }
        } catch { logger.error(self, "roster upsert failed: \(error)") }
    }

    func syncPlayerThemesFromRoster() {
        let players = (try? modelContext.fetch(FetchDescriptor<PlayerModel>())) ?? []
        model.syncPlayerThemes(from: players)
    }

    func saveMatch() {
        guard model.hasGameActivity else { return }
        guard model.playerCount > 0 else { return }
        let yatzyID = ScoringSystemID.yatzy.rawValue
        let gameDescriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == yatzyID }
        )
        guard let gameID = (try? modelContext.fetch(gameDescriptor))?.first?.id else { return }
        model.save(to: modelContext, gameID: gameID)
        try? modelContext.save()
        if model.isGameNight, let matchID = model.persistedMatchID {
            GameNightLogBuffer.shared.associateMatch(matchID: matchID)
        }
    }

    func seedSettingsIfNeeded() {
        // Dedup: CloudKit sync can deliver a second settings row — keep the first, delete extras.
        if settingsModels.count > 1 {
            for extra in settingsModels.dropFirst() {
                modelContext.delete(extra)
            }
            try? modelContext.save()
            return
        }
        guard settingsModels.isEmpty else { return }
        modelContext.insert(AppSettingsModel())
    }

    func seedYatzyGameIfNeeded() {
        let yatzyID = ScoringSystemID.yatzy.rawValue
        let descriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == yatzyID },
            sortBy: [SortDescriptor(\GameModel.createdAt)]
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        // Dedup: CloudKit sync can deliver a second row — keep the fixed-UUID one, delete the rest.
        if existing.count > 1 {
            let keeper = existing.first(where: { $0.id == Game.builtInYatzyID }) ?? existing.first!
            for row in existing where row !== keeper {
                modelContext.delete(row)
            }
            try? modelContext.save()
            return
        }

        // One row already exists — nothing to seed.
        guard existing.isEmpty else { return }

        // Seed with the well-known UUID so every device produces the same CloudKit record.
        let game = GameModel()
        game.id = Game.builtInYatzyID
        game.name = "Yatzy"
        game.scoringSystemID = ScoringSystemID.yatzy.rawValue
        game.scoringSystemVersion = 1
        game.isBuiltIn = true
        game.supportsTeams = false
        game.maxParticipants = 0
        game.sortOrder = 0
        modelContext.insert(game)
    }
}
