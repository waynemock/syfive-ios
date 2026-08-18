# SyFive — Data Model & Architecture Design Spec

*Design authority for the Player + Game persistence system, the domain/persistence
layering, the scoring relocation, and the `GameModel` → `MatchController` refactor.*

> **Status:** Design agreed. This document is the implementation brief for the Xcode
> Claude agent. It describes a target architecture and a staged path to reach it. Read
> the whole document before starting; the stages interlock.

---

## 0. Why this exists (context the agent must not lose)

SyFive today has an excellent, correct in-memory Yatzy engine (`GameModel`) and no
persistence. This spec introduces a durable data model — Players, Games, Matches,
Participants, Scorecards — and reorganizes the code into three layers so that the
scoring engine can later be **extracted into a reusable Swift package (SPM)** with zero
rewrites.

Three roadmap steps set the constraints. They are the *reason* for decisions that would
otherwise look over-engineered:

1. **Ship SyFive 1.0** (Yatzy only).
2. **Extract** the Game+Player+Scoring system into a Swift package, reintegrate into SyFive.
3. **Rebuild ScoreIt v2** — a "score anything" app (dominoes, cards, cornhole, bidding
   games, golf) — on top of that same package.

Because Step 3 is a certainty (not a maybe), we **absorb schema complexity now** so the
package schema is frozen from SyFive's first release and ScoreIt v2 needs no migration.
We do **not** absorb behavioral complexity now — unused capabilities exist in the schema
but are never exercised by SyFive 1.0.

**The single most important rule in this document:** the domain layer must compile in a
target that cannot `import SwiftData`, `import SwiftUI`, or `import RealityKit`. If it
can't, it's in the wrong layer. That rule *is* the extraction plan.

---

## 1. The three-layer architecture

Every type belongs to exactly one layer, decided by one question: **what is it allowed
to import?**

| Layer | May import | Contains | Fate at Step 2 |
|---|---|---|---|
| **1 — Domain** | `Foundation` only | Value types, scoring functions, validation, winner-direction logic | **Becomes the SPM package** |
| **2 — Persistence** | `SwiftData` + Domain | `@Model` twins, conversion, checkpoint writes | Stays as app infra (or thin companion package) |
| **3 — App** | Everything (SwiftUI, RealityKit, Persistence) | Views, dice engine, `MatchController`, theming, settings | Stays in SyFive |

Dependency arrows point **downward only**: App → Persistence → Domain. Domain points at
nothing but Foundation. If that stays true, Step 2 is a file move, not a rewrite.

### 1.1 Folder structure (create this; it makes the boundary visible before it's enforced)

```
SyFive/
  Domain/                      ← Layer 1, FOUNDATION-ONLY (future SPM package)
    Values/                    Player, Team, Game, Match, Participant, ScoreEntry
    Enums/                     ScoreValue, MatchStatus, WinnerDirection, YatzyCategory
    Scoring/                   YatzyScoring (pure funcs), validation, winner direction
  Persistence/                 ← Layer 2, SwiftData + Domain
    Models/                    PlayerModel, TeamModel, GameModel*, MatchModel,
                               ParticipantModel, ScoreEntryModel
    Conversion/                toDomain() / hydrate(from:) / narrow write paths
    Seed/                      Built-in Game catalog seeding (Yatzy)
  App/                         ← Layer 3, everything
    Session/                   MatchController (was GameModel)
    Dice/                      RealityKit engine (STAYS HERE FOREVER — never in package)
    Views/ Theme/ Utilities/   (existing)
```

> **\*Naming collision, must resolve:** the *persistence twin* of the `Game` definition
> is `GameModel`, but the **existing** in-memory engine is also called `GameModel`. The
> existing engine is renamed to `MatchController` (Stage 4). Do that rename **before**
> introducing the persistence `GameModel`, or the two never coexist in the tree.

### 1.2 Naming convention (applies to the whole persistence layer)

- **Pure domain value type** keeps the clean name: `Player`, `Match`, `ScoreEntry`.
- **SwiftData persistence twin** gets the `Model` suffix: `PlayerModel`, `MatchModel`,
  `ScoreEntryModel`.
- Value **enums** stored as primitives inside a model (e.g. `MatchStatus`,
  `ScoreValue`) get **no twin** — they serialize into their parent. The suffix is only
  for persistent entities that need their own `@Model` class.

---

## 2. Domain value types (Layer 1)

These are `struct`s, `Codable`, `Hashable`, `Sendable`, Foundation-only. They are the
package's public API and the *currency* of all logic: scoring, ranking, and validation
operate on these, never on the `@Model` twins.

### 2.1 Supporting enums

```
enum MatchStatus: String, Codable, Sendable { case inProgress, completed, abandoned }

enum WinnerDirection: Sendable { case highest, lowest }   // declared by scoring system, never stored

enum ScoreValue: Codable, Hashable, Sendable {            // typed metadata primitives
    case number(Decimal)
    case flag(Bool)
    case text(String)
}
```

`ScoreValue` is the anti-ScoreIt decision: structured extras travel as *typed* values,
never as a delimited string. It has three cases now; more can be added additively. **In
SyFive 1.0 it is never used** — it exists for ScoreIt v2's bidding games (bid/made/set,
won/stolen).

### 2.2 ScoreEntry (frozen schema — do not change shape after release)

```
struct ScoreEntry: Codable, Hashable, Sendable {
    var slotKey: String                    // "sixes", "fullHouse", "round1", "total"
    var value: Decimal?                    // nil = unscored; 0 = deliberately scored zero
    var metadata: [String: ScoreValue]?    // nil for Yatzy; typed extras for other games
    var recordedAt: Date?
}
```

Three load-bearing decisions:

- **`value` is optional.** `nil` = category open/unscored; `Decimal(0)` = scratched
  (a real strategic zero). These are different game states. ScoreIt's `Double 0.0`
  could not tell them apart — this is that bug fixed by design. **Completeness checks
  test for non-nil, not for > 0.**
- **`metadata` is a dictionary, dormant in 1.0.** The scoring system that owns the slot
  keys is the schema authority: storage is permissive, the scoring system validates and
  interprets. SyFive writes `nil` here for all 13 categories and never reads it.
- **`Decimal`, not `Int`.** Exact, handles negatives/fractions some games need. Yatzy
  only needs integers; this is a small, deliberate tax for package generality.

### 2.3 Player (net-new — there is no Player concept in SyFive today)

> Today "players" are array indices rendered as `"P1"`, `"P2"`… There is nothing to
> migrate. This is greenfield.

```
struct Player: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String            // free text: "Xander", "Mom", "Player 2"
    var initials: String        // the scorecard-circle glyph, 1–2 chars, derived-with-override
    var themeID: String         // Theme.ThemeType.rawValue, e.g. "Midnight"
    var createdAt: Date
    var isArchived: Bool        // soft-delete; keeps historical Participants intact
}
```

- **Single free-text `name`** (no separate first/last, no nickname — "this isn't a bank
  account"). Departure from ScoreIt's `firstName`/`lastName`, intentional.
- **`initials` derive from `name` with override.** Pure function
  `deriveInitials(from:) -> String` in Layer 1: first letter of each word, cap at 2,
  uppercase; single-word names fall back to first two characters. Stored and editable so
  collisions (two "B"s) can be hand-resolved.
- **`themeID` is a String, not the `ThemeType` enum.** `ThemeType` lives in the App
  layer (it is inherently about SwiftUI `Color`). The domain stores the raw value string
  and the app maps it back for rendering. This keeps the domain Foundation-only.
- **The scorecard circle uses the player's theme accent** as its fill; no separate color
  field.

### 2.4 Team (frozen — SyFive 1.0 never instantiates one)

Ships now so the schema is complete for ScoreIt v2 (Bridge, Cornhole — team games with
recurring teams). A durable roster entity paralleling Player.

```
struct Team: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var initials: String
    var themeID: String
    var rosterPlayerIDs: [UUID]     // durable membership (domain refs by id, not object)
    var createdAt: Date
    var isArchived: Bool
}
```

### 2.5 Game (the reusable *definition* — a catalog entry, not a session)

In SyFive this is a catalog of exactly one: Yatzy, seeded at launch. Carries what is
intrinsic and reusable about a *kind* of game.

```
struct Game: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String                 // "Yatzy"
    var scoringSystemID: String      // "yatzy" — routes to the scoring engine
    var scoringSystemVersion: Int    // 1 — frozen schema, bumped only on stored-shape change
    var isBuiltIn: Bool              // seeded vs user-created (ScoreIt's includedWithApp)
    var supportsTeams: Bool          // false for Yatzy
    var maxParticipants: Int         // 0 = unlimited
    var rulesURL: String?
    var sortOrder: Int
    var createdAt: Date
}
```

Deliberate **omissions** vs. ScoreIt (these are corrections, not oversights):

- **No dice config** (`diceSides`/`diceNeeded`). Dice count is roll-UI presentation,
  which is App-layer and irrelevant to a scoring package. ScoreIt conflated the two.
- **No stored `highestScoreWins`.** Winner direction is *declared by the scoring system*
  (`WinnerDirection`), resolved from `scoringSystemID` — not stored, so it can't go
  stale. Yatzy declares `.highest`.

### 2.6 Match (one played *session* of a Game)

Self-describing so history renders correctly forever, even if the Game template is later
edited or the scoring system version-bumped.

```
struct Match: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var gameID: UUID                 // which definition this was a match of
    var scoringSystemID: String      // snapshotted from Game at creation
    var scoringSystemVersion: Int    // the version it was ACTUALLY scored with
    var status: MatchStatus          // inProgress | completed | abandoned
    var startedAt: Date
    var completedAt: Date?
    var participants: [Participant]  // ordered by seat
}
```

- **Snapshots `scoringSystemID` + `version`** rather than only pointing at the Game.
  Interpretation never depends on the template still existing/being unchanged. When
  ScoreIt v2 bumps a system's version, historical matches still know how they were
  scored.
- **`status` is a three-state enum**, not a `matchOver: Bool`. `abandoned` is distinct
  from `completed` so history/stats can exclude abandoned matches from averages.
- **No `number`/`nextMatchNumber` counter** (ScoreIt had one). A mutable counter on the
  template is a CloudKit hazard (concurrent-increment collisions under last-write-wins),
  and `startedAt` gives ordering. Human-facing match numbering, if ever wanted, is an
  additive field later.

### 2.7 Participant (the per-match join — Player/Team made uniform)

This is where the "uniform participant" pattern lands. ScoreIt used an abstract
`Opponent` supertype with `Player`/`Team` subclasses; SwiftData can't express that
cleanly, so we reproduce the **behavior** (a match holds one uniform list; each item is
an individual *or* a team) with composition instead of inheritance.

```
struct Participant: Codable, Hashable, Sendable, Identifiable {
    var id: UUID

    // per-match facts
    var seat: Int                  // turn order within THIS match, 0-based
    var finalScore: Decimal        // denormalized cached total (for cheap ranking/stats)
    var rank: Int                  // resolved at completion; 1 = winner; ties share rank
    var yatzyBonus: Int          // running +100-per-extra-Yatzy tally (see §4)

    // identity — EXACTLY ONE of these is non-nil (enforced in code, not schema)
    var playerID: UUID?
    var teamID: UUID?

    // display snapshot — frozen at match creation, survives roster edits/deletes
    var displayName: String
    var displayInitials: String
    var displayThemeID: String

    // scorecard
    var scoreEntries: [ScoreEntry]
}
```

- **The display snapshot is the heart of history-safety.** `displayName`,
  `displayInitials`, `displayThemeID` are *copied* at match creation. Rename a Player,
  re-theme them, or delete them from the roster, and every past match still renders who
  played and in what color. The `playerID`/`teamID` refs remain for **stats aggregation**
  ("all of Xander's matches") but **rendering never depends on them.** A deleted player
  leaves a fully intact match behind.
- **`yatzyBonus` is a field, not a ScoreEntry.** This mirrors today's
  `playerYatzyBonuses[i]` and keeps `metadata` dormant in 1.0. Confirmed decision.
- **Exactly-one-of invariant** (`playerID` xor `teamID`) is a domain-layer rule (CloudKit
  can't express it — both must be optional). Enforce via factory initializers
  `Participant(individual:)` / `Participant(team:)` and a `validate()` function. SyFive
  1.0 only ever calls the individual path; the team path is frozen schema.
- **`finalScore` / `rank` are denormalized** cached answers, resolved at completion, so
  sorting history and computing stats never re-runs scoring over every historical cell.
  The domain scoring functions remain the source of truth; these are the cache.
- **`seat`** *is* the turn order — a plain sortable Int, no separate "goes first"
  relationship (ScoreIt used one; unnecessary).

---

## 3. Persistence layer (Layer 2)

### 3.1 The `@Model` twins

One `@Model final class` per persistent entity, all **CloudKit-safe**: every property
has a default or is optional, no `@Attribute(.unique)`, relationships optional with
inverses, `UUID` stored as a plain property (identity, not a unique constraint —
same initials/name across family members is expected and fine).

Twins to create: `PlayerModel`, `TeamModel`, `GameModel`, `MatchModel`,
`ParticipantModel`, `ScoreEntryModel`. Enums store as their `rawValue`
(`MatchStatus` → String); `ScoreValue` dictionaries serialize via `Codable`.

> **Replace the `Item` stub.** `Item.swift` is the untouched Xcode template model and is
> the only entry in `SyFiveApp`'s `Schema([...])`. Remove `Item`, register the new twins.

### 3.2 Scorecard storage — blob vs rows is a Layer-2 choice, not part of the contract

The frozen contract is the `ScoreEntry` **value type**. How a participant's entries are
physically stored is free to differ per app:

- **SyFive:** store the participant's scorecard as an atomic `Codable` blob
  (`[ScoreEntry]` encoded on `ParticipantModel`). Scorecards are always read and written
  whole; blobbing means fewer CloudKit records and simpler writes. **Recommended for
  SyFive.**
- **ScoreIt v2:** may normalize into `ScoreEntryModel` rows if it wants per-entry
  queries. Same domain type either way.

Either choice, the domain `ScoreEntry` is identical. Do not let the storage choice leak
into the domain type.

### 3.3 Conversion boundary (lives on the model side — domain never knows models exist)

```
extension MatchModel {
    func toDomain() -> Match { /* map fields; sort participants by seat */ }
    func hydrate(from match: Match) { /* map fields back; reconcile children by id */ }
}
```

- **Reading down** (model → value) is trivial and total.
- **Enums cross as raw values**, with a defensive fallback on decode (unknown status
  string → `.inProgress`). This is the "garbage across app versions" tax, paid
  gracefully.
- **Writing up must reconcile by `id`, never blind-rebuild.** Rebuilding a graph orphans
  SwiftData identities and makes CloudKit resync the world. Match children to existing
  models by `id`: update changed, insert new, delete removed. **For SyFive this is
  narrow** (see §3.4) — do not build a general reconciliation engine; that's a Step 2/3
  concern if ScoreIt v2 needs it.

### 3.4 Persistence strategy — **checkpoint writes, no cross-device continuation**

> **Deliberate scope decision. The agent must NOT reintroduce continuous autosave or
> CloudKit live-conflict handling.** Cross-device mid-game continuation is intentionally
> out of scope: a game started elsewhere simply appears as an unfinished match the user
> may resume or ignore. Yatzy games are short; live handoff is not worth its cost. (This
> is a considered decision — the author has shipped live continuation elsewhere and chose
> against it here.)

What this buys, and how to implement it:

- **Live play stays in memory.** `MatchController` runs the active game in memory exactly
  as `GameModel` does today. Transient turn state — `diceValues`, `held`,
  `rollsRemaining`, `isRolling` — **never persists.**
- **Persist only at boundaries.** Flush to SwiftData on two events:
  1. **Category scored** — upsert the current participant's newly-scored `ScoreEntry`
     (+ updated `yatzyBonus`, + advanced turn/seat state on the match).
  2. **Match completed** — set `status = .completed`, `completedAt`, resolve
     `finalScore` + `rank` for all participants.
  These map directly onto the existing `score(category:)` turn boundary. The hot write
  path is "upsert ~1 changed entry + advance state," not "reconcile the graph on every
  interaction."
- **Resume is a plain query, not a sync.** An unfinished match is a `MatchModel` with
  `status == .inProgress`. Loading it hydrates a `MatchController`; ignoring it and
  starting fresh is equally valid. **No merge, no conflict resolution** — one device
  writes a given match at a time in practice, and last-write-wins at a turn boundary is
  acceptable for short games.
- **Resumed games restart the interrupted player's turn** (scorecard intact, dice reset)
  — the natural consequence of not persisting transient dice state, and cleaner UX than
  restoring mid-air dice.

---

## 4. Scoring engine (Layer 1) — relocation, not reimplementation

The current `GameModel` already implements **Classic Hasbro rules correctly**, including
the Yatzy bonus and joker forced-scoring. This work **moves the scoring math down into
Layer 1 as pure functions** and leaves orchestration in `MatchController`. It is a
refactor-with-relocation of proven logic, plus **one deliberate behavior change** (§4.3).

### 4.1 Two tiers

**Tier 1 — face value (pure, dice-only).** Unchanged from current logic. One function
over the 13 categories:

`faceValue(of category: YatzyCategory, dice: [Int]) -> Int`

Rules (identical to current `scoreValue` switch): Ones–Sixes = face × count; Three/Four
of a Kind = sum of all five if ≥3/≥4 alike else 0; Full House = 25 (strict 3+2) else 0;
Small Straight = 30; Large Straight = 40; Yatzy = 50 if five alike else 0; Chance = sum.

**Tier 2 — contextual (needs scorecard state).** Upper bonus, Yatzy bonus, joker
resolution, completeness, grand total, winner direction, validation. See §4.2–4.4.

Keep `faceValue` **honest and separate** from joker overrides. Joker values (which pay
fixed 25/30/40 for shapes a five-of-a-kind doesn't form) are a *separate* function layered
on top, never folded into `faceValue`.

### 4.2 Classic Hasbro Tier 2 (port existing logic)

- **Upper bonus:** sum of filled upper categories ≥ 63 → +35. (Current `upperBonus`.)
- **Yatzy bonus:** +100 per additional five-of-a-kind **while the Yatzy box holds a
  live 50**, accumulated on `Participant.yatzyBonus`. (Current
  `qualifiesForExtraYatzyBonus` + `playerYatzyBonuses`.)
- **Joker forced-scoring priority** (current `legalScoreCategories` + `jokerScoreValue`):
  1. matching upper box open → **forced** there (five 6s → Sixes = 30);
  2. else any open **lower** category, with FH/SS/LS paying fixed **25/30/40** despite
     shape, and 3/4-of-a-kind/Chance paying sum;
  3. else forced into a remaining box (often 0).
- **Completeness:** all 13 categories non-nil. The `yatzyBonus` tally is **not** a
  category and does not gate completion.
- **Grand total:** Σ filled categories + upper bonus + `yatzyBonus`.
- **Winner direction:** `.highest`, declared (not stored).

### 4.3 REQUIRED BEHAVIOR CHANGE — strict-Hasbro poison rule

**This is a real change from current code, not a refactor artifact. Apply it deliberately.**

Strict Hasbro: if the Yatzy box was **scratched to 0**, then *every* subsequent
five-of-a-kind is an ordinary roll — **no +100 bonus AND no joker forced-scoring.** It is
placed anywhere open and scored by normal face value.

- Current code gets the **bonus** half right (gated on `== 50`).
- Current code gets the **joker** half wrong: `isJokerRoll` fires on `scores[.yatzy] != nil`,
  which includes the scratched-0 case, so a poisoned box still triggers forced-scoring.

**Fix:** gate `isJokerRoll` on `scores[.yatzy] == 50` (not `!= nil`). Because both
`legalScoreCategories` and `jokerScoreValue` call `isJokerRoll`, this single-predicate
change corrects placement **and** scoring together. No other edits needed for the poison
rule.

**Add a regression test:** scratch Yatzy to 0, then roll a five-of-a-kind → assert no
forced upper category, no fixed FH/SS/LS joker values, no +100, normal placement allowed.

### 4.4 Validation (the scoring system is the schema authority)

Pure function, the seam that becomes a `ScoringSystem` protocol method at Step 2:

`validate(_ entry: ScoreEntry) -> ValidationResult`

For Yatzy: `slotKey` is a valid `YatzyCategory`; `value` is `nil` or a non-negative Int
within that category's achievable range (Chance ≤ 30, Full House ∈ {0,25}, Yatzy ∈ {0,50},
etc.); and **`metadata` must be nil** — Classic Yatzy declares it uses no structured
extras (the `yatzyBonus` tally lives on Participant, not in metadata). The validator
encodes the ruleset's schema; that's its whole point.

### 4.5 Do NOT build the `ScoringSystem` protocol/registry yet

Write Yatzy's rules as **pure free functions** now (an audience of one). Design them so
they *could* become a protocol conformer — they take dice/scorecard *values*, return
numbers/verdicts, touch no storage — but the protocol + registry earn their shape only
when the second conformer (a ScoreIt game) exists, at Step 2/3. Premature abstraction for
one game is the mistake to avoid here.

---

## 5. The `GameModel` → `MatchController` refactor (Layer 3)

### 5.1 Rename and re-slot

The existing `@Observable GameModel` becomes **`MatchController`** (App layer, Session/).
Under the new vocabulary it operates on a *Match*, so the rename corrects a now-wrong name
rather than merely dodging the collision with the persistence `GameModel`.

Blast radius is small and mechanical:
- `ContentView` owns it: `@State private var model = GameModel()` → `MatchController()`.
- `PlayerScoreCardView` / `ScorecardView` consume it via stable accessors
  (`playerNames`, `scores(for:)`, `canScore(category:for:)`, `totalScore(for:)`, etc.).
- These are type/property renames, **no logic change**.

### 5.2 What moves down, what stays

- **Move to Layer 1 (Domain/Scoring):** the pure scoring math — `scoreValue`/`faceValue`,
  `countByFace`, `hasKind`, `isFullHouse`, straight checks, `matchingUpperCategory`,
  `jokerScoreValue`, `jokerLowerSectionScore`, `legalScoreCategories`, upper-bonus and
  Yatzy-bonus rules, `isGameOver`/completeness, winner direction, validation. Also move
  the `ScoreCategory` enum → `YatzyCategory` in Domain/Enums (keep the `yatzy` case name
  and `"Yatzy"` display; the rules it obeys are Hasbro Classic).
- **Stays in `MatchController` (App):** *live session state and orchestration* — the
  current dice/held/rolls state, `isRolling`, `beginRoll`/`receiveDiceResults`,
  `currentPlayerIndex`/turn advance, undo, and the *decisions about when* to call the
  Layer-1 functions and when to checkpoint-persist. `MatchController` holds a live `Match`
  value, calls Domain scoring, and flushes through Layer 2 at boundaries (§3.4).
- **Dice engine stays in App forever.** The RealityKit engine and the entire fairness
  harness are App-only and **never enter the package.** They produce `[Int]` face values
  handed to Layer 1. The scoring package cannot tell physics dice from `Int.random` — that
  is the seam working correctly.

### 5.3 Player identity is new UI

Today the header "circle" (`PlayerScoreCardView`) is a **theme swatch / color picker**,
not an identity glyph — it contains no name or initials, and players are `"P\(i+1)"`.
Introducing Players means:
- the scorecard circle gains the participant's **`displayInitials`** (new),
- player headers show **`displayName`** instead of `"P1"` (new),
- new-game flow gains **CRUD of Players from a roster** and selection into the match
  (new).

This is additive UI, not a modification of an existing Player screen (there isn't one).

---

## 6. Theme bridging (keep the domain Foundation-only)

`Theme` / `Theme.ThemeType` live in the App layer and `import SwiftUI` (they are
`Color`-valued). Domain types must not reference the enum.

- Domain stores theme as **`themeID: String` = `Theme.ThemeType.rawValue`**
  (`"Midnight"`, `"Blossom"`, `"Ember"`, `"Forest"`, `"Ocean"`, `"Sunset"`, `"Paper"`).
- The App layer maps that string back to `Theme.ThemeType` for rendering. Provide a small
  App-layer helper `Theme.ThemeType(rawValue:)` fallback to `.midnight` on miss.
- The default-theme-by-index rotation currently in `GameModel.defaultTheme(for:)` moves to
  the App layer (roster/participant creation), since it produces a `ThemeType`.

---

## 7. Settings — deferred (placement principle only, no schema yet)

Do **not** design a Settings schema in this pass. Most settings back features not yet
built (audio, haptics). The principle to record:

- Settings default to a **SwiftData** model (single row, synced across devices) so choices
  follow the user — consistent with the author's other apps.
- Genuinely device-local settings (debug flags, per-device UI state) may live in
  `UserDefaults` (a `UserDefaults+Extension` already exists). Decide per-setting when the
  full list exists.
- The **suggested-move toggle** is the one setting whose logic already exists
  (`suggestedScores` is implemented; it lacks only a persisted on/off). It is the first
  and easiest resident when Settings is built.

---

## 8. Implementation stages (ordered; each is independently checkable)

1. **Domain scaffolding.** Create `Domain/` (Foundation-only). Add the value types (§2)
   and enums, `deriveInitials(from:)`, and the frozen `ScoreEntry`. No SwiftData, no
   SwiftUI. *Check: `Domain/` compiles with only `import Foundation`.*
2. **Relocate scoring.** Move the pure scoring math from `GameModel` into
   `Domain/Scoring` as free functions over dice/scorecard values; introduce `YatzyCategory`.
   Apply the **strict-Hasbro poison fix (§4.3)** and its regression test. *Check: scoring
   unit tests pass with no simulator, including the poison case.*
3. **Rename `GameModel` → `MatchController` (§5).** Mechanical; rewire `ContentView` and
   the scorecard views. `MatchController` now calls Domain scoring instead of holding it.
   *Check: app builds and plays identically to today.*
4. **Persistence models (§3.1–3.2).** Add the `@Model` twins, remove `Item`, register the
   new schema in `SyFiveApp`. Blob scorecards on `ParticipantModel`. Add conversion
   (`toDomain`/`hydrate`) and the **narrow** write paths only. *Check: a match can be
   created, scored, completed, persisted, and re-read.*
5. **Player/roster + Participant wiring (§2.3, §2.7, §5.3).** Seed the built-in Yatzy
   `Game`. Build roster CRUD and player selection into the new-game flow; snapshot display
   fields onto Participants; render `displayInitials` in the scorecard circle and
   `displayName` in headers. *Check: create players, start a match with them, see initials
   in circles, names in headers.*
6. **Checkpoint persistence + resume (§3.4).** Flush on category-scored and match-complete;
   surface `inProgress` matches as resumable. **No continuous autosave, no conflict
   handling.** *Check: kill the app mid-match, relaunch, resume the unfinished match (turn
   restarts, scorecard intact); or ignore it and start fresh.*

---

## 9. Invariants the agent must preserve (quick reference)

- Domain layer imports **only Foundation**. This is the extraction plan; do not break it.
- `ScoreEntry` shape is **frozen** — additive changes only, never reshape after release.
- `value == nil` ≠ `value == 0`. Completeness tests **non-nil**.
- `metadata` stays **nil** everywhere in SyFive 1.0.
- Winner direction is **declared, not stored**.
- Participant carries a **display snapshot**; rendering never depends on Player/Team refs.
- **No cross-device continuation**; no continuous autosave; no CloudKit conflict handling.
- Dice engine is **App-only, never in the package**; it communicates via `[Int]`.
- Strict-Hasbro poison: a scratched Yatzy (0) disables **both** bonus and joker.
- Do **not** build the `ScoringSystem` protocol/registry yet — pure functions for now.
