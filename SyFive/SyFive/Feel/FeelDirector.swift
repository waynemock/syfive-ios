import Foundation
import AVFoundation

// Single entry point for all feel events — sound + haptics through one call.
// @Observable so it can ride SwiftUI .environment(_:) injection (house pattern, D-053).
// @MainActor: physics hooks and app events all arrive on main; playback dispatch is
// internal and non-blocking (scheduleBuffer + haptic start are O(µs)).
@MainActor @Observable
final class FeelDirector {

    // Synced from AppSettingsModel by ContentView (§7).
    var soundMode: AppSoundMode = .mix {
        didSet { audio.applyMode(soundMode) }
    }
    var soundEnabled: Bool { soundMode != .off }
    var hapticsEnabled: Bool = true

    private let catalog: FeelCatalog
    private let audio   = FeelAudioEngine()
    private let haptics = FeelHapticEngine()
    private let cache   = SoundCache()

    // Rattle bed: round-robin across the 4 seeds (§5.2)
    private var rattleBedSeedIndex = 0

    init() {
        self.catalog = .syFive
    }

    init(catalog: FeelCatalog) {
        self.catalog = catalog
    }

    // MARK: - Warm-up (call once at app launch; background Task)

    // Renders / loads all buffers from the content-addressed cache, hands them to
    // the audio engine, then sweeps stale cache entries.
    // A roll that races init simply no-ops (§2.2) — human seconds vs. machine ms.
    func warmUp() async {
        var liveKeys = Set<String>()

        // Sound recipes — one buffer per variant
        // Task.yield() between each item keeps the main actor cooperative (AVFoundation APIs
        // that create AVAudioPCMBuffer/AVAudioFile are @MainActor in iOS 18).
        for (_, recipe) in catalog.sounds {
            let variantCount = max(1, recipe.variants.count)
            for vi in 0..<variantCount {
                let key = cache.key(sound: recipe, variantIndex: vi)
                liveKeys.insert(key)
                await Task.yield()
                if let buffer = loadOrRender(recipe: recipe, variantIndex: vi, key: key) {
                    audio.loadBuffer(buffer, forKey: bufferKey(recipe.id, variant: vi))
                }
            }
        }

        // Rattle beds — one buffer per seed
        for (_, recipe) in catalog.rattles {
            for si in recipe.seeds.indices {
                let key = cache.key(rattle: recipe, seedIndex: si)
                liveKeys.insert(key)
                await Task.yield()
                if let buffer = loadOrRender(rattle: recipe, seedIndex: si, key: key) {
                    audio.loadBuffer(buffer, forKey: rattleKey(recipe.id, seed: si))
                }
            }
        }

        // Pre-build haptic players
        haptics.prepare(haptics: catalog.haptics)

        // Sweep cache entries that are no longer live
        cache.sweepStale(liveKeys: liveKeys)
    }

    // Warms up the haptic engine to avoid first-event latency (§6.2).
    func warmUpHaptics() {
        haptics.warmUp()
    }

    func handleForeground() {
        haptics.handleForeground()
    }

    func stopAudioForBackground() {
        audio.stopForBackground()
    }

    // MARK: - Dice events (called via DiceFeelAdapter, §7.1)

    func dieSettled(index: Int) {
        guard soundEnabled  else { return }
        // Variant = die index so each die has its own slightly pitched voice (§5.1)
        playSound(catalog.sounds["settle_thunk"], variantIndex: min(index, 4))
        audio.duckBed()
        if hapticsEnabled { haptics.play(id: "settle_die") }
    }

    func allDiceSettled(values: [Int]) {
        audio.killBed(fadeDurationMs: 80)
    }

    // MARK: - App events (§7.2)

    func rollStarted(unheldCount: Int) {
        guard soundEnabled, unheldCount > 0 else { return }
        let volume = Float(Foundation.sqrt(Double(unheldCount) / 5.0))
        let key = rattleKey("rattle_bed", seed: rattleBedSeedIndex)
        audio.startBed(key: key, volume: volume)
        rattleBedSeedIndex = (rattleBedSeedIndex + 1) % (catalog.rattles["rattle_bed"]?.seeds.count ?? 4)
    }

    func holdToggled(engaged: Bool) {
        let id = engaged ? "hold_engage" : "hold_release"
        if soundEnabled  { playSound(catalog.sounds[id]) }
        if hapticsEnabled { haptics.play(id: id) }
    }

    func dieNudged() {
        if soundEnabled  { playSound(catalog.sounds["die_nudge"]) }
        if hapticsEnabled { haptics.play(id: "die_nudge") }
    }

    func dieRerolled() {
        if soundEnabled  { playSound(catalog.sounds["die_reroll"]) }
        if hapticsEnabled { haptics.play(id: "die_reroll") }
        rollStarted(unheldCount: 1)  // the relaunched die gets a faint bed (§5.4)
    }

    func scoreConfirmed() {
        if soundEnabled  { playSound(catalog.sounds["score_confirm"]) }
        if hapticsEnabled { haptics.play(id: "score_confirm") }
    }

    func yatzyMoment() {
        if soundEnabled  { playSound(catalog.sounds["yatzy_moment"]) }
        if hapticsEnabled { haptics.play(id: "yatzy_moment") }
    }

    func gameEnded() {
        if soundEnabled  { playSound(catalog.sounds["game_end"]) }
        if hapticsEnabled { haptics.play(id: "game_end") }
    }

    func undone() {
        if soundEnabled  { playSound(catalog.sounds["undo"]) }
        if hapticsEnabled { haptics.play(id: "undo") }
    }

    // MARK: - Feel-board audition (bypasses cache; renders in-memory)

    func auditionSound(_ recipe: SoundRecipe, variantIndex: Int = 0) {
        guard soundEnabled else { return }
        guard let buffer = SoundRenderer.render(recipe, variantIndex: variantIndex) else { return }
        audio.playBuffer(buffer)
    }

    func auditionHaptic(_ recipe: HapticRecipe) {
        guard hapticsEnabled else { return }
        haptics.play(recipe: recipe)
    }

    func auditionBoth(sound: SoundRecipe, variantIndex: Int = 0, haptic: HapticRecipe) {
        auditionSound(sound, variantIndex: variantIndex)
        auditionHaptic(haptic)
    }

    var hapticSupported: Bool { haptics.supportsHaptics }

    // MARK: - Private helpers

    private func playSound(_ recipe: SoundRecipe?, variantIndex: Int = 0) {
        guard let recipe else { return }
        let key = bufferKey(recipe.id, variant: variantIndex)
        audio.play(key: key)
    }

    private func bufferKey(_ id: String, variant: Int) -> String {
        "\(id)#\(variant)"
    }

    private func rattleKey(_ id: String, seed: Int) -> String {
        "\(id)@\(seed)"
    }

    private func loadOrRender(recipe: SoundRecipe, variantIndex: Int, key: String) -> AVAudioPCMBuffer? {
        if let hit = cache.load(key: key) { return hit }
        guard let buffer = SoundRenderer.render(recipe, variantIndex: variantIndex) else { return nil }
        cache.store(buffer, key: key)
        return buffer
    }

    private func loadOrRender(rattle recipe: RattleRecipe, seedIndex: Int, key: String) -> AVAudioPCMBuffer? {
        if let hit = cache.load(key: key) { return hit }
        guard let buffer = SoundRenderer.render(recipe, seedIndex: seedIndex) else { return nil }
        cache.store(buffer, key: key)
        return buffer
    }
}
