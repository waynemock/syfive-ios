# SyLib match setup: Score It \*'s New Match pieces, shared, and SyFive's New Game on them

**Status:** **Ruled; written only.** Tasks 38.1 (SyLib) and 38.2 (SyFive) wait for their sessions.
Score It \* adopts in its own session (§4). Version 1.0, 9 November 2026.

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

---

## 4. Score It \*

Adopts in its own session, with this document as its brief (§2.2): delete `Setup/SeatList.swift` and
`Setup/PlayerPicker.swift` (SyLib's take their place, same calls); `MatchSetupSheet`'s `NavigationStack`
/ `List` / edit mode / palette / toolbar become `MatchSetupForm(title: "New Match", canStart:, onCancel:,
onStart: start) { … }`, its sections unchanged inside; its two capsule sections become
`SameAsLastTimeSection` and `SameAsLastTimeSection("Same Teams as Last Time")`. No behavior change.

---

## 5. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | Open New Game from the pre-game grid, add, reorder and remove players, then Cancel | The game's seats are as before |
| V2 | Do the same, then Start | The game has exactly those seats, in that order; the first roll starts it |
| V3 | After a local game, clear the seats; open New Game | Same as Last Time shows and seats that game's players in order; it hides once the draft matches |
| V4 | Side by side with Score It \*'s New Match | Same look: numbered seats with handles, chips, capsule, Cancel and Start |

## 6. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|

## 7. Ledger rows (Claude files them when 38 closes)

| ID | Ruling | Source |
|---|---|---|
| D-203 | **Match setup's pieces are SyLibScoringUI's**: `SeatList`, `PlayerPicker`, `SameAsLastTimeSection` and `MatchSetupForm`, lifted from Score It \*'s New Match with its signatures, so Score It \* adopts by deleting its copies. Each app keeps its own "last time", Start rule and Start action. | `38 §2.1–2.2` (Pops, 9 Nov 2026) |
| D-190 (rewritten) | **SyFive's New Game is SyLib's match setup** (`38` §2.3): a draft with Cancel and Start, where Start applies the seats and the first roll starts the game; Same as Last Time from the latest completed non-Game Night game; Score It \*'s numbered seats and chips. Editing, archiving and unarchiving are Players'. | `28 §2.6` → `38 §2.3` (Pops, 9 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 9 Nov 2026 | First version |
