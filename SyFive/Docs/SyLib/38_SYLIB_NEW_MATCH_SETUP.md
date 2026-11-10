# SyLib match setup: Score It \*'s New Match pieces, shared, and SyFive's New Game on them

**Status:** **Closed, 10 November 2026.** 38.1 to 38.11 done and checked; V1 to V8 pass; D-203 to D-208 filed and D-190 rewritten in the ledger. Score It \* adopts in its own session (§4).
Score It \* adopts in its own session (§4). Version 1.13, 10 November 2026.

**Scope:** `sylib-swift` (SyLibScoringUI) for 38.1; `syfive-ios` for 38.2. One project per session
(`00A` v1.8).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md` (v1.12),
`00B_SYFIVE_GUARDRAILS.md` (v1.4), this document, SyLib `Docs/SCORING_UI.md`. `00A` §6: the session's
row goes at the top of §6. §7: `00B`'s pinned commands. §8: fix your own errors and warnings.

---

## 1. Why

Pops, 9 November 2026: Score It \*'s New Match sheet works and looks the way SyFive's New Game should:
a draft with Cancel and Start, Same as Last Time, numbered seats with their handles showing, and its
look. D-190 (`28` §2.6) already copied two of its pieces into SyFive's `PlayerPickerSheet` as copies,
and they have drifted. Pops's constraint: **adopting the SyLib version must cost Score It \* very
little.** So SyLib takes Score It \*'s pieces as they are, signatures kept, rather than one sheet that
Score It \* would have to rebuild itself around.

**Read on 9 November 2026:**
- Score It \*'s `Views/Match/Setup/`: `MatchSetupSheet.swift` (807 lines: frame, Same as Last Time,
  teams and sides, scoring and options sections, its own sheets), `SeatList.swift` (54) and
  `PlayerPicker.swift` (36). `SeatList` and `PlayerPicker` use only SyLibUI (`SectionHeader`,
  `InitialsCircle`, `SelectableChip`, `FlowLayout`, the palette modifiers) and SyLibScoringData's
  `PlayerModel`, which both apps use.
- Score It \*'s "last time" rule (`Domain/Match/SetupRules.swift` 84, `sameAsLastTime(matches:)`) uses
  its `RoundPlan`, so it stays Score It \*'s.
- SyFive's `PlayerPickerSheet` (177 lines) opens from `PreGameGridView` while `canEditPlayers` (before
  the first roll or score) and edits the live `MatchController` with each tap; Done closes. The game
  starts at the first roll. `resetGame()` keeps the players for the next game.

---

## 2. Locked decisions (Pops, 9 November 2026)

**2.1 SyLibScoringUI gains four pieces, lifted from Score It \*** (D-203). Each keeps Score It \*'s
behavior, look and, where it has one, signature:

| Piece | From | Shape |
|---|---|---|
| `SeatList` | `Setup/SeatList.swift`, whole | `SeatList(players: [PlayerModel], onMove:, onRemove:)`: "Seats", numbered 1, 2, 3 with initials circles, the "Tap a player below to seat them." hint when empty |
| `PlayerPicker` | `Setup/PlayerPicker.swift`, whole | `PlayerPicker(players: [PlayerModel], onSeat:, onNewPlayer:)`: "Players", a chip per unseated player in its palette, New Player last |
| `SameAsLastTimeSection` | the full-width capsule section `MatchSetupSheet` draws twice (338–342, 302–307) | `SameAsLastTimeSection(_ title: String = "Same as Last Time", action:)`: an `.accent` `CapsuleButton`, full width, clear row |
| `MatchSetupForm` | `MatchSetupSheet`'s frame (289–407) | `MatchSetupForm(title:, canStart:, onCancel:, onStart:, content:)`: `NavigationStack` › `List { content }`, edit mode always active (handles and delete showing), palette list and bar backgrounds, inline title, Cancel and Start (Start disabled unless `canStart`), the sheet tinted with the palette accent |

Each app keeps its own rules: who "last time" was, when Start is allowed, and what Start does.

**2.2 Score It \*'s adoption is small** (§4): delete `SeatList.swift` and `PlayerPicker.swift`; replace
its frame with `MatchSetupForm`; its two capsules become `SameAsLastTimeSection`. Teams, sides, options,
scoring sections, `SetupRules` and its sheets don't change.

**2.3 SyFive's New Game is built from the four pieces** (D-190 superseded):
- **Opens** where it does now: from the pre-game grid, for a new game and to change the seats before
  the first roll.
- **A draft:** it works on a list of player ids, starting from the current seats; nothing changes in
  the game until **Start**, and **Cancel** discards it. Start applies the seats; the first roll still
  starts the game (Pops: "Start applies seats").
- **Same as Last Time:** the players of the most recent completed game that wasn't Game Night, in seat
  order, keeping only active roster players; shown when that list isn't empty and differs from the
  draft.
- **Seats** as Score It \*'s: numbered, plain names, no pencil, no "Turn N" (Pops). Players are edited
  from the Players sheet.
- **Start allowed** with at least one seat.
- **New Player** creates a player and seats them in the draft (the created player is kept even on Cancel,
  as in Score It \*).
- **Game Night** seating is unchanged.

**2.5 A seat is removed with a swipe that says Remove** (D-204; Pops, 9 November 2026, testing
38.2). `SeatList` takes a player out of the setup; it deletes no one. Its `.onDelete`, under the
form's always-on edit mode, shows iOS's minus circle and a **Delete** button, and SwiftUI can't rename
that button. Pops likes swiping to remove.
- **The rule:** each seat swipes from the trailing edge to a red **Remove** (`role: .destructive`),
  which calls `onRemove`. `.onDelete` goes, and with it the minus circle. The drag handles stay
  (`.onMove`).
- **Not known yet:** whether a row's swipe actions work while the list is in edit mode (UIKit turns
  swipe-to-delete off in editing). **Pops checks it on device (V5)**, not the agent (`00B` §3 v1.5:
  no previews, no simulator sessions; v1.1 wrongly asked the agent to check in the simulator). If the
  swipe doesn't show, Pops chooses: drop the always-on edit mode (rows reorder by long-press drag,
  handles hidden), or a one-tap minus button labelled Remove for VoiceOver.
- **V5 failed** (Pops, on device, 9 November 2026): under the always-on edit mode the swipe shows no
  button and only moves from the row's very edge. Edit mode turns swipe actions off, as feared.
- **The fix (Pops: "we have swiping in the Players sheet that works great"):** do what SyFive's own
  New Game did before 38, which Pops liked, and what the Players sheet does: **no edit mode.**
  - `MatchSetupForm` drops `.environment(\.editMode, .constant(.active))`.
  - Each seat swipes to `Label("Remove", systemImage: "xmark")`, `.tint(.red)`, as SyFive's old
    `PlayerPickerSheet` did (its last version, `git show HEAD:SyFive/SyFive/Views/PlayerPickerSheet.swift`
    124–144).
  - A trailing `line.3.horizontal` handle icon stays on each seat, drawn by the row, not by edit mode,
    as the old sheet's was; rows reorder by long-press and drag (`.onMove` without edit mode).
- **Score It \*** gets the same when it adopts (§4): Remove by swipe, the drawn handle, no edit mode.

**2.6 The Seats section says how to remove and reorder** (D-205; Pops, 9 November 2026). Without
edit mode both gestures are hidden. `SeatList`'s section gets a footer, standard footer style:
- **One seat:** "Swipe left to remove."
- **Two or more:** "Swipe left to remove. Touch and hold to reorder." ("Touch and hold" is Apple's
  word for a long press.)
- **None:** no footer; the empty hint already shows.
- **Always on,** no parameter: Score It \* takes it too when it adopts (Pops). It shows every time;
  a hint that hides after use would need stored state, not worth one line.

**2.7 Same as Last Time is the first chip in Players, solid, with a repeat arrow** (D-206; Pops,
9 November 2026). The capsule above the seats sat apart from the players it seats.
- **Where:** the first chip in `PlayerPicker`, before the player chips and New Player.
- **Look:** a solid chip, filled with the palette's accent, white text, `arrow.counterclockwise` before
  the label, so it reads as an action, not a player. Same size, font and padding as the other chips.
- **No "selected" trait:** it's drawn as `SelectableChip`'s filled look through a new `emphasized`
  option, so VoiceOver reads a button, not a selected chip.
- **Visibility:** the app passes the action only when it should show; nil shows no chip. **SyFive
  compares players, not order** (Pops, v1.6): the chip shows when last time's *set* of players differs
  from the draft's, so reordering the seats never brings it back.
- **Also fixes the animation** (Pops): the old capsule was a whole List section appearing and
  disappearing while the seats animated; as a chip it only reflows the chips.
- **Score It \*'s "Same Teams as Last Time"** becomes the same chip, first in its own Teams section
  (`SetupTeamsSection`), when it adopts (Pops).
- **`SameAsLastTimeSection` is retired** (38.6).

**2.8 SyFive: Done, with live edits; Score It \*: Cancel and Start, with a draft** (D-207; Pops,
9 November 2026; amends §2.3). SyFive's Start started nothing, and a draft with no Cancel would lose
changes silently on swipe-down.
- **`MatchSetupForm` gets a button mode,** `buttons: MatchSetupForm.Buttons = .cancelAndStart`:
  - `.cancelAndStart` (default, Score It \*): as now; Cancel calls `onCancel`, Start calls `onStart`,
    disabled unless `canStart`.
  - `.done` (SyFive): one **Done** in the confirming position, calling `onStart`, disabled unless
    `canStart`; no Cancel (`onCancel` unused).
- **SyFive edits the game live,** as before 38: seating a player, reordering, removing and Same as
  Last Time change `MatchController` at once (`addPlayer(from:)`, `movePlayer(from:to:)`,
  `removePlayer(at:)`, `setPlayers(_:)`). On iPad the pre-game grid behind the sheet follows along.
  Done, or swiping the sheet down, just closes. Nothing can be lost.
- **An empty table is allowed** (Pops): SyFive passes `canStart: true`.
- **Score It \* is unchanged:** its draft, applied by Start and discarded by Cancel or a swipe down.
- §2.3's "draft", "Start applies the seats" and "Start allowed with at least one seat" are replaced
  for SyFive by this section.

**2.9 The action chips' icons sit next to their titles** (Pops, 9 November 2026, on device). New
Player's plus sits far from its title, and Same as Last Time's arrow the same: inside a `List` row a
`Label` puts its icon in the row's fixed-width icon column, whatever its label style, so the gap
isn't ours to tune.
- **Both action chips in `PlayerPicker`** draw their label as an `HStack(spacing: 4)` of the
  `Image(systemName:)` and the `Text`, not a `Label`, still `.fixedSize()`. The icon takes the chip's
  font, so it scales with the title. Size, font, colors and the `emphasized` look are unchanged.
- **VoiceOver** reads each chip by its title only: the icon is `.accessibilityHidden(true)`, so "New
  Player" and "Same as Last Time" read as they did.
- **Score It \*** gets this by adopting (§4). Its own `AddPlayerSheet` has the same `Label` chip,
  outside 38; noted for its session.

**2.10 `SelectableChip` draws an icon and title itself** (D-208; Pops, 9 November 2026; follows
§2.9). 38.10 fixed the gap with a private helper in `PlayerPicker`, but every chip with an icon builds
its own label, and a `Label` brings the gap back inside any `List`: SyLib's own `SelectableChip`
examples, Score It \*'s `AddPlayerSheet` and `GameEditorSheet`, and Syderal if it takes `PlayerPicker`.
- **A new initializer**, alongside the text one: `SelectableChip(_ title: String, systemImage:
  String, isSelected: Bool, tintsWhenUnselected: Bool = false, emphasized: Bool = false, action:)`,
  in the same parameter order as the text initializer with `systemImage` after the title. It draws
  §2.9's label: the icon, then the title, 4 pt apart, `.fixedSize()`, the icon hidden from VoiceOver.
  The label is a small public view, `SelectableChipIconLabel(title:systemImage:)`, so the initializer
  is `where Label == SelectableChipIconLabel`.
- **Purely additive:** the existing initializers and every current call are unchanged.
- **`PlayerPicker`** uses it for both action chips and drops `chipLabel`.
- **SyLib's docs and examples** use it, not a `Label`, for any chip with an icon, and say why.
- **Score It \*** moves `AddPlayerSheet`'s and `GameEditorSheet`'s icon chips to it in its session
  (§4).

### 2.4 Considered and excluded

| Excluded | Why |
|---|---|
| One SyLib sheet with slots for app sections | Score It \* would have to restructure its 807-line sheet around it (Pops: little change for Score It \*) |
| Moving `SetupRules.sameAsLastTime` to SyLib | It depends on Score It \*'s `RoundPlan`; each app owns "last time" |
| Start begins SyFive's game | Pops: Start applies seats; the first roll starts the game |
| SyFive's pencil, colored names and "Turn N" | Pops: Score It \*'s rows as they are |
| Teams or options in SyFive | SyFive has neither |

---

## 3. Tasks

### Task 38.1 · SyLib: the four setup pieces (§2.1)

- **A SyLib session.** Inputs: §1–2; SyLib `Docs/SCORING_UI.md`; Score It \*'s `SeatList.swift`,
  `PlayerPicker.swift` and `MatchSetupSheet.swift`, read only.
- **New, `Sources/SyLibScoringUI/Setup/`:** `SeatList.swift`, `PlayerPicker.swift` (copied, made
  `public`, comments' Score It \* citations kept as provenance), `SameAsLastTimeSection.swift`, and
  `MatchSetupForm.swift` (the frame as §2.1 describes, with `content` a `@ViewBuilder`). Previews move
  with them, plus one for `MatchSetupForm` holding all three sections.
- **Docs, `SCORING_UI.md`:** a "Match setup" section: the four pieces, their parameters, what each app
  supplies (the seated and unseated players, Same as Last Time's action and visibility, `canStart`,
  what Start and New Player do), and that the frame shows edit mode always.
- **Tests:** none (views; the previews show them).
- **Must not touch:** any other SyLib API; Score It \*; SyFive; Syderal.
- **Done when:** SyLib's suite passes at its baseline (`00B` §5.3, from the result bundle); Syderal builds
  and its suite passes unchanged (§5.4); Score It \* still builds against it (its own `SeatList` and
  `PlayerPicker` are app-internal types, so its copies shadow SyLib's in its own module; report it if
  they don't); no new warnings; the row is at the top of §6.

### Task 38.2 · SyFive's New Game on the shared pieces (§2.3)

- **Depends on 38.1.**
- **New, `Views/NewGameSheet.swift`,** replacing `PlayerPickerSheet` (deleted):
  - `MatchSetupForm(title: "New Game", canStart: !draft.isEmpty, onCancel: dismiss, onStart: apply)`.
  - Its content, in order: `SameAsLastTimeSection` (when §2.3's rule finds a list that differs from the
    draft), `SeatList` (the draft's players), `PlayerPicker` (active roster players not in the draft,
    sorted by name).
  - The draft: `@State` player ids, from `model.playerIDs` (seats without a roster player are dropped;
    none are expected outside previews).
  - New Player: `PlayerEditSheet(mode: .create, matchModel:, onCreated:)` appending the new id to the
    draft.
- **`MatchController`:** `func setPlayers(_ players: [Player])`, guarded by `canEditPlayers`: no change
  when the ids and order already match; otherwise the seats become exactly `players`, in order, each
  as `addPlayer(from:)` seats one.
- **"Last time":** an internal function returning the player ids of the most recent completed match with
  `isGameNight == false`, by `completedAt`, read through `onePerMatchID()`, participants in seat order,
  keeping ids of active roster players.
- **`ScorecardView`:** presents `NewGameSheet` where it presented `PlayerPickerSheet`.
- **Tests, + 2:** "last time" (picks the latest non-Game Night match, seat order, skips archived and
  missing players); `setPlayers` (reorders, adds and removes to match; refuses once the game has
  started).
- **Must not touch:** Game Night seating; `PreGameGridView` beyond the call it already makes; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at its baseline
  + 2, from the result bundle; the row is at the top of §6; Pops checks V1 to V4.

### Task 38.3 · SyLib: seats swipe to Remove (§2.5)

- **A SyLib session.** Inputs: §2.5; `Sources/SyLibScoringUI/Setup/SeatList.swift`,
  `MatchSetupForm.swift`.
- **No check by the agent** (v1.2): no previews and no simulator sessions (`00B` §3). Pops checks the
  swipe on device (V5).
- **Change, `SeatList`:** remove `.onDelete(perform: onRemove)`; give each seat row
  `.swipeActions(edge: .trailing, allowsFullSwipe: true) { Button("Remove", role: .destructive) { onRemove(IndexSet(integer: index)) } }`.
  The empty hint row gets none. `onRemove`'s signature stays, so callers don't change. A comment
  cites `38` §2.5.
- **Docs, `SCORING_UI.md`,** "Match setup": seats swipe to Remove; no minus circle.
- **Tests:** none (a view).
- **Must not touch:** `onMove` and the handles; `MatchSetupForm`'s edit mode; the other pieces; Score It \*;
  SyFive; Syderal.
- **Done when:** SyLib's suite passes at its baseline, 1595 tests (1670 runs), from the result bundle;
  Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at the top of §6;
  Pops checks V5.

### Task 38.4 · SyLib: no edit mode; swipe to Remove as the Players sheet (§2.5, v1.3)

- **A SyLib session.** Inputs: §2.5; `Sources/SyLibScoringUI/Setup/SeatList.swift`,
  `MatchSetupForm.swift`; for the pattern only, SyFive's last `PlayerPickerSheet`
  (`git show HEAD:SyFive/SyFive/Views/PlayerPickerSheet.swift`, 98–144, read with git, no checkout).
- **Change, `MatchSetupForm`:** remove `.environment(\.editMode, .constant(.active))` and its Score It \*
  M2-25 comment; correct the doc comments (8, 41) that say edit mode shows handles and delete
  controls.
- **Change, `SeatList`:** each seat row:
  - ends with `Spacer()` and `Image(systemName: "line.3.horizontal")`, `.foregroundStyle(.tertiary)`,
    `.font(.title)`, as the old sheet's handle;
  - takes `.contentShape(Rectangle())`;
  - swipes with `.swipeActions(edge: .trailing) { Button(role: .destructive) { onRemove(IndexSet(integer: index)) } label: { Label("Remove", systemImage: "xmark") }.tint(.red) }`.
  `.onMove(perform: onMove)` stays. The hint row gets neither. A comment cites `38` §2.5 v1.3.
- **Docs, `SCORING_UI.md`,** "Match setup": no edit mode; the drawn handle and long-press to reorder;
  Remove by swipe.
- **No previews rendered and no simulator** (`00A` v1.13 §3): Pops checks V5 on device.
- **Tests:** none (views).
- **Must not touch:** the other pieces; `onMove`/`onRemove` signatures; Score It \*; SyFive; Syderal.
- **Done when:** SyLib's suite passes at its baseline, 1595 tests (1670 runs), from the result bundle;
  Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at the top of §6;
  Pops checks V5.

### Task 38.5 · SyLib: the Seats footer, and two tidy-ups (§2.6)

- **A SyLib session.** Inputs: §2.6; `Sources/SyLibScoringUI/Setup/SeatList.swift`.
- **Change, `SeatList`:**
  - the section gains a `footer:` with §2.6's text by seat count: none for 0, "Swipe left to
    remove." for 1, "Swipe left to remove. Touch and hold to reorder." for 2 or more. A comment cites
    `38` §2.6.
  - **Tidy (38.4's report):** the Remove swipe looks the seat's index up by its player's id when
    tapped (`players.firstIndex { $0.id == player.id }`), not the index the row was built with, as
    SyFive's old sheet did against a stale index; nothing happens if it's gone.
  - **Tidy (38.4's report):** the empty-hint preview drops `.environment(\.editMode, .constant(.active))`.
- **Docs, `SCORING_UI.md`,** "Match setup": the footer and its three cases.
- **No previews rendered and no simulator** (`00A` v1.13 §3): Pops checks V6 on device.
- **Tests:** none (a view).
- **Must not touch:** `SeatList`'s signature; the other pieces; Score It \*; SyFive; Syderal.
- **Done when:** SyLib's suite passes at its baseline, 1595 tests (1670 runs), from the result bundle;
  Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at the top of §6;
  Pops checks V6.

### Task 38.6 · SyLib: the solid chip, in Players (§2.7)

- **A SyLib session.** Inputs: §2.7; `Sources/SyLibUI/Components/SelectableChip.swift`,
  `Sources/SyLibScoringUI/Setup/PlayerPicker.swift`, `SameAsLastTimeSection.swift`, `MatchSetupForm.swift`.
- **`SelectableChip` (SyLibUI):** a new `emphasized: Bool = false` on both initialisers. When true, the
  chip draws the selected look (tint fill, white label, tint stroke) without the `.isSelected`
  accessibility trait. Default false: every existing chip is unchanged.
- **`PlayerPicker`:** a new `onSameAsLastTime: (() -> Void)? = nil`. When set, the first chip in the
  `FlowLayout` is `SelectableChip(isSelected: false, action:, emphasized: true) { Label("Same as Last
  Time", systemImage: "arrow.counterclockwise") }` (label style title and icon, `.fixedSize()`, as New
  Player's). Default nil: no chip, so existing callers are unchanged.
- **Retire `SameAsLastTimeSection`:** delete the file; update `MatchSetupForm`'s preview to pass
  `onSameAsLastTime:` to `PlayerPicker` instead, and its doc comment's list of sections. Don't render it.
- **Docs:** `SCORING_UI.md` (the chip in "Match setup"; `SameAsLastTimeSection` gone) and SyLibUI's
  `UI_COMPONENTS.md` (`SelectableChip`'s `emphasized`).
- **Expected:** SyFive won't build until 38.7 (its `NewGameSheet` uses `SameAsLastTimeSection`). Run
  38.7 next; don't build SyFive here.
- **Tests:** none (views).
- **Must not touch:** any other chip's look; `SeatList`; Score It \*; SyFive; Syderal.
- **Done when:** SyLib's suite passes at its baseline, 1595 tests (1670 runs), from the result bundle;
  Syderal builds and passes unchanged; Score It \* still builds (it doesn't use the retired section);
  no new warnings; the row is at the top of §6.

### Task 38.7 · SyFive: Same as Last Time as the first chip (§2.7)

- **Depends on 38.6, and runs right after it.**
- **Change, `Views/NewGameSheet.swift`:** remove the `SameAsLastTimeSection`; pass `PlayerPicker`
  `onSameAsLastTime:` with `{ draft = lastTime }` when last time is non-empty and
  `Set(lastTime) != Set(draft)` (§2.7 v1.6: the same players in another order count as the same),
  else nil.
- **Tests:** none added.
- **Must not touch:** the draft logic, "last time" and `setPlayers`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 38.2's total,
  30 tests (33 runs), from the result bundle; the row is at the top of §6; Pops checks V7.

### Task 38.8 · SyLib: `MatchSetupForm`'s button mode (§2.8)

- **A SyLib session.** Inputs: §2.8; `Sources/SyLibScoringUI/Setup/MatchSetupForm.swift`.
- **Change:** `public enum Buttons { case cancelAndStart, done }` nested in `MatchSetupForm`, and a
  `buttons: Buttons = .cancelAndStart` init parameter. `.cancelAndStart` draws exactly today's toolbar.
  `.done` draws only `ToolbarItem(placement: .confirmationAction) { Button("Done", action: onStart)
  .disabled(!canStart) }`. Doc comments say what each mode is for (Score It \*'s draft; SyFive's live
  edits). The preview stays as it is (don't render it).
- **Docs, `SCORING_UI.md`,** "Match setup": the two modes.
- **Tests:** none (a view).
- **Must not touch:** the other pieces; Score It \*; SyFive; Syderal.
- **This session does 38.8 only.** 38.9 is SyFive's and a separate session, even though SyFive keeps
  building with the default.
- **Done when:** SyLib's suite passes at its baseline, 1595 tests (1670 runs), from the result bundle;
  Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at the top of §6.

### Task 38.9 · SyFive: Done, with live edits (§2.8)

- **Depends on 38.8.**
- **Change, `Views/NewGameSheet.swift`:**
  - `MatchSetupForm(title: "New Game", canStart: true, onCancel: {}, onStart: { dismiss() },
    buttons: .done)`.
  - The `@State` draft and its `.onAppear` filter go. Seated players come from `model.playerIDs`
    (the roster players, in seat order; a slot with no roster player isn't shown, which happens only
    in previews). `PlayerPicker`'s `onSeat` calls `model.addPlayer(from: player.toDomain())`; Same as
    Last Time calls `model.setPlayers(…)` with last time's players, as `toDomain()`.
  - **Indexes by player id** (v1.8): `SeatList`'s offsets count the shown seats, the controller's
    count its slots, so each is converted through the player's id, looked up when the gesture
    happens, as the old sheet did ("so a stale captured index can't crash"). `onRemove`: the shown
    seat's id, then `model.playerIDs.firstIndex(of:)`, then `model.removePlayer(at:)`; nothing if not
    found. `onMove`: one source; convert List's insert-before offset as the old sheet did
    (`source < to ? to - 1 : to`), then take the moved seat's and the target seat's ids, their slot
    indexes, and call `model.movePlayer(from:to:)`; nothing if either isn't found.
  - Same as Last Time shows when last time is non-empty and differs from the seated players as a set
    (§2.7, unchanged).
  - New Player: `PlayerEditSheet(mode: .create, matchModel: model)` without `onCreated`, so it seats the
    new player in the game itself, as before 38.
- **Tests:** none added; 38.2's `setPlayers` and "last time" tests stay and pass.
- **Must not touch:** `MatchController`'s methods; "last time"; Game Night seating; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 30 tests
  (33 runs), from the result bundle; the row is at the top of §6; Pops checks V1 to V4.

### Task 38.10 · SyLib: the action chips' icon spacing (§2.9)

- **A SyLib session.** Inputs: §2.9; `Sources/SyLibScoringUI/Setup/PlayerPicker.swift`.
- **Change:** New Player's and Same as Last Time's chip labels become `HStack(spacing: 4) {
  Image(systemName: …).accessibilityHidden(true); Text(…) }.fixedSize()` in place of `Label(…)
  .labelStyle(.titleAndIcon).fixedSize()`; the icons are `plus` and `arrow.counterclockwise` as now.
  Everything else about the chips (`emphasized`, tint, action, order) unchanged. The preview stays
  (don't render it).
- **Docs, `SCORING_UI.md`,** "Match setup", `PlayerPicker`'s row: the chips draw icon and title 4 pt
  apart, not as a `Label`, and why (a `List` row's icon column).
- **Tests:** none (a view).
- **Must not touch:** `SelectableChip`; the other pieces; Score It \*; SyFive; Syderal.
- **Done when:** SyLib's suite passes at its baseline, 1595 tests (1670 runs), from the result bundle;
  Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at the top of §6;
  Pops checks V8.

### Task 38.11 · SyLib: `SelectableChip`'s icon initializer (§2.10)

- **A SyLib session.** Inputs: §2.9, §2.10; `Sources/SyLibUI/Components/SelectableChip.swift`,
  `Sources/SyLibScoringUI/Setup/PlayerPicker.swift`.
- **Change, `SelectableChip.swift`:**
  - `public struct SelectableChipIconLabel: View`, `init(title: String, systemImage: String)`, drawing
    `HStack(spacing: 4) { Image(systemName:).accessibilityHidden(true); Text(title) }.fixedSize()`,
    with a doc comment on why it isn't a `Label` (a `List` row's icon column, 38 §2.9).
  - `extension SelectableChip where Label == SelectableChipIconLabel` with
    `init(_ title: String, systemImage: String, isSelected: Bool, tintsWhenUnselected: Bool = false,
    emphasized: Bool = false, action: @escaping () -> Void)`, matching the text initializer's order.
  - The type's doc examples and previews that show a chip with an icon (Wanted, Unplayed, New Player)
    use it. Previews stay and compile; don't render them.
- **Change, `PlayerPicker.swift`:** both action chips use it
  (`SelectableChip("Same as Last Time", systemImage: "arrow.counterclockwise", isSelected: false,
  emphasized: true, action: onSameAsLastTime)` and `SelectableChip("New Player", systemImage: "plus",
  isSelected: false, action: onNewPlayer)`); `chipLabel` goes. They draw exactly as after 38.10.
- **Docs:** `UI_COMPONENTS.md`, `SelectableChip`: the initializer, `SelectableChipIconLabel`, and the
  rule (a chip with an icon uses it, never a `Label`, and why). `SCORING_UI.md`, "Match setup",
  `PlayerPicker`'s row: the action chips use it; also replace the row's stale
  `Label("Same as Last Time", …)`.
- **Tests:** one test in `SelectableChipTests`, beside the labelled case: the icon initializer's
  defaults (plain unselected, not tinted) and that `emphasized: true` gives the selected look.
- **Must not touch:** the existing initializers and their behavior; the other setup pieces; Score
  It \*; SyFive; Syderal (build them only).
- **Done when:** SyLib's suite passes at its baseline plus the new test (expected 1596 tests), from the
  result bundle; Syderal unchanged; Score It \* and SyFive still build; no new warnings; the row is at
  the top of §6; Pops checks V8.

---

## 4. Score It \*

Adopts in its own session, with this document as its brief (§2.2): delete `Setup/SeatList.swift` and
`Setup/PlayerPicker.swift` (SyLib's take their place, same calls); `MatchSetupSheet`'s `NavigationStack`
/ `List` / edit mode / palette / toolbar become `MatchSetupForm(title: "New Match", canStart:, onCancel:,
onStart: start) { … }`, its sections unchanged inside; its two capsule sections go:
Same as Last Time becomes `PlayerPicker`'s `onSameAsLastTime:`, and "Same Teams as Last Time" becomes the
same solid chip (`SelectableChip(…, emphasized: true)` with the repeat arrow) first in its own
`SetupTeamsSection` (§2.7). No behavior change,
except §2.5's and §2.6's: no edit mode; seats swipe to Remove and show a drawn handle, reordering by
long-press; the Seats footer says so. Also in that session, outside 38: its `AddPlayerSheet`'s New
Player chip has §2.9's wide gap: use `SelectableChip(_:systemImage:…)` (§2.10), as also for
`GameEditorSheet`'s icon chips.

---

## 5. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | After 38.9, on iPad: open New Game, seat, reorder and remove players | The pre-game grid behind the sheet changes with each tap |
| V2 | After 38.9: change the seats, then close the sheet once with Done and once by swiping it down | Both keep the changes; only Done shows, no Cancel; Done works with no one seated |
| V3 | After a local game, clear the seats; open New Game | Same as Last Time shows first among the chips and seats that game's players in order; it hides once the seats hold the same players, in any order |
| V4 | Side by side with Score It \*'s New Match | Same look: numbered seats with handles, chips, the Seats footer; SyFive shows only Done, Score It \* Cancel and Start |
| V5 | After 38.4: in New Game, swipe a seat left from anywhere on the row; long-press a seat and drag it | A red **Remove** with an xmark shows and removes the seat to the chips; the seat moves to its new place; each seat shows a handle icon |
| V6 | After 38.5: New Game with no seats, one seat, then two | No footer; "Swipe left to remove."; then "Swipe left to remove. Touch and hold to reorder." |
| V7 | After 38.7: New Game after a local game, with different seats | Same as Last Time is the first chip in Players, solid accent with a repeat arrow; nothing above the seats; tapping it seats last time's players and the chip hides; reordering those seats doesn't bring it back; the list doesn't jump as it appears or hides |
| V8 | After 38.11: New Game, with and without Same as Last Time showing | Each chip's icon sits just before its title, a narrow gap like a space; the chips are otherwise as before; VoiceOver reads "New Player" and "Same as Last Time" |

## 6. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| V1 to V4, V8 | 10 Nov 2026 | **pass** (Pops, on device) | — | New Game edits live with Done only; Same as Last Time by set; same look as Score It \*; action chips' icons sit by their titles. 38 closed; ledger rows filed |
| 38.11 | 9 Nov 2026 | complete (SyLib session); V8 is Pops's, on device. **Checked by Claude against the SyLib tree, 10 Nov**: `SelectableChipIconLabel` and the icon initializer as specified, delegating to the designated init; `PlayerPicker`'s two chips use it and `chipLabel` is gone; doc examples and previews moved; the new test; existing initializers untouched. SyLib's new baseline is 1596 tests (1671 runs) | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped. After: `Passed`, 1596 tests (1671 runs), 1595 passed, 0 failed, 1 skipped: + `SelectableChipTests/iconInitializerDefaultsAndEmphasized()`, none removed. **Syderal** (`00B` §5.4). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** and **SyFive** (`xcodebuild build`, each against the changed SyLib, built only): `BUILD SUCCEEDED`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Files (sylib-swift):** `Sources/SyLibUI/Components/SelectableChip.swift`: new `public struct SelectableChipIconLabel: View` (`init(title:systemImage:)`, `HStack(spacing: 4) { Image(systemName:).accessibilityHidden(true); Text(title) }.fixedSize()`, doc comment on a `List` row's icon column, 38 §2.9–2.10). New `extension SelectableChip where Label == SelectableChipIconLabel` with `init(_ title:systemImage:isSelected:tintsWhenUnselected:emphasized:action:)`, as specified with `action` last, delegating to the designated init. The type's doc examples (Wanted; Same as Last Time) and previews (Wanted, Unplayed; New Player) use it; previews not rendered. Existing initializers untouched. `Sources/SyLibScoringUI/Setup/PlayerPicker.swift`: Same as Last Time is `SelectableChip("Same as Last Time", systemImage: "arrow.counterclockwise", isSelected: false, emphasized: true, action: onSameAsLastTime)`, New Player is `SelectableChip("New Player", systemImage: "plus", isSelected: false, action: onNewPlayer)`, and `chipLabel` is gone. Both draw the same `HStack` as after 38.10. `Tests/SyLibTests/SyLibUI/SelectableChipTests.swift`: the test above, beside the labelled case (defaults plain, untinted, not emphasized; selected look when selected; `emphasized: true` gives `.selected`). `Docs/UI_COMPONENTS.md`, `SelectableChip`: the new initializer and label in the signature block, the icon examples moved to it, and the rule (a chip with an icon uses it, never a `Label`, and why). `Docs/SCORING_UI.md`, "Match setup", `PlayerPicker`'s row: the stale `Label("Same as Last Time", …)` replaced by the new call; both action chips use the icon initializer. Plus this row. Other setup pieces, Score It \*, SyFive and Syderal not edited. **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** syfive-ios `git diff HEAD --stat -- Docs/Requirements/`; sylib-swift `git status --short` ×2. **Report:** (1) The spec's signature puts `action` last, while the text initializer has it third ("matching the text initializer's order" otherwise holds); I followed the signature as written, so `{ … }` trailing-closure actions work. (2) The type's doc comment had a fourth icon example, 38.6's emphasized Same as Last Time; it now uses the initializer too. (3) The other `Label(…)` mentions left in the docs are swipe-action buttons (Players sheet, `SeatList`'s Remove), not chips. V8 is Pops's |
| 38.10 | 9 Nov 2026 | complete (SyLib session); V8 is Pops's, on device. **Checked by Claude against the SyLib tree**: both action chips through one private `chipLabel` (`HStack(spacing: 4)`, icon hidden from VoiceOver, `.fixedSize()`), nothing else changed; `SCORING_UI.md`'s row still names `Label("Same as Last Time", …)` earlier on, fixed in 38.11 | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before and after: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped; identical case list. **Syderal** (`00B` §5.4). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** and **SyFive** (`xcodebuild build`, each against the changed SyLib, built only): `BUILD SUCCEEDED`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Files (sylib-swift):** `Sources/SyLibScoringUI/Setup/PlayerPicker.swift`: New Player's and Same as Last Time's chip labels, formerly `Label(…).labelStyle(.titleAndIcon).fixedSize()`, now both draw through one private `chipLabel(_:systemImage:)` returning `HStack(spacing: 4) { Image(systemName:).accessibilityHidden(true); Text(title) }.fixedSize()`, with a doc comment citing SyFive 38 §2.9 (a `List` row's icon column). Icons are still `plus` and `arrow.counterclockwise`; `emphasized`, tint, actions and order unchanged. `Docs/SCORING_UI.md`, "Match setup", `PlayerPicker`'s row: the action chips draw icon and title 4 pt apart, not as a `Label`, and why. Plus this row. `SelectableChip`, the other pieces, Score It \*, SyFive and Syderal not edited; the preview unchanged and not rendered (`00A` v1.13 §3). **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** syfive-ios `git diff HEAD --stat -- Docs/Requirements/`; sylib-swift `git status --short` ×2. **Report:** the two labels share one private helper rather than two inline `HStack`s; each chip draws exactly the specified `HStack`. V8 is Pops's |
| 38.9 | 9 Nov 2026 | complete; V1 to V4 are Pops's, on device. **Checked by Claude against the tree**: Done only, `canStart: true`; the draft, `.onAppear` filter and `apply()` gone; every action edits `model` live; move and remove convert through player ids at the gesture (remove collects ids before removing); Same as Last Time compares sets; New Player without `onCreated`; `lastTimePlayerIDs` unchanged; only `NewGameSheet.swift` changed | Before and after: `Passed`, 30 tests (33 runs), 30 passed, 0 failed, 0 skipped; identical case list, 38.2's `setPlayers` and "last time" tests included. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/NewGameSheet.swift` only. `MatchSetupForm(title: "New Game", canStart: true, onCancel: {}, onStart: { dismiss() }, buttons: .done)`. The `@State` draft, its `init` seeding, the `.onAppear` filter and `apply()` are gone (the memberwise init returns). `seatedPlayers` is `model.playerIDs` mapped to roster players in seat order; a slot with no roster player isn't shown. `unseatedPlayers` is active roster players not in `model.playerIDs`, by name. `onSeat` calls `model.addPlayer(from: $0.toDomain())`. Same as Last Time, shown when last time is non-empty and its set differs from the seated players' set, calls `model.setPlayers(lastTime.compactMap { player($0)?.toDomain() })`. `moveSeat(from:to:)` takes one source, converts `source < to ? to - 1 : to`, looks up both seats' ids in `model.playerIDs` at the gesture, then calls `movePlayer(from:to:)`; nothing if either is missing. `removeSeats(at:)` maps each shown offset to its player id, then `model.playerIDs.firstIndex(of:)`, then `removePlayer(at:)`; a seat that's gone is skipped. New Player is `PlayerEditSheet(mode: .create, matchModel: model)`, no `onCreated`, keeping `.environment(\.syTheme, theme)` and `.sheetTextSizeCeiling()`. The type's doc comment now describes live edits (38 §2.8, D-207). `lastTimePlayerIDs` and the preview are unchanged (not rendered). Plus this row. `MatchController`, "last time" and its tests, Game Night seating, SyLib, Score It \* and Syderal untouched. **Build:** `BuildProject` passed before (0 warnings) and after (with test targets, 0 warnings); 0 `warning:` lines in the test log. No preview, simulator or device session (`00A` v1.13 §3). **Git (read-only):** `git diff HEAD --stat -- Docs/Requirements/`, `git diff HEAD -- Docs/Requirements/00A_STUDIO_CONVENTIONS.md Docs/Requirements/00B_SYFIVE_GUARDRAILS.md`, `git status --short` ×2. **Report:** (1) `removeSeats` handles every offset in the `IndexSet`, though the swipe sends one. (2) Same as Last Time calls `setPlayers` while the sheet is open, which is only before the first roll; `setPlayers` also guards `canEditPlayers`. V1 to V4 are Pops's |
| 38.8 | 9 Nov 2026 | complete (SyLib session); 38.9 not started, as directed. **Checked by Claude against the SyLib tree**: `Buttons` nested in `MatchSetupForm`, `buttons:` defaulted after `onStart`, `.cancelAndStart` the old toolbar, `.done` one Done calling `onStart`, disabled unless `canStart`; `SCORING_UI.md` describes both; nothing else changed | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before and after: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped; identical case list. **Syderal** (`00B` §5.4). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** and **SyFive** (`xcodebuild build`, each against the changed SyLib; SyFive built only, not opened or edited): `BUILD SUCCEEDED`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Files (sylib-swift):** `Sources/SyLibScoringUI/Setup/MatchSetupForm.swift`: nested `public enum Buttons { case cancelAndStart, done }`, each case's doc comment saying what it's for (Score It \*'s draft; SyFive's live edits); a `buttons: Buttons = .cancelAndStart` parameter, placed after `onStart` and before `content`, so 38.9's call `MatchSetupForm(title:canStart:onCancel:onStart:buttons:) { … }` compiles. The toolbar switches on it: `.cancelAndStart` draws exactly the old Cancel and Start; `.done` draws only `ToolbarItem(placement: .confirmationAction) { Button("Done", action: onStart).disabled(!canStart) }`. The type and parameter docs say `onCancel` is unused with `.done`. The preview is unchanged (default mode, not rendered). `Docs/SCORING_UI.md`, "Match setup": the signature with `Buttons` and `buttons:`, and `MatchSetupForm`'s row describes the two modes. Plus this row. Other pieces, Score It \*, SyFive and Syderal not edited. **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** sylib-swift `git status --short` ×2 |
| 38.7 | 9 Nov 2026 | complete; **SyFive builds again** (it hadn't since 38.6); V7 is Pops's, on device | Baseline: no build was possible after 38.6, so it is 38.2's recorded `Passed`, 30 tests (33 runs). After: `Passed`, 30 tests (33 runs), 30 passed, 0 failed, 0 skipped; case list identical to 38.2's bundle. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/NewGameSheet.swift` only: the `SameAsLastTimeSection` block is removed; `PlayerPicker` gets `onSameAsLastTime: showsLastTime ? { draft = lastTime } : nil`, with `showsLastTime = !lastTime.isEmpty && Set(lastTime) != Set(draft)` (§2.7 v1.6: reordered seats count as the same) and a comment citing 38 §2.7. The draft, "last time" and `setPlayers` are untouched; SyLib not edited. Plus this row. **Search:** `grep -rn "SameAsLastTimeSection" --include=*.swift SyFive SyFiveTests` gives no matches. **Build:** `BuildProject` (with test targets) passed, 0 warnings; 0 `warning:` lines in the test log. No preview rendered, no simulator session. **Git (read-only):** `git status --short`. **Report:** 38.6's row and summary should have said first that SyFive didn't build between 38.6 and 38.7, not only in a note |
| V6, V7 | 9 Nov 2026 | **pass** (Pops, on device: "works now") | — | The Seats footer; Same as Last Time as the solid first chip, hidden for a reorder, no list jump |
| 38.7 | 9 Nov 2026 | done; **checked by Claude against the tree**: `NewGameSheet` passes `onSameAsLastTime:` when last time's players differ from the draft's as a set, the section gone, nothing else changed. The agent's row above has since recorded the totals: 30 tests (33 runs), unchanged | — | — |
| 38.6 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: `SelectableChip`'s `emphasized` (selected look, no selected trait, default off), `PlayerPicker`'s `onSameAsLastTime` first chip with the repeat arrow, `SameAsLastTimeSection` deleted, preview and docs updated; SyLib and Syderal unchanged | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before and after: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped; identical case list. **Syderal** (`00B` §5.4). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** (`xcodebuild build`, against the changed SyLib): `BUILD SUCCEEDED`. **SyFive not built**, as directed: it won't build until 38.7 (`NewGameSheet` uses the retired `SameAsLastTimeSection`). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Files (sylib-swift):** `Sources/SyLibUI/Components/SelectableChip.swift`: `emphasized: Bool = false` on both initializers; the designated one is now `init(isSelected:action:emphasized:label:tintsWhenUnselected:)`, with `emphasized` placed before `label` so §3's call `SelectableChip(isSelected: false, action:, emphasized: true) { … }` compiles with a trailing-closure label. Existing calls are unchanged; `Text`'s is `init(_:isSelected:action:tintsWhenUnselected:emphasized:)`. `look` is `.selected` when `isSelected \|\| emphasized`; the `.isSelected` trait still follows `isSelected` only. Doc comment and example added. `Sources/SyLibScoringUI/Setup/PlayerPicker.swift`: `onSameAsLastTime: (() -> Void)? = nil` (last parameter); when set, the `FlowLayout`'s first chip is `SelectableChip(isSelected: false, action: onSameAsLastTime, emphasized: true) { Label("Same as Last Time", systemImage: "arrow.counterclockwise").labelStyle(.titleAndIcon).fixedSize() }`, with a comment citing SyFive 38 §2.7. `Sources/SyLibScoringUI/Setup/SameAsLastTimeSection.swift` deleted (plain `rm`). `Sources/SyLibScoringUI/Setup/MatchSetupForm.swift`: the doc comment's section list no longer names it; the preview drops `SameAsLastTimeSection {}` and passes `onSameAsLastTime: {}` to `PlayerPicker`, retitled. Not rendered. `Docs/SCORING_UI.md`, "Match setup": platform row, intro (three pieces; the section retired), signatures, the section's table row removed, `PlayerPicker`'s row gains the chip, the sample uses `onSameAsLastTime`, and Score It \*'s adoption note says both capsules become the chip. `Docs/UI_COMPONENTS.md`, `SelectableChip`: both signatures and an `emphasized` paragraph with an example. Plus this row. Other chips' looks, `SeatList`, Score It \*, SyFive and Syderal not edited. **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** sylib-swift `git status --short` ×2. **Report:** the deleted file shows as `AD` in sylib-swift (staged add, unstaged delete), for Pops |
| 38.5 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: the footer by seat count, Remove looks the seat up by id at tap time, the preview's edit mode gone; V6 is Pops's, on device | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before and after: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped; identical case list. **Syderal** (`00B` §5.4). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** and **SyFive** (`xcodebuild build`, each against the changed SyLib): `BUILD SUCCEEDED`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Files (sylib-swift):** `Sources/SyLibScoringUI/Setup/SeatList.swift`: the section gains a `footer:` (plain `Text`, the standard footer style) from a private `footerText`: nil for 0 seats, "Swipe left to remove." for 1, "Swipe left to remove. Touch and hold to reorder." for 2 or more, with a comment citing SyFive 38 §2.6. The Remove swipe now looks up `players.firstIndex(where: { $0.id == player.id })` when tapped and calls `onRemove` only if found. The empty-hint preview drops `.environment(\.editMode, .constant(.active))`. Signature unchanged. `Docs/SCORING_UI.md`, "Match setup": `SeatList`'s row gains the footer and its three cases, and the lookup by id. Plus this row. No preview rendered and no simulator or device session (`00A` v1.13 §3); the other pieces, Score It \*, SyFive and Syderal not edited. **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** sylib-swift `git status --short` ×2. V6 is Pops's |
| V5 | 9 Nov 2026 | **pass** (Pops, on device) | — | Swipe shows a red Remove and removes the seat; long-press reorders |
| 38.4 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: edit mode gone from `MatchSetupForm`, each seat has the drawn handle and swipes to a red Remove with an xmark, `.onMove` kept. Reports noted for a later tidy: `SeatList`'s empty-hint preview still sets edit mode (harmless), and the swipe uses the row's built index rather than looking it up by id at tap time (SyLib session); V5 is Pops's, on device | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before and after: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped; identical case list. **Syderal** (`00B` §5.4). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** and **SyFive** (`xcodebuild build`, each against the changed SyLib): `BUILD SUCCEEDED`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Files (sylib-swift):** `Sources/SyLibScoringUI/Setup/MatchSetupForm.swift`: `.environment(\.editMode, .constant(.active))` and its Score It \* M2-25 comment removed; the type's doc comment no longer says edit mode shows handles and delete controls, and now says there's no edit mode and why (SyFive 38 §2.5 v1.3). `Sources/SyLibScoringUI/Setup/SeatList.swift`: each seat row's `HStack` ends with `Spacer()` and `Image(systemName: "line.3.horizontal")`, `.foregroundStyle(.tertiary)`, `.font(.title)`; the row takes `.contentShape(Rectangle())`; 38.3's swipe is replaced by `.swipeActions(edge: .trailing) { Button(role: .destructive) { onRemove(IndexSet(integer: index)) } label: { Label("Remove", systemImage: "xmark") }.tint(.red) }`, with a comment citing SyFive 38 §2.5 v1.3. `.onMove(perform: onMove)` stays; the hint row has neither; `onMove`/`onRemove` signatures unchanged. `Docs/SCORING_UI.md`, "Match setup": `MatchSetupForm`'s row says no edit mode, and why; `SeatList`'s row covers the drawn handle, long-press and drag to reorder, and Remove by swipe (the label, tint and role). Plus this row. No preview rendered and no simulator or device session (`00A` v1.13 §3); the other pieces, Score It \*, SyFive and Syderal not edited. **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** syfive-ios `git diff HEAD -- Docs/Requirements/00A_STUDIO_CONVENTIONS.md`, `git show HEAD:SyFive/SyFive/Views/PlayerPickerSheet.swift`; sylib-swift `git status --short` ×2. **Report:** (1) `SeatList.swift`'s own preview ("Seats: empty, the hint", from Score It \*) still sets `.environment(\.editMode, .constant(.active))`. The task named only the seat rows, so left; with no seats it draws the same either way. (2) The swipe uses the `index` from `ForEach(players.enumerated())`, as specified. The old `PlayerPickerSheet` instead looked the index up by id at tap time ("so a stale captured index can't crash"); here `onRemove` gets the index the row was built with, which the caller's `remove(atOffsets:)` should also bounds-check. V5 is Pops's |
| 38.3 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: `.onDelete` gone, each seat swipes to a red Remove calling `onRemove`, `.onMove` kept, docs updated. The report's stale "delete controls" comments in `MatchSetupForm` are left for its next edit (SyLib session), except **step 1's check, not done: Pops checks on device** (V5) | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before and after: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped; identical case list. **Syderal** (`00B` §5.4). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** and **SyFive** (`xcodebuild build`, each against the changed SyLib): `BUILD SUCCEEDED`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Step 1 (does a row's swipe reveal its action under always-on edit mode?): not observed.** I started a simulator session to check through SyFive's New Game, and Pops stopped it before anything ran: no previews and no simulator runs, ever. Visual checks are Pops's. The session was closed; nothing was installed or swiped. **Pops checks it on device (V5).** If the swipe doesn't reveal Remove there, §2.5's fallback choice is Pops's, and this change should be reverted or replaced. **Files (sylib-swift):** `Sources/SyLibScoringUI/Setup/SeatList.swift`: `.onDelete(perform: onRemove)` removed; each seat row gets `.swipeActions(edge: .trailing, allowsFullSwipe: true) { Button("Remove", role: .destructive) { onRemove(IndexSet(integer: index)) } }` with a comment citing SyFive 38 §2.5; the empty hint row has none; `onRemove`'s signature, `.onMove` and the handles unchanged. `Docs/SCORING_UI.md`, "Match setup": `SeatList`'s row says seats swipe to Remove, with no minus circle and no Delete; `MatchSetupForm`'s row no longer says edit mode shows delete controls. Plus this row. `MatchSetupForm`, the other pieces, Score It \*, SyFive and Syderal not edited. **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** sylib-swift `git status --short`, `git log --oneline -2`, `git diff -- Sources/SyLibScoringUI/Setup/SeatList.swift Docs/SCORING_UI.md`; syfive-ios `git status --short`. **Report:** `MatchSetupForm.swift`'s comments (lines 8 and 41) still say edit mode shows "delete controls"; that file is under must-not-touch, so left |
| 38.2 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: `NewGameSheet` on the four pieces, the draft with Cancel and Start, `setPlayers` guarded and a no-op when unchanged, "last time" as ruled; + 2 tests. Report (1): `ENGINEERING_GUIDELINES.md` updated by Claude. (2) the preview's container lacks `cloudKitDatabase: .none`, as the old sheet's did; a later fix. (3) accepted: anonymous seats occur only in previews | Before: `Passed`, 28 tests (31 runs), 28 passed, 0 failed, 0 skipped. After: `Passed`, 30 tests (33 runs), 30 passed, 0 failed, 0 skipped: + `NewGameSetupTests/lastTimeIsTheLatestLocalGameInSeatOrder()` and `NewGameSetupTests/setPlayersMatchesTheListUntilTheGameStarts()`, none removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** new `Views/NewGameSheet.swift`. `MatchSetupForm(title: "New Game", canStart: !draft.isEmpty, onCancel: dismiss, onStart: apply)` holds, in order: `SameAsLastTimeSection` (only when last time is non-empty and differs from the draft; sets the draft to it), `SeatList` (the draft's players; move and remove edit the draft) and `PlayerPicker` (active roster players not in the draft, by name; a tap appends). The draft is `@State [UUID]` from `model.playerIDs`; seats with no roster player are dropped on appear. New Player is `PlayerEditSheet(mode: .create, matchModel:, onCreated:)` appending the new id; with `onCreated` the editor doesn't seat in the live game (`PlayerEditSheet.swift` 76–79), so Cancel holds. `apply` calls `model.setPlayers(draftPlayers.map { $0.toDomain() })`, then dismisses. Internal `static func lastTimePlayerIDs(matches:roster:)`: `onePerMatchID()`, completed and not Game Night, the latest by `completedAt`, participants by seat, active roster ids only. `Session/MatchController.swift`: `func setPlayers(_:)`, guarded by `canEditPlayers`; a no-op when `playerIDs` already equals the ids in order; otherwise clears every seat array, resets `currentPlayerIndex` and undo, and seats each with `addPlayer(from:)`. `Views/ScorecardView.swift`: presents `NewGameSheet(model:)` where it presented `PlayerPickerSheet`. `Views/PlayerPickerSheet.swift` deleted (plain `rm`). New `SyFiveTests/NewGameSetupTests.swift`. Plus this row. Game Night seating, `PreGameGridView`, the Players sheet and SyLib untouched. **Search (done-when 3):** `grep -rn "PlayerPickerSheet" --include=*.swift SyFive SyFiveTests SyFiveUITests` gives no matches (exit 1); `project.pbxproj` has 0. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings; 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. **Report:** (1) `ENGINEERING_GUIDELINES.md` still names `PlayerPickerSheet` in its file map (29) and its views list (116); not named in this task, so left. (2) The preview avoids `makeInMemoryScoringContainer` (`00B` §3, D-129) and keeps the old sheet's own in-memory `ModelContainer`, which, like before, doesn't pass `cloudKitDatabase: .none` (`SCORING_DATA.md` warns previews can crash without it). The tests use `makeInMemoryScoringContainer`, as 34.3's did. (3) `setPlayers` gives every seat a fresh `slotID` and `participantID`, as `addPlayer(from:)` does. An anonymous default seat ("Player 1", no roster id) is dropped from the draft and so replaced at Start. A seated player archived since stays in the draft; only missing ones are dropped. (4) As §2.3 and §2.4 rule, the old sheet's pencil, colored names and "Turn N" are gone, and its live edits plus Done are now a draft with Cancel and Start. V1 to V4 are Pops's |
| 38.1 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: the four pieces as §2.1 rules, `SeatList` and `PlayerPicker` Score It \*'s bodies made public with inits, `MatchSetupForm` the frame with Cancel and Start; SyLib and Syderal unchanged, Score It \* builds with its own copies shadowing SyLib's. Reports accepted (SyLib session), with one ruling by Pops in-session (below) | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before and after: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped; identical case list (no tests, as specified). **Syderal** (`00B` §5.4, from `syderal-ios/Syderal`). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. Totals from `-resultBundlePath` bundles read with `xcresulttool`. **Score It \*** (`xcodebuild build -project ScoreItAll.xcodeproj -scheme ScoreItAll`, SyLib at `../../sylib-swift`): `BUILD SUCCEEDED` before and after, 0 warnings. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for all | **Ruling (Pops, in-session):** `SeatList` and `PlayerPicker` take `[PlayerModel]` (SyLibScoringData), but SyLibScoringUI depended only on SyLibUI and SyLibScoring, and `SCORING_UI.md` described it as pure renderers. Pops: add the dependency and keep the signatures. **Files (sylib-swift):** `Package.swift`: SyLibScoringUI's dependencies gain `"SyLibScoringData"`, with a comment. New `Sources/SyLibScoringUI/Setup/`, all inside `#if os(iOS)`: `SeatList.swift` and `PlayerPicker.swift`, Score It \*'s bodies, comments (citations kept) and `SeatList`'s preview, made `public` with public memberwise-shaped inits; signatures and behavior unchanged; each has a provenance note. `SameAsLastTimeSection.swift`: `init(_ title: String = "Same as Last Time", action:)`, a section with an `.accent` `CapsuleButton`, full width, `.listRowBackground(Color.clear)`. `MatchSetupForm.swift`: `init(title:canStart:onCancel:onStart:content:)` (`@ViewBuilder content`); `NavigationStack` › `List { content() }`, `.environment(\.editMode, .constant(.active))`, `paletteListBackground`, inline title, `paletteBarBackground`, Cancel (`.cancellationAction`, `onCancel`), Start (`.confirmationAction`, disabled unless `canStart`), `.tint(syTheme.primaryAccent)`, as `MatchSetupSheet` 289–409; plus a preview holding all three sections (`@Previewable` draft). `Docs/SCORING_UI.md`: module header and intro (the setup pieces are the one exception taking `PlayerModel`), platform table row, and a new "Match setup" section before the SyFive worked example: the four signatures, what each draws, edit mode always, what the app supplies, a sample, and Score It \*'s adoption. Plus this row. **Score It \*:** its own app-internal `SeatList`/`PlayerPicker` compiled next to SyLib's public ones with no ambiguity (they shadow SyLib's in its module, as 38 expected). **Warnings:** 0 `: warning:` and 0 `: error:` lines in every log. **Git (read-only):** sylib-swift `git status --short` ×3, `git log --oneline -3`; score-it-all-ios `git status --short` ×2, `git branch --list`; syderal-ios `git status --short`. None in syfive-ios. **Report:** (1) After this session's builds, sylib-swift's changes show **staged** (`A`/`M`), though I ran no git write. Most likely Xcode's source control auto-adding, since SyLib is open in this workspace (as in 35.1). Left as is. (2) `PlayerPicker` came without a preview, as Score It \*'s has none; `MatchSetupForm`'s preview shows it. (3) score-it-all-ios has an untracked doc of Pops's (`29_DUPLICATE_MATCH_ROWS_FINDINGS.md`), left alone |

## 7. Ledger rows (filed 10 November 2026)

| ID | Ruling | Source |
|---|---|---|
| D-203 | **Match setup's pieces are SyLibScoringUI's**: `SeatList`, `PlayerPicker`, `SameAsLastTimeSection` and `MatchSetupForm`, lifted from Score It \*'s New Match with its signatures, so Score It \* adopts by deleting its copies. Each app keeps its own "last time", Start rule and Start action. | `38 §2.1–2.2` (Pops, 9 Nov 2026) |
| D-204 | **Match setup has no edit mode: a seat swipes to a red Remove** (with an xmark, as the Players sheet's swipes) and shows a drawn handle, reordering by long-press. *Why:* a seat only leaves the setup (Pops), and edit mode turned swipes off (V5, on device). | `38 §2.5` (Pops, 9 Nov 2026) |
| D-205 | **The setup's Seats section says how to use it**: a footer, "Swipe left to remove." with one seat, adding "Touch and hold to reorder." with two or more, none when empty; always on, in every app. *Why:* without edit mode both gestures are hidden. | `38 §2.6` (Pops, 9 Nov 2026) |
| D-206 | **Same as Last Time is the first chip in Players**: solid (`SelectableChip`'s new `emphasized`, the selected look without the selected trait), with a repeat arrow; shown only when the app passes its action. Score It \*'s "Same Teams as Last Time" becomes the same chip, first in its Teams section. `SameAsLastTimeSection` is retired. *Why:* it seats players, so it belongs with them (Pops). | `38 §2.7` (Pops, 9 Nov 2026) |
| D-207 | **Match setup has two button modes**: `.cancelAndStart` (Score It \*'s draft: Start applies, Cancel or swipe-down discards) and `.done` (SyFive: one Done, edits applied live, an empty table allowed). *Why:* SyFive's Start started nothing, and a draft without Cancel would lose changes silently (Pops). | `38 §2.8` (Pops, 9 Nov 2026) |
| D-208 | **A chip with an icon is `SelectableChip(_:systemImage:…)`**, never a `Label` in the chip: it draws icon and title 4 pt apart, the icon hidden from VoiceOver. *Why:* in a `List` row a `Label` puts its icon in the row's icon column, a wide gap (Pops, on device). | `38 §2.9–2.10` (Pops, 9 Nov 2026) |
| D-190 (rewritten) | **SyFive's New Game is SyLib's match setup** (`38`): **Done**, with edits applied live (seat, reorder, remove, Same as Last Time) so the iPad's pre-game grid follows; Same as Last Time as Players' first chip, from the latest completed non-Game Night game, shown when the players differ as a set; Score It \*'s numbered seats with a drawn handle, swipe to Remove, the Seats footer. Editing, archiving and unarchiving are Players'. | `28 §2.6` → `38 §2.3–2.8` (Pops, 9 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.13 | 10 Nov 2026 | V1 to V4 and V8 pass (Pops). Closed: D-203 to D-208 filed, D-190 rewritten in the ledger |
| 1.12 | 10 Nov 2026 | 38.11 checked; SyLib's baseline now 1596 tests (1671 runs). All tasks done; V1 to V4 and V8 remain |
| 1.11 | 9 Nov 2026 | 38.10 checked. §2.10 (Pops): `SelectableChip`'s icon initializer, Task 38.11 (SyLib); V8 moves after 38.11; D-208; §4's Score It \* note uses it |
| 1.10 | 9 Nov 2026 | §2.9 (Pops): the action chips' icons sit next to their titles; Task 38.10 (SyLib); V8; Score It \*'s `AddPlayerSheet` noted in §4 |
| 1.9 | 9 Nov 2026 | 38.9 checked; V3 and V4 reworded for Done (no draft; Done, not Cancel and Start) |
| 1.8 | 9 Nov 2026 | 38.8 checked; 38.7's totals recorded. 38.9: seat indexes converted through player ids (slots with no roster player aren't shown) |
| 1.7 | 9 Nov 2026 | §2.8 (Pops): SyFive uses Done with live edits, Score It \* keeps Cancel/Start with its draft; `MatchSetupForm`'s button mode, Tasks 38.8 (SyLib) and 38.9 (SyFive); V1 and V2 rewritten; D-207; D-190's rewrite updated |
| 1.6 | 9 Nov 2026 | §2.7 (Pops): the chip compares players as a set, so reordering doesn't show it; the move also ends the list jumping; 38.7 and V7 updated |
| 1.5 | 9 Nov 2026 | 38.5 checked. §2.7 (Pops): Same as Last Time as the first, solid chip in Players; Score It \*'s team version first in its Teams section; Tasks 38.6 (SyLib) and 38.7 (SyFive); V7; D-206 |
| 1.4 | 9 Nov 2026 | V5 passes. §2.6 (Pops): the Seats footer, Task 38.5, with 38.4's two tidy-ups; V6; D-205 |
| 1.3 | 9 Nov 2026 | V5 failed on device: edit mode disables swipes. §2.5: no edit mode, swipe to Remove and a drawn handle, as SyFive's old sheet; Task 38.4; V5 and D-204 updated |
| 1.2 | 9 Nov 2026 | 38.3's simulator check removed (`00B` §3 v1.5): Pops checks the swipe on device, V5 |
| 1.1 | 9 Nov 2026 | 38.2 checked. §2.5 (Pops): seats swipe to Remove, Task 38.3 (SyLib), checking first that swipes work in edit mode; V5; D-204 |
| 1.0 | 9 Nov 2026 | First version |
