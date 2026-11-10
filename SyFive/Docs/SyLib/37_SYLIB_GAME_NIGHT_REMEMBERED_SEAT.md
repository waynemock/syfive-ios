# SyLib Game Night: remember this device's player and reseat them at the next Game Night

**Status:** **Closed** 9 November 2026: 37.1 to 37.3 done and checked; V1 to V4 pass (Pops, on multiple devices); D-202 filed in `00_DECISION_LEDGER.md`. Syderal adopts in its own session (§4). Version 1.3, 9 November 2026.

**Scope:** `sylib-swift` (SyLibGameNight) for 37.1; `syfive-ios` for 37.2. One project per session
(`00A` v1.8).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md` (v1.12),
`00B_SYFIVE_GUARDRAILS.md` (v1.4), this document, SyLib `Docs/GAME_NIGHT.md`. `00A` §6: the session's
row goes at the top of §6. §7: `00B`'s pinned commands. §8: fix your own errors and warnings.

---

## 1. Why

Pops, 9 November 2026: at every Game Night each device has to claim its seat again, picking the same
player as last time. The device should remember the last player it seated and seat them again when
a new Game Night reaches the table. Stored on the device only.

**How seating works today** (read 9 November 2026):
- Both apps seat a device's player through `GameNightSession.claimSeat(displayName:displayInitials:
  themeID:playerID:isLocal:)` (`GameNightSession.swift` 854), from SyLib's `SeatClaimSheet`, opened by
  `GameNightTableView`'s "Claim a seat" (SyFive `TableSettingView`; Syderal `GameNightTableSheet`).
- The session already keeps small per-device facts in `UserDefaults` under the app's `keyPrefix`
  (`"\(keyPrefix).gn.…"`, 221–243; SyFive's prefix is `"syfive"`, Syderal's `"syderal"`).
- A host seats at once (`addSeat`, broadcast). A guest adds its seat locally, sends `seatClaim`, and
  keeps it as `pendingSeatClaim` until the host's `tableState` lists it (713–745).
- Once seated there is no way to change who sits there: "Claim a seat" hides, a host's remove
  (`removeSeat`, 982) clears the seat, and a guest's remove leaves the whole session
  (`GameNightTableView` 80–83). `addSeat`'s upsert by `seatClaimID` (994–1000) updates name, initials
  and theme, not `playerID`.

---

## 2. Locked decisions (Pops, 9 November 2026)

**2.1 The device remembers the last player it claimed a seat for** (D-202).
- **What:** the `playerID` of this device's own claim, stored as `"\(keyPrefix).gn.lastSeatPlayerID"`
  in `UserDefaults.standard`. Local to the device; it doesn't sync.
- **When:** every `claimSeat` with a non-nil `playerID`, and every seat change (2.3). Seats a host adds
  for players no device owns (`addHostedSeat`, Syderal's computer players) are never remembered.
- **Forgotten** when this device removes its own seat at the table (rec.): removing it says "not me
  this time". Only the table's remove control forgets; **Leave** doesn't (v1.1). Leaving Game Night
  before it starts is not "not me".

**2.2 Seated automatically, no tap** (Pops). When a new Game Night reaches the table
(`phase == .settingTable`) and this device has no seat:
- **Host:** at once, when the session is configured as host.
- **Guest:** after the first `tableState` from the host, so the seats already taken are known.
- **Only if** the app can still find the player (2.4) and no seat at the table already has that
  `playerID`. Otherwise nothing happens and "Claim a seat" shows as now.
- **Once per session activation.** Never on the resume path (a match in progress skips the table),
  and never when the device already has a seat or a pending claim.

**2.3 A seated device can change its player.** Auto-seating means a different person may pick up the
device. Its own seat row gets a **Change** action, which opens the same picker; choosing a player
updates this device's seat in place (same `seatClaimID`, new `playerID`, name, initials and theme),
for host and guest alike. A guest's update travels as the existing `seatClaim` message, and the
host's upsert by `seatClaimID` now also updates `playerID`. No new message, so no protocol change.

**2.4 The app supplies the player.** SyLib stores only the id. The app gives the session a lookup,
`(UUID) -> SeatRosterEntry?`, returning the player's current name, initials and theme, or nil for a
player archived, deleted or unknown. So a rename or re-theme since last time shows correctly.

**2.5 Already seated elsewhere: fall back to the picker** (Pops). If another device has already
seated that player (Pops's iPhone and iPad both remembering Wayne), this device seats no one and
"Claim a seat" shows, without that player in the list (as now).
- **Accepted:** two guests that receive the same `tableState` and auto-claim the same player in the
  same instant can both be seated. Rare; the host can remove one. Refusing duplicate claims at the
  host was considered and not ruled (Pops: fall back only).

### 2.6 Considered and excluded

| Excluded | Why |
|---|---|
| A one-tap suggestion in the picker | Pops chose automatic seating |
| Syncing the remembered player through iCloud | Each device is someone's own; Pops: stored locally |
| The host refusing a second seat for one player id | Pops: fall back to the picker only (2.5) |
| Remembering hosted seats (`addHostedSeat`) | They belong to the table, not the device |

---

## 3. Tasks

### Task 37.1 · SyLib: remember, reseat, and change a seat (§2)

- **A SyLib session.** Inputs: §1–2; SyLib `Docs/GAME_NIGHT.md`; `GameNightSession.swift`,
  `Views/GameNightTableView.swift`, `Views/SeatRosterEntry.swift`.
- **`GameNightSession`:**
  - `public private(set) var rememberedSeatPlayerID: UUID?`, read from and written to
    `"\(keyPrefix).gn.lastSeatPlayerID"`.
  - `public var rememberedSeatLookup: ((UUID) -> SeatRosterEntry?)?`, set by the app (nil: no
    auto-seat).
  - `claimSeat` records `playerID` when non-nil (2.1).
  - Auto-seat (2.2): one internal function, run once per activation, from the host's configure path
    and from a guest's first accepted `tableState`. It checks `phase == .settingTable`,
    `localSeatClaimID == nil`, `pendingSeatClaim == nil`, a remembered id, the lookup's entry, and no
    seat with that `playerID`; then calls `claimSeat` with the entry's values. Logs one `info` line
    either way (seated, or why not).
  - `public func changeLocalSeat(to entry: SeatRosterEntry)` (2.3): with a `localSeatClaimID`, sends
    or applies a `SeatClaimPayload` under that same id with the entry's values, and records the id.
    Host: upsert and broadcast. Guest: upsert locally, `pendingSeatClaim`, send `seatClaim`.
  - `addSeat`'s upsert by `seatClaimID` also updates `playerID`.
  - Removing this device's own seat forgets the remembered id (2.1): the host's `removeSeat` of its
    own claim, and a guest's own-seat remove before it leaves.
- **`GameNightTableView`:** this device's own seat row, during `.settingTable`, gets a **Change**
  action calling a new `onChangeSeat` closure; the session-based initialiser opens the app's picker
  through it. A new init parameter with a default, so existing callers compile.
- **Docs:** `GAME_NIGHT.md` gains a "Remembered seat" section: the key, when it is written and
  forgotten, the lookup, when auto-seat runs and doesn't, and `changeLocalSeat`.
- **Tests, in SyLib:** record on claim and not on a hosted seat; auto-seat runs for a host with no
  seat, and not when the player is seated, the lookup returns nil, or a claim exists; a guest waits
  for `tableState`; `changeLocalSeat` keeps the `seatClaimID` and changes `playerID`; the upsert
  updates `playerID`; removing one's own seat forgets the id. Use a test `keyPrefix` and clear its key.
- **Must not touch:** the wire protocol (no new message kinds, no version bump); `addHostedSeat`;
  match start and the resume path; SyFive; Syderal.
- **Done when:** SyLib's suite passes at its baseline plus the new tests (`00B` §5.3, from the result
  bundle); Syderal builds and its suite passes unchanged (§5.4: the new init parameter has a
  default); no new warnings; the row is at the top of §6.

### Task 37.2 · SyLib: only the remove control forgets (§2.1, v1.1)

- **Found checking 37.1:** 37.1 forgets the remembered player inside `leaveSession()` while
  `phase == .settingTable`, because the table's remove control calls `leaveSession()` for a guest.
  But SyFive's **Leave** button calls `leaveSession()` too (`TableSettingView`, a guest at the
  table), so leaving Game Night before it starts would forget the player. Only removing one's own
  seat should.
- **Change, SyLibGameNight:**
  - `GameNightSession.leaveSession()` no longer forgets.
  - `forgetRememberedSeat()` becomes `public` (doc comment: for the table's remove control).
  - `GameNightTableView`'s session initialiser, `onRemoveSeat`'s guest branch, calls
    `session.forgetRememberedSeat()` before `session.leaveSession()`. The host branch is unchanged:
    `removeSeat` of its own claim already forgets.
  - `GAME_NIGHT.md`'s "Remembered seat" section says Leave doesn't forget.
- **Tests:** 37.1's `removingO…` test adjusted only if it relied on `leaveSession()` forgetting; + 1:
  `leaveSession()` at the table keeps the remembered player.
- **Must not touch:** anything else in 37.1; SyFive; Syderal.
- **Done when:** SyLib's suite passes at 37.1's total + 1 (1595 tests), from the result bundle;
  Syderal unchanged; no new warnings; the row is at the top of §6.

### Task 37.3 · SyFive adopts it (§2)

- **Depends on 37.1 and 37.2.**
- **Change:**
  - Where SyFive configures its `GameNightSession` (`GameNightController`), set
    `rememberedSeatLookup`: fetch the `PlayerModel` by id, skip it if archived, and return a
    `SeatRosterEntry` built as `SyFiveSeatClaimSheet` builds them (`GameNightScreens.swift` 130–141).
    It also returns nil while `gameNight.coordinator.hasPendingHostResume` is true: the host's
    auto-seat runs when the session is configured, before a resume replaces the seats (37.1's
    report and its doc comment). Set it where SyFive already wires the session's closures with its
    model context (`ContentView`, beside `gameNight.onMatchComplete`), unless 37.1's API points
    elsewhere.
  - `SyFiveGameNightTableView` (`GameNightScreens.swift`) builds the table with the **full**
    initialiser and its own closures, so it gets neither of 37.1–37.2's session-initialiser behaviors
    for free (37.2's report):
    - it takes an `onChangeSeat: (() -> Void)?` and passes it to `GameNightTableView`;
    - its `onRemoveSeat` guest branch calls `gameNight.session.forgetRememberedSeat()` before
      `gameNight.leaveSession()` (the host branch's `removeSeat` already forgets).
    `TableSettingView`'s **Leave** stays as it is: it doesn't forget.
  - `TableSettingView`: pass `onChangeSeat`, opening the same `SyFiveSeatClaimSheet` in a change mode
    whose `onClaim` calls `changeLocalSeat(to:)` instead of `claimSeat`; its New Player does the same
    with the new entry. Change sits beside the existing `SeatEditButton`, which stays.
- **Tests:** + 1: the lookup returns an entry for an active player and nil for an archived or missing
  one (in-memory store).
- **Must not touch:** `GameNightController`'s other session wiring; SyLib.
- **Done when:** the build passes with no new warnings; `00B`'s pinned command passes at its baseline
  + 1, from the result bundle; the row is at the top of §6; Pops checks V1 to V4.

---

## 4. Syderal

Adopts in its own session, briefed by Syderal's `Docs/Requirements/POST_MVP/29_GAME_NIGHT_REMEMBERED_SEAT.md` (written 9 November 2026): set `rememberedSeatLookup` from its
`RecordsStore` roster, and pass `onChangeSeat` in `GameNightTableSheet`. Until then Syderal behaves
as today (no lookup, no auto-seat; Change shows only when `onChangeSeat` is passed).

---

## 5. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | Two devices: claim Wayne on one and Sherida on the other; end Game Night; start a new one | Each device is seated as before, with no tap, host and guest alike |
| V2 | On one device, Change to another player; end and start again | The device is reseated as the new player |
| V3 | Both of Pops's devices remember Wayne; start Game Night with both | One is seated as Wayne; the other shows "Claim a seat" without Wayne |
| V4 | Remove your own seat at the table (host), or archive the remembered player; start again | No auto-seat; "Claim a seat" shows |

## 6. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| V1–V4 | 9 Nov 2026 | **pass** (Pops, on multiple devices) | — | Reseat with no tap, host and guest; Change remembered; one of two devices remembering the same player falls back to the picker; removing one's own seat forgets, Leave doesn't |
| 37.3 | 9 Nov 2026 | complete (the agent); **checked by Claude against the tree**: the lookup (active players only, nil during a host resume), `onChangeSeat` passed through the full initialiser, the guest remove forgets, Change mode in the claim sheet; + 1 test | Before: `Passed`, 27 tests (30 runs), 27 passed, 0 failed, 0 skipped. After: `Passed`, 28 tests (31 runs), 28 passed, 0 failed, 0 skipped: + `RememberedSeatLookupTests/lookupFindsOnlyAnActivePlayer()`, none removed. Totals from `-resultBundlePath` bundles read with `xcresulttool` (`00B` §5). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** `Views/ContentView+GameNight.swift`: internal `static func rememberedSeatEntry(for:in:colorScheme:hostResumePending:) -> SeatRosterEntry?`. It returns nil while `hostResumePending`; otherwise the first non-archived `PlayerModel` row with that id, built as `SyFiveSeatClaimSheet` builds entries; nil when there is none. `Views/ContentView.swift`: `gameNight.session.rememberedSeatLookup` set **in `.onAppear`** (beside `onCommentarySuppressedChanged`), capturing `modelContext`, `colorScheme` and `gameNight`, and reading `gameNight.coordinator.hasPendingHostResume` live on each call. `App/GameNight/Views/GameNightScreens.swift`: `SyFiveGameNightTableView` takes `onChangeSeat: (() -> Void)? = nil` and passes it on; its `onRemoveSeat` guest branch calls `gameNight.session.forgetRememberedSeat()` before `gameNight.leaveSession()`; the host branch is unchanged. `SyFiveSeatClaimSheet` gains `var changesSeat = false`; in change mode `onClaim`, which `SeatClaimSheet` also calls with New Player's created entry, calls `gameNight.session.changeLocalSeat(to:)` instead of `claimSeat`. `App/GameNight/Views/TableSettingView.swift`: `onChangeSeat: { showsSeatChange = true }` and a second `.sheet` with `SyFiveSeatClaimSheet(…, changesSeat: true)`. Leave, `SeatEditButton`, `GameNightController` and SyLib untouched. New `SyFiveTests/RememberedSeatLookupTests.swift` (in-memory store: active Ada gives her entry; archived Bo, a missing id, and Ada during a pending resume give nil). Plus this row. **Fix under `00A` §8:** my test file first lacked `import SwiftUI` and `import SyLibGameNight` (build errors); added. **Build:** `BuildProject` passed before (0 warnings); after, those import errors, fixed; then passed with 0 warnings (test targets included); 0 `warning:` lines in the test log. **Git (read-only):** `git status --short` ×2, `git diff --stat HEAD -- Docs/Requirements/`, `git diff --stat`. **Report:** (1) **Where the lookup is set.** Not beside `gameNight.onMatchComplete`: those hooks are set in `.onChange(of: sessionActivationCount)`, which fires after `configureSession` returns, while the host's auto-seat (37.1) runs inside it. Set there, the lookup would be nil for the first Game Night after each launch, so the host wouldn't auto-seat (V1 on a fresh launch), and a guest's first `tableState` would race it. 37 §3 allows another place ("unless 37.1's API points elsewhere"). Set once in `.onAppear`, still in ContentView with its model context; the resume guard is read on each call, so it still holds. (2) Auto-seat calls `session.claimSeat` directly, so it skips `GameNightController.claimSeat`'s third `beginProximityRanging()` call (D-GNP-025). The other two call sites still run: host at activation, guest on `tableState`. Noted, not changed. (3) The `colorScheme` captured at `.onAppear` only colors the entry's `accentColor`, which the session doesn't use when seating. (4) Change mode's roster leaves out every seated player, this device's current one included, as the claim sheet's does. V1 to V4 are Pops's |
| 37.2 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: `leaveSession()` no longer forgets, `forgetRememberedSeat()` is public, the session initialiser's guest remove forgets first; + 1 test, Syderal unchanged. Report (1) folded into 37.3 (v1.2) (SyLib session) | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before: `Passed`, 1594 tests (1669 runs), 1593 passed, 0 failed, 1 skipped. After: `Passed`, 1595 tests (1670 runs), 1594 passed, 0 failed, 1 skipped: + `GameNightRememberedSeatTests/leavingAtTheTableKeepsTheRememberedPlayer()`, none removed. **Syderal** (`00B` §5.4, from `syderal-ios/Syderal`). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. All totals from `-resultBundlePath` bundles read with `xcresulttool`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files (sylib-swift):** `Sources/SyLibGameNight/GameNightSession.swift`: 37.1's forget line and its comment removed from `leaveSession()`; `forgetRememberedSeat()` is now `public`, with a doc comment (for the table's remove control; Leave doesn't call it; the host's own `removeSeat` calls it itself). `Views/GameNightTableView.swift`: in the session initializer's `onRemoveSeat`, the guest branch calls `session.forgetRememberedSeat()` then `session.leaveSession()`, with a comment; the host branch is unchanged; its doc bullet now says so. `Docs/GAME_NIGHT.md`: "Remembered seat"'s *Forgotten* paragraph rewritten (only the remove control forgets; Leave, `leaveSession()` and `leaveSessionOnThisDevice()`, doesn't; an app on the full initializer calls `forgetRememberedSeat()` in its own guest branch); `forgetRememberedSeat()` added to the member table; the `leaveSession()` row says it keeps it; step 5's initializer description and the full-initializer example's guest branch call `forgetRememberedSeat()` first. `Tests/…/GameNightRememberedSeatTests.swift`: **37.1's `removingOnesOwnSeatForgetsThePlayer` adjusted, because it relied on `leaveSession()` forgetting.** Its guest part now removes through the session initializer's `onRemoveSeat` (and also expects `localSeatClaimID` nil); the host and past-the-table parts are unchanged. + `leavingAtTheTableKeepsTheRememberedPlayer`. Plus this row. Nothing else in 37.1 changed; SyFive and Syderal not edited. **Warnings:** 0 `: warning:` lines in all four logs. **Git (read-only):** syfive-ios `git diff --stat HEAD -- Docs/Requirements/`; sylib-swift `git status --short`, `git diff --stat -- Sources Docs Tests`; syderal-ios `git status --short` ×2. **Report:** (1) **37.3 needs one more line.** SyFive builds its table with the full initializer and its own `onRemoveSeat` (`SyFiveGameNightTableView`, `GameNightScreens.swift`). After this task its guest remove won't forget unless that guest branch calls `gameNight.session.forgetRememberedSeat()` before `leaveSession()`. 37.3 doesn't say so yet (V4 depends on it for a guest). (2) syderal-ios has a third untracked doc of Pops's (`29_GAME_NIGHT_REMEMBERED_SEAT.md`), left alone. Syderal uses the session initializer, so it gets the guest forget once it adopts |
| 37.1 | 9 Nov 2026 | complete (SyLib session); **checked by Claude against the SyLib tree**: remember, auto-seat (host at configure, guest on first `tableState`, once per activation), `changeLocalSeat`, the `playerID` upsert and Change all as ruled. One fix: forgetting in `leaveSession()` also catches SyFive's Leave, Task 37.2. Reports (a)–(c) accepted (SyLib session), with two rulings by Pops in-session (below) | **SyLib** (`00B` §5.3, `xcodebuild test -scheme SyLib-Package` from `sylib-swift`). Before: `Passed`, 1584 tests (1659 runs), 1583 passed, 0 failed, 1 skipped. After: `Passed`, 1594 tests (1669 runs), 1593 passed, 0 failed, 1 skipped: + 10, all in `GameNightRememberedSeatTests`: `aClaimIsRememberedAndAHostedSeatIsNot`, `aHostWithNoSeatIsAutoSeated`, `autoSeatIsTriedOncePerActivation`, `autoSeatSeatsNoOneWhenItShouldNot`, `aGuestWaitsForTableState`, `aGuestWhosePlayerIsSeatedClaimsNothing`, `changeLocalSeatKeepsTheClaimAndChangesThePlayer`, `theUpsertUpdatesPlayerID`, `removingOnesOwnSeatForgetsThePlayer`, `theTableViewPassesOnChangeSeat`. None removed; every existing test unchanged and passing. **Syderal** (`00B` §5.4, `xcodebuild test -project Syderal.xcodeproj -scheme Syderal` from `syderal-ios/Syderal`). Before and after: `Passed`, 915 tests (973 runs), 911 passed, 0 failed, 4 skipped; identical case list. All totals from `-resultBundlePath` bundles read with `xcresulttool`. Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files (sylib-swift):** `Sources/SyLibGameNight/GameNightSession.swift`. `public private(set) var rememberedSeatPlayerID: UUID?`, read at `init` from `"\(keyPrefix).gn.lastSeatPlayerID"`; `public var rememberedSeatLookup: ((UUID) -> SeatRosterEntry?)?`. `claimSeat` records a non-nil `playerID`. Internal `autoSeatIfRemembered()` runs once per activation (a flag reset in `configureSession`), from the host's branch of `configureSession` and from `handleTableState` on a guest's first accepted `tableState` (not one rejected on version). Its checks are 37 §2.2's, and it logs one info line either way. `public func changeLocalSeat(to:)` keeps `localSeatClaimID` and records the new id; the host upserts and broadcasts; a guest upserts, sets `pendingSeatClaim` and sends `seatClaim`. `addSeat`'s upsert also sets `playerID`. The host's `removeSeat` of its own claim, and `leaveSession()` at `.settingTable` with a seat, forget the id. `Views/GameNightTableView.swift`: `onChangeSeat: (() -> Void)? = nil` on both initializers (the full one after `onRemoveSeat`), shown as a **Change** button (`.subheadline`, `.borderless`) on this device's own row during `.settingTable`, only when given. `Docs/GAME_NIGHT.md`: new "Remembered seat" section under Seats (key, written and forgotten, lookup, when auto-seat runs and doesn't, `changeLocalSeat`, the resume-pending rule, Syderal adoption). The Seats table, `removeSeat`, `leaveSession`, the UserDefaults keys table (now four) and the table view's parameters and description updated to match. New `Tests/SyLibTests/SyLibGameNight/GameNightRememberedSeatTests.swift` (Swift Testing, `@MainActor`, a fresh key prefix per session, `removeTestDefaults` in defers). Plus this row. Wire protocol (no kind, no version), `addHostedSeat`, match start and the resume path untouched; SyFive and Syderal not edited. **Warnings:** 0 `: warning:` lines in all four logs (the only `warning:` text is appintentsmetadataprocessor's notice, present before). **Git (read-only):** syfive-ios `git diff --stat HEAD -- Docs/Requirements/`; sylib-swift `git status --short` ×2, `git branch --list`, `git log --oneline -2`, `git diff --stat`; syderal-ios `git status --short` ×2. **Rulings (Pops, in-session):** (1) **Resume path.** On a host re-host, `configureSession` tears down to `.settingTable` with no seats before the app's `consumePendingHostResume()` → `resumeAsHost` (`GameNightMatchCoordinator` 267–309, 378–389), so 37's host trigger would fire mid-resume, against §2.2. Built as written; GAME_NIGHT.md says the lookup must return nil while `coordinator.hasPendingHostResume`. **37.2 needs that check in SyFive's lookup**, and its spec doesn't say so yet. (2) **Guest forget** is in `leaveSession()`, only at `.settingTable` with a seat, so SyFive's full-initializer wiring is covered and a mid-match `leaveSessionOnThisDevice()` keeps the id. **Report:** (a) `changeLocalSeat` also guards `phase == .settingTable`, as `updateOwnSeat` does; 37 didn't say. (b) `claimSeat` records every non-nil `playerID`, an additional `isLocal: true` seat's included, as 37 §2.1 reads. (c) A guest's change, if its `seatClaim` is lost, isn't resent: the next `tableState` lists the claim id (with the old player), which counts as acknowledged. The host's broadcast after applying a delivered change corrects every device. (d) sylib-swift is on `main`; 34.12 and 34.14 remain staged; this task's files are unstaged or untracked, for Pops |

## 7. Ledger row (filed 9 November 2026)

| ID | Ruling | Source |
|---|---|---|
| D-202 | **A device remembers the last player it seated at Game Night and seats them again**, automatically, when a new Game Night reaches the table: stored locally (`"<prefix>.gn.lastSeatPlayerID"`), the app supplying the current player, never when that player is already seated (then the picker shows), forgotten when the device removes its own seat. A seated device can **Change** its player in place. In SyLibGameNight, for every app. | `37 §2` (Pops, 9 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.3 | 9 Nov 2026 | Closed: V1–V4 pass; D-202 filed |
| 1.2 | 9 Nov 2026 | 37.2 checked. 37.3: SyFive's table uses the full initialiser, so it passes `onChangeSeat` and its guest remove calls `forgetRememberedSeat()` (37.2's report) |
| 1.1 | 9 Nov 2026 | 37.1 checked. Task 37.2 (SyLib): Leave no longer forgets the remembered player, only the remove control does; SyFive's adoption is now 37.3, with the lookup returning nil during a pending host resume |
| 1.0 | 9 Nov 2026 | First version |
