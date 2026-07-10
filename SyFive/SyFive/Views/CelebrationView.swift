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

// MARK: - Main overlay

/// Full-screen SwiftUI particle overlay for Yatzy and game-over moments.
/// Hit-testing is disabled — all taps pass through to the content below.
struct CelebrationView: View {
    @Environment(CelebrationCoordinator.self) private var coordinator
    let model: MatchController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let event = coordinator.yatzyEvent {
                YatzyOverlayView(
                    theme: Theme(type: model.themeType(for: event.playerIndex), colorScheme: colorScheme),
                    reduceMotion: reduceMotion,
                    onDone: { coordinator.clearYatzy() }
                )
                // Fresh view identity per event — no accumulation across rapid Yatzys (§2.4).
                .id(event.id)
            }

            if coordinator.isGameOverActive {
                GameOverOverlayView(
                    winnerThemes: coordinator.winnerIndices.map {
                        Theme(type: model.themeType(for: $0), colorScheme: colorScheme)
                    },
                    reduceMotion: reduceMotion,
                    onDone: { coordinator.clearGameOver() }
                )
            }
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Yatzy overlay

private struct YatzyOverlayView: View {
    let theme: Theme
    let reduceMotion: Bool
    let onDone: () -> Void

    @State private var startDate = Date()
    @State private var motes: [Mote] = []
    @State private var titleOpacity: Double = 0

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
                Text("YATZY")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(theme.primaryAccent)
                Text("+50")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
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
            Task {
                try? await Task.sleep(for: .seconds(1.3))
                withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 0.0 }
                try? await Task.sleep(for: .seconds(0.5))
                onDone()
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

// MARK: - Particle factories

// Approximate normalized positions of 5 dice in the tray.
// The tray occupies the top ~42% of the full-screen overlay in portrait.
private let dieOrigins: [(x: Double, y: Double)] = [
    (0.28, 0.14), (0.72, 0.11),
    (0.50, 0.24),
    (0.22, 0.36), (0.78, 0.33),
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
    return ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
        CelebrationView(model: model)
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
