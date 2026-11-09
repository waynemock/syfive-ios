# SyFive: delete an archived player and every game they played, as Syderal

**Status:** **34.1 to 34.3 done and checked, 8–9 November 2026; 34.4 (a copy fix) done and checked, 9 November 2026; 34.5 (the orphan sweep's log) done and checked, 9 November 2026; V5 in. 34.6 and 34.7 (§2.6) next; V1 to V4 and V6 are Pops's**. The ledger row is filed when they pass. Version 1.6, 9 November 2026.
**v1.2** brought 34 up to date with what Score It \* `27` learned building the same delete on
8 November 2026 (§2.2's check, "1 other", and §2.4, found in the reading). **v1.3** records Pops's
rulings on §2.2 and §2.4, the latter widened to Match History's deletes.

**Scope:** `syfive-ios`. SyLib is unchanged by this document. It uses what Syderal `26` added:
- `PlayersSheet`'s `archivedDelete` (26.20) and its swipe icons (26.22, which SyFive takes at its
  next build);
- SyLibScoringData's `deletePlayerAndMatches(_:in:willDelete:)` and `playerDeletionImpact` (26.24),
  which deletes every synced row of the player's id (26.28);
- SyLibScoringData's `deleteUnplayedPlayer`, `completedMatchCounts`, and `absorbPlayer`'s rollback
  (26.26), for Task 34.2.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md` (v1.12),
`00B_SYFIVE_GUARDRAILS.md`, this document, SyLib `Docs/SCORING_UI.md` and `Docs/SCORING_DATA.md`.
`00A` §6: the session's row goes at the top of §5. §7: `00B`'s pinned command. §8: fix your own
errors and warnings without stopping.

---

## 1. Why

Pops, 8 November 2026, for Syderal (its S-17), and now for every app:
- **The problem:** test data from development keeps creeping into production data, synced through
  iCloud, with no way to clean it up.
- **Players need it too:** a one-off guest, a duplicate, a practice game.
- **Archiving doesn't do it:** it hides a person but keeps their games in everyone's records.

## 2. Locked decisions (Pops, 8 November 2026)

**2.1 An archived player can be deleted with every game they played** (D-194).
- **The cost:** a game belongs to everyone at its table, so those games leave every player's
  records: games, wins, head-to-head and House Records. Every stat
  is computed from the stored matches, so nothing needs recomputing.
- **The swipe:** a red **Delete** on archived rows, beside Merge and Unarchive.
- **The alert** names the cost, in SyFive's words:
  - **Title:** "Delete {name} and {n} games?" ("1 game"; with none, "Delete {name}?").
  - **Message:** "Those games leave everyone's records, including {others}. This can't be undone."
    - `{others}` reads "Ada", "Ada and Bo", "Ada, Bo and Cy", or "Ada, Bo, Cy and {k} others", with
      "1 other" when k is 1 (Score It \* `27`; Syderal's "1 others" is its own `27`'s fix).
    - With no others, the message is "Those games leave your records. This can't be undone."
    - With no games, it is "This can't be undone."
- **Supersedes:** D-177's "only a never-played active player" stands for active players. This adds
  archived ones.

**2.2 Not while they're in a game in progress** (Claude; Pops, 8 November 2026, as Score It \* `27`
§2.2). SyFive saves its game in progress as a `MatchModel`. Deleting that match under the live
`MatchController` would break the game on screen. If any participant naming the player is in a match
whose `statusRaw` is `"inProgress"`, Delete deletes nothing and shows an alert instead, as Score It \*'s:
- **Title:** "Can't delete {name}".
- **Message:** "{name} is in a game that isn't finished. Finish it, or delete it from Match History,
  first." (Pops, 9 November 2026; v1.0–v1.3 had Score It \*'s "Finish or end it first", but SyFive
  has no End action. Task 34.4.)
- **Button:** OK only.
- **In progress only, not "isn't completed"** (v1.2, from Score It \* `27` §2.2): SyFive no longer
  saves abandoned games, but rows with `"abandoned"` from earlier builds can remain until
  `LegacyRematchRepair` removes them. A check on "not completed" would block such a player forever.
  Any other status goes with the player; `playerDeletionImpact` counts completed games only, so the
  alert's {n} leaves those out.
- **When the check runs** (Pops, 8 November 2026): after the sheet's confirm. SyLib's archived-delete
  alert always offers a red Delete, so `action` checks first and shows this alert in place of the
  delete. No SyLib change.

### 2.3 Considered and excluded

| Excluded | Why |
|---|---|
| SyFive's own delete code | SyLibScoringData's `deletePlayerAndMatches` is shared (Syderal S-20) |
| Deleting a player's synced duplicate rows | `deletePlayerAndMatches` deletes every row of the id (Syderal 26.28) |
| An OK-only alert for an unfinished game | SyLib's alert has one shape; the check after Delete is enough (§2.2) |
| A `willDelete` callback | SyFive has no rows of its own tied to a match |
| Deleting the player's teams (`includingTeams`, Score It \* `27` §2.8) | SyFive makes no teams: every participant's `teamID` is nil. The default, `false`, is right |

**2.4 Abandoning or deleting an unfinished game removes its participants too** (Claude; Pops,
8 November 2026; found in v1.2's reading). SyFive has no End Game or Abandon Game menu items (those
are Score It \*'s). It abandons an unfinished game by deleting it: New Game's "Delete & Start New",
or for a Game Night host "Play Locally" and "New Game Night Game", all through
`MatchController.abandonMatch(in:)`. A finished game is never touched: `abandonMatch` skips it
(`!isGameOver`). `abandonMatch` deletes the `MatchModel` alone. A match's
participants rule is `.nullify`, so its `ParticipantModel`s stay behind with no match, still naming
their players (SyLib's `deleteMatch` exists for exactly this: "deleting the match alone would leave
its participants behind"). Every abandoned game has left such orphans, and each player in one reads as
having played: no Delete on their active row (D-177's `everPlayed`), and `deleteUnplayedPlayer`
refuses them (34.2).
- **Match History does the same** (found in v1.3's reading): "Delete this unfinished game" and
  "Delete all unfinished games" (`MatchHistoryView`) call `modelContext.delete(m)` on the match alone.
  `LegacyRematchRepair` already deletes participants first and is fine.
- **Ruled (Pops):** all three call SyLib's `deleteMatch(match, in: context)` in place of deleting the
  match alone, so an abandoned game leaves nothing behind (Task 34.3). This is what Score It \*
  has always done (`MatchRecorder.delete`, its `13` §3.4) and what Syderal `26` moved into SyLib.
- **Orphans already stored don't stay** (corrected in v1.5; v1.2 to v1.4 said they did): since 1.0,
  `LegacyRematchRepair.run(in:)` opens with an orphan sweep that deletes **every** `ParticipantModel`
  whose `match` is nil, on every move to the foreground (`ContentView`'s `scenePhase` `.active`). So
  each abandoned game's seats were deleted the next time SyFive came to the foreground, and D-177's
  check was blocked only until then. See §2.5.

**2.5 The orphan sweep: log it now, guard it once the log is read** (Pops, 9 November 2026; found in
v1.5's reading).
- **What it does:** at every foreground, it deletes every `ParticipantModel` with no match and logs
  one line, "orphan sweep: deleting N orphaned ParticipantModel(s)". Nothing more is recorded.
- **The risk:** CloudKit syncs a match and its participants as separate records. On a new device or
  mid-sync, a participant can arrive before its match and look exactly like an orphan, and the sweep
  deletes it. That delete then syncs to every device, and the game loses a seat. No participant
  carries a creation date (only each score entry's `recordedAt`), so the sweep can't tell a
  participant waiting on its match from a true orphan.
- **Where it came from:** `36_SYFIVE_LEGACY_DATA_REPAIRS.md` records each repair in
  `LegacyRematchRepair`, the match-per-turn bug behind them (fixed before 1.0), and V5's first log.
- **Pops's call:** Pops expects more orphans on his devices than any player will have: development
  deleted many matches. First see them: **Task 34.5** logs each orphan the sweep deletes, with no
  change to what it deletes. Pops reads the log (V5).
- **V5's result** (9 November 2026, `36` §4.1): the iPhone had none. The iPad had two: Sherida's and
  Wayne's seats of a **finished** game on 30 October, 13 of 13 scored each. That game's match is in
  neither device's History. The sweep deleted the two seats, which held enough to rebuild it.

**2.6 Retire the sweep, and keep a lasting log of the repair's deletes** (D-196; Pops, 9 November
2026, from V5).
- **The sweep goes** (Task 34.6). Since 34.3 SyFive makes no orphans of its own, and the one set it
  found on Pops's account was a finished game's seats. An orphan now stays until its player is
  deleted: `deletePlayerAndMatches` already takes a player's orphans with them, and an active player
  blocked only by orphans is a later SyLib change (`36` §5).
- **The other repairs log every delete to a file** (Task 34.7). V5 couldn't say what deleted the
  30 October match, because `AppLogger` writes at info level, which iOS doesn't keep. Strategies 1
  to 4 delete completed matches. Each of their deletes now also goes to a small text file in the
  app's container that survives relaunch, so the next lost game can be traced.
- **Considered and excluded:** guarding the sweep (by `recordedAt` age, during a CloudKit import, or
  once per launch). No participant has a creation date, so no guard can tell a seat waiting for its
  match from a true orphan. Rebuilding a match from full-scorecard orphans: a bigger design, not now.

---

## 3. Task 34.1 · Delete on archived players

- **Inputs:** §2; SyLib `SCORING_UI.md` (`archivedDelete`, `PlayersSheetArchivedDelete`),
  `SCORING_DATA.md` (`deletePlayerAndMatches`, `playerDeletionImpact`).
- **Change, `Views/PlayersView.swift`:** pass `archivedDelete:` to `PlayersSheet`:
  - **`title`** and **`message`**: §2.1's copy, from `try? playerDeletionImpact(playerID:in: modelContext)`.
    A `static func list(_ names: [String]) -> String`, internal so the tests reach it, builds `{others}`.
  - **`action`**:
    - First §2.2's check: a `ParticipantModel` naming the player whose match's `statusRaw` is
      `"inProgress"`. If one exists, delete nothing and show §2.2's alert: `@State` holding the
      player's name, an OK-only `.alert`, set from a `Task { … }` so it presents after the sheet's
      confirm alert has closed (as Score It \*'s `showSaveFailure()`).
    - Otherwise, `try deletePlayerAndMatches(player, in: modelContext)`. It deletes every row of the
      id, so SyFive deletes no rows itself.
    - On a throw, set `mergeFailureMessage = "Couldn't delete that player. Please try again."`.
      That's the existing "Player Action Failed" alert, unchanged.
    - Not "isn't completed": abandoned rows from earlier builds must not block (§2.2).
- **Tests, + 1 (`SyFiveTests`):** the `list` formatting for 0, 1, 2, 3, 4 ("…and 1 other") and 5
  ("…and 2 others") names; `list` is `static`, internal, so the test reaches it. The deletion itself
  is SyLib's, tested there.
- **Must not touch:** the active-player delete; merge; link; SyLib.
- **Done when:**
  1. The build passes.
  2. `00B`'s pinned command passes at the previous total + 1.
  3. The row is at the top of §5.
  4. Pops checks V1.

### Task 34.2 · Players on SyLib's shared delete, counts and merge (Syderal S-21)

Syderal `26` 26.26 moved three jobs into SyLibScoringData (Syderal S-21). SyFive's versions are
the thinnest of the three apps':
- **`deleteUnplayedPlayer(id:in:)`** refuses a played player and deletes every synced row of the id.
  SyFive's `onDelete` today calls `modelContext.delete(player)` with neither check.
- **`completedMatchCounts(in:)`** gives completed games per player, once per game.
- **`absorbPlayer`** now rolls back on failure. SyFive's merge and link get that without a change.

- **Change, `Views/PlayersView.swift`:**
  - `onDelete`: `if (try? deleteUnplayedPlayer(id: id, in: modelContext)) != true { mergeFailureMessage = "Couldn't delete that player. Please try again." }`.
  - `entries`: `n` comes from `(try? completedMatchCounts(in: modelContext)) ?? [:]`. The
    `completedMatches` dictionary built from `participants` goes. `everPlayed` (for `canDelete`)
    stays: any participant at all, finished or not, as D-177 has it.
- **Must not touch:** merge and link (they call `absorbPlayer` as they are); SyLib.
- **Done when:** the build passes; `00B`'s pinned command passes at 34.1's total; the row is at the
  top of §5.

### Task 34.3 · Abandoning or deleting an unfinished game removes its participants (§2.4)

- **Inputs:** §2.4; SyLib `SCORING_DATA.md` (`deleteMatch`).
- **Change**, each with a one-line comment citing `34` §2.4; both files already import
  `SyLibScoringData`:
  1. `Session/MatchController.swift`, `abandonMatch(in:)`: `context.delete(match)` becomes
     `deleteMatch(match, in: context)`. Nothing else in the function changes.
  2. `Views/Stats/MatchHistoryView.swift`, the "Delete this unfinished game?" alert's Delete:
     `modelContext.delete(m)` becomes `deleteMatch(m, in: modelContext)`.
  3. The same file, the "Delete all … unfinished games?" alert's Delete All: `for m in
     inProgressMatches { modelContext.delete(m) }` becomes `for m in inProgressMatches {
     deleteMatch(m, in: modelContext) }`.
  Nothing else changes, including when each calls `onActiveMatchDeleted`.
- **Tests, + 1:** in `MatchController`'s tests (or a new file beside them), an in-memory store: a
  match in progress with two participants, `abandonMatch`; afterwards no `MatchModel` and no
  `ParticipantModel` remain, and both `PlayerModel`s do.
- **Must not touch:** the stored orphans (§2.4: they stay); `LegacyRematchRepair`; SyLib.
- **Done when:** the build passes; `00B`'s pinned command passes at 34.2's total + 1; the row is at
  the top of §5; Pops checks V3 and V4.

### Task 34.4 · §2.2's alert says what SyFive offers (Pops, 9 November 2026)

- **Change, `Views/PlayersView.swift`:** the "Can't delete {name}" alert's message becomes, verbatim,
  "\(name) is in a game that isn't finished. Finish it, or delete it from Match History, first."
  The title, button and everything else stay.
- **Tests:** none (copy only).
- **Must not touch:** anything else.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.3's
  total, 25 tests (28 runs), with totals from the result bundle (`00B` §5 v1.3); the row is at the
  top of §5.

### Task 34.5 · The orphan sweep logs what it deletes (§2.5)

- **Inputs:** §2.5; `Persistence/Migration/LegacyRematchRepair.swift`'s orphan sweep (its first block
  in `run(in:)`).
- **Change, that block only:** before the deletes, after the existing count line, log one
  `logger.info` line per orphan:
  - its `id` and `playerID` (or "nil");
  - whether that player exists, as "active", "archived" or "missing" (fetch `PlayerModel` once, before
    the loop);
  - `displayName`, `seat`, how many score entries have a value, and the oldest and newest
    `recordedAt` (or "none");
  - `teamID` if it isn't nil.
  Then one summary line: the orphans per `playerID`, and how many have no `recordedAt`.
- **Behavior unchanged:** the same orphans are deleted, then the same save. Nothing else in `run(in:)`
  changes, and the log runs in every build, as the existing line does.
- **Tests:** none (log only).
- **Must not touch:** what the sweep deletes, and when; Strategies 1 to 4; `healOrphanedParticipants`;
  SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.4's total,
  25 tests (28 runs), from the result bundle; the row is at the top of §5; Pops runs V5.

### Task 34.6 · The orphan sweep is retired (§2.6)

- **Change, `Persistence/Migration/LegacyRematchRepair.swift`:**
  - Delete the orphan sweep: the whole first block of `run(in:)`, from its
    `// --- Orphan sweep` comment through its `try? context.save()`, including 34.5's lines.
  - The header comment: "Runs on every launch" becomes "Runs at every move to the foreground
    (`ContentView`'s `scenePhase` `.active`)", and it adds one line: "The orphan sweep that opened
    `run(in:)` until 34.6 deleted participants waiting on their match (`34` §2.6)."
  - Strategies 1 to 4, the save, and the imports stay. Remove `import SyLibScoring` only if the
    build warns that it's now unused.
- **Change, `Persistence/Migration/LegacyYahtzeeRepair.swift`:** its header's "Runs on every launch"
  becomes "Runs at every move to the foreground". Nothing else.
- **Tests:** none (a removal; no test covered the sweep).
- **Must not touch:** Strategies 1 to 4; `healOrphanedParticipants`; `ContentView`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.5's
  total, 25 tests (28 runs), from the result bundle; the row is at the top of §5.

### Task 34.7 · A lasting log of the repair's deletes (§2.6)

- **New, `Persistence/Migration/RepairLog.swift`:** `enum RepairLog` with
  `static func record(_ line: String)`. It appends one line, prefixed with an ISO 8601 UTC
  timestamp and the device model (`UIDevice.current.model`, so "iPhone" or "iPad"), to
  `Application Support/RepairLog/repair-log.txt` in the app's container, creating the folder and
  file if missing. If the file passes 256 KB, it keeps the newest half, cut at a line break. It
  reads the size from the open `FileHandle` (`seekToEnd()`), not from file attributes, so the privacy
  manifest (`35`) needs no new reason. A failure is logged with `logger.error` and never throws.
- **Change, `LegacyRematchRepair.run(in:)`:** at each of strategies 1 to 4's deletes, beside its
  existing `logger.info`, call `RepairLog.record` with: the strategy; the match's full `id`,
  `statusRaw`, `isGameNight`, `startedAt` and `completedAt`; and each participant's `id`,
  `playerID`, `displayName` and `finalScore`, in seat order. For strategy 3 also record the keeper's
  `id`. If the run deleted anything, one closing line with the existing "repaired: …" totals, and
  one more if the save fails. A run that deletes nothing writes nothing.
- **Reading it:** Xcode › Devices and Simulators › SyFive › Download Container, then
  `AppData/Library/Application Support/RepairLog/repair-log.txt`. No in-app screen.
- **Tests, + 1:** `RepairLog` over a temporary folder (give it an internal `fileURL` override for the
  test): two records give two lines in order; past the size cap, the newest lines remain and the
  first line is whole.
- **Must not touch:** what strategies 1 to 4 delete; `AppLogger`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.6's
  total + 1, from the result bundle; the row is at the top of §5; Pops checks V6.

## 4. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | Archive a test player who played games with others; swipe it | Red Delete beside Merge and Unarchive; the alert's counts and names are right; after Delete, the player and those games are gone from Players, Stats and House Records; a player in an unfinished game: after Delete, §2.2's alert, and nothing is deleted |
| V2 | After 34.2: add a player and delete them before they play; check the counts; merge two players | The new player is gone (on the other device too, after sync); each row's "N games" matches Stats; the merge works as before |
| V3 | After 34.3: add a new player, start a game with them, then New Game › Delete & Start New; open Players | The new player shows "0 games" and offers Delete, which removes them |
| V4 | After 34.3: add a new player, start a game with them, leave it unfinished; delete it from Match History (once singly, once with Delete All) | Each time, the new player then shows "0 games" and offers Delete, which removes them |
| V5 | After 34.5: on each of Pops's devices, run SyFive from Xcode (attached, so the private, info-level lines show; Console.app shows `<private>` and doesn't keep info), bring it to the foreground, and filter Xcode's console to `LegacyRematchRepair`; send Claude the orphan lines | The lines list each orphan as 34.5 specifies; the summary's count matches the existing "deleting N" line. On a second foreground, no orphans (they were deleted the first time) |
| V6 | After 34.7: on a device, download SyFive's container from Xcode and open `repair-log.txt` | It exists after a foreground that deleted something, or is absent when nothing was deleted; each line has a timestamp, the device, the strategy and the match's details |

## 5. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| 34.5 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: logging only, the same deletes and save, the `import SyLibScoring` fix is behavior-free. Report (1): the header comment's "every launch" is wrong (it's every foreground); left for §2.5's guard task. Report (2) confirmed: `AppLogger` logs its whole message as one dynamic string, private by default, and at info level, which isn't persisted. So V5 is read in Xcode's console with Xcode attached, not in Console.app. V5 is Pops's | Before: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped. After: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped; identical case list, none added or removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Persistence/Migration/LegacyRematchRepair.swift`, the orphan sweep block only. After the existing "deleting N" line and before the deletes, it fetches `PlayerModel` once, inside the block, so a foreground with no orphans does no extra fetch. Then one `logger.info` per orphan: `orphan: id=… playerID=…\|nil player=active\|archived\|missing name=… seat=… scored=<entries with a value> recordedAt=<oldest>…<newest>\|none`, plus ` teamID=…` when it isn't nil. Then `orphan sweep summary: N orphan(s); per playerID [<id>=<n>, …]; K with no recordedAt` (sorted by count, then id). Ids are full UUIDs. A player id with several synced rows reads "active" if any row is unarchived. The same orphans are deleted, then the same save; no flag; the rest of `run(in:)` is unchanged. Plus this row. **Fix under `00A` §8:** my change needed `import SyLibScoring` (for `ScoreEntry.value`/`recordedAt`); I added it, which changes no behavior. **Build:** `BuildProject` passed before (0 warnings); after, one error from my change (that import), fixed; then passed, 0 warnings. **Git (read-only):** `git status --short`, `git diff --stat HEAD -- Docs/Requirements/`, `git diff HEAD -- Docs/Requirements/00_DECISION_LEDGER.md`, `git diff HEAD -- Docs/Requirements/00B_SYFIVE_GUARDRAILS.md`, `git diff -- SyFive/Persistence/Migration/LegacyRematchRepair.swift`. **Report, outside the task:** (1) the file's header comment says it "Runs on every launch"; it runs at every foreground (`ContentView`'s `.active`), as §2.5 says. (2) The lines carry players' display names. If `AppLogger` logs interpolations as private, Console without Xcode attached will show `<private>` for V5. Not checked: it's SyLib source. V5 is Pops's |
| 34.4 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: one line, the message verbatim, nothing else changed. The D-001 report is Pops's to rule | Before: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped. After: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped; identical case list, none added or removed. Totals from `-resultBundlePath` bundles read with `xcrun xcresulttool get test-results summary` / `tests` (`00B` §5 v1.3). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayersView.swift`, one line: the "Can't delete {name}" alert's message is now `"\(name) is in a game that isn't finished. Finish it, or delete it from Match History, first."`. Title, OK button and everything else unchanged; plus this row. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`, `git diff HEAD -- Docs/Requirements/00B_SYFIVE_GUARDRAILS.md`, `git diff -- SyFive/Views/PlayersView.swift`. **Report, outside the task:** `00B` E-1 (D-001) holds SyFive's design documents immutable once delivered, with Supersessions blocks for changes. `34` has instead been rewritten in place, v1.0 to v1.4 (§2.2's message here), as Syderal's and Score It \*'s documents are under `00A` §1. I didn't act on it; whether `34` (and `33`, `35`) are exceptions, as D-148 makes `14` one, is for Pops |
| 34.3 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: the three call sites as §3 specifies, no saves added, `onActiveMatchDeleted` unchanged; the test checks its premise (one match in progress, two participants) before it calls `abandonMatch`. 25 tests (28 runs), from the xcresult bundle. V3 and V4 are Pops's | Before: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed. After: `** TEST SUCCEEDED **`, 25 tests (28 runs), 0 failed, 0 skipped: + `AbandonMatchTests/abandoningDeletesTheMatchAndItsParticipants()`, none removed. `testLaunch()` runs 4 times. Totals from each run's `.xcresult` (`xcrun xcresulttool get test-results summary` / `tests`). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Session/MatchController.swift`, `abandonMatch(in:)`: `context.delete(match)` becomes `deleteMatch(match, in: context)`, with a comment citing 34 §2.4; nothing else in the function changed. `Views/Stats/MatchHistoryView.swift`: in the single Delete and in Delete All's loop, `modelContext.delete(m)` becomes `deleteMatch(m, in: modelContext)`, each with a 34 §2.4 comment. No saves added; the `onActiveMatchDeleted` calls are unchanged. New `SyFiveTests/AbandonMatchTests.swift` (Swift Testing, `@MainActor`): `makeInMemoryScoringContainer(additionalModels: [AppSettingsModel.self])`; two `PlayerModel`s; a `MatchController` with both (`addPlayer(from: toDomain())`); `save(to:gameID: Game.builtInYatzyID)` plus a context save; then it checks the premise (one `"inProgress"` match, 2 participants) and calls `abandonMatch`. After it: 0 `MatchModel`, 0 `ParticipantModel`, and both players' ids remain. Plus this row. Stored orphans, `healOrphanedParticipants`, `LegacyRematchRepair`, `PlayersView` and SyLib untouched. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; no fixes needed. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`, `git diff --stat`. **Report:** text matching on `'…' passed on` read 27 runs after the change: interleaved xcodebuild output split a `testLaunch()` line mid-name again (as in 34.1). The xcresult bundle gives 28, which I recorded, and should be the source for totals from now on. V3 and V4 are Pops's |
| 34.2 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: `onDelete` and `entries` as §3 specifies, counts fetched once per call, `everPlayed` kept, nothing else touched. The report's duplicate-row difference is accepted: one count per match id is SyLib's rule in every app, and `LegacyRematchRepair` merges same-id duplicates at launch. If V2 ever shows a row one above Stats, the cause is a duplicate synced since launch (Stats' `@Query` counts rows, not ids). V2 is Pops's | Before: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed. After: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed; same case list, none added or removed. Counted from the run's `'…' passed on` lines. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayersView.swift` only, plus this row. `onDelete` is now `if (try? deleteUnplayedPlayer(id: id, in: modelContext)) != true { mergeFailureMessage = "Couldn't delete that player. Please try again." }`, with a one-line comment; the separate `try? modelContext.save()` is gone. In `entries`, `completedCounts = (try? completedMatchCounts(in: modelContext)) ?? [:]` is fetched once per call, before the map; `n = completedCounts[player.id] ?? 0`; the `completedMatches` dictionary is gone. `everPlayed` (any participant, any status) still drives `canDelete`. Doc comment updated. `archivedDelete`/`list`/`undeletableName` (34.1), merge, link, `healOrphanedParticipants` and `MatchController` untouched. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; no fixes needed. **Git (read-only):** `git status --short`, `git diff --stat HEAD -- Docs/Requirements/`, `git diff -- SyFive/Views/PlayersView.swift`. **Report:** one difference the counts can show, not a defect I found: the old loop counted every completed match a player's participant row was in, while `completedMatchCounts` reads one row per match id (the fullest). Where synced duplicates of one match differ in participants, a player missing from the fullest row would now read one fewer. V2 is Pops's |
| 34.1 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: §2.1's copy verbatim, §2.2's check on `"inProgress"` only, the alert set from a `Task` after the confirm, `deletePlayerAndMatches` with defaults, nothing else touched. Report (1): §3's stale `private` is fixed (v1.3). (3): "Those games" with one game is as Syderal ("Those missions") and Score It \* ("Those matches"), kept. V1 is Pops's | Before: `** TEST SUCCEEDED **`, 23 tests (26 runs), 0 failed. After: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed: + `ArchivedDeleteOthersTests/othersListNamesThreeThenCounts()`, none removed. `testLaunch()` runs 4 times. Counted from the run's `'…' passed on` lines (xcodebuild prints no summary total). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayersView.swift`: `@State undeletableName`; internal `static func list(_:)`; an `archivedDelete` property passed to `PlayersSheet`. Its title and message are §2.1's copy from `try? playerDeletionImpact(playerID:in:)`; if that throws, they fall back to the no-games copy. Its action runs §2.2's check against the view's existing `participants` query (`playerID == id && match?.statusRaw == "inProgress"`); if that finds one, it sets the name in `Task { @MainActor … }` for the new OK-only "Can't delete {name}" alert. Otherwise `try deletePlayerAndMatches(player, in: modelContext)` with defaults; a throw is logged and sets the existing `mergeFailureMessage`. New `SyFiveTests/ArchivedDeleteOthersTests.swift` (Swift Testing, `@MainActor`); this row. `onDelete`, merge, link and `healOrphanedParticipants` untouched. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; no fixes needed. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. **Report:** (1) §3 says `private static func list` in one line and internal in another; the prompt said internal, which I followed. (2) `list([])` returns `""` (the spec doesn't say); the alert never uses it, since no others picks §2.1's "your records" message. (3) With 1 game, §2.1's message still reads "Those games…", pasted as given. (4) The first count in this session missed one `testLaunch()` run, because interleaved xcodebuild output split its line; the counter now matches without a line anchor. V1 is Pops's |

## 6. Ledger rows (Claude files them when 34 closes)

| ID | Ruling | Source |
|---|---|---|
| D-194 | **An archived player can be deleted with every game they played**, through SyLibScoringData's `deletePlayerAndMatches`; an unplayed active player through `deleteUnplayedPlayer`, and the rows' counts from `completedMatchCounts` (Syderal S-21). The games leave everyone's records, and the alert names the completed count and the others ("1 other"). Not while they're in a game in progress (`"inProgress"`); any other status goes with them. Abandoning an unfinished game (`abandonMatch`), or deleting one from Match History, deletes its participants with it, through `deleteMatch` (§2.4); `LegacyRematchRepair`'s foreground orphan sweep is retired (D-196). Ruled separately below. *Why:* development test data kept creeping into synced production data with no way to clean it up, and players want the same for guests, duplicates and practice games. | `34 §2` (Pops, 8 Nov 2026) |
| D-196 | **SyFive's foreground orphan sweep is retired, and `LegacyRematchRepair`'s deletes go to a lasting log.** No participant has a creation date, so the sweep couldn't tell a seat waiting for its match from a true orphan; on Pops's iPad it deleted both seats of a finished game whose match was gone. An orphan now stays until its player is deleted. Strategies 1 to 4 also write each delete to `repair-log.txt` in the app's container, which survives relaunch, unlike `AppLogger`'s info lines. | `34 §2.5–2.6` → `36` §4.1 (Pops, 9 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.6 | 9 Nov 2026 | V5 is in (§2.5): the iPad's two orphans were a finished 30 October game's seats, its match gone. §2.6 (Pops): retire the sweep (Task 34.6) and log the repair's deletes to a file (Task 34.7); V6; D-196 |
| 1.5 | 9 Nov 2026 | Correction: since 1.0, `LegacyRematchRepair` sweeps every no-match participant at each foreground, so stored orphans didn't stay (§2.4). §2.5 (Pops): log it first, Task 34.5 and V5; its guard is ruled after the log |
| 1.4 | 9 Nov 2026 | Wording only (Pops): "ended" becomes "abandoned" in §2.4, 34.3's title, V3 and the ledger row; SyFive has no End Game menu item (Score It \*'s vocabulary had crept in), and abandoning a game means deleting it unfinished. §2.2's alert message becomes "Finish it, or delete it from Match History, first." (Pops), as Task 34.4 |
| 1.3 | 8 Nov 2026 | Pops's rulings: §2.2 confirmed, with Score It \*'s alert title "Can't delete {name}" presented after the confirm closes; §2.4 ruled and widened to Match History's two unfinished-game deletes; 34.1's stale "isn't completed" line fixed; V4 |
| 1.2 | 8 Nov 2026 | Brought up to date with Score It \* `27`: §2.2 checks `"inProgress"`, not "isn't completed"; `{others}` says "1 other", tested at four names; teams excluded (SyFive makes none); §2.4 and Task 34.3, `abandonMatch`'s orphaned participants, for Pops to rule; V3 |
| 1.1 | 8 Nov 2026 | Brought up to date with Syderal 26.26–26.28: §2.2's check runs after the sheet's confirm (Pops); `deletePlayerAndMatches` deletes every synced row of the id; V2 for 34.2 |
| 1.0 | 8 Nov 2026 | First version |
