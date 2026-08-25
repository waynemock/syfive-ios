import SwiftUI
import SwiftData
import SyLibCore

// MARK: - Shared particle type

private struct Mote {
    let x: Double         // 0-1 horizontal origin (normalized to view width)
    let y: Double         // 0-1 vertical origin (normalized to view height)
    let vx: Double        // pts/sec horizontal wander
    let vy: Double        // pts/sec vertical (negative = up, positive = down)
    let color: Color
    let size: Double      // base diameter in pts
    let delay: Double     // seconds before appearing
    let lifetime: Double  // seconds until fully faded
}

// MARK: - Full-screen overlay (game-over only)

/// Full-screen SwiftUI overlay applied to the NavigationStack.
/// Only hosts game-over effects that legitimately fill the screen.
/// Yatzy and score announcements live in DiceTrayOverlayView.
struct CelebrationView: View {
    @Environment(CelebrationCoordinator.self) private var coordinator
    let model: MatchController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if coordinator.isGameOverActive {
            GameOverOverlayView(
                winnerThemes: coordinator.winnerIndices.map {
                    Theme(type: model.themeType(for: $0), colorScheme: colorScheme)
                },
                reduceMotion: reduceMotion,
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .center) {
            // Full-frame particle burst — Yatzy only.
            if let event = coordinator.yatzyEvent {
                YatzyParticleCanvas(
                    theme: Theme(type: model.themeType(for: event.playerIndex), colorScheme: colorScheme),
                    reduceMotion: reduceMotion
                )
                .id(event.id)
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Card stack — cards slide in/out individually; VStack reflows with spring.
            VStack(spacing: 12) {
                if let event = coordinator.yatzyEvent {
                    let playerIndex = event.playerIndex
                    YatzyTextCard(
                        theme: Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
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
                        theme: Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
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
                        playerTheme: Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
                        categoryName: announcement.category.displayName,
                        value: announcement.value,
                        leaderName: leaderNames,
                        leaderInitials: model.playerInitials(for: leaderIdx),
                        leaderTheme: Theme(type: model.themeType(for: leaderIdx), colorScheme: colorScheme),
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
                    let isTied = winner.winnerIndices.count > 1
                    let winners: [(initials: String, themeType: Theme.ThemeType)] = winner.winnerIndices.map {
                        (model.playerInitials(for: $0), model.themeType(for: $0))
                    }
                    let winnerNames = joinedWithAmpersand(winner.winnerIndices
                        .compactMap { model.playerDisplayNames.indices.contains($0) ? model.playerDisplayNames[$0] : nil })
                    let primaryTheme = Theme(type: model.themeType(for: winner.winnerIndices.first ?? 0), colorScheme: colorScheme)
                    WinnerCardView(
                        isTied: isTied,
                        winners: winners,
                        winnerNames: winnerNames,
                        primaryTheme: primaryTheme,
                        score: winner.score
                    )
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

// MARK: - Yatzy particle canvas

private struct YatzyParticleCanvas: View {
    let theme: Theme
    let reduceMotion: Bool

    @State private var startDate = Date()
    @State private var motes: [Mote] = []

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
                Canvas { gctx, size in
                    let elapsed = ctx.date.timeIntervalSince(startDate)
                    for m in motes {
                        drawMote(m, in: gctx, size: size, elapsed: elapsed)
                    }
                }
            }
            .onAppear {
                startDate = Date()
                motes = makeYatzyMotes(theme: theme)
            }
        }
    }

    private func drawMote(_ m: Mote, in ctx: GraphicsContext, size: CGSize, elapsed: Double) {
        let age = elapsed - m.delay
        guard age > 0, age < m.lifetime else { return }
        let progress = age / m.lifetime
        // Fade in quickly (first 15%), fade out over the remainder
        let opacity = min(1.0, max(0.0,
            progress < 0.15 ? progress / 0.15 : 1.0 - (progress - 0.15) / 0.85
        ))
        let scale = 1.0 - progress * 0.55
        let r = (m.size / 2) * scale
        guard opacity > 0.01, r > 0.5 else { return }
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: m.x * size.width  + m.vx * age - r,
                y: m.y * size.height + m.vy * age - r,
                width: r * 2, height: r * 2
            )),
            with: .color(m.color.opacity(opacity))
        )
    }
}

// MARK: - Yatzy text card

private struct YatzyTextCard: View {
    let theme: Theme
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
                    PlayerInitialsCircle(initials: playerInitials, themeType: theme.type)
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
    let theme: Theme
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
                    PlayerInitialsCircle(initials: playerInitials, themeType: theme.type)
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

// MARK: - Winner card

private struct WinnerCardView: View {
    let isTied: Bool
    let winners: [(initials: String, themeType: Theme.ThemeType)]
    let winnerNames: String
    let primaryTheme: Theme
    let score: Int

    @ScaledMetric private var headlineFontSize: CGFloat = 40
    @ScaledMetric private var scoreFontSize: CGFloat = 24
    @Environment(\.colorScheme) private var colorScheme
    @State private var activeThemeIndex = 0

    // Cycles through tied players' themes; falls back to the single winner's theme.
    private var displayTheme: Theme {
        guard isTied, winners.indices.contains(activeThemeIndex) else { return primaryTheme }
        return Theme(type: winners[activeThemeIndex].themeType, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 4) {
            if isTied {
                HStack(spacing: 6) {
                    ForEach(Array(winners.enumerated()), id: \.offset) { _, w in
                        PlayerInitialsCircle(initials: w.initials, themeType: w.themeType)
                    }
                }
                Text(winnerNames)
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(displayTheme.secondaryAccent)
                    .multilineTextAlignment(.center)
            } else if let solo = winners.first {
                HStack(spacing: 6) {
                    PlayerInitialsCircle(initials: solo.initials, themeType: solo.themeType)
                    Text(winnerNames)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(displayTheme.secondaryAccent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Text(isTied ? "IT'S A TIE" : "WINNER")
                .font(.system(size: headlineFontSize, weight: .black, design: .rounded))
                .foregroundStyle(displayTheme.primaryAccent)
            Text("\(score) pts")
                .font(.system(size: scoreFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(displayTheme.secondaryAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(RainbowBorderModifier(cornerRadius: 22))
        .shadow(color: displayTheme.primaryAccent.opacity(0.3), radius: 20, x: 0, y: 6)
        .task {
            guard isTied, winners.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.6)) {
                    activeThemeIndex = (activeThemeIndex + 1) % winners.count
                }
            }
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

    @Environment(\.theme) private var theme

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

// MARK: - Game-over overlay

private struct GameOverOverlayView: View {
    let winnerThemes: [Theme]
    let reduceMotion: Bool
    let onDone: () -> Void

    @State private var startDate = Date()
    @State private var particles: [Mote] = []
    @State private var washOpacity: Double = 0
    @State private var overlayOpacity: Double = 1.0

    var body: some View {
        ZStack {
            LinearGradient(colors: washColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .opacity(washOpacity)

            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
                    Canvas { gctx, size in
                        let elapsed = ctx.date.timeIntervalSince(startDate)
                        for p in particles {
                            drawParticle(p, in: gctx, size: size, elapsed: elapsed)
                        }
                    }
                }
            }
        }
        .opacity(overlayOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            startDate = Date()
            particles = makeFallParticles(winnerThemes: winnerThemes)
            withAnimation(.easeIn(duration: 0.8).delay(0.3)) { washOpacity = 1.0 }
            Task {
                try? await Task.sleep(for: .seconds(4.0))
                withAnimation(.easeOut(duration: 0.5)) { overlayOpacity = 0.0 }
                try? await Task.sleep(for: .seconds(0.5))
                onDone()
            }
        }
    }

    private var washColors: [Color] {
        guard !winnerThemes.isEmpty else {
            return [Color.accentColor.opacity(0.15), Color.clear]
        }
        if winnerThemes.count == 1 {
            let t = winnerThemes[0]
            return [t.primaryAccent.opacity(0.18), t.secondaryAccent.opacity(0.10), Color.clear]
        }
        // Tie: interleave each winner's primary and secondary accent.
        var colors: [Color] = winnerThemes.flatMap { t in
            [t.primaryAccent.opacity(0.15), t.secondaryAccent.opacity(0.08)]
        }
        colors.append(.clear)
        return colors
    }

    private func drawParticle(_ p: Mote, in ctx: GraphicsContext, size: CGSize, elapsed: Double) {
        let age = elapsed - p.delay
        guard age > 0, age < p.lifetime else { return }
        let progress = age / p.lifetime
        // Fade in over first 10%, hold, fade out over last 25%
        let opacity = min(1.0, max(0.0,
            progress < 0.1  ? progress / 0.1 :
            progress > 0.75 ? 1.0 - (progress - 0.75) / 0.25 : 1.0
        ))
        let r = p.size / 2
        guard opacity > 0.01, r > 0.5 else { return }
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: p.x * size.width  + p.vx * age - r,
                y: p.y * size.height + p.vy * age - r,
                width: r * 2, height: r * 2
            )),
            with: .color(p.color.opacity(opacity))
        )
    }
}

// MARK: - Score announcement banner

private struct ScoreAnnouncementBannerView: View {
    let announcementID: UUID
    let playerName: String
    let playerInitials: String
    let playerTheme: Theme
    let categoryName: String
    let value: Int
    let leaderName: String
    let leaderInitials: String
    let leaderTheme: Theme
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
            PlayerInitialsCircle(initials: playerInitials, themeType: playerTheme.type)
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
            PlayerInitialsCircle(initials: leaderInitials, themeType: leaderTheme.type)
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

// MARK: - Helpers

private func joinedWithAmpersand(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    case 2: return "\(names[0]) & \(names[1])"
    default: return names.dropLast().joined(separator: ", ") + " & " + names[names.count - 1]
    }
}

// MARK: - Particle factories

// Approximate normalized positions of 5 dice within the tray view (0-1 relative to tray bounds).
private let dieOrigins: [(x: Double, y: Double)] = [
    (0.28, 0.25), (0.72, 0.20),
    (0.50, 0.45),
    (0.22, 0.70), (0.78, 0.65),
]

private func makeYatzyMotes(theme: Theme) -> [Mote] {
    let count = Int.random(in: 15...25)
    // 2:1 primary-to-secondary ratio keeps the burst cohesive but varied.
    let colors = [theme.primaryAccent, theme.primaryAccent, theme.secondaryAccent]
    return (0..<count).map { i in
        let origin = dieOrigins[i % dieOrigins.count] 
        return Mote(
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

private func makeFallParticles(winnerThemes: [Theme]) -> [Mote] {
    let allColors: [Color] = winnerThemes.isEmpty
        ? [.accentColor]
        : winnerThemes.flatMap { [$0.primaryAccent, $0.primaryAccent, $0.secondaryAccent] }
    return (0..<55).map { i in
        Mote(
            x: Double.random(in: 0.05...0.95),
            y: -0.02,
            vx: Double.random(in: -20...20),
            vy: Double.random(in: 65...115),
            color: allColors[i % allColors.count],
            size: Double.random(in: 4...9),
            delay: Double.random(in: 0.3...2.0),
            lifetime: Double.random(in: 2.5...3.5)
        )
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Yatzy — Single player") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: Theme.ThemeType.midnight.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
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
                            themeID: Theme.ThemeType.midnight.rawValue,
                            createdAt: Date(), isArchived: false, source: .local)
    let leaderPlayer = Player(id: UUID(), name: "Sherida", initials: "SM",
                              themeID: Theme.ThemeType.forest.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: bID, name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
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
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p3 = Player(id: UUID(), name: "Winry Ember", initials: "WE",
                    themeID: Theme.ThemeType.ember.rawValue,
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
