# SyFive — House Records Design Spec

*Design authority for the household records surface: title set, computation model,
tenure semantics, eligibility rules, and placement.*

> **Status:** Design agreed. This document is the implementation brief for the Xcode
> Claude agent. It introduces **no schema** — every value is derived from the existing
> persisted model. Read §2 (locked decisions) before writing any code; several rulings
> exist specifically to prevent a "reasonable" implementation that is wrong.

---

## 0. Supersessions

| Document | Effect |
|---|---|
| `04_PLAYER_INSIGHTS_DESIGN.md` | **Scoped, not superseded.** Player Insights remains per-player and neutral-to-affirming. House Records is a separate, house-level destination. Neither reads from the other; both compute independently from the same persisted matches. |
| `09_COMMENTATOR_DESIGN.md` | **Extended with a prohibition.** The commentator never references records, in any pack, at any level. See §6, Invariant 2. |
| `12_EXTERNAL_DISPLAY_DESIGN.md` | **Extended with an exclusion.** House Records never renders on the external display. Stage is for the table; records are a browsing destination. See §6, Invariant 3. |
| `02_DATAMODEL_DESIGN.md` | **Consumed, unchanged.** This feature adds no models, no fields, and no stored aggregates. It reads `MatchModel`, `ParticipantModel`, and the blobbed `[ScoreEntry]` exactly as they exist. |

---

## 1. Why this exists, and what it is *not*

A ranked leaderboard was considered and **rejected**. A sorted column is ordinal by
construction: someone is last every time they open it, and in a household roster that is
usually the person who plays least — often a kid or a partner. That is the one screen in
the app capable of making someone feel worse for having opened it, which is the opposite
of the product's stated ethos.

House Records replaces the ladder with **distributed titles**. Each record is a held
title showing a name, a number, and a date. With a well-mixed title set and a typical
four-player roster, nearly everyone holds something — and the person who holds nothing is
not *shown* holding nothing. They simply do not appear on that card.

Same underlying query layer. Entirely different emotional read.

---

## 2. Locked decisions

Each is a ruling, with the reasoning that produced it. The agent implements these; it
does not relitigate them.

### 2.1 Nothing ages out

Records are all-time. There is no rolling window, no "This Year" set, no expiry.

*Rationale:* permanence is the point. A high score held for three years is the feature,
not a stale-data problem. A rolling window would quietly delete exactly the moment people
care about most.

### 2.2 Archived players remain eligible

A soft-deleted (`isArchived == true`) Player may still hold a title. Rendering uses the
Participant **display snapshot** (`displayName`, `displayInitials`, `displayThemeID`),
never the live Player record — so a deleted player's title still renders correctly.

*Rationale:* records are history, and history includes people who left. If a "hide player
from stats" option is ever added, that is the mechanism for removing them — not archival.

### 2.3 Game Night guests are part of the house

A guest whose match landed on this device via the completion upsert is eligible for
titles here. No special-casing, no visual flag.

*Rationale:* they played at this table. See also Invariant 4 — this is why two devices
can legitimately disagree about who holds a record.

### 2.4 Ties list all holders, each with their own date

When two or more participants share a record value, all are listed. Each holder shows the
date they entered the current holding set. When those dates are identical — the common
case, two players tying within the same match — render **one** date for the card rather
than repeating it per name.

### 2.5 Silent recalculation

Titles change hands with no notification, no animation, no game-over acknowledgment. The
screen simply reflects current truth the next time it is opened.

*Rationale:* the game-over moment already has a deliberate, frequency-governed treatment
(`11_`). Records must not be pulled into it. This also means the gate-crossing transition
in §2.7 passes unremarked, which is desirable.

### 2.6 No anti-titles — permanent prohibition

No Worst Game. No Most Scratched Yatzys. No Coldest Dice. No title whose held state is a
negative attribute of the holder, under any framing, ever.

*Rationale:* this reads as fun in a design discussion and corrodes in a household. It is
recorded as an invariant (§6) precisely so a future contributor cannot rediscover it as a
good idea.

### 2.7 Average-type titles are gated at N = 10 completed matches

A participant is eligible for **Best Average** only after 10 completed matches. The
sample count is **always rendered on the card**.

*Rationale:* because nothing ages out, a single lucky 310 would otherwise hold Best
Average permanently on a sample of one. The gate is not a statistical claim — Yatzy score
standard deviation is large enough that even N=10 is noisy — it means *"you have actually
played."* The displayed N does the honest work the threshold cannot.

**Shrinkage / regression toward a house mean was considered and rejected.** It is
statistically nicer but would display a number that is not the player's actual average,
putting this card in direct contradiction with what Player Insights shows for the same
person. A record that disagrees with the stats screen is worse than a blunt threshold.

### 2.8 Rank-derived titles require multi-participant matches

Any title computed from `Participant.rank` must filter to matches where
`participants.count > 1`.

*Rationale:* a solo match resolves `rank = 1`. Ungated, "Most Wins" degrades into "how
often did you play alone." Score-derived titles have no such problem and use all
completed matches.

### 2.9 Retaking a title resets its tenure

If a holder loses a title and later reclaims it, "held since" is the **retake** date, not
the original. Tenure is current continuous holding, per sports convention.

*Side effect, considered desirable:* losing and reclaiming a title becomes a real event
rather than an accounting footnote.

### 2.10 Unclaimed titles are shown

Two distinct flavors, rendered differently:

| Flavor | Condition | Treatment |
|---|---|---|
| **Not yet achieved** | Metric exists, nobody has a qualifying value | `Unclaimed` |
| **Not yet eligible** | Gate unmet by every participant (Best Average only) | `Unclaimed — after 10 games` |

*Rationale:* the aspirational flavor needs no explanation. The gated flavor is unclaimed
for a reason the player cannot infer, so it carries a quiet house-level subtitle — a fact
about the title, not a callout about any person.

### 2.11 The screen is hidden until the first completed match

House Records does not appear in the menu until at least one `MatchStatus.completed`
match exists.

*Rationale:* six empty cards on a fresh install reads as an absence. After one match,
Best Game and Most Games Played are both claimed by construction, so the screen opens as
a beginning with a few invitations rather than a vacancy.

### 2.12 Placement: first item in the menu, its own destination

House Records is the **first menu item** and a standalone destination. It is not a
section inside Player Insights.

*Rationale:* Insights is per-player; Records is house-level. Different scope, different
screen.

### 2.13 The title list is App-layer for 1.0

Title definitions live in the App layer alongside the rest of SyFive's Yatzy-specific
presentation. They do **not** enter the Domain layer and do **not** become part of the
SyLib extraction in Step 2.

*Rationale:* "Most Yatzys" is Yatzy-specific. The *concept* of per-game records is a
future scoring-system responsibility — declared by the scoring system, like
`WinnerDirection` — but that abstraction earns its shape only when a second conformer
exists at Step 2/3. This mirrors the ruling in `02_` §2.5 that kept dice configuration
out of `Game`. **Absorb the thought now, not the abstraction.**

---

## 3. The title set

Eight titles, mixed deliberately across skill, luck, and participation so that no single
strong player sweeps the board.

### 3.1 Event records

A frozen moment. "Held since" is the `completedAt` of the match that set the record.

| Title | Metric | Axis |
|---|---|---|
| **Best Game** | Highest `finalScore` in a single completed match | Skill + luck |
| **Most Yatzys in a Game** | Highest five-of-a-kind count in a single match (§4.2) | Luck |
| **Best Upper Section** | Highest upper-section subtotal (Ones–Sixes, excluding the +35 bonus) in a single match | Skill |

### 3.2 Standing records

A live computation that changes hands as play continues. "Held since" requires the
chronological walk described in §4.3.

| Title | Metric | Gate | Axis |
|---|---|---|---|
| **Best Average** | Mean `finalScore` across completed matches | N ≥ 10 | Skill |
| **Most Wins** | Count of `rank == 1` | `participants.count > 1` | Competitive |
| **Most Games Played** | Count of completed matches | — | Participation |
| **Most Yatzys** | Career five-of-a-kind count (§4.2) | — | Luck + volume |
| **Most Upper Bonuses** | Count of matches where the upper subtotal reached 63 | — | Skill |

### 3.3 Card anatomy

Each card shows: title, holder name(s) with initials glyph in the holder's
`displayThemeID` accent, the record value, and the tenure date. Best Average
additionally shows its sample count inline — e.g. *"218 average over 34 games."*

**No runner-up, no second place, no partial ordering of any kind appears on a card.** A
card names who holds the title and nothing about who does not. This is the ruling that
keeps House Records from becoming a leaderboard by accretion.

---

## 4. Computation model

### 4.1 Source set and exclusions

Compute from `MatchModel` where `status == .completed`. **In-progress and abandoned
matches are excluded from every title**, including Most Games Played — consistent with
`02_` §2.6, where `abandoned` exists precisely so it can be excluded from history and
stats.

**No stored aggregates.** Every value here is compute-on-read, fully derivable and
retroactive, requiring zero new schema. Do not add counters, caches, or denormalized
record-holder fields. `finalScore` and `rank` are already denormalized at completion and
are read as-is; nothing further is stored.

### 4.2 Deriving a participant's Yatzy count for a match

```
yatzyCount = (scoreEntries["yatzy"].value == 50 ? 1 : 0) + (yatzyBonus / 100)
```

This is correct under the strict-Hasbro poison rule (`02_` §4.3): a scratched Yatzy
scores 0 and disables the bonus, so a poisoned card contributes 0 — which is the intended
reading.

**Performance note — this is the one pressure point.** Every other metric reads a
denormalized field. Yatzy counts require decoding each participant's blobbed
`[ScoreEntry]`. At household scale (hundreds of matches, single-digit players) this is
comfortably fast and should be left as a plain computation. If it ever becomes a problem,
that is the moment to revisit — and the answer would still not be a stored aggregate
without an explicit ruling. **Do not pre-optimize this into a counter.**

### 4.3 Tenure for standing records — the chronological walk

Event-record tenure is a field lookup. Standing-record tenure is not, and this is the
part most likely to be implemented wrongly by assumption.

To determine when a standing title was taken, replay completed matches in `completedAt`
order, recomputing the metric after each and recording every change to the **holder set**:

- A participant's "held since" is the date they **entered the current continuous holder
  set** — not the date the record value was first reached.
- When a second participant ties into an existing holder set, the incumbent **keeps**
  their original date; the newcomer gets the current date. This is why §2.4 specifies
  per-name dates.
- When a holder drops out and later returns, their date is the return (§2.9).

One pass over completed matches, in memory, at read time. Cheap at household scale and
still compute-on-read.

**A legitimate non-obvious transition:** a participant crossing the N = 10 gate can take
Best Average instantly, without having played a notably good game. This is correct
behavior. Silent recalculation (§2.5) means it passes unremarked.

---

## 5. Implementation stages

Ordered; each independently checkable.

1. **Records computation layer (App).** A pure, testable type that takes
   `[Match]` (domain values, completed only) and returns the resolved title set. No
   SwiftUI, no SwiftData — it consumes domain values so it can be unit-tested without a
   simulator. *Check: unit tests over synthetic match sets produce expected holders,
   values, and dates.*
2. **Tenure walk.** Implement §4.3 for the five standing records, including tie entry,
   retake reset, and gate-crossing transitions. *Check: the tenure test cases in §7 pass.*
3. **House Records screen.** Card list, holder rendering with theme accent, unclaimed
   states (both flavors), Best Average sample count. *Check: renders correctly for a
   roster with ties, an archived holder, and at least one unclaimed title.*
4. **Menu placement + visibility gate.** First menu item; hidden entirely until the first
   completed match. *Check: absent on a fresh install, present after one completed match.*
5. **Boundary enforcement.** Confirm the commentator has no records access and Stage does
   not route this screen. These are prohibitions, so the check is the absence of wiring.
   *Check: no reference to the records layer from the commentator or external-display
   code paths.*

---

## 6. Invariants the agent must preserve

1. **No anti-titles, ever.** No title whose held state is a negative attribute of the
   holder, under any framing.
2. **The commentator never references records.** Any pack, any level, any moment. Snark
   near *"you just lost Best Average to your daughter"* is precisely the
   people-not-dice line from `09_`. Hard prohibition, not a tuning parameter.
3. **House Records never renders on the external display.** Stage (`12_`) is for the
   table.
4. **Records are per-device by construction.** They are computed from completed matches
   in the local store. CloudKit syncs the user's own devices; a Game Night guest's device
   only ever holds the matches it participated in. **Two households will legitimately
   disagree about who holds a record. This is correct — do not "fix" it**, do not attempt
   to reconcile records across devices, do not add a shared records store.
5. **No stored aggregates.** Compute-on-read, fully retroactive, zero new schema.
6. **No new models, fields, or migrations.** This feature consumes `02_` as written.
7. **Only `status == .completed` matches count.** In-progress and abandoned are excluded
   everywhere.
8. **Rank-derived titles filter to `participants.count > 1`.**
9. **Rendering uses the Participant display snapshot**, never the live Player record.
10. **Nothing ages out.** No windows, no expiry, no seasonal reset.
11. **No runner-up or partial ordering on any card.**
12. **Title definitions stay App-layer** and never enter the SyLib package.

---

## 7. Validation matrix

| Scenario | Expected |
|---|---|
| Fresh install, no completed matches | House Records absent from menu |
| One completed solo match | Screen appears; Best Game and Most Games Played claimed; Most Wins **unclaimed** (solo excluded) |
| Solo matches only, many | Most Wins remains unclaimed regardless of count |
| Participant at 9 completed matches | Ineligible for Best Average; card shows `Unclaimed — after 10 games` if nobody qualifies |
| Participant crosses to 10 with a mediocre score | May take Best Average immediately; no notification; tenure date = that match |
| Two participants tie Best Game in the same match | Both listed; **single** date rendered |
| Two participants reach the same Best Average in different matches | Both listed; **per-name** dates |
| Incumbent tied into by a newcomer | Incumbent keeps original date; newcomer gets current date |
| Holder loses then reclaims a standing title | Tenure = reclaim date, not original |
| Holder is archived | Title still held; renders from display snapshot |
| Holder's Player record deleted | Title still held; renders from display snapshot |
| Match abandoned mid-play | Excluded from every title including Most Games Played |
| Yatzy scratched to 0, later five-of-a-kind rolled | Contributes 0 to both Yatzy titles (poison rule) |
| Game Night guest match completes on this device | Guest eligible for all titles |
| Same match viewed on host and guest devices | Record sets may differ; both correct |
| Commentator active during a title change | No commentary line fires |
| External display connected | House Records not routed to Stage |

---

## 8. Open decisions (Pops resolves — the agent must not)

1. **Title count and composition.** Eight is proposed in §3. Adding titles improves
   distribution but busies the screen; the skill/luck/participation balance is the
   constraint, not the number.
2. **Tenure rendering format.** Absolute (`March 2026`) or relative (`held 8 months`).
   Relative is warmer and ages more gracefully; absolute is unambiguous across long spans.
3. **Card glyph treatment.** Whether each title carries an icon, or the cards are
   typographic only. Ethos leans typographic.
4. **Screen ordering.** Whether cards are ordered by category (event, then standing), by
   prestige, or fixed by declaration order.
5. **Empty-state copy** for both unclaimed flavors, beyond the placeholder wording in
   §2.10.
6. **Whether a title ever appears inside Player Insights** as a per-player reflection
   ("you hold 2 house records"). Attractive, but it crosses the house-level /
   per-player boundary this spec just drew — deliberately parked rather than assumed.

---

## 9. Ledger rows — ready to paste into `00_DECISION_LEDGER.md`

| ID | Decision | Ruling | Source |
|---|---|---|---|
| HR-01 | Records surface form | Distributed titles ("House Records"), not a ranked leaderboard | `13_` §1 |
| HR-02 | Record expiry | None — all-time, nothing ages out | `13_` §2.1 |
| HR-03 | Archived player eligibility | Eligible; renders from display snapshot | `13_` §2.2 |
| HR-04 | Game Night guest eligibility | Eligible, unflagged | `13_` §2.3 |
| HR-05 | Tie handling | All holders listed; per-name dates, collapsed when identical | `13_` §2.4 |
| HR-06 | Title-change moment | Silent recalculation; no notification or celebration | `13_` §2.5 |
| HR-07 | Anti-titles | Permanently prohibited | `13_` §2.6 |
| HR-08 | Average-title gate | N ≥ 10 completed matches; sample count always rendered | `13_` §2.7 |
| HR-09 | Shrinkage / regression to house mean | Rejected — displayed value must match Player Insights | `13_` §2.7 |
| HR-10 | Rank-derived titles | Require `participants.count > 1` | `13_` §2.8 |
| HR-11 | Tenure on retake | Resets to reclaim date | `13_` §2.9 |
| HR-12 | Unclaimed titles | Shown; gated flavor carries an "after 10 games" subtitle | `13_` §2.10 |
| HR-13 | Screen visibility | Hidden until first completed match | `13_` §2.11 |
| HR-14 | Placement | First menu item, standalone destination | `13_` §2.12 |
| HR-15 | Title-list ownership | App layer for 1.0; per-game records a future scoring-system concern | `13_` §2.13 |
| HR-16 | Commentator boundary | Commentator never references records — hard prohibition | `13_` §6.2, extends `09_` |
| HR-17 | Stage boundary | House Records never renders on external display | `13_` §6.3, extends `12_` |
| HR-18 | Cross-device semantics | Records are per-device by construction; divergence is correct | `13_` §6.4 |
| HR-19 | Storage model | Compute-on-read; no stored aggregates, no new schema | `13_` §4.1, consistent with `02_` |
| HR-20 | Match status filter | Only `completed`; abandoned and in-progress excluded everywhere | `13_` §4.1 |
