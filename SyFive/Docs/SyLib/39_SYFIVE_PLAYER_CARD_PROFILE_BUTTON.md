# SyFive: the player card's profile button replaces its pencil, and pre-game stats fill its foot

**Status:** **Closed, 10 November 2026.** 39.1 to 39.8 done and checked; V1 to V4 pass; D-209 to D-212 filed.
Version 1.16, 10 November 2026.

**Scope:** `syfive-ios`, `Views/PlayerScoreCardView.swift` (39.1, 39.3, 39.5),
`Views/Stats/MatchDetailView.swift` (39.8, v1.14) and a new
`Views/Stats/PreGameStatsCard.swift` (39.5); `sylib-swift` (SyLibUI),
`IconButton` (39.2, v1.2; 39.4, v1.5). One project per session (`00A` v1.8).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md` (v1.13),
`00B_SYFIVE_GUARDRAILS.md`, this document. `00A` §6: the session's row goes at the top of §5. §7:
`00B`'s pinned command. §8: fix your own errors and warnings without stopping. No previews rendered,
no simulator or device sessions (`00A` v1.13 §3).

---

## 1. Why

Before the game starts, each player's card has two ways in, both from before SyFive had a player
editor and a profile with its own Edit (D-181, D-182):
- **A pencil** after the name (`header`, `model.canEditPlayers`), opening `PlayerEditSheet(.edit(…,
  matchSlot:))`. A small `.caption` glyph with no accessibility label, against the name.
- **"View profile ›"** at the foot of the card (`statsContent`), opening `PlayerProfileView` as a
  sheet with `matchSlot`. The profile's header pencil opens the same edit, seated in the same slot,
  so the card updates as before.

The pencil duplicates the profile's Edit. Pops, 10 November 2026: remove it, and make the profile
the header's one control beside the name.

## 2. Decision (Pops, 10 November 2026)

**2.1 A profile button where the pencil was** (D-209):
- **The pencil goes.** Editing a player is the profile's Edit (and Players').
- **`IconButton("person.crop.circle")`** (SyLibUI, the default `.standard` context and `.regular`
  size), right after the name, where the pencil sat, opening the same `PlayerProfileView` sheet as
  View profile does today (`showsProfile = true`). Kept away from the remove X at the right edge, which
  unseats a player with no undo.
- **Before the game only:** shown when `model.canEditPlayers`, as the pencil was and as View profile
  is today; never during or after play.
- **Only for a roster player:** shown when `model.playerIDs[playerIndex]` is non-nil, as View profile.
- **VoiceOver:** `.accessibilityLabel("Profile, \(name)")`, so it reads as the player's profile, not
  the symbol's name.

**2.2 The card's foot loses View profile** (Pops): `statsContent` keeps `HeadToHeadCard` (exactly two
players) and nothing else. With one, three or four players the area below the header is empty before
the game: Pops, "fine as is". **Superseded by §2.5 (v1.3).** **"Add to roster for stats"** goes too: it shows only for a seat with no
roster player, which since `38` only previews have.

**2.4 A small `IconButton`** (D-210; Pops, 10 November 2026, on device after 39.1). At `.regular`
(a bold `.title2` symbol at large image scale) the profile button is too big beside a `.title3` name.
- **`IconButton.Size` gains `.small`**: a bold `.body` symbol at `.large` image scale (v1.7: Pops
  changed it from `.medium` after 39.4, too small on device), roughly the
  name's size. Its badge dot, count padding and offset are 0.75 of `.regular`'s; the count keeps bold
  `.caption2`. `.regular` and `.large` are unchanged.
- **The touch area is unchanged:** in `.standard` context still at least 44 × 44 pt, by context, not
  size. So the symbol shrinks, not the target.
- **Additive:** no app switches over `IconButton.Size`; SydeTwo's two `.large` buttons and every
  default are untouched.
- **SyFive's profile button uses it:** `IconButton("person.crop.circle", size: .small)`.

**2.5 Pre-game stats in the card's foot** (D-211; Pops, 10 November 2026). Before the game, below the
header, each card shows something about its player for the table it's at, from completed games
(one row per match id, `onePerMatchID()`, as the profile and Head to Head read them):
- **Solo (one player):** the player's **solo** record, one row of three: **Games**, **Best**, **Avg**;
  then **"Score to beat: N"**, N their best solo score.
- **Two players:** Head to Head, unchanged.
- **Three or four players:** the player's **multiplayer** record, one row of three: **Games**,
  **Wins**, **Win %**.
- **Then, at every table size, one insight line:** SyLib's `plainLanguageRead(playerInsights(…))`,
  the sentence the profile opens with, from the same games as the row (solo games at a solo table,
  multiplayer games otherwise, as the profile's two modes split them). It's nil under three games, or
  when there's nothing to say; then no line. At most two lines, footnote, secondary.
- **No games of that kind yet:** "First game, no stats yet." in place of the row and the target.
- The numbers use the profile's figures (`playerSummary`), so the card and the profile always agree.
- **Before the game only**, as the rest of the foot (`statsContent`, `model.canEditPlayers`); roster
  players only (every pre-game seat since `38`).

**2.6 `IconButton` takes a weight** (D-212; Pops, 10 November 2026). Even at `.small`, the bold
symbol is too heavy for the card.
- **`weight: Font.Weight = .bold`** on both initializers, after `size`: the symbol's weight, for every
  size. The default keeps every button as it is. The badge's count stays bold.
- **SyFive's profile button passes `.regular`:** `IconButton("person.crop.circle", size: .small,
  weight: .regular)`. **Done by Pops, 10 November 2026**, after 39.4 (not in 39.5).

**2.7 No insight line** (Pops, 10 November 2026, on device after 39.5: "just too much"; amends §2.5).
The card's foot shows the figures only: solo, Games, Best, Avg and "Score to beat"; three or four,
Games, Wins, Win %; none yet, "First game, no stats yet."; two players, Head to Head alone, as before
39.5. The profile keeps its opening sentence.

**2.8 The insight line, for a solo table only** (Pops, 10 November 2026: "ok for the extra info,
does not feel cluttered"; amends §2.7). Under a solo player's figures and "Score to beat", the
profile's opening sentence from their **solo** games: `plainLanguageRead(playerInsights(…))`, nil
under three games or when there's nothing to say, then no line; `.footnote`, secondary, at most two
lines, as 39.5 drew it. Three or four players, two players and "First game" show none.

**2.9 Match detail's places don't wrap** (Pops, 10 November 2026, on iPad: "1st" drew as "1s" over
"t"). Not the card, but found alongside it. `MatchDetailView.finalScoresCard` draws each place
(`participant.rank.ordinal`) in a column fixed at 32 pt, which the larger text outgrows.
- **The rows become a `Grid`:** place, name, then the score trailing, so the place column is as wide
  as its widest entry ("4th") at any text size, and the names line up.
- **A place never wraps:** `.lineLimit(1)` on it.
- Fonts, colours, order and the card's heading are unchanged.

**2.3 Considered and excluded**

| Excluded | Why |
|---|---|
| The profile button beside the X | Too close to Remove, which can't be undone |
| Tapping the initials and name to open the profile | Hidden; nothing says it's tappable |
| Showing the button during play and after | The header stays about the score once the game starts (Pops) |
| Leaving the foot empty with one, three or four players | Was §2.2's "fine as is"; replaced by §2.5 (Pops) |
| The full profile badge grid in the card | Too big for a card; one row of three, the profile has the rest |
| A different insight each time, or several | One stable line; the profile has them all |
| A scaled fixed width for the place column (`@ScaledMetric`) | Still a guessed width; a `Grid` sizes to the text |
| The insight line at a multiplayer table | Too much beside a table's figures (Pops, §2.7, §2.8); the profile has it |

---

## 3. Task 39.1 · The profile button

- **Inputs:** §2; `Views/PlayerScoreCardView.swift`; SyLib `Docs/UI_COMPONENTS.md` (`IconButton`), read
  only.
- **Change, `Views/PlayerScoreCardView.swift`:**
  - In `header`, the `if model.canEditPlayers` pencil `Button` becomes, in the same place:
    `if model.canEditPlayers, model.playerIDs[playerIndex] != nil { IconButton("person.crop.circle")
    { showsProfile = true }.accessibilityLabel("Profile, \(model.playerNames[playerIndex])") }`,
    with a comment citing 39 §2.1.
  - `showsPlayerEdit`, its `.sheet(item:)` and `fetchPlayerEditMode()` go, if nothing else uses them.
  - In `statsContent`, the `if viewerID != nil { … View profile … } else { … Add to roster for stats …
    }` block goes; `HeadToHeadCard` stays as it is.
  - The `.sheet(isPresented: $showsProfile)` stays exactly as it is.
- **Tests:** none (a view).
- **Must not touch:** the remove X; the score content; `PlayerProfileView`; `PlayerEditSheet`;
  `HeadToHeadCard`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 30 tests
  (33 runs), from the result bundle; `grep -n "pencil\|View profile\|Add to roster"
  Views/PlayerScoreCardView.swift` finds nothing; the row is at the top of §5; Pops checks V1 and V2.

### Task 39.2 · SyLib: `IconButton.Size.small` (§2.4)

- **A SyLib session.** Inputs: §2.4; `Sources/SyLibUI/Components/IconButton.swift`; `Docs/UI_COMPONENTS.md`
  (`IconButton`).
- **Change, `IconButton.swift`:**
  - `case small` in `Size`, first, with a doc comment on each case (`.small`: a bold `.body` symbol at
    `.medium` image scale, for an icon beside body-sized text; `.regular`; `.large`).
  - The size-dependent values by a `switch size` instead of `size == .large ? … : …`: symbol font
    (`.body` / `.title2` / `.largeTitle`, all bold), image scale (`.medium` for `.small`, `.large`
    otherwise), `badgeScale` (0.75 / 1.0 / 1.5), and the count's font (bold `.caption2` for `.small`
    and `.regular`, bold `.caption` for `.large`). `.regular` and `.large` draw exactly as now.
  - The touch area is unchanged (`minimumTouchSide(for:)`, by context).
  - The "Toolbar" preview, or a new one beside it, shows a `.small` button. Previews stay and compile;
    don't render them.
- **Docs, `UI_COMPONENTS.md`,** `IconButton`: the signature's `Size`, the size paragraph with `.small`,
  and an example (`IconButton("person.crop.circle", size: .small) { … }`).
- **Tests:** none (a view; the touch rule is already tested and unchanged).
- **Must not touch:** `.regular` and `.large`; `Context`; the touch area; every other component;
  SyFive, Score It \*, Syderal and SydeTwo (build SyFive, Score It \* and Syderal only).
- **Done when:** SyLib's suite passes at its baseline, 1596 tests (1671 runs), from the result bundle;
  Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at the top of §5.

### Task 39.3 · SyFive: the small profile button (§2.4)

- **Depends on 39.2.**
- **Change, `Views/PlayerScoreCardView.swift`:** `IconButton("person.crop.circle", size: .small)`;
  nothing else.
- **Must not touch:** anything else; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 30 tests
  (33 runs), from the result bundle; the row is at the top of §5; Pops checks V1 and V2.

### Task 39.4 · SyLib: `IconButton`'s weight (§2.6)

- **A SyLib session.** Inputs: §2.6; `Sources/SyLibUI/Components/IconButton.swift`;
  `Docs/UI_COMPONENTS.md` (`IconButton`).
- **Change, `IconButton.swift`:** `weight: Font.Weight = .bold` on both initializers, right after
  `size`, stored and documented; `symbolFont` applies it to the size's font (`.body`, `.title2`,
  `.largeTitle`) in place of the fixed `.bold`. `countFont` unchanged (bold). The "Small" preview adds a
  `.small`, `weight: .regular` profile button beside its bold one. Previews stay and compile; don't
  render them.
- **Docs, `UI_COMPONENTS.md`,** `IconButton`: both signatures and a sentence on `weight`, with the
  `.small`, `.regular` example.
- **Tests:** none (a view).
- **Must not touch:** sizes, `Context`, the touch area, badges; every other component; SyFive, Score
  It \*, Syderal and SydeTwo (build SyFive, Score It \* and Syderal only).
- **Done when:** SyLib's suite passes at its baseline, 1596 tests (1671 runs), from the result bundle;
  Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at the top of §5.

### Task 39.5 · SyFive: pre-game stats in the card's foot (§2.5, §2.6)

- **Depends on 39.3 and 39.4.** Inputs: §2.5, §2.6; `Views/PlayerScoreCardView.swift` (`statsContent`);
  `Views/Stats/HeadToHeadCard.swift` (the pattern: its own `@Query` of completed matches,
  `onePerMatchID()`); `Views/Stats/PlayerProfileView.swift` (its `summary`, `insights`, solo and
  multiplayer split, `soloBadges` and the `displayInt` note), read only.
- **New, `Views/Stats/PreGameStatsCard.swift`:**
  - `PreGameStatsCard(playerID: UUID, playerCount: Int, theme: SyTheme)`, a view with its own
    `@Query(filter: statusRaw == "completed", sort: startedAt)` of `MatchModel`, read through
    `onePerMatchID()` and `toDomain()`, as `HeadToHeadCard`.
  - The choosing is a pure, internal static function for tests, e.g.
    `static func content(playerID: UUID, playerCount: Int, matches: [Match]) -> Content`, where
    `Content` is `.solo(games:best:average:)`, `.table(games:wins:winPercent:)` or `.firstGame`, plus
    the insight `String?`. Solo games are those with one participant, multiplayer games more than one
    (the profile's split). Scores as whole numbers through `Double`, as the profile's `displayInt`
    does, and why.
  - Draws one row of three figures (value bold `.headline` in `theme.secondaryAccent`, title `.caption2`
    secondary, each `frame(maxWidth: .infinity)`, on `theme.cellBackgroundColor` in a rounded rectangle,
    smaller than the profile's badges); for solo, "Score to beat: N" under it (`.subheadline`); then the
    insight (`.footnote`, secondary, `lineLimit(2)`), when there is one. `.firstGame` draws "First game,
    no stats yet." (`.footnote`, secondary) and the insight is nil.
  - VoiceOver: each figure reads as one element ("Games, 12").
- **The header is already done (§2.6):** Pops set the profile button's `weight: .regular` himself.
  Leave the header as it is.
- **Change, `Views/PlayerScoreCardView.swift`, `statsContent`:**
  - With exactly two roster players: `HeadToHeadCard` as now, then the insight line for this player
    (multiplayer games). Easiest by `PreGameStatsCard` drawing only its insight when `playerCount == 2`,
    or a small shared view; the session picks one and says which.
  - Otherwise, with a roster player: `PreGameStatsCard(playerID:playerCount:theme:)`.
  - `statsContent`'s `theme` parameter is used again.
- **Tests, + 3,** `SyFiveTests/PreGameStatsTests.swift`, on the static function with `Match` values:
  (1) a solo table with solo games gives `.solo` with games, best and average from solo games only,
  ignoring multiplayer ones; (2) a three-player table gives `.table` from multiplayer games only;
  (3) no games of that kind gives `.firstGame` and no insight, and fewer than three games give no
  insight.
- **Must not touch:** `HeadToHeadCard`; `PlayerProfileView`; the header; the
  score content; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 30 tests
  plus the 3 new (33 tests), from the result bundle; the row is at the top of §5; Pops checks V3.

### Task 39.6 · SyFive: no insight line (§2.7)

- **Inputs:** §2.7; `Views/Stats/PreGameStatsCard.swift`; `Views/PlayerScoreCardView.swift`
  (`statsContent`); `SyFiveTests/PreGameStatsTests.swift`.
- **Change, `PreGameStatsCard.swift`:** the insight goes: `content(playerID:playerCount:matches:)`
  returns the `Record` alone (drop `Content` and its `insight`, or keep `Content` with only `record`,
  the session's choice, said in the row), no `playerInsights` or `plainLanguageRead`, and no insight
  `Text`. The two-player branch (insight only) goes, so the card always draws its record. Remove
  imports nothing else needs (likely `SyLibYatzy`). Doc comments say what the card shows now.
- **Change, `PlayerScoreCardView.swift`, `statsContent`:** with two roster players, `HeadToHeadCard`
  alone, as before 39.5; otherwise `PreGameStatsCard` as now.
- **Tests:** the same three, without insight: drop the insight expectations, and test 3 checks that
  a table with no games of its kind (a solo table with only multiplayer games, and the reverse) gives
  `.firstGame`. Still 3.
- **Must not touch:** the record's figures, layout and VoiceOver; the header; `HeadToHeadCard`;
  `PlayerProfileView`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 33 tests
  (36 runs), from the result bundle; `grep -n "insight\|plainLanguageRead"
  Views/Stats/PreGameStatsCard.swift Views/PlayerScoreCardView.swift` finds nothing; the row is at the
  top of §5; Pops checks V3.

### Task 39.7 · SyFive: the insight line for a solo table (§2.8)

- **Inputs:** §2.8; `Views/Stats/PreGameStatsCard.swift`; `SyFiveTests/PreGameStatsTests.swift`;
  for the drawing, 39.5's version of the card in §5's 39.5 row.
- **Change, `PreGameStatsCard.swift`:** `.solo` carries the insight:
  `.solo(games:best:average:insight: String?)`, from `playerInsights(playerID:matches:)` over the solo
  games, through `plainLanguageRead`. `.table` and `.firstGame` unchanged. The solo branch draws it
  under "Score to beat" when non-nil: `.footnote`, secondary, `lineLimit(2)`, leading. Import
  `SyLibYatzy` again. Doc comments say the insight is solo only.
- **Tests:** the same three; test 1 also expects an insight with three or more solo games and none
  with fewer. Still 3.
- **Must not touch:** `.table`, `.firstGame`; the figures, layout and VoiceOver; `statsContent`; the
  header; `HeadToHeadCard`; `PlayerProfileView`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 33 tests
  (36 runs), from the result bundle; the row is at the top of §5; Pops checks V3.

### Task 39.8 · SyFive: match detail's place column (§2.9)

- **Inputs:** §2.9; `Views/Stats/MatchDetailView.swift` (`finalScoresCard`).
- **Change:** `finalScoresCard`'s `ForEach` of `HStack`s becomes a `Grid(alignment: .leading)` with a
  `GridRow` per participant: the place (`.lineLimit(1)`, its font and colour as now, no fixed
  `frame(width: 32)`), the name, and the score, which takes the remaining width and sits trailing
  (`.gridColumnAlignment(.trailing)`, `.frame(maxWidth: .infinity, alignment: .trailing)`). The
  heading stays above the grid; spacing as near today's as the grid allows.
- **Tests:** none (a view).
- **Must not touch:** the rest of `MatchDetailView`; other views; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 33 tests
  (36 runs), from the result bundle; the row is at the top of §5; Pops checks V4.

---

## 4. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | After 39.3, before the game, on iPhone and iPad: look at each player's card; tap the profile button; in the profile, tap Edit and rename the player | A person-in-circle button right after the name, about the name's size, not larger, and not bold (after 39.5), no pencil, the X unchanged at the right; no View profile at the foot. The button opens the profile sheet; the rename shows on the card. Two players: Head to Head still at the foot |
| V2 | Start the game by rolling; with VoiceOver on, before the game, focus the button | The button is gone once the game starts. VoiceOver reads "Profile, <name>" |
| V3 | After 39.7, before the game: a solo game for a player with solo games, then one with none; a three- or four-player table; a two-player table. Compare with each player's profile | Solo: Games, Best, Avg, then "Score to beat" with their solo best. No solo games: "First game, no stats yet." Three or four: Games, Wins, Win % each. Two: Head to Head alone, as before. Under a solo player's figures, the profile's opening sentence once they have three solo games or more, at most two lines; no sentence at any other table. The numbers match the profile's. Gone once the game starts |
| V4 | After 39.8, on iPad and iPhone at the largest text size SyFive allows: open a four-player game's detail from Match History | "1st" to "4th" each on one line; names line up in one column; scores at the trailing edge, as before |

## 5. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| V1 to V4 | 10 Nov 2026 | **pass** (Pops, on device) | — | The small, regular-weight profile button; VoiceOver; the pre-game stats at every table size; match detail's places on one line. 39 closed; ledger rows filed |
| 39.8 | 10 Nov 2026 | complete; V4 is Pops's, on device. **Checked by Claude against the tree**: `finalScoresCard` is a `Grid` (place with `.lineLimit(1)` and no fixed width, name, score trailing); fonts and colours unchanged; nothing else in the file. **Follow-up outside 39:** `SyFiveUITests.testLaunchPerformance()` crashed the app in the 39.6 and 39.8 baselines and passed after each; a launch crash under the performance test. Pops: it happens only in the agent's test runs; not a concern | **After:** `Passed`, 33 tests (36 runs), 33 passed, 0 failed, 0 skipped; 0 warnings, 0 errors. **Baseline (before any edit):** `Failed`, 33 tests (36 runs), 32 passed, 1 failed. The failure was `SyFiveUITests.testLaunchPerformance()`, "com.syzygysoftwerksllc.SyFive crashed", the same UI-test flake as 39.6's baseline. Every unit test passed; 0 warnings. Identical case list before and after. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/Stats/MatchDetailView.swift`, `finalScoresCard` only. The `ForEach` of `HStack`s is now a `Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12)` with a `GridRow` per participant, with a comment citing 39 §2.9. The cells are: (1) the place, font `.subheadline.weight(.semibold)` and `.secondary` as before, `.lineLimit(1)`, with no `frame(width: 32)`; (2) the name as before; (3) the score as before, with `.gridColumnAlignment(.trailing)` and `.frame(maxWidth: .infinity, alignment: .trailing)` in place of the `Spacer()`. **Spacing:** the rows keep the VStack's old 12 pt as `verticalSpacing`; `horizontalSpacing: 8` is about the old `HStack`'s default spacing between the place, name and score. The "Final Scores" heading stays above the grid in the same `VStack(spacing: 12)`, and the card's padding and background are unchanged. Plus this row. The rest of `MatchDetailView`, other views and SyLib are untouched. No tests (none asked for). No preview, simulator or device session (`00A` v1.13 §3). **Git (read-only):** `git status --short`, `git diff --stat -- SyFive/Views/Stats/MatchDetailView.swift`. **Report:** (1) `testLaunchPerformance` has now crashed the app in two of the last three baselines (39.6, 39.8) and passed in every after-run. It's worth a look outside this doc. (2) The only `warning:` lines in the logs are `appintentsmetadataprocessor`'s |
| 39.7 | 10 Nov 2026 | complete; V3 is Pops's, on device. **Checked by Claude against the tree**: `.solo` carries `insight`, from `playerInsights` over the solo games through `plainLanguageRead`; drawn under "Score to beat" when non-nil; `.table` and `.firstGame` unchanged; `SyLibYatzy` imported; test 1 covers three solo games (an insight) and two (none). Only `PreGameStatsCard.swift` and its tests changed | Before and after: `Passed`, 33 tests (36 runs), 33 passed, 0 failed, 0 skipped; identical case list; 0 warnings, 0 errors in both bundles. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/Stats/PreGameStatsCard.swift`: `.solo(games:best:average:insight: String?)`, with a doc comment. `content` fills `insight` with `playerInsights(playerID:matches:)` over the same solo games, through `plainLanguageRead`. `.table` and `.firstGame` are unchanged. The solo branch draws the insight under "Score to beat" when it's non-nil: `.footnote`, secondary, `lineLimit(2)`, `frame(maxWidth: .infinity, alignment: .leading)`, as 39.5 drew it. `import SyLibYatzy` is back. The type's and `content`'s doc comments say the insight is solo only (§2.8). The figures, layout and VoiceOver are unchanged. `SyFiveTests/PreGameStatsTests.swift`: still 3 tests, same names. Test 1 now also expects an insight from three solo games, and `.solo(games: 2, best: 250, average: 225, insight: nil)` from two solo games beside a multiplayer one. Tests 2 and 3 are unchanged. Plus this row. `statsContent`, the header, `HeadToHeadCard`, `PlayerProfileView` and SyLib are untouched. No preview, simulator or device session (`00A` v1.13 §3). Both suite runs ran in the background, so the 10-minute tool limit couldn't cut off a result bundle (as in 39.6). **Git (read-only):** `git status --short`. **Report:** `PlayerScoreCardView.swift` shows `MM`. That's 39.6's unstaged `statsContent` edit; this session didn't touch the file. The only `warning:` lines in the logs are `appintentsmetadataprocessor`'s |
| 39.6 | 10 Nov 2026 | complete; V3 is Pops's, on device. **Checked by Claude against the tree**: `content(…)` returns the `Record` alone; no insight, no `SyLibYatzy` import; the card always draws its record; two players get Head to Head alone; the three tests reworked, the third on `.firstGame` both ways. The red baseline was the UI launch tests only (all unit tests passed), before any edit, and didn't recur; noted, not chased. Its Status-line report fixed (v1.11) | **After:** `Passed`, 33 tests (36 runs), 33 passed, 0 failed, 0 skipped; 0 warnings, 0 errors. **Baseline (before any edit) was red, from the UI tests only:** run 1, `Failed`, 33 tests (36 runs), 32 passed, 1 failed: `SyFiveUITests.testLaunchPerformance()`, "com.syzygysoftwerksllc.SyFive crashed". All 30 unit tests passed; 0 warnings. A rerun, also before any edit, failed `SyFiveUITestsLaunchTests.testLaunch()` and ran to the 10-minute tool limit, so its bundle was never finished and has no totals. The case list differs from run 1 only by test 3's new name. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/Stats/PreGameStatsCard.swift`: the insight is gone. **The choice:** `Content` is dropped; `content(playerID:playerCount:matches:)` returns the `Record` alone (`.solo`, `.table`, `.firstGame`). There's no `playerInsights`, `plainLanguageRead` or insight `Text`. The two-player branch is gone, so the card always draws its record. `import SyLibYatzy` is removed (nothing else used it). The doc comments now describe figures only (§2.7), with the two-player table noted as `HeadToHeadCard`'s. The figures, the layout, "Score to beat", "First game, no stats yet." and VoiceOver are unchanged. `Views/PlayerScoreCardView.swift`, `statsContent`: the two-player `PreGameStatsCard` and its comment are gone, so `HeadToHeadCard` stands alone as before 39.5; otherwise `PreGameStatsCard` is as before. `SyFiveTests/PreGameStatsTests.swift`: still 3 tests, with no insight expectations. Tests 1 and 2 are unchanged apart from that. Test 3 is now `noGamesOfTheKindGiveFirstGame`: a solo table with only multiplayer games, a three-player table with only solo games, and a four-player table with none all give `.firstGame`. It was renamed because the old name was about insight. Plus this row. The header, `HeadToHeadCard`, `PlayerProfileView` and SyLib are untouched. No preview, simulator or device session (`00A` v1.13 §3). **Check:** `grep -n "insight\|plainLanguageRead" Views/Stats/PreGameStatsCard.swift Views/PlayerScoreCardView.swift` finds nothing. **Git (read-only):** `git status --short`, `git diff -- SyFive/Views/PlayerScoreCardView.swift`. **Report:** (1) The baseline's two UI launch-test failures came before any edit and didn't recur after; it looks like the same simulator flakiness as earlier sessions. (2) This doc's **Status** line reads "then Pops's V1 to V3; then Pops's V1 to V3, D-209 to D-212, and close", with the phrase repeated. Left for you. (3) The only `warning:` lines in the logs are `appintentsmetadataprocessor`'s |
| 39.5 | 10 Nov 2026 | complete; V1 to V3 are Pops's, on device. **Checked by Claude against the tree**: `PreGameStatsCard` as specified (own `@Query`, `onePerMatchID()`, solo or multiplayer games by participant count, `playerSummary` figures, `plainLanguageRead` insight, `.firstGame`); at two players it draws only the insight under Head to Head; one VoiceOver element per figure; the three tests; the header untouched (Pops's weight). SyFive's baseline is now 33 tests (36 runs) | Before: `Passed`, 30 tests (33 runs), 30 passed, 0 failed, 0 skipped. After: `Passed`, 33 tests (36 runs), 33 passed, 0 failed, 0 skipped. The case lists differ only by the three new `PreGameStatsTests`. 0 warnings, 0 errors in both bundles. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** **New `Views/Stats/PreGameStatsCard.swift`:** `PreGameStatsCard(playerID:playerCount:theme:)`, with its own `@Query` of completed `MatchModel` sorted by `startedAt`, read through `onePerMatchID()` and `toDomain()`, as `HeadToHeadCard`. The choosing is `static func content(playerID:playerCount:matches:) -> Content`. `Content` is a struct: `record: Record` (`.solo(games:best:average:)`, `.table(games:wins:winPercent:)`, `.firstGame`) plus `insight: String?`. Solo games have one participant, multiplayer games more, as the profile splits them. The figures are `playerSummary` over the table's kind: Win % is `Int(winRate * 100)` as the profile's; Best and Avg go through a file-private `Decimal.displayInt` by `Double`, with the profile's reason (`Int(truncating:)` gives 0 for division results). The insight is `plainLanguageRead(playerInsights(…))` over the same games. It draws one row of three figures (bold `.headline` value in `secondaryAccent`, `.caption2` secondary title, `maxWidth: .infinity`, on `cellBackgroundColor` in a 10 pt rounded rectangle, 6 pt vertical padding, smaller than the profile's 12 pt badges). Solo adds "Score to beat: N" (`.subheadline`). Then the insight (`.footnote`, secondary, `lineLimit(2)`) when there is one. `.firstGame` draws "First game, no stats yet." Each figure is one VoiceOver element ("Games, 12"). It has one preview, which was not rendered. **`Views/PlayerScoreCardView.swift`:** (a) The header's `weight: .regular` was already in the working tree when this session began, not by this session; it's §2.6 exactly, so it was left as is and nothing else in the header changed. (b) `statsContent`: two roster players get `HeadToHeadCard` as before, then `PreGameStatsCard(playerID:playerCount: 2, theme:)`. **The choice:** `PreGameStatsCard` draws only its insight when `playerCount == 2` (no shared view). Otherwise, with a roster player, it's `PreGameStatsCard(playerID:playerCount:theme:)`. `statsContent`'s `theme` is used again. **New `SyFiveTests/PreGameStatsTests.swift`** (+3, `@MainActor`, on `content` with `Match` values): (1) a solo table ignores multiplayer games (3 solo games give games 3, best 250, avg 208 from 208.33; insight non-nil); (2) a three-player table ignores solo games (games 3, wins 2, 66%; insight non-nil); (3) multiplayer-only games at a solo table, and no games at a four-player table, give `.firstGame` with nil insight; two solo games beside three multiplayer give a `.solo` record and nil insight. Plus this row. `HeadToHeadCard`, `PlayerProfileView`, the score content and SyLib untouched. No preview, simulator or device session (`00A` v1.13 §3). **Fix (`00A` §8):** the first test run failed to build because `PreGameStatsCard.swift` was missing `import SyLibUI` (for `SyTheme`); added. **Git (read-only):** `git status --short` (twice), `git diff HEAD -- Views/PlayerScoreCardView.swift`, `git diff --stat` on `HeadToHeadCard.swift` and `PlayerProfileView.swift` (empty), `git diff -- Views/PlayerScoreCardView.swift`. **Report:** (1) The header's `weight: .regular`, as (a) above. (2) If a two-seat table has a second seat with no roster player (only previews have one, since `38`), `statsContent` falls to the `else` branch, so that card shows only its insight and no Head to Head, as before this task. (3) The only `warning:` lines in the log are `appintentsmetadataprocessor`'s, which is build-tool output |
| 39.4 | 10 Nov 2026 | complete (SyLib); 39.5 (SyFive) next. **Checked by Claude against the SyLib tree**: `weight` after `size` on both initializers, default `.bold`, applied by `symbolFont` at every size; the count stays bold; preview and docs updated. **Then Pops** made `.small`'s image scale `.large` (§2.4 v1.7); Claude updated `UI_COMPONENTS.md` and this doc. Left in the code for a later SyLib tidy: `Size.small`'s doc comment still says `.medium`, and `symbolScale`'s switch now gives `.large` for every size | **SyLib** before and after: `Passed`, 1596 tests (1671 runs), 1595 passed, 0 failed, 1 skipped; identical case list; 0 warnings in both bundles. **Syderal** before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list; 0 warnings. **Score It \*** and **SyFive** `xcodebuild build`: succeeded, 0 warnings, 0 errors. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files (sylib-swift):** `Sources/SyLibUI/Components/IconButton.swift`: both initializers take `weight: Font.Weight = .bold` right after `size`, with a `- Parameter weight:` doc. It's stored as `private let weight` (documented). `symbolFont` is now `.body` / `.title2` / `.largeTitle` `.weight(weight)` in place of the fixed `.bold`. `countFont`, the sizes, `badgeScale`, `symbolScale`, `Context`, `badgeOffset` and `minimumTouchSide(for:)` are unchanged. The type's doc example gains a `weight: .regular` line. In the "Small" preview, a `.small`, `weight: .regular` profile button sits beside the bold one, outlined, and the preview's comment mentions §2.6. It compiles and was not rendered. `Docs/UI_COMPONENTS.md`, `IconButton`: both signatures gain `weight: Font.Weight = .bold,` after `size`; a new `weight` paragraph (for every size; `.bold` default draws as before; the count stays bold; 39 §2.6, D-212) has the example `IconButton("person.crop.circle", size: .small, weight: .regular) { showsProfile = true }`. Plus this row. No tests (none asked for). SyFive, Score It \*, Syderal and SydeTwo untouched. No preview, simulator or device session (`00A` v1.13 §3). **Git (read-only):** `git status --short` (sylib-swift and syfive-ios, twice each), `git diff -- Docs/UI_COMPONENTS.md`, `git diff --stat` (sylib-swift). **Report:** (1) In sylib-swift, 39.2's changes were already staged when this session started (`M ` on both files). During this session most of 39.4's edits were staged too, not by this session; probably Xcode's auto-staging. At the end, `git diff --stat` shows only one line unstaged, in `IconButton.swift`. Left as is. (2) `Size`'s doc comments still say "A bold `.body` symbol" and so on. That's true for the default weight; they were left alone because the sizes were out of scope. (3) The only `warning:` lines in the logs are `appintentsmetadataprocessor`'s "Metadata extraction skipped", which is build-tool output |
| 39.3 | 10 Nov 2026 | complete; V1 and V2 are Pops's, on device; 39.5 next. **Checked by Claude against the tree**: the one line, `size: .small`, nothing else | Before and after: `Passed`, 30 tests (33 runs), 30 passed, 0 failed, 0 skipped; identical case list; 0 warnings, 0 errors in both bundles. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayerScoreCardView.swift` only, one line: `IconButton("person.crop.circle") { showsProfile = true }` is now `IconButton("person.crop.circle", size: .small) { showsProfile = true }`. Its condition, accessibility label and comment are unchanged, and so is everything else. Plus this row. SyLib untouched. No tests (none asked for). No preview, simulator or device session (`00A` v1.13 §3). **Build:** the pinned test run builds the app and test targets: 0 warnings in both bundles. The log's only `warning:` lines are `appintentsmetadataprocessor`'s "Metadata extraction skipped" (×2, before and after alike), which is build-tool output. **Git (read-only):** `git diff --stat`, `git status --short`. **Report:** `git status` shows the index staged, not by this session: `AM` on this doc, `M ` on `project.pbxproj` and `MM` on `PlayerScoreCardView.swift`. Probably Xcode's auto-staging or Pops's. Left as is |
| 39.2 | 10 Nov 2026 | complete (SyLib); 39.3 (SyFive) next. **Checked by Claude against the SyLib tree**: `.small` first, four private `switch size` properties giving `.regular` and `.large` their old values, `Context` and the touch area unchanged, a "Small" preview, docs updated | **SyLib** before and after: `Passed`, 1596 tests (1671 runs), 1595 passed, 0 failed, 1 skipped; identical case list; 0 warnings in both bundles. **Syderal** before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list; 0 warnings. **Score It \*** and **SyFive** `xcodebuild build`: succeeded, 0 warnings, 0 errors. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files (sylib-swift):** `Sources/SyLibUI/Components/IconButton.swift`: `Size` is `small, regular, large`, `.small` first, each with a doc comment. The size-dependent values are private `switch size` properties in place of `size == .large ? … : …`: `symbolFont` (bold `.body` / `.title2` / `.largeTitle`), `symbolScale` (`.medium` for `.small`, `.large` otherwise), `badgeScale` (0.75 / 1.0 / 1.5), `countFont` (bold `.caption2` for `.small` and `.regular`, bold `.caption` for `.large`). `.regular` and `.large` get the same values as before. `Context`, `badgeOffset` (still `badgeScale` times the context's offset) and `minimumTouchSide(for:)` are unchanged. The type's doc example gains a `.small` line. There is a new `#Preview("Small")` after "Toolbar": a `.title3` name beside `.small` and `.regular` profile buttons, touch areas outlined, plus `.small` badged bells. It compiles and was not rendered. `Docs/UI_COMPONENTS.md`, `IconButton`: both signatures' `size:` lines note `.small, .regular or .large`; the size paragraph describes all three (the touch area goes by context, citing 39 §2.4 and D-210); the example adds `IconButton("person.crop.circle", size: .small) { showsProfile = true }`; the context note now says `.small` scales the offsets by 0.75 (it said only `.large`'s 1.5, which would have been wrong). Plus this row. No tests (none asked for). SyFive, Score It \*, Syderal and SydeTwo untouched. No preview, simulator or device session (`00A` v1.13 §3). **Git (read-only):** `git status --short` and `git diff --stat` in both repos. **Report:** the SyLib test log's only `warning:` line is `appintentsmetadataprocessor`'s "Metadata extraction skipped". That's build-tool output, not a compiler warning; the bundle counts 0 warnings |
| 39.1 | 10 Nov 2026 | complete; V1 and V2 are Pops's, on device. **Checked by Claude against the tree**: the pencil, its sheet and `fetchPlayerEditMode()` gone; `IconButton("person.crop.circle")` after the name, roster players and before the game only, with its label; View profile and "Add to roster for stats" gone; Head to Head, the profile sheet and the remove X unchanged. The report's leftovers (`statsContent`'s unread `theme`, the unread `modelContext`) are harmless and left for a later tidy; the `MARKETING_VERSION` 1.3.0 bump is Pops's | Before and after: `Passed`, 30 tests (33 runs), 30 passed, 0 failed, 0 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayerScoreCardView.swift` only. In `header`, the `if model.canEditPlayers` pencil `Button` is now, in the same place, `if model.canEditPlayers, model.playerIDs[playerIndex] != nil { IconButton("person.crop.circle") { showsProfile = true }.accessibilityLabel("Profile, \(model.playerNames[playerIndex])") }`, with a comment citing 39 §2.1. `showsPlayerEdit`, its `.sheet(item:)` and `fetchPlayerEditMode()` are removed (nothing else used them). In `statsContent`, the `if viewerID != nil { View profile } else { Add to roster for stats }` block is removed; `HeadToHeadCard` and its condition are unchanged. The `.sheet(isPresented: $showsProfile)`, the remove X and the score content are unchanged. Plus this row. `PlayerProfileView`, `PlayerEditSheet`, `HeadToHeadCard` and SyLib untouched. **Check:** `grep -n "pencil\|View profile\|Add to roster" Views/PlayerScoreCardView.swift` finds nothing. **Build:** `BuildProject` passed before (0 warnings) and after (with test targets, 0 warnings); 0 `warning:` lines in the test log. No preview, simulator or device session (`00A` v1.13 §3). **Git (read-only):** `git diff HEAD --stat -- Docs/Requirements/`, `git status --short` ×2, `git diff -- SyFive.xcodeproj/project.pbxproj`. **Report:** (1) `project.pbxproj` shows modified, not by this session: `MARKETING_VERSION` 1.2.0 → 1.3.0 in both app configurations (Pops's version bump, it seems). Left as is. (2) `statsContent` still takes a `theme` parameter it no longer reads, and `modelContext` is no longer read by this view. Neither warns; left, as the task named neither |

## 6. Ledger rows (filed 10 November 2026)

| ID | Ruling | Source |
|---|---|---|
| D-210 | **`IconButton` has a `.small` size**: a `.body` symbol at large image scale, as every size, for an icon beside body-sized text, the 44 pt touch area unchanged. *Why:* `.regular` was too big beside a player's name (Pops, on device). | `39 §2.4` (Pops, 10 Nov 2026) |
| D-211 | **Before the game, a player card's foot shows that player's figures for the table**: solo, their solo Games, Best and Avg and "Score to beat"; two players, Head to Head; three or four, their multiplayer Games, Wins and Win %; "First game, no stats yet" with none. At a solo table, the profile's opening sentence from solo games, when it has one; at other tables none. *Why:* the foot was empty for every table but two, and a sentence was too much for a card (Pops). | `39 §2.5, §2.7, §2.8` (Pops, 10 Nov 2026) |
| D-212 | **`IconButton` takes a `weight`** (default `.bold`, so every button is as it was); SyFive's profile button is `.small`, `.regular`. *Why:* bold was too heavy beside a player's name (Pops). | `39 §2.6` (Pops, 10 Nov 2026) |
| D-209 | **Before the game, a player card's one control beside the name is a profile button** (`IconButton("person.crop.circle")`, roster players only), opening the player's profile, where Edit lives; the card's pencil and its "View profile" link are gone. *Why:* the pencil predated the profile's Edit (D-182) and duplicated it. | `39 §2` (Pops, 10 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.16 | 10 Nov 2026 | V1 to V4 pass (Pops). Closed: D-209 to D-212 filed |
| 1.15 | 10 Nov 2026 | 39.8 checked; all tasks done; the launch-performance flake noted |
| 1.14 | 10 Nov 2026 | §2.9 (Pops): match detail's place column; Task 39.8; V4 |
| 1.13 | 10 Nov 2026 | 39.7 checked; all tasks done |
| 1.12 | 10 Nov 2026 | §2.8 (Pops): the insight line back, for a solo table only; Task 39.7; V3 and D-211 updated |
| 1.11 | 10 Nov 2026 | 39.6 checked; the Status line's repeated phrase fixed; all tasks done |
| 1.10 | 10 Nov 2026 | §2.7 (Pops): no insight line; Task 39.6; V3 and D-211 updated |
| 1.9 | 10 Nov 2026 | 39.5 checked; all tasks done; V1 to V3 remain |
| 1.8 | 10 Nov 2026 | The profile button's `weight: .regular` done by Pops; 39.5 leaves the header alone |
| 1.7 | 10 Nov 2026 | 39.4 checked. `.small`'s image scale is `.large` (Pops, after 39.4); §2.4 and D-210 updated |
| 1.6 | 10 Nov 2026 | 39.3 checked |
| 1.5 | 10 Nov 2026 | §2.6 (Pops): `IconButton`'s `weight`; new Task 39.4 (SyLib); the stats task renumbered 39.5, which also passes `weight: .regular`; D-212 |
| 1.4 | 10 Nov 2026 | 39.2 checked |
| 1.3 | 10 Nov 2026 | §2.5 (Pops): pre-game stats in the card's foot, superseding §2.2's empty foot; Task 39.4; V3; D-211 |
| 1.2 | 10 Nov 2026 | §2.4 (Pops): `IconButton`'s `.small` size; Tasks 39.2 (SyLib) and 39.3 (SyFive); V1 after 39.3; D-210 |
| 1.1 | 10 Nov 2026 | 39.1 checked |
| 1.0 | 10 Nov 2026 | First version |
