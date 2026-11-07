# SyLib adoption, round 2: what Score It \* added to SyLib, into SyFive 1.2.0

**Status:** **Tasks complete (26.1 to 26.14, with 26.9b), 6 November 2026; ship steps open (§5 Ship, and the deferred Game Night pass in §12).** Version 2.0, 6 November 2026. All rulings by Pops, 6 November
2026 (§2). Version 1 (5–6 November) was a design for review and was never given to the agent, so
this version replaces it in place (`00B` E-1 covers delivered documents only).

**Scope:**
- **SyFive:** `syfive-ios`, branch `sylib-reintegration`, cut from `main` at `b9c27e4`.
  `MARKETING_VERSION` is already 1.2.0 in both configurations (Pops, 6 November, not yet committed).
- **SyLib:** `sylib-swift`, branch `syfive-integration`, cut from `main` at `0ee6219` ("Score It All
  integration (#15)"). Its tree is byte-identical to `scoreit-integration` at `6c76367`, which is
  what version 1 reviewed. Against SyLib's previous `main` (`8f9ec06`) the merge changes 164 files,
  77 of them under `Sources/`.
- **SyLib edits** are made only by the three SyLib tasks, 26.9, 26.9b and 26.12, which also edit the SyLib docs
  they name. Each one adds to a public API without changing a default. Every other SyLib change is a
  stop condition (`00B` §2).
- **Syderal** is out of scope (§10).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document, and the SyLib usage doc each task names (in the
package's `Docs/`).

**Line numbers** are from the trees above, except where a task says they were moved by an earlier task. Find each edit by the declaration named, not the
number.

---

## Supersessions

- **D-131** (`appProtocolVersion` 1, transport 3, "frozen for 1.1.0") is **extended to 1.2.0**
  without changing the ruling: `Match` gains an `options` key on the wire that older builds ignore
  (§2.2, D-156). Source chain: `14 §1.x → 26 §2.2`.
- **D-101's and D-106's** rulings are unchanged. What changes is only how the date **reads**: SyFive
  showed it as month and year ("November 2026", or "Nov 2026" per holder), and it now reads as an
  abbreviated date ("Nov 5, 2026"), the same in both places (§2.10, D-164).
- **Nothing else is superseded.** D-160 (Score It \*'s look wins) defers to every ledger row that
  fixes a look. Those conflicts go to Pops in `28` (§11).

---

## 1. Why

Score It \* was built on SyLib from 29 October to 5 November 2026. It moved a great deal into SyLib
that began in SyFive: the palettes, the feel recipes, the game-over celebration and the Yatzy
scorecard. It also added pieces that SyFive does by hand, and changed a few things every SyLib app
gets.

SyFive compiles against SyLib's working copy (`XCLocalSwiftPackageReference "../../sylib-swift"`
in `project.pbxproj`). So this round is two parts:

- **Absorb (§3, Phase 1):** what SyFive needs to build and ship on this SyLib at all.
- **Adopt (Phases 2 and 3):** each adoption deletes a SyFive copy, or fixes something. Pops's
  direction (6 November 2026) decides which look wins where the two apps differ: *"I'm really
  digging the look/feel of Score It All, so I want to adopt a lot of it in SyFive when we take the
  lid off again."*

---

## 2. Locked decisions

Pops, 6 November 2026. Each ruling's ledger row is in §9.

**2.1 The store moves to `ScoringSchemaV2` in 1.2.0** (D-155; Q1). `GameModel` gains `isArchived`,
`optionsData` and `rulesLinksData`, and `MatchModel` gains `optionsData`, all with defaults. A 1.1.x
store opens as V2 by SwiftData's inferred migration, proved in SyLib by `ScoringMigrationTests`
against a committed V1 fixture. SyFive's code reads none of the new fields. CloudKit Development
gets the fields through `initializeCloudKitSchema`, and Production is deployed before any
TestFlight build (D-026). *Rationale:* the schema is already in SyLib. SyFive can't avoid it, only
gate it, and an additive change is the cheapest kind.

**2.2 `Match` carries `options` on the wire, and the versions don't move** (D-156; Q2).
`MatchStartPayload`, `MatchStatePayload` and `MatchCompletePayload` each encode `options` (always
`{}` from SyFive). A 1.1.x decoder ignores the unknown key. This build's decoder tolerates its
absence (`decodeIfPresent … ?? [:]`). `appProtocolVersion` stays 1 and the transport stays 3.
*Rationale:* a 1.1.x device and a 1.2.0 device can share a table. The proof is a mixed table (V3).

**2.3 `Theme` becomes `SyTheme` in one pass** (D-157; Q3). `Theme/Theme.swift` is deleted, every
reference is renamed in the same task, and no `typealias` is left behind. *Rationale:* the rename
is mechanical and easy to grep, and a half-renamed tree is worse than either end state. D-013 holds:
Domain still stores `themeID: String`.

**2.4 The shared pieces SyFive already had are SyLib's** (D-158). This covers the feel catalog
(`FeelCatalog.syzygy`, merged with SyFive's own `celebration`), the dice-to-feel adapter
(`SyLibDiceFeel`), the dice palette, the tray's roll controls, and the game-over overlay and winner
card. The Yatzy moment, the `celebration` recipe and `CelebrationCoordinator` stay SyFive's.
*Rationale:* each is SyFive's code, moved word for word and made shared. These adoptions only
delete code.

**2.5 Settings' Audio & Feedback rows are `FeelSettingsRows`, and Haptics is hidden where the
device has none** (D-159; Q5). *Rationale:* this is Score It \*'s behavior. A toggle that does
nothing is noise.

**2.6 Appearance is `AppearanceSetting`, applied by `WindowAppearance`** (D-159; §3.8 of version 1).
Pops confirmed on a device that SyFive has the bug: Settings keeps its old scheme when Color Scheme
is changed from inside it. `.preferredColorScheme` leaves the root, because SyLib's `THEME.md` says
to have one owner. *Rationale:* it fixes a real defect, and the stored raw values are unchanged.

**2.7 Where SyFive's look and Score It \*'s differ, SyFive takes Score It \*'s** (D-160), **except
where a ledger row fixes the look.** A conflict with a ruling goes to Pops, and the direction never
silently overrides it. A difference that is a defect in either app is fixed, not copied.

**2.8 The in-play scorecard is `SyLibYatzyUI`, with legality per category** (D-161; Q4).
`YatzyScorecardCard` and `YatzyScorecardPager` replace `PlayerScoreCardView`'s in-play layout and
`ScorecardView`'s paging. On iPad this includes the width cap (each card at most its ideal width ×
1.25, with fewer cards than fit sitting centered). Two more parts of the ruling:
- **SyLib addition (26.9):** `YatzyScorecardCard` gains `scorableCategories: Set<YatzyCategory>? =
  nil`. When it is nil the card behaves exactly as today. When it is set, an open category not in
  the set is drawn and treated as not scorable. SyFive passes `legalScoreCategories(for:)` there.
  *Rationale:* SyFive enables cells one category at a time
  (`PlayerScoreCardView.swift` 355, `model.canScore(category:for:)`), which is what enforces joker
  forced-scoring and the strict-poison rule (D-003 to D-005). The SyLib card's single
  `canScore: Bool` would let a five-of-a-kind be scored into a category that isn't legal.
- **SyLib addition (26.9b, Pops, 6 Nov 2026):** `YatzyScorecardCard` gains
  `pulsesBestSuggestion: Bool = true`. With it false, open cells still show their suggested
  values but nothing pulses. SyFive passes its Suggested Move setting there. *Rationale:* in
  SyFive the setting has only ever controlled the pulse (`ScoreRow.swift` 56); a legal cell always
  shows what it would score (91–93). SyLib's card ties values and pulse together, so without this
  the setting turned off would hide the values as well.
- **The pre-game card stays SyFive's** this round: the edit pencil, the remove button, the
  head-to-head card and View profile (`model.canEditPlayers`, `MatchController.swift` 105). It is
  restyled to match in `28` (§11).

**2.9 Player edit is `PalettePlayerEditSheet`, with `PaletteChips`** (D-162; Q6). The swatch picker
(`PlayerEditSheet.themePicker`) goes. SyFive keeps its modes, its match and Game Night handling
(`onCreated`, `matchSlot`) and its writes, all in `onSave`.

**2.10 House Records uses `RecordCard`, extended in SyLib, laid out in SyLib's grid** (D-164; Q9).
- `RecordCard` gains several holders, D-101's dates, a caption under a holder, and an unclaimed
  state (26.12).
- Score It \*'s grid moves into SyLib as `RecordCard.grid` (26.12).
- Dates read as Score It \* writes them: `date.formatted(date: .abbreviated, time: .omitted)`
  ("Nov 5, 2026").
- D-097 to D-116 are unchanged. The title definitions and their computation stay SyFive's (D-110),
  and so does every word of copy.

**2.11 `SegmentedPicker` and `WindowTint`** (D-163; Q8). SyLib's segmented control replaces the
two `.segmented` pickers in Stats. `WindowTint` puts the palette accent on alerts, navigation bars
and Back.

**2.12 `IconButton`'s 44 pt minimum is accepted as it lands** (D-165; Q7). The two dice-area
buttons sit in 32 × 24 slots, so the frame overflows its slot. That is checked on a device (V6). An
overflow that shows is a defect, and Pops rules the fix.

**2.13 `paletteBarBackground` lands with `28`'s palette lists**, not in this round (D-166; Q10). On
SyFive's system-colored lists the bar would be the palette's color over the system's background.

**2.14 The new `deriveInitials` rule is accepted** (D-167). "Mary-Jo" now gives "MJ" (it was
"MA"). Stored initials never change. One edge is lost: a player named with punctuation before 1.2.0
no longer has initials that follow a rename (`PlayerEditSheet.swift` 73 compares against
`deriveInitials(from: oldName)` under the new rule).

### 2.15 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| A `typealias Theme = SyTheme` bridge | Two tasks instead of one, and a tree that is half one name and half the other (Q3) |
| Bumping `appProtocolVersion` | 1.1.x and 1.2.0 would stop sharing a table, for a key that older decoders ignore (Q2) |
| Guarding illegal scores inside `onSelect` | The cell would still look tappable. Legality belongs in what the card draws (§2.8) |
| A SyLib pre-game mode for `YatzyScorecardCard` | No second app needs it yet (Q4) |
| Keeping the palette swatches | Score It \* ruled the chips the studio's picker (SIA-262), and Q6 follows it |
| SyFive's month-and-year date on record cards | Q9. The card takes one date format, Score It \*'s |
| `opensWebLinksInApp`, `WebLinkDestination` | SyFive opens no web pages. Its two `openURL` calls (`ContentView.swift` 512, 517) are App Store pages, which go to the system |
| `ScreenAwake` | SyFive's only idle-timer write is the fairness harness's (`DiceRoller.keepScreenAwake`). One holder, nothing to coordinate |
| `onePerID` | SyFive handles sync duplicates its own way: the fixed-id seed, `LegacyRematchRepair`, and readers that keep the first participant of a duplicated id |
| `TeamNaming`, `existingTeam`, `insertTeam`, team views and merges | SyFive has no teams |
| `SplitMix64`, `SoundTier`, `FeelCatalogSections` | Nothing in SyFive is built from a seed, plays only some sounds, or lists recipes by play order |
| `ScoringSystem`, `YatzyScoringSystem` | SyFive scores through `YatzyScoring` directly |
| `systemTextSize`, `DynamicTypeSize.bodyPointSize`, `AppIconView(image:)`, `ICloudStatusButton(pulses:)`, `SelectableChip(tintsWhenUnselected:)`, `EmptyStateView(message: Text)` | SyFive has no text-size floor, no TV board, no other app's icon, no iCloud button, and uses neither of the last two types |
| `makeScoringContainer`, `seedCatalogGame` | D-129 |
| `FeelCatalog.validate()` | Not adopted (`17` §1) |

---

## 3. What changes just by building

None of these needs code. Each is checked by Pops on a device, in V1.

| Change in SyLib | What SyFive gets | Check |
|---|---|---|
| `SoundRenderer.rendererVersion` 1 → 2: the last 20 ms of every sound fade to silence (`Render/SoundRenderer.swift`) | Every cache key changes (D-041), so every sound re-renders once on first launch. `game_end`'s end click is gone | Listen to settle, hold, undo, score confirm and game end. Score It \* has an open item for a faint end tick after `game_end` with Haptics off, so listen for it here too |
| `IconButton`'s `.standard` context has a 44 pt minimum touch area (`Components/IconButton.swift`) | How to Play in the toolbar (`ContentView.swift` 87), and the commentary and undo buttons in their 32 × 24 slots (`DiceAreaView.swift`) | V6 |
| `AppIconView` rounds at 22.5 % of its side, instead of 11 % | About's 200 pt icon is rounder | Look at About |
| `RainbowBorderModifier` runs from a clock | The winner's rainbow (`PlayerScoreCardView.swift` 99, then the SyLib card) starts mid-turn | One look at a game over |
| `ScoreTrendChart` draws a monotone line (SIA-277) | A profile's trend no longer hooks backward between matches a day apart | A profile with matches close together |
| `OpponentSummaryRow` uses `ViewThatFits` (SIA-274) | Head-to-head rows stack where they would crowd | The smallest iPhone at xxxLarge |
| `AboutView` puts the sheet's background behind its bar once scrolled (SIA-272) | About's bar takes Midnight's background when the text scrolls under it | Scroll About |
| `DiceFairnessView` takes its bar's background from `syTheme` | **A defect until 26.3.** SyFive sets no `syTheme`, so the bar is `SyTheme()`'s default (Blossom, dark) over a system-colored list. 26.3 fixes it, and Phase 1 doesn't ship without Phase 2 | Open Dice Fairness and scroll, after 26.3 |
| `deriveInitials` splits on any character that isn't a letter or digit | §2.14 | none |

These change in SyLib but make **no difference** to SyFive, because each new parameter defaults to
today's behavior: `MatchHistoryRow`, `UnfinishedMatchRow`, `OpponentSummaryRow`,
`HeadToHeadCardContent`, `HeadToHeadDetailContent`, `InitialsCircle`, `PlacementDistributionChart`'s
ordinal labels (identical below rank 21), and `SyzygyInfo`'s `SafariView`. Accessibility-size
layouts aren't reached, because SyFive caps text at xxxLarge. Nor are `recordsBoard`,
`CompetitorViews` or `absorbPlayer`'s team step.

---

## 4. Before starting (Pops)

1. Check out `syfive-ios` on `sylib-reintegration` and `sylib-swift` on `syfive-integration`.
2. In Xcode, link the products **`SyLibDiceFeel`** and **`SyLibYatzyUI`** to the SyFive target. An
   agent can't do it reliably by editing `project.pbxproj`.
3. Hand the agent one task per session (`00A` §3), in the order of §5.

---

## 5. Tasks

Each task runs `00B` §5 when it finishes: build; SyFive's suite on the pinned destination; and,
when it touches SyLib, SyLib's suite and Syderal's compatibility build. The summary reports each
suite's destination and its own total. **26.1 records the baseline totals**, and every later task
compares against the previous task's totals, plus the tests it names, less the deletions it names.

### Phase 1 · Build on this SyLib

#### Task 26.1 · Compile, and record the baseline

- **Inputs:** this doc §2.1 and §2.2; SyLib `Docs/SCORING_DATA.md`.
- **Change:** add `options: [:]` to the two `Match(` initializer calls in
  `Session/MatchController.swift`: line 351 (`let match = Match(`, the persisted snapshot) and
  line 827 (in `buildMatchSnapshot(matchID:gameID:)`, the Game Night snapshot). Nothing else in
  SyFive's source or tests calls `Match`'s or `Game`'s memberwise initializer. If anything else
  fails to compile, stop and report it.
- **Must not touch:** every other file; SyLib.
- **Done when:** the app builds; SyFive's suite and SyLib's suite pass on the pinned destination;
  the summary records both totals as the round's baseline; the summary lists every new warning,
  file and line, unfixed (`00A` §8).

#### Pops, after 26.1

- **V1:** the looks and listens in §3.
- **V2:** run once with `DebugCloudKit.runSchemaExercise` (or SyFive's usual
  `initializeCloudKitSchema` path). Then confirm in the CloudKit console that Development has the
  §2.1 fields for `iCloud.com.syzygysoftwerksllc.SyFive`. Production waits for the ship gate (§5,
  Ship).
- **V3:** the mixed table.

### Phase 2 · The same look

Players see nothing new in this phase, except the fix from 26.8 and the Dice Fairness bar from §3.
**Phases 1 and 2 ship together.**

#### Task 26.2 · `Theme` → `SyTheme`, in one pass

- **Inputs:** §2.3; SyLib `Docs/THEME.md`, `Docs/EXTENSIONS.md`.
- **Change:**

  | Today | After |
  |---|---|
  | `Theme/Theme.swift` | deleted |
  | `Theme(type: t, colorScheme: c)` (32 calls in 21 files) | `SyTheme(type: t, colorScheme: c)` |
  | `Theme.ThemeType` | `SyTheme.ThemeType` |
  | `@Environment(\.theme) private var theme` (16) | `@Environment(\.syTheme) private var theme` (the local name stays `theme`, to keep the diff mechanical) |
  | `.environment(\.theme, x)` (20) | `.environment(\.syTheme, x)` |
  | `Theme.ThemeType(rawValue: id) ?? .midnight` | `SyTheme.ThemeType(themeID: id)` |
  | `SyTheme(type: SyTheme.ThemeType(rawValue: id) ?? .midnight, colorScheme: c)` (where both are built together) | `SyTheme(themeID: id, colorScheme: c)` |
  | `MatchController.swift` 209, 308: `?? Self.defaultTheme(for: n)` | `SyTheme.ThemeType(themeID: id, fallback: Self.defaultTheme(for: n))` |
  | `MatchController.swift` 459: `let themeType = Theme.ThemeType(rawValue: player.themeID),` inside a `guard let` | `SyTheme.ThemeType(rawValue: player.themeID)`. An unknown id still means none |
  | `Theme.accent(forParticipant:colorScheme:)` (`HeadToHeadDetailView.swift` 35; `MatchHistoryView.swift` 91, 103) | `SyTheme.accent(forParticipant:colorScheme:)`, importing `SyLibScoringUI` |
  | `MatchDetailView.swift` 97 `rankLabel(participant.rank)`; the function at 180 | `participant.rank.ordinal` (SyLibCore); the function deleted |

  There are 15 `ThemeType(rawValue:)` lookups: `PlayerEditSheet` 52; `PlayersView` 96, 172, 187,
  238, 275; `HouseRecordsView` 111, 164; `PlayerPickerSheet` 171, 214; `MatchController` 209, 308,
  384, 459, 763 (after 26.1's two added lines). Previews are renamed in the same way.
- **Stop if:** SyFive uses a member of `Theme` that `SyTheme` doesn't have. Report it, and don't add
  it anywhere.
- **Must not touch:** stored data (the palette raw values are the same); Domain; SyLib.
- **Done when:** no type named `Theme` and no `\.theme` environment key remain in the app or its
  tests (`grep -rnw "Theme" --include=*.swift` finds only `SyTheme` and comments); the build and
  suites pass at the baseline totals, less any `rankLabel` test the summary names as deleted.

#### Task 26.3 · `syTheme` reaches every SyLib view that reads it

Task 26.2 writes `\.syTheme` wherever `\.theme` was written, mostly at `ContentView`'s root (line
232). A sheet attached to a modifier chain outside that write doesn't inherit the value. In SyLib,
four things read `\.syTheme`: `paletteBarBackground` (which `DiceFairnessView` uses),
`paletteListBackground`, `SegmentedPicker` and `PalettePlayerEditSheet`.

- **Change:** check each place SyFive presents one of those. Today that is `DiceFairnessView`
  (`ContentView.swift` 467) and `AboutView` (477). After 26.11 and 26.14 it also includes the edit
  sheet and the two pickers. For each, find out whether `\.syTheme` is written above it in the same
  chain. Where it isn't, add `.environment(\.syTheme, theme)` at the presentation site.
- **Done when:** the summary lists each site by file and line, saying whether it inherited the value
  or had it added; the build and suites pass. Rerun this check at the end of 26.11 and 26.14.

#### Task 26.4 · The feel catalog

- **Inputs:** §2.4; SyLib `Docs/FEEL.md`.
- **Change:** in `Feel/SyFiveCatalog.swift`, `FeelCatalog.syFive` becomes
  `FeelCatalog.syzygy.merging(FeelCatalog(sounds: ["celebration": …], rattles: [:], haptics:
  ["celebration": …]))`, with SyFive's two existing `celebration` recipes copied in unchanged. Every
  other recipe in the file goes. `FeelBoardView`'s references to `FeelCatalog.syFive` stay as they
  are.
- **Stop if:** any recipe in SyFive's file other than `celebration` differs from
  `FeelCatalog.syzygy`'s recipe of the same id. Version 1 compared them line by line on 5 November
  and found them identical. Report a difference, and don't resolve it.
- **Done when:** a new test asserts that `FeelCatalog.syFive` equals `FeelCatalog.syzygy` for every
  id except `celebration`, and has SyFive's `celebration` sound and haptic (suite total + 1).

#### Task 26.5 · The dice adapter and the dice palette

- **Inputs:** §2.4; SyLib `Docs/DICE.md`. `SyLibDiceFeel` is linked (§4).
- **Change:** delete `App/DiceFeelAdapter.swift`. `DiceAreaView.swift` imports `SyLibDiceFeel`, and
  its `@State private var feelAdapter: DiceFeelAdapter?` (line 30) and the construction at line 78
  are unchanged. Delete `DiceAreaView.swift`'s `extension Theme { var dicePalette … }` (lines
  12–23), so it reads SyLibDice's `SyTheme.dicePalette`. `DiceTrayView` still takes the palette
  (D-013).
- **Must not touch:** when the adapter is called (D-092: spectators get no dice audio).
- **Done when:** both files' contents are gone; the build and suites pass.

#### Task 26.6 · The tray's roll controls

- **Inputs:** SyLib `Docs/DICE.md` (`DiceRollControls`, `DiceRollButton`).
- **Change:** `DiceAreaView.rollControls` (line 119) is rebuilt as `DiceRollControls`. Only the
  layout moves. Every action, state and condition stays SyFive's:

  | `rollControls` today | `DiceRollControls` |
  |---|---|
  | The commentary `IconButton`, with its opacity and disabled state | `leading:` (the slot's frame moves to the control; opacity and disabled stay on the button) |
  | The Roll `Button` titled `rollButtonTitle`, its action, and `.toast($commentaryToast, …)` | `roll: { DiceRollButton(rollButtonTitle, isEnabled: canRoll) { … }.toast(…) }` |
  | The undo `IconButton`, with `.tint(undoButtonTint)` (line 208), opacity and disabled state | `trailing:` |
  | The row's `zIndex(1)` | built in; removed from SyFive |
  | The stuck message (when `isLocalTurn`) | `stuckMessage: isLocalTurn ? diceRoller.stuckDiceMessage : nil` |
  | "Choose a category to score", "No rolls remaining — choose a category", or the clear placeholder | `message:` the same string, or `nil` for the placeholder |
  | `proxyModeControls` (line 232) | `extra:` |

- **Done when:** the build and suites pass; the summary reports `DiceRollControls.controlHeight`
  against the slot heights it replaced. The look is V6, by Pops.

#### Task 26.7 · The game-over overlay and winner card

- **Inputs:** §2.4; SyLib `Docs/UI_COMPONENTS.md` (Celebration).
- **Change:** in `Views/CelebrationView.swift`, `GameOverOverlayView(` at line 21 becomes
  `GameOverOverlay(winnerThemes:onDone:)` with the same `[SyTheme]`. `WinnerCardView(` at line 132
  becomes `WinnerCard(winners:scoreText:)`. Its `winners` is built from `winner.winnerIndices`,
  one `CelebrationWinner(name:initials:themeType:)` per index, in today's order. Its `scoreText` is
  the string `WinnerCardView` shows today. Delete `WinnerCardView` (285), `GameOverOverlayView`
  (396) and `makeFallParticles` (577). Delete `joinedWithAmpersand` (540) only if nothing else in
  the file still calls it.
- **Must not touch:** `CelebrationCoordinator`, the Yatzy moment, `DiceTrayOverlayView`, the
  upper-bonus card, the score banner and the post-match head-to-head. D-069 to D-073, D-122 and
  D-123 are the same code in SyLib.
- **Done when:** the build and suites pass; the summary quotes the old and new `scoreText` strings.

#### Task 26.8 · Audio & Feedback rows, and Appearance

- **Inputs:** §2.5, §2.6; SyLib `Docs/FEEL.md`, `Docs/THEME.md`.
- **Change, feel rows:** in `Views/SettingsView.swift` 49–61, the section's two rows become
  `FeelSettingsRows(soundMode: $settings.soundMode, hapticsEnabled: $settings.hapticsEnabled,
  hapticsSupported: director.hapticSupported)`. Its footer becomes `Text(FeelSettingsRows.footer)`,
  which is word for word today's footer. The header stays SyFive's. `$settings.soundMode` binds
  the model's existing computed `soundMode` (get and set through `soundModeRaw`, falling back to
  `.mix`). `director` is the `FeelDirector`, read with `@Environment(FeelDirector.self)` in
  `SettingsForm`. Its `hapticSupported` is the property `FeelBoardView.swift` 76 reads. **The Settings
  sheet doesn't pass the director today** (`ContentView.swift` 460–464 passes only `\.syTheme` and
  `commentaryVoices`), and sheets here don't inherit the root's environment, so add
  `.environment(director)` there, as the Feel Board's sheet does (480–484). Without it, opening
  Settings crashes.
- **Change, appearance:**
  - Delete `enum AppColorScheme` (`AppSettingsModel.swift` 7–26, including its
    `preferredColorScheme`). Leave the file's environment extension alone: it is
    `suggestedMoveEnabled`'s. Retype the **computed** `colorScheme` property (44–47) as
    `AppearanceSetting` (`AppearanceSetting(rawValue: colorSchemeRaw) ?? .dark`). The stored
    `colorSchemeRaw` and its default stay exactly as they are, written as
    `AppearanceSetting.dark.rawValue` (the same `"dark"`). No stored attribute changes, so this is
    not `00B` §2's schema stop.
  - Settings' Color Scheme picker (`SettingsView.swift` 40) iterates `AppearanceSetting.allCases`.
  - In `ContentView.swift`, remove `.preferredColorScheme(…)` (line 230). In its place, call
    `WindowAppearance.apply(appSettings?.colorScheme ?? .dark)` in `.onAppear` and in an
    `.onChange(of: appSettings?.colorSchemeRaw)`, as `THEME.md` shows.
- **Must not touch:** the external display. `ExternalWindowManager` forces its window dark, and
  `WindowAppearance` skips that window.
- **Done when:** the build and suites pass. Pops checks the fix with V4.

### Phase 3 · The new look

#### Task 26.9 · SyLib: per-category scorability on `YatzyScorecardCard`

- **Inputs:** §2.8; SyLib `Docs/YATZY.md` (Scorecard views); `Sources/SyLibYatzyUI/YatzyScorecardTotals.swift`
  (`YatzyScorecardContent`) and `YatzyScorecardCard.swift`.
- **Change (SyLib):**
  - `YatzyScorecardContent` (`YatzyScorecardTotals.swift` 42) gains
    `var scorableCategories: Set<YatzyCategory>? = nil`, after `suggestedValues`. The default
    keeps every existing call site and test compiling unchanged.
  - Its `isScorable(_:)` (53–55) becomes
    `canScore && scorecard[category] == nil && (scorableCategories?.contains(category) ?? true)`.
    That one predicate already drives `isTappable`, `cellText` (a suggested value only where
    scorable, otherwise the placeholder) and `bestSuggestedCategory` (the pulse only among
    scorable cells), so nothing else in the type changes.
  - `YatzyScorecardCard.init` gains `scorableCategories: Set<YatzyCategory>? = nil`, right after
    `canScore`, stores it, and passes it to `YatzyScorecardContent` in `content` (94–95). Its doc
    comment: "the open categories that can be scored this turn; nil means every open one (the
    default). A host enforcing rules (SyFive's joker and strict-poison placement) passes its legal
    set."
  - `YATZY.md`'s `YatzyScorecardCard` section documents the parameter with that sentence.
- **Tests (SyLib), in `Tests/SyLibTests/SyLibYatzyUI/YatzyScorecardTotalsTests.swift`, total + 3:**
  1. With `scorableCategories: nil`, `isScorable` is true for exactly the open categories (today's
     behavior).
  2. With a set (e.g. `[.sixes, .chance]`, both open, plus `.ones` open but not in the set):
     `isScorable` and `isTappable` are true only for the set; `cellText(.ones)` is `.placeholder`
     with suggestions present; `bestSuggestedCategory` is in the set even when `.ones` has the
     highest suggested value.
  3. With `canScore: false`, nothing is scorable, whatever the set.
- **Must not touch:** any other parameter or default; Score It \* (it passes nothing and is
  unchanged).
- **Done when:** SyLib's suite is at 1548 + 3 = 1551 (1 skipped, as before); Syderal builds and
  passes (`00B` §5.4); SyFive builds.

#### Task 26.9b · SyLib: values without the pulse on `YatzyScorecardCard`

- **Inputs:** §2.8; SyLib `Docs/YATZY.md`; `YatzyScorecardTotals.swift`, `YatzyScorecardCard.swift`.
- **Change (SyLib):**
  - `YatzyScorecardContent` gains `var pulsesBestSuggestion: Bool = true`, after
    `scorableCategories`. `bestSuggestedCategory` (`guard canScore, let suggestedValues`) becomes
    `guard canScore, pulsesBestSuggestion, let suggestedValues`. Nothing else in the type changes,
    so `cellText` still shows the suggested values.
  - `YatzyScorecardCard.init` gains `pulsesBestSuggestion: Bool = true`, right after
    `suggestedValues`, stores it and passes it into `content`. Doc comment: "whether the best
    suggested value pulses; false still shows the values (SyFive's Suggested Move setting off).
    True, the default, is the behavior without it."
  - `YATZY.md` documents it with that sentence, beside `suggestedValues`.
- **Tests (SyLib), in `YatzyScorecardTotalsTests.swift`, total + 2:**
  1. With suggestions and `pulsesBestSuggestion: false`: `bestSuggestedCategory` is nil, and
     `cellText` for an open scorable category is still `.suggested(value)`.
  2. With the default: `bestSuggestedCategory` is as before (the highest scorable suggestion).
- **Must not touch:** any other parameter or default; Score It \*.
- **Done when:** SyLib's suite is at 1551 + 2 = 1553 (1 skipped); Syderal builds and passes; SyFive
  builds.

#### Task 26.10 · The in-play scorecard

- **Inputs:** §2.8; SyLib `Docs/YATZY.md` and `Sources/SyLibYatzyUI/YatzyScorecardPager.swift`.
  `SyLibYatzyUI` is linked (§4). Runs after 26.9 and 26.9b.
- **What the tree has (read 6 November 2026):** `ScorecardView` (`Views/ScorecardView.swift`)
  shows `PreGameGridView` while `model.canEditPlayers`, and otherwise its own `inGameView` (57–112):
  a vertical and a horizontal `ScrollView` of `PlayerScoreCardView`s, with `singleCardWidth`, a
  label-width probe, scroll-to-current-player, scroll-to-top on a player change, and a scroll to
  the winner at game over. `YatzyScorecardPager` is that same layout, with the iPad width cap, but
  it only follows `currentIndex`. `PlayerScoreCardView` is used in play by `ScorecardView` and
  before the game by `PreGameGridView` (29).
- **Change, `ScorecardView`:** the in-play branch becomes
  `YatzyScorecardPager(cards: cards, currentIndex: pagerIndex)`, where:
  - `pagerIndex` is `model.isGameOver ? (model.winnerIndices.first ?? model.currentPlayerIndex) :
    model.currentPlayerIndex`. That keeps today's scroll to the winner at game over (the pager
    scrolls whenever `currentIndex` changes).
  - `cards` holds one `YatzyScorecardCard` per seat (`model.slotIDs.indices`), with player `i`'s
    inputs from `MatchController`:

    | Card input | Value |
    |---|---|
    | `name` | `model.playerNames[i]` |
    | `initials` | `model.playerInitials(for: i)` |
    | `palette` | `model.themeType(for: i)` |
    | `scorecard` | `model.scores(for: i)` |
    | `yatzyBonus` | `model.yatzyBonus(for: i)` |
    | `isCurrentTurn` | `i == model.currentPlayerIndex && model.playerCount > 1 && model.hasStarted && !model.isGameOver` (today's turn-icon rule, `PlayerScoreCardView` header) |
    | `isWinner` | `model.isWinner(i) && model.isGameOver` |
    | `isLeading` | `model.playerCount > 1 && model.leaderIndices.contains(i)` |
    | `canScore` | `model.canScore && i == model.currentPlayerIndex`. **Only the current player's card can score**; without this every card would be tappable |
    | `scorableCategories` | `Set(YatzyCategory.allCases.filter { model.canScore(category: $0, for: i) })`, which is today's per-cell rule (joker and strict-poison placement included). `MatchController` doesn't change |
    | `suggestedValues` | `model.suggestedScores(for: i)` (always, as today) |
    | `pulsesBestSuggestion` | the `\.suggestedMoveEnabled` environment value |
    | `onSelect` | `{ category in model.score(category: category); if model.isGameOver { director.gameEnded() } else { director.scoreConfirmed() } }`, today's cell action (`PlayerScoreCardView.swift` 365–368) |

  - Delete what only `inGameView` used: `inGameView`, `scrollToCurrentPlayer`,
    `celebrateWinningPlayer`, `singleCardWidth`, `cardMetrics`, `sectionLabelProbe` and its
    `.background` probe, `LabelWidthKey`, `measuredLabelWidth`, and the layout constants. List each
    deletion in the summary. Keep the pre-game branch, the player-picker sheet and `showsPlayerPicker`.
  - Add `@Environment(FeelDirector.self) private var director` and
    `@Environment(\.suggestedMoveEnabled) private var suggestedMoveEnabled`.
- **`PlayerScoreCardView` is not changed in this task.** It still serves `PreGameGridView`. Its
  in-play code becomes unreachable, and `28` removes it with the pre-game restyle.
- **Also (from 26.8):** `SettingsView`'s `#Preview` adds `.environment(FeelDirector(catalog: .syFive))`.
- **Done when:** the build and suites pass; the summary lists the deletions, and any
  `PlayerScoreCardView` in-play behavior (in its header or cell code) that has no card input above.
  Pops checks V5.

#### Task 26.11 · Player edit with palette chips

- **Inputs:** §2.9; SyLib `Docs/THEME.md` (`PaletteChips`), `Docs/UI_COMPONENTS.md`
  (`PalettePlayerEditSheet`); `Sources/SyLibUI/Roster/PalettePlayerEditSheet.swift`,
  `PlayerEditSheet.swift` and `PlayerEditRules.swift`.
- **What the tree has (read 6 November 2026):** SyFive's `Views/PlayerEditSheet.swift` is a form
  with Name, Initials and a swatch `themePicker` (118–150), and a `save()` that writes the
  `PlayerModel` and the match. SyLib's sheet has the same fields, title, Cancel and Save, the same
  initials-follow rule (`PlayerEditRules.nameChanged`: follow while the initials are empty or equal
  the derived ones) and the same blank-initials fallback. SyFive has **no** name or initials limits
  today. `PalettePlayerEditSheet` dismisses itself after calling `onSave`.
- **Change, `Views/PlayerEditSheet.swift`:**
  - The type keeps its name, `Mode`, init, `matchModel`, `onSave` and `onCreated`, so its five call
    sites don't change.
  - Its `body` becomes `PalettePlayerEditSheet(existing:themeID:nameLimit:initialsLimit:deriveInitials:onSave:)`:

    | Parameter | Value |
    |---|---|
    | `existing` | `nil` for `.create`; `(pm.name, pm.initials)` for `.edit(pm, _)` |
    | `themeID` | `matchModel.nextPlayerThemeType.rawValue` for `.create`; `pm.themeID` for `.edit` |
    | `nameLimit`, `initialsLimit` | `nil` (SyFive has none) |
    | `deriveInitials` | `{ deriveInitials(from: $0) }` (SyLibScoring) |
    | `onSave` | `{ name, initials, themeID in … }`: today's `save()` writes, with `name` and `initials` already trimmed and resolved by SyLib, `themeType = SyTheme.ThemeType(themeID: themeID)`, then `onSave?()`. **No `dismiss()`**, because the SyLib sheet dismisses itself |

  - Delete `themePicker`, `save()`, the `@State` name, initials and theme, and the environment
    values and `swatchSize` nothing uses any more.
  - The two previews keep working, with any needed `syTheme`.
- **Change, presentation sites:** `PalettePlayerEditSheet` reads `\.syTheme`. `PlayersView` 89,
  `PlayerScoreCardView` 117 and `PlayerPickerSheet` 92 already pass it. The two Game Night sites in
  `App/GameNight/Views/GameNightScreens.swift` (39 and 154) don't: add `.environment(\.syTheme, theme)`
  to each, reading the enclosing view's `@Environment(\.syTheme) private var theme` (add it if the
  view has none). This is 26.3's recheck for the edit sheet.
- **Visible (D-160):** chips instead of swatches, a plain "Color" section header, and the form on the
  palette's background with the palette's tint, as Score It \* has them.
- **Stop if:** any behavior of today's sheet (a mode, a validation, a Game Night case) has no place
  in these parameters or `onSave`. Report it.
- **Done when:** the build and suites pass; the summary lists each of today's sheet behaviors and
  where it now lives, and the syTheme status of all five presentation sites.

#### Task 26.12 · SyLib: `RecordCard` with several holders, an unclaimed state, and the grid

- **Inputs:** §2.10; SyLib `Docs/SCORING_UI.md` (Records and celebration); Score It \*'s
  `Views/Game/RecordCardView.swift` (`score-it-all-ios` at `3c26af0`), quoted below.
- **Change (SyLib), `Sources/SyLibScoringUI/Records/RecordCard.swift`:**

  ```swift
  public struct RecordCard: View {
      public struct Holder: Sendable, Hashable, Identifiable {
          public let id: String
          public let name: String
          public let initials: String
          public let themeID: String
          public let date: Date
          /// A line under the name, in .caption secondary, e.g. a sample count.
          public let caption: String?
          public init(id: String, name: String, initials: String, themeID: String,
                      date: Date, caption: String? = nil)
      }
      public enum Content: Sendable, Hashable {
          case claimed(holders: [Holder], value: String)
          /// The label in the name's place; the note in the date's place.
          case unclaimed(label: String, note: String?)
      }
      public init(title: String, content: Content)
      /// Unchanged signature: one holder, no caption, claimed.
      public init(title: String, holderName: String, holderInitials: String, holderThemeID: String,
                  value: String, date: Date)
  }
  ```

  Layout. The surface, padding, title and spacing are today's, unchanged.
  - **Claimed:**
    - **Holders:** one row per holder, in the order given. Each row is today's row: an `HStack`
      aligned on the first text baseline, spacing 8, with the 24 pt `InitialsCircle` and the name in
      `.subheadline`. With one holder, the name keeps `.lineLimit(2, reservesSpace: true)`. With two
      or more, it is `.lineLimit(2)` without reserved space. A holder's `caption`, if any, sits under
      the name in `.caption`, `.secondary`.
    - **Dates:** compute `sharedDate`, which is true when every holder's `date` is equal (`==`). When
      it is false, each row ends with `Spacer(minLength: 8)` and that holder's date in `.caption`,
      `.secondary`.
    - **Value and date:** the value follows, as today. Under it is the date in `.caption`,
      `.secondary`, as today, when `sharedDate` is true, and nothing when it is false.
    - Every date is `date.formatted(date: .abbreviated, time: .omitted)`.
  - **Unclaimed:** the title as today. Then the `label` in `.subheadline`, `.secondary`, with
    `.lineLimit(2, reservesSpace: true)` and no circle. Then the `note` in `.caption`, `.secondary`,
    or, when the note is nil, a hidden `Text(" ")` in `.caption`. Then a hidden `Text("0")` in
    `.title2.weight(.bold)`, so the card is as tall as a one-holder claimed card.
  - The existing initializer builds
    `.claimed(holders: [Holder(id: holderName, name: holderName, initials: holderInitials, themeID:
    holderThemeID, date: date)], value: value)`, so Score It \*'s cards draw exactly as today.
- **Change (SyLib), the grid**, moved from Score It \*'s `RecordCardView` (its `24` PL-41, `21`
  M8-22) and made generic. The body is Score It \*'s, with `id:` in place of `\.kind`:

  ```swift
  extension RecordCard {
      nonisolated public static let gridSpacing: CGFloat = 12
      public nonisolated static func gridColumnCount(width: CGFloat, minimum: CGFloat) -> Int {
          max(1, Int(((width + gridSpacing) / (minimum + gridSpacing)).rounded(.down)))
      }
      public static func grid<Item, ID: Hashable, Card: View>(
          _ items: [Item], id: KeyPath<Item, ID>, width: CGFloat, minimum: CGFloat,
          @ViewBuilder card: @escaping (Item) -> Card) -> some View {
          let columns = gridColumnCount(width: width, minimum: minimum)
          let columnWidth = max(0, (width - CGFloat(columns - 1) * gridSpacing) / CGFloat(columns))
          let rows = stride(from: 0, to: items.count, by: columns)
              .map { Array(items[$0..<min($0 + columns, items.count)]) }
          return Grid(alignment: .leading, horizontalSpacing: gridSpacing, verticalSpacing: gridSpacing) {
              ForEach(rows.indices, id: \.self) { index in
                  GridRow {
                      ForEach(rows[index], id: id) { item in
                          card(item).frame(width: columnWidth)
                      }
                  }
              }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
      }
  }
  ```

  Callers measure the width with
  `.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }`, and scale the
  minimum with `@ScaledMetric(relativeTo: .subheadline) var minimum = RecordCard.gridMinimum`. That
  is how Score It \* does it, and how the file's existing preview does it. Replace that preview's
  hand-built grid with `RecordCard.grid`. Add previews for a three-holder tie with differing dates,
  a holder with a caption, and both unclaimed forms.
- **Docs (SyLib):** `SCORING_UI.md`'s RecordCard section documents `Holder`, `Content`, the new
  initializer and the grid. The paragraph that sends readers to Score It \*'s `RecordCardView.grid`
  sends them to `RecordCard.grid` instead. Replace the line "*SyFive adoption: … what it needs
  beyond this card is for then.*" with "SyFive's House Records uses it (SyFive `26`)."
- **Tests (SyLib)**, a new `Tests/SyLibTests/SyLibScoringUI/RecordCardTests.swift`
  (`@testable import SyLibScoringUI`), **total + 5**:
  1. `gridColumnCount`: width 0 → 1; 375 at 160 → 2; 800 at 160 → 4.
  2. `sharedDate` is true for one holder.
  3. `sharedDate` is true for two holders with equal dates.
  4. `sharedDate` is false when two holders' dates differ.
  5. The old initializer's `content` equals `.claimed(holders: [one holder with no caption], value:)`.

  `sharedDate` is `internal static func sharedDate(_ holders: [Holder]) -> Bool`, and the stored
  `content` is internal, so both can be tested.
- **Must not touch:** Score It \* (its own `RecordCardView.grid` stays until a Score It \* session
  adopts this one); `gridMinimum`; the card's surface, padding or fonts.
- **Done when:** SyLib's suite is at 1553 + 5 = 1558 (1 skipped); Syderal builds and passes;
  SyFive builds.

#### Task 26.13 · House Records on `RecordCard`

- **Inputs:** §2.10; SyLib `Docs/SCORING_UI.md`. Runs after 26.12.
- **Change, in `Views/HouseRecords/HouseRecordsView.swift`:**
  - The `ScrollView` stays. Its `LazyVStack(spacing: 14)` becomes `VStack(alignment: .leading,
    spacing: 14)`.
  - Each section's `ForEach … TitleCard(title:)` becomes
    `RecordCard.grid(sectionTitles, id: \.id, width: width, minimum: minimum) { RecordCard(title:
    $0.name, content: content(for: $0)) }`.
  - `width` is one `@State` measured on the first grid, and `minimum` is the `@ScaledMetric` above.
    The two `RecordsSectionHeader`s and their copy are unchanged.
  - `content(for:)` maps `HouseRecords.TitleState`, keeping the copy as it is today:

    | `TitleState` | `RecordCard.Content` |
    |---|---|
    | `.claimed(holders, displayValue)` | `.claimed(holders: holders.map { RecordCard.Holder(id: $0.id, name: $0.displayName, initials: $0.displayInitials, themeID: $0.displayThemeID, date: $0.heldSince, caption: $0.sampleCount.map { "\($0) game\($0 == 1 ? "" : "s")" }) }, value: displayValue)` |
    | `.unclaimed` | `.unclaimed(label: "Unclaimed", note: nil)` |
    | `.unclaimedGated` | `.unclaimed(label: "Unclaimed", note: "After 10 games")` |

  - Delete `TitleCard`, `ClaimedContent`, `HolderRow` and `UnclaimedContent`. The preview stays and
    is renamed for 26.2.
- **Must not touch:** `App/HouseRecords/HouseRecords.swift` (D-110); the title copy; D-097 to D-116.
- **Report, don't fix:** `HouseRecords` builds tied holders from `Array(holderSet.values)`, a
  dictionary, so their order isn't fixed between launches. This is today's behavior. Report it for
  Pops.
- **Done when:** the build and suites pass. Pops checks V7.

#### Task 26.14 · `SegmentedPicker` and `WindowTint`

- **Inputs:** §2.11; SyLib `Docs/UI_COMPONENTS.md` (`SegmentedPicker`), `Docs/THEME.md`
  (`WindowTint`).
- **Change:** the two `Picker`s with `.pickerStyle(.segmented)` (`PlayerProfileView.swift` 87,
  PvP / Solo; `MatchHistoryView.swift` 47, Finished / Unfinished) become
  `SegmentedPicker(_:selection:segments:)`, with the same selections and segment titles. In
  `ContentView.swift`, call `WindowTint.apply(UIColor(theme.primaryAccent))` in `.onAppear` and in
  `.onChange(of: theme)`. The existing `.tint(theme.primaryAccent)` (line 231) stays.
- **Done when:** the build and suites pass; 26.3's check is repeated for the two pickers' screens
  (report each by file and line, and whether `\.syTheme` reaches it; add it there if not). Pops
  checks V8.

### Phase 4 · Restyle

The restyle is `28` (§11), together with `paletteBarBackground` (§2.13).

### Ship

1. Confirm V1 to V8 pass, with results in §12.
2. **CloudKit:** deploy Development to Production for `iCloud.com.syzygysoftwerksllc.SyFive`
   (D-026). Pops does this.
3. Run the `00B` §6 pre-archive checklist. `MARKETING_VERSION` 1.2.0 is already set.
4. TestFlight. The mixed table (V3) is run again with a TestFlight build against a 1.1.x App Store
   build.

---

## 6. Validation

| # | When | Who | Check | Pass |
|---|---|---|---|---|
| V1 | After 26.1 | Pops, device | §3's looks and listens | Each as described; any end tick after `game_end` with Haptics off is recorded |
| V2 | After 26.1 | Pops | CloudKit Development has the §2.1 fields | Present for `GameModel` and `MatchModel` |
| V3 | After 26.1, and at ship | Pops, two devices | A 1.1.x device and this build share a table, with each one hosting once, through a full match and history sync | Joins, plays, completes, and syncs history both ways |
| V4 | After 26.8 | Pops, device | Open Settings, then change Color Scheme from inside it | Settings itself changes scheme at once; About, the sheets and the external display behave as before |
| V5 | After 26.10 | Pops, iPhone and iPad | An in-play scorecard, including a joker turn (a five-of-a-kind with Yatzy at 50 and its upper box filled), a turn after Yatzy has been scratched, and game over | Only legal cells can be tapped; the poison turn places freely; on iPad the cards are capped and centered; the winner's count-up and rainbow appear |
| V6 | After 26.6 | Pops, iPhone SE and iPad | The toolbar's How to Play, and the commentary and undo buttons beside Roll | No overlap or clipping. Any frame that shows outside its slot is recorded for a ruling |
| V7 | After 26.13 | Pops, iPhone and iPad | House Records with a tie that has differing dates, a same-match tie, Best Average with its count, and both unclaimed forms | As D-101, D-104 and D-107 rule, in Score It \*'s card; a grid on iPad; dates like "Nov 5, 2026" |
| V8 | After 26.14 | Pops, device | Stats' two pickers; an alert; Back on a pushed screen | The pickers, alert buttons and Back take the palette's accent |

---

## 7. Open decisions

None for this round. `28` and `17_GAME_NIGHT_NEARBY_JOIN` carry their own.

---

## 8. Invariants (quick reference)

- Builds use `sylib-reintegration` against `syfive-integration`. SyLib is edited only by 26.9, 26.9b
  and 26.12, and only additively.
- `appProtocolVersion` stays 1 and the transport stays 3. `Match.options` is always `[:]` from
  SyFive.
- CloudKit Production is deployed before TestFlight (D-026).
- D-129 holds: SyFive keeps its own store and its own seed.
- D-013 holds: no `SyTheme` below the App layer.
- Scoring legality is the controller's (`legalScoreCategories`), never the card's.
- Copy is unchanged. Every string a task moves is pasted as it is today.
- D-097 to D-116 stand. The title definitions stay SyFive's (D-110).
- Score It \*'s look wins only where no ledger row fixes the look (D-160).

---

## 9. Ledger rows (paste into `00_DECISION_LEDGER.md`)

| ID | Ruling | Source |
|---|---|---|
| D-155 | **SyFive 1.2.0 is built on SyLib's `ScoringSchemaV2`** (additive: `GameModel.isArchived`, `optionsData`, `rulesLinksData`; `MatchModel.optionsData`). CloudKit Production is deployed before any TestFlight build (D-026). | `26 §2.1` |
| D-156 | **`Match` carries `options` on the wire, always `[:]` from SyFive.** `appProtocolVersion` stays 1 and the transport 3 through 1.2.0, so 1.1.x and 1.2.0 share a table. Proved by a mixed table. | `14 §1.x → 26 §2.2` (extends D-131) |
| D-157 | **SyFive's palettes are SyLibUI's `SyTheme`**, renamed in one pass; `Theme.swift` is retired, with no typealias. D-013 unchanged. | `26 §2.3` |
| D-158 | **The feel catalog (`FeelCatalog.syzygy` + SyFive's `celebration`), `DiceFeelAdapter` (SyLibDiceFeel), the dice palette, `DiceRollControls` and the game-over `GameOverOverlay` / `WinnerCard` are SyLib's.** The Yatzy moment, `celebration` and `CelebrationCoordinator` stay SyFive's. | `26 §2.4` |
| D-159 | **Settings' Audio & Feedback rows are `FeelSettingsRows`, and Haptics is hidden without haptic hardware. Appearance is `AppearanceSetting`, applied by `WindowAppearance`**; `.preferredColorScheme` leaves the root (it fixed Settings keeping its old scheme). | `26 §2.5, §2.6` |
| D-160 | **Where SyFive's look and Score It \*'s differ, SyFive takes Score It \*'s, except where a ledger row fixes the look**; those conflicts go to Pops. A defect in either app is fixed, not copied. (Pops, 6 Nov 2026.) | `26 §2.7` |
| D-161 | **The in-play scorecard is SyLibYatzyUI's card and pager**, iPad width cap included. Legality is passed per category (`scorableCategories`, built from `canScore(category:for:)`), and only the current player's card can score. Suggested values always show; the Suggested Move setting controls only the pulse (`pulsesBestSuggestion`, SyLib addition 26.9b, Pops 6 Nov 2026). The pre-game card stays SyFive's. | `26 §2.8` |
| D-162 | **Player edit is `PalettePlayerEditSheet` with `PaletteChips`**; the swatch picker is retired. SyFive's modes and writes stay in `onSave`. | `26 §2.9` |
| D-163 | **Stats uses SyLib's `SegmentedPicker`; `WindowTint` puts the palette's accent on windows, alerts and bars.** | `26 §2.11` |
| D-164 | **House Records' cards are `RecordCard`, extended in SyLib for ties, captions and unclaimed titles, and laid out in `RecordCard.grid`.** Dates read as an abbreviated date ("Nov 5, 2026"). D-097 to D-116 unchanged; the titles stay SyFive's (D-110). | `12 → 26 §2.10` |
| D-165 | **`IconButton`'s 44 pt minimum touch area is accepted**; an overflow from the dice area's 32 × 24 slots is a defect ruled on a device. | `26 §2.12` |
| D-166 | **`paletteBarBackground` lands with `28`'s palette lists**, not before. | `26 §2.13` |
| D-167 | **SyLib's `deriveInitials` splits on non-alphanumerics** ("Mary-Jo" → "MJ"). Stored initials never change; a pre-1.2.0 punctuated name's initials no longer follow a rename. Accepted. | `26 §2.14` |

---

## 10. Syderal (out of scope)

Syderal builds on the same SyLib, and with SyLib now on `main` it inherits all of this at its next
build. A Syderal session handles it. For that session:

- `ScoringSchemaV2`, with Syderal's own CloudKit Development push and Production deploy.
- `Match(… options:)` at every place where Syderal calls the initializer.
- §3's build-only changes that apply to it: the 44 pt `IconButton`, renderer v2 sounds, the
  `AppIconView` corner, `deriveInitials`, and anything it presents from SyLib that reads `syTheme`.
- The additions from 26.9, 26.9b and 26.12 change nothing for it. Its compatibility build after each one
  (`00B` §5.4) proves that.

---

## 11. Next: `28`, Score It \*'s look beyond SyLib

Much of Score It \*'s look lives in its own screens, not in SyLib: spacing and type, `List`
sections on the palette, toolbars, empty states and sheets. That is a restyle of SyFive, and it
gets its own document, **`28_SYFIVE_SCOREIT_RESTYLE.md`**. It is written after this round's
Phase 2.

- **A survey first:** each SyFive screen beside Score It \*'s closest equivalent (Players, a player's
  profile, Match History, Settings, About, House Records against Records), with each difference
  listed and the direction it goes.
- **Already in SyLib for it:** `paletteListBackground`, `paletteRowBackground`,
  `paletteBarBackground` (§2.13), and `.cardSurface()`, which SyFive doesn't use yet.
- **Also in it:** the restyled pre-game scorecard (§2.8).
- **Rulings stay rulings (D-160).** Where a ruling fixes a look (D-069 to D-073, D-097 to D-116),
  the survey lists the conflict for Pops.
- **Anything two apps would then share** is a SyLib candidate and goes through the same bar as
  every other SyLib move.

`17_GAME_NIGHT_NEARBY_JOIN.md` (bump to join) follows this round's Phase 2. It is a separate
document.

---

## 12. Results log

| Task / V | Date | Result | Totals (SyFive / SyLib) | Notes |
|---|---|---|---|---|
| 26.1 | 6 Nov 2026 | Done: `options: [:]` at both `Match(` calls, no other change | baseline: 19 / 1548 | Both on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` (iOS 18.6, 22G86). SyFive: 19 tests (22 runs), all passed; confirmed by a re-run. SyLib: 1548 tests (1623 runs), 1547 passed, 1 skipped (`writeTheV1Fixture`, env-gated). New warnings: none in SyFive; SyLib `Tests/SyLibTests/SyLibUI/RainbowRotationTests.swift` 23, 26, 53 (main actor-isolated call from a nonisolated context), reported, not fixed |
| 26.2 | 6 Nov 2026 | Done (checked by Claude against the diff) | 19 / — expected | `Theme.swift` deleted; 28 files; every changed line is the rename, the table's lookups (`themeID:`, `fallback:` at 210/309, `rawValue` kept at 460), `SyTheme(themeID:colorScheme:)` in `PlayerPickerSheet`, two imports, and `rank.ordinal`. No `Theme` type, `\.theme` key or typealias remains. MatchController lines are now +1 after 26.1 |
| 26.3 | 6 Nov 2026 | **Verified by Claude, no code change, no agent session** | — | Every sheet in `ContentView` that shows a SyLib reader of `syTheme` writes `.environment(\.syTheme, theme)`: Dice Fairness 465–474 (on its `NavigationStack`), About 476–478. Both wrote `\.theme` before, and 26.2 renamed them. The Game Night sheets (489–500) take an accent color and read no `syTheme`. The recheck moved into 26.11 and 26.14 |
| 26.4 (pre-check) | 6 Nov 2026 | Claude compared both catalogs | — | All 11 shared recipe ids (sounds, rattles and haptics) are identical in value; neither catalog sets `rootHz` or reverb. Only `celebration` is SyFive's own |
| 26.4 | 6 Nov 2026 | Done (checked by Claude against the diff) | 20 / — expected | `FeelCatalog.syFive` = `FeelCatalog.syzygy.merging(…)` with SyFive's `celebration` sound and haptic copied unchanged (verified against HEAD); 194 → 33 lines; `FeelBoardView` untouched. New test `syFiveCatalog_isSyzygyPlusOnlyCelebration` in `FeelTests.swift` |
| 26.5 | 6 Nov 2026 | Done (checked by Claude against the diff) | 20 / — expected | `App/DiceFeelAdapter.swift` deleted; `DiceAreaView` imports `SyLibDiceFeel` and its `extension SyTheme { var dicePalette }` is gone. Nothing else changed |
| 26.6 | 6 Nov 2026 | Done (checked by Claude against the diff) | 20 / — expected | `rollControls` is one `DiceRollControls`; actions, strings and toast unchanged; `rollControlHeight` and the row's `zIndex` removed |
| V6 | 6 Nov 2026 | **Pass** (Pops, iPhone and iPad) | | The tray looks as before; no slot or tap-area trouble from the 44 pt minimum (D-165) |
| 26.7 | 6 Nov 2026 | **Done** (code checked by Claude; suite re-run by the agent; Pops's device check passed on iPhone and iPad) | 20 / — expected | `GameOverOverlay` at 21 and `WinnerCard` with `CelebrationWinner`s at 125–130, as specified; `WinnerCardView`, `GameOverOverlayView`, `joinedWithAmpersand` and `makeFallParticles` deleted; file 702 lines; no new warnings. The first suite run hit the D-144 launch crash (row below) and was re-run |
| D-144 evidence | 6 Nov 2026 | Simulator launch crash during 26.7's suite (18:27, `SyFive-2026-11-06-182716.ips`) | | iPhone SE (3rd generation), iOS 18.6. SIGABRT on the main thread, display-link driven, all RealityKit: `PhysicsSystem::ecsToSim` → `ForceEffectComponent` → `_os_crash_msg`, no SyFive frame. Same class as `17` §11, but through `ForceEffectComponent` rather than `PhysicsSimulationComponent`. The agent also mentioned a crash during 26.5 and a Network crash at 17:19; their details aren't recorded here. Still simulator-only; D-144 holds (no SyLib dice change without device evidence) |
| 26.8 | 6 Nov 2026 | Done (checked by Claude against the tree) | 20 / — expected | `FeelSettingsRows` with `hapticsSupported: director.hapticSupported` and `FeelSettingsRows.footer`; `AppColorScheme` deleted, computed `colorScheme` is `AppearanceSetting`, stored default unchanged; `.preferredColorScheme` replaced by `WindowAppearance.apply` (ContentView 261, 405); Settings sheet passes the director. Follow-up: `SettingsView`'s `#Preview` has no `FeelDirector`; harmless while its store is empty, added in 26.10 |
| V4 | 6 Nov 2026 | **Pass** (Pops, iPhone and iPad) | | Settings changes scheme at once from inside itself |
| 26.9 | 6 Nov 2026 | Done (checked by Claude against the SyLib diff) | 20 / 1551 expected | `YatzyScorecardContent.scorableCategories` (nil default) in `isScorable`; card init parameter after `canScore`; `YATZY.md` documented; 3 tests, including the pulse staying among legal cells. Additive, staged on `syfive-integration` |
| 26.9b | 6 Nov 2026 | Done (checked by Claude against the SyLib diff) | 20 / 1553 expected | `pulsesBestSuggestion` (default true) on `YatzyScorecardContent`, in `bestSuggestedCategory`'s guard only, and on the card init after `suggestedValues`, passed through; `YATZY.md` documented; 2 tests. Additive |
| 26.10 | 6 Nov 2026 | Done (checked by Claude against the tree) | 20 / — expected | `ScorecardView`'s in-play branch is `YatzyScorecardPager` with the 26 table's inputs; `inGameView` and its helpers removed; `PlayerScoreCardView` untouched; Settings preview has its director. Leftovers for `28`: unused `colorScheme`, `sizeCategory`, `logger` and the `availableWidth` parameter in `ScorecardView` |
| V5 | 6 Nov 2026 | **Pass** (Pops, iPhone and iPad) | | |
| 26.11 | 6 Nov 2026 | Done (checked by Claude against the tree); device check passed on iPhone and iPad (Pops) | 20 / — expected | `PlayerEditSheet` wraps `PalettePlayerEditSheet` (nil limits, SyLib `deriveInitials`); today's writes in `onSave`, no second dismiss; the two Game Night sites in `GameNightScreens.swift` now pass `\.syTheme` (45, 165). Game Night checks deferred (below) |
| Game Night pass | 6 Nov 2026 | **Deferred to the end of this build** (Pops) | | One pass after the last task: V3 (mixed table), and the Game Night edit-sheet checks from 26.11 (edit own seat, create a player while claiming a seat) |
| 26.12 | 6 Nov 2026 | Done (checked by Claude against the SyLib diff) | — / 1558 expected | `RecordCard.Holder`, `Content`, `init(title:content:)`; the holder-name init maps onto one claimed holder and draws as before; per-holder dates when they differ; captions; unclaimed with the value's room kept; `RecordCard.grid` with `nonisolated` spacing and column count; 3 new previews; `SCORING_UI.md` updated; 5 tests in `RecordCardTests.swift`. Score It untested from here (its own copy is unchanged) |
| 26.13 | 6 Nov 2026 | Done (checked by Claude against the tree) | 20 / — expected | House Records lays both sections in `RecordCard.grid` (one width, measured on the first), with `content(for:)` mapping `TitleState` and today's copy; `TitleCard`, `ClaimedContent`, `HolderRow` and `UnclaimedContent` deleted; 130 lines |
| V7 | 6 Nov 2026 | **Pass** (Pops, iPhone and iPad) | | |
| 26.14 | 6 Nov 2026 | Done (checked by Claude against the tree) | 20 / — expected | Both Stats pickers are `SegmentedPicker` with today's selections and text (no `.pickerStyle(.segmented)` remains); `WindowTint.apply` at launch (ContentView 263) and on theme change (408); `.tint` kept. `\.syTheme` reaches both: `PlayerProfileView` 154 (the player's palette), History via `ContentView` |
| V8 | 6 Nov 2026 | **Pass** (Pops, iPhone and iPad) | | A player's profile keeps its toolbar buttons in the player's color under `WindowTint` |
| Syderal checks | 6 Nov 2026 | **Not run** (correction, Claude) | | `00B` §5.4's Syderal compatibility build could not run for 26.9, 26.9b or 26.12 (nor 27.1): Syderal doesn't compile against SyLib since `0ee6219`, because its `Match(` calls lack `options:` (e.g. `RecordsStore.swift` 353, `GameNightMatchBridge.swift` 474), the break §10 records. Earlier rows that implied Syderal passed were written without the agent's reports. All the SyLib changes are additive with defaults that keep today's behavior, but Syderal is unverified until it adopts `options` in its own session. **Pops, 6 Nov 2026: Syderal's fix and its check wait for Syderal's next release; SyFive 1.2.0 ships with Syderal unverified against this round's SyLib changes** |
| V1 | 6 Nov 2026 | **Pass** (Pops) | | Every look and listen as described. `game_end`'s end click is gone, and no tick after it with Haptics off: Score It \*'s open item doesn't reproduce in SyFive |
| V2 | 6 Nov 2026 | **Pass** (Pops) | | `initializeCloudKitSchema` logged "Development schema initialized". The Production deploy dialog listed exactly `CD_GameModel` + `CD_isArchived`, `CD_optionsData`, `CD_rulesLinksData` and `CD_MatchModel` + `CD_optionsData`, each `Data` field with its `_ckAsset` companion, plus 8 sortable/queryable indexes. Additive only |
| Ship: Production deploy | 7 Nov 2026 | **Done** (Pops) | | CloudKit Production deployed from Development for `iCloud.com.syzygysoftwerksllc.SyFive`, before the first 1.2.0 TestFlight build (D-155; `00B` §6) |
| V3 | 6 Nov 2026 | **Deferred** (Pops) | | No later task changes the wire, so it can run at any point before ship; it must pass before TestFlight |

---

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 5–6 Nov 2026 | Design for review: Part A (absorb), Part B (fifteen adoptions), ten questions. Updated 6 Nov with Pops's direction (Score It \*'s look) and Score It \*'s `25`. |
| 2.0 | 6 Nov 2026 | Task document. All questions ruled (§2). Re-pinned to `syfive-integration` at `0ee6219` (SyLib `main`) and SyFive `sylib-reintegration`. Found and ruled the per-category legality gap in the SyLib scorecard (26.9). Specified the `RecordCard` extension and grid from Score It \*'s source. Added §2.15 exclusions, tasks, validation, invariants, Syderal's inheritance and §11. Counts verified against the tree. |
