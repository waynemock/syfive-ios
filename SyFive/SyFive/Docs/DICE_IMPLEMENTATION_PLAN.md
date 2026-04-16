# DICE_IMPLEMENTATION_PLAN.md
SyFive — RealityKit Dice System: Implementation Plan

## Target Platform
- iOS 18.6 minimum (iOS 26+ preferred where APIs improve)
- Uses `RealityView` (iOS 18+), `PhysicsBodyComponent`, `CollisionComponent`

---

## UI Decision
The RealityKit 3D tray **replaces** the `DicePill` text display entirely.
- `DiceAreaView` will host `DiceRKView` as its primary visual
- Hold interaction moves to tapping a die directly in the 3D scene
- No fallback 2D pill row

---

## File Structure

```
SyFive/
  Dice/
    DiceRoller.swift          — @Observable orchestrator: roll, settle, result delivery
    DiceEntity.swift          — RealityKit die: mesh + collision + physics + face reading
    DiceTrayEntity.swift      — Floor + 4 walls, static physics
    DiceRandSource.swift      — Seeded RNG (LCG) for deterministic replay
    DiceRollRecipe.swift      — Codable snapshot of one full roll (debug replay)
  Views/
    DiceRKView.swift          — SwiftUI RealityView wrapper, camera, lighting
    DiceAreaView.swift        — Updated: embeds DiceRKView, drives DiceRoller
  Models/
    GameModel.swift           — Updated: isRolling flag, receiveDiceResults(_:)
```

---

## Architecture Overview

```
ContentView
  └── DiceAreaView (@Bindable GameModel, @State DiceRoller)
        ├── DiceRKView (owns RealityViewContent, references DiceRoller)
        │     ├── DiceRig (camera transform + lighting)
        │     ├── DiceTrayEntity (floor + walls)
        │     └── DiceEntity × 5
        └── Roll button / status text
```

### Data flow
1. User taps Roll → `DiceAreaView` calls `DiceRoller.roll(held:)`
2. `DiceRoller` spawns/resets unheld dice, applies impulse + torque
3. Scene update loop polls velocity → settle detection
4. On settle: `DiceRoller` reads top face of each die, calls `GameModel.receiveDiceResults(_:)`
5. `GameModel` updates `diceValues`, decrements `rollsRemaining`
6. UI reacts to model changes as before

### Ownership
- `DiceRoller` is `@Observable`, owned by `DiceAreaView` (not `GameModel`)
- `GameModel` stays physics-agnostic: it only receives final integer results
- `DiceRKView` holds a reference to `DiceRoller` for scene update callbacks

---

## Phase 0 — Visual Rig

**Goal:** See a tray and at least one resting die in a stable angled camera view.

### Tasks
1. **`DiceRKView`**
   - `RealityView` with `make` and `update` closures
   - Camera: angled 3/4 view — roughly 45° pitch, pulled back ~0.5–0.8 m above tray center
   - Attach `DirectionalLightComponent` (key), `PointLightComponent` (fill), `SpotLightComponent` or second directional (rim)
   - Set `EnvironmentResource` to a dark/midnight feel
   - Register scene update subscription for settle detection later

2. **`DiceTrayEntity`**
   - Floor: thin box, `ShapeResource.generateBox(...)`, `PhysicsBodyMode.static`
   - 4 walls: thin tall boxes on each edge
   - Friction: 0.6, restitution: 0.2
   - Tray sized ~0.3 × 0.3 m (world units)

3. **Integrate into `DiceAreaView`**
   - Replace dice grid section with `DiceRKView`
   - Keep Roll button and status text below

**Exit criteria:** Tray is visible with stable camera. A manually placed static die sits in it.

---

## Phase 1 — One Die MVP

**Goal:** One die rolls, settles, and the face value is read correctly.

### Tasks

1. **`DiceEntity`**
   - `ModelComponent`: procedural box mesh, ~0.045 m per side, rounded-corner appearance via material or mesh
   - `CollisionComponent`: `ShapeResource.generateBox` matching mesh size
   - `PhysicsBodyComponent`: dynamic, mass ~0.02 kg
   - Physics baseline targets:
     - Restitution: 0.3 (not rubber)
     - Friction: 0.5
     - Angular damping: 2.0
     - Linear damping: 0.8
   - Face normals map (local space → pip value):
     ```
     +Y → 1,  -Y → 6
     +X → 2,  -X → 5
     +Z → 3,  -Z → 4
     ```
     (standard Western die layout — adjust after visual verification)

2. **`DiceRandSource`**
   - Simple LCG seeded RNG conforming to `RandomNumberGenerator`
   - `init(seed: UInt64)`
   - Production: seed from `SystemRandomNumberGenerator`
   - Debug: fixed seed for reproducibility

3. **`DiceRoller.roll(held:)`**
   - Spawn/reset die near tray center
   - Random initial position: within ±0.06 m of center
   - Random spawn height: 0.08–0.12 m above floor
   - Random initial orientation: randomized quaternion
   - Apply `PhysicsBodyComponent` impulse:
     - Magnitude: 0.04–0.11 (tunable)
     - Direction: biased slightly upward + random lateral
   - Apply torque:
     - Random axis, magnitude 0.05–0.15 (tunable)
   - Capture `DiceRollRecipe` for debug

4. **Settle detection** (scene update subscription)
   - Per die: track consecutive frames where:
     - `linearVelocity.length < 0.02`
     - `angularVelocity.length < 0.15`
   - Require 30 consecutive frames (~0.5 s at 60 fps)
   - Timeout: 4.0 s → apply small random rescue nudge, log rescue
   - On all dice settled: read faces, deliver results

5. **Face reading**
   - Transform each local face normal by die's world transform
   - Compare all 6 world normals against `SIMD3<Float>(0, 1, 0)`
   - Top face = max dot product
   - Stability guard: sample for 0.1 s window, require consistent result

6. **`GameModel` updates**
   - Add `var isRolling: Bool` (published via `@Observable`)
   - Add `func receiveDiceResults(_ values: [Int])` — sets `diceValues`, decrements `rollsRemaining`
   - `roll()` becomes initiation only (sets `isRolling = true`), results come via callback

**Exit criteria:** One die rolls, settles, value reads correctly, debug overlay shows value.

---

## Phase 2 — Five Dice + Full Yatzy Integration

**Goal:** Full Yatzy roll loop with 5 physical dice and hold mechanic.

### Tasks

1. **Spawn 5 dice**
   - Staggered spawn positions (grid offset) to prevent overlap explosions
   - Small random spawn delay (0–80 ms) per die to reduce simultaneous collision chaos
   - Collision warmup: spawn slightly above tray, let gravity do initial drop

2. **Hold mechanic**
   - Tap die in 3D scene → `DiceRoller.toggleHold(entityID:)` → `GameModel.toggleHold(at:)`
   - Held dice: switch `PhysicsBodyMode` to `.static` (freeze in place)
   - Visual: held dice get a highlight material overlay (bright border or tint)
   - On next roll: only non-held dice get impulse; held stay frozen

3. **Roll button integration**
   - Disable during `model.isRolling`
   - Show "Rolling…" state
   - After settle: re-enable, show remaining rolls

4. **Input handling**
   - `SpatialTapGesture` in `RealityView` for die tapping (hold toggle)
   - Only allow hold toggle when `model.rollsRemaining < 3 && !model.isRolling`

**Exit criteria:** Full Yatzy turn (up to 3 rolls, hold between rolls) is playable with 3D dice.

---

## Phase 3 — "Feels Random" Polish

**Goal:** Varied, natural-feeling rolls with no repetitive motion patterns.

### Tasks

1. **Micro-variation**
   - Randomize impulse direction within a cone (not just magnitude)
   - Vary torque axis selection each roll
   - Slightly vary spawn height and horizontal offset per die
   - Pre-roll orientation jitter

2. **Audio hooks** (stub only in this phase)
   - `DiceAudioController` protocol stub
   - Hook points: `onDieLaunch`, `onDieHitFloor`, `onDieHitWall`, `onDieSettle`
   - Actual sounds added later

3. **Roll strength** (debug slider)
   - Expose impulse/torque magnitude range as tunable params in `DiceRoller`
   - Debug HUD slider to adjust live

**Exit criteria:** Rolls feel varied, no obvious repetitive loops.

---

## Phase 4 — Debug Test Harness

**Goal:** Validate fairness with measurable statistics.

### Tasks

1. **Debug HUD** (`DiceDebugHUD.swift`)
   - Toggle via `AppConfig` flag
   - Shows last 200 result distribution (bar chart or histogram)
   - Shows current physics params
   - "Run 500 rolls" fast-batch button
   - "Export CSV" button

2. **`DiceRandomnessHarness`**
   - Headless fast-simulation mode (reduced render fidelity)
   - Runs 10k rolls, stores results array
   - Computes:
     - Face frequency per value
     - Chi-square p-value (goodness of fit vs uniform)
     - Serial correlation between result[i] and result[i+1]
     - Runs test (streaks)
   - Outputs summary + CSV

3. **Replay mode**
   - Load `DiceRollRecipe` from storage
   - Re-apply identical seed, position, impulse, torque
   - Clearly marked "REPLAY" overlay in debug builds

**Exit criteria:** Harness can run 10k rolls and show fairness metrics. No obvious bias.

---

## `DiceRollRecipe` Schema

```swift
struct DiceRollRecipe: Codable {
    let seed: UInt64
    let appVersion: String
    let dice: [DieLaunchParams]

    struct DieLaunchParams: Codable {
        let spawnPosition: SIMD3<Float>
        let spawnOrientation: simd_quatf
        let impulse: SIMD3<Float>
        let torque: SIMD3<Float>
        let physicsParams: PhysicsSnapshot
    }

    struct PhysicsSnapshot: Codable {
        let restitution: Float
        let friction: Float
        let angularDamping: Float
        let linearDamping: Float
        let trayFriction: Float
        let trayRestitution: Float
    }
}
```

---

## Physics Parameters (Baseline — Tunable)

| Parameter | Die | Tray |
|---|---|---|
| Restitution | 0.3 | 0.2 |
| Friction | 0.5 | 0.6 |
| Angular damping | 2.0 | — |
| Linear damping | 0.8 | — |
| Mass | 0.02 kg | static |

Impulse magnitude range: 0.04–0.11
Torque magnitude range: 0.05–0.15
Settle vThreshold: 0.02 m/s
Settle wThreshold: 0.15 rad/s
Settle window: 30 frames
Roll timeout: 4.0 s

All values are stored in `DiceRoller.Config` (a tunable struct) — not hardcoded.

---

## Fairness Constraints (from Requirements)

- No persistent skew of any face beyond chi-square tolerance
- Rescue nudges must be symmetric/randomized and logged
- Distribution must not vary by spawn position, device orientation, or frame rate
- Harness must run before shipping any physics parameter changes

---

## Definition of Done

- [ ] 5 dice roll in tray, readable, settle reliably
- [ ] Hold mechanic works
- [ ] Tap-to-hold works in 3D scene
- [ ] Results wired into `GameModel` correctly
- [ ] Debug harness can run 10k rolls + output CSV
- [ ] No obvious bias in harness runs
- [ ] Roll feels varied to a human observer
- [ ] `DiceRollRecipe` captured and replayable (debug only)
