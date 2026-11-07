# SyFive in Score It \*'s look, beyond SyLib: the restyle

**Status:** **Done (28.1 to 28.5); V1–V7 with Pops.** Version 1.2, 7 November 2026. In SyFive 1.2.0, before the
first TestFlight build (Pops, 7 November 2026: everything in this round is 1.2.0).

**Scope:** `syfive-ios` on `sylib-reintegration`. SyLib is unchanged: every piece used here is
SyLib's today.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A`, `00B`, this document, SyLib
`Docs/UI_COMPONENTS.md` and `Docs/THEME.md`.

---

## Supersessions

- **This is `26` §11's `28`**, planned there and not written until now; `29` to `32` were written
  meanwhile. D-166 ("`paletteBarBackground` lands with `28`'s palette lists") is met here.
- **SyFive's accent-colored section headers go** (§2.2). Nothing in the ledger fixed them.
- **The player picker's roster becomes chips** (§2.6, D-190): its roster pencil, its Archive swipe
  and its Archived section go; Players (`30`) is where a player is edited, archived and unarchived.
- D-164 (House Records' cards and grid) and D-145 (How to Play's "Got it") stand; nothing here
  touches them.

---

## 1. The survey (7 November 2026)

Each SyFive screen read beside Score It \*'s closest (`score-it-all-ios` at `3c26af0`, read only).
Already restyled and not in it: Players (`30`) and the profile header (`31`). Every SyFive sheet
already reaches `\.syTheme` (the current player's palette, set at each presentation in
`ContentView`) and already takes its text-size cap (`29`).

| Screen | SyFive | Score It \* |
|---|---|---|
| Lists everywhere | System backgrounds; no palette list, row or bar background in SyFive's own code | `paletteListBackground()`, `paletteRowBackground()` on every row or section, `paletteBarBackground()` (`25`) |
| Section headers | `Text(…).foregroundStyle(theme.primaryAccent)` | Plain `Section("…")` / `Text("…")` in lists and forms; `SectionHeader("…")` over setup's sections and the profile's |
| Sheets' tint, Done | No `.tint`; Done mostly `.topBarTrailing` | `.tint(syTheme.primaryAccent)`; Done `.confirmationAction` |
| Settings (`SettingsView`) | Accent headers (50, 58, 67, 85, 95); Appearance a menu `Picker` (44) | Plain headers; Appearance a `SegmentedPicker` (`SettingsSheet` 43) |
| Dice Fairness (`ContentView` 487) | SyLib's `DiceFairnessView` on the system list | The same view, `.paletteListBackground(theme.backgroundColor)`, `.tint` (`DiceFairnessScreen` 14–15) |
| Profile body (`PlayerProfileView`) | Cards on `theme.backgroundColor`, titles `Text(…).font(.headline)` (380, 397); empty state `ContentUnavailableView` (159) | `SectionHeader` titles (176, 196, 240); `EmptyStateView` (102); palette list and bar |
| Match History (`MatchHistoryView`) | System list; two `ContentUnavailableView` overlays (138, 144); Delete All and Done together `.topBarTrailing` (120–130) | Palette list, rows, bar (`AllHistoryView` 34–40); `EmptyStateView` |
| Match and unfinished detail | System background; cards in `secondarySystemBackground` (MatchDetail 117, 131, 175; Unfinished 125, 139, 182) | The palette background and surfaces; `paletteBarBackground` (`MatchView` 412, 422) |
| Player picker (`PlayerPickerSheet`) | System list; roster rows with pencil, + and an Archive swipe (165–210); an Archived section with Unarchive (78–86, 211–240); a custom empty prompt (248) | Seats a list with a hint row "Tap a player below to seat them." (`SeatList` 19); players a `FlowLayout` of `SelectableChip`s in each player's palette, New Player last (`PlayerPicker` 17–29); `SectionHeader`s; palette list, rows, bar |
| House Records (`HouseRecordsView`) | `ScrollView` on the system background; its own accent `RecordsSectionHeader` with a subtitle (72–89) | `SectionHeader("Records")` (`GameDetailView` 383); palette list and bar |
| About (`AboutView` 6) | Always Midnight | The app's palette |
| The studio's App Store link (`ContentView` 545) | The URL written out | `SyzygyLinks.developerAppStore` (`GameListView` 154) |
| Feel Board (`FeelBoardView`, DEBUG) | System `List`, accent "Master" header (83) | Palette form |

---

## 2. Locked decisions (Pops, 7 November 2026)

**2.1 Every SyFive list is on the palette** (D-187): `paletteListBackground()` on the list or form,
`paletteRowBackground()` on each section (or row), `paletteBarBackground()` on each stack's root,
`.tint(theme.primaryAccent)` on each sheet's stack, as Score It \*. *Rationale:* D-160; today only
Players is.

**2.2 Section headers are Score It \*'s** (D-188): plain `Text("…")` in a list or form's sections;
`SectionHeader("…")` over the picker's and the profile's. No accent-colored headers.

**2.3 Sheets' Done is `.confirmationAction`** (D-188).

**2.4 Empty screens are `EmptyStateView`**, with today's words (D-188). The progression chart's
in-card message stays (it is a chart's placeholder, not a screen).

**2.5 The profile keeps its cards, on the palette** (D-189; Pops). Its titles become
`SectionHeader`; its cards keep `theme.cellBackgroundColor`. The match detail screens' cards take
the same fill in place of `secondarySystemBackground`.

**2.6 The player picker's roster is Score It \*'s chips** (D-190; Pops). "Playing" stays a list
(turn order, drag to reorder, swipe to remove, a pencil that edits the seat). "Roster" becomes a
`FlowLayout` of `SelectableChip`s, each in its player's palette; a tap seats them; New Player is the
last chip. Editing, archiving and unarchiving are Players' (`30`).

**2.7 Dice Fairness and the Feel Board stay in ⋯** (Pops); only their look changes.

**2.8 About is in the current palette, and the studio link is `SyzygyLinks`** (D-191).

### 2.9 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| The profile as a `List` | §2.5 (Pops) |
| Dice Fairness and Feel Board rows in Settings | §2.7 (Pops) |
| Head-to-head's `noun: .match`, `showsAverageScore: false` | Score It \*'s words for its matches; SyFive's are games, and Yatzy averages mean something |
| Renaming `.sheetTextSizeCeiling()` to Score It \*'s `.appTextSizeCap()` | Two names for one cap (`29`); neither is SyLib's |
| `.cardSurface()` for the cards | A fixed white wash, not the palette's cell color |
| The record cards, the grid, How to Play's button | D-164, D-145 |
| Score It \*'s match screen toolbar for the unfinished detail | SyFive's Resume stays |

---

## 3. Tasks

Every task: **Must not touch** SyLib, D-164's cards and grid, D-145's button, behavior beyond what
the task names. **Done when:** the build and SyFive's suite pass (20); report each site changed by
file and line, and any list, form or header found that the task doesn't name, left as it was.

### Task 28.1 · Settings and the ⋯ screens

- **`Views/SettingsView.swift`:**
  - The `Form`: `.paletteListBackground()`.
  - Each section: `.paletteRowBackground()`.
  - Headers: plain `Text("…")`, the `.foregroundStyle(theme.primaryAccent)` removed.
  - Appearance's Color Scheme: `SegmentedPicker("Color Scheme", selection: $settings.colorSchemeRaw,
    segments: AppearanceSetting.allCases.map { ($0.rawValue, $0.displayName) })`, as Score It \*'s 43.
  - `SettingsView`'s stack: `.paletteBarBackground()`, `.tint(theme.primaryAccent)`, and Done
    `.confirmationAction`.
- **`App/Commentary/CommentaryScreens.swift`:** `CommentarySettingsView(…)` gains
  `.paletteListBackground()` and `.tint(theme.primaryAccent)`, as Score It \*'s Dice Fairness.
- **`ContentView` Dice Fairness sheet (487–493):** `DiceFairnessView(…)` gains
  `.paletteListBackground(theme.backgroundColor)`, `.tint(theme.primaryAccent)` and
  `.paletteBarBackground()`; Done `.confirmationAction`.
- **`Views/FeelBoardView.swift`:** the `List`, `.paletteListBackground()`; sections,
  `.paletteRowBackground()`; the "Master" header plain; its stack `.paletteBarBackground()`,
  `.tint`, Done `.confirmationAction`.
- **`Views/AboutView.swift`:** `theme` is `@Environment(\.syTheme)`, not Midnight; its previews pass
  `.environment(\.syTheme, SyTheme(type: .midnight, colorScheme: …))`.
- **`ContentView` 545:** `openURL(SyzygyLinks.developerAppStore)`; import SyLibCore if needed.

### Task 28.2 · Match History and match detail

- **`Views/Stats/MatchHistoryView.swift`:** the `List`, `.paletteListBackground()`; its sections or
  rows, `.paletteRowBackground()`; the stack `.paletteBarBackground()` and `.tint`; Done its own
  `ToolbarItem(.confirmationAction)`, Delete All staying `.topBarTrailing`. The two overlays become
  `EmptyStateView(systemImage:title:message:)` with today's symbols and words.
- **`Views/Stats/MatchDetailView.swift`, `UnfinishedMatchDetailView.swift`:** the screen's
  background `theme.backgroundColor`; each card's `Color(UIColor.secondarySystemBackground)`
  becomes `theme.cellBackgroundColor`; `.paletteBarBackground()`; `.tint(theme.primaryAccent)`.
  `theme` is `@Environment(\.syTheme)` where the view has none. The DEBUG log button and Resume are
  unchanged.

### Task 28.3 · The profile body and House Records

- **Also (from 28.2):** `MatchHistoryView`'s `VStack` (43) gains `.background(theme.backgroundColor)`, so the
  Finished/Unfinished picker sits on the palette, as Score It \*'s split lists put the screen's background on
  the content (`25` §1).

- **`Views/Stats/PlayerProfileView.swift`:** the titles at 380 and 397 become `SectionHeader(title)`;
  the empty state (159) `EmptyStateView(systemImage: "chart.bar.xaxis", title: "No games yet",
  message: "Finish a game to see your stats.")`; `.paletteBarBackground()` on `content`. The cards,
  their fills and the background are unchanged.
- **`Views/HouseRecords/HouseRecordsView.swift`:** the background `theme.backgroundColor`;
  `.paletteBarBackground()`, `.tint`, Done `.confirmationAction`; `RecordsSectionHeader`'s title
  becomes `SectionHeader(title)`, its subtitle unchanged under it. The cards and grid are D-164's.

### Task 28.4 · The player picker's chips

- **`Views/PlayerPickerSheet.swift`:**
  - The `List`: `.paletteListBackground()`; each section `.paletteRowBackground()`; the stack
    `.paletteBarBackground()`, `.tint(theme.primaryAccent)`; Done stays `.confirmationAction`.
  - **Playing:** unchanged rows and behavior; header `SectionHeader("Playing")`. When no one is
    seated, the section shows one row, "Tap a player below to seat them.", `.secondary`, as Score
    It \*'s `SeatList` 19, and is shown even then.
  - **Roster:** one row, a `FlowLayout` of `SelectableChip(player.name, isSelected: false, action: {
    model.addPlayer(from: player.toDomain()) }, tintsWhenUnselected: true)` tinted
    `SyTheme.accent(forThemeID: player.themeID, colorScheme:)`, for `availablePlayers`, then
    `SelectableChip(isSelected: false, action: { playerEditMode = .create }) { Label("New Player",
    systemImage: "plus").labelStyle(.titleAndIcon).fixedSize() }`, `.padding(.vertical, 4)`, as Score
    It \*'s `PlayerPicker` 17–29; header `SectionHeader("Roster")`.
  - **Removed:** `rosterRow`, `archivedRow`, the Archived section, `archivedPlayers`,
    `pendingArchive` and its alert, and `emptyRosterPrompt` (§2.6).
  - The editor sheet stays (the seat pencil and New Player use it).

### Task 28.5 · The leftovers (from a second sweep, 7 November 2026)

A second read of Score It \*'s use of SyLib (every SyLib type, modifier and argument Score It \*
uses and SyFive doesn't; `23A` §6's and `25` §6's lists for SyFive; SyLib's "SyFive adoption"
notes) found these, all D-187, D-188 or D-192. Everything else was already adopted or is excluded
(§2.9, `26` §2.10's table).

- **Done `.confirmationAction`** (D-188), where 28.1 to 28.3 didn't reach:
  `Views/Stats/PlayerProfileView.swift` 173 (the sheet form's Done) and `Views/HowToPlayView.swift` 64.
- **Bars and tint** (D-187): `HowToPlayView`'s stack and `App/GameNight/Views/TableSettingView.swift`'s
  gain `.paletteBarBackground()` and `.tint(theme.primaryAccent)` (`theme` from `\.syTheme` where the
  view has none). Nothing else in either changes: How to Play keeps its background, Game Night's
  table keeps Leave and Start.
- **Toolbar buttons are `IconButton(…, context: .toolbar)`** (D-192), as every toolbar button in Score
  It \* is (SIA-216):
  - `Views/ContentView.swift` 90: `IconButton("questionmark.circle", context: .toolbar)`.
  - `ContentView.swift` 81–84 (Game Night Help), `Views/ContentView+GameNight.swift` 64–69 (Play
    Again, `arrow.clockwise.circle`), 72–75 (New Game, `arrow.clockwise`), 78–85 (play again,
    `plus`), and `TableSettingView` 45–48 (Game Night Help): each `Button { … } label: {
    Image(systemName:) }` becomes `IconButton(systemName, context: .toolbar) { … }` with the same
    action and `accessibilityLabel`.
  - `GameNightLeadingControlButton` is SyLib's and stays.
- **Must not touch:** SyLib; How to Play's content and "Got it" (D-145); any action.

## 4. Validation (Pops, iPhone and iPad, light and dark, two palettes)

| # | Check | Pass |
|---|---|---|
| V1 | Settings, Commentary, Dice Fairness, Feel Board | The palette behind lists and rows and under the bar once scrolled; plain headers; Appearance segmented; Done on the right in the accent |
| V2 | About | In the current palette; the studio link opens the App Store |
| V3 | Match History (both segments, and empty), a finished game, an unfinished game | Palette list and bar; empty states as Players'; detail cards in the palette's cell color; Resume works |
| V4 | A profile (pushed and as a sheet) and House Records | Titles as Score It \*'s; "No games yet" as an empty state; cards as before |
| V5 | New Game's picker: seat from chips, New Player chip, reorder, remove, pencil on a seat | Chips in each player's palette; the hint row with nobody seated; no Archive in the picker |
| V6 | At AX5 | Every screen holds at AX2 (29); chips wrap |
| V7 | After 28.5: the game screen's toolbar before, during and after a game, and in Game Night (host, at the table) | Every toolbar symbol the same size and weight as the ⋯; Done on the right in How to Play and a profile sheet; How to Play's and Game Night's bars on the palette |

## 5. Ledger rows

| ID | Ruling | Source |
|---|---|---|
| D-187 | **Every SyFive list is on the palette**: `paletteListBackground`, `paletteRowBackground`, `paletteBarBackground` and the accent tint on each sheet, as Score It \*. Meets D-166. | `28 §2.1` (Pops, 7 Nov 2026) |
| D-188 | **Headers, Done and empty states are Score It \*'s**: plain headers in lists and forms, `SectionHeader` over the picker's and profile's sections, Done `.confirmationAction`, `EmptyStateView` with today's words. | `28 §2.2–2.4` |
| D-189 | **The profile keeps its cards, on the palette**; the match detail cards take `theme.cellBackgroundColor`. | `28 §2.5` (Pops, 7 Nov 2026) |
| D-190 | **New Game's roster is Score It \*'s chips**; "Playing" stays a list; editing, archiving and unarchiving are Players'. | `28 §2.6` (Pops, 7 Nov 2026) |
| D-191 | **About is in the current palette; the studio link is `SyzygyLinks.developerAppStore`.** Dice Fairness and the Feel Board stay in ⋯. | `28 §2.7–2.8` (Pops, 7 Nov 2026) |
| D-192 | **SyFive's toolbar buttons are `IconButton(…, context: .toolbar)`**, as Score It \*'s (SIA-216); SyLib's own controls stay. | `28` Task 28.5 |

## 6. Results log

| Task / V | Date | Result | Notes |
|---|---|---|---|
| 28.1 | 7 Nov 2026 | Done (checked by Claude against the tree) | `SettingsView`: Form on the palette, `paletteRowBackground` on all five sections, plain headers, Color Scheme a `SegmentedPicker`, stack bar background and tint, Done `.confirmationAction`. `CommentaryScreen`: list background and tint. Dice Fairness sheet: list background, tint, bar, Done `.confirmationAction`. `FeelBoardView`: list, three section builders' rows, bar, tint, plain "Master". `AboutView`: `\.syTheme`, previews pass Midnight. `ContentView`: `SyzygyLinks.developerAppStore`. SyFive 20 expected |
| 28.2 | 7 Nov 2026 | Done (checked by Claude against the tree) | `MatchHistoryView`: List on the palette (116), `paletteRowBackground` on its four row groups, bar (125), tint; Done its own `.confirmationAction`, Delete All alone `.topBarTrailing`; both overlays `EmptyStateView` with today's words. Both detail views: `\.syTheme`, `theme.backgroundColor`, three cards each on `cellBackgroundColor`, bar, tint. **Gap, the spec's:** the `VStack` holding the Finished/Unfinished picker above the List has no background, so the picker's strip shows the system color; fixed in 28.3 (see there). SyFive 20 expected |
| 28.3 | 7 Nov 2026 | Done (checked by Claude against the tree; a first report landed nothing on disk, the second did) | `PlayerProfileView`: "Opponents" and the card titles `SectionHeader`; the empty state `EmptyStateView` with today's words; `paletteBarBackground` on `content`; cards unchanged. `HouseRecordsView`: `theme.backgroundColor`, bar, tint; Done was already `.confirmationAction`; `RecordsSectionHeader`'s title `SectionHeader`, subtitle unchanged, its own theme read removed; cards and grid untouched (D-164). `MatchHistoryView`'s `VStack` on `theme.backgroundColor` (123), closing 28.2's gap. SyFive 20 expected |
| 28.5 | 7 Nov 2026 | Done (checked by Claude against the tree) | Done `.confirmationAction` in `PlayerProfileView` (sheet form) and `HowToPlayView`; `HowToPlayView` and `TableSettingView` bar background and tint; `ContentView`'s ? `context: .toolbar`; Game Night Help (both), Play Again, New Game and the finished game's + are `IconButton(…, context: .toolbar)` with their actions and labels unchanged; SyLib's leading control, Leave and Start untouched. SyFive 20 expected |
| 28.4 | 7 Nov 2026 | Done (checked by Claude against the tree) | `PlayerPickerSheet` (291 → 177 lines): list, both sections' rows, bar, tint on the palette; Done `.confirmationAction`. Playing always shown with the hint row when nobody is seated, its rows, reorder, remove and seat pencil unchanged, `SectionHeader("Playing")`. Roster a `FlowLayout` of `SelectableChip`s in each player's palette seating on tap, New Player last, `SectionHeader("Roster")`. `rosterRow`, `archivedRow`, the Archived section, `archivedPlayers`, `pendingArchive` and its alert, `emptyRosterPrompt` removed; the editor sheet kept. SyFive 20 expected |
| V1–V6 | | | |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 7 Nov 2026 | First version, from the survey in §1 |
| 1.1 | 7 Nov 2026 | 28.3 also gives Match History's picker strip the palette background (a gap in 28.2's spec) |
| 1.2 | 7 Nov 2026 | Task 28.5 and V7, from a second sweep of Score It \*'s SyLib use; D-192 |
