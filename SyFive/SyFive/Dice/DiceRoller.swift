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
    private let logger = AppLogger(category: "DiceRoller")

    // MARK: - Config (tunable)

    struct Config {
        // Settle detection
        var settleVThreshold: Float = 0.02
        var settleWThreshold: Float = 0.15
        var settleFlatnessThreshold: Float = 0.96
        var settleHeightTolerance: Float = 0.008
        var settleFrames: Int = 30
        var rollTimeout: Float = 2.5

        // Launch variation
        var impulseMin: Float = 0.08
        var impulseMax: Float = 0.18
        var torqueMin: Float  = 0.05
        var torqueMax: Float  = 0.15
        var coneHalfAngle: Float = 0.70
        var spawnJitter: Float = 0.012
        /// Each die draws an independent random spawn height from this range each roll.
        /// Max is capped so the top of the die (center + 21mm) stays below the 240mm ceiling.
        var spawnYMin: Float = 0.084 // 2× die size (42mm)
        var spawnYMax: Float = 0.19

        // Settle assistance — replaces active rescue interventions
        /// Seconds a still-and-stacked die must wait before the hop rescue fires.
        var stackedRescueDelay: Float = 0.15
        /// Seconds a still-and-wall-blocked die is allowed before being marked stuck.
        var wallStuckSeconds: Float = 2.0
        /// Seconds a floor-stuck die is allowed before being marked stuck as a last resort.
        /// Catches stable box-edge equilibria that no angular kick can overcome.
        var floorStuckSeconds: Float = 6.0
        /// Base downward force (N) per frame applied to a still-but-tilted die in open space.
        var gravityBoostBase: Float = 0.05
        /// Log-curve rate for gravity boost — higher values ramp faster.
        var gravityBoostRate: Float = 5.0

        static let batch = Config(
            settleVThreshold: 0.08, settleWThreshold: 0.40, settleFlatnessThreshold: 0.94,
            settleHeightTolerance: 0.010, settleFrames: 8, rollTimeout: 1.5,
            impulseMin: 0.04, impulseMax: 0.11,
            torqueMin: 0.05, torqueMax: 0.15,
            coneHalfAngle: 0.70, spawnJitter: 0.012,
            spawnYMin: 0.05, spawnYMax: 0.09,
            stackedRescueDelay: 0.05, wallStuckSeconds: 0.8,
            floorStuckSeconds: 3.0,
            gravityBoostBase: 0.05, gravityBoostRate: 8.0
        )
    }

    // MARK: - Public state

    var isRolling: Bool = false
    var config = Config()
    private(set) var stuckDieIndices: Set<Int> = []
    private(set) var nudgeableDieIndices: Set<Int> = []

    var hasStuckDice: Bool { !stuckDieIndices.isEmpty || !nudgeableDieIndices.isEmpty }

    var stuckDiceMessage: String? {
        guard hasStuckDice else { return nil }
        if stuckDieIndices.isEmpty {
            let noun = nudgeableDieIndices.count == 1 ? "die" : "dice"
            return "Tap highlighted \(noun) to nudge"
        }
        if nudgeableDieIndices.isEmpty {
            let noun = stuckDieIndices.count == 1 ? "die" : "dice"
            return "Tap highlighted \(noun) to reroll"
        }
        return "Tap highlighted dice to nudge or reroll"
    }

    /// Accumulated roll statistics — auto-populated after every roll.
    let statistics = DiceStatistics()

    /// True while a batch run is in progress.
    private(set) var isBatchRunning: Bool = false
    private(set) var batchProgress: Int = 0
    private(set) var batchTotal: Int = 0
    var batchHoldModeEnabled: Bool = false

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
    private var stillUnsettledTime: [Float] = []
    private var escapeRecoveryCounters: [Int] = []
    private var currentRollRescueKinds: [Set<String>] = []
    private var currentRollEscapeRecovered: [Bool] = []
    private var currentRollStuckReroll: [Bool] = []
    private var currentRollStuckNudge: [Bool] = []
    private var currentRollStuckReason: [String] = []
    private var currentRollFinalAlign: [Float] = []
    private var currentRollUnsettledSecs: [Float] = []
    private var currentRollFinalX: [Float] = []
    private var currentRollFinalZ: [Float] = []
    private var currentRollFinalHeight: [Float] = []
    private var currentRollSpawnPos: [SIMD3<Float>] = []
    /// Fixed tipping axis per die — set once when a floor-only stuck episode begins,
    /// reused every frame so the nudge direction stays consistent and can't oscillate.
    private var flattenNudgeAxes: [SIMD3<Float>?] = []
    /// Seconds the die has been continuously floor-only and tilted — does NOT reset when
    /// the die moves from the nudge itself (unlike stillUnsettledTime). Used to gate the
    /// position-shift intervention that bypasses friction-constraint rejection.
    private var floorStuckTime: [Float] = []
    /// True for each die index if a player nudge was attempted this roll episode.
    /// Persists across the nudge re-roll so a second stuck event routes to red (reroll).
    private var dieNudgeAttempted: [Bool] = Array(repeating: false, count: 5)
    private var rollTime: Float = 0
    private var currentHeld: [Bool] = []
    private var pendingResults: (([Int]) -> Void)?
    private var sceneSubscription: EventSubscription?
    private var rng = DiceRandSource()
    private var activeRollingIndices: Set<Int> = []
    private var pendingLaunchIndices: Set<Int> = []

    private var batchRemaining: Int = 0
    private var savedBatchConfig: Config?
    private var activeRollNumber: Int = 0
    private var lastStuckLogBucket: Int = -1
    private var batchHeldIndices: Set<Int> = []
    private var batchNeedsFreeRollAfterReset: Bool = false
    private static let maxEscapeRecoveriesPerDie = 1

    private static let spawnGrid: [SIMD2<Float>] = [
        .init(-0.055, -0.055),
        .init( 0.055, -0.055),
        .init( 0.000,  0.000),
        .init(-0.055,  0.055),
        .init( 0.055,  0.055),
    ]

    private static let heldDiceWallInset: Float = 0.0
    private static let heldDiceVisualGap: Float = 0.001
    private static let expectedSettledCenterHeight: Float = DiceEntity.dieSize / 2
    private static let wallRescueInset: Float = 0.006
    private static let outOfBoundsHorizontalLimit: Float = DiceTrayEntity.halfSize * 2.5
    private static let outOfBoundsLowerY: Float = -0.10
    private static let outOfBoundsUpperY: Float = DiceTrayEntity.collisionWallHeight + 0.20

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
            stillUnsettledTime.append(0)
            escapeRecoveryCounters.append(0)
            currentRollRescueKinds.append([])
            currentRollEscapeRecovered.append(false)
            currentRollStuckReroll.append(false)
            currentRollStuckNudge.append(false)
            currentRollStuckReason.append("")
            currentRollFinalAlign.append(0)
            currentRollUnsettledSecs.append(0)
            currentRollFinalX.append(0)
            currentRollFinalZ.append(0)
            currentRollFinalHeight.append(0)
            currentRollSpawnPos.append(.zero)
            flattenNudgeAxes.append(nil)
            floorStuckTime.append(0)
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

    func isStuckDie(index: Int) -> Bool {
        stuckDieIndices.contains(index) || nudgeableDieIndices.contains(index)
    }

    func isNudgeableDie(index: Int) -> Bool {
        nudgeableDieIndices.contains(index)
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
        activeRollNumber = statistics.totalRolls + 1
        lastStuckLogBucket = -1
        settleCounters = Array(repeating: 0, count: diceCount)
        stillUnsettledTime = Array(repeating: 0, count: diceCount)
        escapeRecoveryCounters = Array(repeating: 0, count: diceCount)
        currentRollRescueKinds = Array(repeating: [], count: diceCount)
        currentRollEscapeRecovered = Array(repeating: false, count: diceCount)
        currentRollStuckReroll = Array(repeating: false, count: diceCount)
        currentRollStuckNudge = Array(repeating: false, count: diceCount)
        currentRollStuckReason = Array(repeating: "", count: diceCount)
        currentRollFinalAlign = Array(repeating: 0, count: diceCount)
        currentRollUnsettledSecs = Array(repeating: 0, count: diceCount)
        currentRollFinalX = Array(repeating: 0, count: diceCount)
        currentRollFinalZ = Array(repeating: 0, count: diceCount)
        currentRollFinalHeight = Array(repeating: 0, count: diceCount)
        currentRollSpawnPos = Array(repeating: .zero, count: diceCount)
        flattenNudgeAxes = Array(repeating: nil, count: diceCount)
        floorStuckTime = Array(repeating: 0, count: diceCount)
        activeRollingIndices = []
        pendingLaunchIndices = []
        stuckDieIndices = []
        nudgeableDieIndices = []
        dieNudgeAttempted = Array(repeating: false, count: diceCount)

        logDiagnostics("Starting roll \(activeRollNumber) seed=\(rollSeed) held=\(held)")

        arrangeHeldDice(for: held)

        for (index, die) in diceEntities.enumerated() {
            let heldFlag = index < held.count ? held[index] : false
            die.isHeld = heldFlag
            die.isStuck = false
            die.isNudgeable = false
            die.entity.isEnabled = true

            guard !heldFlag else { continue }
            pendingLaunchIndices.insert(index)

            let params = await launchDie(at: index)
            pendingLaunchIndices.remove(index)
            activeRollingIndices.insert(index)
            launchParams.append(params)
            audioController?.onDieLaunched(index: index)
        }

        logDiagnostics("Launched roll \(activeRollNumber) params=\(launchParams.count)")

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
        let heldPattern = nextBatchHeldPattern()

        savedBatchConfig = config
        config = .batch
        batchRemaining = count
        batchTotal = count
        batchProgress = 0
        isBatchRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        prepareBatchDiceIfNeeded(for: heldPattern)
        triggerNextBatchRoll()
    }

    func stopBatch() {
        isBatchRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        batchRemaining = 0
        batchHeldIndices = []
        batchNeedsFreeRollAfterReset = false
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
            let heldPattern = nextBatchHeldPattern()
            prepareBatchDiceIfNeeded(for: heldPattern)
            await roll(held: heldPattern) { [weak self] values in
                guard let self else { return }
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

    func rerollStuckDie(at index: Int) async {
        guard stuckDieIndices.contains(index), !isRolling, diceEntities.indices.contains(index) else { return }
        stuckDieIndices.remove(index)
        dieNudgeAttempted[index] = false  // fresh launch — reset so next stuck event starts yellow again
        activeRollingIndices = [index]
        settleCounters[index] = 0
        stillUnsettledTime[index] = 0
        rollTime = 0
        isRolling = true
        lastStuckLogBucket = -1
        currentHeld[index] = false
        currentRollStuckReroll[index] = true

        let die = diceEntities[index]
        die.isHeld = false
        die.isStuck = false
        die.isNudgeable = false
        die.entity.isEnabled = true

        logDiagnostics("Rerolling stuck die \(index) on roll \(activeRollNumber)")
        _ = await launchDie(at: index)
        audioController?.onDieLaunched(index: index)
    }

    /// Apply a downward press + random angular kick to a yellow (nudgeable) die, then re-enter active rolling.
    /// If the die settles flat it counts normally; if stuck again it turns red for reroll.
    func nudgeStuckDie(at index: Int) {
        guard nudgeableDieIndices.contains(index), diceEntities.indices.contains(index) else { return }

        dieNudgeAttempted[index] = true
        currentRollStuckNudge[index] = true
        nudgeableDieIndices.remove(index)

        let die = diceEntities[index]
        die.isNudgeable = false

        // Restore dynamic physics so the nudge forces take effect.
        if var body = die.entity.components[PhysicsBodyComponent.self] {
            body.mode = .dynamic
            die.entity.components.set(body)
        }

        // Downward press to force the die against the floor, plus a random horizontal spin
        // to break the stable equilibrium without relaunching from scratch.
        let kickAngle = Float.random(in: 0..<(2 * .pi), using: &rng)
        let kickMagnitude: Float = 5.0
        var motion = PhysicsMotionComponent()
        motion.linearVelocity = .init(0, -0.4, 0)
        motion.angularVelocity = .init(kickMagnitude * cos(kickAngle), 0, kickMagnitude * sin(kickAngle))
        die.entity.components.set(motion)

        // Re-enter the active rolling loop.
        activeRollingIndices.insert(index)
        isRolling = true
        rollTime = 0
        settleCounters[index] = 0
        stillUnsettledTime[index] = 0
        floorStuckTime[index] = 0
        flattenNudgeAxes[index] = nil
        lastStuckLogBucket = -1

        logDiagnostics("Nudged die \(index) on roll \(activeRollNumber) kickAngle=\(String(format: "%.2f", kickAngle))")
    }

    private func arrangeHeldDice(for held: [Bool]) {
        let heldIndices = diceEntities.indices.filter { index in
            index < held.count && held[index]
        }

        guard !heldIndices.isEmpty else { return }

        let sortedHeldIndices = heldIndices.sorted { lhs, rhs in
            let lhsValue = diceEntities[lhs].topFaceValue
            let rhsValue = diceEntities[rhs].topFaceValue
            if lhsValue == rhsValue {
                return lhs < rhs
            }
            return lhsValue < rhsValue
        }

        let dieSize = DiceEntity.dieSize
        let halfSize = DiceTrayEntity.halfSize
        let yPosition = (dieSize / 2) + 0.001
        let startX = -halfSize + Self.heldDiceWallInset + (dieSize / 2)
        let zPosition = -halfSize + Self.heldDiceWallInset + dieSize

        for (rowIndex, dieIndex) in sortedHeldIndices.enumerated() {
            let xPosition = startX + (Float(rowIndex) * (dieSize + Self.heldDiceVisualGap))
            let die = diceEntities[dieIndex]
            die.present(
                value: die.topFaceValue,
                at: SIMD3<Float>(xPosition, yPosition, zPosition),
                isHeld: true
            )
        }
    }

    func clearDice() {
        isRolling = false
        pendingResults = nil
        currentHeld = Array(repeating: false, count: diceCount)
        settleCounters = Array(repeating: 0, count: diceCount)
        stillUnsettledTime = Array(repeating: 0, count: diceCount)
        escapeRecoveryCounters = Array(repeating: 0, count: diceCount)
        currentRollRescueKinds = Array(repeating: [], count: diceCount)
        currentRollEscapeRecovered = Array(repeating: false, count: diceCount)
        currentRollStuckReroll = Array(repeating: false, count: diceCount)
        currentRollStuckNudge = Array(repeating: false, count: diceCount)
        currentRollStuckReason = Array(repeating: "", count: diceCount)
        currentRollFinalAlign = Array(repeating: 0, count: diceCount)
        currentRollUnsettledSecs = Array(repeating: 0, count: diceCount)
        currentRollFinalX = Array(repeating: 0, count: diceCount)
        currentRollFinalZ = Array(repeating: 0, count: diceCount)
        currentRollFinalHeight = Array(repeating: 0, count: diceCount)
        currentRollSpawnPos = Array(repeating: .zero, count: diceCount)
        flattenNudgeAxes = Array(repeating: nil, count: diceCount)
        floorStuckTime = Array(repeating: 0, count: diceCount)
        activeRollingIndices = []
        pendingLaunchIndices = []
        stuckDieIndices = []
        nudgeableDieIndices = []
        dieNudgeAttempted = Array(repeating: false, count: diceCount)
        rollTime = 0
        activeRollNumber = 0
        lastStuckLogBucket = -1

        for die in diceEntities {
            die.isHeld = false
            die.isStuck = false
            die.isNudgeable = false
            die.entity.isEnabled = false
        }
    }

    func restoreDice(values: [Int], held: [Bool]) {
        guard !diceEntities.isEmpty else { return }

        isRolling = false
        pendingResults = nil
        currentHeld = held
        settleCounters = Array(repeating: 0, count: diceCount)
        stillUnsettledTime = Array(repeating: 0, count: diceCount)
        escapeRecoveryCounters = Array(repeating: 0, count: diceCount)
        currentRollRescueKinds = Array(repeating: [], count: diceCount)
        currentRollEscapeRecovered = Array(repeating: false, count: diceCount)
        currentRollStuckReroll = Array(repeating: false, count: diceCount)
        currentRollStuckNudge = Array(repeating: false, count: diceCount)
        currentRollStuckReason = Array(repeating: "", count: diceCount)
        currentRollFinalAlign = Array(repeating: 0, count: diceCount)
        currentRollUnsettledSecs = Array(repeating: 0, count: diceCount)
        currentRollFinalX = Array(repeating: 0, count: diceCount)
        currentRollFinalZ = Array(repeating: 0, count: diceCount)
        currentRollFinalHeight = Array(repeating: 0, count: diceCount)
        currentRollSpawnPos = Array(repeating: .zero, count: diceCount)
        flattenNudgeAxes = Array(repeating: nil, count: diceCount)
        floorStuckTime = Array(repeating: 0, count: diceCount)
        activeRollingIndices = []
        pendingLaunchIndices = []
        stuckDieIndices = []
        rollTime = 0
        activeRollNumber = 0
        lastStuckLogBucket = -1

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
        logStuckRollSnapshotIfNeeded()
        var allSettled = true

        for (index, die) in diceEntities.enumerated() {
            let held = index < currentHeld.count ? currentHeld[index] : false

            if held {
                settleCounters[index] = config.settleFrames
                stillUnsettledTime[index] = 0
                continue
            }

            if pendingLaunchIndices.contains(index) {
                allSettled = false
                continue
            }

            if sanitizeDieTransformIfNeeded(at: index) {
                allSettled = false
                continue
            }

            if !activeRollingIndices.contains(index) {
                settleCounters[index] = config.settleFrames
                stillUnsettledTime[index] = 0
                continue
            }

            let linearOK  = die.linearSpeed  < config.settleVThreshold
            let angularOK = die.angularSpeed < config.settleWThreshold
            let flatOK = die.topFaceAlignment >= config.settleFlatnessThreshold
            let heightOK = abs(die.centerHeightAboveTrayFloor - Self.expectedSettledCenterHeight) <= config.settleHeightTolerance
            let isStill = linearOK && angularOK

            if isStill && flatOK && heightOK {
                settleCounters[index] += 1
                stillUnsettledTime[index] = 0
                flattenNudgeAxes[index] = nil
                floorStuckTime[index] = 0
            } else if isStill {
                settleCounters[index] = 0
                stillUnsettledTime[index] += deltaTime
                applySettleAssistance(for: index, die: die)
            } else {
                settleCounters[index] = 0
                stillUnsettledTime[index] = 0
            }

            // Floor-flattening: three-stage approach for die stuck tilted on the open floor.
            // 1) Angular nudge (w<1.0, fst<2s): gentle rocking toward flat.
            // 2) One-shot angular velocity kick at fst=2s: sets ω directly, bypassing the
            //    friction equilibrium. Helps shallower tilts (align≥0.90). For deep box-edge
            //    equilibria the kick is largely absorbed by friction (PhysX edge-contact).
            // 3) fst timeout: if the die is still stuck at floorStuckSeconds, markDieStuck.
            //    This is the reliable backstop — physics alone can't break some equilibria.
            // The tilt axis is stored once and preserved across motion episodes so the
            // nudge direction stays fixed and can't oscillate.
            if activeRollingIndices.contains(index), !flatOK,
               !isLikelyBlockedByWall(die), supportingDieIndex(for: index) == nil {
                floorStuckTime[index] += deltaTime
                if flattenNudgeAxes[index] == nil {
                    if let axis = die.flatteningAxis(using: &rng) {
                        flattenNudgeAxes[index] = axis
                        logDiagnostics("d\(index) floor-stuck axis=(\(rounded(axis.x)),\(rounded(axis.z))) align=\(rounded(die.topFaceAlignment)) fst=\(rounded(floorStuckTime[index]))")
                    }
                }
                if die.angularSpeed < 1.0, floorStuckTime[index] < 2.0, let axis = flattenNudgeAxes[index] {
                    die.applyFlatteningNudge(axis: axis, magnitude: 0.01)
                }
                let justCrossedKickThreshold = floorStuckTime[index] >= 2.0 && (floorStuckTime[index] - deltaTime) < 2.0
                if justCrossedKickThreshold, let axis = flattenNudgeAxes[index] {
                    // One-shot angular velocity kick fires exactly once when fst crosses 2s.
                    // Sets ω directly. Effective for shallow tilts; deep box-edge equilibria
                    // absorb most of it (friction torque capacity along the contact edge).
                    die.applyFlatteningNudge(axis: axis, magnitude: 3.0)
                    logDiagnostics("d\(index) one-shot kick fst=\(rounded(floorStuckTime[index])) align=\(rounded(die.topFaceAlignment))")
                }
                if floorStuckTime[index] >= config.floorStuckSeconds {
                    logDiagnostics("d\(index) floor-stuck timeout fst=\(rounded(floorStuckTime[index])) align=\(rounded(die.topFaceAlignment))")
                    currentRollRescueKinds[index].insert("floor")
                    markDieStuck(index, reason: "floor-stuck-timeout")
                }
            } else {
                floorStuckTime[index] = 0
                flattenNudgeAxes[index] = nil
            }

            if settleCounters[index] < config.settleFrames { allSettled = false }
        }

        if activeRollingIndices.isEmpty && pendingLaunchIndices.isEmpty {
            isRolling = false
            if stuckDieIndices.isEmpty && nudgeableDieIndices.isEmpty {
                finishRoll()
            } else if isBatchRunning {
                autoRerollStuckDiceForBatch()
            }
            return
        }

        if rollTime >= config.rollTimeout {
            logDiagnostics("Roll \(activeRollNumber) hit timeout \(rollTime)s; applying rescue nudges. Snapshot: \(diceSnapshotSummary())")
            applyRescueNudges()
            rollTime = 0
        }

        if allSettled {
            if stuckDieIndices.isEmpty && nudgeableDieIndices.isEmpty {
                finishRoll()
            } else {
                isRolling = false
                if isBatchRunning {
                    autoRerollStuckDiceForBatch()
                }
            }
        }
    }

    // MARK: - Private helpers

    private func nextBatchHeldPattern() -> [Bool] {
        guard batchHoldModeEnabled else {
            batchHeldIndices = []
            batchNeedsFreeRollAfterReset = false
            return Array(repeating: false, count: diceCount)
        }

        if batchNeedsFreeRollAfterReset {
            batchNeedsFreeRollAfterReset = false
            return Array(repeating: false, count: diceCount)
        }

        if batchHeldIndices.count >= (diceCount - 1) {
            batchHeldIndices = []
            batchNeedsFreeRollAfterReset = true
            return Array(repeating: false, count: diceCount)
        }

        let availableIndices = (0..<diceCount).filter { !batchHeldIndices.contains($0) }
        if let newHeldIndex = availableIndices.randomElement(using: &rng) {
            batchHeldIndices.insert(newHeldIndex)
        }

        return (0..<diceCount).map { batchHeldIndices.contains($0) }
    }

    private func prepareBatchDiceIfNeeded(for held: [Bool]) {
        guard held.contains(true) else { return }

        let hasVisibleDice = diceEntities.contains { $0.entity.isEnabled }
        guard !hasVisibleDice else { return }

        let seedValues = Array(1...diceCount)
        restoreDice(values: seedValues, held: held)
    }

    private func applyRescueNudges() {
        for (index, die) in diceEntities.enumerated() {
            let held = index < currentHeld.count ? currentHeld[index] : false
            guard !held, activeRollingIndices.contains(index), settleCounters[index] < config.settleFrames else { continue }
            let isStill = die.linearSpeed < config.settleVThreshold && die.angularSpeed < config.settleWThreshold
            guard !isStill else { continue }
            let mag: Float = 0.015
            die.entity.addForce(
                .init(Float.random(in: -mag...mag, using: &rng), mag, Float.random(in: -mag...mag, using: &rng)),
                relativeTo: nil
            )
        }
    }

    private func applySettleAssistance(for index: Int, die: DiceEntity) {
        if let supportIdx = supportingDieIndex(for: index) {
            if stillUnsettledTime[index] >= config.wallStuckSeconds {
                // Repeated hops haven't resolved it — give up and go red.
                currentRollRescueKinds[index].insert("stacked")
                markDieStuck(index, reason: "stacked-timeout")
            } else if stillUnsettledTime[index] >= config.stackedRescueDelay {
                let supportingDie = diceEntities[supportIdx]
                let separation = SIMD3<Float>(
                    die.entity.position.x - supportingDie.entity.position.x,
                    0,
                    die.entity.position.z - supportingDie.entity.position.z
                )
                currentRollRescueKinds[index].insert("stacked")
                die.applyStackedRescue(separationDirection: separation)
                // Do NOT reset stillUnsettledTime — let it accumulate toward the timeout above.
            }
        } else if isLikelyBlockedByWall(die) {
            // No gravity boost here — the downward force spikes v above the isStill threshold,
            // resetting stillUnsettledTime and preventing the timeout from ever firing.
            // Just let the timer accumulate and mark stuck cleanly.
            if stillUnsettledTime[index] >= config.wallStuckSeconds {
                logDiagnostics("Wall-blocked die \(index) timed out at \(String(format: "%.1f", stillUnsettledTime[index]))s on roll \(activeRollNumber)")
                currentRollRescueKinds[index].insert("wall")
                markDieStuck(index, reason: "wall-blocked")
            }
        } else {
            // No timeout — nothing is blocking this die, so gravity escalates until it settles.
            let extraG = config.gravityBoostBase * exp(stillUnsettledTime[index] * config.gravityBoostRate * 0.1)
            die.entity.addForce(.init(0, -extraG, 0), relativeTo: nil)
        }
    }

    private func isLikelyBlockedByWall(_ die: DiceEntity) -> Bool {
        let maxCenter = DiceTrayEntity.halfSize - DiceEntity.wallHeuristicRadius
        let position = die.entity.position
        return abs(position.x) >= (maxCenter - Self.wallRescueInset)
            || abs(position.z) >= (maxCenter - Self.wallRescueInset)
    }

    private func supportingDieIndex(for index: Int) -> Int? {
        let die = diceEntities[index]
        let expectedHeight = Self.expectedSettledCenterHeight
        let heightAboveFloor = die.centerHeightAboveTrayFloor

        guard heightAboveFloor > (expectedHeight + config.settleHeightTolerance) else {
            return nil
        }

        let position = die.entity.position

        for (otherIndex, otherDie) in diceEntities.enumerated() {
            guard otherIndex != index else { continue }
            guard otherDie.entity.isEnabled else { continue }

            let otherPosition = otherDie.entity.position
            guard otherPosition.y < position.y else { continue }

            let deltaXZ = SIMD2<Float>(position.x - otherPosition.x, position.z - otherPosition.z)
            if simd_length(deltaXZ) <= (DiceEntity.supportHeuristicRadius * 2) {
                return otherIndex
            }
        }

        return nil
    }

    private func sanitizeDieTransformIfNeeded(at index: Int) -> Bool {
        let die = diceEntities[index]
        let position = die.entity.position
        let hasInvalidPosition = !position.x.isFinite || !position.y.isFinite || !position.z.isFinite
        let isOutOfBounds =
            abs(position.x) > Self.outOfBoundsHorizontalLimit ||
            abs(position.z) > Self.outOfBoundsHorizontalLimit ||
            position.y < Self.outOfBoundsLowerY ||
            position.y > Self.outOfBoundsUpperY

        guard hasInvalidPosition || isOutOfBounds else { return false }

        let reason = hasInvalidPosition ? "non-finite-transform" : "out-of-bounds"
        let wasPendingLaunch = pendingLaunchIndices.contains(index)
        let wasActiveRolling = activeRollingIndices.contains(index)
        let held = index < currentHeld.count ? currentHeld[index] : false
        let velocity = die.entity.physicsMotion?.linearVelocity ?? .zero
        let angularVelocity = die.entity.physicsMotion?.angularVelocity ?? .zero
        logDiagnostics(
            "Detected \(reason) die state on roll \(activeRollNumber) die=\(index) " +
            "position=\(position) linearVelocity=\(velocity) angularVelocity=\(angularVelocity) " +
            "pendingLaunch=\(wasPendingLaunch) activeRolling=\(wasActiveRolling) held=\(held) " +
            "state=\(describeDie(at: index))"
        )
        if recoverEscapedDieIfPossible(at: index, reason: reason) {
            return true
        }

        markDieStuck(index, reason: reason)
        positionStuckDieVisibly(at: index)
        return true
    }

    private func finishRoll() {
        isRolling = false
        let values = diceEntities.map { $0.topFaceValue }
        logDiagnostics("Finished roll \(activeRollNumber) values=\(values) snapshot=\(diceSnapshotSummary())")
        activeRollNumber = 0
        lastStuckLogBucket = -1

        // Only feed stats during normal play / batch — not during replay
        // (replay would skew the distribution toward repeated results).
        if !isReplay {
            // Capture final position/alignment for dice that settled normally (stuck dice
            // were already captured in markDieStuck before their state was cleared).
            for (index, die) in diceEntities.enumerated() {
                if currentRollFinalAlign[index] == 0 {
                    currentRollFinalAlign[index] = die.topFaceAlignment
                    currentRollUnsettledSecs[index] = stillUnsettledTime[index]
                    currentRollFinalX[index] = die.entity.position.x
                    currentRollFinalZ[index] = die.entity.position.z
                    currentRollFinalHeight[index] = die.centerHeightAboveTrayFloor
                }
            }
            let rescueKinds = currentRollRescueKinds.map { $0.sorted().joined(separator: "|") }
            statistics.addRoll(
                values,
                source: isBatchRunning ? .batch : .gameplay,
                held: currentHeld,
                rescueKinds: rescueKinds,
                escapeRecovered: currentRollEscapeRecovered,
                stuckReroll: currentRollStuckReroll,
                stuckNudge: currentRollStuckNudge,
                stuckReasons: currentRollStuckReason,
                finalAligns: currentRollFinalAlign,
                unsettledSecs: currentRollUnsettledSecs,
                finalXs: currentRollFinalX,
                finalZs: currentRollFinalZ,
                finalHeights: currentRollFinalHeight,
                spawnPositions: currentRollSpawnPos,
                rollDurationSecs: rollTime
            )
        }

        for (index, value) in values.enumerated() {
            audioController?.onDieSettled(index: index, value: value)
        }
        audioController?.onAllDiceSettled(values: values)

        let callback = pendingResults
        pendingResults = nil
        callback?(values)
    }

    private func logStuckRollSnapshotIfNeeded() {
        guard AppConfig.DebugDice.logRollDiagnostics else { return }
        let bucket = Int(rollTime / 2)
        guard bucket >= 1, bucket != lastStuckLogBucket else { return }
        lastStuckLogBucket = bucket
        logger.debug(self, "Roll \(activeRollNumber) still active at \(String(format: "%.2f", rollTime))s. \(diceSnapshotSummary())")
    }

    private func diceSnapshotSummary() -> String {
        diceEntities.indices.map(describeDie(at:)).joined(separator: " | ")
    }

    private func describeDie(at index: Int) -> String {
        let die = diceEntities[index]
        let position = die.entity.position
        let wallBlocked = isLikelyBlockedByWall(die)
        let supportIndex = supportingDieIndex(for: index)
        return "d\(index){p=(\(rounded(position.x)),\(rounded(position.y)),\(rounded(position.z))) v=\(rounded(die.linearSpeed)) w=\(rounded(die.angularSpeed)) top=\(die.topFaceValue) align=\(rounded(die.topFaceAlignment)) h=\(rounded(die.centerHeightAboveTrayFloor)) settle=\(settleCounters[index]) unsettled=\(rounded(stillUnsettledTime[index])) fst=\(rounded(floorStuckTime[index])) wall=\(wallBlocked) support=\(supportIndex.map(String.init) ?? "-")}"
    }

    private func rounded(_ value: Float) -> String {
        String(format: "%.3f", value)
    }

    private func logDiagnostics(_ message: String) {
        guard AppConfig.DebugDice.logRollDiagnostics else { return }
        logger.debug(self, message)
    }

    private func markDieStuck(_ index: Int, reason: String) {
        guard activeRollingIndices.contains(index) else { return }

        // Capture diagnostic snapshot before any state is cleared.
        if diceEntities.indices.contains(index) {
            let die = diceEntities[index]
            currentRollStuckReason[index] = reason
            currentRollFinalAlign[index] = die.topFaceAlignment
            currentRollUnsettledSecs[index] = stillUnsettledTime[index]
            currentRollFinalX[index] = die.entity.position.x
            currentRollFinalZ[index] = die.entity.position.z
            currentRollFinalHeight[index] = die.centerHeightAboveTrayFloor
        }

        activeRollingIndices.remove(index)
        pendingLaunchIndices.remove(index)
        settleCounters[index] = 0
        stillUnsettledTime[index] = 0
        flattenNudgeAxes[index] = nil
        floorStuckTime[index] = 0

        let die = diceEntities[index]

        var motion = PhysicsMotionComponent()
        motion.linearVelocity = .zero
        motion.angularVelocity = .zero
        die.entity.components.set(motion)

        // If a nudge was already attempted, go straight to red (stuck/reroll).
        // Otherwise go to yellow (nudgeable) first — in gameplay the player taps;
        // in batch autoRerollStuckDiceForBatch() will auto-nudge, just like a player would.
        let nudgeAttempted = diceEntities.indices.contains(index) && dieNudgeAttempted[index]
        if nudgeAttempted {
            stuckDieIndices.insert(index)
            die.isStuck = true
            logDiagnostics("Marked die \(index) stuck(red) on roll \(activeRollNumber) reason=\(reason) nudgeAttempted=true state=\(describeDie(at: index))")
        } else {
            nudgeableDieIndices.insert(index)
            die.isNudgeable = true
            logDiagnostics("Marked die \(index) stuck(yellow) on roll \(activeRollNumber) reason=\(reason) state=\(describeDie(at: index))")
        }
    }

    private func autoRerollStuckDiceForBatch() {
        guard (!stuckDieIndices.isEmpty || !nudgeableDieIndices.isEmpty), isBatchRunning else { return }

        // Yellow dice get a physics nudge first, just like a player would tap them.
        let toNudge = Array(nudgeableDieIndices)
        if !toNudge.isEmpty {
            logDiagnostics("Auto-nudging \(toNudge.count) yellow die(s) in batch on roll \(activeRollNumber): \(toNudge)")
            for index in toNudge {
                nudgeStuckDie(at: index)  // clears nudgeableDieIndices entry, re-enters rolling
            }
        }

        // Red dice (nudge already failed) get relaunched from scratch.
        let toRelaunch = Array(stuckDieIndices)
        guard !toRelaunch.isEmpty else { return }

        logDiagnostics("Auto-rerolling \(toRelaunch.count) stuck die(s) in batch on roll \(activeRollNumber): \(toRelaunch)")

        stuckDieIndices = []
        isRolling = true
        rollTime = 0
        lastStuckLogBucket = -1

        for index in toRelaunch {
            currentRollStuckReroll[index] = true
            settleCounters[index] = 0
            stillUnsettledTime[index] = 0
            pendingLaunchIndices.insert(index)
            let die = diceEntities[index]
            die.isHeld = false
            die.isStuck = false
            die.isNudgeable = false
            die.entity.isEnabled = true
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            for index in toRelaunch {
                let _ = await launchDie(at: index)
                pendingLaunchIndices.remove(index)
                activeRollingIndices.insert(index)
                audioController?.onDieLaunched(index: index)
            }
        }
    }

    private func recoverEscapedDieIfPossible(at index: Int, reason: String) -> Bool {
        guard diceEntities.indices.contains(index) else { return false }
        guard !pendingLaunchIndices.contains(index) else { return false }

        escapeRecoveryCounters[index] += 1
        let recoveryAttempt = escapeRecoveryCounters[index]
        guard recoveryAttempt <= Self.maxEscapeRecoveriesPerDie else {
            logDiagnostics(
                "Escaped die recovery limit exceeded on roll \(activeRollNumber) die=\(index) " +
                "attempt=\(recoveryAttempt) reason=\(reason)"
            )
            return false
        }

        let die = diceEntities[index]
        let offset = Self.spawnGrid[index % Self.spawnGrid.count]
        let safeY = Self.expectedSettledCenterHeight + 0.010

        activeRollingIndices.remove(index)
        pendingLaunchIndices.insert(index)
        stuckDieIndices.remove(index)
        nudgeableDieIndices.remove(index)
        settleCounters[index] = 0
        stillUnsettledTime[index] = 0
        currentRollRescueKinds[index].insert("escape_recovered")
        currentRollEscapeRecovered[index] = true
        die.isStuck = false
        die.isNudgeable = false
        die.isHeld = false
        die.entity.isEnabled = true

        var motion = PhysicsMotionComponent()
        motion.linearVelocity = .zero
        motion.angularVelocity = .zero
        die.entity.components.set(motion)
        die.entity.position = SIMD3<Float>(offset.x, safeY, offset.y)

        logDiagnostics(
            "Auto-recovering escaped die on roll \(activeRollNumber) die=\(index) " +
            "attempt=\(recoveryAttempt) reason=\(reason) resetPosition=\(die.entity.position)"
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.pendingLaunchIndices.contains(index) else { return }
            let _ = await self.launchDie(at: index)
            self.pendingLaunchIndices.remove(index)
            self.activeRollingIndices.insert(index)
            self.audioController?.onDieLaunched(index: index)
            self.logDiagnostics("Recovered die \(index) relaunched on roll \(self.activeRollNumber)")
        }

        return true
    }

    private func positionStuckDieVisibly(at index: Int) {
        guard diceEntities.indices.contains(index) else { return }

        let die = diceEntities[index]
        let offset = Self.spawnGrid[index % Self.spawnGrid.count]
        let visibleY = Self.expectedSettledCenterHeight + 0.001
        die.entity.position = SIMD3<Float>(offset.x, visibleY, offset.y)
    }

    private func launchParameters(for index: Int) -> SIMD3<Float> {
        let offset = Self.spawnGrid[index % Self.spawnGrid.count]
        let jitter = config.spawnJitter
        let jx = Float.random(in: -jitter...jitter, using: &rng)
        let jz = Float.random(in: -jitter...jitter, using: &rng)
        let spawnY = Float.random(in: config.spawnYMin...config.spawnYMax, using: &rng)
        return SIMD3<Float>(offset.x + jx, spawnY, offset.y + jz)
    }

    private func launchDie(at index: Int) async -> DiceRollRecipe.DieLaunchParams {
        if index > 0 {
            let delayMs = UInt64.random(in: 10...80)
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
        }

        let spawnPos = launchParameters(for: index)
        currentRollSpawnPos[index] = spawnPos
        return diceEntities[index].launch(
            at: spawnPos,
            impulseRange: config.impulseMin...config.impulseMax,
            torqueRange:  config.torqueMin...config.torqueMax,
            coneHalfAngle: config.coneHalfAngle,
            using: &rng
        )
    }
}
