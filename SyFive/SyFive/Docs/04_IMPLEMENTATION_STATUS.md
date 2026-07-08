# SyFive — Implementation Status Report

*As of: July 2026*

---

## Summary

The core game loop is complete and polished. The dice are best-in-class — real physics, proven fair, better than the original spec. The scorecard is fully functional with multi-player support. Persistence is wired end-to-end (SwiftData models, domain conversion, MatchController session layer). The pre-game player roster grid is built. What remains is the stats layer (6 staged build-outs per `03_STATS_DESIGN.md`), audio, haptics, settings, and pre-submission.

**Overall progress: ~75% to 1.0 Definition of Done**

---

## Core Gameplay — COMPLETE ✅

| Requirement | Status | Notes |
|---|---|---|
| 5 dice, 3 rolls per turn | ✅ Done | |
| Hold subset between rolls | ✅ Done | Tap die in 3D tray or from DicePill |
| Score a category after rolling | ✅ Done | |
| Category locks after use | ✅ Done | |
| Upper section: Ones–Sixes | ✅ Done | |
| Upper bonus (63 threshold, +35) | ✅ Done | |
| Lower section: 3oaK, 4oaK, FH, SS, LS, Yahtzee, Chance | ✅ Done | All scoring correct |
| Yahtzee bonus (+100 per extra Yatzy) | ✅ Done | |
| Joker rules (forced scoring on second Yatzy) | ✅ Done | Full joker logic in `GameModel` |
| Undo last score | ✅ Done | One level of undo via `LastScoreSnapshot` |
| Winner detection + end-of-game state | ✅ Done | Tie support included |

---

## Dice System — COMPLETE ✅ (Exceeded Spec)

The requirements recommended **Physics-Lite (Option A)** for 1.0 with full physics deferred. We shipped **full RealityKit/PhysX physics** instead, validated fair at 10,000 rolls.

| Requirement | Status | Notes |
|---|---|---|
| Dice feel physical and satisfying | ✅ Done | RealityKit, chamfered convex hull, tuned damping |
| Roll animation → returns values | ✅ Done | Physics settle → face orientation read |
| Tap to hold in 3D tray | ✅ Done | `SpatialTapGesture` on entities |
| Held dice visually distinct | ✅ Done | Held tint + kinematic arrangement by face value |
| Held dice do not change on re-roll | ✅ Done | |
| Stuck dice always resolve (game never hangs) | ✅ Done | Yellow nudge → Red reroll UX |
| Fairness validated | ✅ Done | p=0.217, all 5 dice pass, serial r=0.003 |
| Original spec: SpriteKit | ➡️ Superseded | RealityKit is strictly better; no loss |

---

## Scorecard UX — COMPLETE ✅

| Requirement | Status | Notes |
|---|---|---|
| Tap category to score | ✅ Done | |
| Locked categories non-interactive + visually subdued | ✅ Done | |
| Available categories obvious | ✅ Done | |
| Roll button with rolls-remaining count | ✅ Done | |
| Roll button disabled at 0 remaining | ✅ Done | |
| iPhone portrait layout | ✅ Done | |
| iPad layout | ✅ Done | Probe-driven card width, adapts to Dynamic Type |
| One-tap new game | ✅ Done | + button in nav bar, reset alert if in-progress |
| Suggested best move (default OFF) | ✅ Done | `suggestedScores()` computed in `GameModel`, surfaced in `PlayerScoreCardView` |
| Card border (theme accent, 2pt) | ✅ Done | `strokeBorder` on card background |

---

## Multi-Player — COMPLETE ✅ (Was Planned for 1.1)

Multi-player was listed as a 1.1+ feature. It shipped ahead of schedule.

| Requirement | Status | Notes |
|---|---|---|
| Add/remove players | ✅ Done | |
| Per-player themes | ✅ Done | Each player gets their own theme |
| Turn sequencing | ✅ Done | Rotates correctly through players |
| Scorecard scrolls to current player | ✅ Done | Animated scroll on turn change |
| Scrolls to winner at game end | ✅ Done | Spring animation |
| Leading player shown in nav title | ✅ Done | |
| Pass-and-play multiplayer | ✅ Done | Works on single device |
| Pre-game player grid | ✅ Done | `PreGameGridView` — card per player, adaptive columns, stats placeholder area |

---

## Theming / Look & Feel — COMPLETE ✅

| Requirement | Status | Notes |
|---|---|---|
| 2–3 theme presets for 1.0 | ✅ Done | 7 themes: Midnight, Blossom, Ember, Forest, Ocean, Sunset, Paper |
| Light/dark support | ✅ Done | All themes adapt to system color scheme |
| Dice + tray adapt to theme | ✅ Done | Die material tinted per theme accent |
| Strong typography, calm surfaces | ✅ Done | |
| Matches Sydoku/SyFlux vibe | ✅ Done | |

---

## Persistence — COMPLETE ✅

SwiftData models are defined and wired. Domain↔model conversion is implemented. `MatchController` manages the in-session game state and checkpoints to persisted storage.

| Requirement | Status | Notes |
|---|---|---|
| SwiftData models | ✅ Done | `GameModel`, `MatchModel`, `ParticipantModel`, `PlayerModel`, `TeamModel` |
| Domain ↔ model conversion | ✅ Done | `+Conversion` files per model |
| Current game autosave | ✅ Done | Checkpoint flush at each scored category |
| Completed games history | ✅ Done | `MatchModel` with `status == .completed` |
| Player roster | ✅ Done | `PlayerModel`, persisted, survives app restart |
| `recordedAt` on `ScoreEntry` | ⚠️ Needs hardening | Exists as `Date?`; must be stamped unconditionally at checkpoint (see Stats Stage 4) |

---

## Stats — NOT STARTED ❌

Stats compute on demand from persisted matches (no aggregate tables). The design is fully specified in `03_STATS_DESIGN.md`. Stages are independently unit-testable against synthetic fixtures. **Build order matters: Stage 1 must be done before any other stage.**

### Stats architecture (from `03_STATS_DESIGN.md`)

- **Tier 1 — Generic** (`Domain/Stats/Generic/`): Foundation-only. `PlayerSummary`, `HeadToHead`, `LineupRecord`, `RecordsBoard`, streak/trend helpers. Ships unchanged in SyLib.
- **Tier 2 — Yatzy-specific** (`Domain/Stats/Yatzy/`): Reads `YatzyCategory` and calls Domain scoring functions. `CategoryStats`, `UpperSectionStats`, `YatzyStats`, `MatchProgression`.
- **Series output** (`Domain/Stats/Series/`): Chart-ready plain value types (`DatedPoint`, `Distribution`, `SeriesPoint`). Domain never imports `Charts`.
- **App surfaces** (`Views/Stats/`): Maps series to Swift Charts, applies theme. SwiftData fetch → `toDomain()` → stats function → series → chart.

### Invariants (must not be broken)

- Tier 1 imports **only Foundation** — this is the SyLib extraction plan.
- No charting framework in the domain layer.
- Stats are **compute-on-read** — no stored aggregates, no running totals.
- Stats outputs are **not frozen schema** — they may change freely (never persisted).
- `abandoned` and `inProgress` matches are **excluded** from every stat.
- `rank == 1` = match win; ties share rank, credited to neither's win column.
- Scratch rate tests `value == Decimal(0)`, never falsy; `nil` = unscored (data bug in a completed match).
- Dice/roll telemetry stays with the dice engine — never a stats input, never in `ScoreEntry.metadata`.
- Per-match progression **reuses the pure scoring functions** on entry prefixes — no reimplementation.
- **Do not build `StatsProviding` protocol yet** — pure free functions until a second game exists.
- **Elo deferred** — derivable retroactively; do not wire rating capture into the schema.

### Build plan

| Stage | What | Done when |
|---|---|---|
| **1 — Scaffolding + fixtures** | Create `Domain/Stats/` (Foundation-only). Write a fixture set of completed `Match` values with known ranks/scores/scorecards. | `Domain/Stats/` compiles with only `import Foundation` + sibling domain. Fixtures load. |
| **2 — Tier 1 generic core** | `PlayerSummary`, `HeadToHead`, `LineupRecord`, `RecordsBoard`, ordered-history helper (streaks, trends). Pure free functions. | Unit tests assert exact wins, win rate, pairwise-ahead, streaks, records against fixtures. |
| **3 — Tier 2 Yatzy stats** | `CategoryStats`, `UpperSectionStats`, `YatzyStats`. Calls existing Domain scoring functions. | Scratch rate distinguishes `Decimal(0)` from `nil`; bonus counts match `yahtzeeBonus`. |
| **4 — `recordedAt` hardening + progression replay** | Stamp `recordedAt` unconditionally at checkpoint flush. Build `MatchProgression` via prefix replay through existing pure scoring functions. | A fresh persisted match replays to a monotonic per-player series with correct running totals. A `nil`-timestamp fixture falls back cleanly with no crash. |
| **5 — Series types + chart mapping** | Emit `DatedPoint` / `Distribution` / `SeriesPoint` from stats functions. Map to Swift Charts in `Views/Stats/`. | Domain imports no charting framework. App renders trend, distribution, and progression charts. |
| **6 — App surfaces** | Pre-game H2H card (the signature moment), player profile, match history browser + per-match detail with progression chart, post-game diff ("New personal best"). | Two players starting see their record. Finished match shows progression. Post-game diff surfaces quietly. |

---

## Audio — NOT STARTED ❌

The `DiceAudioController` protocol is fully designed with the right hook points, but there is no concrete implementation. All protocol methods have no-op defaults — the game runs silently.

| Requirement | Status | Notes |
|---|---|---|
| Roll rattle sound | ❌ Not started | Protocol hook: `onDieLaunched(index:)` exists |
| Settle thunk sound | ❌ Not started | Protocol hook: `onDieSettled(index:value:)` exists |
| Hold toggle click | ❌ Not started | No hook yet; needs addition |
| Score confirm chime | ❌ Not started | No hook yet; needs addition |
| Sound on/off user control | ❌ Not started | Blocked by settings screen |

The architecture is ready — implementing audio means writing a concrete `DiceAudioControlling` class using `AVAudioEngine` or `AVAudioPlayer` and assigning it to `DiceRoller.audioController`. The collision hooks (`onDieHitFloor`, `onDieHitWall`) are reserved for a future RealityKit collision event phase.

---

## Haptics — NOT STARTED ❌

| Requirement | Status | Notes |
|---|---|---|
| Light tap on hold toggle | ❌ Not started | `UIImpactFeedbackGenerator` needed |
| Soft impact on settle | ❌ Not started | |
| Optional confirm on scoring | ❌ Not started | |
| Haptics on/off user control | ❌ Not started | Blocked by settings screen |

---

## Settings Screen — NOT STARTED ❌

There is no settings screen. Several features are blocked waiting for it.

| Requirement | Status | Notes |
|---|---|---|
| Settings screen (premium + short) | ❌ Not started | |
| Sound on/off | ❌ Not started | |
| Haptics on/off | ❌ Not started | |
| Suggested move on/off | ⚠️ Logic done | No UI toggle to expose the control |

---

## Platform Scope

| Platform | Status | Notes |
|---|---|---|
| iOS (primary) | ✅ Done | Fully functional |
| iPadOS | ✅ Done | Responsive layout works well |
| macOS | ❌ Excluded | `SUPPORTS_MACCATALYST = NO` in build settings. Can be revisited post-1.0. |
| watchOS / tvOS / visionOS | 🔜 Future | Not 1.0 per requirements |

---

## Debug / Test Infrastructure — COMPLETE ✅ (Beyond Spec)

| Item | Status |
|---|---|
| Live distribution chart + chi-square / serial r / runs Z | ✅ |
| Batch roll (1k / 10k) with auto-rescue | ✅ |
| Per-die rescue / nudge / reroll breakdown table | ✅ |
| CSV export (21 fields per sample) | ✅ |
| Python analysis script | ✅ |
| Roll recipe capture + replay | ✅ |
| Physics tuning sliders (debug-flag gated) | ✅ |

---

## Definition of Done — 1.0 Gap Analysis

From `REQUIREMENTS.md`:

| DoD Criterion | Status |
|---|---|
| Full game playable start-to-finish with correct scoring | ✅ Done |
| Reliable roll/hold behavior | ✅ Done |
| Clean scorecard UX + satisfying dice tray interactions | ✅ Done |
| Basic history + best score | ❌ Needs stats layer (Stages 1–2 minimum) |
| Feels premium (the "Sydoku maker" bar) | ✅ Done |

---

## What's Left for 1.0

Ordered by dependency and user impact:

1. **Stats — Stages 1–2** (scaffolding + fixtures, Tier 1 generic core) — enables the pre-game H2H card and basic history. Blocks Stage 6 surfaces.
2. **`recordedAt` hardening** (Stats Stage 4, first half) — must ship before any new matches are played so replay works forward.
3. **Stats — Stages 3–6** (Yatzy stats, progression replay, series/charts, app surfaces).
4. **Settings screen** — Sound on/off, haptics on/off, suggested move toggle. Can be minimal.
5. **Haptics** — 2–3 `UIFeedbackGenerator` callsites (hold toggle, settle, score confirm). Quick win.
6. **Audio** — Write a concrete `DiceAudioControlling` implementation. Hook points are in place.
7. **Pre-submission** — Flip `AppConfig.DebugDice.showHarness = false`, `logRollDiagnostics = false`, `DebugLayout.isEnabled = false`. Final QA pass, App Store assets.
