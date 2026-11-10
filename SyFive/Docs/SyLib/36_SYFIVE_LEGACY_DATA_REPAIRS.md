# SyFive: the legacy data repairs, what each fixes and whether it's still needed

**Status:** **Reference, now history. `LegacyRematchRepair` was retired on 9 November 2026 (`34` §2.8, Task 34.10); `LegacyYahtzeeRepair` (§6) the same day (`34` §2.9, Task 34.11). SyFive runs no data repairs now.** Written 9 November 2026 from the code and Pops's account.
§5's open items are Pops's. Version 1.4, 9 November 2026.

**Scope:** `syfive-ios`, `Persistence/Migration/`: `LegacyRematchRepair.swift` (210 lines) and, for
completeness, `LegacyYahtzeeRepair.swift` (70). Nothing here changes code. `34` §2.5 cites this
document for the orphan sweep.

---

## 1. Why this exists

Until now the only record of these repairs was each file's header comment. The design corpus names
them only in folder listings (`ENGINEERING_GUIDELINES.md`, `02`, `14`). The bugs behind them aren't
recorded anywhere, and git can't help: everything landed in the first commit (`488a320`, "SyFive
full 1.0 implementation", 24 August 2026).

**The history, from Pops (9 November 2026):** early in SyFive's development there were many
problems with orphaned and duplicated data. The worst was **a bug that created a new match every
time a participant took a turn**. It was fixed **before 1.0 shipped**, so its damage is in
development data, chiefly Pops's own devices (which also carry many matches deleted during
development), not in players' data.

---

## 2. When the repairs run

Both run on **every move to the foreground**, not once per launch: `ContentView`'s
`.onChange(of: scenePhase)` calls `LegacyYahtzeeRepair.run(in:)`, then `LegacyRematchRepair.run(in:)`,
on `.active`. Both header comments say "every launch", which is wrong (`34` 34.5's report).

Every delete either makes syncs to every device on the same iCloud account. A wrong delete is not
local.

---

## 3. `LegacyRematchRepair`, part by part

In the order the code runs them.

| Part | What it deletes | The cause it repairs | Still needed? |
|---|---|---|---|
| **Orphan sweep** | Every `ParticipantModel` whose `match` is nil | Match deletes that skipped participants (`abandonMatch`, Match History's two unfinished-game deletes), until `34` 34.3 | Probably not: 34.3 stopped SyFive making new ones, and V5 on Pops's first device found none. It is also the one part that can delete good data (§4.1) |
| **Strategy 1**, id dedup | All but one `MatchModel` per `id`, keeping a completed one, then the latest `completedAt`; their participants first | Sync duplicates of one match id | Yes: CloudKit can deliver a record twice at any time (SyLib's readers also take one row per id) |
| **Strategy 2**, abandoned | Every match with `statusRaw == "abandoned"`, participants first | Builds that saved abandoned games. SyFive no longer does | Only for old rows; harmless if none remain |
| **Strategy 4**, foreign Game Night | Completed Game Night matches in which no participant has ever played solo on this account | Game Night matches synced to a device they don't belong to (the header's example: Wayne and BurnTest's matches on Sherida's phone) | Unclear; see §4.2. Skipped entirely when the account has no solo games |
| **Strategy 3**, content dedup | Within each group of completed matches sharing one fingerprint (`GNMatchIdentity`: start second, sorted names, sorted scores), all but the valid copy with the earliest `completedAt`. Skips a group whose `completedAt` spread is over 20 minutes, or where any copy lacks one, or where every copy has `completedAt` before `startedAt` | The match-per-turn bug, and copies whose `startedAt` was re-stamped at insert by the history-sync handler | Yes, while the 4 groups in §4.3 remain |

Then one save for strategies 1 to 4. The orphan sweep saves on its own, first.

---

## 4. Findings

### 4.1 The orphan sweep can delete a seat from a real game

CloudKit syncs a match and its participants as separate records. On a new device or mid-sync, a
participant can arrive before its match and look exactly like an orphan. The sweep deletes it, the
delete syncs, and the game loses a seat on every device. A participant has no creation date, only
each score entry's `recordedAt`, so the sweep can't tell the two apart. (`34` §2.5.)

**V5, Pops's two devices, one iCloud account (9 November 2026):**
- **iPhone:** no orphans, at either foreground. Strategy 4's solo owner is `765CB4B8` (Wayne).
- **iPad:** 2 orphans, deleted by the sweep after it logged them:

  | Participant | Player | Seat | Scored | Entries recorded (UTC) |
  |---|---|---|---|---|
  | `9730D94A…` | Sherida (`3DB751D6`, active) | 0 | 13 | 30 Oct 2026, 15:03:23 to 15:11:04 |
  | `9C6F60B9…` | Wayne (`765CB4B8`, active) | 1 | 13 | 30 Oct 2026, 15:03:50 to 15:11:14 |

  These are not leftovers of an abandoned game: both scorecards are full (13 of 13), so they are
  the two seats of one **finished** game, Sherida and Wayne, about 9:03 to 9:11 am Denver time on
  30 October. Their match was nil on the iPad only; the iPhone had no orphans. Both devices count
  101 matches. Whether that game is still in History (so these were a stray extra copy of its
  seats) or is now missing its seats (so the sweep deleted part of a real game) is open (§5).
- **Both devices** show the same four strategy-3 groups (§4.3) and nothing else to repair.

### 4.2 Strategy 4 assumes the solo owner's id is their id everywhere

It keeps a Game Night match only if some participant's `playerID` has a solo local game on this
account. That holds while the owner's Game Night seat carries the same player id as their solo
games. If it ever doesn't (a seat recorded under another id, before linking for example), the
owner's own Game Night match is deleted, and the delete syncs. Not seen; recorded as the
assumption it rests on.

### 4.3 Four duplicate groups strategy 3 leaves alone

From V5's log on Pops's first device, 9 November 2026 (start times in Denver):

| Started | Players and scores | Why skipped |
|---|---|---|
| 7 Aug 2026, 20:38 | BurnTest 135, Wayne 251 | Every copy has `completedAt` before `startedAt` |
| 12 Aug 2026, 08:34 | BurnTest 235, Wayne 257 | Every copy has `completedAt` before `startedAt` |
| 6 Oct 2026, 17:04 | Sherida 207, Wayne 259 | `completedAt` spread over 20 minutes, or a copy without one |
| 28 Oct 2026, 17:14 | Sherida 219, Wayne 254 | `completedAt` spread over 20 minutes, or a copy without one |

Each group is one game stored more than once. Stats, Head-to-Head and House Records query
`MatchModel` rows, so each probably counts twice there, while the Players list counts once per id
(`34` 34.2). The two October groups are after 1.0, so the match-per-turn bug can't be their cause;
Game Night history sync is the likelier one.

### 4.4 Strategy 1 can keep a partial copy

Strategy 1 keeps a completed row with the latest `completedAt`. SyLib's readers take the row with
the most participants, since at Game Night every device on an account writes the finished match
under its one id, and one copy's seats may not have arrived. So strategy 1 could delete the full
copy, seats and all. Moot once the repair is retired (`34` §2.8, D-198): readers take the fullest row instead.

### 4.5 Game Night history sync, reviewed (9 November 2026)

Pops asked whether history sync deletes data or shares matches that don't belong. It does neither:
- **No deletes.** `GNHistoryStore.storeReceived` only inserts, and skips a received match that
  already exists by id or by fingerprint (`GNMatchIdentity.duplicateExists`), so it never
  reconciles or overwrites an existing row.
- **Only what the table shares.** A device offers and sends only completed Game Night matches in
  which every person participant is seated now (`manifestIDs`, `matches(for:)`), from its 40 newest
  completed matches, up to 20. The receiver keeps one only if it knows every person in it.
- **One gap in principle:** the table test counts only participants with a `playerID`. A Game Night
  match with a nil-id seat could be shared with a table that person isn't at. SyFive's Game Night
  seats carry player ids, so this isn't known to happen; noted, not tasked.

The Game Night deletes that can lose data are elsewhere: `abandonMatch` (`34` §2.7), strategy 1
(§4.4), strategy 4 (§4.2).

---

## 5. Open for Pops

**Pops's scope (9 November 2026):** the aim is to prevent further loss from here on. Matches
damaged before these fixes aren't pursued.

0. **The 30 October game (§4.1): answered, not pursued.** It is in neither device's History, so the
   iPad's two orphans were a real game's seats, its match already gone, and the sweep deleted them.
   It was a Game Night game (Pops). The likely cause is `abandonMatch` deleting a match that
   `onMatchComplete` had already stored as completed; `34` §2.7 and Task 34.8 close that path.
   **It may come back** (Pops, 9 Nov 2026): Sherida's device, on her own iCloud account, may still
   hold it. Game Night history sync (`GNHistoryStore`, at every match start and rematch) offers a
   peer each completed Game Night match whose every player is seated, from the newest 40 completed
   matches (`scanLimit`), up to 20 (`limit`). A Sherida-and-Wayne table would bring it back to
   Pops's account if it is still on her device and still in her newest 40. Best done after 34.8.
1. **`LegacyRematchRepair`: ruled.** The orphan sweep is retired (`34` §2.6, Task 34.6). The rest
   follows (`34` §2.8, D-198): SyFive's views take one row per id (Task 34.9), then the file is
   deleted (Task 34.10). `abandonMatch`'s deletes go to 34.7's lasting log (Task 34.8).
2. **Orphans blocking Delete, later:** SyLib's `deleteUnplayedPlayer` could ignore and remove a
   player's match-less participants (and SyFive's `everPlayed` ignore them), so a stray orphan never
   blocks Delete. With the sweep gone, a new orphan (from sync) now stays until its player is deleted.
3. **Strategy 4 (§4.2): moot,** retired with the rest (`34` §2.8).
4. **The four groups (§4.3): not pursued** (old data, Pops). They stay as they are.

---

## 6. `LegacyYahtzeeRepair`, for completeness (retired, `34` §2.9)

Repairs `ParticipantModel` rows broken by the yahtzee → yatzy field renames (CloudKit treats a
rename as a delete plus an add, so old records arrive with the new fields defaulted). Fix 1 renames
the `"yahtzee"` slot key in the score-entry blob. Fix 2 rebuilds `bonusPoints` as finalScore − card
sum − upper bonus, guarded by gap % 100 == 0. It deletes nothing and is idempotent. Still needed
while any device can sync a pre-rename record.

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.4 | 9 Nov 2026 | `LegacyRematchRepair` is being retired (`34` §2.8); §4.4 and §5's strategy 4 item are moot |
| 1.3 | 9 Nov 2026 | §4.4, strategy 1's keeper (fixed by `34` 34.9); §4.5, the Game Night history sync review |
| 1.2 | 9 Nov 2026 | §5: the 30 October game was a Game Night game; its likely cause and fix are `34` §2.7 |
| 1.1 | 9 Nov 2026 | §5: the 30 October game is in neither device's History; the sweep is retired and the repair's deletes are logged to a file (`34` §2.6) |
| 1.0 | 9 Nov 2026 | First version, from the code, Pops's history of the match-per-turn bug, and V5's first log |
