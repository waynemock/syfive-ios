import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @State private var model = MatchController()
    @State private var director = FeelDirector(catalog: .syFive)
    @State private var showsResetAlert = false
    @State private var showsHistory = false
    @State private var showsSettings = false
    @State private var showsAbout = false
    @State private var showsFeelBoard = false
    @State private var showsGameNight = false
    @State private var showsSessionEndedAlert = false
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
    private let showsDebugLayout = AppConfig.DebugLayout.isEnabled
    private let logger = AppLogger(category: "ContentView")

    private var appSettings: AppSettingsModel? { settingsModels.first }

    var body: some View {
        let theme = Theme(type: model.themeType(for: model.currentPlayerIndex), colorScheme: colorScheme)
        NavigationStack {
            GeometryReader { proxy in
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if model.hasStarted && !model.isGameOver {
                            showsResetAlert = true
                        } else {
                            model.abandonMatch(in: modelContext)
                            model.resetGame()
                        }
                    } label: {
                        Image(systemName: model.hasStarted && !model.isGameOver ? "arrow.clockwise" : "plus")
                    }
                    .accessibilityLabel("New Game")
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
                        Button {
                            showsHistory = true
                        } label: {
                            Label("History", systemImage: "clock")
                        }
                        Divider()
                        Button {
                            Task {
                                do {
                                    try await gameNight.startAsHost()
                                    showsGameNight = true
                                } catch {
                                    logger.error(self, "startAsHost failed: \(error)")
                                }
                            }
                        } label: {
                            Label("Game Night", systemImage: "person.3.fill")
                        }
                        gameNightMenuItems
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
                Button("Start Over", role: .destructive) {
                    model.abandonMatch(in: modelContext)
                    model.resetGame()
                }
            } message: {
                Text("This will reset the current game and scores.")
            }
            .alert("Game Night ended", isPresented: $showsSessionEndedAlert) {
                Button("OK") { gameNight.clearSessionEndedFlag() }
            } message: {
                Text("Your progress has been saved. Start a new Game Night session to continue.")
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
            gameNight.startListeningForSessions()
            // Sync initial settings values (onChange won't fire for the first load).
            director.soundEnabled   = appSettings?.soundEnabled   ?? true
            director.hapticsEnabled = appSettings?.hapticsEnabled ?? true
            // Warm up haptic engine before first roll to avoid first-event latency (§6.2).
            director.warmUpHaptics()
            syncCommentaryEngine()
        }
        .onChange(of: gameNight.isSessionActive) { _, active in
            syncCommentaryEngine()  // gate / restore on every session transition
            if active {
                showsGameNight = true
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
            }
        }
        .onChange(of: gameNight.phase) { _, newPhase in
            if newPhase == .inProgress { showsGameNight = false }
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
        .sheet(isPresented: $showsHistory) {
            MatchHistoryView()
                .environment(\.theme, theme)
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
        .sheet(isPresented: $showsGameNight, onDismiss: {
            if !gameNight.isSessionActive { return }
        }) {
            TableSettingView(gameNight: gameNight)
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
        let voiceID = UserDefaults.standard.string(forKey: "commentaryVoiceID")
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
    }

    private func saveMatch() {
        guard model.playerCount > 0 else { return }
        let gameDescriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == "yatzy" }
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
        let descriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == "yatzy" }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        let game = GameModel()
        game.name = "Yatzy"
        game.scoringSystemID = "yatzy"
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

    @ViewBuilder
    private var gameNightMenuItems: some View {
        if gameNight.isSessionActive && gameNight.role == .host {
            if gameNight.phase == .inProgress {
                Button(role: .destructive) {
                    gameNight.abandonSession()
                } label: {
                    Label("End Game Night", systemImage: "xmark.circle")
                }
            }
            if gameNight.phase == .completed {
                Button {
                    model.abandonMatch(in: modelContext)
                    model.resetGame()
                    gameNight.playAgain()
                } label: {
                    Label("Play Again", systemImage: "arrow.clockwise.circle")
                }
            }
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
    ContentView()
}
