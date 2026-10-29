# SyFive's celebration particles play under Reduce Motion

**Status:** **Closed** 28 October 2026. Written 28 October 2026.

**Scope:** `SyFive` only (§4.1). No SyLib change: this adopts the opt-in Reduce Motion factory
SyLib added for Sydoku (SyLib `45e9964`, "Added support for reduced motion particle bursts", on
branch `reduced-motion`; Sydoku `09A` S.1). Ships with the next SyFive build (the working tree is
at 1.1.2).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document.

---

## Supersessions

This document changes **D-073** in part. `08` is not edited; the ledger row is rewritten (§7).

- `08` §1, the Reduce Motion row: "Crossfade to title card, no motes" (Yatzy) and "Crossfade to
  winner state, no fall" (game over).
- `08` §4: "**Yatzy:** skip motes entirely; crossfade directly to the rim-light-lifted state and the
  title card." and "**Game over:** skip the slow-fall entirely; crossfade to the winner resting
  state".
- `08` §8 (Definition of Done): "Both moments have a Reduce Motion path that reaches the same end
  state with no particle motion and no flashing."
- `08` §10 (invariants): "**Reduce Motion always has a no-particle path to the same end state;
  nothing flashes.**"

**Now:** with Reduce Motion on, the Yatzy motes and the game-over slow-fall play exactly as they do
with it off (§2.1). Everything else in D-073 stands: no flashing, non-blocking, clean cancel.
D-124 (count-up stays animated) is unchanged.

---

## 1. Why

SyLib's `ParticleBurst` draws nothing when Reduce Motion is on, unless the caller passes a
Reduce Motion factory. SyFive's two calls (`Views/CelebrationView.swift` 51 and 407) pass none,
so a Reduce Motion player sees no motes on a Yatzy and no fall at game over. The Yatzy moment is
left with only its title card.

Sydoku gave its Reduce Motion players a gentler confetti in place of its full burst (Sydoku `09`).
SyFive does not need one. Its particles are already the calm form (D-068, D-069): 15–25 small
circles rising 70–140 points over about 1.5 s, and 55 small circles falling at 65–115 points a
second over about 4 s. Nothing spins, launches, zooms or flashes. Pops, 28 October 2026, after
watching the previews: "they are already very chill", so use the current particles for both.

---

## 2. Locked decisions

**2.1 One factory, passed twice** (D-073, rewritten). Each `ParticleBurst` passes its existing
factory as both `particles:` and `reducedMotion:`. The factories themselves are unchanged.
*Rationale:* §1. Passing the same closure needs no SyLib change, and keeps one definition of each
celebration.

**2.2 `shrink` stays at SyLib's default (0.55) under Reduce Motion** *(rec.)*. SyLib's doc
comment for the Reduce Motion factory asks for "no spin or change of size". On 5–10 point circles
that are fading out, the shrink reads as part of the fade, not as a zoom. *Rationale:* Pops's
ruling is "the current for both"; a Reduce Motion variant with `shrink: 0` would be a second
celebration to keep in step.

**2.3 Turning Reduce Motion on mid-burst ends that burst.** This is SyLib's behaviour
(`.onChange(of: reduceMotion)`, Sydoku `09` S-7); nothing replays until the next Yatzy or game
over. Accepted as is.

### 2.4 Considered and excluded (do not revisit)

| Item | Why it is out |
|---|---|
| A separate, gentler Reduce Motion particle set (Sydoku's settling recipe) | §1: SyFive's particles are already that calm. Pops, 28 Oct 2026 |
| `RainbowBorderModifier` (winner card, scorecard) stopping its rotation and pulse under Reduce Motion | Pops, 28 Oct 2026: no other Reduce Motion changes; the app is already very calm |
| Card entrances (scale and slide) becoming a plain crossfade under Reduce Motion, as `08` §4 described | Same ruling |
| A Debug menu to fire celebrations in the running app | Pops, 28 Oct 2026: the `CelebrationView` previews are enough |

---

## 3. Before starting

- `sylib-swift` (the local package at `../../sylib-swift`) is on branch `reduced-motion` at
  `45e9964` or later, or that branch is merged. Without it, `reducedMotion:` does not exist and the
  build fails: a stop condition (`00B` §2), not something to work around.
- Record SyFive's suite total on the pinned destination (`00B` §5.2) before the change.

---

## 4. Tasks

One task, reported in `00A` §6's form.

### 4.1 SyFive: pass each particle factory for Reduce Motion too

**Read:** `Views/CelebrationView.swift`; `LIB/Sources/SyLibUI/Components/ParticleBurst.swift`
(the two initialisers and their doc comments). Nothing else.

**Line numbers are the tree at SyFive `5da665f`.** Find each edit by its quoted text.

1. **`DiceTrayOverlayView`**, under `// Full-frame particle burst — Yatzy only.`:
   `ParticleBurst { makeYatzyParticles(theme: theme) }` becomes

   ```swift
   // Same motes under Reduce Motion: they are already the calm form (D-073).
   ParticleBurst(particles: { makeYatzyParticles(theme: theme) },
                 reducedMotion: { makeYatzyParticles(theme: theme) })
   ```

   `.id(event.id)`, the `.transition` and the `.frame` stay as they are.

2. **`GameOverOverlayView`**: `ParticleBurst { makeFallParticles(winnerThemes: winnerThemes) }`
   becomes

   ```swift
   // Same slow-fall under Reduce Motion: it is already the calm form (D-073).
   ParticleBurst(particles: { makeFallParticles(winnerThemes: winnerThemes) },
                 reducedMotion: { makeFallParticles(winnerThemes: winnerThemes) })
   ```

3. **`project.pbxproj`**: add `Docs/SyLib/24_SYLIB_REDUCED_MOTION_PARTICLES.md` to the app target's
   resource exceptions, beside `Docs/SyLib/23_SYLIB_IOS27_CERTIFICATION.md`, as every earlier
   document is. No other change to the project file.

**No new test.** The factories are private to the file, and SyLib's
`ParticleBurstTests.modeFollowsReduceMotionAndTheSecondFactory` already proves that a given
Reduce Motion factory is the one drawn when Reduce Motion is on.

**Done when:**
- `BuildProject` is clean, with no warnings added.
- Every `CelebrationView` preview still builds.
- SyFive's suite passes on the pinned destination (`00B` §5.2), at §3's total, unchanged.

**Do not:** change `makeYatzyParticles` or `makeFallParticles`; add `shrink`, `fade` or any other
`Particle` argument; touch `RainbowBorderModifier`, any transition or animation, or SyLib.

---

## 5. Validation

| ID | After | Check | Expect |
|---|---|---|---|
| R1 | 4.1 | **Pops, preview or device, Reduce Motion off.** The Yatzy and Game Over previews in `CelebrationView.swift` | Exactly as before: motes rise from the dice; the winner-accent slow-fall and wash at game over |
| R2 | 4.1 | **Pops, device, Reduce Motion on** (Settings › Accessibility › Motion). Play a one-player game to the end | The game-over slow-fall plays, the same as with Reduce Motion off, along with the wash, winner card and count-up |
| R3 | 4.1 | **Yatzy, Reduce Motion on.** Not forced: there is no way to rig the dice. Accepted on R2 and source review, as the two edits are identical in form. If a Yatzy comes up in play, look | The motes rise from the dice, as with Reduce Motion off |

Previews can't switch Reduce Motion on (`accessibilityReduceMotion` is read-only), so R2 and R3
need the system setting.

---

## 6. Open decisions

None. §2.2 is Claude's recommendation, accepted with Pops's ruling to use the current particles
for both. Pops may change it before the task runs.

---

## 7. Ledger row

Rewrites D-073 in place, under **Celebrations**.

| ID | Current ruling | Source → chain |
|---|---|---|
| D-073 | **Reduce Motion is honoured, and the particles are already its form.** With Reduce Motion on, the Yatzy motes and the game-over slow-fall play unchanged: each `ParticleBurst` passes its factory as both `particles:` and `reducedMotion:`. No flashing in either path. Celebrations are non-blocking and cancel cleanly on early dismissal. The rainbow border and card transitions are not gated (`24` §2.4). | `08 §4` → `24` §2 (Pops, 28 Oct 2026) |

---

## 8. Close-out (Claude, directly)

- Ledger: D-073 as §7.
- `IMPLEMENTATION_STATUS.md`, Celebrations table: "Reduce Motion: particles skipped" becomes
  "Reduce Motion: particles play unchanged (D-073, `24`)". The "Open celebrations decisions" list
  (O-3 to O-6) is marked resolved, pointing at D-122 to D-125. The Yatzy title card's
  "auto-dismissed at ~1.8 s" note is corrected to the code's 10 s.

---

## 9. Results log

| Item | Value |
|---|---|
| §4.1 | Done 28 Oct 2026. SyLib `reduced-motion` at `45e9964`. Both `ParticleBurst` calls pass their factory twice; pbxproj exception for `24` already present. `BuildProject` clean, 0 warnings. Suite on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`: 19 tests (22 runs), 0 failures, before and after |
| R1 | **Pass** (Pops, 28 Oct 2026). Previews unchanged with Reduce Motion off |
| R2 | **Pass** (Pops, 28 Oct 2026). With Reduce Motion on, the game-over slow-fall plays as with it off |
| R3 | **Accepted** on R2 and source review (Claude, 28 Oct 2026: both call sites have the identical two-factory form). Not seen live: no way to rig a Yatzy |
| Ledger and status | D-073 rewritten as §7 (checked against §7 by Claude: verbatim). `IMPLEMENTATION_STATUS.md`: Reduce Motion row, O-3 to O-6 marked resolved (D-122 to D-125), Yatzy title card corrected to 10 s. Claude, at close-out: the stale "What's Left for 1.0" item 2 (celebration calibration) marked resolved |

**Review, 28 October 2026 (Claude, at source: SyFive staged changes on `5da665f`, SyLib `reduced-motion` at `45e9964`).** `CelebrationView.swift` matches §4.1 items 1 and 2 exactly, comments included; the factories, transitions and `RainbowBorderModifier` are untouched. The project file adds only `24` to the resource exceptions for this task (the 1.1.2 version bump and "Designed for iPhone/iPad on Mac" setting in the same diff are separate, Pops's own). Ledger and status as above. This document is **Closed**.
