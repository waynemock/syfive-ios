import Foundation
import CoreHaptics
import SyLibCore

// CoreHaptics wrapper. Pre-builds CHHapticPatternPlayers at prepare() time so
// firing is O(µs). Non-Taptic hardware (iPad) no-ops via the capability gate.
final class FeelHapticEngine {

    let supportsHaptics: Bool
    private var engine: CHHapticEngine?
    private var players: [String: CHHapticPatternPlayer] = [:]
    private let logger = AppLogger(category: "FeelHapticEngine")

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: - Lifecycle

    // Call on match-view appear to warm up the engine before the first roll (§6.2).
    func warmUp() {
        guard supportsHaptics, engine == nil else { return }
        startEngine()
    }

    func handleForeground() {
        guard supportsHaptics else { return }
        if engine == nil { startEngine() }
        else { try? engine?.start() }
    }

    // MARK: - Prepare from catalog

    func prepare(haptics: [String: HapticRecipe]) {
        guard supportsHaptics else { return }
        if engine == nil { startEngine() }
        guard let engine else { return }
        for (_, recipe) in haptics {
            buildPlayer(for: recipe, engine: engine)
        }
    }

    // MARK: - Playback

    func play(id: String) {
        guard supportsHaptics, let player = players[id] else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    // Bypass the pre-built player — renders directly from a recipe (for feel-board audition).
    func play(recipe: HapticRecipe) {
        guard supportsHaptics, let engine else { return }
        let events = recipe.events.compactMap { makeEvent($0) }
        guard !events.isEmpty,
              let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    // MARK: - Private

    private func startEngine() {
        do {
            let eng = try CHHapticEngine()
            eng.resetHandler = { [weak self] in self?.handleReset() }
            eng.stoppedHandler = { [weak self] reason in
                guard let self else { return }
                self.logger.debug(self, "stopped: \(reason)")
            }
            try eng.start()
            engine = eng
        } catch {
            logger.warning(self, "start failed: \(error)")
        }
    }

    private func handleReset() {
        players.removeAll()
        try? engine?.start()
        logger.debug(self, "engine reset — players cleared, will rebuild on next prepare()")
    }

    private func buildPlayer(for recipe: HapticRecipe, engine: CHHapticEngine) {
        let events = recipe.events.compactMap { makeEvent($0) }
        guard !events.isEmpty else { return }
        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        players[recipe.id] = player
    }

    private func makeEvent(_ event: HapticRecipe.HEvent) -> CHHapticEvent? {
        let t = event.timeMs / 1_000.0
        let params: [CHHapticEventParameter] = [
            .init(parameterID: .hapticIntensity, value: Float(event.intensity)),
            .init(parameterID: .hapticSharpness, value: Float(event.sharpness)),
        ]
        switch event.kind {
        case .transient:
            return CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: t)
        case .continuous:
            let dur = (event.durationMs ?? 100.0) / 1_000.0
            return CHHapticEvent(eventType: .hapticContinuous, parameters: params,
                                 relativeTime: t, duration: dur)
        }
    }
}
