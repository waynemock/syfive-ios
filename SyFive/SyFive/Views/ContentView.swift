import SwiftUI
import SyLibCommentary
import SyLibCore
import SyLibDice
import SyLibFeel
import SyLibGameNight
import SyLibGameNightMatch
import SyLibScoring
import SyLibScoringData
import SyLibUI
import SwiftData

struct ContentView: View {
    @State var model = MatchController()
    @State var director = FeelDirector(catalog: .syFive)
    @State var showsResetAlert = false
    @State var showsHouseRecords = false
    @State var showsHistory = false
    @State var showsPlayers = false
    @State var showsSettings = false
    @State var showsDiceFairness = false
    @State var showsAbout = false
    @State var showsFeelBoard = false
    @State var showsGameNight = false
    @State var gnAlerts = GameNightAlertState()
    @State var showsGameNightLocalConflictAlert = false
    @State var showsInviteInstructions = false
    @State var showsGameNightPendingSheet = false
    @State var showsGameNightHelp = false
    @State var showsHowToPlay = false
    /// Set when the reconnect alert's "Restart as Host" is tapped, so isSessionActive handler
    /// can skip the seating sheet and jump straight to the in-progress match.
    @State var pendingResumeMatchID: UUID? = nil
    @State var pendingResumeGameID: UUID? = nil
    @State var celebrationCoordinator = CelebrationCoordinator()
    @State var commentaryEngine: CommentaryEngine<CommentaryEventKind>? = nil
    @State var isUpdateAvailable = false
    @State var updateBadgeAcknowledged = false
    @Environment(GameNightController.self) var gameNight
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query var settingsModels: [AppSettingsModel]
    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" })
    private var completedMatchesGate: [MatchModel]

    private var hasCompletedMatch: Bool { !completedMatchesGate.isEmpty }
    let showsDebugLayout = AppConfig.DebugLayout.isEnabled
    let logger = AppLogger(category: "ContentView")

    var appSettings: AppSettingsModel? { settingsModels.first }

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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !(appSettings?.helpDismissed ?? false) {
                        Button { showsHowToPlay = true } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel("How to Play")
                    }
                    Menu {
                        if !(appSettings?.helpDismissed ?? false) {
                            Button { showsHowToPlay = true } label: {
                                Label("How to Play", systemImage: "questionmark.circle")
                            }
                            Divider()
                        }
                        if isUpdateAvailable {
                            Button { openAppStore() } label: {
                                Label("Update Available", systemImage: "arrow.down.circle")
                            }
                            Divider()
                        }
                        if hasCompletedMatch {
                            Button { showsHouseRecords = true } label: {
                                Label("House Records", systemImage: "trophy.fill")
                            }
                        }
                        Button { showsPlayers = true } label: {
                            Label("Players", systemImage: "person.2")
                        }
                        Button { showsHistory = true } label: {
                            Label("History", systemImage: "clock")
                        }
                        Divider()
                        gameNightMenuSection
                        Divider()
                        Button { showsSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Button { showsDiceFairness = true } label: {
                            Label("Dice Fairness", systemImage: "die.face.5")
                        }
                        Divider()
                        if appSettings?.helpDismissed ?? false {
                            Button { showsHowToPlay = true } label: {
                                Label("How to Play", systemImage: "questionmark.circle")
                            }
                        }
                        Button { showsAbout = true } label: {
                            Label("About", systemImage: "info.circle")
                        }
                        Button { openSyzygyAppStore() } label: {
                            Label("App Store", systemImage: "storefront.fill")
                        }
                        #if DEBUG
                        if AppConfig.DebugFeel.showFeelBoard {
                            Divider()
                            Button { showsFeelBoard = true } label: {
                                Label("Feel Board", systemImage: "waveform")
                            }
                        }
                        #endif
                    } label: {
                        IconButton(
                            "ellipsis.circle",
                            context: .toolbar,
                            badge: shouldShowUpdateBadge ? 0 : nil,
                            badgeBackground: theme.successColor,
                            badgeOutline: Color.black.opacity(0.8)
                        )
                        .accessibilityLabel(shouldShowUpdateBadge ? "Menu, update available" : "Menu")
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
                        celebrationCoordinator.clearWinnerAnnouncement()
                        startGameNightRematch()
                    }
                    Button("Play Locally", role: .destructive) {
                        model.abandonMatch(in: modelContext)
                        model.resetGame()
                        celebrationCoordinator.clearWinnerAnnouncement()
                    }
                } else {
                    Button("Pause") {
                        // Detach from the current record in memory — it stays in History
                        // as an Unfinished game resumable from the next app launch.
                        model.resetGame()
                        celebrationCoordinator.clearAll()
                        celebrationCoordinator.clearWinnerAnnouncement()
                    }
                    Button("Delete & Start New", role: .destructive) {
                        model.abandonMatch(in: modelContext)
                        model.resetGame()
                        celebrationCoordinator.clearAll()
                        celebrationCoordinator.clearWinnerAnnouncement()
                    }
                }
            } message: {
                Text(gameNight.isSessionActive && gameNight.role == .host
                     ? "Start a new Game Night game with the same players, or reset to a local game."
                     : "Pause saves the game to History so you can resume it later. Delete removes it permanently.")
            }
        }
        .gameNightAlerts(
            session: gameNight.session,
            state: gnAlerts,
            appName: "SyFive",
            appStoreURL: AboutView.appStoreURL,
            onAbandonSession: { gameNight.abandonSession() },
            onGuestReconnect: { gameNight.prepareForGuestReconnect(matchID: $0) },
            hostReconnectIDs: { fetchHostReconnectIDs() },
            onHostReconnect: { matchID, gameID in
                pendingResumeMatchID = matchID
                pendingResumeGameID = gameID
                gameNight.beginHosting(
                    onNeedsConversation: {
                        pendingResumeMatchID = nil
                        pendingResumeGameID = nil
                    },
                    onReadyToSeat: { showsGameNight = true }
                )
            }
        )
        .alert("Reconnect Game Night?", isPresented: $gnAlerts.showsHostReconnect) {
            Button("Resume as Host") {
                gameNight.beginHosting(
                    onNeedsConversation: {
                        pendingResumeMatchID = nil
                        pendingResumeGameID = nil
                    },
                    onReadyToSeat: { showsGameNight = true }
                )
            }
            Button("Play Locally", role: .cancel) {
                pendingResumeMatchID = nil
                pendingResumeGameID = nil
            }
        } message: {
            Text("Your scores are intact. If you were the host, tap Resume as Host — guests will rejoin automatically.")
        }
        .alert("Local Game in Progress", isPresented: $showsGameNightLocalConflictAlert) {
            Button("Play Game Night") { showsGameNight = true }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("Starting Game Night will set aside your current game. You can resume it from History later.")
        }
        .overlay {
            CelebrationView(model: model)
                .ignoresSafeArea()
                .onChange(of: model.rollsRemaining) { oldValue, newValue in
                    if newValue < oldValue {
                        logger.debug(self, "rollsRemaining \(oldValue)→\(newValue): clearing celebration cards")
                        celebrationCoordinator.clearAll()
                    }
                }
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
            #if DEBUG
            runCloudKitSchemaExercise()
            #endif
            loadMatchIfNeeded()
            syncPlayerThemesFromRoster()
            healOrphanedParticipants()
            // Sync initial settings values (onChange won't fire for the first load).
            director.soundMode      = appSettings?.soundMode      ?? .mix
            director.hapticsEnabled = appSettings?.hapticsEnabled ?? true
            // Warm up haptic engine before first roll to avoid first-event latency (§6.2).
            director.warmUpHaptics()
            syncCommentaryEngine()
            gameNight.onCommentarySuppressedChanged = { handleCommentarySuppressionChanged() }
            // Wire score announcement banner for local PvP and GN host paths.
            let coordinator = celebrationCoordinator
            model.onScoreAnnounced = { playerIndex, category, value in
                coordinator.triggerScoreAnnouncement(playerIndex: playerIndex, category: category, value: value)
            }
            model.onUpperBonusEarned = { playerIndex in
                coordinator.triggerUpperBonus(playerIndex: playerIndex)
            }
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
        .onChange(of: gameNight.session.sessionActivationCount) { _, count in
            logger.info(self, "onChange(sessionActivationCount): count=\(count) isSessionActive=\(gameNight.isSessionActive) phase=\(String(describing: gameNight.phase))")
            guard gameNight.isSessionActive else {
                logger.warning(self, "onChange(sessionActivationCount): isSessionActive=false, skipping")
                return
            }
            // Host: restore last session's commentary settings so guests inherit them via the
            // first tableState broadcast. Guests don't touch this block — their settings come
            // from the host via handleTableState / onCommentarySettingsChanged.
            if gameNight.role == .host, let settings = appSettings {
                gameNight.commentaryEnabled    = settings.commentaryMode != .off
                gameNight.commentaryPackID     = settings.commentaryPersonalityID
                gameNight.commentaryLevelRaw   = settings.commentaryLevelRaw
                Task { await gameNight.broadcastTableState() }
            }
            syncCommentaryEngine()
            // D-GNP-036: host-only in practice. Guests have no commentaryEnabled until the
            // host's tableState arrives, so this always skips with "commentary disabled" on
            // guests. The tableState handler is the effective call site for guests. This call
            // is load-bearing for the host (localSharePlayID is guaranteed here at activation).
            gameNight.beginProximityRanging()
            gnAlerts.showsHostReconnect = false
            // Close any open sheets so the seating sheet can present immediately.
            showsHouseRecords = false
            showsHistory = false
            showsPlayers = false
            showsSettings = false
            showsAbout = false
            showsFeelBoard = false
            showsInviteInstructions = false
            gameNight.attach(matchController: model)
            // Wire score announcement banner for GN guest path (opponent scores via matchState diff).
            let announcementCoordinator = celebrationCoordinator
            gameNight.onOpponentScored = { playerIndex, category, value in
                announcementCoordinator.triggerScoreAnnouncement(playerIndex: playerIndex, category: category, value: value)
            }
            gameNight.onUndoApplied = {
                announcementCoordinator.clearScoreAnnouncement()
            }
            gameNight.onCommentarySettingsChanged = {
                syncCommentaryEngine()
            }
            let ctx = modelContext
            gameNight.onMatchStarted = {
                celebrationCoordinator.clearAll()
                celebrationCoordinator.clearWinnerAnnouncement()
            }
            gameNight.onMatchComplete = { completedMatch in
                // Upsert by session UUID so both host and guest end up with one canonical record.
                let matchID = completedMatch.id
                var descriptor = FetchDescriptor<MatchModel>(
                    predicate: #Predicate { $0.id == matchID }
                )
                descriptor.fetchLimit = 1
                if let existing = (try? ctx.fetch(descriptor))?.first {
                    existing.hydrate(from: completedMatch, context: ctx)
                    existing.isGameNight = true
                } else {
                    let newModel = MatchModel()
                    ctx.insert(newModel)
                    newModel.hydrate(from: completedMatch, context: ctx)
                    newModel.isGameNight = true
                }
                try? ctx.save()
            }
            gameNight.onHistoryManifestNeeded = {
                // Only advertise matches where every participant is in the current session.
                // Prevents sending history from games the receiving device never attended.
                let sessionPlayerIDs = Set(gameNight.seats.compactMap { $0.playerID })
                guard !sessionPlayerIDs.isEmpty else { return [] }
                let completed = "completed"
                var descriptor = FetchDescriptor<MatchModel>(
                    predicate: #Predicate { $0.statusRaw == completed },
                    sortBy: [SortDescriptor(\MatchModel.completedAt, order: .reverse)]
                )
                descriptor.fetchLimit = 40
                let all = (try? ctx.fetch(descriptor)) ?? []
                return all.filter { model in
                    guard model.isGameNight else { return false }
                    let pIDs = model.participants.compactMap { $0.playerID }
                    return !pIDs.isEmpty && pIDs.allSatisfy { sessionPlayerIDs.contains($0) }
                }.prefix(20).map { $0.id }
            }
            gameNight.onHistoryMatchesNeeded = { matchIDs in
                matchIDs.compactMap { id in
                    var descriptor = FetchDescriptor<MatchModel>(predicate: #Predicate { $0.id == id })
                    descriptor.fetchLimit = 1
                    return (try? ctx.fetch(descriptor))?.first?.toDomain()
                }
            }
            gameNight.onHistoryMatchesReceived = { matches in
                // Build local player ID set once for the whole batch.
                let localPlayerIDs = Set(
                    ((try? ctx.fetch(FetchDescriptor<PlayerModel>())) ?? []).map { $0.id }
                )
                for match in matches {
                    // Skip if any participant is unknown to this device.
                    let participantIDs = match.participants.compactMap { $0.playerID }
                    guard !participantIDs.isEmpty,
                          participantIDs.allSatisfy({ localPlayerIDs.contains($0) }) else {
                        logger.info(self, "onHistoryMatchesReceived: skipped foreign match id=\(match.id.uuidString.prefix(8))")
                        continue
                    }
                    // Skip if an equivalent record already exists — either by wire UUID (post-fix
                    // records) or by startedAt fingerprint within 20 min (pre-fix auto-UUID records).
                    if GNMatchIdentity.duplicateExists(for: match, in: ctx) {
                        logger.info(self, "onHistoryMatchesReceived: skipped duplicate id=\(match.id.uuidString.prefix(8))")
                        continue
                    }
                    let newModel = MatchModel()
                    ctx.insert(newModel)
                    newModel.hydrate(from: match, context: ctx)
                    newModel.isGameNight = true
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
                upsertGameNightPlayerModels()
            }
            // Re-show the seating sheet when the host calls playAgain().
            if newPhase == .settingTable && gameNight.isSessionActive { showsGameNight = true }
        }
        .onChange(of: model.playerCount) { saveMatch() }
        .onChange(of: model.playerScores) { saveMatch() }
        .onChange(of: appSettings?.soundModeRaw) { _, _ in handleSoundModeChanged() }
        .onChange(of: appSettings?.hapticsEnabled) { _, v in director.hapticsEnabled = v ?? true }
        .onChange(of: appSettings?.commentaryModeRaw)        { _, _ in syncCommentaryEngine() }
        .onChange(of: appSettings?.commentaryLevelRaw)      { _, _ in syncCommentaryEngine() }
        .onChange(of: appSettings?.commentaryPersonalityID) { _, _ in syncCommentaryEngine() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: director.stopAudioForBackground()
            case .active:
                director.handleForeground()
                LegacyYahtzeeRepair.run(in: modelContext)
                LegacyRematchRepair.run(in: modelContext)
            case .inactive: break
            @unknown default: break
            }
        }
        .onChange(of: model.isGameOver) { _, isGameOver in
            guard isGameOver else { return }
            celebrationCoordinator.clearAll()
            celebrationCoordinator.triggerGameOver(winnerIndices: model.winnerIndices)
            if model.playerCount > 1 {
                celebrationCoordinator.triggerWinnerAnnouncement(
                    winnerIndices: model.winnerIndices,
                    score: model.leaderScore ?? 0
                )
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                guard model.isGameOver else { return }
                model.clearUndoSnapshot()
            }
        }
        .sheet(isPresented: $showsHouseRecords) {
            HouseRecordsView()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsHistory) {
            MatchHistoryView(
                activeMatchID: model.persistedMatchID,
                onActiveMatchDeleted: {
                    model.resetGame()
                    celebrationCoordinator.clearWinnerAnnouncement()
                },
                onResume: { matchModel in
                    model.load(from: matchModel)
                    showsHistory = false
                }
            )
            .environment(\.theme, theme)
            .environment(director)
        }
        .sheet(isPresented: $showsPlayers, onDismiss: { syncPlayerThemesFromRoster() }) {
            PlayersView()
                .environment(\.theme, theme)
                .environment(director)
        }
        .sheet(isPresented: $showsSettings, onDismiss: { syncCommentaryEngine() }) {
            SettingsView()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsDiceFairness) {
            NavigationStack {
                DiceFairnessView(accentColor: theme.primaryAccent, appName: "SyFive")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showsDiceFairness = false }
                        }
                    }
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsFeelBoard) {
            FeelBoardView()
                .environment(director)
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsGameNight) {
            TableSettingView(gameNight: gameNight, matchModel: model)
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsInviteInstructions) {
            GameNightInviteInstructions(accentColor: theme.primaryAccent)
        }
        .sheet(isPresented: $showsGameNightPendingSheet) {
            GameNightPendingSheet(accentColor: theme.primaryAccent) {
                gameNight.cancelHostPreparation()
            }
        }
        .sheet(isPresented: $showsGameNightHelp) {
            GameNightHelpSheet(
                context: gameNightHelpContext,
                isEligibleForGroupSession: gameNight.session.isEligibleForGroupSession,
                appName: "SyFive",
                accentColor: theme.primaryAccent
            )
        }
        .sheet(isPresented: $showsHowToPlay) {
            HowToPlayView(settings: appSettings)
                .environment(\.theme, theme)
        }
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

    private func openSyzygyAppStore() {
        guard let url = URL(string: "https://apps.apple.com/us/developer/syzygy-softwerks-llc/id1118759442") else { return }
        openURL(url)
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
