import SwiftUI
import SyLibScoring
import SyLibUI
import SyLibYatzy
import SwiftData
import SyLibCore
import SyLibScoringData

// MARK: - Full-screen overlay (game-over only)

/// Full-screen SwiftUI overlay applied to the NavigationStack.
/// Only hosts game-over effects that legitimately fill the screen.
/// Yatzy and score announcements live in DiceTrayOverlayView.
struct CelebrationView: View {
    @Environment(CelebrationCoordinator.self) private var coordinator
    let model: MatchController
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if coordinator.isGameOverActive {
            GameOverOverlay(
                winnerThemes: coordinator.winnerIndices.map {
                    SyTheme(type: model.themeType(for: $0), colorScheme: colorScheme)
                },
                onDone: { coordinator.clearGameOver() }
            )
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Dice-tray overlay (Yatzy + score announcement)

/// Applied as an overlay directly on the dice tray view so centering is
/// relative to the tray bounds, not the full screen.
///
/// Cards stack in a VStack and animate independently: Yatzy pops in from
/// center and slides up when done; score slides in from below and exits the
/// same way. Both vanish together (spring) when clearAll() is called on roll.
struct DiceTrayOverlayView: View {
    @Environment(CelebrationCoordinator.self) private var coordinator
    let model: MatchController
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .center) {
            // Full-frame particle burst — Yatzy only.
            if let event = coordinator.yatzyEvent {
                let theme = SyTheme(type: model.themeType(for: event.playerIndex), colorScheme: colorScheme)
                // Same motes under Reduce Motion: they are already the calm form (D-073).
                ParticleBurst(particles: { makeYatzyParticles(theme: theme) },
                              reducedMotion: { makeYatzyParticles(theme: theme) })
                .id(event.id)
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Card stack — cards slide in/out individually; VStack reflows with spring.
            VStack(spacing: 12) {
                if let event = coordinator.yatzyEvent {
                    let playerIndex = event.playerIndex
                    YatzyTextCard(
                        theme: SyTheme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
                        playerName: model.playerDisplayNames.indices.contains(playerIndex)
                            ? model.playerDisplayNames[playerIndex] : "",
                        playerInitials: model.playerInitials(for: playerIndex),
                        playerCount: model.playerDisplayNames.count,
                        onDone: { coordinator.clearYatzy() }
                    )
                    .id(event.id)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                if let event = coordinator.upperBonusEvent {
                    let playerIndex = event.playerIndex
                    UpperBonusTextCard(
                        theme: SyTheme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
                        playerName: model.playerDisplayNames.indices.contains(playerIndex)
                            ? model.playerDisplayNames[playerIndex] : "",
                        playerInitials: model.playerInitials(for: playerIndex),
                        playerCount: model.playerDisplayNames.count,
                        onDone: { coordinator.clearUpperBonus() }
                    )
                    .id(event.id)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                if let announcement = coordinator.scoreAnnouncement {
                    let playerIndex = announcement.playerIndex
                    let leaderIdx = model.leaderIndices.first ?? 0
                    let isTied = model.leaderIndices.count > 1
                    let leaderNames = model.leaderIndices
                        .compactMap { model.playerDisplayNames.indices.contains($0) ? model.playerDisplayNames[$0] : nil }
                        .joined(separator: " & ")
                    ScoreAnnouncementBannerView(
                        announcementID: announcement.id,
                        playerName: model.playerDisplayNames.indices.contains(playerIndex)
                            ? model.playerDisplayNames[playerIndex] : "",
                        playerInitials: model.playerInitials(for: playerIndex),
                        playerTheme: SyTheme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
                        categoryName: announcement.category.displayName,
                        value: announcement.value,
                        leaderName: leaderNames,
                        leaderInitials: model.playerInitials(for: leaderIdx),
                        leaderTheme: SyTheme(type: model.themeType(for: leaderIdx), colorScheme: colorScheme),
                        leaderScore: model.leaderScore ?? 0,
                        leaderLabel: isTied ? "Tied" : "Leading",
                        onDone: { coordinator.clearScoreAnnouncementIfCurrent(id: announcement.id) }
                    )
                    .id(announcement.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }

                if let winner = coordinator.winnerAnnouncement {
                    WinnerCard(winners: winner.winnerIndices.map { i in
                                   CelebrationWinner(
                                       name: model.playerDisplayNames.indices.contains(i) ? model.playerDisplayNames[i] : "",
                                       initials: model.playerInitials(for: i),
                                       themeType: model.themeType(for: i)) },
                               scoreText: "\(winner.score) pts")
                    .id(winner.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .task(id: winner.id) {
                        try? await Task.sleep(for: .seconds(30))
                        coordinator.clearWinnerAnnouncement()
                    }

                    if model.playerCount == 2,
                       let aID = model.playerIDs.first.flatMap({ $0 }),
                       let bID = model.playerIDs.last.flatMap({ $0 }) {
                        PostMatchH2HView(
                            playerAID: aID,
                            playerAName: model.playerDisplayNames[0],
                            playerBID: bID,
                            playerBName: model.playerDisplayNames[1]
                        )
                        .id(winner.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 390)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: coordinator.yatzyEvent?.id)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: coordinator.upperBonusEvent?.id)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: coordinator.scoreAnnouncement?.id)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: coordinator.winnerAnnouncement?.id)
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Yatzy text card

private struct YatzyTextCard: View {
    let theme: SyTheme
    let playerName: String
    let playerInitials: String
    let playerCount: Int
    let onDone: () -> Void
    
    @ScaledMetric private var yatzyFontSize: CGFloat = 40
    @ScaledMetric private var bonusFontSize: CGFloat = 24
    
    var body: some View {
        VStack(spacing: 4) {
            if playerCount > 1 {
                HStack(spacing: 6) {
                    InitialsCircle(initials: playerInitials, color: theme.primaryAccent, diameter: 28)
                    Text(playerName)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(theme.secondaryAccent)
                }
                HStack {
                    yatzyInfo
                }
            } else {
                yatzyInfo
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: theme.primaryAccent.opacity(0.3), radius: 20, x: 0, y: 6)
        .task {
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            onDone()
        }
    }
    
    var yatzyInfo: some View {
        Group {
            Text("YATZY")
                .font(.system(size: yatzyFontSize, weight: .black, design: .rounded))
                .foregroundStyle(theme.primaryAccent)
            Text("+50")
                .font(.system(size: bonusFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.secondaryAccent)
        }
    }
}


// MARK: - Upper bonus text card

private struct UpperBonusTextCard: View {
    let theme: SyTheme
    let playerName: String
    let playerInitials: String
    let playerCount: Int
    let onDone: () -> Void

    @ScaledMetric private var bonusFontSize: CGFloat = 36
    @ScaledMetric private var valueFontSize: CGFloat = 24

    var body: some View {
        VStack(spacing: 4) {
            if playerCount > 1 {
                HStack(spacing: 6) {
                    InitialsCircle(initials: playerInitials, color: theme.primaryAccent, diameter: 28)
                    Text(playerName)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(theme.secondaryAccent)
                }
                HStack {
                    bonusInfo
                }
            } else {
                bonusInfo
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: theme.primaryAccent.opacity(0.3), radius: 20, x: 0, y: 6)
        .task {
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            onDone()
        }
    }

    var bonusInfo: some View {
        Group {
            Text("BONUS")
                .font(.system(size: bonusFontSize, weight: .black, design: .rounded))
                .foregroundStyle(theme.primaryAccent)
            Text("+35")
                .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.secondaryAccent)
        }
    }
}

// MARK: - Post-match head-to-head card

private struct PostMatchH2HView: View {
    let playerAID: UUID
    let playerAName: String
    let playerBID: UUID
    let playerBName: String

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedModels: [MatchModel]

    @Environment(\.syTheme) private var theme

    private var hasHistory: Bool {
        let aID = playerAID
        let bID = playerBID
        return completedModels.contains { m in
            let parts = m.participants
            return parts.contains { $0.playerID == aID } && parts.contains { $0.playerID == bID }
        }
    }

    var body: some View {
        if hasHistory {
            HeadToHeadCard(
                playerAID: playerAID,
                playerAName: playerAName,
                playerBID: playerBID,
                playerBName: playerBName,
                showsMeta: false
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: theme.primaryAccent.opacity(0.2), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Score announcement banner

private struct ScoreAnnouncementBannerView: View {
    let announcementID: UUID
    let playerName: String
    let playerInitials: String
    let playerTheme: SyTheme
    let categoryName: String
    let value: Int
    let leaderName: String
    let leaderInitials: String
    let leaderTheme: SyTheme
    let leaderScore: Int
    let leaderLabel: String
    let onDone: () -> Void

    private let logger = AppLogger(category: "ScoreAnnouncement")

    private var id8: String { announcementID.uuidString.prefix(8).description }
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    private var ts: String { Self.timeFormatter.string(from: Date()) }

    var body: some View {
        VStack(spacing: 16) {
            scoreCard
            leaderCard
        }
        .onAppear {
            logger.debug(self, "[\(id8)] appeared player=\(playerName) category=\(categoryName) t=\(ts)")
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(30.0))
            } catch {
                logger.debug(self, "[\(id8)] task cancelled — view removed externally t=\(ts)")
                return
            }
            logger.debug(self, "[\(id8)] 30s elapsed — calling onDone t=\(ts)")
            onDone()
        }
    }

    private var scoreCard: some View {
        HStack(spacing: 10) {
            InitialsCircle(initials: playerInitials, color: playerTheme.primaryAccent, diameter: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(playerName) scored")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(playerTheme.secondaryAccent)
                Text("\(categoryName)  ·  \(value) pts")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "dice.fill")
                .foregroundStyle(playerTheme.primaryAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: playerTheme.primaryAccent.opacity(0.25), radius: 10, x: 0, y: 4)
    }

    private var leaderCard: some View {
        HStack(spacing: 10) {
            InitialsCircle(initials: leaderInitials, color: leaderTheme.primaryAccent, diameter: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(leaderName)
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(leaderTheme.secondaryAccent)
                Text("\(leaderLabel)  ·  \(leaderScore) pts")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "trophy.fill")
                .foregroundStyle(leaderTheme.primaryAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: leaderTheme.primaryAccent.opacity(0.25), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Particle factories

// Approximate normalized positions of 5 dice within the tray view (0-1 relative to tray bounds).
private let dieOrigins: [(x: Double, y: Double)] = [
    (0.28, 0.25), (0.72, 0.20),
    (0.50, 0.45),
    (0.22, 0.70), (0.78, 0.65),
]

private func makeYatzyParticles(theme: SyTheme) -> [Particle] {
    let count = Int.random(in: 15...25)
    // 2:1 primary-to-secondary ratio keeps the burst cohesive but varied.
    let colors = [theme.primaryAccent, theme.primaryAccent, theme.secondaryAccent]
    return (0..<count).map { i in
        let origin = dieOrigins[i % dieOrigins.count] 
        return Particle(
            x: origin.x + Double.random(in: -0.06...0.06),
            y: origin.y + Double.random(in: -0.04...0.04),
            vx: Double.random(in: -20...20),
            vy: Double.random(in: -90...(-45)),
            color: colors[i % colors.count],
            size: Double.random(in: 5...10),
            delay: Double.random(in: 0...0.2),
            lifetime: Double.random(in: 1.0...1.6)
        )
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Yatzy — Single player") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerYatzy(playerIndex: 0) }
}

#Preview("Yatzy — Multiplayer") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: SyTheme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    let _ = model.addPlayer(from: p2)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerYatzy(playerIndex: 0) }
}

#Preview("Upper Bonus — Single player") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerUpperBonus(playerIndex: 0) }
}

#Preview("Upper Bonus — Multiplayer") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: SyTheme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    let _ = model.addPlayer(from: p2)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerUpperBonus(playerIndex: 1) }
}

#Preview("Yatzy + Score") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: SyTheme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    let _ = model.addPlayer(from: p2)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear {
        model.seedScoresForPreview([.ones: 3, .twos: 6, .fullHouse: 25], forPlayerIndex: 1)
        coordinator.triggerYatzy(playerIndex: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            coordinator.triggerScoreAnnouncement(playerIndex: 0, category: .yatzy, value: 50)
        }
    }
}

#Preview("Score Announcement") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let mockPlayer = Player(id: UUID(), name: "Wayne", initials: "WM",
                            themeID: SyTheme.ThemeType.midnight.rawValue,
                            createdAt: Date(), isArchived: false, source: .local)
    let leaderPlayer = Player(id: UUID(), name: "Sherida", initials: "SM",
                              themeID: SyTheme.ThemeType.forest.rawValue,
                              createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: mockPlayer)
    let _ = model.addPlayer(from: leaderPlayer)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear {
        model.seedScoresForPreview([.ones: 3, .twos: 6, .threes: 9], forPlayerIndex: 1)
        coordinator.triggerScoreAnnouncement(playerIndex: 0, category: .fullHouse, value: 25)
    }
}

#Preview("Winner — single") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: SyTheme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    let _ = model.addPlayer(from: p2)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .modelContainer(for: MatchModel.self, inMemory: true)
    .onAppear {
        model.seedScoresForPreview([.ones: 3, .twos: 6, .threes: 9, .fours: 16, .fullHouse: 25], forPlayerIndex: 0)
        coordinator.triggerWinnerAnnouncement(winnerIndices: [0], score: 243)
    }
}

#Preview("Winner — with H2H history") {
    let aID = UUID()
    let bID = UUID()
    let schema = Schema([MatchModel.self, ParticipantModel.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)

    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: aID, name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: bID, name: "Sherida", initials: "SM",
                    themeID: SyTheme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    let _ = model.addPlayer(from: p2)

    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .modelContainer(container)
    .onAppear {
        let ctx = container.mainContext
        func addMatch(winner: UUID, loser: UUID, winnerScore: Int, loserScore: Int, daysAgo: Double) {
            let m = MatchModel()
            m.statusRaw = "completed"
            m.startedAt = Date().addingTimeInterval(-daysAgo * 86_400)
            m.completedAt = m.startedAt.addingTimeInterval(3_600)
            let pA = ParticipantModel(); pA.playerID = winner; pA.finalScore = Decimal(winnerScore); pA.rank = 1; pA.seat = 0
            let pB = ParticipantModel(); pB.playerID = loser;  pB.finalScore = Decimal(loserScore);  pB.rank = 2; pB.seat = 1
            m.participants = [pA, pB]
            ctx.insert(m); ctx.insert(pA); ctx.insert(pB)
        }
        func addTie(score: Int, daysAgo: Double) {
            let m = MatchModel()
            m.statusRaw = "completed"
            m.startedAt = Date().addingTimeInterval(-daysAgo * 86_400)
            m.completedAt = m.startedAt.addingTimeInterval(3_600)
            let pA = ParticipantModel(); pA.playerID = aID; pA.finalScore = Decimal(score); pA.rank = 1; pA.seat = 0
            let pB = ParticipantModel(); pB.playerID = bID; pB.finalScore = Decimal(score); pB.rank = 1; pB.seat = 1
            m.participants = [pA, pB]
            ctx.insert(m); ctx.insert(pA); ctx.insert(pB)
        }
        addMatch(winner: aID, loser: bID, winnerScore: 287, loserScore: 241, daysAgo: 30)
        addMatch(winner: bID, loser: aID, winnerScore: 263, loserScore: 198, daysAgo: 14)
        addTie(score: 259, daysAgo: 7)
        addMatch(winner: aID, loser: bID, winnerScore: 301, loserScore: 278, daysAgo: 3)
        coordinator.triggerWinnerAnnouncement(winnerIndices: [0], score: 301)
    }
}

#Preview("Winner — tie") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: SyTheme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    let _ = model.addPlayer(from: p2)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .modelContainer(for: MatchModel.self, inMemory: true)
    .onAppear {
        coordinator.triggerWinnerAnnouncement(winnerIndices: [0, 1], score: 243)
    }
}

#Preview("Winner — 3-way tie") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: SyTheme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: SyTheme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p3 = Player(id: UUID(), name: "Winry Ember", initials: "WE",
                    themeID: SyTheme.ThemeType.ember.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let _ = model.addPlayer(from: p1)
    let _ = model.addPlayer(from: p2)
    let _ = model.addPlayer(from: p3)
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear {
        coordinator.triggerWinnerAnnouncement(winnerIndices: [0, 1, 2], score: 243)
    }
}

#Preview("Game Over — single winner") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        CelebrationView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerGameOver(winnerIndices: [0]) }
}

#Preview("Game Over — tie (two winners)") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        CelebrationView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerGameOver(winnerIndices: [0, 1]) }
}

#endif
