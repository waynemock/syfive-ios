# SyFive — Stats & Analytics Design Spec

*Design authority for the stats/analytics layer that sits on top of the persisted
data model: per-player summaries, head-to-head records, records boards, Yatzy-specific
breakdowns, per-match progression, and their chart outputs.*

> **Status:** Design agreed. This document is the implementation brief for the Xcode
> Claude agent. It builds directly on `02_DATAMODEL_DESIGN.md` and reuses its vocabulary
> (Match, Participant, ScoreEntry, Player, Game, YatzyCategory, the pure scoring
> functions). Read that document first; this one assumes it. Persistence is already
> complete through its Stage 6, so stats have real data to run on.

---

## 0. Why this exists (context the agent must not lose)

Stats are the **first real consumer of the data model beyond the game itself**. Building
them is also a stress-test of the schema: everywhere the model *can* answer a question,
that's the denormalization decisions (`finalScore`, `rank`, three-state `status`,
`recordedAt`) paying rent; everywhere it *can't*, the missing data turns out to be
exactly the data the layering rules say shouldn't live in the package anyway.

Like scoring, stats serve two masters and must be built for both from day one:

1. **SyFive 1.0** — surface rich stats about Yatzy games played on this device.
2. **SyLib (Step 2/3)** — the generic half of the stats engine ships in the same package
   as Game+Player+Scoring, so **ScoreIt v2 gets per-player summaries, head-to-head
   records, records boards, and rating support for its entire catalog with zero new
   code.**

The single most important rule from the data model doc applies unchanged here: **the
generic stats layer must compile in a target that cannot `import SwiftData`,
`import SwiftUI`, `import RealityKit`, or `import Charts`.** It takes domain value types
in and returns domain value types out. That rule *is* the extraction plan for stats.

---

## 1. Architecture — two tiers, mirroring scoring

Stats split along the **same seam as scoring** (data model §4). One question decides the
tier: *does this stat need to know what the slot keys mean?*

| Tier | Needs | Reads | Fate at Step 2 | Parallel to |
|---|---|---|---|---|
| **1 — Generic** | Foundation only | `Match`, `Participant` (rank, finalScore, status, seat, dates, playerID) | **Ships in SyLib** | `faceValue` being game-agnostic-in-shape |
| **2 — System-specific** | Foundation only + `YatzyCategory` + Domain scoring funcs | `ScoreEntry.slotKey` / `value` semantics | Ships in the Yatzy scoring module | Yatzy Tier-2 contextual scoring |

**Tier 1 works because `rank == 1` always means "winner,"** regardless of
`WinnerDirection`. Generic stats never need to know the game or which direction wins —
that was resolved into `rank` and `finalScore` at match completion. So win rate,
head-to-head, streaks, placement distributions, and margins are identical machinery for
Yatzy, cornhole, golf, and bridge. This is the payoff of denormalizing `finalScore`/`rank`
at completion and making `abandoned` a distinct status.

**Tier 2 is anything that reads a scorecard cell's meaning** — category averages, scratch
rates, upper-bonus pace. It lives beside Yatzy's scoring functions and, like them, is
written as **pure free functions now — no `StatsProviding` protocol yet** (§9).

### 1.1 Folder placement

```
SyFive/
  Domain/
    Stats/                       ← NEW. Foundation-only. Ships in SyLib.
      Generic/                   Tier 1: PlayerSummary, HeadToHead, RecordsBoard,
                                 streaks/trends, placement distributions
      Yatzy/                     Tier 2: CategoryStats, upper/bonus stats, progression
      Series/                    Chart-ready output value types (§4)
    Scoring/                     (existing — Tier 2 stats call these)
    Values/  Enums/              (existing)
  App/
    Views/Stats/                 ← NEW. Renders series into Swift Charts (§10)
```

> Domain/Stats depends only on Domain (Values, Enums, Scoring). It never depends upward.
> If a stats file needs to `import` anything but Foundation and sibling domain code, it is
> in the wrong layer.

---

## 2. The compute-on-read stance (no aggregate tables)

**Stats are computed on demand from persisted matches. Nothing is cached to disk. There
are no running-total tables.**

Envelope math justifies this outright. A family playing daily for five years is
~2,000 matches × 4 participants × 13 entries ≈ 100k `ScoreEntry` values. Decoding 2,000
scorecard blobs and folding them into every stat in this document is single-digit
milliseconds. Matches complete rarely (seconds-to-minutes apart), so there is nothing to
incrementally maintain, and a stored aggregate would only become a CloudKit invalidation
hazard later — the same reasoning that produced "no reconciliation engine yet" in the
data model doc.

### 2.1 Two derivation classes (both compute-on-read; neither is stored)

| Class | Examples | Input needed |
|---|---|---|
| **Commutative fold** | wins, win rate, averages, category scratch rate, records | a *bag* of completed matches (any order) |
| **Order-dependent** | current/best streak, score trend, Elo (deferred, §8) | matches sorted by `startedAt` |

Both are fully derivable from persisted data. The only difference is that order-dependent
stats sort the input first. **Neither requires a stored aggregate.** Calling this out
because it's tempting to "just store the streak" — don't; sort and fold.

### 2.2 Filtering and memoization

The entry point is a filtered fetch of `MatchModel` where `status == .completed`,
optionally narrowed by `gameID` and/or a participant `playerID`, converted `toDomain()`,
then handed to a pure stats function. **`abandoned` and `inProgress` matches are excluded
by default** from every stat in this document (an abandoned match has no meaningful rank).
Per-session memoization keyed on the filter is fine and optional; persistent caching is
not.

### 2.3 Stats outputs are NOT frozen schema

Unlike `ScoreEntry` (frozen — data model §9), the stats value types in this document are
**computed outputs that are never persisted.** They can change shape freely across app
versions with zero migration cost, because nothing stores them. Only the *inputs*
(Match/Participant/ScoreEntry) are frozen. This is liberating: iterate on stat shapes as
the UI needs them.

---

## 3. The derivable / capture-required boundary

**Every stat in this document is derivable from data already persisted.** That means the
entire catalog works **retroactively** on all historical matches the day it ships — no
capture-in-advance, no schema change, no migration.

The stats that are *not* derivable form one clean family: **roll-level telemetry** — rolls
used per turn, hold decisions, dice-face distributions, luck metrics.

**This boundary is correct and is embraced, not fixed.** Roll-level data is dice-engine
telemetry, and per the data model doc the dice engine is App-only and destined for its own
separate part of SyLib. **Dice telemetry stays with the dice engine and is never part of
the stats contract.** It never enters `ScoreEntry.metadata` (which stays `nil` for Yatzy —
data model invariant) and never becomes a package-level stats input. ScoreIt v2's
manually-entered games will never have roll data anyway, so it could not be part of a
shared contract even in principle.

### 3.1 The one derivable-count / non-derivable-detail split

Joker placements are the lone subtlety. **Joker *count* is derivable** —
`Participant.yahtzeeBonus / 100` gives the number of bonus Yahtzees. But ***which category*
a joker was placed into is not** recoverable: a joker Full House scored 25 is
indistinguishable in the completed scorecard from an earned Full House. That detail is not
worth capturing for 1.0; the count is enough. Noted so no one later mistakes the gap for a
bug.

---

## 4. Chart/series output (keeping the domain Foundation-only)

Charts must not drag `import Charts` into the package. The split:

- **The domain emits chart-ready series** — plain Foundation value types: ordered point
  sequences, distributions, histograms. No colors, no marks, no view code.
- **The App layer maps series to Swift Charts marks** and applies theme.

Illustrative series types (in `Domain/Stats/Series/`, shapes free to evolve per §2.3):

```
struct SeriesPoint: Sendable { var x: Decimal; var y: Decimal; var label: String? }
struct DatedPoint:  Sendable { var at: Date; var value: Decimal }
struct Distribution: Sendable { var bins: [Int: Int] }   // e.g. rank -> count, total -> count
```

Everything the UI charts — score trend over time, placement distribution, per-match
progression race, category averages — is expressible as one of these. **SyLib never
imports a charting framework.** This is the exact analogue of the dice engine handing
Layer 1 a bare `[Int]`: the stats engine hands the App bare numbers.

---

## 5. The catalog — Tier 1 (generic, ships in SyLib)

All types below are `Sendable`, Foundation-only, computed. `Decimal` throughout to match
the data model's score type.

### 5.1 Per-player summary

```
struct PlayerSummary: Sendable {
    var playerID: UUID
    var matchesPlayed: Int
    var wins: Int
    var winRate: Double
    var podiumRate: Double                 // top-3 finishes / matches (multi-player)
    var placementDistribution: [Int: Int]  // rank -> count (1st, 2nd, ...)
    var averageScore: Decimal
    var bestScore: Decimal
    var worstScore: Decimal
    var medianScore: Decimal
    var averageRank: Double
    var averageMarginToWinner: Decimal     // winner.finalScore - this.finalScore, 0 for wins
    var firstPlayed: Date?
    var lastPlayed: Date?
    // order-dependent (input sorted by startedAt) — §2.1
    var currentStreak: Int                 // + = consecutive wins, - = consecutive losses
    var bestWinStreak: Int
    var worstLossStreak: Int
}
```

Notes: `winRate = wins / matchesPlayed`. `podiumRate` and `placementDistribution` are only
interesting for multi-player and degenerate cleanly for heads-up. `averageMarginToWinner`
uses `finalScore`, no scoring re-run. `bestScore` also feeds the records board (§5.4). A
companion `scoreTrend(playerID:window:) -> [DatedPoint]` returns a rolling average of the
last N `finalScore`s for the trend chart.

### 5.2 Head-to-head (the pre-game card)

The signature surface: two players about to start, shown how they've done against each
other. **Decided: match-wins is the headline, pairwise-ahead is the second line.**

```
struct HeadToHead: Sendable {
    var playerA: UUID
    var playerB: UUID
    var sharedMatches: Int                 // matches both participated in (completed only)

    // HEADLINE — who won the match outright
    var matchWinsA: Int
    var matchWinsB: Int
    var sharedTies: Int                    // both share rank 1

    // SECOND LINE — who finished ahead of whom (matters in 3+ player games
    // where neither won but one still placed above the other)
    var pairwiseAheadA: Int                // A's rank < B's rank in a shared match
    var pairwiseAheadB: Int
    var pairwiseTies: Int                  // equal rank

    var averageScoreA: Decimal             // A's avg score in shared matches
    var averageScoreB: Decimal
    var lastMeeting: Date?
    var currentStreakA: Int                // A's H2H streak (+ win / - loss), order-dependent
}
```

- **Match win** = `rank == 1` in a shared match (ties → both get a `sharedTie`, credited
  to neither's win column).
- **Pairwise-ahead** = lower `rank` number in the shared match. This is the substrate the
  deferred multiplayer Elo (§8) reuses, so it is worth computing well now.
- "You score 14 higher against Mom" is `averageScoreA` minus A's overall `PlayerSummary`
  average — computed in the App when both are on hand, not stored here.

### 5.3 Multi-player lineup view

For a 3+ player group at setup, the same idea one level up:

```
struct LineupRecord: Sendable {
    var playerIDs: [UUID]                  // the exact group, order-insensitive (sort before keying)
    var timesPlayed: Int
    var winsByPlayer: [UUID: Int]
    var groupHighScore: Decimal            // best finalScore any member posted in this lineup
}
```

Key on the **sorted** ID set so {A,B,C} matches regardless of seat order.

### 5.4 Records board (per Game definition)

```
struct RecordsBoard: Sendable {
    var gameID: UUID
    var allTimeHigh: (playerID: UUID, score: Decimal, matchID: UUID)?
    var highestLosingScore: (playerID: UUID, score: Decimal, matchID: UUID)?
    var lowestWinningScore: (playerID: UUID, score: Decimal, matchID: UUID)?
    var biggestBlowout: (matchID: UUID, margin: Decimal)?     // winner - runner-up
    var narrowestWin: (matchID: UUID, margin: Decimal)?
}
```

All generic (rank + finalScore). "Most Yatzies in one match" is Tier 2 (§6.3) because it
reads `yahtzeeBonus`, so it lives in the Yatzy records extension, not here.

### 5.5 Ordered-history helpers

Streaks and trends (§5.1) share one internal utility: **map a player's completed matches
to an ordered win/loss/placement sequence** by `startedAt`, then fold. Write it once,
reuse for `currentStreak`, `bestWinStreak`, `scoreTrend`, and the deferred Elo replay.

---

## 6. The catalog — Tier 2 (Yatzy-specific)

These read scorecard semantics and call the Domain scoring functions. They live beside
Yatzy scoring and ship in the Yatzy module of SyLib, not the generic core.

### 6.1 Category stats

```
struct CategoryStats: Sendable {
    var category: YatzyCategory
    var timesFilled: Int                   // value != nil (always all 13 in completed matches)
    var timesZeroed: Int                   // value == Decimal(0) — a taken zero / scratch
    var scratchRate: Double                // timesZeroed / timesFilled
    var averageValue: Decimal              // mean over all filled instances (zeros included)
    var averageWhenPositive: Decimal       // mean over value > 0 only
    var bestValue: Decimal
}
```

- **The `nil` vs `0` distinction pays rent here.** `scratchRate` tests `value == 0`, never
  a falsy/`<= 0` check. `nil` (unscored) cannot legitimately appear in a completed match;
  if it does, that's a data bug, not a scratch — count it separately, don't fold it in.
  "You scratch Large Straight 31% of the time" is exactly `scratchRate` for that category.

### 6.2 Upper-section stats

```
struct UpperSectionStats: Sendable {
    var averageUpperTotal: Decimal         // sum of Ones..Sixes per match, averaged
    var bonusRate: Double                  // fraction of matches reaching the 63 threshold (+35)
    var averageByFace: [YatzyCategory: Decimal]   // avg Sixes = 19.2, etc.
}
```

`averageByFace` against the per-face bonus pace (a category needs its face × 3 to be "on
pace" for the 63 bonus) is a nice coaching read if ever surfaced — kept OFF-by-default in
spirit, like the suggested-move highlight.

### 6.3 Yatzy / bonus stats

```
struct YatzyStats: Sendable {
    var yatzyHitRate: Double               // matches with Yatzy box == 50 / matches
    var careerYatzyCount: Int              // scored-50 boxes + bonus Yatzies
    var multiYatzyMatches: Int             // matches where yahtzeeBonus > 0
    var mostYatziesInOneMatch: Int         // 1 + max(yahtzeeBonus / 100) over matches
    var averageChance: Decimal             // sneaky dice-quality proxy — Chance is the raw sum
}
```

Bonus counts come straight off `Participant.yahtzeeBonus` (`/ 100` per extra) — no scoring
re-run. `mostYatziesInOneMatch` is the Tier-2 record that belongs with these, not on the
generic `RecordsBoard`.

### 6.4 Per-match progression replay (the underrated unlock)

`recordedAt` on every `ScoreEntry` (hardened per §7) means a completed match can be
**replayed**: sort all participants' entries by timestamp, and at each step run the
**existing pure Tier-2 contextual scoring** over the partial scorecard to get running
totals (upper bonus and Yahtzee bonus fold in correctly because the functions take
scorecard state, not just a cell).

```
struct MatchProgression: Sendable {
    var matchID: UUID
    var participants: [ParticipantProgression]
    var leadChanges: Int
    var largestLead: (playerID: UUID, margin: Decimal)?
    var comebackFrom: Decimal?             // largest deficit later overcome by the winner
}
struct ParticipantProgression: Sendable {
    var participantID: UUID
    var points: [ProgressionStep]          // ordered by recordedAt → a race-chart series
}
struct ProgressionStep: Sendable {
    var at: Date
    var category: YatzyCategory            // what was just scored
    var runningTotal: Decimal
}
```

This costs nothing new — it reuses the scoring functions on entry prefixes and reads only
persisted data. It yields the score-progression race chart, lead-change count, comeback
detection ("trailed by 40 with five categories left"), and per-player tendencies
("fills Yatzy at turn 11 on average"). `ParticipantProgression.points` maps directly to a
Swift Charts line series via §4.

---

## 7. `recordedAt` hardening (required)

**Decided: `recordedAt` is written unconditionally at the checkpoint flush** (the
category-scored boundary, data model §3.4). It is no longer best-effort.

- On every category score, stamp the new `ScoreEntry.recordedAt = Date()` as part of the
  same narrow upsert that already persists the entry, `yahtzeeBonus`, and advanced turn
  state.
- **`nil` now means "legacy data only"** — a match created before this hardening. §6.4
  progression treats a `nil`-timestamp match as un-replayable and falls back to showing
  the final scorecard without a progression chart. New matches always replay.

No schema change — `recordedAt` already exists on `ScoreEntry` (it's `Date?`); this only
guarantees it's populated going forward.

---

## 8. Deferred: Elo-style rating

**Decision: not in the 1.0 catalog, not in any UI, derivable retroactively when wanted.**

Elo assigns each player one rating number; when players meet, the gap predicts each one's
win probability, and the result nudges both ratings — beating a favorite earns a lot,
beating an underdog earns almost nothing. It is **fully generic** (needs only `rank`,
`finalScore` for ordering, and dates), so architecturally it is clean Tier-1 SyLib.

Two properties make deferral free:

- **It stays derivable with zero new schema.** You never store a mutable rating; you
  **replay completed matches in `startedAt` order** through the update formula. It is the
  *most* order-dependent stat (a rating depends on the sequence and the rating-at-the-time
  across players), but it is still compute-on-read over the ordered history — consistent
  with §2. Multiplayer decomposes into pairwise results, which is exactly the
  `pairwiseAhead` data from §5.2.
- **Deferred on ethos grounds, not technical ones.** A persistent competitive ladder — a
  number that drops when you lose to your kid — pulls against the calm, night-table
  identity. It's the same register that (rightly) kept the suggested-move highlight OFF by
  default.

**Revisit as an opt-in "competitive mode" later.** Because it's fully recoverable from
existing data, the day it's wanted it computes retroactively over every match ever
played — no migration, no capture-in-advance. Record it here so the option isn't
forgotten and no one wires rating capture into the schema prematurely.

---

## 9. Do NOT build yet — the `StatsProviding` protocol/registry

Mirror data model §4.5. Write Tier-2 Yatzy stats as **pure free functions** now (an
audience of one game). Design them so they *could* become a `StatsProviding` protocol
conformer — they take `Match`/`Participant`/`ScoreEntry` *values*, return value types,
touch no storage — but the protocol and any registry earn their shape only when a second
conformer (a ScoreIt game) exists at Step 2/3. Premature abstraction for one game is the
mistake to avoid.

The **Tier-1 generic functions**, by contrast, are already game-agnostic and belong in the
shared core as-is — they are the part that ships to ScoreIt v2 unchanged.

---

## 10. Presentation surfaces (App layer)

Render series (§4) into Swift Charts; keep it calm and quiet-by-default, consistent with
the product ethos.

- **Pre-game head-to-head card** — the signature moment. Match-wins headline, pairwise
  record second line, last meeting, current H2H streak. For 3+ players, the §5.3 lineup
  view.
- **Player profile** — `PlayerSummary` + score-trend chart + Tier-2 category breakdown.
- **Match history browser** — list of completed matches → per-match detail with the §6.4
  progression race chart; falls back gracefully for legacy `nil`-timestamp matches.
- **Post-game summary** — diff new stats against pre-match and surface "New personal best"
  and similar. Cheap (both snapshots are on hand) and on-brand **if kept quiet** — no
  confetti, in keeping with the "Yatzy! moment" restraint.

---

## 11. Implementation stages (ordered; each independently checkable)

Stats are pure domain, so **each stage is unit-testable against synthetic `[Match]`
fixtures before any UI exists.** Build the fixtures first (a handful of hand-authored
completed matches with known ranks/scores/scorecards) and assert exact numbers.

1. **Stats scaffolding + fixtures.** Create `Domain/Stats/` (Foundation-only) and a
   fixture set of completed `Match` values. *Check: `Domain/Stats/` compiles with only
   `import Foundation` + sibling domain; fixtures load.*
2. **Tier-1 generic core.** `PlayerSummary`, `HeadToHead`, `LineupRecord`, `RecordsBoard`,
   the ordered-history helper (§5.5). *Check: unit tests assert exact wins, win rate,
   pairwise-ahead, streaks, and records against fixtures.*
3. **Tier-2 Yatzy stats.** `CategoryStats`, `UpperSectionStats`, `YatzyStats`, reusing the
   Domain scoring functions. *Check: scratch rate distinguishes `0` from `nil`; bonus
   counts match `yahtzeeBonus`.*
4. **`recordedAt` hardening + progression replay.** Make the checkpoint flush stamp
   `recordedAt` unconditionally (§7); build `MatchProgression` via prefix replay. *Check:
   a freshly played, persisted match replays to a monotonic per-player series with correct
   running totals; a `nil`-timestamp fixture falls back cleanly.*
5. **Series types + chart mapping.** Emit `DatedPoint`/`Distribution`/`SeriesPoint` from
   the stats functions; map to Swift Charts in `App/Views/Stats/`. *Check: domain still
   imports no charting framework; App renders trend, distribution, and progression charts.*
6. **App surfaces (§10).** Pre-game H2H card, player profile, history browser + per-match
   detail, post-game diff. *Check: two players starting a game see their record; a
   finished match shows its progression.*

---

## 12. Invariants the agent must preserve (quick reference)

- Generic stats (Tier 1) import **only Foundation** and ship in SyLib. This is the
  extraction plan for stats; do not break it.
- **No charting framework in the domain.** Domain emits bare series value types; the App
  maps them.
- **Compute-on-read. No stored aggregates, no running-total tables.** Sort the input for
  order-dependent stats; never persist the result.
- Stats **outputs are not frozen schema** — they may evolve freely (nothing stores them).
  Only Match/Participant/ScoreEntry are frozen.
- **`abandoned` and `inProgress` matches are excluded** from every stat by default.
- `rank == 1` is the single definition of "match win"; ties share rank and are credited to
  neither player's win column.
- Scratch rate tests **`value == Decimal(0)`**, never a falsy/`<= 0` check; `nil` is
  unscored, not a scratch.
- **Dice/roll telemetry stays with the dice engine** and is never a stats input, never in
  `ScoreEntry.metadata`. `metadata` stays `nil` in SyFive 1.0.
- `recordedAt` is **written unconditionally at checkpoint**; `nil` means legacy data only.
- Per-match progression **reuses the pure scoring functions** on entry prefixes — no
  reimplementation.
- **Do not build the `StatsProviding` protocol/registry yet** — pure free functions until
  a second game exists.
- **Elo is deferred, derivable retroactively** via chronological replay; do not wire
  rating capture into the schema.
