# SyFive — Implementation Status Report

*As of: July 2026*

---

## Summary

The core game loop, dice system, scorecard UX, persistence, and the full stats layer are all complete. The stats work spans both `03_STATS_DESIGN.md` (all 6 stages) and `05_PLAYER_INSIGHTS DESIGN.md` (consistency, proficiency, style signature, risk profile, clutch, and the plain-language player read). App surfaces include pre-game H2H cards, player profiles, and a match history browser with progression charts. What remains is audio, haptics, a settings screen, and pre-submission cleanup.

**Overall progress: ~92% to 1.0 Definition of Done**

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
| Pre-game player grid | ✅ Done | `PreGameGridView` — card per player, adaptive columns, H2H card + profile link per card |

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
| `recordedAt` on `ScoreEntry` | ✅ Done | Stamped unconditionally in `MatchController.score(category:)`; loaded back via `playerScoreTimestamps` |

---

## Stats — COMPLETE ✅

All six stages from `03_STATS_DESIGN.md` and the full Player Insights layer from `05_PLAYER_INSIGHTS DESIGN.md` are shipped. Stats compute on demand from persisted matches — no stored aggregates, no new schema.

### Architecture (preserved invariants)

- **Tier 1 — Generic** (`Domain/Stats/Generic/`): Foundation-only. Extractable to SyLib unchanged.
- **Tier 2 — Yatzy-specific** (`Domain/Stats/Yatzy/`): Reads `YatzyCategory`, calls Domain scoring functions.
- **Series output** (`Domain/Stats/Series/`): Chart-ready plain value types. Domain never imports `Charts`.
- **App surfaces** (`Views/Stats/`): SwiftData fetch → `toDomain()` → stats function → chart view.

### Stage completion

| Stage | What shipped | Status |
|---|---|---|
| **1 — Scaffolding + fixtures** | `Domain/Stats/` structure, `StatsFixtures.swift` with known-outcome `Match` values | ✅ Done |
| **2 — Tier 1 generic core** | `PlayerSummary`, `HeadToHead`, `LineupRecord`, `RecordsBoard`, `OrderedHistory`, `ScoreTrend` | ✅ Done |
| **3 — Tier 2 Yatzy stats** | `CategoryStats`, `UpperSectionStats`, `YatzyStats`, `CategoryAverages` | ✅ Done |
| **4 — `recordedAt` hardening + progression replay** | `MatchController` stamps timestamp unconditionally; `MatchProgression` prefix-replay | ✅ Done |
| **5 — Series types + chart mapping** | `DatedPoint`, `Distribution`, `SeriesPoint`; `ScoreTrendChart`, `PlacementDistributionChart`, `MatchProgressionChart` | ✅ Done |
| **6 — App surfaces** | `HeadToHeadCard` (pre-game), `PlayerProfileView`, `MatchHistoryView` + `MatchDetailView` | ✅ Done |

### Player Insights (from `05_PLAYER_INSIGHTS DESIGN.md`)

| Insight | File | Status |
|---|---|---|
| Consistency (spread, variability) | `Generic/ConsistencyProfile.swift` | ✅ Done |
| Proficiency (strongest/coldest + upper-pace notes) | `Yatzy/Proficiency.swift` | ✅ Done |
| Style signature (section lean, bonus approach, Yatzy turn, opening) | `Yatzy/StyleSignature.swift` | ✅ Done |
| Risk profile (scratch rate, early/late zeros, Yatzy zeroed) | `Yatzy/RiskProfile.swift` | ✅ Done |
| Clutch profile (back-half vs front-half, comebacks, surrendered leads) | `Yatzy/ClutchProfile.swift` | ✅ Done |
| Plain-language read ("An upper-section specialist who...") | `Yatzy/PlayerInsights.swift` | ✅ Done — first-pass thresholds; calibrate on real data |

**Open from `05` §6 (author decisions, not closed by implementation):**
- Style signature placement (centerpiece vs. one section among equals)
- Plain-language read timing (sentences now vs. calibrated later) — shipped first-pass
- Read scope for 1.0 — shipped as part of `PlayerProfileView`

### Unit test coverage

`StatsTests.swift` asserts exact values for Stages 1–4 against synthetic fixtures. Charts and insight structs are covered by preview data and build-time type-checking; no dedicated chart tests.

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
| Basic history + best score | ✅ Done — match history browser, per-match detail, player profile with score trend |
| Feels premium (the "Sydoku maker" bar) | ✅ Done |

---

## What's Left for 1.0

Ordered by dependency and user impact:

1. **Settings screen** — Sound on/off, haptics on/off, suggested move toggle. Can be minimal (one sheet off the toolbar).
2. **Haptics** — 2–3 `UIFeedbackGenerator` callsites (hold toggle, settle, score confirm). Quick win; no blocker.
3. **Audio** — Write a concrete `DiceAudioControlling` implementation using `AVAudioEngine` or `AVAudioPlayer` and assign it to `DiceRoller.audioController`. Hook points are already in place.
4. **Pre-submission** — Flip `AppConfig.DebugDice.showHarness = false`, `logRollDiagnostics = false`, `DebugLayout.isEnabled = false`. Final QA pass, App Store assets.
