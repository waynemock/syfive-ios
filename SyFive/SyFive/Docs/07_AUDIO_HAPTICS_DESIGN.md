# SyFive — Audio & Haptics ("Feel") Design Spec

*Design authority for the unified sound + haptic system: the parametric recipe schema,
the offline renderer and content-addressed cache, the playback engines, the concrete
sound family, the dice-roller hook relocation, and the extraction-readiness register
for the dice system.*

> **Status:** Design agreed. This document is the implementation brief for the Xcode
> Claude agent. The recipes in §5 are the sounds — the agent implements a renderer and
> transcribes the tables; it never invents a parameter. Read the whole document before
> starting; the roller changes in §8 are load-bearing for the design in §5.
>
> **Read alongside:** `00_DECISION_LEDGER.md` (always), `02_DATAMODEL_DESIGN.md` (for
> the layering vocabulary this doc extends).

---

## 0. Why this exists (context the agent must not lose)

SyFive's game loop is complete and silent. `DiceAudioControlling` exists with no-op
defaults; `SettingsView` + `AppSettingsModel` already ship `soundEnabled` and
`hapticsEnabled` toggles that nothing consumes. This spec fills that gap with a single
**Feel** system covering both audio and haptics, designed so that:

1. **Every sound and haptic is a number, not a vibe.** Sounds are synthesized from
   parametric recipes (partials, envelopes, noise bands); haptics are intensity/
   sharpness event lists. The spec fully determines the output — the same property the
   physics dice have, where the recipe determines the roll.
2. **The Feel engine is future SyLib material.** ScoreIt v2 will want score chimes with
   no dice in sight. The module ships package-shaped from day one (§2), the same
   discipline `02` used for the domain layer.
3. **Calm governs.** Quiet by default, `.ambient` session (silent switch respected,
   mixes with the user's podcast), no sound that demands attention, haptics that
   punctuate rather than buzz.

Two corpus corrections before anything else.

---

## 1. Supersessions

Per the governance convention (ledger D-001): older docs are not edited; the rulings
below override them, and the ledger rows carry the chain.

- **S-1 — supersedes `02_DATAMODEL_DESIGN.md` §5.2 / §9** ("Dice engine stays in App
  forever" / "Dice engine is App-only, never in the package"). **New ruling (D-009):**
  the dice engine ships in SyLib as its own target, `SyLibDice`. The rule `02` was
  protecting — Foundation-only purity — was always *per-target*, not per-package; SyLib
  is a multi-target umbrella (D-008) and `SyLibCore` keeps the Foundation-only invariant
  untouched. The `[Int]` hand-off seam between dice and scoring is retained exactly as
  designed. Rationale and structure: §2.
- **S-2 — refines `02` §0/§1.** "The domain layer must compile in a target that cannot
  import SwiftData/SwiftUI/RealityKit" stands, scoped explicitly per SPM target (D-007).
  Not a reversal — a clarification the multi-target structure makes necessary.
- **S-3 — supersedes `IMPLEMENTATION_STATUS.md` Haptics note** ("`UIImpactFeedbackGenerator`
  needed"). **New ruling (D-045):** CoreHaptics, parametric patterns, no fallback tier
  (iOS floor is 18.6; CoreHaptics is 13+). Non-Taptic hardware no-ops via capability gate.
- **S-4 — overrules `IMPLEMENTATION_STATUS.md` Audio note** ("Hold toggle click — no
  hook yet; needs addition"). **New ruling (D-048):** no hook is added.
  `DiceAudioControlling` keeps its exact current five-method shape and stays
  physics-lifecycle only. Hold, score, Yatzy, and game-end are game-state events and
  fire app-side through `FeelDirector` (§7). This is the shape a package port should
  have.

Also noted, not a supersession: `IMPLEMENTATION_STATUS.md` predates the current tree —
the settings screen, `MatchController`, Domain/Persistence layers, and stats all exist
now. Trust the code.

---

## 2. Architecture — the Feel module

### 2.1 Placement and import discipline

```
SyFive/
  Feel/                        ← future SyLibFeel target
    Recipes/                   SoundRecipe, RattleRecipe, HapticRecipe (+ the catalog)
    Render/                    SoundRenderer (offline DSP), SoundCache
    Playback/                  FeelAudioEngine (AVAudioEngine wrapper),
                               FeelHapticEngine (CHHapticEngine wrapper)
    FeelDirector.swift         the single entry point for all feel events
  App/ (existing)
    DiceFeelAdapter.swift      conforms DiceAudioControlling → forwards to director
    Views/FeelBoardView.swift  debug tuning board (SwiftUI — stays app-side forever)
```

**The import rule (the extraction plan, same trick as `02`):** everything under `Feel/`
imports **only Foundation, AVFoundation, and CoreHaptics.** No SwiftUI, no UIKit, no
`Theme`, no `AppConfig`, no SwiftData. Anything app-flavored arrives injected.
*(Ledger D-053.)*

**No Feel↔Dice dependency, either direction.** `DiceAudioControlling` stays in `Dice/`
as that system's outbound port. `DiceFeelAdapter` (App layer) conforms to it and
forwards into the director. Feel never imports Dice; Dice never imports Feel. At
extraction, `SyLibFeel` and `SyLibDice` are sibling targets with no edge between them.

**Machinery vs. content:** the recipe schema, renderer, cache, and engines are package
material. SyFive's specific numbers in §5 — the D-root family, the 147 Hz thunk — are
app content, SyFive's *voice*, and live in the app as a recipe catalog handed to the
director at init. Same split as ScoreEntry-schema vs. Yatzy-rules.

Per `02 §4.5` discipline: **do not create the actual SPM package now.** Folder
boundaries + import rules make extraction a file move at SyLib time.

### 2.2 FeelDirector

```swift
@MainActor @Observable
final class FeelDirector {
    var soundEnabled: Bool = true      // synced from AppSettingsModel by the app
    var hapticsEnabled: Bool = true

    init(catalog: FeelCatalog)          // the recipes (§3), injected

    // Dice-driven (via DiceFeelAdapter)
    func dieSettled(index: Int)
    func allDiceSettled(values: [Int])

    // App-driven (call sites in §7)
    func rollStarted(unheldCount: Int)
    func holdToggled(engaged: Bool)
    func dieNudged()
    func dieRerolled()                  // knock + internally rollStarted(unheldCount: 1)
    func scoreConfirmed()
    func yatzyMoment()
    func gameEnded()
    func undone()                       // pending the open decision in §11
}
```

Threading contract: the API is main-actor (the roller is `@MainActor`; hooks arrive on
main). Playback dispatch is internal and non-blocking — **a feel call must never block a
physics tick.** Scheduling a pre-rendered buffer on a player node and starting a haptic
pattern player are both O(µs); the director does no rendering, no I/O, no waiting on
its call path. If initialization hasn't finished (or an engine failed to start), every
call silently no-ops — the calm failure mode.

`@Observable` exists only so the director can ride SwiftUI's `.environment(_:)`
injection (house style, matching `suggestedMoveEnabled`); it publishes nothing views
depend on.

---

## 3. Recipe schema (Codable — these structs ARE the file format and the cache key)

```swift
struct SoundRecipe: Codable, Hashable {
    var id: String                     // "settle_thunk", "score_confirm", …
    var durationMs: Double
    var renderSeed: UInt64 = 0x5EED    // seeds noise layers → bit-identical renders
    var layers: [Layer]
    var variants: [Variant] = []       // empty ⇒ single canonical render

    enum Layer: Codable, Hashable {
        case tone(Tone)
        case noise(Noise)
    }
    struct Tone: Codable, Hashable {
        var freqHz: Double
        var levelDb: Double            // dBFS, absolute (renderer never normalizes)
        var startMs: Double = 0
        var attackMs: Double
        var decayTauMs: Double         // exponential decay e^(−t/τ) after attack
        var bendCents: Double = 0      // linear pitch ramp of this many cents…
        var bendMs: Double = 0         // …over this window from layer start
    }
    struct Noise: Codable, Hashable {  // seeded white noise → band-pass → envelope
        var bandLowHz: Double
        var bandHighHz: Double
        var levelDb: Double
        var startMs: Double = 0
        var attackMs: Double
        var decayTauMs: Double
    }
    struct Variant: Codable, Hashable {
        var pitchCents: Double         // whole-render transposition
        var levelDb: Double            // whole-render trim
    }
}

struct RattleRecipe: Codable, Hashable {           // generative bed — §5.2
    var id: String
    var durationMs: Double
    var grainBandsHz: [[Double]]       // candidate [low, high] pairs, seeded pick per grain
    var grainDurMs: Double
    var grainAttackMs: Double
    var grainDecayTauMs: Double
    var grainLevelDb: Double
    var grainLevelJitterDb: Double     // uniform [−j, 0], seeded
    var densityFloorPerSec: Double     // λ(t) = floor + (peak − floor)·e^(−t/τ)
    var densityPeakPerSec: Double
    var densityTauSec: Double
    var tailFadeMs: Double
    var seeds: [UInt64]                // one cached variant per seed
}

struct HapticRecipe: Codable, Hashable {
    var id: String
    var events: [HEvent]
    struct HEvent: Codable, Hashable {
        var timeMs: Double
        var kind: Kind                 // .transient | .continuous
        var intensity: Double          // 0…1
        var sharpness: Double          // 0…1
        var durationMs: Double? = nil          // continuous only
        var intensityCurve: [CurvePoint]? = nil // continuous only
    }
    enum Kind: String, Codable { case transient, continuous }
    struct CurvePoint: Codable, Hashable { var timeMs: Double; var value: Double }
}

struct FeelCatalog: Codable {          // one entry per event; app content (§2.1)
    var sounds: [String: SoundRecipe]
    var rattles: [String: RattleRecipe]
    var haptics: [String: HapticRecipe]
    var rootHz: Double = 146.83        // D3 — the single family-tuning constant (D-043)
}
```

**Determinism rules (D-042):** variant pitch/level values are literal tables in §5 —
never `Double.random` at render time. Noise is seeded by `renderSeed`; rattle grains by
each entry in `seeds`. Same catalog ⇒ byte-identical renders on every install, forever.

**Canonical JSON:** `JSONEncoder` with `.sortedKeys` (and `.withoutEscapingSlashes`).
This encoding is the hash input — treat encoder settings as part of the file format.

---

## 4. Rendering & the content-addressed cache

### 4.1 Renderer (offline, no real-time DSP anywhere)

Output format everywhere: **48 kHz, Float32, mono, deinterleaved** into
`AVAudioPCMBuffer`.

- **Tone layer:** phase-accumulated sine. Linear attack over `attackMs`, then
  exponential decay `e^(−t/τ)`. Pitch bend: linear cents ramp over `bendMs` applied to
  the phase increment.
- **Noise layer:** white noise from a seeded generator (reuse the `DiceRandSource` LCG
  *algorithm* — copy the ~15 lines into `Feel/`; do **not** import from `Dice/`, per the
  no-dependency rule) → single RBJ biquad band-pass with center `√(lo·hi)` and
  `Q = center/(hi − lo)` → same attack/decay envelope.
- **Sum layers, apply variant transposition/trim, write.** The renderer **never
  normalizes** — levels are authored absolute so relationships between sounds hold.
  Debug builds assert rendered peak ≤ −1 dBFS; an assert firing means a recipe is
  mis-authored, not that the renderer should rescue it.
- **Rattle render:** draw grain onset times from the inhomogeneous Poisson process
  λ(t) (thinning against λ_peak is fine), place grains (band choice, level jitter from
  the seed), apply `tailFadeMs` linear fade at the buffer end.

A full catalog render is milliseconds of arithmetic; the cache below buys discipline
and headroom (longer rattle beds, fatter variant pools later), not launch speed. Say so
in code comments so nobody "optimizes" it away.

### 4.2 Cache (D-041)

- **Key:** `SHA256( canonicalJSON(recipe) ‖ rendererVersion ‖ formatTag ‖ selector )`
  where `selector` is the variant index (sound recipes) or the seed hex (rattle beds),
  `formatTag = "caf-f32-48k-mono"`, and `rendererVersion` is a single `Int` constant in
  `SoundRenderer`. Bump it **only** when the DSP changes meaning (an envelope-math fix)
  — same recipe through different math is a different sound.
- **Location:** `Library/Caches/Feel/<sha256-hex>.caf`, written/read via `AVAudioFile`
  (`kAudioFormatLinearPCM`, 32-bit float, 48 kHz, 1 channel). Caches is semantically
  correct *because* regeneration is deterministic: system purge ⇒ silent rebuild next
  launch.
- **Startup flow** (background `Task`, utility QoS, kicked off at app launch): for each
  (recipe, selector) compute key → load on hit, render-and-write on miss → hand buffers
  to the engines on the main actor → sweep any file in `Feel/` whose key isn't in the
  live set. A roll racing initialization simply no-ops (§2.2) — in practice human
  seconds vs. machine milliseconds.
- **Feel-board edits bypass the cache** (in-memory render on demand). Freezing tuned
  numbers back into the catalog changes the hashes; the cache rolls forward by itself.

---

## 5. The sound family (the recipes — transcribe exactly)

**Family (D-043):** everything pitched sits on D and A across octaves — open fifths,
maximally consonant, so overlapping sounds can never clash. Real dice aren't pitched;
quantizing to the family is the deliberate stylization, the audio equivalent of the
icon brief's "slightly stylized, not photorealistic." `rootHz` (146.83, D3) is the one
family constant; the feel board may transpose it, and every pitched value below derives
from it. Reference frequencies at root D: D2 73.42 · D3 146.83 · A3 220.00 ·
D4 293.66 · A4 440.00 · D5 587.33 · A5 880.00 · D6 1174.66.

Perceived-loudness ordering, quiet→loud: rattle bed ≪ hold/undo < settle thunk <
nudge/reroll knock < chime/bloom. Nothing exceeds −6 dBFS pre-mix.

### 5.1 `settle_thunk` — per die (fires per §8 relocation)

| Layer | Params |
|---|---|
| Tone (body) | 146.83 Hz (D3), −6 dBFS, attack 2 ms, τ 70 ms, bend −15 cents over 30 ms |
| Tone (sub-weight) | 73.42 Hz (D2), −14 dBFS, attack 2 ms, τ 45 ms — reads on headphones/iPad; near-silent on phone speakers by design |
| Noise (contact tick) | 300–1200 Hz, −22 dBFS, attack 1 ms, τ 4 ms |

Duration 160 ms. **Variants — selected by die index, not round-robin** (each die owns a
voice; die 3 is always slightly brighter than die 1, a free physicality cue):

| Die index | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| pitchCents | −38 | −19 | 0 | +21 | +40 |
| levelDb | −0.6 | −0.2 | 0 | −0.4 | −0.8 |

Haptic (per-die option, §11): transient at 0 ms, intensity **0.38**, sharpness **0.28**.
Fallback single-pulse option: one transient on `allDiceSettled`, **0.50 / 0.30**.

Canonical JSON worked example (the serialization contract — the agent's structs must
round-trip this):

```json
{"durationMs":160,"id":"settle_thunk","layers":[
 {"tone":{"attackMs":2,"bendCents":-15,"bendMs":30,"decayTauMs":70,"freqHz":146.83,"levelDb":-6,"startMs":0}},
 {"tone":{"attackMs":2,"bendCents":0,"bendMs":0,"decayTauMs":45,"freqHz":73.42,"levelDb":-14,"startMs":0}},
 {"noise":{"attackMs":1,"bandHighHz":1200,"bandLowHz":300,"decayTauMs":4,"levelDb":-22,"startMs":0}}],
 "renderSeed":24301,
 "variants":[{"levelDb":-0.6,"pitchCents":-38},{"levelDb":-0.2,"pitchCents":-19},{"levelDb":0,"pitchCents":0},{"levelDb":-0.4,"pitchCents":21},{"levelDb":-0.8,"pitchCents":40}]}
```

### 5.2 `rattle_bed` — the Poisson rattle (D-044, user-locked)

| Param | Value |
|---|---|
| durationMs | 1800 |
| grainBandsHz | [700, 1800] · [900, 2600] · [1200, 3200] (seeded pick per grain) |
| grain dur / attack / τ | 5 ms / 0.5 ms / 1.5 ms |
| grainLevelDb / jitter | −26 dBFS / −3 dB uniform |
| density λ(t) | 6 + 22·e^(−t/0.45) events/s  (≈28/s at launch → ≈20 grains per bed) |
| tailFadeMs | 150 |
| seeds | 0xD1CE0001 · 0xD1CE0002 · 0xD1CE0003 · 0xD1CE0004 (4 cached beds, round-robin per roll) |

Runtime behavior (director-owned, on the dedicated bed node):

- **Start** on `rollStarted(unheldCount: n)` with node volume `√(n/5)` — one die tossed
  rattles less than five. `dieRerolled()` routes here with n = 1.
- **Duck** ×0.65 (≈ −3.7 dB) on each `dieSettled` — the bed thins as dice land.
- **Kill** on `allDiceSettled`: 80 ms linear ramp to 0, stop. The bed never outlives
  visible motion — the foley-mismatch risk identified at design time is bounded to a
  fade.
- Haptic: **none** (D-047).

### 5.3 `hold_engage` / `hold_release`

| | Tone | Noise tick | Duration | Haptic |
|---|---|---|---|---|
| engage | 1174.66 Hz (D6), −14 dBFS, attack 1 ms, τ 25 ms | 1500–4000 Hz, −24 dBFS, τ 1 ms, 3 ms | 70 ms | transient 0.45 / 0.70 |
| release | 880 Hz (A5), −16 dBFS, attack 1 ms, τ 20 ms | 1500–4000 Hz, −26 dBFS, τ 1 ms, 3 ms | 60 ms | transient 0.35 / 0.55 |

Rising = latch, falling fifth = release: on and off feel different (the latch metaphor
from design).

### 5.4 `die_nudge` / `die_reroll` — the stuck-die taps

You flicked a physical object; it should answer like wood.

| | Tone | Noise | Duration | Haptic |
|---|---|---|---|---|
| nudge (yellow) | 220 Hz (A3), −12 dBFS, attack 1 ms, τ 40 ms | 400–1600 Hz, −20 dBFS, τ 2 ms, 4 ms | 110 ms | transient 0.50 / 0.50 |
| reroll (red) | 146.83 Hz (D3), −11 dBFS, attack 1 ms, τ 45 ms | 350–1400 Hz, −19 dBFS, τ 2 ms, 5 ms | 120 ms | transient 0.55 / 0.45 |

Reroll additionally triggers `rollStarted(unheldCount: 1)` internally (§5.2), so the
relaunched die's flight carries a faint bed.

### 5.5 `score_confirm` — the chime

Soft dyad, rolled: D5 587.33 Hz at 0 ms (−16 dBFS, attack 4 ms, τ 180 ms) + A5 880 Hz
at 60 ms (−18 dBFS, attack 4 ms, τ 160 ms). Duration 480 ms.
Haptic mirrors the roll: transients at 0 ms (0.40 / 0.40) and 60 ms (0.32 / 0.45).

### 5.6 `yatzy_moment` — the signature (dossier canon: settle → pause → glow → tick)

Rising bloom, quiet and confident — not fireworks: D4 293.66 at 0 ms (−18 dBFS, attack
6 ms, τ 300 ms) · A4 440 at 90 ms (−18, attack 6, τ 300) · D5 587.33 at 180 ms (−16,
attack 6, τ 340). Duration 950 ms.
Haptic **canonical** (dossier: "soft haptic tick"): single transient at 180 ms — aligned
with the D5 arrival / future title-card beat — **0.50 / 0.25**.
Haptic **alternative** (open, §11): continuous 200 ms swell starting at 90 ms, intensity
curve 0 → 0.5 → 0, sharpness 0.25 — matches the push-in rather than the card.
Note: the rim-light/title-card *visual* from the dossier does not exist yet; this feel
event stands alone until that work happens, keyed to the same trigger (§7.3).

### 5.7 `game_end` — falling resolution (the mirror of 5.6)

D5 587.33 at 0 ms (−18 dBFS, attack 8 ms, τ 420 ms) · A4 440 at 150 ms (−18, attack 8,
τ 460) · D4 293.66 at 300 ms (−16, attack 8, τ 520). Duration 1400 ms. Rising bloom =
Yatzy, falling resolution = the match closing — same three notes, opposite direction,
slower.
Haptic: transients at 0 ms (0.35 / 0.30) and 300 ms (0.45 / 0.22).

### 5.8 `undo` — OPEN (§11), lean recorded

Lean: a tiny "set back down" — D3 146.83, −20 dBFS, attack 2 ms, τ 30 ms, 70 ms total;
haptic transient 0.25 / 0.35. Acknowledgment without commentary; a reversed chime would
editorialize a mistake, which is anti-calm. Alternative: fully silent.

**Sharpness sanity check (D-046 mapping):** thunk (dark, ~150 Hz) 0.28 · game-end tail
0.22 · chime mid-register 0.40–0.45 · nudge knock 0.50 · hold ping (1.2 kHz) 0.70.
Sharpness tracks spectral centroid throughout; keep this monotone relationship when
tuning.

---

## 6. Playback engines

### 6.1 `FeelAudioEngine` (AVAudioEngine wrapper)

- One `AVAudioEngine`; **8 pooled `AVAudioPlayerNode`s** for one-shots (round-robin,
  steal-oldest if exhausted) **+ 1 dedicated bed node** (needs the volume automation in
  §5.2). All connect to `mainMixerNode`.
- `mainMixerNode.outputVolume = 0.63` (−4 dB master trim). Worst realistic overlap —
  several thunks inside a settle window over a bed — stays clear of the limiter with
  authored levels + this trim; the debug peak-assert in §4.1 guards the rest.
- Variants are pre-rendered, so **no runtime pitch/rate units** — the engine stays dumb:
  `scheduleBuffer` + `play`, nothing else on the hot path.
- **Session (D-051):** `AVAudioSession` category **`.ambient`** — silent switch
  respected, mixes with the user's audio. This is the calm choice; never "fix" a
  silent-switch bug report by changing category. Configure lazily before first playback;
  engine `start()` lazily on first sound. Any start/activation failure ⇒ feel goes
  silent, log once, never alert.
- Interruptions: observe `AVAudioSession.interruptionNotification`; on `.began` stop the
  bed and let one-shots die naturally; on `.ended` just re-prepare — everything is
  one-shot, there's nothing to resume. On `scenePhase` background, stop the bed.

### 6.2 `FeelHapticEngine` (CoreHaptics wrapper)

- Gate at init on `CHHapticEngine.capabilitiesForHardware().supportsHaptics` — iPads
  no-op cleanly, and the feel board hides its haptic column when this is false.
- Build one `CHHapticPattern` per `HapticRecipe` at init; keep `CHHapticPatternPlayer`s
  pre-created so firing is O(µs). Recipe mapping is direct: `.transient`/`.continuous`
  events with `.hapticIntensity`/`.hapticSharpness` parameters; `intensityCurve` maps to
  a `CHHapticParameterCurve` on `.hapticIntensityControl`.
- Lifecycle (the part everyone forgets): set `resetHandler` (recreate players, restart),
  `stoppedHandler` (log reason), and restart the engine on foreground return. Start
  lazily on first event.
- Warmth: `ContentView` nudges the director on match-view appear so the haptic engine is
  started before the first roll (avoids first-event latency).

---

## 7. Event routing — exact call sites (from the current tree)

The director is created in `ContentView`, injected via `.environment(FeelDirector.self)`
(house pattern), and its `soundEnabled`/`hapticsEnabled` are synced from
`AppSettingsModel` in `ContentView` via `onAppear` + `onChange` — the toggles already
exist and persist; this doc only specs consumption (D-051).

### 7.1 Dice events — `DiceFeelAdapter`

```swift
@MainActor final class DiceFeelAdapter: DiceAudioControlling {
    private unowned let director: FeelDirector
    init(director: FeelDirector) { self.director = director }
    func onDieSettled(index: Int, value: Int) { director.dieSettled(index: index) }
    func onAllDiceSettled(values: [Int])      { director.allDiceSettled(values: values) }
    // onDieLaunched / onDieHitFloor / onDieHitWall: default no-ops — reserved
}
```

`DiceRoller.audioController` is **weak** — the adapter must be retained. `DiceAreaView`
holds it in `@State` alongside `diceRoller` and assigns
`diceRoller.audioController = adapter` once at setup.

### 7.2 App events — call-site table

| Event | Call site (current code) |
|---|---|
| `rollStarted(unheldCount:)` | `DiceAreaView` roll-button action, between `model.beginRoll()` and `diceRoller.roll(...)`; count = `model.held.filter { !$0 }.count` |
| `holdToggled(engaged:)` | `DiceAreaView.handleDiceTap` hold branch, after `model.toggleHold(at:)`, passing the new `model.held[index]` |
| `dieNudged()` | `DiceAreaView.handleDiceTap` nudgeable branch, alongside `diceRoller.nudgeStuckDie(at:)` |
| `dieRerolled()` | `DiceAreaView.handleDiceTap` stuck branch, alongside `diceRoller.rerollStuckDie(at:)` |
| `scoreConfirmed()` / `gameEnded()` | `PlayerScoreCardView`, immediately after `model.score(category:)` (~line 309): `model.isGameOver ? gameEnded() : scoreConfirmed()` — the game's final score plays the resolution *instead of* the chime, not both |
| `yatzyMoment()` | `DiceAreaView`, in the `onResults` closure after `model.receiveDiceResults(values)` — predicate below |
| `undone()` | wherever the undo button calls `model.undoLastScore()` — pending §11 |

### 7.3 The Yatzy-moment predicate (D-052)

The celebration fires **at settle** (dossier canon), app-side, because only
`MatchController` knows the poison state:

```swift
let fresh = values.dropFirst().allSatisfy { $0 == values[0] }
let box   = model.scores(for: model.currentPlayerIndex)[.yahtzee]
if fresh && (box == nil || box == 50) { director.yatzyMoment() }
```

A five-of-a-kind after a scratched Yatzy box is an ordinary roll (D-005) — celebrating
it would be salt. No celebration, normal thunks only.

---

## 8. Required `DiceRoller` changes (small, load-bearing)

**8.1 Relocate per-die settle hooks into `tick()` (D-049).** Today `finishRoll()` fires
`onDieSettled` for all five dice in a burst *after everything* has settled — the
protocol's "once per die when its motion has settled" comment is currently false, and
staggered thunks are impossible as wired. New behavior:

- Add `private var settleAnnounced: [Bool]` (reset in `roll(held:)`, and per-index in
  `nudgeStuckDie` / `rerollStuckDie`).
- In `tick()`, when a die's still+flat+height check first passes (the
  `settleCounters[index]` 0→1 transition) and `!settleAnnounced[index]`: fire
  `onDieSettled(index:value: die.topFaceValue)`, set the flag. This is the **perceptual
  landing moment**; waiting for the 30-frame counter to complete would put every thunk
  ~0.5 s after the visible landing.
- If the die resumes motion (fails the still check for ≥ 6 consecutive frames), clear
  the flag — a die that hops and lands again *should* thunk again; physically honest.
- Document in the protocol: the per-die `value` is **provisional** (read at first
  stillness); `onAllDiceSettled(values:)`, still fired from `finishRoll()`, carries the
  authoritative results. Only feel consumes the per-die hook, and feel ignores the
  value.

**8.2 Batch guard (D-050).** Wrap every `audioController?` call in
`guard !isBatchRunning else { … }` (a private `notify` helper keeps this one-line). Ten
thousand validation rolls are feel-silent; batch is a dice-system concept, so the guard
lives roller-side.

**8.3 Protocol shape: unchanged.** Five methods as-is; `onDieLaunched` stays wired but
unconsumed (reserved — a future per-die launch grain accent); `onDieHitFloor`/`Wall`
stay reserved for the collision-event phase that eventually replaces the pre-rendered
bed (D-044's deferral).

---

## 9. Debug feel board (App layer, SwiftUI — never extracted)

Gate: `AppConfig.DebugFeel.showFeelBoard` (new flag, sibling of `DebugDice`). One
section per event:

- Sliders bound to a **working copy** of the catalog entry (every recipe field that's a
  number gets a slider; family `rootHz` gets one global slider).
- **Audition** buttons: Sound / Haptic / Both. Edited recipes render in-memory,
  bypassing the cache (§4.2); a render is milliseconds, so slider→audition feels live.
- **A/B** toggle: canonical vs. edited.
- **Freeze**: print the edited recipe's canonical JSON to console + pasteboard. The
  human pastes it back into this doc / the catalog; the changed hash rolls the cache
  forward automatically. This loop is the whole answer to "hard to get the sounds
  right" — tune on device, freeze numbers, spec stays truth.
- Haptic column hidden when `supportsHaptics == false`.

---

## 10. Extraction-readiness register — `Dice/` → `SyLibDice`

From the code read (July 2026 tree). None of this blocks the feel work; items marked ⏱
can land in any order. The target rule: `Dice/` imports Foundation, simd, RealityKit,
Observation — and (iOS target) UIKit for `UIColor` as RealityKit's tint currency — but
never SwiftUI, `Theme`, `AppConfig`, `UIApplication`, or `Bundle.main` reads.

1. **`DiceEntity.theme: Theme`** (`DiceEntity.swift:9`, five computed tints, `init(theme:)`,
   `updateTheme(_:)`) — the biggest leak; `Theme` is App-layer SwiftUI. Replace with an
   injected palette (D-013):
   ```swift
   struct DiceTintPalette {   // lives in Dice/
       var normal, held, nudgeable, stuck, pip: UIColor
   }
   ```
   App builds it from `Theme` (absorbing the hardcoded `.systemYellow` at line 24 into
   `nudgeable`). `init(palette:)` / `updatePalette(_:)` replace the theme pair.
2. **`DiceRoller.setup(in:theme:)` / `applyTheme(_:)`** (`DiceRoller.swift:165, 199`) —
   same substitution at the API boundary: take `DiceTintPalette`.
3. **`UIApplication.shared.isIdleTimerDisabled`** (`DiceRoller.swift:297, 304`) — inject
   `var keepScreenAwake: ((Bool) -> Void)?` on `DiceRoller`; App supplies the
   UIApplication call at wiring time. ⏱
4. **`AppConfig.DebugDice.logRollDiagnostics`** (`DiceRoller.swift:875, 899`) — fold into
   `DiceRoller.Config` as `var logDiagnostics: Bool = false`; the Config struct is the
   natural home and already exists. (`DiceAreaView`'s `AppConfig` uses are App-side and
   fine.) ⏱
5. **`Bundle.main` version read** (`DiceRoller.swift:276`, recipe capture) — add
   `Config.appVersion: String`, injected by App. ⏱
6. **`AppLogger`** (`DiceRoller.swift:12`) — Foundation + os.log only, so it *moves with*
   the code rather than being abstracted (future shared utility target). While there:
   its hardcoded subsystem is still `"com.syzygy.syflux"` — SyFLUX legacy; parameterize.
   ⏱
7. **`DiceTrayEntity` hardcoded UIColors** (`DiceTrayEntity.swift:46, 69`) — tray
   floor/walls don't theme today. Decide: palette gains `trayFloor`/`trayWall` fields,
   or they stay constants. Either is package-clean; deciding is the work. ⏱
8. **Stale comment** — `DiceRollRecipe.swift:5` claims recipes are "Stored in
   UserDefaults"; no such persistence exists (in-memory `lastRecipe` only). Fix the
   comment. ⏱
9. **Already clean ✅** — `DiceStatistics` (Foundation + Observation; `csvString()` is
   pure string-building), `DiceRandSource`, `DiceRollRecipe`. Views (`DiceRKView`,
   `DiceAreaView`, `DiceDebugHUD` + its `ShareLink` export) stay App-side by design and
   are not extraction subjects.

The full multi-target SyLib structure (target manifests, `SyLibCore` extraction) is the
**SyLib extraction brief's** job — a future doc. This register just keeps `Dice/` from
accruing new debt and burns down the existing five leaks cheaply.

---

## 11. Open decisions (Pops resolves; agent does not)

1. **Undo feel** — tiny D3 set-down tick (§5.8, the lean) vs. fully silent.
2. **Settle haptic pattern** — per-die transients (five inside a ~200 ms window; risk:
   buzz-mush) vs. single pulse on all-settled. Both are spec'd (§5.1); build both behind
   a feel-board toggle and decide on device.
3. **Yatzy haptic** — canonical soft tick (dossier canon) vs. the 200 ms swell
   alternative (§5.6). Same treatment: feel-board toggle, decide on device.

Resolved decisions get promoted to ledger rows; these three are already pointered there.

---

## 12. Implementation stages (ordered; each independently checkable)

1. **Feel scaffolding.** `Feel/` folder with the §3 schema, `SoundRenderer`,
   `SoundCache`, and the SyFive catalog transcribed from §5. Unit tests: (a) rendering
   the same recipe twice yields byte-identical buffers; (b) the §5.1 worked JSON
   round-trips through the structs; (c) cache key changes when any recipe field changes
   and is stable otherwise. *Check: tests pass; `Feel/` compiles importing only
   Foundation + AVFoundation + CoreHaptics.*
2. **Engines + director + board.** `FeelAudioEngine`, `FeelHapticEngine`,
   `FeelDirector`, environment injection, settings sync, and the feel board. *Check:
   every §5 event auditions from the board on device — sound, haptic, both — with
   toggles honored and iPad haptics no-oping.*
3. **Dice + app integration.** §8 roller changes (per-die relocation, batch guard);
   `DiceFeelAdapter` wired in `DiceAreaView`; all §7.2 call sites including the Yatzy
   predicate. *Check: a full match plays with staggered per-die thunks, bed
   start/duck/kill, hold click, nudge/reroll knocks, chime, Yatzy bloom (and none on a
   poisoned five-of-a-kind), game-end resolution; a 1,000-roll batch runs silent.*
4. **Tuning pass.** On-device feel-board session; freeze final numbers back into the
   catalog + this doc's tables (or a dated amendment doc if drift is large); resolve
   §11 items 2–3; cache rolls forward. *Check: frozen values committed; ledger updated.*
5. **Extraction seams (⏱ items, any order).** §10 items 1–8. *Check: `grep` finds no
   `Theme`, `AppConfig`, `UIApplication`, or `Bundle.main` references under `Dice/`.*

---

## 13. Invariants the agent must preserve (quick reference)

- `Feel/` imports **only Foundation, AVFoundation, CoreHaptics**. No SwiftUI/UIKit/
  Theme/AppConfig/SwiftData. That rule is the extraction plan.
- **No Feel↔Dice dependency** in either direction; `DiceFeelAdapter` lives App-side.
- `DiceAudioControlling` keeps its exact five-method shape — physics-lifecycle only.
  Game-semantic events (hold/score/Yatzy/game-end/undo) never enter it.
- **The recipes are the spec.** The agent transcribes §5 and never invents or "improves"
  a parameter; changes round-trip through the feel board → frozen back into doc +
  ledger.
- Determinism: variant tables and seeds are literal; renderer never normalizes; same
  catalog ⇒ byte-identical audio on every install.
- Cache: `Library/Caches/Feel/`, key = SHA-256(canonical JSON ‖ rendererVersion ‖
  formatTag ‖ selector); renderer-version bump only on DSP-meaning change.
- Session is `.ambient` — silent switch respected, mixes with user audio. Sound and
  haptics toggles independent; haptics are **not** gated by the silent switch.
- Rattle is sound-only and quiet; haptics never fire for ambience (D-047).
- Batch mode is feel-silent (roller-side guard).
- A feel call **never blocks a physics tick**; failed engines degrade to silence, never
  to alerts.
- No celebration on a poisoned five-of-a-kind (D-052 ∧ D-005).
