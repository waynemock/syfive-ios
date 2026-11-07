# SyFive — Visual Celebrations Design Spec

*Design authority for the two celebratory visual moments in SyFive: the per-Yatzy
reward beat and the once-per-game winner celebration. App-layer only.*

> **Status:** Design agreed. This document is the implementation brief for the Xcode
> Claude agent. Sound and haptics are already in place; this adds the visual layer that
> completes the sensory triad. Read §0 first — the governing principle constrains every
> decision below.

---

## 0. Why this exists (and the line it must not cross)

SyFive's founding ethos is explicit and, in this exact area, explicit *by negation*.
The project dossier rules out "no sparkles… no confetti explosions," and frames the
signature Yatzy moment as **"minimal, premium, confident — not fireworks."** This spec
does not overturn that. It reconciles the legitimate impulse (a satisfying visual reward
for a big moment) with the calm grammar the app is built on.

**The governing principle: frequency governs intensity.**

Under Classic Hasbro rules a Yatzy can occur several times in a single game (the +100
bonus stacks). Game-over happens exactly once. Therefore the two moments must **not**
receive the same treatment. A full particle burst on every Yatzy would exhaust its
welcome by the third occurrence and quietly break "quiet by default." So:

- **Yatzy is restrained-but-repeatable** — a whisper, tuned to survive happening five
  times in one game without fatigue.
- **Game-over is the generous moment** — the single place per game where fuller spectacle
  is *earned*, and even there it stays soft-edged and gravity-calm, never a burst.

Two hard guardrails carried from the dossier and the dice motion-comfort spec:

1. **No burst/explosion motion, ever.** Nothing radiates outward at speed. No slot-machine
   grammar, no casino red, no hard-edged sparkle.
2. **Every celebration has a Reduce Motion path** (§4) that reaches the same end state with
   no particle motion at all.

---

## 1. The two moments at a glance

| | **Yatzy** | **Game Over (winner)** |
|---|---|---|
| Frequency | Several per game | Once per game |
| Intensity | Whisper (sparse, slow) | Generous but calm |
| Signature motion | Accent motes rising off the tray | Winner-accent slow-fall + total count-up |
| Color source | **Current scoring player's** accent | **Winner's** accent |
| Duration | ~1.2–1.8 s, overlaps existing sequence | ~2.5–4 s, own moment |
| Reduce Motion | Crossfade to title card, no motes | Crossfade to winner state, no fall |

---

## 2. The Yatzy celebration (repeatable → whisper)

### 2.1 It extends the existing sequence, it does not replace it

The dossier already specifies the Yatzy beat: *dice settle → micro pause → rim-light
intensifies → gentle cinematic push-in → soft haptic tick → centered title card
("YATZY / +50")*. **Preserve that sequence.** The motes are inserted into it, not layered
over a different animation. The order becomes:

1. Dice settle (existing).
2. Micro pause (existing).
3. Rim-light intensifies + gentle push-in (existing).
4. **Accent motes begin rising from the settled dice** (new — §2.2).
5. Soft haptic tick (existing — already implemented).
6. Title card "YATZY / +50" fades in centered (existing).
7. Motes finish lifting and fade out as the card holds, then the card dismisses.

### 2.2 Rising accent-motes (the core idea)

This is the deliberate inversion of confetti. Instead of particles *falling* (casino
grammar), a sparse set of soft motes *rises and dissipates* — embers lifting off the
tray, not confetti raining down.

- **Count: sparse.** 15–30 motes total across all five dice, not hundreds. Sparseness is
  what lets it repeat without fatigue — treat the count as a ceiling, not a target.
- **Origin:** emanate from the settled dice positions (roughly the five die centers, with
  small jitter), so the reward reads as coming *from the roll itself*.
- **Motion:** slow upward drift with slight lateral wander, gentle ease-out, fading opacity
  and shrinking scale as they lift. No gravity, no fall, no outward blast.
- **Form:** soft-edged small dots or short soft streaks — no hard stars, no glints, no
  sharp sparkle shapes.
- **Timing:** the whole mote lifecycle lives inside the existing ~1.2–1.8 s beat; motes are
  gone (or nearly) by the time the title card is fully settled.

### 2.3 Color sourcing

Motes are tinted with the **current scoring player's** accent — the person who just rolled
the Yatzy, not a global app color. Because participants carry a `displayThemeID` snapshot
(see the data-model spec), "the user's accent" resolves cleanly per player and multiplayer
handles itself with no extra bookkeeping.

- **Primary accent:** the player's theme accent (majority of motes).
- **Secondary accent:** a minority of motes in a secondary/companion tint for subtle
  variation. **See open decision O-1** — confirm whether each `Theme.ThemeType` already
  exposes a distinct secondary accent, or whether the secondary is derived (a lightened /
  hue-shifted primary). Do not invent a hardcoded second palette; source it from the theme.

### 2.4 Repetition behavior (this is the make-or-break requirement)

Because multiple Yatzys per game are normal, the effect **must not escalate or accumulate.**
Each Yatzy fires the identical sparse whisper — no bigger burst on the second, no residue
from the first still on screen when the second fires. If a Yatzy occurs while a prior mote
set is still animating (rapid succession is possible in scripted/test paths), the new set
replaces or coexists cleanly without stacking into a dense cloud. **Verify by rolling three
Yatzys in a row and confirming the third feels identical to the first, not louder.**

### 2.5 Calmer fallback direction (Pops's call — see O-2)

If the rising-motes version reads as even slightly too much once on device, the fallback is
**no particles at all:** a single soft ring of accent light pulses once outward from tray
center and dissipates, synchronized with the rim-light bloom. This is the calmest option
that still marks the moment. Build motes first; keep this as the retreat position if the
motes don't earn their place.

---

## 3. The game-over celebration (once → earned generosity)

This is the one moment per game where fuller spectacle is legitimate. It still obeys the
guardrails: soft-edged, gravity-calm, winner-colored, no burst. It builds on behavior that
already ships — winner detection with tie support, scroll-to-winner spring, leading-player
nav title.

### 3.1 Components (layered, calm)

Four elements, coordinated. Not all are mandatory — §9 flags which are core vs. optional so
Pops can dial intensity.

1. **Winner-accent slow-fall (the "confetti that isn't an explosion").** Soft-edged
   particles in the winner's accent, drifting *down* slowly under gentle gravity, soft and
   sparse enough to feel premium rather than arcade. This is the one place a falling motion
   is permitted, precisely because it happens once. Slow-fall, not burst-then-fall.
2. **Winner scorecard glow + gentle scale.** The winning scorecard gains a warm accent halo
   and a small scale-up as it becomes the focus (pairs with the existing scroll-to-winner).
3. **Grand-total count-up.** The winner's grand total animates *counting up* to its final
   number. Numbers-as-celebration fits a scoring app better than pure spectacle — this is
   the detail that makes the moment feel like SyFive rather than a generic win screen.
4. **Theme-gradient background wash.** A slow drift of the winner's theme gradient washes
   across the background — "night table," premium, quiet. **This alone, with no particles,
   is the calmest strong option** and is worth testing to decide whether confetti earns its
   place even here (O-3).

### 3.2 Color sourcing

All four elements pull from the **winner's** `displayThemeID` accent (primary, with the
same secondary treatment resolved in O-1). Winner identity comes from the existing
winner-detection logic — this celebration consumes that result, it does not recompute it.

### 3.3 Tie handling (real edge case — the data model supports ties)

Participants can share `rank == 1` (ties are already supported end-to-end). The celebration
must not assume a single winner. **See open decision O-4** for the intended behavior; the
candidates are: (a) blend/alternate the tied winners' accents in the particle field and glow
each tied scorecard, or (b) fall back to a neutral app-accent celebration when there's no
unique winner. Whichever is chosen, count-up runs on each tied winner's total, and no single
scorecard is singled out over the others.

### 3.4 Sequence

Game-completion detected → scroll to winner (existing spring) → scorecard glow + scale-in →
count-up begins on the grand total → gradient wash drifts in → slow-fall particles begin and
continue softly for ~2.5–4 s → particles fade → celebration settles into a calm resting
winner state (glow persists softly, particles gone). The moment should *land and rest*, not
loop.

---

## 4. Reduce Motion & accessibility (mandatory, not optional)

This is consistent with the dice motion-comfort stance (no rapid motion, no aggressive
flashes). When `UIAccessibility.isReduceMotionEnabled` is true:

- **Yatzy:** skip motes entirely; crossfade directly to the rim-light-lifted state and the
  title card. The moment is still marked, with no particle motion.
- **Game over:** skip the slow-fall entirely; crossfade to the winner resting state (glow +
  gradient wash held static or very slow). The **total count-up may still run** — it's a
  value transition, not disorienting motion — but confirm this reads acceptably (O-5); if
  in doubt, snap the total to final under Reduce Motion.
- **No flashing.** No element crosses accessibility flash thresholds; opacity ramps are
  gentle. This holds in both normal and Reduce Motion paths.
- Celebrations are **non-interactive and non-blocking** — the player can dismiss/advance at
  any point (tap through the title card, start a new game) and the celebration cancels
  cleanly without leaving orphaned particles or a stuck glow.

---

## 5. Coordination with sound & haptics (already implemented)

Sound and haptics exist; the visuals must align to them, not fight them.

- **Yatzy:** the visual mote onset should sit with the existing soft haptic tick and the
  Yatzy score-confirm sound so the three land as one event, not three staggered ones.
- **Game over:** if a win sound/haptic exists, the count-up and particle onset align to it.
  If there is currently no dedicated game-over sound/haptic, flag it (O-6) — the visual
  moment may want a soft companion cue — but **do not add audio in this pass;** this spec is
  visual-only and audio is owned elsewhere.
- Respect existing sound-off / haptics-off user controls: visuals play regardless of those
  toggles (they are the *visual* channel), but must never assume a sound/haptic fired.

---

## 6. Architecture placement

- **App layer only (Layer 3).** Celebrations are pure presentation. They never enter the
  Domain package and have no persistence footprint — nothing about a celebration is stored.
- **Keep celebrations OUT of the RealityKit dice scene.** The dice scene is validated fair
  at 10,000 rolls; do not add particle entities or effects inside it that could touch physics
  timing, perf, or the settle loop. Implement both celebrations as a **SwiftUI overlay** above
  the tray/scorecard (e.g. a Canvas/TimelineView-driven particle layer), framework-native, no
  third-party dependency (consistent with the app's Apple-first, dependency-light stance).
- **Theme bridging:** accent colors resolve in the App layer from `displayThemeID` →
  `Theme.ThemeType` (the same string→enum mapping the rest of the app uses, `.midnight`
  fallback on miss). The domain stays Foundation-only and knows nothing about any of this.

---

## 7. Performance notes

- Particle counts are deliberately low (Yatzy sparse by design; game-over soft, not dense),
  so this should be cheap. Still, the overlay must not stutter the 60 fps roll or the
  scorecard scroll — profile a Yatzy fired *immediately* after a physics roll settles, when
  the RealityKit scene is still busy.
- Particles must be **fully cancelable and self-cleaning** — no accumulation across repeated
  Yatzys (§2.4), no leaked timers when the user advances early, no work continuing after the
  celebration ends.

---

## 8. Definition of Done

- [ ] Yatzy fires sparse rising accent-motes in the **current scoring player's** primary +
      secondary accent, inserted into the existing rim-light/push-in/title-card sequence.
- [ ] Three consecutive Yatzys feel identical — no escalation, no accumulation, no residue.
- [ ] Game-over fires the winner celebration: winner-accent slow-fall + scorecard glow/scale
      + grand-total count-up + theme-gradient wash, in the **winner's** accent.
- [ ] Ties render per the resolved O-4 behavior; no single scorecard wrongly singled out.
- [ ] Both moments have a Reduce Motion path that reaches the same end state with no particle
      motion and no flashing.
- [ ] Celebrations are non-blocking and cancel cleanly on early dismissal / new game.
- [ ] Nothing runs inside the RealityKit dice scene; no perf regression on roll or scroll.
- [ ] No new dependency; no persistence footprint; domain layer untouched.

---

## 9. Open decisions for Pops

- **O-1 — Secondary accent source.** Does each `Theme.ThemeType` already expose a distinct
  secondary accent, or is the secondary derived from the primary (lightened / hue-shifted)?
  This sets how motes and particles get their two-tone tint.
- **O-2 — Yatzy: motes vs. ring pulse.** Ship rising motes (recommended), or fall back to the
  single soft accent-ring pulse (§2.5) if motes feel like too much on device?
- **O-3 — Game-over: confetti or wash-only.** Does the slow-fall earn its place, or is the
  theme-gradient wash + glow + count-up (no particles) the right calm ceiling even for the
  once-per-game moment?
- **O-4 — Tie behavior.** Blend/alternate tied winners' accents and glow each, or fall back to
  a neutral app-accent celebration when there's no unique winner?
- **O-5 — Count-up under Reduce Motion.** Keep the total count-up when Reduce Motion is on, or
  snap the total to final?
- **O-6 — Game-over audio companion.** Is there an existing win sound/haptic to align to, and
  do you want one added (separately, not in this pass)?

---

## 10. Invariants the agent must preserve (quick reference)

- **Frequency governs intensity:** Yatzy stays a repeatable whisper; game-over is the one
  earned generous moment. Never give them equal weight.
- **No burst/explosion motion, ever.** Yatzy motes rise; game-over particles slow-fall. No
  outward blast, no casino grammar, no hard sparkle, no casino red.
- **Yatzy never escalates or accumulates** across repeats within a game.
- **Colors are participant-scoped:** current scorer for Yatzy, winner for game-over, both from
  the `displayThemeID` snapshot.
- **Reduce Motion always has a no-particle path to the same end state; nothing flashes.**
- **Nothing touches the RealityKit dice scene.** SwiftUI overlay, App layer only, no
  dependency, no persistence, domain untouched.
