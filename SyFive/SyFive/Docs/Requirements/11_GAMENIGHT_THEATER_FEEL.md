# SyFive — Game Night Theater Feel Design Spec

*Design authority for how the implemented sound + haptics ("feel") system behaves
during Game Night spectator theater: what theater renders, what it never renders,
which devices play it, and the shared Yatzy moment's sound.*

> **Status:** Design agreed; one decision open (§7). Ships **with Game Night**.
> Prerequisites: `05_AUDIO_HAPTICS_DESIGN.md` (the feel system, now implemented),
> `06_MULTIDEVICE_DESIGN.md` (Game Night, esp. §6.2 roll theater), and
> `10_GAMENIGHT_COMMENTARY.md`. This document closes the last open half of
> 06 §13.1.

---

## Supersessions

- **06 §13.1 ("Spectator theater audio — parked until the audio workstream
  exists").** The commentary half was resolved by 10; the dice-feel half was left
  open there ("remains open and is untouched by this doc"). → **Fully resolved
  here:** spectated rolls render dice audio on eligible devices (§1, §4) and never
  render haptics (§2). Chain: 06 §13.1 → 10 Supersessions → **11 (closed)**.
- **05_AUDIO_HAPTICS extended, not overridden.** The rattle bed, settle voices,
  tonal family, `FeelDirector` / `DiceAudioControlling` split, and the
  content-addressed cache all apply unchanged; this doc only maps them onto the
  theater lifecycle and gates the haptic side off for spectated rolls.

Ledger rows at the end, ready to paste.

---

## 0. Why this exists (context the agent must not lose)

The feel system is implemented. That unparks the question 06 deferred: **does
spectator theater make sound?**

Ruling: **yes — theater is the sound of the table.** A silent stage is watching dice
through glass. And the locked audio architecture makes it nearly free, twice over:

1. **The rattle bed is procedural on roll lifecycle, not collision-driven** (the
   user-locked Poisson decision). Spectator replays diverge physically from the
   roller's real roll — but the bed doesn't care. It sounds *right* regardless of
   divergence, because it was never listening to collisions in the first place.
2. **The replay is the real physics engine** (06 §6.2 promotes the debug replay
   path). Its dice launch and settle through the same lifecycle as a live roll, so
   the same `DiceAudioControlling` hooks fire naturally. Theater audio is not a new
   system; it is the existing system running on a replayed recipe.

Three principles govern everything below:

- **Sound travels a room; touch doesn't.** At a real table you hear everyone's dice
  and feel only your own.
- **Interventions are never audible.** The theater sounds like dice, never like
  machinery.
- **You get theater sound only if you can't hear the real dice** (§4).

Locked decisions: theater audio yes; theater haptics never; interventions
feel-silent; hear-the-real-dice defaults with one device-local toggle; Yatzy
celebration audio on all theater-audio devices. One decision open: the shared Yatzy
haptic pulse (§7).

---

## 1. What theater renders (audio)

- **Rattle bed:** the procedural Poisson bed runs across the replay's roll lifecycle
  — from replay launch to the last die's true final settle, including any
  auto-resolve extension (§3). Same recipes, same renderer, same content-addressed
  cache as live play; each device renders and caches locally. (Version skew across
  devices means each sounds like its own app version — accepted, graceful.)
- **Per-die settle thunks:** fired by the replay engine's own per-die settle
  detection, individually, exactly as live play fires them. No new hook points.
- **Nothing app-layer.** `FeelDirector` events — hold click, score confirm, undo —
  remain **actor-local**: the person who acts hears their own confirm; tables don't
  broadcast UI confirmations. Spectators see the held line move and the scorecard
  tick silently. The one deliberate exception is the Yatzy moment (§5).
- **Coexistence with the announcer:** on a device running both (the host), 09's
  duck-don't-interrupt rule governs — the announcer speaks over a ducked bed.
- **A free acoustic gift:** the primary theater device (the unseated iPad) is
  typically the call endpoint, so its theater audio is AEC reference and never
  leaks into the outgoing call. Meanwhile the roller's *real* rattle travels the
  call as authentic table sound, masked in remote rooms by their own local-first
  theater — same sound, local copy first, exactly the commentary masking logic.

## 2. What theater never renders (haptics)

**Spectated rolls fire no haptics, ever.** The haptic side of every feel event is
gated off for theater-sourced lifecycles; the audio side plays per §4. The player's
own turn is untouched — the 06 pixel-identical invariant extends to the fingertips.
Implementation shape: the gate lives where the lifecycle is known to be
theater-sourced (the replay path), not as conditionals inside the feel system —
`FeelDirector` and the renderer stay Game-Night-ignorant, mirroring 10's rule for
the commentator engine.

## 3. Interventions are feel-silent

- **The correction wobble makes no sound.** It is camouflaged as the chamfered
  hull's natural settle motion (06 §6.2); a second thunk would unmask it. The die
  already thunked at its replay settle; the corrective reorientation is silent, and
  no re-settle event reaches the feel system.
- **Spectator auto-resolves are silent interventions inside a live bed.** A
  batch-style nudge/relaunch extends the roll: the rattle bed simply keeps running
  to the true final settle, the die's eventual settle fires its one normal thunk,
  and the nudge/relaunch itself emits nothing. One thunk per die per roll, always
  at its real rest.
- Roller-side yellow/red interactions are the roller's own device's feel territory
  (05_AUDIO / feel board) and out of scope here; spectators never see those states
  anyway.

## 4. Which devices play theater audio

The physical rule: **theater sound belongs where the real dice are inaudible.**
Defaults by join context, no detection machinery — the same pattern as 10 §4.4:

| Device situation | Theater audio default |
|---|---|
| Unseated in-session device (the iPad/TV) | **ON** |
| Seated device that took the call sheet on itself (one-device player) | **ON** |
| Seated device joined via tap, link, or same-account prompt | **OFF** |
| Host device with no call active (in-person night) | **OFF** |

In-person tables need nothing: every roller's own device already makes the real
sound, and the room hears it. Remote rooms get the table's sound through theater.

- **One toggle:** "Theater sound on this device" — device-local, persistent
  (`UserDefaults`, per the 02 §7 device-local principle), one row in Settings.
- **The accepted wrinkle:** in a two-device room, your own iPad theaters your *own*
  roll a beat behind your iPhone's real feel — brief, quiet, stadium-PA flavored.
  One toggle flip if it grates; not engineered away.

## 5. The Yatzy moment, completed

**Celebration audio fires on every theater-audio-ON device**, timed to that
device's own theater settle and title card — the synchronized bloom (06 §6.4) gains
its sound, four rooms at once. This is the sole app-layer feel event that crosses
the table, and it needs no wire traffic: every device already computes Yatzy from
the authoritative values.

The **haptic tick** stays roller-only by default, per the touch rule — pending the
one open decision (§7). Note: whether the roller's Yatzy haptic is a tick or a
continuous swell remains a separate, independent feel-board item from 05_AUDIO.

---

## 6. Implementation stages (ordered, independently checkable)

1. **Theater lifecycle → audio hooks.** Verify the replay path fires
   `DiceAudioControlling` audio naturally (bed + per-die settles) on a spectator
   device; gate all haptics off for theater-sourced lifecycles at the replay path.
   *Check: spectator device plays a full, correct-sounding roll; zero haptic
   events fire.*
2. **Intervention silence.** Correction pass and auto-resolve emit no feel events;
   bed persists to true final settle; exactly one thunk per die. *Check: forced
   divergence and forced auto-resolve both sound like ordinary rolls.*
3. **Defaults + toggle.** §4 table wired to join context; Settings row overrides
   and persists. *Check: each join door lands its default; toggle survives
   relaunch.*
4. **Yatzy celebration audio** on theater devices, local-settle timing; haptic
   tick roller-only pending §7. *Check: two households, bloom + sound within ~1 s
   everywhere.*

## 7. Open decision (Pops resolves; the agent must not decide this)

1. **Shared Yatzy haptic pulse:** should theater-audio devices also fire a soft
   haptic pulse at the synchronized bloom, or does the tick stay roller-only per
   the touch rule? Default until ruled: **roller-only.** The case for the pulse:
   four phones pulsing at one bloom, mid-call, has its charms.

## 8. Validation matrix additions (continue 06's numbering)

25. Spectator device: rattle bed + individually-timed per-die thunks match its own
    replay; no haptics fire at any point.
26. Correction wobble is silent — no double-thunk on corrected dice.
27. Auto-resolved spectator die: bed continues unbroken, no intervention sound,
    single thunk at true settle.
28. Defaults land per join door; toggle overrides and persists across relaunch.
29. Two-device room: own-roll double-audio observed and judged tolerable; toggle
    flip silences the iPad theater.
30. Two-household listen test: real rattle over the call masked by local-first
    theater; judged by ear at both ends.
31. Theater audio from a call-endpoint device does not leak into the outgoing call
    (AEC confirms by ear at the far end).
32. Yatzy: celebration audio on all theater-ON devices within ~1 s; haptic
    roller-only (pending §7).

## 9. Invariants quick reference

- Theater renders **dice audio only**: bed + settles. Haptics never fire for
  spectated rolls; the player's own turn is feel-identical to today.
- Interventions are silent: no correction sound, no auto-resolve sound, one thunk
  per die at its true rest, bed unbroken to final settle.
- App-layer feel events stay **actor-local**; the Yatzy celebration audio is the
  single sanctioned exception and crosses via local computation, not wire traffic.
- **Zero wire changes.** No new message kinds; no new feel recipes; the cache,
  renderer, and 05_AUDIO architecture are untouched.
- The feel system stays **Game-Night-ignorant**; theater gating lives at the
  replay path, mirroring 10's composition-root rule.
- Theater audio defaults follow the join context (§4 table); one device-local
  toggle overrides; no detection machinery.

---

## Ledger rows (paste into `00_DECISION_LEDGER.md`; adapt to its column format)

| Decision | Ruling | Source |
|---|---|---|
| Spectator theater audio (06 §13.1) | **Fully resolved:** dice audio yes on eligible devices; chain 06 §13.1 → 10 → 11 | 11 Supersessions |
| Theater haptics | Never, for spectated rolls; own turn feel-identical | 11 §2 |
| Intervention feel | Silent: no correction sound, no auto-resolve sound, one thunk per die at true settle | 11 §3 |
| Theater audio defaults | Hear-the-real-dice rule: unseated + call-sheet devices ON; tap/link/prompt-seated + no-call hosts OFF; one device-local toggle | 11 §4 |
| App-layer feel in Game Night | Actor-local (hold/score/undo); Yatzy celebration audio is the sole exception, on all theater-ON devices | 11 §1, §5 |
| Shared Yatzy haptic pulse | **OPEN** — default roller-only pending ruling | 11 §7 |
