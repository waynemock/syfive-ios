# SyFive — Player Insights Design Spec

*Design authority for the deep player-understanding layer: the insight catalog organized
by the question a player is really asking about themselves, the outcomes-vs-decisions
architectural spine that produces it, its tier placement in SyLib, and the presentation
principles that keep it calm.*

> **Status:** Design agreed. Implementation brief for the Xcode Claude agent. Builds on
> `02_DATAMODEL_DESIGN.md` (entities, scoring, `recordedAt`) and `03_STATS_DESIGN.md`
> (two-tier stats, progression replay, derivable/retroactive invariants). Read both first;
> this document assumes their vocabulary and does not restate it.

---

## 0. Why this exists (context the agent must not lose)

The basic stats in `03` answer **"how did I do"** — score, wins, records. This layer
answers the harder and more valuable question: **"how do I play"** — and, ultimately,
**"who am I as a player."** The deliverable of *understanding* is not a bigger table; it
is a player recognizing themselves in what the app reflects back.

One distinction organizes everything below, and it is already baked into the data model:

- **The final scorecard records outcomes.** It tells a player their score.
- **The progression replay (the `recordedAt` fill-order, `03` §6.4) records decisions.**
  It tells a player *who they are* — the order they commit categories, when they take
  risks, whether they close or fade.

Almost everything genuinely revealing lives in the second layer. That is precisely why the
`recordedAt` hardening was worth doing: it is the substrate for the insights no competitor
has, because they require the timestamped decision history we already persist.

Same constraints as the other specs: **generic insights compile Foundation-only and ship
in SyLib** (so ScoreIt v2 inherits them); everything is **derivable, retroactive, and needs
zero new schema.**

---

## 1. The architectural spine — outcomes vs decisions

Every insight is sourced from exactly one of the two layers. This table *is* the design;
the catalog in §3 elaborates it.

| Source | What it reads | Insights it produces | Novelty |
|---|---|---|---|
| **Final scorecard** | `finalScore`, `rank`, per-category `value` (nil/0/positive) | Proficiency, consistency, trajectory | Familiar shape |
| **Progression replay** | ordered `ScoreEntry.recordedAt` + running totals via Domain scoring | Style signature, risk timing, clutch | **Unique to SyFive** |

The style-signature and clutch reads are the ones no other Yatzy app can produce, because
they require the ordered fill-history, not just the final grid. **Treat them as the
centerpiece of "depth," not an add-on.**

### 1.1 The honesty constraint (a hard design guardrail)

**We can never compute "you left points on the table."** That requires knowing what was
*rollable* on a given turn, which is dice data — dice-engine telemetry, correctly
App-only and out of scope (`03` §3). Do not approximate it, do not fake it, do not imply
it. Proficiency (§3.1) must therefore be expressed **relative** (to the player's own
baseline and to the household), with exactly one **absolute** yardstick available for free:

- **The upper section has a rules-fixed bar.** The 63-point bonus threshold is
  three-of-each-face, so each upper category has a derivable "on-pace" value (face × 3).
  "Your Sixes average 17.8 — just under the 18 that keeps you on bonus pace" is fully
  honest, fully derivable, and genuinely actionable. It is the only coaching line we can
  state as fact rather than comparison. Use it; invent no others.

---

## 2. Invariants carried forward (from `03`, do not relitigate)

- **Two tiers.** Generic insights (`Match`/`Participant` only) ship in SyLib; Yatzy-specific
  insights (read `slotKey`/category meaning) ship in the Yatzy module. §4 places each.
- **Compute-on-read.** No stored aggregates; order-dependent insights sort the input.
- **Insight outputs are not frozen schema** — they are computed, never persisted, and may
  evolve freely. Only Match/Participant/ScoreEntry are frozen.
- **Derivable + retroactive.** Everything here works on all historical matches the day it
  ships. Zero new schema.
- **Dice telemetry stays with the dice engine.** Never a stats input, never in
  `metadata` (stays nil in 1.0).
- **No `StatsProviding` protocol yet** — pure free functions until a second game exists.

---

## 3. The insight catalog (organized by the player's real question)

Illustrative output types are `Sendable`, Foundation-only, `Decimal`-valued, and **not
frozen** (§2). Shapes are a starting point for the agent, free to evolve with the UI.

### 3.1 "What am I good at — where do I leak points?" — Proficiency

Per-category standing, expressed **relative** (own baseline + household) plus the single
**absolute** upper-pace yardstick (§1.1). Presented as a warm ranked read — "carries you"
vs "runs cold" — **not a radar/spider**, which is busy and invites the "I'm bad at that
spike" anxiety the ethos avoids.

```
struct Proficiency: Sendable {
    var strongest: [YatzyCategory]      // ranked vs own baseline and household
    var coldest: [YatzyCategory]
    var upperPaceNotes: [YatzyCategory: (average: Decimal, pace: Decimal)]  // §1.1
}
```

### 3.2 "What's my style?" — Style signature (progression; centerpiece candidate)

Read entirely from fill-order, no dice values needed. A stable strategic fingerprint:

- **Upper-first vs lower-first** tendency.
- **Bonus behavior** — chase and lock the upper bonus early, or backfill it late.
- **Yatzy timing** — *the tell that matters most.* Leaving the Yatzy box open until late is
  a gambler holding for the big hit; banking it at first opportunity is a banker.
- **Opening move** — the first category filled each game barely varies across a player's
  history; it is a genuine fingerprint.

```
struct StyleSignature: Sendable {
    var sectionOrder: SectionLean        // .upperFirst / .lowerFirst / .balanced
    var bonusApproach: BonusApproach     // .lockEarly / .backfill / .neglect
    var averageYatzyTurn: Double?        // nil if rarely filled early enough to read
    var typicalOpening: YatzyCategory?
}
```

### 3.3 "Am I a gambler or a banker?" — Risk profile (scratch behavior)

From *what* a player zeroes and *when*. The `nil`/`0` distinction (`03` §6.1) is what makes
this legible: `0` is a taken zero, and the progression tells an early strategic bail apart
from a forced end-of-card zero.

- **What they zero:** a cheap Ones vs the catastrophic Yatzy-poison zero (which, per the
  strict-Hasbro rule, kills all future bonus and joker — `02` §4.3). A player who scratches
  Yatzy early plays a fundamentally different game.
- **When they zero:** early and strategic vs forced at the end.

Pairs with §3.2's Yatzy timing into a single **risk-appetite** dimension — the
banker↔gambler axis surfaced in the profile mockup.

### 3.4 "Am I steady or streaky?" — Consistency

Score variance and distribution shape: a metronome ~240 player vs a boom-or-bust
180–320 player. Cheap (final scores only). Pair with a **variance-source** read — correlate
their best games against components:

- Are their big nights **bonus** games, **Yatzy-luck** games, or **consistently-strong-lower**
  games? This tells a player what their *ceiling actually depends on* — a real understanding
  payoff, not just a spread number.

```
struct ConsistencyProfile: Sendable {
    var scoreSpread: (min: Decimal, median: Decimal, max: Decimal)
    var variability: Variability          // .steady / .swingy (thresholded on stddev)
    var ceilingDependsOn: CeilingDriver   // .upperBonus / .yatzyLuck / .strongLower
}
```

### 3.5 "Do I close or fade?" — Clutch (progression)

Whether a player builds early leads and gets run down, or closes strong: comeback
frequency, and how the back half of their card scores relative to the front. This is where
progression replay earns its keep a second time. Consumes the `MatchProgression` from
`03` §6.4.

```
struct ClutchProfile: Sendable {
    var backHalfVsFront: Decimal          // avg back-6 points minus front-7, normalized
    var comebacksWon: Int                 // matches won after trailing by a margin
    var leadsSurrendered: Int             // matches lost after leading late
}
```

### 3.6 "Am I getting better?" — Trajectory

Understanding in the temporal sense — growth. Rolling average over time, personal-best
cadence, and **category-level drift** (Full House rate this month vs six months ago). The
most quietly motivating insight *without* tipping into a competitive ladder (that is the
deferred Elo, `03` §8 — keep them distinct). Emits `[DatedPoint]` series (`03` §4).

### 3.7 "What were my best moments?" — Highlights

A highlight reel: best game, best instance of each category, the match where the comeback
landed. The cozy, celebratory, **memory-not-metrics** register — the most on-brand insight
of all, and the natural closer for the profile surface.

### 3.8 "Who am I as a player?" — The plain-language read (synthesis)

The actual deliverable of "understanding." Not a table — a **sentence**: *"An upper-bonus
specialist who banks safely, rarely scratches, and closes strong."* Composed from the
metrics above, in Yatzy vocabulary.

**The ethos guardrail is non-negotiable:** every read is **neutral-to-affirming**.
Weaknesses appear as *texture*, never as "you're bad at X." Default quiet; depth is opt-in.
The moment the read feels like a nagging coach, it has violated the entire premise. This
read leads the profile surface (§5.1).

---

## 4. Tier placement (so ScoreIt v2 inherits the right half)

| Insight | Tier | Why |
|---|---|---|
| Consistency (spread/variability) | **1 generic** | final scores only |
| Trajectory (score trend, PB cadence) | **1 generic** | final scores over time |
| Clutch metrics (lead changes, comebacks) | **1 generic** | consume a progression series, game-agnostic once produced |
| Fill-order helper (opening, ordering) | **1 generic** | ordered entries exist in any game |
| Best-game highlight | **1 generic** | finalScore + date |
| Proficiency (category strong/cold, upper pace) | **2 Yatzy** | reads category meaning + the 63 rule |
| Style interpretation (banker/gambler, bonus, Yatzy timing) | **2 Yatzy** | Yatzy-specific vocabulary over the generic ordering |
| Risk profile (which zero is catastrophic) | **2 Yatzy** | Yatzy poison semantics |
| Variance-source, category drift, per-category highlights | **2 Yatzy** | component decomposition needs categories |
| Plain-language read generation | **2 Yatzy** | game vocabulary; consumes both tiers |

Key layering note: **the progression *replay* is Tier 2** (it needs the scoring functions to
compute running totals), but **the clutch *analysis* that runs on the resulting series is
Tier 1.** In ScoreIt v2, each game's scoring module produces its own progression; the
generic clutch analyzer runs on top of all of them unchanged. That seam is the pattern to
preserve.

---

## 5. Presentation principles (design intent for the agent)

These come from pressure-testing the surfaces and are **requirements, not suggestions**.
They are how "deep" stays "quiet." No screen is built in this project; these principles
govern the ones the agent builds.

### 5.1 The profile surface — lead with the sentence

The profile **opens with the plain-language read** (§3.8), not a number. Identity first,
headline stats demoted beneath it, the category grid **never** leading. Order the body by
novelty: decisions (style, risk, clutch — the progression material) above outcomes
(proficiency, consistency), closing on trajectory and highlights. The grid is a detail a
player descends into, never the greeting.

### 5.2 Calm, not a dashboard — one screen summarizes, sections deep-link

The profile is a **calm summary**. Each insight family (consistency/variance-source, clutch,
trajectory-over-months, per-category detail) **deep-links to its own view** rather than
growing the profile into a dashboard. One accent color, generous whitespace, weaknesses as
texture. Depth is reachable, not stacked on the front page.

### 5.3 The head-to-head card — even-handedness is a fairness requirement

The pre-game H2H card sits **between two players about to compete**, so it must not feel
like it roots for either. This is the calm ethos doing double duty as fairness. Each player
renders in their own theme accent; neither is visually privileged. **Match-wins is the
headline; pairwise-ahead is the quieter second line** (`03` §5.2). Even-handed layout is
part of the spec, not styling.

### 5.4 The ethos guardrail (applies to every surface)

Neutral-to-affirming always. Default quiet, opt-in for more. Never a nagging coach. A read
that would make a player feel worse about a pleasant evening of dice has failed regardless
of how accurate it is. Consistent with keeping the suggested-move highlight OFF by default
and the "Yatzy!" moment restrained.

---

## 6. Open decisions (author's call — not to be closed by the agent)

1. **Style signature placement.** Front-and-center as the profile centerpiece (the
   recommendation — it is the highest-novelty, highest-understanding item and sits on
   infrastructure already built), or tucked lower as one section among equals?
2. **Read timing — metrics now, sentences later?** Ship the underlying insight metrics
   first and layer the plain-language read (§3.8) once real distributions exist to
   calibrate archetype thresholds against (the recommendation — avoids archetypes
   misfiring on thin history). Or generate reads from day one?
3. **Read scope.** Is the plain-language synthesis (§3.8) in scope for the first insights
   pass at all, or is it explicitly a later layer on top of shipped metrics?

---

## 7. Invariants the agent must preserve (quick reference)

- Insights are sourced from **outcomes (final scorecard)** or **decisions (progression
  replay)** — §1 maps each. Style and clutch require the fill-order and are the unique
  differentiators.
- **Never compute "points left on the table."** No dice data exists to support it. Proficiency
  is relative + the single absolute upper-pace yardstick (§1.1).
- **Generic insights import only Foundation** and ship in SyLib; Yatzy-specific insights ship
  in the Yatzy module. §4 is authoritative on which is which.
- **Progression replay is Tier 2; clutch analysis over it is Tier 1.** Preserve that seam.
- **Compute-on-read; outputs are not frozen; everything is derivable and retroactive; zero
  new schema.**
- **Scratch analysis tests `value == 0`** (a taken zero), distinct from `nil` (unscored).
- **The profile leads with the sentence, never the grid.** Deep-link sections; do not build a
  dashboard.
- **The H2H card is even-handed by design** — match-wins headline, pairwise second line,
  neither player privileged.
- **Every read is neutral-to-affirming; weaknesses are texture, never "you're bad at X";
  default quiet, opt-in for depth.**
- **No `StatsProviding` protocol yet.** Dice telemetry stays with the dice engine. Elo stays
  deferred (`03` §8) and distinct from trajectory.
