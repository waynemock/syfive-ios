# Game Night Phase 1 — split the controller inside SyFive

**Scope:** `SyFive` only. **No package changes. No new target. Nothing becomes
`public`.**

This phase finds the seam between transport and game rules while everything is
still app-side, revertable with one `git revert`, and testable against an app
whose correct behavior you already know. Phase 2 moves the result into
`SyLibGameNight`, and by then it should be a file move.

**Required reading:** `03_GAMENIGHT_BEHAVIOR_INVENTORY.md`. Its 27 entries are the
test suite — GroupActivities cannot be unit tested. Entry numbers are referenced
throughout.

---

## ⚠️ What this phase must not change

This code took a long time to get right and every flag in it is a bug someone
already paid for.

- **No behavior changes.** Not one. If something looks wrong, report it — do not
  fix it in this commit.
- **No wire format changes.** No new message kinds, no payload fields added or
  removed, no `currentProtocolVersion` bump.
- **No `UserDefaults` key format changes.** See §3.
- **No logic "cleanup."** Several orderings look arbitrary and are load-bearing;
  §2 lists them. If you find yourself reordering statements, stop.
- **No renaming** of existing types, methods, or observable properties that views
  bind to.

The success condition is that a diff of behavior is empty and only the file
layout changed.

---

## 1. The split

`GameNightController.swift` (≈1,250 lines) becomes two types in the same module,
in `App/GameNight/`:

**`GameNightSession.swift`** — knows about sessions, seats, and envelopes.
Knows nothing about matches, scores, dice, or commentary.

**`GameNightController.swift`** — everything else. Holds a `GameNightSession`
and remains the type views bind to.

### Moves to `GameNightSession`

| Area | Members |
|---|---|
| GroupActivities | `session`, `messenger`, `messageListenTask`, `listenForSessions()`, `prepareAsHost()`, `cancelHostPreparation()`, `configureSession(_:)`, `endSession()`, `leaveSession()`, `tearDownSession()` |
| Role & election | `role`, `pendingHostSessionActivation`, the `gnIsHost` read/write/remove |
| Session state | `isSessionActive`, `isSessionPending`, `isEligibleForGroupSession`, `sessionActivationCount`, `sessionEndedDuringPlay`, `clearSessionEndedFlag()`, `groupStateObserver` |
| Transport | `send(_:payload:)`, `listenForMessages(messenger:)`, envelope decode and kind dispatch |
| Handshake | `sendHello()`, `handleHello(_:from:)`, `versionMismatchedIDs`, `versionMismatchedCount`, `lastMismatchedProtocolVersion`, `hostVersionMismatch`, `clearHostVersionMismatch()` |
| Seats | `seats`, `phase`, `claimSeat(...)`, `handleSeatClaim`, `handleSeatRelease`, `addSeat`, `removeSeat`, `localSeatClaimID`, `pendingSeatClaim`, `broadcastTableState()`, `handleTableState` |
| Guest reconnect | `isGuestAwaitingReconnect`, `prepareForGuestReconnect(matchID:)`, the `gnParticipantID` read/write |
| Interruption | `isAudioInterrupted`, `sessionDroppedDuringInterruption`, `interruptionRecoveryTask`, `startObservingAudioInterruptions()`, `handleAudioInterruption(_:)`, `cancelInterruptionRecovery()` |
| Diagnostics | the `GameNightLogBuffer.shared.startSession()` / `flushToDisk()` calls |

### Stays in `GameNightController`

Everything touching `matchController` (~35 sites), all `Match` / `Participant`
payloads (`matchStart`, `matchState`, `matchComplete`, `matchAbandoned`,
rematch), roll theater (`rollBegan`, `rollResult`, `holdToggled`,
`DiceRollRecipe`, `spectatorRollInProgress`, `pendingAuthoritativeResult`),
scoring (`scoreChosen`, `YatzyCategory`, `proposeScore`,
`detectAndAnnounceOpponentScore`), undo, commentary, history sync, proxy mode,
`sessionMatchID` / `sessionGameID` / `localParticipantID`, and every `on*` hook.

### The message routing seam

`GameNightSession` owns the receive loop and handles the four kinds it
understands: `hello`, `tableState`, `seatClaim`, `seatRelease`. Everything else
is forwarded:

```swift
/// Called for message kinds the session doesn't handle itself.
var onAppMessage: ((GameNightMessageKind, GameNightEnvelope, UUID) -> Void)?
```

Unknown kind strings are still dropped inside the session (inventory 5.2) — they
never reach the controller.

⚠️ **`TableStatePayload` is mixed and stays whole in this phase.** It carries
`phase` and `seats` (session) alongside `commentaryEnabled`, `commentaryPackID`,
`commentaryLevelRaw` (controller). Splitting it is a wire change and does not
belong here. Instead the session applies its own fields and hands the decoded
envelope on:

```swift
/// Called after the session applies phase and seats, so the app can read its
/// own fields from the same payload.
var onTableStateReceived: ((GameNightEnvelope) -> Void)?
```

Note it in your report as a known wart for Phase 2. Do not fix it now.

`phase` lives on the session but the controller sets it — `broadcastMatchStart`
sets `.inProgress`, completion sets `.completed`. Make it settable by the
controller; do not add a state machine.

---

## 2. Orderings that are load-bearing

These look arbitrary and are not. Preserve each exactly.

**`tearDownSession()` reads `session?.id` *before* clearing `session`.** The
`removeGnIsHost(for:)` call must happen while the reference is still live, or the
host flag leaks and a later join wrongly self-promotes. (Inventory 2.2.)

**`GameNightLogBuffer.shared.flushToDisk()` is the *first* statement in
`tearDownSession()`**, before any state is cleared, so the log captures state at
failure time. (Inventory 8.1.)

**`GameNightLogBuffer.shared.startSession()` is the *last* statement in
`configureSession`.** (Inventory 8.1.)

**`configureSession` returns early on `session?.id == incomingSession.id`.**
Without it, a redelivered session tears down a live table. (Inventory 1.5.)

**`cancelInterruptionRecovery()` is called from `configureSession` before
teardown**, and that call is what distinguishes "recovered" from "genuinely
dropped." (Inventory 3.1, 3.2.)

**The 6-second interruption window was measured, not chosen.** Do not round it.
(Inventory 3.2.)

**`isRematch` is computed one line before `sessionMatchID` is reassigned**
(`handleMatchStart`, lines 786–787). This stays in the controller, but if you
touch that method at all, the ordering must survive — reassigning first silently
breaks rematch detection and destroys the previous match's record.
(Inventory 7.2. This one has no error path; the symptom is a missing match in
history days later.)

**`pendingSeatClaim` is resent when the next `tableState` doesn't reflect it**,
and `effectiveClaimID` falls back to it when `localSeatClaimID` is cleared. Both
halves are needed. (Inventory 4.2, 4.3 — the failure mode was a dead-end state
recoverable only by restarting Game Night.)

---

## 3. `UserDefaults` key prefix

The three keys move to `GameNightSession` and gain a configurable app prefix, so
two Syzygy apps on one device don't collide:

```swift
GameNightSession(keyPrefix: "syfive")
```

⚠️ **The key format must not change.** Today:

```
syfive.gn.host.{sessionID}
syfive.gn.participantID.{matchID}
syfive.gn.wasHost.{matchID}
```

With `keyPrefix: "syfive"` and the format `"\(keyPrefix).gn.host.\(id)"`, the
generated strings are byte-identical. Verify that by string comparison before
you finish — a changed format orphans every existing value, and a host mid-session
loses its role on the update that ships this refactor.

`gnWasHost` is read by `ContentView+GameNight.swift` for the host-reconnect
offer. It moves with the others; update that call site.

---

## 4. Task order

**T1 — extract with no seam.** Create `GameNightSession` and move the §1 members
verbatim. Give `GameNightController` a `let session = GameNightSession(...)` and
forward every moved member as a one-line passthrough, so no view or call site
changes yet. Build.

**✅ C1:** compiles; no view file modified; behavior untouched.

**T2 — wire the routing seam.** Move the receive loop into the session; add
`onAppMessage` and `onTableStateReceived`; the controller installs both. Build.

**✅ C2:** compiles. Then verify inventory **1.3, 1.4, 4.1, 5.1, 5.2** on two
devices — the message path is now split and these are the entries that exercise it.

**T3 — key prefix.** Per §3, including the byte-identical check.

**✅ C3:** verify **2.1, 2.2, 2.3** on device. 2.1 requires force-quitting the
host mid-session and confirming it resumes as host with no prompt.

**T4 — remove the passthroughs.** Update views and call sites to reach
`gameNight.session.isSessionActive` (or expose deliberate forwarding properties
where a view reads something constantly). Prefer a small number of forwarded
properties over rewriting many view files; churn in views is risk without benefit.

**✅ C4:** full inventory sweep, all 27 entries, sign-off table completed.

---

## 5. Report

- Final line counts for both files.
- The `TableStatePayload` wart, and anything else that resisted the split — those
  are Phase 2's real agenda.
- Any member you couldn't place cleanly on one side, and why.
- Any behavior you believed was wrong but left alone.
- Confirmation that the three `UserDefaults` key strings are byte-identical.

---

## 6. Definition of done

- [ ] `GameNightSession.swift` and `GameNightController.swift` both in
      `App/GameNight/`, neither `public`.
- [ ] No new target, no package change, no wire format change, no
      `currentProtocolVersion` bump.
- [ ] Every ordering in §2 preserved.
- [ ] `keyPrefix` configurable; the three key strings byte-identical to before.
- [ ] `GameNightSession` contains no reference to `Match`, `Participant`,
      `YatzyCategory`, `DiceRollRecipe`, `MatchController`, or any Commentary
      type. Grep for each and confirm zero hits.
- [ ] All 27 inventory entries verified on two physical devices; sign-off table
      filled in.
