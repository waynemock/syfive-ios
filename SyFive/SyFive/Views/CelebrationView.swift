import SwiftUI

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
struct DiceTrayOverlayView: View {
    @Environment(CelebrationCoordinator.self) private var coordinator
    let model: MatchController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let event = coordinator.yatzyEvent {
                let playerIndex = event.playerIndex
                YatzyOverlayView(
                    theme: Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme),
                    playerName: model.playerDisplayNames.indices.contains(playerIndex)
                        ? model.playerDisplayNames[playerIndex] : "",
                    playerInitials: model.playerInitials(for: playerIndex),
                    playerCount: model.playerDisplayNames.count,
                    reduceMotion: reduceMotion,
                    onDone: { coordinator.clearYatzy() }
                )
                .id(event.id)
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
            }
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Yatzy overlay

private struct YatzyOverlayView: View {
    let theme: Theme
    let playerName: String
    let playerInitials: String
    let playerCount: Int
    let reduceMotion: Bool
    let onDone: () -> Void

    @State private var startDate = Date()
    @State private var motes: [Mote] = []
    @State private var titleOpacity: Double = 0
    @ScaledMetric private var yatzyFontSize: CGFloat = 40
    @ScaledMetric private var bonusFontSize: CGFloat = 24

    var body: some View {
        ZStack {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
                    Canvas { gctx, size in
                        let elapsed = ctx.date.timeIntervalSince(startDate)
                        for m in motes {
                            drawMote(m, in: gctx, size: size, elapsed: elapsed)
                        }
                    }
                }
            }

            VStack(spacing: 4) {
                if playerCount > 1 {
                    HStack(spacing: 6) {
                        PlayerInitialsCircle(initials: playerInitials, themeType: theme.type)
                        Text(playerName)
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(theme.secondaryAccent)
                    }
                }
                Text("YATZY")
                    .font(.system(size: yatzyFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(theme.primaryAccent)
                Text("+50")
                    .font(.system(size: bonusFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.secondaryAccent)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: theme.primaryAccent.opacity(0.3), radius: 20, x: 0, y: 6)
            .opacity(titleOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startDate = Date()
            motes = makeYatzyMotes(theme: theme)
            withAnimation(.easeIn(duration: 0.35).delay(0.2)) { titleOpacity = 1.0 }
        }
        .task {
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 0.0 }
            do { try await Task.sleep(for: .seconds(0.5)) } catch { return }
            onDone()
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
    @State private var opacity: Double = 0

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
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .opacity(opacity)
        .onAppear {
            logger.debug(self, "[\(id8)] appeared player=\(playerName) category=\(categoryName) t=\(ts)")
            withAnimation(.easeIn(duration: 0.25)) { opacity = 1.0 }
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(30.0))
            } catch {
                logger.debug(self, "[\(id8)] task cancelled — view removed externally t=\(ts)")
                return
            }
            logger.debug(self, "[\(id8)] 30s elapsed — starting fadeout t=\(ts)")
            withAnimation(.easeOut(duration: 0.35)) { opacity = 0.0 }
            do {
                try await Task.sleep(for: .seconds(0.4))
            } catch {
                logger.debug(self, "[\(id8)] task cancelled during fadeout t=\(ts)")
                return
            }
            logger.debug(self, "[\(id8)] calling onDone t=\(ts)")
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

#Preview("Yatzy — Midnight") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    let p1 = Player(id: UUID(), name: "Wayne", initials: "WM",
                    themeID: Theme.ThemeType.midnight.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    let p2 = Player(id: UUID(), name: "Sherida", initials: "SM",
                    themeID: Theme.ThemeType.forest.rawValue,
                    createdAt: Date(), isArchived: false, source: .local)
    model.addPlayer(from: p1)
    model.addPlayer(from: p2)
    return ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerYatzy(playerIndex: 0) }
}

#Preview("Game Over — single winner") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    return ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        CelebrationView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerGameOver(winnerIndices: [0]) }
}

#Preview("Game Over — tie (two winners)") {
    let coordinator = CelebrationCoordinator()
    let model = MatchController()
    return ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        CelebrationView(model: model)
    }
    .environment(coordinator)
    .onAppear { coordinator.triggerGameOver(winnerIndices: [0, 1]) }
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
    model.addPlayer(from: mockPlayer)
    model.addPlayer(from: leaderPlayer)
    return ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        DiceTrayOverlayView(model: model)
    }
    .environment(coordinator)
    .onAppear {
        coordinator.triggerScoreAnnouncement(playerIndex: 0, category: .fullHouse, value: 25)
    }
}
