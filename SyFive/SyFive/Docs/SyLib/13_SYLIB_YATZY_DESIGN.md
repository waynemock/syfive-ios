# SYLIB_YATZY_DESIGN

Extract SyFive's Yatzy scoring system and scorecard UI into a shared target, so
ScoreIt v2 can offer a Yatzy scorecard for real-dice play without reimplementing
the rules or the grid.

Two phases. **Phase 1 is unambiguous and should ship on its own.** Phase 2 needs
one thing built that does not exist yet.

---

## 0. This supersedes D-028

SyFive's ledger records Tier 2 — scoring systems stay app-side, only the generic
vocabulary goes in the package. That was correct with one app.

ScoreIt v2 wanting a Yatzy scorecard is exactly the trigger that changes it, the
same way a second Game Night consumer changed D-008. Update the ledger entry
rather than leaving two documents disagreeing.

**Naming:** `SyLibYatzy`. A game-specific module in a general library looks odd
until you remember `Game.scoringSystemID` was always designed as a plug point.
This is the first concrete scoring system, and it proves the plug works. Opt-in,
like `SyLibDice` — apps that do not offer Yatzy do not link it.

---

# Phase 1 — the domain

~960 lines of pure logic, zero UI, zero `MatchController`, zero SwiftData.

## 1.1 Target

```swift
.library(name: "SyLibYatzy", targets: ["SyLibYatzy"]),

.target(name: "SyLibYatzy", dependencies: ["SyLibScoring"]),
```

Every file below already imports exactly `Foundation` and `SyLibScoring`. No
other dependency should appear — if one does, that file does not belong here.

Add `"SyLibYatzy"` to the `SyLibTests` target dependencies.

## 1.2 What moves

| From | Lines |
|---|---:|
| `Domain/Enums/YatzyCategory.swift` | 45 |
| `Domain/Scoring/YatzyScoring.swift` | 171 |
| `Domain/Stats/` — all ten files | 742 |

The stats files are `CategoryAverages`, `CategoryStats`, `ClutchProfile`,
`MatchProgression`, `PlayerInsights`, `Proficiency`, `RiskProfile`,
`StyleSignature`, `UpperSectionStats`, `YatzyStats`.

`typealias YatzyScorecard = [YatzyCategory: Decimal]` moves with `YatzyScoring`.

**`ScoringSystemID` stays in SyFive.** It is the app's catalog of which scoring
systems it offers, not a property of Yatzy itself. ScoreIt declares its own.

⚠️ `YatzyScoring`'s functions are currently top-level and internal. Making them
public puts fifteen bare function names into every consumer's namespace —
`faceValue`, `upperBonus`, `isFullHouse`, `hasKind`. Wrap them in an
`public enum YatzyScoring { }` namespace. `fileprivate func jokerLowerValue`
stays private inside it.

## 1.3 What is new: manual-entry validation

This is the one part that is not a move, and it is why ScoreIt cannot just link
the existing code.

Every function in `YatzyScoring` is dice-shaped — `faceValue(of:dice:)`,
`legalCategories(dice:scorecard:)`, `isFullHouse(_:)`. Nothing answers the
question a number pad has to ask: *is 23 a legal entry for Ones?*

ScoreIt's user rolls real dice on a table and types a result. Without validation
it will happily accept 51 in the Yatzy box or 7 in Ones, and those errors survive
into stats and history. The rules belong next to the rules, not in ScoreIt.

```swift
public extension YatzyScoring {
    /// Every value that can legally be entered for a category, ascending.
    /// Use for a picker or to validate manual entry.
    static func legalValues(for category: YatzyCategory) -> [Int]

    /// Whether a manually entered value is legal for a category.
    static func isLegalValue(_ value: Int, for category: YatzyCategory) -> Bool
}
```

The rules, stated so they can be checked rather than inferred:

| Category | Legal values |
|---|---|
| Ones … Sixes | `0` and multiples of the face, up to 5× (Ones: 0–5; Sixes: 0,6,12,18,24,30) |
| Three of a Kind | `0`, or 5–30 |
| Four of a Kind | `0`, or 5–30 |
| Full House | `0` or `25` |
| Small Straight | `0` or `30` |
| Large Straight | `0` or `40` |
| Yatzy | `0` or `50` |
| Chance | `0`, or 5–30 |

⚠️ **Verify these against `faceValue(of:dice:)` before implementing** — the table
is derived from the standard rules, not read out of the existing code, and
SyFive's scoring is the authority. In particular confirm whether SyFive scores
Three/Four of a Kind as the sum of all five dice (5–30) or only the matching
dice; the two give different ranges.

Also confirm the joker rule's interaction: `jokerValue(of:dice:scorecard:)` can
produce a fixed score for a lower category during a joker roll. Manual entry has
no dice to detect a joker roll from, so ScoreIt cannot reproduce that path — the
user simply enters what the rules gave them. Note the limitation rather than
trying to model it.

## 1.4 SyFive changes

`import SyLibYatzy` wherever those types are used. `MatchController` gains the
import; `yatzyScorecard(for:)` at line 621 is unchanged.

Call sites become `YatzyScoring.upperBonus(...)` rather than bare `upperBonus(...)`
once namespaced. Mechanical, and the compiler finds every one.

## 1.5 Phase 1 verification

```bash
swift build && swift test
grep -rn "SwiftUI\|SwiftData\|MatchController\|import SyLibCore" Sources/SyLibYatzy
# must return nothing
```

- SyFive builds and every existing scoring test passes unchanged. `YatzyScoringTests`
  and `StatsTests` are the safety net for the whole move — they must not be edited
  to accommodate it.
- New tests for `legalValues` / `isLegalValue`: every category's boundaries,
  rejection of a value one above and one below each legal edge, and `0` legal
  everywhere.
- Play a full match in SyFive and confirm scores, bonuses, and grand total match
  what they did before.

---

# Phase 2 — the scorecard UI

Defer until Phase 1 has shipped and ScoreIt's entry interaction is real enough to
push back on this. The design below is the shape, not a brief.

## 2.1 The seam already exists

`ScoreRow.PlayerCell` is a value type and `ScoreRow` (200 lines) renders entirely
from it, knowing nothing about `MatchController`:

```swift
struct PlayerCell: Identifiable {
    let id: Int
    let value: Int?
    let suggested: Int
    let isBestSuggested: Bool
    let isAvailable: Bool
    let canScore: Bool
    let isCurrentPlayer: Bool
    let isWinner: Bool
    let onSelect: () -> Void
}
```

`PlayerScoreCardView` touches 25+ `model.` members, but they nearly all converge
in one 20-line `playerCell(for:)` function. **That function is the app-specific
part; everything downstream of it is portable.**

For ScoreIt: `suggested = 0`, `isBestSuggested = false`, and `onSelect` opens the
number pad instead of committing. The pulse animation goes inert on its own,
since `shouldPulse` is gated on `isBestSuggested`.

## 2.2 What moves

| Piece | Lines | Notes |
|---|---:|---|
| `ScoreRow` + `PlayerCell` | 200 | Already decoupled |
| `ScorecardView` carousel | ~205 | Layout math — see 2.3 |
| `PlayerScoreCardView` grid | ~350 of 550 | Minus header and previews |

`ScorecardView` is barely coupled — six `model.` members. The value is the layout
work: card width from available width, peek amount, the hidden Dynamic Type label
probe that measures the widest section label at the user's actual text size, and
the nested vertical/horizontal scroll sync.

⚠️ **`model.slotIDs` is the one thing that does not translate.** It is SyFive's
match-slot identity; ScoreIt's equivalent is a player ID. The carousel should take
`ids: [some Hashable]` rather than reaching for slot identity.

## 2.3 What stays app-side

**The card header** — theme picker, `PlayerEditSheet`, profile sheet,
`modelContext`, initials circle, winner-highlight animation. Same `seatTrailing`
treatment as Game Night: a `@ViewBuilder header:` slot.

**`playerCell(for:)`** — the mapping function, one per app.

**The number pad itself.** ScoreIt owns its entry UI; `SyLibYatzy` owns the rules
that tell it which values are legal. Do not put a number pad in the package before
two apps have one.

**Dice affordances** — `beginRoll`, `receiveDiceResults`, `suggestedScores`,
`suggestedCategory`, and the `FeelDirector` environment dependency all stay in
SyFive's mapping closure.

## 2.4 Likely shape

```swift
public struct YatzyScorecardCarousel<ID: Hashable, Header: View>: View {
    public init(
        ids: [ID],
        currentIndex: Int,
        winnerIndices: Set<Int>,
        isGameOver: Bool,
        availableWidth: CGFloat,
        accentColor: Color,
        cell: @escaping (Int, YatzyCategory) -> ScoreRow.PlayerCell,
        @ViewBuilder header: @escaping (Int) -> Header
    )
}
```

Two open questions for whenever this is scoped, both better answered with
ScoreIt's screen in front of you: whether the carousel owns the
scroll-to-current-player and winner-celebration behaviour or exposes them as
callbacks, and whether `canEditPlayers` / `PreGameGridView` is a SyFive concept or
a shared pre-game state.

---

## 3. Recommended order

1. **Phase 1.2** — move the domain, namespace `YatzyScoring`.
2. **Phase 1.3** — add manual-entry validation, with the rules table verified
   against SyFive's existing scoring first.
3. **Ship it.** ScoreIt can now compute and validate Yatzy correctly.
4. **Build ScoreIt's scorecard screen** against the domain, with its own UI.
5. **Phase 2** — extract the shared view layer once both screens exist and the
   differences are observed rather than predicted.

Step 4 before step 5 is deliberate. Two real screens will show whether one shared
card with an injected cell mapping is right, or whether they are two views over
shared rules that happen to look similar.
