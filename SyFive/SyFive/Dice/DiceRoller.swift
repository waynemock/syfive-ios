import SwiftUI
import RealityKit
import Observation

/// Orchestrates physics dice rolls: spawns dice, applies impulses, detects settle, delivers results.
///
/// Owned by `DiceAreaView` via `@State`. Call `setup(in:)` once from `DiceRKView.make`,
/// then `roll(held:onResults:)` each time the player rolls.
@MainActor
@Observable
final class DiceRoller {

    // MARK: - Config (tunable)

    struct Config {
        // Settle detection
        /// Linear speed below which a die counts as "still" (m/s).
        var settleVThreshold: Float = 0.02
        /// Angular speed below which a die counts as "still" (rad/s).
        var settleWThreshold: Float = 0.15
        /// Consecutive "still" frames required before a die is declared settled.
        var settleFrames: Int = 30
        /// Seconds before a rescue nudge is applied to any unsettled die.
        var rollTimeout: Float = 4.0

        // Launch variation (Phase 3)
        var impulseMin: Float = 0.04
        var impulseMax: Float = 0.11
        var torqueMin: Float  = 0.05
        var torqueMax: Float  = 0.15
        /// Half-angle of the upward cone the impulse direction is sampled from (radians).
        var coneHalfAngle: Float = 0.70
        /// Random XZ offset added to each die's grid spawn position (metres).
        var spawnJitter: Float = 0.012

        /// Faster settle thresholds used during batch rolling to reduce per-roll time.
        static let batch = Config(
            settleVThreshold: 0.08, settleWThreshold: 0.40,
            settleFrames: 8, rollTimeout: 1.5,
            impulseMin: 0.04, impulseMax: 0.11,
            torqueMin: 0.05, torqueMax: 0.15,
            coneHalfAngle: 0.70, spawnJitter: 0.012
        )
    }

    // MARK: - Public state

    var isRolling: Bool = false
    var config = Config()

    /// Accumulated roll statistics — auto-populated after every roll.
    let statistics = DiceStatistics()

    /// True while a batch run is in progress.
    private(set) var isBatchRunning: Bool = false
    private(set) var batchProgress: Int = 0
    private(set) var batchTotal: Int = 0

    /// True when replaying a saved recipe (shown as overlay in debug HUD).
    private(set) var isReplay: Bool = false

    /// The recipe from the most recent roll — use for replay.
    private(set) var lastRecipe: DiceRollRecipe?

    /// Optional audio hook receiver.
    weak var audioController: (any DiceAudioControlling)?

    // MARK: - Private

    private let diceCount = 5
    private var diceEntities: [DiceEntity] = []
    private var settleCounters: [Int] = []
    private var rollTime: Float = 0
    private var currentHeld: [Bool] = []
    private var pendingResults: (([Int]) -> Void)?
    private var sceneSubscription: EventSubscription?
    private var rng = DiceRandSource()

    private var batchRemaining: Int = 0
    private var savedBatchConfig: Config?

    private static let spawnGrid: [SIMD2<Float>] = [
        .init(-0.055, -0.055),
        .init( 0.055, -0.055),
        .init( 0.000,  0.000),
        .init(-0.055,  0.055),
        .init( 0.055,  0.055),
    ]

    // MARK: - Setup

    func setup(in content: inout RealityViewCameraContent, theme: Theme) {
        guard diceEntities.isEmpty else {
            applyTheme(theme)
            return
        }

        for _ in 0..<diceCount {
            let die = DiceEntity(theme: theme)
            die.entity.isEnabled = false
            content.add(die.entity)
            diceEntities.append(die)
            settleCounters.append(0)
        }

        sceneSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] (event: SceneEvents.Update) in
            self?.tick(deltaTime: Float(event.deltaTime))
        }
    }

    func applyTheme(_ theme: Theme) {
        for die in diceEntities {
            die.updateTheme(theme)
        }
    }

    // MARK: - Roll

    /// Launch all non-held dice. `onResults` is called with 5 values once all settle.
    func roll(held: [Bool], onResults: @escaping ([Int]) -> Void) async {
        guard !isRolling, !diceEntities.isEmpty else { return }

        // Capture seed before any RNG calls — allows deterministic replay.
        let rollSeed = rng.currentSeed
        var launchParams: [DiceRollRecipe.DieLaunchParams] = []

        pendingResults = onResults
        currentHeld = held
        isRolling = true
        rollTime = 0
        settleCounters = Array(repeating: 0, count: diceCount)

        for (index, die) in diceEntities.enumerated() {
            let heldFlag = index < held.count ? held[index] : false
            die.isHeld = heldFlag
            die.entity.isEnabled = true

            guard !heldFlag else { continue }

            if index > 0 {
                let delayMs = UInt64.random(in: 10...80)
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }

            let offset = Self.spawnGrid[index % Self.spawnGrid.count]
            let jitter = config.spawnJitter
            let jx = Float.random(in: -jitter...jitter, using: &rng)
            let jz = Float.random(in: -jitter...jitter, using: &rng)
            let jy = Float.random(in: -0.005...0.005,   using: &rng)
            let spawnY: Float = 0.05 + Float(index) * 0.010 + jy
            let spawnPos = SIMD3<Float>(offset.x + jx, spawnY, offset.y + jz)

            let params = die.launch(
                at: spawnPos,
                impulseRange: config.impulseMin...config.impulseMax,
                torqueRange:  config.torqueMin...config.torqueMax,
                coneHalfAngle: config.coneHalfAngle,
                using: &rng
            )
            launchParams.append(params)
            audioController?.onDieLaunched(index: index)
        }

        lastRecipe = DiceRollRecipe(
            seed: rollSeed,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            timestamp: Date(),
            dice: launchParams
        )
    }

    // MARK: - Batch rolling (Phase 4)

    /// Runs `count` back-to-back rolls using fast settle detection.
    /// Results feed into `statistics` only — the game model is not touched.
    /// Each roll still runs full RealityKit physics; expect ~1 second per roll.
    func startBatch(count: Int) {
        guard !isRolling, !isBatchRunning else { return }
        savedBatchConfig = config
        config = .batch
        batchRemaining = count
        batchTotal = count
        batchProgress = 0
        isBatchRunning = true
        triggerNextBatchRoll()
    }

    func stopBatch() {
        isBatchRunning = false
        batchRemaining = 0
        if let saved = savedBatchConfig {
            config = saved
            savedBatchConfig = nil
        }
    }

    private func triggerNextBatchRoll() {
        Task { @MainActor [weak self] in
            guard let self, isBatchRunning, batchRemaining > 0 else {
                self?.stopBatch(); return
            }
            let allFree = Array(repeating: false, count: diceCount)
            await roll(held: allFree) { [weak self] values in
                guard let self else { return }
                statistics.add(values)
                batchProgress += 1
                batchRemaining -= 1
                if isBatchRunning && batchRemaining > 0 {
                    triggerNextBatchRoll()
                } else {
                    stopBatch()
                }
            }
        }
    }

    // MARK: - Replay (Phase 4)

    /// Re-runs the last recorded roll using the same RNG seed → identical physics.
    /// Marks `isReplay = true` during the roll so the debug HUD can show a banner.
    func replayLast(onResults: @escaping ([Int]) -> Void) async {
        guard let recipe = lastRecipe, !isRolling, !isBatchRunning else { return }
        isReplay = true
        let savedRng = rng
        rng = DiceRandSource(seed: recipe.seed)
        let noneHeld = Array(repeating: false, count: diceCount)
        await roll(held: noneHeld) { [weak self] values in
            self?.isReplay = false
            onResults(values)
        }
        // Restore RNG after launches so normal play continues from where it left off.
        rng = savedRng
    }

    // MARK: - Hold management

    func index(of entity: Entity) -> Int? {
        // Walk up the parent chain so tapping a pip child still resolves to the die.
        var current: Entity? = entity
        while let e = current {
            if let idx = diceEntities.firstIndex(where: { $0.entity === e }) {
                return idx
            }
            current = e.parent
        }
        return nil
    }

    func setHeld(_ held: [Bool]) {
        for (index, die) in diceEntities.enumerated() {
            die.isHeld = index < held.count ? held[index] : false
        }
        currentHeld = held
    }

    func clearDice() {
        isRolling = false
        pendingResults = nil
        currentHeld = Array(repeating: false, count: diceCount)
        settleCounters = Array(repeating: 0, count: diceCount)
        rollTime = 0

        for die in diceEntities {
            die.isHeld = false
            die.entity.isEnabled = false
        }
    }

    func restoreDice(values: [Int], held: [Bool]) {
        guard !diceEntities.isEmpty else { return }

        isRolling = false
        pendingResults = nil
        currentHeld = held
        settleCounters = Array(repeating: 0, count: diceCount)
        rollTime = 0

        let presentationY = (DiceEntity.dieSize / 2) + 0.001

        for (index, die) in diceEntities.enumerated() {
            let offset = Self.spawnGrid[index % Self.spawnGrid.count]
            let value = index < values.count ? values[index] : 1
            let isHeld = index < held.count ? held[index] : false
            let position = SIMD3<Float>(offset.x, presentationY, offset.y)
            die.present(value: value, at: position, isHeld: isHeld)
        }
    }

    // MARK: - Per-frame tick

    private func tick(deltaTime: Float) {
        guard isRolling else { return }

        rollTime += deltaTime
        var allSettled = true

        for (index, die) in diceEntities.enumerated() {
            let held = index < currentHeld.count ? currentHeld[index] : false

            if held {
                settleCounters[index] = config.settleFrames
                continue
            }

            let linearOK  = die.linearSpeed  < config.settleVThreshold
            let angularOK = die.angularSpeed < config.settleWThreshold

            if linearOK && angularOK {
                settleCounters[index] += 1
            } else {
                settleCounters[index] = 0
            }

            if settleCounters[index] < config.settleFrames { allSettled = false }
        }

        if rollTime >= config.rollTimeout {
            applyRescueNudges()
            rollTime = 0
        }

        if allSettled { finishRoll() }
    }

    // MARK: - Private helpers

    private func applyRescueNudges() {
        for (index, die) in diceEntities.enumerated() {
            let held = index < currentHeld.count ? currentHeld[index] : false
            guard !held, settleCounters[index] < config.settleFrames else { continue }
            let mag: Float = 0.015
            die.entity.addForce(
                .init(Float.random(in: -mag...mag), mag, Float.random(in: -mag...mag)),
                relativeTo: nil
            )
        }
    }

    private func finishRoll() {
        isRolling = false
        let values = diceEntities.map { $0.topFaceValue }

        // Only feed stats during normal play / batch — not during replay
        // (replay would skew the distribution toward repeated results).
        if !isReplay { statistics.add(values) }

        for (index, value) in values.enumerated() {
            audioController?.onDieSettled(index: index, value: value)
        }
        audioController?.onAllDiceSettled(values: values)

        let callback = pendingResults
        pendingResults = nil
        callback?(values)
    }
}
