import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var model = MatchController()
    @State private var showsResetAlert = false
    @State private var showsHistory = false
    @State private var showsSettings = false
    @State private var showsAbout = false
    @State private var isUpdateAvailable = false
    @State private var updateBadgeAcknowledged = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    private let showsDebugLayout = AppConfig.DebugLayout.isEnabled
    private let logger = AppLogger(category: "ContentView")

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
                        Button {
                            showsHistory = true
                        } label: {
                            Label("History", systemImage: "clock")
                        }
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
        }
        .tint(theme.primaryAccent)
        .environment(\.theme, theme)
        .task {
            isUpdateAvailable = await AppUpdateChecker.shared.isUpdateAvailable()
        }
        .onAppear {
            seedYatzyGameIfNeeded()
            loadMatchIfNeeded()
        }
        .onChange(of: model.playerCount) { saveMatch() }
        .onChange(of: model.playerScores) { saveMatch() }
        .sheet(isPresented: $showsHistory) {
            MatchHistoryView()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsSettings) {
            Text("Settings")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
                .environment(\.theme, theme)
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
