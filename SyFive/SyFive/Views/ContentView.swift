import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @State private var model = MatchController()
    @State private var director = FeelDirector()
    @State private var showsResetAlert = false
    @State private var showsHouseRecords = false
    @State private var showsHistory = false
    @State private var showsPlayers = false
    @State private var showsSettings = false
    @State private var showsAbout = false
    @State private var showsFeelBoard = false
    @State private var showsGameNight = false
    @State private var showsSessionEndedAlert = false
    @State private var showsGameNightReconnect = false
    @State private var showsGameNightGuestReconnect = false
    @State private var showsGameNightLocalConflictAlert = false
    @State private var showsInviteInstructions = false
    @State private var showsCancelGameNightAlert = false
    @State private var showsGameNightHelp = false
    /// Set when the reconnect alert's "Restart as Host" is tapped, so isSessionActive handler
    /// can skip the seating sheet and jump straight to the in-progress match.
    @State private var pendingResumeMatchID: UUID? = nil
    @State private var pendingResumeGameID: UUID? = nil
    /// Match ID held across the guest reconnect alert — passed to prepareForGuestReconnect
    /// only if the user explicitly taps Rejoin.
    @State private var pendingGuestReconnectMatchID: UUID? = nil
    @State private var celebrationCoordinator = CelebrationCoordinator()
    @State private var commentaryEngine: CommentaryEngine? = nil
    @State private var isUpdateAvailable = false
    @State private var updateBadgeAcknowledged = false
    @Environment(GameNightController.self) private var gameNight
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsModels: [AppSettingsModel]
    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" })
    private var completedMatchesGate: [MatchModel]

    private var hasCompletedMatch: Bool { !completedMatchesGate.isEmpty }
    private let showsDebugLayout = AppConfig.DebugLayout.isEnabled
    private let logger = AppLogger(category: "ContentView")

    private var appSettings: AppSettingsModel? { settingsModels.first }

    var body: some View {
        let theme = Theme(type: model.themeType(for: model.currentPlayerIndex), colorScheme: colorScheme)
        NavigationStack {
            GeometryReader { proxy in
                geometryContent(proxy: proxy)
            }
            .background(debugColor(Color.yellow.opacity(0.25)))
            .background(theme.backgroundColor)
            .overlay(showsDebugLayout ? SafeAreaDebugView() : nil)
            .onPreferenceChange(ContentLayoutSizePreferenceKey.self) { size in
                let isPortrait = size.height >= size.width
                logger.debug(self, "content size: \(size.width)x\(size.height), isPortrait=\(isPortrait)")
                logger.debug(self, "scorecard width from GeometryReader: \(size.width)")
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    leadingNavButton
                    if showsGameNightHelpButton {
                        Button { showsGameNightHelp = true } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel("Game Night Help")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if isUpdateAvailable {
                            Button {
                                openAppStore()
                            } label: {
                                Label("Update Available", systemImage: "arrow.down.circle")
                            }
                            Divider()
                        }
                        if hasCompletedMatch {
                            Button {
                                showsHouseRecords = true
                            } label: {
                                Label("House Records", systemImage: "trophy.fill")
                            }
                        }
                        Button {
                            showsPlayers = true
                        } label: {
                            Label("Players", systemImage: "person.2")
                        }
                        Button {
                            showsHistory = true
                        } label: {
                            Label("History", systemImage: "clock")
                        }
                        Divider()
                        gameNightMenuSection
                        Divider()
                        Button {
                            showsSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Divider()
                        Button {
                            showsAbout = true
                        } label: {
                            Label("About", systemImage: "info.circle")
                        }
                        Button {
                            openSyzygyAppStore()
                        } label: {
                            Label("App Store", systemImage: "storefront.fill")
                        }
                        #if DEBUG
                        if AppConfig.DebugFeel.showFeelBoard {
                            Divider()
                            Button {
                                showsFeelBoard = true
                            } label: {
                                Label("Feel Board", systemImage: "waveform")
                            }
                        }
                        #endif
                    } label: {
                        MainMenuButton(showBadge: shouldShowUpdateBadge)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        acknowledgeUpdateBadge()
                    })
                }
            }
            .alert("Start a new game?", isPresented: $showsResetAlert) {
                Button("Cancel", role: .cancel) {}
                if gameNight.isSessionActive && gameNight.role == .host {
                    Button("New Game Night Game") {
                        model.abandonMatch(in: modelContext)
                        model.resetGame()
                        startGameNightRematch()
                    }
                    Button("Play Locally", role: .destructive) {
                        model.abandonMatch(in: modelContext)
                        model.resetGame()
                    }
                } else {
                    Button("Pause") {
                        // Detach from the current record in memory — it stays in History
                        // as an Unfinished game resumable from the next app launch.
                        model.resetGame()
                    }
                    Button("Delete & Start New", role: .destructive) {
                        model.abandonMatch(in: modelContext)
                        model.resetGame()
                    }
                }
            } message: {
                Text(gameNight.isSessionActive && gameNight.role == .host
                     ? "Start a new Game Night game with the same players, or reset to a local game."
                     : "Pause saves the game to History so you can resume it later. Delete removes it permanently.")
            }
            .alert("Game Night ended", isPresented: $showsSessionEndedAlert) {
                Button("OK") { gameNight.clearSessionEndedFlag() }
            } message: {
                Text("Your progress has been saved. Start a new Game Night session to continue.")
            }
            .alert("Reconnect to Game Night?", isPresented: $showsGameNightGuestReconnect) {
                Button("Rejoin") {
                    if let matchID = pendingGuestReconnectMatchID {
                        gameNight.prepareForGuestReconnect(matchID: matchID)
                    }
                    pendingGuestReconnectMatchID = nil
                }
                Button("Play Locally", role: .cancel) {
                    pendingGuestReconnectMatchID = nil
                }
            } message: {
                Text("Your scores are intact. If the host restarts the session you'll rejoin automatically.")
            }
            .alert("Reconnect Game Night?", isPresented: $showsGameNightReconnect) {
                Button("Resume as Host") {
                    gameNight.prepareAsHost()
                    GameNightSharing.present(
                        onRequiresConversation: {
                            gameNight.cancelHostPreparation()
                            pendingResumeMatchID = nil
                            pendingResumeGameID = nil
                        },
                        onDismissed: {
                            logger.info(self, "reconnect onDismissed: isSessionActive=\(gameNight.isSessionActive) phase=\(String(describing: gameNight.phase))")
                            if gameNight.isSessionActive && gameNight.phase == .settingTable {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    guard gameNight.isSessionActive && gameNight.phase == .settingTable else { return }
                                    showsGameNight = true
                                }
                            }
                        },
                        onCancelled: {
                            gameNight.cancelHostPreparation()
                            pendingResumeMatchID = nil
                            pendingResumeGameID = nil
                        }
                    )
                }
                Button("Play Locally", role: .cancel) {
                    pendingResumeMatchID = nil
                    pendingResumeGameID = nil
                }
            } message: {
                Text("Your scores are intact. If you were the host, tap Resume as Host — guests will rejoin automatically.")
            }
            .alert(
                gameNight.isSessionPending ? "Cancel Game Night Invite?" : "End Game Night?",
                isPresented: $showsCancelGameNightAlert
            ) {
                Button(gameNight.isSessionPending ? "Cancel Invite" : "End Game Night",
                       role: .destructive) {
                    if gameNight.isSessionPending {
                        gameNight.cancelHostPreparation()
                    } else if gameNight.role == .host {
                        gameNight.abandonSession()
                    } else {
                        // Guest ending the session — nuclear option for broken/stuck states.
                        gameNight.endSession()
                    }
                }
                Button(gameNight.isSessionPending ? "Keep Waiting" : "Keep Playing",
                       role: .cancel) {}
            } message: {
                Text(gameNight.isSessionPending
                     ? "Your invite will be cancelled and the other player won't be able to join."
                     : "This will end the Game Night session for all players.")
            }
            .alert("Local Game in Progress", isPresented: $showsGameNightLocalConflictAlert) {
                Button("Play Game Night") {
                    showsGameNight = true
                }
                Button("Keep Playing", role: .cancel) {}
            } message: {
                Text("Starting Game Night will set aside your current game. You can resume it from History later.")
            }
            .onChange(of: gameNight.sessionEndedDuringPlay) { _, ended in
                if ended { showsSessionEndedAlert = true }
            }
        }
        .overlay {
            CelebrationView(model: model)
                .ignoresSafeArea()
        }
        .preferredColorScheme(appSettings?.colorScheme.preferredColorScheme ?? .dark)
        .tint(theme.primaryAccent)
        .environment(\.theme, theme)
        .environment(\.suggestedMoveEnabled, appSettings?.suggestedMoveEnabled ?? true)
        .environment(director)
        .environment(celebrationCoordinator)
        .task {
            isUpdateAvailable = await AppUpdateChecker.shared.isUpdateAvailable()
            await director.warmUp()
        }
        .onAppear {
            seedSettingsIfNeeded()
            seedYatzyGameIfNeeded()
            loadMatchIfNeeded()
            healOrphanedParticipants()
            // Sync initial settings values (onChange won't fire for the first load).
            director.soundEnabled   = appSettings?.soundEnabled   ?? true
            director.hapticsEnabled = appSettings?.hapticsEnabled ?? true
            // Warm up haptic engine before first roll to avoid first-event latency (§6.2).
            director.warmUpHaptics()
            syncCommentaryEngine()
        }
        // Restore commentary when session ends (isSessionActive false→true is handled below).
        // Also dismiss the Game Night sheet so guests aren't left stranded if the host ends the session.
        .onChange(of: gameNight.isSessionActive) { _, active in
            if !active {
                showsGameNight = false
                syncCommentaryEngine()
            }
        }
        // Keyed off sessionActivationCount rather than isSessionActive so this always fires,
        // even when tearDownSession() + reconfigure flips isSessionActive false→true in the
        // same SwiftUI render cycle (net value unchanged → onChange would otherwise be skipped).
        .onChange(of: gameNight.sessionActivationCount) { _, count in
            logger.info(self, "onChange(sessionActivationCount): count=\(count) isSessionActive=\(gameNight.isSessionActive) phase=\(String(describing: gameNight.phase))")
            guard gameNight.isSessionActive else {
                logger.warning(self, "onChange(sessionActivationCount): isSessionActive=false, skipping")
                return
            }
            syncCommentaryEngine()
            showsGameNightReconnect = false
            // Close any open sheets so the seating sheet can present immediately.
            showsHouseRecords = false
            showsHistory = false
            showsPlayers = false
            showsSettings = false
            showsAbout = false
            showsFeelBoard = false
            showsInviteInstructions = false
            gameNight.attach(matchController: model)
            let ctx = modelContext
            gameNight.onMatchComplete = { completedMatch in
                // Guests write exactly once — upsert by session UUID.
                let matchID = completedMatch.id
                var descriptor = FetchDescriptor<MatchModel>(
                    predicate: #Predicate { $0.id == matchID }
                )
                descriptor.fetchLimit = 1
                if let existing = (try? ctx.fetch(descriptor))?.first {
                    existing.hydrate(from: completedMatch, context: ctx)
                } else {
                    let newModel = MatchModel()
                    ctx.insert(newModel)
                    newModel.hydrate(from: completedMatch, context: ctx)
                }
                try? ctx.save()
            }
            // Reconnect path: skip the seating sheet and jump into the running match.
            // Fresh sessions show the seating sheet normally.
            if let matchID = pendingResumeMatchID, let gameID = pendingResumeGameID {
                pendingResumeMatchID = nil
                pendingResumeGameID = nil
                gameNight.resumeAsHost(matchID: matchID, gameID: gameID)
            } else {
                // Delay sheet presentation so the UIKit GroupActivitySharingController
                // dismiss animation (~0.35s) fully completes before SwiftUI presents.
                // controller.result resolves when the user's action completes, not when
                // the animation finishes. Without the delay, showsGameNight = true silently
                // fails and gets stuck at true (making subsequent taps no-ops).
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard gameNight.isSessionActive else { return }
                    // Don't show the seating sheet when the game is already running —
                    // the host's matchState arrives during the 500ms window on reconnect.
                    guard gameNight.phase != .inProgress else { return }
                    logger.info(self, "onChange(sessionActivationCount): showing Game Night sheet")
                    presentGameNightSheetOrAlert()
                }
            }
        }
        .onChange(of: gameNight.phase) { _, newPhase in
            if newPhase == .inProgress {
                showsGameNight = false
                markCurrentMatchAsGameNight()
                upsertGameNightPlayerModels()
            }
            // Re-show the seating sheet when the host calls playAgain().
            if newPhase == .settingTable && gameNight.isSessionActive { showsGameNight = true }
        }
        .onChange(of: model.playerCount) { saveMatch() }
        .onChange(of: model.playerScores) { saveMatch() }
        .onChange(of: appSettings?.soundEnabled)   { _, v in director.soundEnabled   = v ?? true }
        .onChange(of: appSettings?.hapticsEnabled) { _, v in director.hapticsEnabled = v ?? true }
        .onChange(of: appSettings?.commentaryEnabled)      { _, _ in syncCommentaryEngine() }
        .onChange(of: appSettings?.commentaryLevelRaw)     { _, _ in syncCommentaryEngine() }
        .onChange(of: appSettings?.commentaryPersonalityID){ _, _ in syncCommentaryEngine() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: director.stopAudioForBackground()
            case .active:     director.handleForeground()
            default: break
            }
        }
        .onChange(of: model.isGameOver) { _, isGameOver in
            guard isGameOver else { return }
            celebrationCoordinator.triggerGameOver(winnerIndices: model.winnerIndices)
        }
        .sheet(isPresented: $showsHouseRecords) {
            HouseRecordsView()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsHistory) {
            MatchHistoryView(
                activeMatchID: model.persistedMatchID,
                onActiveMatchDeleted: { model.resetGame() }
            )
            .environment(\.theme, theme)
            .environment(director)
        }
        .sheet(isPresented: $showsPlayers) {
            PlayersView()
        }
        .sheet(isPresented: $showsSettings, onDismiss: { syncCommentaryEngine() }) {
            SettingsView()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsFeelBoard) {
            FeelBoardView()
                .environment(director)
        }
        .sheet(isPresented: $showsGameNight) {
            TableSettingView(gameNight: gameNight)
        }
        .sheet(isPresented: $showsInviteInstructions) {
            GameNightInviteInstructions()
        }
        .sheet(isPresented: $showsGameNightHelp) {
            GameNightHelpSheet(context: gameNightHelpContext, isEligibleForGroupSession: gameNight.isEligibleForGroupSession)
                .environment(\.theme, theme)
        }
    }

    @ViewBuilder
    private func geometryContent(proxy: GeometryProxy) -> some View {
        let isPortrait = proxy.size.height >= proxy.size.width
        let contentWidth = max(0, proxy.size.width - 48)
        let scorecardAvailableWidth = isPortrait
            ? proxy.size.width
            : max(0, (contentWidth - 20) / 2 + 48)
        // AnyLayout switches between VStack/HStack while preserving
        // subview identity — this prevents DiceAreaView (and its
        // embedded RealityView) from being destroyed on rotation.
        let layout = isPortrait
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 20))
        layout {
            DiceAreaView(model: model)
                .background(debugColor(Color.red.opacity(0.25)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ScorecardView(model: model, availableWidth: scorecardAvailableWidth)
                .padding(.horizontal, -24)
                .background(debugColor(Color.green.opacity(0.25)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .background(Color.clear.preference(key: ContentLayoutSizePreferenceKey.self, value: proxy.size))
        .onAppear {
            logger.debug(self, "geometry size onAppear: \(proxy.size.width)x\(proxy.size.height)")
        }
        .onChange(of: proxy.size) { _, newSize in
            let newContentWidth = max(0, newSize.width - 48)
            let newScorecardWidth = isPortrait
                ? newSize.width
                : max(0, (newContentWidth - 20) / 2 + 48)
            logger.debug(self, "geometry size onChange: \(newSize.width)x\(newSize.height)")
            logger.debug(self, "scorecardAvailableWidth: \(newScorecardWidth)")
        }
    }

    private func syncCommentaryEngine() {
        // Commentary speaks only on the host's seated device during Game Night (10 §3).
        if gameNight.isSessionActive && gameNight.role != .host {
            commentaryEngine?.stopSpeaking()
            commentaryEngine = nil
            model.commentaryEventSink = nil
            return
        }
        guard let settings = appSettings, settings.commentaryEnabled else {
            commentaryEngine?.stopSpeaking()
            commentaryEngine = nil
            model.commentaryEventSink = nil
            return
        }
        let personality = CommentaryPersonality.find(id: settings.commentaryPersonalityID)
        let level = CommentaryLevel(rawValue: settings.commentaryLevelRaw) ?? .celebrations
        let voiceID = UserDefaults.standard.commentaryVoiceID
        let voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
        if let engine = commentaryEngine {
            engine.update(personality: personality, voice: voice, level: level)
        } else {
            let engine = CommentaryEngine(personality: personality, voice: voice, level: level)
            commentaryEngine = engine
            model.commentaryEventSink = { [weak engine] event in engine?.handle(event) }
        }
    }

    private func loadMatchIfNeeded() {
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
    private func healOrphanedParticipants() {
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
    private func ensurePlayerModels(for participants: [ParticipantModel]) {
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

    private func markCurrentMatchAsGameNight() {
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

    /// Creates PlayerModel records for any remote participants whose playerID doesn't
    /// exist in local storage yet. Called when a Game Night match goes .inProgress so
    /// every device has a full player roster for stats and future merge UI.
    /// Applies the same name+initials collision check as ensurePlayerModels() — if a local
    /// roster player already exists, all participants are remapped immediately rather than
    /// creating a duplicate gameNight-sourced entry.
    private func upsertGameNightPlayerModels() {
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

    private func startGameNightRematch() {
        let yatzyID = ScoringSystemID.yatzy.rawValue
        let descriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == yatzyID }
        )
        guard let gameID = (try? modelContext.fetch(descriptor))?.first?.id else { return }
        gameNight.broadcastRematch(gameID: gameID)
        markCurrentMatchAsGameNight()
    }

    private func saveMatch() {
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

    private func seedSettingsIfNeeded() {
        guard settingsModels.isEmpty else { return }
        modelContext.insert(AppSettingsModel())
    }

    private func seedYatzyGameIfNeeded() {
        let yatzyID = ScoringSystemID.yatzy.rawValue
        let descriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == yatzyID }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        let game = GameModel()
        game.name = "Yatzy"
        game.scoringSystemID = ScoringSystemID.yatzy.rawValue
        game.scoringSystemVersion = 1
        game.isBuiltIn = true
        game.supportsTeams = false
        game.maxParticipants = 0
        game.sortOrder = 0
        modelContext.insert(game)
    }

    private var shouldShowUpdateBadge: Bool {
        isUpdateAvailable && !updateBadgeAcknowledged
    }

    private func acknowledgeUpdateBadge() {
        guard shouldShowUpdateBadge else { return }
        updateBadgeAcknowledged = true
    }

    private func openAppStore() {
        openURL(AboutView.appStoreURL)
    }

    /// Opens the App Store page for Syzygy
    private func openSyzygyAppStore() {
        guard let appStoreURL = URL(string: "https://apps.apple.com/us/developer/syzygy-softwerks-llc/id1118759442") else { return }
        openURL(appStoreURL)
    }

    /// Leading nav bar button — tracks Game Night state when a session is active or pending,
    /// otherwise shows the standard new-game / reset button.
    @ViewBuilder
    private var leadingNavButton: some View {
        if gameNight.isSessionPending {
            // Invite sent — let the host cancel from the nav bar (with confirmation).
            Button {
                showsCancelGameNightAlert = true
            } label: {
                Image(systemName: "person.3.fill")
            }
            .accessibilityLabel("Cancel Game Night Invite")
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
                    showsCancelGameNightAlert = true
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
        } else if gameNight.isEligibleForGroupSession {
            // Active FaceTime/iMessage call — promote Game Night as the primary action.
            Button {
                gameNight.prepareAsHost()
                GameNightSharing.present(
                    onRequiresConversation: {
                        gameNight.cancelHostPreparation()
                        showsInviteInstructions = true
                    },
                    onDismissed: {
                        if gameNight.isSessionActive && gameNight.phase == .settingTable {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                guard gameNight.isSessionActive && gameNight.phase == .settingTable else { return }
                                presentGameNightSheetOrAlert()
                            }
                        }
                    },
                    onCancelled: {
                        gameNight.cancelHostPreparation()
                    }
                )
            } label: {
                Image(systemName: "person.3.fill")
            }
            .accessibilityLabel("Game Night")
        } else {
            // No Game Night — standard new-game / reset button.
            Button {
                if model.hasGameActivity && !model.isGameOver {
                    showsResetAlert = true
                } else {
                    model.abandonMatch(in: modelContext)
                    model.resetGame()
                }
            } label: {
                Image(systemName: model.hasGameActivity && !model.isGameOver ? "arrow.clockwise" : "plus")
            }
            .accessibilityLabel("New Game")
        }
    }

    /// Context-aware Game Night section for the main menu. Never calls activate()
    /// when a session is already live — prevents the iOS "Replace?" conflict dialog
    /// that appears when a second device tries to start while the host's session is
    /// still propagating via GroupActivities.
    @ViewBuilder
    private var gameNightMenuSection: some View {
        if !gameNight.isSessionActive && !gameNight.isSessionPending {
            // No session and no pending invite — offer to start one as host.
            Button {
                gameNight.prepareAsHost()
                GameNightSharing.present(
                    onRequiresConversation: {
                        // Sharing controller was cancelled or needs a conversation first.
                        // Reset host preparation so a later incoming session from another
                        // device doesn't incorrectly claim this device as host.
                        gameNight.cancelHostPreparation()
                        showsInviteInstructions = true
                    },
                    onDismissed: {
                        logger.info(self, "gameNightMenu onDismissed: isSessionActive=\(gameNight.isSessionActive) phase=\(String(describing: gameNight.phase))")
                        // With Messages SharePlay, the session can arrive while the UIKit modal
                        // is on screen. Re-show the seating sheet after a brief delay so the
                        // UIKit dismiss animation finishes before SwiftUI tries to present.
                        if gameNight.isSessionActive && gameNight.phase == .settingTable {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                guard gameNight.isSessionActive && gameNight.phase == .settingTable else { return }
                                presentGameNightSheetOrAlert()
                            }
                        }
                    },
                    onCancelled: {
                        gameNight.cancelHostPreparation()
                    }
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
                showsCancelGameNightAlert = true
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
                        showsCancelGameNightAlert = true
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
                    showsCancelGameNightAlert = true
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
    private var showsGameNightHelpButton: Bool {
        (gameNight.isEligibleForGroupSession && !gameNight.isSessionActive && !gameNight.isSessionPending) ||
        gameNight.isSessionPending ||
        (gameNight.isSessionActive && gameNight.phase == .settingTable)
    }

    private var gameNightHelpContext: GameNightHelpSheet.Context {
        if gameNight.isSessionPending || (gameNight.isSessionActive && gameNight.role == .host) {
            return .hosting
        } else if gameNight.isSessionActive && gameNight.role != .host {
            return .joined
        } else {
            return .preSession
        }
    }

    private func presentGameNightSheetOrAlert() {
        if model.hasStarted && !model.isGameOver {
            showsGameNightLocalConflictAlert = true
        } else {
            showsGameNight = true
        }
    }

    private func debugColor(_ color: Color) -> Color {
        showsDebugLayout ? color : Color.clear
    }

    private var navigationTitle: String {
        if model.isGameOver {
            let names = model.winnerNames.joined(separator: ", ")
            return names.isEmpty ? "SyFive" : "\(names) Wins"
        }
        if model.hasStarted {
            if let names = model.leadingPlayerLabel, !names.isEmpty {
                return "\(names) • Turn \(model.currentRound)/\(model.totalRounds)"
            }

            return "Turn \(model.currentRound)/\(model.totalRounds)"
        }
        return "SyFive"
    }

}

private struct ContentLayoutSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    let schema = Schema([
        PlayerModel.self, TeamModel.self, GameModel.self,
        MatchModel.self, ParticipantModel.self, AppSettingsModel.self,
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )

    // Seed a completed match so loadMatchIfNeeded() pre-populates 2 players.
    let match = MatchModel()
    match.statusRaw = "completed"
    container.mainContext.insert(match)

    let p1 = ParticipantModel()
    p1.displayName = "Wayne"
    p1.displayInitials = "WM"
    p1.displayThemeID = Theme.ThemeType.midnight.rawValue
    p1.seat = 0
    p1.playerID = UUID()
    p1.match = match
    container.mainContext.insert(p1)

    let p2 = ParticipantModel()
    p2.displayName = "Sherida"
    p2.displayInitials = "SM"
    p2.displayThemeID = Theme.ThemeType.forest.rawValue
    p2.seat = 1
    p2.playerID = UUID()
    p2.match = match
    container.mainContext.insert(p2)

    return ContentView()
        .environment(GameNightController())
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
