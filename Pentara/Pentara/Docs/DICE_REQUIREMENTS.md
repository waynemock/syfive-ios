# dice_requirements.md
Pentara — RealityKit Dice System (Fair, Physical, Testable)

## Goal
Create dice rolls that *feel* like real tabletop dice while staying **statistically fair** (unloaded) and **repeatably testable**. Use RealityKit 3D dice as the primary roll experience (the “moon shot”), starting with an MVP that is shippable and expandable.

---

## Non-Goals (for 1.0 MVP)
- Perfect photorealism or bespoke die meshes.
- Complex tabletop scenes (hands, cups, felt fibers, etc.).
- Multiplayer network determinism.
- Physical “dice tower” props (possible later).
- Custom watchOS/visionOS experiences (future).

---

## Core Principles
1. **Physics-first feel**: The roll is driven by dynamics (impulse + spin + collisions), not “pick random number then animate.”
2. **Fairness is measurable**: Every change to physics, materials, or forces must be validated with a repeatable test harness.
3. **Deterministic replay for debugging**: Any suspicious roll should be reproducible via a saved “roll recipe.”
4. **Player trust**: No patterns that look “sticky,” “streaky,” or biased beyond normal randomness.

---

## UX Requirements
### Roll interaction
- User taps “Roll” (or shakes device later) → dice spawn (or reset) → roll.
- Dice are angled camera view (top + two sides visible when settled).
- Rolls should feel energetic but not chaotic:
  - 0.6–1.6 seconds typical settle time.
  - Occasional longer settle is okay, but must not be frustrating.

### Result presentation
- Final value is taken only when dice are **settled**.
- UI updates only after settle detection passes.
- Optional: “nudge” micro impulse if a die rests cocked on an edge too long.

### Accessibility / motion comfort
- No rapid camera movement.
- Lighting stable; no aggressive bloom flashes.
- Option later: reduce motion / simplified roll.

---

## Technical Approach (RealityKit)
### Scene components
- **DiceEntity**: one die model + collision + physics body + face-reading helper.
- **DiceTrayEntity**: floor + low walls (prevents escapes), collision shapes.
- **DiceRig**: camera transform + lighting (key/fill/rim) + environment settings.
- **DiceRoller**: spawns dice, applies impulse/torque, tracks settle, extracts results.
- **DiceRandomnessHarness**: headless-ish harness that runs thousands of simulated rolls and exports metrics.

### Physics configuration (baseline targets)
- Dice:
  - Dynamic physics body
  - Restitution (bounciness): modest (not rubber)
  - Friction: moderate (tabletop)
  - Angular damping: tuned to settle in ~1–2s
  - Linear damping: tuned similarly
- Tray:
  - Static physics bodies
  - Slightly higher friction than dice
  - Walls tall enough to keep dice in frame, low enough not to obscure readability

### “Roll recipe” (deterministic debug record)
Store per-die:
- Seed
- Initial position + orientation
- Initial linear impulse vector
- Initial torque vector
- Material parameters snapshot (friction, restitution, damping)
- Tray parameters snapshot (friction, restitution)
- Simulation timestep settings (if adjustable)
- App build/version

This enables “Replay this roll” for debugging claims of bias.

---

## MVP Scope (Phase 1)
### MVP Deliverables
- One die rolling in a tray (RealityKit view embedded in SwiftUI).
- Settling detection + top-face extraction.
- Roll recipe capture + replay button (debug-only).
- Basic stats display (debug-only): last 200 results distribution.

### MVP Acceptance Criteria
- Die remains in tray 99.9% of rolls.
- Result is stable (no misread) after settle.
- Distribution does not show obvious skew in short runs (debug stats sanity check).
- Roll feels believable: visible tumble, varied landings, no “samey” motion loops.

---

## Roadmap (Implementation Plan)
### Phase 0 — Visual Rig + Plumbing (1–2 sessions)
- Create `DiceView` (SwiftUI wrapper) hosting RealityKit.
- Build `DiceRig`:
  - Angled camera (3/4 view)
  - Key/fill/rim lights
  - Midnight background plane
- Place tray/floor and confirm collisions.

**Exit:** You see a tray and a die in a stable camera view.

---

### Phase 1 — One Die MVP (core feel + correctness)
- Add dynamic die physics body.
- Implement roll:
  - spawn/reset die near center
  - apply randomized impulse + torque within tuned bounds
- Implement settle detection:
  - threshold on linear + angular velocity for N consecutive frames
  - max roll timeout + optional rescue nudge
- Implement face reading:
  - Determine which face normal points “up” in world space.
  - Map to pip number.

**Exit:** One die rolls, settles, face reads reliably, debug overlay shows the value.

---

### Phase 2 — Multi-die + Yatzy integration
- Roll 5 dice simultaneously.
- Add “Hold”:
  - held dice remain static / removed from rolling set
  - roll only unheld dice
- Ensure dice don’t clip or explode when spawned together (spawn offsets + collision warmup).

**Exit:** Full Yatzy roll loop is playable with 3 rolls per turn.

---

### Phase 3 — “Feels random” polish (player trust)
- Micro-variation in:
  - impulse magnitude
  - torque axis selection
  - spawn height/offset
  - pre-roll orientation jitter
- Add audio hooks (subtle, cozy clicks; keep it calm).
- Add optional “Roll strength” slider (debug first; maybe user later).

**Exit:** Rolls feel varied and natural without looking chaotic.

---

### Phase 4 — Advanced realism (optional)
- Dice cup / shake gesture.
- Table materials / themes (match Pentara midnight).
- Per-theme tray lighting presets.
- “Tilt table” subtle: tiny randomized gravity tilt (small enough not to bias; must be tested).

---

## Randomness & Fairness Requirements
We are not using “random number then animate,” but physics still needs validation because:
- certain friction/damping combos can bias outcomes
- spawn positioning can bias outcomes
- settle thresholds can misread edge cases
- “rescue nudges” can accidentally bias

### Fairness constraints
- No persistent skew of any face beyond statistical tolerance.
- No consistent face preference tied to:
  - spawn position
  - camera/tray orientation
  - device orientation (portrait vs landscape)
  - frame rate
- Rescue nudges must be symmetric / randomized and validated.

---

## Debug Test Harness (Mandatory)
A dedicated internal screen / debug build feature:
- Runs automated batches of simulated rolls and produces:
  - distribution
  - streak analysis
  - correlation checks
  - replay capture for suspicious runs

### Harness modes
1. **Interactive Debug HUD**
   - Shows last N results histogram (N = 200/1000).
   - Shows current physics params (friction, restitution, damping).
   - “Run 500 rolls” button (fast loop).
   - “Export CSV” button.

2. **Batch Simulation Mode**
   - Runs 10k–100k rolls (as performance allows).
   - Stores only results + minimal roll recipe sample set.
   - Outputs summary + CSV.

3. **Replay Mode**
   - Load a saved roll recipe
   - Reproduce roll for debugging (within reasonable determinism limits)

### Metrics to compute (single die)
- **Face frequency** over N rolls
  - Expected ~N/6 each
  - Flag if any face deviates beyond tolerance (see below)
- **Chi-square test** (goodness of fit)
  - Report p-value (debug-only)
- **Serial correlation** (are results dependent)
  - correlation between result[i] and result[i+1]
- **Runs test** (too many streaks / too few streaks)
  - helps catch “sticky” behavior
- **Position bias check**
  - Run batches with different spawn quadrants and compare distributions
- **Orientation bias check**
  - Run batches with fixed starting face up vs randomized

### Metrics for 5 dice (Yatzy realism)
- Distribution of totals (5–30) vs expected (reference via RNG baseline)
- Distribution of counts (e.g., number of sixes per roll)
- Pairwise independence checks across dice

### Tolerance guidance (practical)
For N = 10,000 single-die rolls:
- Expected per face = 1666.7
- A deviation of ~±3% (≈ ±50) is usually not alarming, but:
  - Use chi-square + sanity thresholds rather than eyeballing.
- For N = 100,000:
  - expected 16666.7; deviations should tighten.

**Fail criteria (debug):**
- Chi-square p-value consistently extremely low across repeated runs.
- One face consistently high/low across spawn variants.
- Strong dependence (correlation) across sequential results.
- Rescue nudges correlate with specific outcomes.

---

## Roll Generation (Physics “Randomness” Inputs)
### Randomized inputs (per die)
- Spawn position: within a centered rectangle (avoid edges)
- Spawn height: small randomized vertical offset
- Initial orientation: randomized quaternion
- Impulse:
  - magnitude range tuned (e.g., 1.0–2.8)
  - direction biased slightly upward + lateral
- Torque:
  - random axis
  - magnitude range tuned (e.g., 0.8–3.0)

### Deterministic seeding
- In production: seed from system RNG.
- In debug harness: allow fixed seed for reproducibility:
  - same seed → same sequence of roll recipes
- Store seed in roll recipe for replays.

---

## Settling Detection
A die is “settled” when for a continuous window:
- linear speed < `vThreshold` (e.g., 0.02)
- angular speed < `wThreshold` (e.g., 0.15)
- for `settleFrames` frames (e.g., 20–40 frames depending on fps)

### Timeout and rescue
- If roll exceeds timeout (e.g., 3.0s):
  - apply a *small*, randomized nudge impulse
  - log that rescue occurred (for fairness analysis)

Rescue must be tested for bias.

---

## Face Reading (Top Face)
### Requirement
Top face identification must be robust and not “flip-flop” near settling.

### Approach
- Predefine local-space face normals and corresponding values.
- Transform normals into world space.
- Choose the face whose world normal has the largest dot with world up `(0,1,0)`.

### Stability guard
- After settle detection, sample face reading for a short window (e.g., 0.1s) and require consistency.
- If inconsistent, extend settling window slightly.

---

## Performance Targets
- Real-time roll rendering at 60fps on modern iPhones.
- Debug batch mode can run slower but should complete 10k rolls in reasonable time if possible.
- If RealityKit cannot batch fast enough:
  - implement a “physics-only fast mode” (lower render fidelity / offscreen)
  - or provide a separate RNG baseline comparator (Swift RNG) for statistical expectation.

---

## Risk Register
- RealityKit determinism varies across devices/OS.
  - Mitigation: roll recipe replay is “best effort”; still valuable.
- Physics parameter changes can silently introduce bias.
  - Mitigation: harness must run before shipping updates.
- Rescue nudges can bias outcomes.
  - Mitigation: log + analyze rescue frequency and outcome correlation.

---

## Definition of Done (1.0 for dice system)
- 5 dice roll reliably in tray, readable, fun, calm.
- Holds work.
- Debug harness exists and can:
  - run 10k rolls and output CSV
  - compute basic fairness metrics
- No obvious bias in harness runs across common device configs.
- Roll “feels random” to humans (varied motion, no repetitive patterns).

---

## Nice-to-Have (post-1.0)
- Dice skins (midnight, blossom, ember variants)
- Tray themes matching Pentara’s vibe
- Sound design: soft ceramic clicks / felt thuds
- “Cup shake” gesture roll mode
- Camera zoom preset (close vs wide)
- Optional “slow motion settle” for satisfying final bounce