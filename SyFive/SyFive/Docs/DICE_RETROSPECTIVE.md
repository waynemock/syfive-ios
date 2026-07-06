# SyFive — RealityKit Dice System: Implementation Retrospective

*Completed: July 2026*

---

## Overview

This document captures the full arc of the SyFive dice implementation — from the initial requirements and plan through every discovery, dead end, and decision made along the way. It exists for posterity and as a reference if the dice system ever needs to be revisited.

**References:**
- [`DICE_REQUIREMENTS.md`](DICE_REQUIREMENTS.md) — original goals, fairness constraints, and UX spec
- [`DICE_IMPLEMENTATION_PLAN.md`](DICE_IMPLEMENTATION_PLAN.md) — phase-by-phase build plan

**Final result summary (10,000-roll validation):**
- Overall chi-square p-value: **0.217** (all five dice pass individually)
- Serial correlation: **0.003** (no sequential dependency)
- Runs test Z: **−0.44** (no streak patterns)
- Rescue rate: **9.2%** (stacked/wall/floor rescues)
- Stuck-reroll rate: **0.98%** (down from 4.17% at baseline)
- Nudge success rate: **50.5%** (half of stuck dice self-right via physics nudge)
- The dice are fair.

---

## The Starting Point

The requirements (see `DICE_REQUIREMENTS.md`) set three non-negotiable principles:

1. **Physics-first feel** — drive the roll with real dynamics, not "pick a number then animate."
2. **Fairness is measurable** — every physics change must be validated with a repeatable harness.
3. **Player trust** — no patterns that look sticky, streaky, or biased.

The implementation plan (see `DICE_IMPLEMENTATION_PLAN.md`) laid out four phases:
- Phase 0: Visual rig (tray, camera, lighting)
- Phase 1: One die MVP (roll, settle, face read)
- Phase 2: Five dice + full Yatzy integration
- Phase 3: "Feels random" polish
- Phase 4 (optional): Debug test harness

The plan was well-conceived. What it couldn't anticipate was how much of the work would be spent on a problem it mentioned only briefly in one bullet: *"nudge micro impulse if a die rests cocked on an edge too long."* That one bullet became a multi-session saga.

---

## Phase Execution

### Phases 0–2: Went Largely as Planned

The visual rig, physics scaffolding, multi-die spawning, hold mechanic, and Yatzy integration all shipped close to the plan. A few notable divergences:

- **Pip rendering**: The plan noted "rounded-corner appearance via material or mesh" as an option. We ended up building actual pip geometry — flat dark UnlitMaterial discs parented to each die face. True concave indentations require CSG (not available in RealityKit), so unlit near-black circles against the lit white die body was the standard 3D-game approach. It reads unmistakably as dice.

- **Hold mechanic**: Implemented as `PhysicsBodyMode.kinematic` rather than `.static`. Kinematic allows position-setting (used to arrange held dice in a neat visual line) while static does not. Held dice are arranged by face value — a small UX touch not in the plan.

- **Spawn positions**: The plan called for random positions within a rectangle. The shipped version uses a deterministic `spawnGrid` of five fixed offset positions, each jittered with a small random component. This prevents the "spawn collision explosion" that purely random positions create while still feeling varied.

### Phase 3: Polish That Became Infrastructure

"Feels random" polish turned into real engineering:

- **Cone-constrained impulse direction**: The launch impulse is bounded within a configurable cone half-angle (0.70 radians). Too narrow and rolls feel repetitive; too wide and dice escape the tray.
- **Dual-axis torque**: Two independent random torque axes are combined so dice get complex tumbling, not rotation about a single axis.
- **Batch mode**: Added for the Phase 4 harness but became critical for physics tuning — running 1,000 or 10,000 rolls while watching distribution live.
- **`DiceRoller.Config` struct**: All tunable parameters in one place, with a separate `Config.batch` variant using looser thresholds for fast batch runs.

### Phase 4: Debug Harness Exceeded the Plan

The plan asked for "a HUD with a histogram and a Run 500 rolls button." What shipped:

- Live distribution bar chart with per-face frequency annotations
- Chi-square, serial correlation, and runs test with pass/fail badges
- Batch roll controls (1,000 / 10,000, with progress bar)
- Auto-hold cycling mode (validates fairness across the held-die path)
- Per-die rescue/nudge/reroll breakdown table
- CSV export with 21 fields per sample (including spawn position, final alignment, rescue kind, stuck reason, nudge flag, reroll flag)
- Python analysis script (`analyze_dice_fairness.py`) for offline post-processing
- Roll recipe capture and replay

---

## Crossing the Uncanny Valley

Physics-driven dice have a version of the uncanny valley problem. Get the parameters wrong in the obvious direction and you have cartoon physics: dice that bounce like superballs, spin forever, glide frictionlessly across the surface, or all come to rest in the same two seconds with the same dead thump. It's immediately, viscerally wrong. But even with "realistic" parameters dialed in roughly, early versions of the dice sat in an uncomfortable middle zone — the motion looked *almost* right but something felt off, like watching footage of real dice played back at the wrong frame rate.

Crossing out of that zone required tuning several interdependent parameters simultaneously, with no formula for the right answer — only the feel test of watching the dice roll and asking honestly: *does that look like dice I've thrown on a table?*

### What Made Early Versions Feel Wrong

The first instinct for "realistic friction" was too high. At μ_s = 0.50 / μ_k = 0.40 (plausible for a hard plastic die on felt), dice would skid to a stop in a flat sliding deceleration rather than tumbling. Real dice tumble-roll; they don't skate. The high friction was killing angular momentum too fast and converting the roll into a slide.

Restitution (bounciness) was similarly counterintuitive. Starting at 0.45 felt right on paper — dice do bounce — but it made the first impact look rubbery. Real dice bounce once, sharply, then settle quickly. The fix was lower restitution (0.30) combined with higher angular damping (2.0), which produces the characteristic sharp initial bounce and rapid spin decay that reads as "dense object."

The single-axis torque was the least obvious problem. Early dice tumbled around one axis — they looked like they were being rolled in a specific direction rather than thrown. Adding a second independent random torque axis (combined via cross-product) produced genuine three-axis tumbling: the chaotic, unpredictable tumble of a real throw that makes you uncertain which face will come up.

The launch impulse cone was too wide initially. Dice would sometimes travel nearly horizontally and slam into the far wall with too much energy. Narrowing the cone half-angle (0.70 radians from vertical) kept all rolls in the "toss onto the table" visual range — energetic enough to feel thrown, contained enough to feel intentional.

### The Visual Side

The pip geometry mattered more than expected. Early placeholders used a tinted material face — dice looked like colored cubes rather than dice. Switching to actual pip mesh geometry (flat, near-black discs parented to each face) made the dice instantly identifiable from motion alone. Even a die spinning in the air, partially obscured, reads as a *die* because the dot pattern catches the light.

The hold mechanic presentation reinforced the physical feel. Held dice aren't just frozen in place — they're rearranged into a short line at the front of the tray, sorted by face value. This arrangement looks deliberate: the player set those dice aside carefully. It separates the "in play" visual state from the "decided" visual state without any 2D UI overlay.

### The Chamfered Hull: A Physical Correctness Win With a Visual Bonus

The chamfered convex hull fix (discussed in detail in the stuck-die section) solved an edge-friction physics artifact. But it also had an unexpected visual benefit: dice with a chamfered hull self-right with a small, natural wobble before settling. The sharp-box hull either settled flat instantly or teetered for too long. The chamfered hull settles with a brief rocking motion that looks exactly like a real die coming to rest. That wobble was not engineered — it emerged from the corrected physics.

### The Moment It Clicked

There was a specific moment — not when fairness was proven, not when stuck dice were resolved, but earlier — when the dice were first tuned to their final damping and friction values and you just watched a roll and thought: *those look like dice.* Not 3D-model dice, not app dice — dice. The kind you pick up and throw. The angular momentum was right, the impact sound timed correctly, the tray contained everything without feeling like a box, and the pips caught the lighting at the end of the roll as each die rocked to a stop.

That's the uncanny valley crossed. Everything after that was making sure the dice *stayed* that way under all the edge cases: stuck on a wall, landed on top of another, held in the kinematic line, nudged yellow, relaunched red. Each path had to feel equally real, not like a special case. When a nudge fires and the die just... tips over and settles like a real die would when flicked, instead of snapping or teleporting, that's the work paying off.

---

## The Stuck-Die Problem: A Multi-Session Saga

This was the defining technical challenge. The plan mentioned "nudge micro impulse if a die rests cocked" as a one-liner. In practice, it took several complete debug cycles to fully resolve.

### Stage 1: The Naive Approach (addTorque)

Initial rescue used `addTorque` applied every tick while a die was detected as stuck. This was too violent — it kept the die spinning indefinitely rather than settling it. Switched to a gentler flattening nudge (`applyFlatteningNudge`) applied only when angular speed was below 1.0 rad/s.

### Stage 2: Discovering Stable Friction Equilibria

Dice were observed getting genuinely stuck at consistent tilt angles — not random orientations, but specific angles that persisted across many rolls. Analysis showed these were **stable friction equilibria**: positions where the torque required to pivot the die flat was less than the maximum static friction torque available.

At the original friction settings (μ_s = 0.50, μ_k = 0.40), a die tilted up to ~33.6° from flat could be in stable equilibrium. The die wasn't stuck by a wall or another die — it was in a valid physical resting state.

### Stage 3: The PhysX Edge-Contact Discovery

This led to the most important technical discovery of the entire project. Lowering friction helped (μ_s = 0.30, μ_k = 0.25 reduced the stable tilt angle to ~23°), but some dice remained stuck even at shallow tilts where pure physics said they should roll flat.

The root cause: **PhysX edge-contact discretization**. When a box rests on an edge, the physics engine discretizes the contact into 2–4 contact points distributed along the edge. Each point generates an independent friction constraint. Together they create an artificial multi-point friction torque that resists edge-pivot rotation — even though pure-pivot rotation about a single edge contact would theoretically be frictionless.

This is a known physics engine artifact, not a real-world phenomenon. A real die on a real table edge would pivot freely; the simulation's discrete constraint solver makes it artificially sticky.

### Stage 4: The Chamfered Convex Hull Fix

The solution was to replace the sharp box collision shape with a **chamfered convex hull**:

```swift
let chamferedMesh = MeshResource.generateBox(size: .init(s, s, s), cornerRadius: 0.005)
let shape = ShapeResource.generateConvex(from: chamferedMesh)
```

`ShapeResource.generateConvex(from:)` builds a convex hull from the chamfered visual mesh. The chamfer radius eliminates sharp edges — instead of edge-line contacts (which create the multi-point friction artifact), the rounded hull generates only point contacts. A point contact cannot resist torque, so the artificial edge-friction disappears entirely and dice self-right naturally.

This single change eliminated the majority of floor-stuck events. It also matched physics shape to visual shape more accurately as a bonus.

### Stage 5: The One-Shot Angular Velocity Kick

Before the chamfered hull fix, a one-shot angular velocity kick was added at `floorStuckTime = 2.0s`. Rather than calling `addTorque` every frame, this fires exactly once, setting `angularVelocity` directly to bypass the friction constraint. It's effective for shallow tilts (align ≥ 0.90) but gets mostly absorbed by friction at deeper tilts — which confirmed that the problem was friction constraint capacity, not impulse magnitude.

The kick was kept as a first-stage rescue even after the hull change; it resolves many cases before the `floorStuckSeconds` timeout fires.

### Stage 6: The Wall Heuristic False Positive

During debugging, a die appeared to be "stuck by a wall" when visually it was nowhere near a wall. Investigation revealed a false positive in `isLikelyBlockedByWall`:

The function uses the die's full 3D half-diagonal (0.0364 m, the containing sphere radius) as a detection radius from the wall. A die at z = 0.098 m triggered the threshold at 0.0976 m — but was actually 42 mm from the wall. The containing-sphere heuristic is intentionally conservative (a tilted die's corner can reach further than its center), so the false positive was benign: the die got rescued via the 2.0s wall timeout, which is faster than the 6.0s floor timeout. The heuristic was kept as-is.

### Stage 7: The Yellow/Red Stuck-Die UX

With the physics largely solved, attention turned to the player experience when a die does get stuck. The original plan implied "nudge and hope." The final design is more intentional:

- **Yellow die (first stuck event)**: Die is frozen with a yellow tint. Player taps → `nudgeStuckDie()` applies a downward linear velocity (−0.4 m/s) + random horizontal angular kick (5 rad/s) and re-enters the active rolling loop. If it settles, the value counts normally. If it gets stuck again, `dieNudgeAttempted[index]` is now true.
- **Red die (second stuck event)**: Die is frozen with a red tint. Player taps → `rerollStuckDie()` launches it fresh from scratch.
- **Never auto-reroll**: The player is always in the loop. A die is never silently relaunched without player input during normal gameplay.
- **Batch mode**: Automatically nudges yellow dice (mimicking player tap) then relaunches red dice. This allows unattended 10,000-roll validation runs.

The nudge resolves ~50.5% of stuck events without a full relaunch, which is both better for fairness (the die's last valid trajectory contributes to the outcome) and more satisfying for the player.

---

## An Intentional Design Choice: The Jumping Bean Die

During testing, a die landing on top of another die would sometimes bounce chaotically — hopping, skittering, and eventually falling to the floor. This is physically accurate behavior (a die really can bounce off another), and the original plan targeted it for elimination.

The decision was made to **keep it**. It's brief, it's plausible, and it has a kind of whimsy that matches the app's personality. Games should have small moments of surprise. The "jumping bean die" stays.

---

## Fairness Validation Journey

### Baseline Run (Pre-Chamfered Hull)

First 10,000-roll run showed:
- Overall p = 0.29 — PASS
- **Die 3: p = 0.005 — borderline FAIL** (face 1 at 19.15%, faces 3 and 6 low at ~14.8%)
- **Die 0: p = 0.038 — borderline** (face 2 at 19.20%)
- Rescued samples (p = 0.28) and clean samples (p = 0.20) both fine
- Stuck-reroll rate: 4.17% (all wall-blocked)
- No floor-stuck events (chamfered hull working)

### Post-Changes Run

After all changes (yellow/red UX, batch auto-nudge, performance fixes):
- Overall p = 0.217 — PASS
- **Die 3: p = 0.178** — bias completely gone, confirmed seed artifact
- **Die 0: p = 0.910** — gone
- All five dice pass individually
- Stuck-reroll rate: **0.98%** (−77% vs baseline)
- Rescue rate: **9.2%** (−34% vs baseline)
- Rescued/nudged/rerolled samples all unbiased

The Die 3 result (p = 0.005 in baseline) was a clean confirmation that it was a seed artifact: with 5 dice at α = 0.05, you expect ~0.25 false positives from chance alone. The fresh run produced a completely normal p = 0.178 for the same die.

---

## Performance Work: The O(n) Statistics Problem

Late in development, the animation began stuttering during long batch runs (~5,600+ rolls). The stutter was a main-thread blocking issue, not a physics issue.

**Root cause**: `DiceStatistics` was `@Observable`, and every property the HUD accessed was an O(n) computed property scanning 10,000 records from scratch:

- `faceCounts` — O(n) scan of `history`
- `faceFrequencies` — called `faceCounts`, O(n)
- `totalRolls` — `Set(records.map(\.rollID)).count`, O(n) + Set allocation
- `rescueCountsPerDie` — O(n) scan of records
- `totalRescues` — O(n) filter
- `nudgeCountsPerDie` — O(n) scan
- `totalNudges` — O(n) filter
- `stuckRerollCountsPerDie` — O(n) scan
- `totalStuckRerolls` — O(n) filter
- `chiSquare` — called `faceCounts`, O(n)
- `serialCorrelation` — O(n) with array copies
- `runsTestZ` — O(n)

The HUD re-rendered every roll (because `batchProgress` changed), triggering all 12 properties × O(10,000) = 120,000 iterations per render. Additionally, the array trim (`removeFirst(5)`) ran every roll after the 10,000-sample cap — an O(10,000) memory move five elements at a time.

**Fix**: All HUD-facing values became stored incremental counters updated in `addRoll()`:
- `faceCounts`, rescue/nudge/reroll counts: O(1) stored, decremented on trim
- `totalRolls`: simple counter
- `chiSquare`: O(6) from stored `faceCounts` (unchanged)
- `serialCorrelation` / `runsTestZ`: cached, recomputed at most every 500 samples
- Trimming: batched (11,000 → 10,000 in one shot, ~once per 200 rolls) instead of 5 elements per roll

This reduced per-render work from 120,000 iterations to effectively O(1) for everything the HUD displays.

The stutter also raised a question about data integrity: the face value read at `finishRoll()` comes directly from the physics entity's current orientation, so it's unaffected by rendering lag. However, `tick()` (settle detection, rescue logic) runs on the main thread via `SceneEvents.Update`. Blocked frames cause settle timers to advance in larger jumps, which can trigger timeouts slightly earlier — potentially inflating rescue rates. The fairness data is clean; the rescue counts may be marginally elevated in the pre-fix baseline.

---

## Architecture: Planned vs Shipped

| Aspect | Plan | Shipped |
|---|---|---|
| Collision shape | `ShapeResource.generateBox` | `ShapeResource.generateConvex(from: chamferedMesh)` |
| Friction (die) | 0.5 / 0.4 | 0.30 / 0.25 |
| Roll timeout | 4.0s | 2.5s (gameplay), 1.5s (batch) |
| Stuck-die handling | "nudge impulse" | Yellow (nudge) → Red (reroll), never auto |
| Statistics | Computed from scratch | Incremental stored counters |
| HUD rescue display | Not specified | Per-die rescue / nudge / reroll table |
| CSV export | Basic | 21 fields including all rescue metadata |
| Screen sleep | Not specified | `isIdleTimerDisabled` during batch |
| Jumping bean die | Targeted for removal | Intentionally kept |

---

## Final Physics Parameters

| Parameter | Value |
|---|---|
| Die size | 0.042 m |
| Collision shape | Convex hull of chamfered box (cornerRadius: 0.005 m) |
| Static friction | 0.30 |
| Dynamic friction | 0.25 |
| Restitution | 0.30 |
| Angular damping | 2.0 |
| Linear damping | 0.8 |
| Mass | 0.02 kg |
| Settle v threshold | 0.02 m/s |
| Settle ω threshold | 0.15 rad/s |
| Settle frames | 30 (gameplay), 8 (batch) |
| Flatness threshold | 0.96 alignment (gameplay), 0.94 (batch) |
| Floor-stuck timeout | 6.0s (gameplay), 3.0s (batch) |
| Wall-stuck timeout | 2.0s (gameplay), 0.8s (batch) |
| Angular kick (1-shot) | 3.0 rad/s at fst = 2.0s |
| Nudge linear velocity | −0.4 m/s (downward) |
| Nudge angular kick | 5.0 rad/s (random horizontal) |

---

## Definition of Done: Final Status

From `DICE_REQUIREMENTS.md`:

- ✅ 5 dice roll reliably in tray, readable, fun, calm
- ✅ Hold mechanic works (tap die in 3D scene)
- ✅ Results wired into `GameModel` correctly
- ✅ Debug harness: 10k rolls + CSV export + fairness metrics
- ✅ No obvious bias in harness runs (p = 0.217, all dice pass)
- ✅ Roll feels varied to a human observer
- ✅ No forever-stuck dice — game always continues
- ✅ Rescue nudges logged and validated as unbiased (rescue p = 0.994)
- ✅ `DiceRollRecipe` captured and replayable (debug only)

---

## Closing Note

The original requirements said: *"Physics-first feel: the roll is driven by dynamics, not 'pick random number then animate.'"*

That remained true throughout. The simulation never cheats. The randomness comes entirely from physics initial conditions — spawn position, orientation, impulse direction and magnitude, torque axis — all seeded from a deterministic RNG. RealityKit and PhysX take it from there. The outcome of each roll is genuinely unknown until the dice stop moving.

The test harness confirmed what physics promised. The dice are fair.
