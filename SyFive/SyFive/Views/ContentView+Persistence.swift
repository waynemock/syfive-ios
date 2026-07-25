import SwiftUI
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
                let wasHost = UserDefaults.standard.gnWasHost(for: matchModel.id)
                if wasHost {
                    // Host re-initiates the session from the reconnect alert.
                    showsGameNightReconnect = true
                    pendingResumeMatchID = matchModel.id
                    let yatzyID = ScoringSystemID.yatzy.rawValue
                    let gameDesc = FetchDescriptor<GameModel>(
                        predicate: #Predicate { $0.scoringSystemID == yatzyID }
                    )
                    pendingResumeGameID = (try? modelContext.fetch(gameDesc))?.first?.id
                } else {
                    // Guest (or host whose wasHost flag was lost): show a choice rather than
                    // silently blocking rolling. prepareForGuestReconnect is called only on opt-in.
                    showsGameNightGuestReconnect = true
                    pendingGuestReconnectMatchID = matchModel.id
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
        let playersByID     = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0) })
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
    /// When a Game Night UUID has no local PlayerModel but a local roster player with the
    /// same name+initials exists, all ParticipantModel records are remapped to the canonical
    /// local UUID instead of creating a duplicate entry.
    func ensurePlayerModels(for participants: [ParticipantModel]) {
        var changed = false
        for p in participants {
            guard let playerID = p.playerID else { continue }

            // Already have a PlayerModel for this UUID — nothing to do.
            var byID = FetchDescriptor<PlayerModel>(predicate: #Predicate { $0.id == playerID })
            byID.fetchLimit = 1
            if (try? modelContext.fetch(byID))?.first != nil { continue }

            // Before creating a new entry, check if a local roster player with matching
            // name+initials already exists. Game Night sessions can carry a different UUID
            // for the same physical person; remapping prevents identity splits in House Records.
            let pName = p.displayName
            let pInitials = p.displayInitials
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
                logger.info(self, "ensurePlayerModels: remapped '\(pName)' \(playerID) → \(canonical.id)")
                changed = true
                continue
            }

            // No local player found — create a gameNight-sourced PlayerModel.
            let newPM = PlayerModel()
            newPM.id = playerID
            newPM.name = p.displayName
            newPM.initials = p.displayInitials
            newPM.themeID = p.displayThemeID
            newPM.source = .gameNight
            modelContext.insert(newPM)
            changed = true
        }
        if changed { try? modelContext.save() }
    }

    func markCurrentMatchAsGameNight() {
        var descriptor = FetchDescriptor<MatchModel>(
            predicate: #Predicate { $0.statusRaw == "inProgress" },
            sortBy: [SortDescriptor(\MatchModel.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let matchModel = (try? modelContext.fetch(descriptor))?.first else { return }
        guard !matchModel.isGameNight else { return }
        matchModel.isGameNight = true
        try? modelContext.save()
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

    #if DEBUG
    /// Inserts and immediately deletes one dummy row for every registered model type so CloudKit
    /// JIT-creates all record types and fields in the Development environment.
    /// Only runs when `AppConfig.DebugCloudKit.runSchemaExercise == true`.
    func runCloudKitSchemaExercise() {
        guard AppConfig.DebugCloudKit.runSchemaExercise else { return }
        let player = PlayerModel()
        let team = TeamModel()
        let game = GameModel()
        let match = MatchModel()
        let participant = ParticipantModel()
        let settings = AppSettingsModel()
        modelContext.insert(player)
        modelContext.insert(team)
        modelContext.insert(game)
        modelContext.insert(match)
        modelContext.insert(participant)
        modelContext.insert(settings)
        try? modelContext.save()
        modelContext.delete(participant)
        modelContext.delete(match)
        modelContext.delete(player)
        modelContext.delete(team)
        modelContext.delete(game)
        modelContext.delete(settings)
        try? modelContext.save()
        AppLogger(category: "CloudKit").info(self, "Schema exercise complete — check CloudKit Console > Development for all record types")
    }
    #endif
}
