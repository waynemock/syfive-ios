# SyFive: delete an archived player and every game they played, as Syderal

**Status:** **Closed** 9 November 2026: 34.1 to 34.14 done and checked; V1 to V11 pass (Pops, on device); D-194 and D-196 to D-201 filed in `00_DECISION_LEDGER.md`. Score It \*'s adoption (§2.10) and `PlayersSheet`'s broken previews (§2.11) are for later sessions. Version 1.15, 9 November 2026.
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

**2.6 Retire the orphan sweep** (D-196; Pops, 9 November
2026, from V5).
- **The sweep goes** (Task 34.6). Since 34.3 SyFive makes no orphans of its own, and the one set it
  found on Pops's account was a finished game's seats. An orphan now stays until its player is
  deleted: `deletePlayerAndMatches` already takes a player's orphans with them, and an active player
  blocked only by orphans is a later SyLib change (`36` §5).
- **The rest of `LegacyRematchRepair` follows** (§2.8, v1.9). Task 34.7, built to v1.8's plan, logs
  strategies 1 to 4's deletes to `RepairLog` until 34.10 removes the repair.
- **Considered and excluded:** guarding the sweep (by `recordedAt` age, during a CloudKit import, or
  once per launch). No participant has a creation date, so no guard can tell a seat waiting for its
  match from a true orphan. Rebuilding a match from full-scorecard orphans: a bigger design, not now.

**2.7 Abandoning never deletes a completed match** (D-197; Pops, 9 November 2026). The 30 October
game was a Game Night game (Pops). A Game Night game is saved twice over: `ContentView`'s
`onMatchComplete` writes the finished `MatchModel` under the game's wire id from the completed
match it receives, and the device's `MatchController` holds that same id as `persistedMatchID`.
`abandonMatch` decides whether the game is over from the controller's in-memory scorecards
(`!isGameOver`), never from the stored row. If the controller is a score short when the session
ends (the last score arrived only in the completed match, or the session dropped before the final
state), the stored row is already `"completed"`, and Delete & Start New, or the host's Play Locally
or New Game Night Game, deletes it.
- **Likely, not proven, for 30 October:** the playing device deleted the match, leaving its seats
  (before 34.3); its own sweep cleared them; the delete synced to the iPad, whose copies of the seats
  stayed orphaned until V5's foreground.
- **Why now:** since 34.3, `deleteMatch` takes the seats too, so this path would erase a finished
  Game Night game whole.
- **The rule:** `abandonMatch` deletes a stored match only if its `statusRaw` is `"inProgress"` as
  well as `!isGameOver`. A completed one is left alone and the controller simply unbinds from it,
  as it already does after any abandon.
- **A lasting log:** every delete `abandonMatch` does make is written to a small text file in the
  app's container that survives relaunch (`AppLogger`'s info lines don't), so the next lost game can
  be traced (Task 34.8, on 34.7's `RepairLog`).

**2.8 `LegacyRematchRepair` is retired; readers take one row per match id** (D-198; Pops,
9 November 2026; supersedes v1.8's "strategy 1 keeps the fullest copy"). Pops's aim is to stop loss
from here on, not to repair old data (`36` §5). Each part, against that aim (`36` §3–4):
- **Strategies 2, 3 and 4** clean only old data: abandoned rows no build saves now, copies from the
  match-per-turn bug and early Game Night saves, and matches synced to the wrong account, which
  history sync's table test now prevents (`36` §4.5). Strategy 4 is also a risk (`36` §4.2).
- **Strategy 1** handles a live case: two rows with one match id, as when two devices on one
  account are at one Game Night. But it deletes to do it, and could keep the partial copy (`36` §4.4).
  SyLib's readers already settle duplicates without deleting: one row per id, the one with the most
  participants (`fetchCompletedMatches`, `completedMatchCounts`, `GNHistoryStore`).
- **So:** SyFive's views that read `MatchModel` rows through `@Query` take one row per id the same way
  (Task 34.9), and then `LegacyRematchRepair` is deleted (Task 34.10). Order matters: readers first,
  or a doubled game would count twice in Stats in between.
- **`LegacyYahtzeeRepair`:** kept here because it deletes nothing; retired after all by §2.9.
- **Accepted:** the four old duplicate groups in `36` §4.3 have different ids, so they keep counting
  twice (Pops: old data).

**2.9 `LegacyYahtzeeRepair` is retired too** (D-199; Pops, 9 November 2026). It repaired two field
renames that CloudKit kept delivering under their old names: the `"yahtzee"` slot key (the
"Expunged yahtzee" change, before the 1.0 commit), and the Yatzy bonus field, renamed
`yatzyBonus` → `bonusPoints` for SyLib (`00_SYLIB_MIGRATION_PLAN.md` §4.1, 28 August 2026, likely
shipped in 1.0.1). It never deleted, but it rewrote fields, and it read every participant and
decoded every scorecard at every foreground.
- **Converged:** each record was fixed once and the fix synced, so every device that has run SyFive
  since has been repaired. V5's logs on both of Pops's devices show no "repaired slotKeys=…" line.
- **Accepted:** a device on the same account still running 1.0 would write the old bonus field, which
  a current device would read as 0. Unlikely months on (Pops).
- **`Persistence/Migration/`** is then empty and goes.

**2.10 One row per match id, and deleting every copy of one, move into SyLib** (D-200; Pops,
9 November 2026; kept in this document by Pops). The fullest-row-per-id rule is written five times:
SyLib's `fetchCompletedMatches` (`MatchModel+Operations.swift` 59–64), `GNHistoryStore.manifestIDs`
(63) and `GNHistoryStore.matches(for:)` (112); Score It \*'s `StatsMatches` (92); and SyFive's
`onePerMatchID()` (34.9).
- **SyLibScoringData gains** `onePerMatchID()` on `[MatchModel]` (SyFive's 34.9 rule and name, now
  public), used by SyLib's own three readers, and `deleteMatches(id:in:)`, which deletes every row of
  one match id through `deleteMatch` (34.10's Match History change, made shared). Task 34.12.
- **SyFive adopts both** and drops its copy (Task 34.13).
- **Score It \* follows in its own session** (not tasked here, `00A` v1.8): `StatsMatches` uses
  `onePerMatchID()`; `MatchSetupSheet` (120, 146) replaces `onePerID(…, createdAt: \.startedAt)` on
  match rows, which keeps whichever copy is fetched first, not the fullest; `MatchRecorder.delete(matchID:)`,
  which deletes only the row it fetches, uses `deleteMatches(id:in:)`.
- **Stays in SyFive:** `RepairLog` (one app; a lasting `AppLogger` file sink is the SyLib form, when a
  second app wants one) and the abandon guard (`MatchController`'s).

**2.11 Delete swipes are red** (D-201; Pops, 9 November 2026, testing V1). On device, both Delete
swipes in the Players sheet, on active and archived rows, show orange: neither red nor the player's
theme color. SyLib's own spec says red (`SCORING_UI.md`, the swipe table from Syderal `26` 26.22:
Delete has no tint, "`role: .destructive` draws it red").
- **The cause** (from the code; confirmed by the agent's reading in 34.14's first, blocked session): `RosterSheet` puts
  `.tint(colors?.accent ?? syTheme.primaryAccent)` on the whole sheet (168). A swipe button with no
  tint of its own takes the surrounding tint, which overrides the destructive red, so Delete shows the
  sheet's palette accent. With an orange accent it sits beside Archive's `.orange`, the two hard to
  tell apart.
- **The rule:** both Delete swipes carry `.tint(.red)` explicitly, so the sheet's tint can't reach them.
  `TeamsSheet` shares `RosterSheet`, so its Deletes follow. All three apps take it at their next build.
- **Also found** (34.14's first session): `PlayersSheet`'s Xcode previews don't compile ("initializer
  delegation ('self.init') cannot be nested in another expression", 201 onward). Pre-existing, and not
  part of this fix; to be taken up in a later SyLib session.
- **Unchanged:** Edit stays the sheet's accent; Archive orange, Unarchive green, Merge indigo; the
  alerts' Delete buttons (system alerts, red by role).

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

### Task 34.7 · A lasting log of the repair's deletes (done, to v1.8's spec)

*Built before §2.8 retired the repair. Its strategy logging stands until 34.10 removes
`LegacyRematchRepair`; `RepairLog` itself is kept and moved then.*


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
- **Also, `LegacyRematchRepair.swift`:** remove `import SyLibScoring`, which only 34.5's sweep needed
  (34.6's report), if the file still builds without it.
- **Must not touch:** what strategies 1 to 4 delete; `AppLogger`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.6's
  total + 1, from the result bundle; the row is at the top of §5; Pops checks V6.

### Task 34.8 · Abandoning never deletes a completed match, and logs what it deletes (§2.7)

- **Uses 34.7's `RepairLog`** (`Persistence/Migration/RepairLog.swift`), unchanged.
- **Change, `Session/MatchController.swift`, `abandonMatch(in:)`:** the delete happens only when the
  fetched match's `statusRaw == "inProgress"` and `!isGameOver`. Before `deleteMatch`, call
  `RepairLog.record` with "abandonMatch", the match's `id`, `statusRaw`, `isGameNight` and
  `startedAt`, and each participant's `id`, `playerID`, `displayName` and seat. When a fetched match
  is skipped because it's completed, `logger.info` one line saying so (nothing was deleted, so not the
  repair log). The save and the unbinding after it (`persistedMatchID = nil` and the rest) are
  unchanged, so the controller lets go of a completed match either way. A one-line comment cites
  `34` §2.7.
- **Tests, + 1:**
  1. Beside 34.3's `AbandonMatchTests`: a `MatchController` with two players saves a match in
     progress; the stored row is then set to `statusRaw = "completed"` (as `onMatchComplete` would)
     while the controller's scorecards stay incomplete; `abandonMatch`. The match and both
     participants remain, and `persistedMatchID` is nil. 34.3's test still passes unchanged.
- **Must not touch:** `onMatchComplete`; `MatchHistoryView` (its deletes are already limited to
  unfinished games by its query); `LegacyRematchRepair` (34.10); `RepairLog`; Game Night code; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.7's
  total + 1, from the result bundle; the row is at the top of §5; Pops checks V7.

### Task 34.9 · SyFive's views take one row per match id (§2.8)

- **New, `Persistence/MatchModel+OnePerID.swift`:** `extension Array where Element == MatchModel`
  with `func onePerMatchID() -> [MatchModel]`: one row per `id`, the rule `fetchCompletedMatches`
  uses (a later row replaces the kept one only with strictly more `participants`), each kept row at
  the position its id first appears, so a view's sort order holds. A comment cites `34` §2.8 and
  notes it as a SyLib candidate.
- **Change:** every `@Query` of `MatchModel` that a view counts or lists reads through it:
  - `Views/HouseRecords/HouseRecordsView.swift` (`completedModels`);
  - `Views/Stats/HeadToHeadCard.swift`, `HeadToHeadDetailView.swift` and `PlayerProfileView.swift`
    (`completedModels`);
  - `Views/Stats/MatchHistoryView.swift`, both `completedMatches` and `inProgressMatches`, including
    the "Delete all N" count and loop.

  The simplest form is a computed property beside each query (for example
  `private var matches: [MatchModel] { completedModels.onePerMatchID() }`) used in place of the raw
  array. `CelebrationView`'s and `ContentView`'s queries only test "any match exists" and stay as
  they are.
- **Tests, + 1:** an in-memory store with three rows: two of one id (the later with more
  participants) and one of another id. `onePerMatchID()` returns two rows, the fuller copy for the
  shared id, in first-appearance order; with equal participants the first row stays.
- **Must not touch:** what any view shows beyond dropping duplicate rows; `LegacyRematchRepair`
  (34.10); SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.8's
  total + 1, from the result bundle; the row is at the top of §5; Pops checks V8.

### Task 34.10 · `LegacyRematchRepair` is retired (§2.8)

- **Depends on 34.9** (or duplicates count twice in between).
- **Change:**
  - Delete `Persistence/Migration/LegacyRematchRepair.swift`. The `SyFive` folder is synchronized,
    so this removes it from the target; don't edit `project.pbxproj`.
  - `Views/ContentView.swift`, the `scenePhase` `.active` case: remove
    `LegacyRematchRepair.run(in: modelContext)`, with a one-line comment that it was retired in
    `34` §2.8. `LegacyYahtzeeRepair.run(in:)` stays.
  - Move `Persistence/Migration/RepairLog.swift` to `Persistence/RepairLog.swift` (it outlives the
    repair), and change its header comment to say it records `abandonMatch`'s deletes (`34` §2.7),
    as it did `LegacyRematchRepair`'s from 34.7 until 34.10.
  - Remove any import that only `LegacyRematchRepair` needed elsewhere (none is expected).
  - `Views/Stats/MatchHistoryView.swift` (34.9's report): a delete removes **every** stored row of the
    match's id, not only the kept one, since strategy 1 no longer clears copies. The single Delete
    calls `deleteMatch` for each row in `inProgressRows` whose `id` is the kept row's; Delete All loops
    over `inProgressRows`, the raw query. The alert's count stays `inProgressMatches.count`, and
    `onActiveMatchDeleted` is called as now.
- **Tests:** none (a removal, and view code).
- **Must not touch:** `LegacyYahtzeeRepair`; `healOrphanedParticipants`; SyLib's `GNMatchIdentity`
  (history sync still uses it).
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.9's
  total, from the result bundle; no reference to `LegacyRematchRepair` remains in SyFive's code; the
  row is at the top of §5; Pops checks V9.

### Task 34.11 · `LegacyYahtzeeRepair` is retired (§2.9)

- **Change:**
  - Delete `Persistence/Migration/LegacyYahtzeeRepair.swift`, then the empty `Persistence/Migration/`
    folder. The `SyFive` folder is synchronized; don't edit `project.pbxproj`.
  - `Views/ContentView.swift`, the `scenePhase` `.active` case: remove
    `LegacyYahtzeeRepair.run(in: modelContext)`. Replace 34.10's comment there with one line covering
    both: "The legacy data repairs that ran here were retired (34 §2.8–2.9)."
    `director.handleForeground()` stays.
  - Remove any import that only `LegacyYahtzeeRepair` needed elsewhere (none is expected).
- **Tests:** none (a removal; no test covered it).
- **Must not touch:** everything else in the `scenePhase` handler; `RepairLog`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.10's
  total, from the result bundle; no reference to `LegacyYahtzeeRepair` remains in SyFive's code (a
  quoted search); the row is at the top of §5; Pops checks V10.

### Task 34.12 · SyLib: `onePerMatchID()` and `deleteMatches(id:in:)` (§2.10)

- **A SyLib session** (`sylib-swift`, its own session under `00A` v1.8). Inputs: §2.10; SyLib
  `Docs/SCORING_DATA.md`; SyFive's `Persistence/MatchModel+OnePerID.swift`, read only, for the rule.
- **New, `Sources/SyLibScoringData/Operations/MatchModel+OnePerID.swift`:**
  - `public extension Array where Element == MatchModel { func onePerMatchID() -> [MatchModel] }`:
    one row per `id`; a later row replaces the kept one only with strictly more `participants`; each
    kept row sits where its id first appears. Doc comment: why (CloudKit enforces no uniqueness; at
    Game Night every device on an account writes the finished match under its one id), and that it
    reads only.
  - `@discardableResult public func deleteMatches(id: UUID, in context: ModelContext) throws -> Int`:
    fetches every `MatchModel` with that `id`, calls `deleteMatch` on each, returns the count. Doesn't
    save, as `deleteMatch` doesn't.
- **Change, SyLib's three readers, behavior identical:** `fetchCompletedMatches` (its one-per-id loop),
  `GNHistoryStore.manifestIDs` (its `fullestByID` loop) and `GNHistoryStore.matches(for:)` (its
  `fullestByID` loop, over the asked ids) each use `onePerMatchID()` in place of their loop. Every
  existing SyLib test passes unchanged; any that fails means the rule moved and is a stop condition.
- **Docs:** `SCORING_DATA.md` documents both beside `deleteMatch` and `fetchCompletedMatches`, and
  notes that the three readers use `onePerMatchID()`.
- **Tests, + 2** (SyLib, `makeInMemoryScoringContainer()`): `onePerMatchID()` keeps the fuller copy,
  in first-appearance order, the first on a tie; `deleteMatches(id:in:)` deletes every copy of one id
  and its participants, leaves other matches, returns the count.
- **Must not touch:** any other SyLib API; SyFive; Syderal; Score It \*.
- **Done when:** SyLib's suite passes at its previous total + 2 (`00B` §5.3, totals from the result
  bundle); Syderal builds and its suite passes unchanged against it (`00B` §5.4, as it uses
  `GNHistoryStore`); the row is at the top of §5.
- **Expected:** SyFive won't build between 34.12 and 34.13. It uses SyLib by local path, and its own
  internal `onePerMatchID()` then clashes with SyLib's public one (an ambiguous call). Run 34.13 next;
  don't build SyFive in this session.

### Task 34.13 · SyFive on SyLib's `onePerMatchID()` and `deleteMatches(id:in:)` (§2.10)

- **Depends on 34.12, and runs right after it:** until this task deletes SyFive's own
  `onePerMatchID()`, SyFive doesn't build (an ambiguous call). That is the first build error to
  expect; fixing it by this task's change is in scope.
- **Change:**
  - Delete `Persistence/MatchModel+OnePerID.swift` and `SyFiveTests/OnePerMatchIDTests.swift` (the
    test moved to SyLib in 34.12). The five views keep calling `onePerMatchID()`, now SyLib's, with
    no edit; each already imports `SyLibScoringData`.
  - `Views/Stats/MatchHistoryView.swift`, the single Delete: the `inProgressRows` filter and loop
    become `try? deleteMatches(id: m.id, in: modelContext)`. Delete All is unchanged (it already
    loops the raw rows).
  - `ENGINEERING_GUIDELINES.md`'s folder listing loses its `MatchModel+OnePerID.swift` line.
- **Tests:** none added; one removed (moved to SyLib).
- **Must not touch:** the views' `@Query` properties; `RepairLog`; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at 34.11's total
  − 1 (`OnePerMatchIDTests` removed, named), from the result bundle (the baseline is 34.11's
  recorded 28 tests (31 runs), since SyFive can't build before this change); the row is at the top of §5.
  V8 still holds.

### Task 34.14 · Delete swipes are red (§2.11)

- **A SyLib session** (`sylib-swift`, `00A` v1.8). Inputs: §2.11; SyLib `Docs/SCORING_UI.md` (the swipe
  table).
- **No preview check** (v1.14): a preview is a still image, and swipe buttons only appear mid-swipe,
  so no preview can show a Delete's color. The first session stopped on that (§5). The change is
  checked on device, V11.
- **Change, `Sources/SyLibScoringUI/Roster/RosterSheet.swift`:** both trailing Delete swipe buttons
  (active rows, `canDelete`; archived rows, `archivedDelete`) gain `.tint(.red)`, keeping
  `role: .destructive`. A one-line comment: the sheet's tint would otherwise reach them (`34` §2.11).
  Nothing else.
- **Docs, `SCORING_UI.md`:** the swipe table's Delete row's Tint becomes "`.red`, explicit: the sheet's
  `.tint` would otherwise override the destructive role (SyFive `34` §2.11)". The Teams sheet section
  needs no change (it says the swipes are the Players sheet's).
- **Tests:** none (a tint; previews show it).
- **Must not touch:** the other swipes and their tints; the alerts; any other SyLib API; SyFive, Syderal,
  Score It \*.
- **Done when:** SyLib's suite passes at 34.12's total, 1584 tests (1659 runs), from the result bundle
  (`00B` §5.3); Syderal builds and its suite passes unchanged, 915 (973) (`00B` §5.4); the row is at
  the top of §5; Pops checks V11.
- **Found, not fixed here:** `PlayersSheet`'s previews don't compile in Xcode Previews ("initializer
  delegation ('self.init') cannot be nested in another expression", `PlayersSheet.swift` 201, 210,
  231, 257 and on), from before this task. A separate fix (§2.11's note).

## 4. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | Archive a test player who played games with others; swipe it | Red Delete beside Merge and Unarchive; the alert's counts and names are right; after Delete, the player and those games are gone from Players, Stats and House Records; a player in an unfinished game: after Delete, §2.2's alert, and nothing is deleted |
| V2 | After 34.2: add a player and delete them before they play; check the counts; merge two players | The new player is gone (on the other device too, after sync); each row's "N games" matches Stats; the merge works as before |
| V3 | After 34.3: add a new player, start a game with them, then New Game › Delete & Start New; open Players | The new player shows "0 games" and offers Delete, which removes them |
| V4 | After 34.3: add a new player, start a game with them, leave it unfinished; delete it from Match History (once singly, once with Delete All) | Each time, the new player then shows "0 games" and offers Delete, which removes them |
| V5 | After 34.5: on each of Pops's devices, run SyFive from Xcode (attached, so the private, info-level lines show; Console.app shows `<private>` and doesn't keep info), bring it to the foreground, and filter Xcode's console to `LegacyRematchRepair`; send Claude the orphan lines | The lines list each orphan as 34.5 specifies; the summary's count matches the existing "deleting N" line. On a second foreground, no orphans (they were deleted the first time) |
| V6 | After 34.7: on a device, download SyFive's container from Xcode | `AppData/Library/Application Support/RepairLog/repair-log.txt` exists only after a foreground whose repair deleted something; each line has a timestamp, the device, the strategy and the match's details |
| V7 | After 34.8: a Game Night game played to the end, then on each device New Game › Delete & Start New (host: also Play Locally); then a local game abandoned midway; download SyFive's container and open `repair-log.txt` | The finished Game Night game stays in History on both devices; the midway game is gone, and the log has one "abandonMatch" line for it with a timestamp, the device and its details |
| V8 | After 34.9: Stats, Head-to-Head, House Records and Match History on both devices, after a Game Night game the two of them were at | Each game appears and counts once; totals match the Players list's "N games" |
| V9 | After 34.10: run SyFive from Xcode and bring it to the foreground | No `LegacyRematchRepair` lines; History and Stats unchanged from V7 |
| V10 | After 34.11: open a few finished games with a Yatzy bonus in Match History, on both devices | Their bonus and totals are as before |
| V11 | After 34.14, in SyFive with an orange-accented palette: swipe an active player who can be deleted, and an archived player | Delete is red on both, distinct from Archive's orange; Edit is still the accent |

## 5. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| V7, V8 | 9 Nov 2026 | **pass** (Pops, on device) | — | A finished Game Night game survives Delete & Start New and Play Locally; each game counts once in Stats, Head-to-Head and House Records |
| V11 | 9 Nov 2026 | **pass** (Pops, on device) | — | Delete is red on active and archived rows |
| 34.14 (second attempt) | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: `.tint(.red)` on both Delete swipes with a §2.11 comment, the swipe table updated, nothing else | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before: `Passed`, 1584 tests (1659 runs), 1583 passed, 0 failed, 1 skipped. After: identical totals and case list. **Syderal** (`00B` §5.4, `xcodebuild test -project Syderal.xcodeproj -scheme Syderal` from `syderal-ios/Syderal`, SyLib at `../../sylib-swift`). Before: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped. After: identical totals and case list. All totals from `-resultBundlePath` bundles read with `xcresulttool`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files (sylib-swift):** `Sources/SyLibScoringUI/Roster/RosterSheet.swift`: both trailing Delete swipes (active, `canDelete`, at 202; archived, `archivedDelete`, at 223) gain `.tint(.red)` after their label, keeping `role: .destructive`, each with the comment "Explicit: the sheet's .tint would otherwise reach it (SyFive 34 §2.11)." Edit, Archive, Merge, Unarchive, the alerts and `PlayersSheet`'s previews unchanged. `Docs/SCORING_UI.md`: the swipe table's Delete Tint cell now reads "`.red`, explicit: the sheet's `.tint` would otherwise override the destructive role (SyFive 34 §2.11)". Plus this row. SyFive, Syderal and Score It \* not edited. No preview check, per v1.14. **Warnings:** 0 `warning:` lines in all four test logs. **Git (read-only):** syfive-ios `git diff --stat HEAD -- Docs/Requirements/`; sylib-swift `git status --short` ×2, `git branch --list`, `git diff -- Sources/SyLibScoringUI/Roster/RosterSheet.swift Docs/SCORING_UI.md`; syderal-ios `git status --short` ×2. **Report:** (1) sylib-swift is on `main`, 34.12 still staged; this task's two files are unstaged, for Pops. (2) syderal-ios has a second untracked doc of Pops's (`28_DUPLICATE_MATCH_ROWS_FINDINGS.md`), left alone. (3) 34 v1.14's Task 34.14 still says "Tests: none (a tint; previews show it)" (line 510), which contradicts its "No preview check" line. V11 is Pops's |
| V10 | 9 Nov 2026 | **pass** (Pops, on device) | — | Yatzy bonuses and totals unchanged after 34.11 |
| V9 | 9 Nov 2026 | **pass** (Pops, on device) | — | No `LegacyRematchRepair` lines at foreground; History and Stats unchanged |
| V6 | 9 Nov 2026 | **pass** (Pops, on device) | — | `repair-log.txt` in the downloaded container, with the abandoned game's "abandonMatch" line |
| V4 | 9 Nov 2026 | **pass** (Pops, on device) | — | Unfinished games deleted from Match History, singly and with Delete All; the new player then shows 0 games and deletes |
| V3 | 9 Nov 2026 | **pass** (Pops, on device) | — | Delete & Start New, then the new player shows 0 games and deletes |
| V1 | 9 Nov 2026 | **pass** (Pops, on device) | — | Archived-player Delete: counts and names right, games gone from Players, Stats and House Records; a player in an unfinished game gets the "Can't delete" alert |
| 34.14 | 9 Nov 2026 | **blocked**: step 2 ("confirm the cause in previews") can't be done and done-when 3 ("the previews show red Deletes beside the orange Archive") can't be met from a session (`00A` §4) | Not run: the baselines come before edits, and no edit was made. Last recorded: SyLib 1584 tests (1659 runs), Syderal 915 (973), 34.12 | **No source edited** in sylib-swift, SyFive or Syderal; this row only. **Found:** (1) `PlayersSheet.swift`'s previews don't compile in Xcode Previews. `RenderPreview` of "An archived player, expanded, with Delete" fails in the preview thunk with "initializer delegation ('self.init') cannot be nested in another expression" at lines 201, 210, 231, 257 and on: the design-time wrapper around the file's delegating `init`s (`PlayerListEntry`, `PlayersSheetCopy`, `PlayersSheet` convenience initializers). It predates this task; the live canvas likely hits it too. (2) Even a rendered preview is a static snapshot, and swipe actions show only when a row is swiped, so no preview can show a Delete swipe's color. **From the code (read, not confirmed):** `RosterSheet.swift:168` tints the sheet `colors?.accent ?? syTheme.primaryAccent`; the Delete swipes (`:202` active, `:221` archived) have no tint of their own, while Archive (`:209` `.orange`), Merge (`:231` `.indigo`) and Unarchive (`:236` `.green`) do. That matches §2.11's likely cause. **For Pops to choose:** (a) accept the cause from the code and the device report (V1), re-word done-when 3 to a device check (V11), and re-issue 34.14 unchanged otherwise; (b) ask for a simulator check with the device-interaction tools (`00A` §6: by request), swiping a row in SyFive's Players sheet before and after; or (c) first fix the previews' compile error (a separate SyLib task), though they still couldn't show a swipe. **Git (read-only):** syfive-ios `git diff --stat HEAD -- Docs/Requirements/`; sylib-swift `git status --short`, `git branch --list` (on `main`; 34.12's changes staged) |
| V2 | 9 Nov 2026 | **pass** (Pops, on device) | — | An unplayed player deletes; each row's "N games" matches Stats; merge works as before |
| 34.13 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: SyFive's copy and its test are gone, the views use SyLib's `onePerMatchID()` unedited, Match History's single delete is `deleteMatches(id:in:)`, the guidelines listing is updated. 27 tests (30 runs) | Baseline (no build, as directed): 34.11's recorded `Passed`, 28 tests (31 runs). After: `Passed`, 27 tests (30 runs), 27 passed, 0 failed, 0 skipped. Against 34.11's own bundle, the only case-list change is `OnePerMatchIDTests/onePerMatchIDKeepsTheFullerCopyInFirstAppearanceOrder()` removed (moved to SyLib in 34.12); none added. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Persistence/MatchModel+OnePerID.swift` and `SyFiveTests/OnePerMatchIDTests.swift` deleted (plain `rm`). The five views' `onePerMatchID()` calls now resolve to SyLibScoringData's, which each already imports; no view edited, `@Query` properties untouched. `Views/Stats/MatchHistoryView.swift`, single Delete: the `inProgressRows` filter and loop become `_ = try? deleteMatches(id: m.id, in: modelContext)`; the comment and its 34 §2.4/§2.8 citations kept; Delete All unchanged. `Docs/ENGINEERING_GUIDELINES.md`: the `MatchModel+OnePerID.swift` line removed from the folder listing. Plus this row. **Fix under `00A` §8:** the specified `try? deleteMatches(…)` warned "Result of 'try?' is unused", since `@discardableResult` doesn't cover `try?`'s optional; `_ =` added, no behavior change. **Build:** the first build after the change gave that one warning, fixed; then passed, 0 warnings (test targets included); 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. The two deletions show as `AD` (staged adds, unstaged deletes), for Pops |
| 34.12 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: both functions as specified, the three readers keep the same row by the same rule, `fetchCompletedMatches` keeps its sort, existing tests unchanged; Syderal unchanged at 915 (973). Report (1): SyLib's changes are on `main`, uncommitted, for Pops | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package`, from `sylib-swift`). Before: `Passed`, 1582 tests (1657 runs), 1581 passed, 0 failed, 1 skipped. After: `Passed`, 1584 tests (1659 runs), 1583 passed, 0 failed, 1 skipped: + `OnePerMatchIDTests/onePerMatchIDKeepsTheFullerCopyInFirstAppearanceOrder()` and `OnePerMatchIDTests/deleteMatchesDeletesEveryCopyOfOneID()`, none removed, every existing test unchanged and passing. **Syderal** (`00B` §5.4, `xcodebuild test -project Syderal.xcodeproj -scheme Syderal`, from `syderal-ios/Syderal`, which resolves SyLib at `../../sylib-swift`). Before: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped. After: identical totals and case list. All totals from `-resultBundlePath` bundles read with `xcresulttool`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` for both | **Files (sylib-swift):** new `Sources/SyLibScoringData/Operations/MatchModel+OnePerID.swift`: `public extension Array where Element == MatchModel { func onePerMatchID() }`, SyFive's 34.9 rule with the doc comment as specified, and `@discardableResult public func deleteMatches(id:in:) throws -> Int` (fetch by id, `deleteMatch` each, return the count, no save). `MatchModel+Operations.swift`: `fetchCompletedMatches`'s loop becomes `.onePerMatchID()` before its `(startedAt, id)` sort. `GNHistoryStore.swift`: `manifestIDs` iterates `fetch(…).onePerMatchID()` (its `order`/`fullestByID` gone); `matches(for:)` builds `fullestByID` from `fetch(…).filter { asked.contains($0.id) }.onePerMatchID()`. Each is the same rule over the same rows, so the same row of each id is kept (shown by the unchanged readers' tests). `Docs/SCORING_DATA.md`: `deleteMatches` in the deleteMatch section's heading, signature and bullets; a new "onePerMatchID" subsection under `fetchCompletedMatches`, saying the three readers use it, with a SyFive adoption note pointing to 34.13. New `Tests/SyLibTests/SyLibScoringData/OnePerMatchIDTests.swift` (Swift Testing, `ModelContext(makeInMemoryScoringContainer())`). No other SyLib API changed; SyFive, Syderal and Score It \* not edited. SyFive not built, as directed (34.13). Plus this row. **Warnings:** 0 `warning:` lines in either test log, before and after. **Git (read-only):** syfive-ios `git diff --stat HEAD -- Docs/Requirements/`; sylib-swift `git status --short` ×2, `git branch --list`, `git log --oneline -3`, `git diff --stat`; syderal-ios `git status --short` ×2, `git branch --list`. **Report:** (1) sylib-swift was on `main` with a clean tree. I worked there as found (`00A` §9); its changes are uncommitted for Pops. (2) syderal-ios has an untracked doc of Pops's (`Syderal/Docs/Requirements/POST_MVP/27_DELETE_ALERT_ONE_OTHER.md`), left alone. (3) SyFive won't build until 34.13 (its own `onePerMatchID()` now clashes with SyLib's), as 34 §3 expects |
| 34.11 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: the file and the `Migration/` folder are gone, no reference to either repair remains, the foreground handler keeps `handleForeground()` and one comment. The `HouseRecords` doc-comment edit (Pops-approved) is accepted; the read-only bonus fallback it describes stays. Pops stages the delete. V10 is Pops's | Before: `Passed`, 28 tests (31 runs), 28 passed, 0 failed, 0 skipped. After: `Passed`, 28 tests (31 runs), 28 passed, 0 failed, 0 skipped; identical case list, none added or removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Persistence/Migration/LegacyYahtzeeRepair.swift` deleted (plain `rm`), then the empty `Persistence/Migration/` folder (`rmdir`). The folder is synchronized; `project.pbxproj` not edited and names neither. `Views/ContentView.swift`, `scenePhase` `.active`: the `run(in:)` call and 34.10's comment are replaced by "The legacy data repairs that ran here were retired (34 §2.8–2.9)."; `director.handleForeground()` and the rest of the handler are unchanged. **Outside the task's list, approved by Pops in-session:** `App/HouseRecords/HouseRecords.swift:337`, a doc comment only. "not yet repaired by LegacyYahtzeeRepair." is now "not repaired by the legacy repair retired in 34 §2.9."; the `bonusPoints` fallback it describes is unchanged. Without this edit, done-when 3 couldn't be met. Imports: the deleted file's `SyLibYatzy`/`SyLibScoring` imports were its own, and `ContentView` imports neither for it, so none removed. Plus this row. **Search (done-when 3):** `grep -rn "LegacyYahtzeeRepair" --include=*.swift SyFive SyFiveTests SyFiveUITests` gives no matches (exit 1); `project.pbxproj` has 0 hits for the name or `Migration`. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings; 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. The deletion shows as `MD` (34.6's staged header change plus the unstaged delete), for Pops to stage. V10 is Pops's |
| 34.10 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: the file is gone, no reference remains, `RepairLog` moved with only its header changed, Match History's deletes take every copy of an id, `LegacyYahtzeeRepair` stays. Pops stages the ` D` and `??`. V9 is Pops's | Before: `Passed`, 28 tests (31 runs), 28 passed, 0 failed, 0 skipped. That is the rerun: the first baseline run was stopped when the simulator crashed (Pops), with no code changed yet. After: `Passed`, 28 tests (31 runs), 28 passed, 0 failed, 0 skipped; identical case list, none added or removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Persistence/Migration/LegacyRematchRepair.swift` deleted (plain `rm`; the folder is synchronized; `project.pbxproj` not edited and names neither file). `Views/ContentView.swift`, `scenePhase` `.active`: the `run(in:)` call is replaced by the comment "The match repair that ran here was retired; views take one row per id (34 §2.8)."; `LegacyYahtzeeRepair.run(in:)` stays. `RepairLog.swift` moved from `Persistence/Migration/` to `Persistence/` (plain `mv`); only its header comment changed, now "A lasting record of what abandonMatch deletes (34 §2.7), as it was of the legacy match repair's deletes from 34.7 until that repair was retired in 34.10…". Behavior unchanged. `Views/Stats/MatchHistoryView.swift`: the single Delete now deletes, through `deleteMatch`, every row in `inProgressRows` whose id is the kept row's; Delete All loops over `inProgressRows`; the alert's count (`inProgressMatches.count`) and both `onActiveMatchDeleted` calls are unchanged; each has a 34 §2.8 comment. Imports: the deleted file's only SyLib-specific use was `GNMatchIdentity` (SyLibGameNightMatch), which `ContentView` still imports for Game Night, so no import was removed. Plus this row. **Search (done-when 3):** `grep -rn "LegacyRematchRepair" --include=*.swift SyFive SyFiveTests SyFiveUITests` gives no matches (exit 1); the same name in `project.pbxproj`, none. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings; 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. The tree now shows the deletion as ` D` and the moved file as `??` `SyFive/Persistence/RepairLog.swift`, for Pops to stage. V9 is Pops's |
| 34.9 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: `onePerMatchID()` by `fetchCompletedMatches`'s rule, in first-appearance order; the five views read through it; `CelebrationView` and `ContentView` untouched. Report (1) is a real gap, fixed in 34.10: Match History's deletes take every row of the id. (2) accepted: tied copies are one game. V8 is Pops's | Before: `Passed`, 27 tests (30 runs), 27 passed, 0 failed, 0 skipped. That is the rerun: the first baseline was `Failed`, 25 of 27, when the simulator crashed (Pops), with only `SyFiveUITests/testLaunchPerformance()` and `SyFiveUITestsLaunchTests/testLaunch` failing and no code changed yet. After: `Passed`, 28 tests (31 runs), 28 passed, 0 failed, 0 skipped: + `OnePerMatchIDTests/onePerMatchIDKeepsTheFullerCopyInFirstAppearanceOrder()`, none removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** new `Persistence/MatchModel+OnePerID.swift`: `extension Array where Element == MatchModel { func onePerMatchID() }`. It keeps one row per id; a later row replaces the kept one only with strictly more `participants`; each kept row sits at its id's first position. The comment cites 34 §2.8 and notes it as a SyLib candidate. In `HouseRecordsView`, `HeadToHeadCard`, `HeadToHeadDetailView`, `PlayerProfileView` and `MatchHistoryView`, each `@Query` property is renamed (`completedRows`, `inProgressRows`). Its old name (`completedModels`, `completedMatches`, `inProgressMatches`) is now a computed `{ …Rows.onePerMatchID() }` beside it, with a one-line 34 §2.8 comment. So every existing use reads one row per id, with no use edited: Match History's lists, segment count, swipe-delete index, empty states, and "Delete all N" count and loop. `CelebrationView` (`contains`) and `ContentView` (`isEmpty`) untouched. New `SyFiveTests/OnePerMatchIDTests.swift` (in-memory store: [partial(id A, 1 seat), other(id B, 2), fuller(id A, 2)] gives [fuller, other]; a tie of 2 and 2 seats keeps the first). Plus this row. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings; 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`, `git diff -- SyFive/Views/`. **Report:** (1) Match History's deletes now act on the kept row only. Where an unfinished game has two stored copies, Delete or Delete All removes one, and the other then shows in its place and needs a second delete. As specified ("including the … loop"); 34.10 removes strategy 1, which used to clear such copies. (2) Ties: `fetchCompletedMatches` keeps the first by `startedAt` ascending; `onePerMatchID` keeps the first in the view's own order. In `HeadToHeadDetailView` and `MatchHistoryView` (sorted `.reverse`) that is the later-started copy of a tie. Copies of one id with equal seats are one game, so nothing shown changes in practice. V8 is Pops's |
| 34.8 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: deletes only an `"inProgress"` row the controller holds as unfinished, records it first, keeps and unbinds anything else; the test covers the 30 October shape. Report (1) is the rule as ruled. (2) accepted: a simulator-only line in the test host's log. V7 is Pops's | Before: `Passed`, 26 tests (29 runs), 26 passed, 0 failed, 0 skipped. After: `Passed`, 27 tests (30 runs), 27 passed, 0 failed, 0 skipped: + `AbandonMatchTests/abandoningKeepsAMatchStoredAsCompleted()`, none removed; 34.3's `abandoningDeletesTheMatchAndItsParticipants()` passes unchanged. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Session/MatchController.swift`, `abandonMatch(in:)` only. Inside the existing `if let match …, !isGameOver`, it deletes only when `match.statusRaw == "inProgress"`, with a comment citing 34 §2.7. First `RepairLog.record("abandonMatch deleted: id=… status=… isGameNight=… startedAt=… participants=[{id playerID name seat} …]")` in seat order, then 34.3's `deleteMatch`. Otherwise one `logger.info`: "abandonMatch: kept match <id>, stored status=<statusRaw>, not in progress; unbinding only". The save and unbinding after it are unchanged. `SyFiveTests/AbandonMatchTests.swift`: a second `@Test` (two players, a match saved in progress, the stored row set to `"completed"` with the scorecards empty, then `abandonMatch`). Afterwards the one match remains, still `"completed"`, with 2 participants, and `persistedMatchID` is nil. 34.3's test is untouched. Plus this row. `RepairLog`, `onMatchComplete`, `MatchHistoryView`, `LegacyRematchRepair` and Game Night code untouched. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings; 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. **Report:** (1) The skip line is logged for any stored status but `"inProgress"`, not only `"completed"`, so a legacy `"abandoned"` row is also kept and named. The rule ("only `inProgress`") deletes neither. (2) 34.3's test, kept unchanged, now writes one "abandonMatch deleted" line to the test host's real `repair-log.txt` on the simulator, since it sets no `fileURL` override. Harmless, and simulator only. V7 is Pops's |
| 34.7 | 9 Nov 2026 | complete (the agent, to v1.8's spec); **checked by Claude against the tree**: `RepairLog` as specified (size from the handle, cap at a line break, never throws), strategies 1 to 4 record each delete with full details, nothing recorded when nothing is deleted, deletes unchanged, `import SyLibScoring` gone. Report accepted: `attributesOfItem` is in the test target only. V6 is Pops's | Before: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped. After: `Passed`, 26 tests (29 runs), 26 passed, 0 failed, 0 skipped: + `RepairLogTests/repairLogAppendsInOrderAndKeepsTheNewestWhole()`, none removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). The first after-run was stopped when the simulator crashed (Pops); the totals are from the rerun. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** new `Persistence/Migration/RepairLog.swift`: `enum RepairLog` with `record(_:)`. It writes `<ISO 8601 UTC> <UIDevice.current.model> <line>` to `URL.applicationSupportDirectory/RepairLog/repair-log.txt`, creating the folder and file. It gets the size from the open `FileHandle`'s `seekToEnd()`, with no file attributes. Past `capBytes` (256 KB) it rewrites the newest half, starting after the first line break in it. Failures go to `logger.error` (category "RepairLog"); it never throws. `static var fileURL: URL?` is the test override. `LegacyRematchRepair.swift`: beside each of strategies 1 to 4's `logger.info`, and before its deletes, `RepairLog.record("strategyN deleted: …")` with the match's full id, `statusRaw`, `isGameNight`, `startedAt`, `completedAt` and each participant `{id playerID name finalScore}` in seat order. Strategy 3 adds `keeper=<id>`. The "repaired: …" text is built once, logged as before, and recorded only when `deleted > 0`; "save failed: …" is recorded the same way. A run that deletes nothing writes nothing, and no file is created. What the strategies delete is unchanged. `import SyLibScoring` removed: the file builds without it. New `SyFiveTests/RepairLogTests.swift` (Swift Testing, `@MainActor`, synchronous, so the host app can't record while `fileURL` is overridden). Plus this row. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings; 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. **Report:** the test reads the file's size with `attributesOfItem` to check the cap. That is test-target code, not in the app, so `35`'s manifest is unaffected. V6 is Pops's |
| 34.6 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: the sweep is gone, `run(in:)` opens at strategies 1 to 4, both headers say "every move to the foreground", nothing else changed. The report is right: Swift doesn't warn on unused imports. 34.7 removes `import SyLibScoring`, since it touches the same file | Before: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped. After: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped; identical case list, none added or removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Persistence/Migration/LegacyRematchRepair.swift`: the orphan sweep is deleted, from `// --- Orphan sweep` through its `try? context.save()` and closing brace, with 34.5's per-orphan lines and summary and the blank line after it; `run(in:)` now opens at `let all = …`. The header's "Runs on every launch" is now "Runs at every move to the foreground (ContentView's scenePhase .active)", wrapped to two lines, plus the line "The orphan sweep that opened run(in:) until 34.6 deleted participants waiting on their match (34 §2.6)." Strategies 1 to 4, their logging, the save and all imports are unchanged. `Persistence/Migration/LegacyYahtzeeRepair.swift`: the header's "Runs on every launch" is now "Runs at every move to the foreground"; nothing else (the line now runs past the file's usual wrap; left as is). Plus this row. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; both files recompiled with no issue of any severity, so `import SyLibScoring` stays. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`, `git diff -- Docs/Requirements/`, `git diff -- SyFive/Persistence/Migration/`. **Report:** Swift doesn't warn about unused imports, so the "remove `import SyLibScoring` if it warns" condition can't fire. That import came in with 34.5, only for the sweep's `ScoreEntry.value`/`recordedAt`, and is probably unneeded now. Left in place, as directed |
| 34.5 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: logging only, the same deletes and save, the `import SyLibScoring` fix is behavior-free. Report (1): the header comment's "every launch" is wrong (it's every foreground); left for §2.5's guard task. Report (2) confirmed: `AppLogger` logs its whole message as one dynamic string, private by default, and at info level, which isn't persisted. So V5 is read in Xcode's console with Xcode attached, not in Console.app. V5 is Pops's | Before: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped. After: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped; identical case list, none added or removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Persistence/Migration/LegacyRematchRepair.swift`, the orphan sweep block only. After the existing "deleting N" line and before the deletes, it fetches `PlayerModel` once, inside the block, so a foreground with no orphans does no extra fetch. Then one `logger.info` per orphan: `orphan: id=… playerID=…\|nil player=active\|archived\|missing name=… seat=… scored=<entries with a value> recordedAt=<oldest>…<newest>\|none`, plus ` teamID=…` when it isn't nil. Then `orphan sweep summary: N orphan(s); per playerID [<id>=<n>, …]; K with no recordedAt` (sorted by count, then id). Ids are full UUIDs. A player id with several synced rows reads "active" if any row is unarchived. The same orphans are deleted, then the same save; no flag; the rest of `run(in:)` is unchanged. Plus this row. **Fix under `00A` §8:** my change needed `import SyLibScoring` (for `ScoreEntry.value`/`recordedAt`); I added it, which changes no behavior. **Build:** `BuildProject` passed before (0 warnings); after, one error from my change (that import), fixed; then passed, 0 warnings. **Git (read-only):** `git status --short`, `git diff --stat HEAD -- Docs/Requirements/`, `git diff HEAD -- Docs/Requirements/00_DECISION_LEDGER.md`, `git diff HEAD -- Docs/Requirements/00B_SYFIVE_GUARDRAILS.md`, `git diff -- SyFive/Persistence/Migration/LegacyRematchRepair.swift`. **Report, outside the task:** (1) the file's header comment says it "Runs on every launch"; it runs at every foreground (`ContentView`'s `.active`), as §2.5 says. (2) The lines carry players' display names. If `AppLogger` logs interpolations as private, Console without Xcode attached will show `<private>` for V5. Not checked: it's SyLib source. V5 is Pops's |
| 34.4 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: one line, the message verbatim, nothing else changed. The D-001 report is Pops's to rule | Before: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped. After: `Passed`, 25 tests (28 runs), 25 passed, 0 failed, 0 skipped; identical case list, none added or removed. Totals from `-resultBundlePath` bundles read with `xcrun xcresulttool get test-results summary` / `tests` (`00B` §5 v1.3). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayersView.swift`, one line: the "Can't delete {name}" alert's message is now `"\(name) is in a game that isn't finished. Finish it, or delete it from Match History, first."`. Title, OK button and everything else unchanged; plus this row. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`, `git diff HEAD -- Docs/Requirements/00B_SYFIVE_GUARDRAILS.md`, `git diff -- SyFive/Views/PlayersView.swift`. **Report, outside the task:** `00B` E-1 (D-001) holds SyFive's design documents immutable once delivered, with Supersessions blocks for changes. `34` has instead been rewritten in place, v1.0 to v1.4 (§2.2's message here), as Syderal's and Score It \*'s documents are under `00A` §1. I didn't act on it; whether `34` (and `33`, `35`) are exceptions, as D-148 makes `14` one, is for Pops |
| 34.3 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: the three call sites as §3 specifies, no saves added, `onActiveMatchDeleted` unchanged; the test checks its premise (one match in progress, two participants) before it calls `abandonMatch`. 25 tests (28 runs), from the xcresult bundle. V3 and V4 are Pops's | Before: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed. After: `** TEST SUCCEEDED **`, 25 tests (28 runs), 0 failed, 0 skipped: + `AbandonMatchTests/abandoningDeletesTheMatchAndItsParticipants()`, none removed. `testLaunch()` runs 4 times. Totals from each run's `.xcresult` (`xcrun xcresulttool get test-results summary` / `tests`). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Session/MatchController.swift`, `abandonMatch(in:)`: `context.delete(match)` becomes `deleteMatch(match, in: context)`, with a comment citing 34 §2.4; nothing else in the function changed. `Views/Stats/MatchHistoryView.swift`: in the single Delete and in Delete All's loop, `modelContext.delete(m)` becomes `deleteMatch(m, in: modelContext)`, each with a 34 §2.4 comment. No saves added; the `onActiveMatchDeleted` calls are unchanged. New `SyFiveTests/AbandonMatchTests.swift` (Swift Testing, `@MainActor`): `makeInMemoryScoringContainer(additionalModels: [AppSettingsModel.self])`; two `PlayerModel`s; a `MatchController` with both (`addPlayer(from: toDomain())`); `save(to:gameID: Game.builtInYatzyID)` plus a context save; then it checks the premise (one `"inProgress"` match, 2 participants) and calls `abandonMatch`. After it: 0 `MatchModel`, 0 `ParticipantModel`, and both players' ids remain. Plus this row. Stored orphans, `healOrphanedParticipants`, `LegacyRematchRepair`, `PlayersView` and SyLib untouched. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; no fixes needed. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`, `git diff --stat`. **Report:** text matching on `'…' passed on` read 27 runs after the change: interleaved xcodebuild output split a `testLaunch()` line mid-name again (as in 34.1). The xcresult bundle gives 28, which I recorded, and should be the source for totals from now on. V3 and V4 are Pops's |
| 34.2 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: `onDelete` and `entries` as §3 specifies, counts fetched once per call, `everPlayed` kept, nothing else touched. The report's duplicate-row difference is accepted: one count per match id is SyLib's rule in every app, and `LegacyRematchRepair` merges same-id duplicates at launch. If V2 ever shows a row one above Stats, the cause is a duplicate synced since launch (Stats' `@Query` counts rows, not ids). V2 is Pops's | Before: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed. After: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed; same case list, none added or removed. Counted from the run's `'…' passed on` lines. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayersView.swift` only, plus this row. `onDelete` is now `if (try? deleteUnplayedPlayer(id: id, in: modelContext)) != true { mergeFailureMessage = "Couldn't delete that player. Please try again." }`, with a one-line comment; the separate `try? modelContext.save()` is gone. In `entries`, `completedCounts = (try? completedMatchCounts(in: modelContext)) ?? [:]` is fetched once per call, before the map; `n = completedCounts[player.id] ?? 0`; the `completedMatches` dictionary is gone. `everPlayed` (any participant, any status) still drives `canDelete`. Doc comment updated. `archivedDelete`/`list`/`undeletableName` (34.1), merge, link, `healOrphanedParticipants` and `MatchController` untouched. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; no fixes needed. **Git (read-only):** `git status --short`, `git diff --stat HEAD -- Docs/Requirements/`, `git diff -- SyFive/Views/PlayersView.swift`. **Report:** one difference the counts can show, not a defect I found: the old loop counted every completed match a player's participant row was in, while `completedMatchCounts` reads one row per match id (the fullest). Where synced duplicates of one match differ in participants, a player missing from the fullest row would now read one fewer. V2 is Pops's |
| 34.1 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: §2.1's copy verbatim, §2.2's check on `"inProgress"` only, the alert set from a `Task` after the confirm, `deletePlayerAndMatches` with defaults, nothing else touched. Report (1): §3's stale `private` is fixed (v1.3). (3): "Those games" with one game is as Syderal ("Those missions") and Score It \* ("Those matches"), kept. V1 is Pops's | Before: `** TEST SUCCEEDED **`, 23 tests (26 runs), 0 failed. After: `** TEST SUCCEEDED **`, 24 tests (27 runs), 0 failed: + `ArchivedDeleteOthersTests/othersListNamesThreeThenCounts()`, none removed. `testLaunch()` runs 4 times. Counted from the run's `'…' passed on` lines (xcodebuild prints no summary total). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/PlayersView.swift`: `@State undeletableName`; internal `static func list(_:)`; an `archivedDelete` property passed to `PlayersSheet`. Its title and message are §2.1's copy from `try? playerDeletionImpact(playerID:in:)`; if that throws, they fall back to the no-games copy. Its action runs §2.2's check against the view's existing `participants` query (`playerID == id && match?.statusRaw == "inProgress"`); if that finds one, it sets the name in `Task { @MainActor … }` for the new OK-only "Can't delete {name}" alert. Otherwise `try deletePlayerAndMatches(player, in: modelContext)` with defaults; a throw is logged and sets the existing `mergeFailureMessage`. New `SyFiveTests/ArchivedDeleteOthersTests.swift` (Swift Testing, `@MainActor`); this row. `onDelete`, merge, link and `healOrphanedParticipants` untouched. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; no fixes needed. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`. **Report:** (1) §3 says `private static func list` in one line and internal in another; the prompt said internal, which I followed. (2) `list([])` returns `""` (the spec doesn't say); the alert never uses it, since no others picks §2.1's "your records" message. (3) With 1 game, §2.1's message still reads "Those games…", pasted as given. (4) The first count in this session missed one `testLaunch()` run, because interleaved xcodebuild output split its line; the counter now matches without a line anchor. V1 is Pops's |

## 6. Ledger rows (filed 9 November 2026)

| ID | Ruling | Source |
|---|---|---|
| D-194 | **An archived player can be deleted with every game they played**, through SyLibScoringData's `deletePlayerAndMatches`; an unplayed active player through `deleteUnplayedPlayer`, and the rows' counts from `completedMatchCounts` (Syderal S-21). The games leave everyone's records, and the alert names the completed count and the others ("1 other"). Not while they're in a game in progress (`"inProgress"`); any other status goes with them. Abandoning an unfinished game (`abandonMatch`), or deleting one from Match History, deletes its participants with it, through `deleteMatch` (§2.4); `LegacyRematchRepair`'s foreground orphan sweep is retired (D-196). Ruled separately below. *Why:* development test data kept creeping into synced production data with no way to clean it up, and players want the same for guests, duplicates and practice games. | `34 §2` (Pops, 8 Nov 2026) |
| D-196 | **SyFive's foreground orphan sweep is retired.** No participant has a creation date, so the sweep couldn't tell a seat waiting for its match from a true orphan; on Pops's iPad it deleted both seats of a finished game whose match was gone. An orphan now stays until its player is deleted. | `34 §2.5–2.6` → `36` §4.1 (Pops, 9 Nov 2026) |
| D-197 | **Abandoning never deletes a completed match.** `abandonMatch` deletes only a stored match whose `statusRaw` is `"inProgress"`, as well as one the controller holds as unfinished; a completed one is kept and the controller unbinds. Every abandon delete goes to `repair-log.txt` in the app's container, which survives relaunch. *Why:* a Game Night game is stored complete by `onMatchComplete` while the controller can lag a score behind, so its in-memory state alone could delete a finished game; the likely cause of the lost 30 October Game Night game. | `34 §2.7` (Pops, 9 Nov 2026) |
| D-198 | **`LegacyRematchRepair` is retired, and SyFive's views take one row per match id** (the fullest, as SyLib's readers do) instead of deleting duplicates. Strategies 2 to 4 cleaned only old data; strategy 1's live case is settled by reading, not deleting. `LegacyYahtzeeRepair`, which deletes nothing, stays. *Why:* the aim is to stop loss from here on, and every part of the repair deleted data on every foreground. | `34 §2.8` → `36` §3–5 (Pops, 9 Nov 2026) |
| D-199 | **`LegacyYahtzeeRepair` is retired**, and with it SyFive's last foreground data repair. It fixed two old field renames (the `"yahtzee"` slot key; `yatzyBonus` → `bonusPoints`), and every device that has run since has been repaired. *Why:* it read every participant at every foreground to fix records that no longer exist. | `34 §2.9` (Pops, 9 Nov 2026) |
| D-200 | **SyLibScoringData owns one-row-per-match-id and delete-every-copy**: `onePerMatchID()` on `[MatchModel]` (the fullest copy, in first-appearance order), used by `fetchCompletedMatches` and `GNHistoryStore`, and `deleteMatches(id:in:)`. SyFive adopts both; Score It \* follows in its own session (`StatsMatches`, `MatchSetupSheet`, `MatchRecorder.delete`). *Why:* the rule was written five times, and Score It \*'s setup sheet used a different one. | `34 §2.10` (Pops, 9 Nov 2026) |
| D-201 | **The roster sheets' Delete swipes are red, explicitly** (`.tint(.red)` with `role: .destructive`), in `PlayersSheet` and `TeamsSheet` for every app. *Why:* the sheet's own accent tint reached the untinted Delete, which showed orange beside Archive's orange (Pops, on device). | `34 §2.11` (Pops, 9 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.15 | 9 Nov 2026 | Closed: V7 and V8 pass; D-194 and D-196 to D-201 filed |
| 1.14 | 9 Nov 2026 | Task 34.14's preview check and its done-when removed: previews can't show a swipe's color (the agent stopped there). V11 on device is the check. `PlayersSheet`'s broken previews noted in §2.11 |
| 1.13 | 9 Nov 2026 | §2.11 (Pops, from testing): Delete swipes showed the sheet's accent, not red; Task 34.14 (SyLib) tints them red explicitly; V11; D-201 |
| 1.12 | 9 Nov 2026 | §2.10 (Pops, kept in 34): `onePerMatchID()` and `deleteMatches(id:in:)` move into SyLibScoringData, Task 34.12 (SyLib session), 34.13 (SyFive adopts); Score It \* noted for its own session; D-200 |
| 1.11 | 9 Nov 2026 | §2.9 (Pops): `LegacyYahtzeeRepair` is retired too, Task 34.11; V10; D-199 |
| 1.10 | 9 Nov 2026 | 34.7 ran to v1.8's spec (`RepairLog`, logging strategies 1 to 4). Recorded as done; the rest renumbered: 34.8 the abandon guard (+1 test, on 34.7's `RepairLog`), 34.9 the views, 34.10 the removal, which also moves `RepairLog` to `Persistence/`. V6 restored for 34.7; V7–V9 follow |
| 1.9 | 9 Nov 2026 | §2.8 rewritten (Pops): `LegacyRematchRepair` is retired, after SyFive's views take one row per id; supersedes v1.8's strategy 1 fix and v1.6's repair-wide log. Tasks reordered: 34.7 is the abandon guard with `RepairLog` (abandon deletes only), 34.8 the views, 34.9 the removal; V6–V8, D-196 to D-198 rewritten |
| 1.8 | 9 Nov 2026 | §2.8 (Pops): strategy 1 keeps the copy with the most participants, Task 34.9; V8; D-198. From the Game Night sync review (`36` §4.4–4.5) |
| 1.7 | 9 Nov 2026 | §2.7 (Pops): the 30 October game was a Game Night game; `abandonMatch` trusted only in-memory state and could delete a stored completed match. Task 34.8 guards it on `statusRaw` and logs its deletes; V7; D-197 |
| 1.6 | 9 Nov 2026 | V5 is in (§2.5): the iPad's two orphans were a finished 30 October game's seats, its match gone. §2.6 (Pops): retire the sweep (Task 34.6) and log the repair's deletes to a file (Task 34.7); V6; D-196 |
| 1.5 | 9 Nov 2026 | Correction: since 1.0, `LegacyRematchRepair` sweeps every no-match participant at each foreground, so stored orphans didn't stay (§2.4). §2.5 (Pops): log it first, Task 34.5 and V5; its guard is ruled after the log |
| 1.4 | 9 Nov 2026 | Wording only (Pops): "ended" becomes "abandoned" in §2.4, 34.3's title, V3 and the ledger row; SyFive has no End Game menu item (Score It \*'s vocabulary had crept in), and abandoning a game means deleting it unfinished. §2.2's alert message becomes "Finish it, or delete it from Match History, first." (Pops), as Task 34.4 |
| 1.3 | 8 Nov 2026 | Pops's rulings: §2.2 confirmed, with Score It \*'s alert title "Can't delete {name}" presented after the confirm closes; §2.4 ruled and widened to Match History's two unfinished-game deletes; 34.1's stale "isn't completed" line fixed; V4 |
| 1.2 | 8 Nov 2026 | Brought up to date with Score It \* `27`: §2.2 checks `"inProgress"`, not "isn't completed"; `{others}` says "1 other", tested at four names; teams excluded (SyFive makes none); §2.4 and Task 34.3, `abandonMatch`'s orphaned participants, for Pops to rule; V3 |
| 1.1 | 8 Nov 2026 | Brought up to date with Syderal 26.26–26.28: §2.2's check runs after the sheet's confirm (Pops); `deletePlayerAndMatches` deletes every synced row of the id; V2 for 34.2 |
| 1.0 | 8 Nov 2026 | First version |
