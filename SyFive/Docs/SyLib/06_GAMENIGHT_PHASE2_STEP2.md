# Game Night Phase 2, Step 2 — move `GameNightSession` into the package

**Scope:** `sylib-swift` (`SyLibGameNight`) and `SyFive`.
**Prerequisite:** Step 1 shipped and verified — the protocol types are already in
the package, transport is at version 2, `TableStatePayload` carries
`appSettings: Data?`.
**Not in this step:** the four Game Night views. They stay in SyFive until
Phase 3.

This should be a pure move. Two things block that and have to be designed first
(§1, §2); everything after is re-homing plus access control.

**Required reading:** `GameNight-Behavior-Inventory.md`.

---

## ⚠️ No behavior changes

Every entry in the inventory must behave identically afterwards. The two
highest-risk items:

- **2.1 — host survives force-quit and relaunch.** Depends entirely on
  `UserDefaults` keys resolving to byte-identical strings. Verify by string
  comparison, not by reasoning about it.
- **2.2 — `tearDownSession` reads `session?.id` before clearing `session`.**
  Preserve the ordering. The comment explaining it must survive the move.

Do not reorder statements, rename members, or "clean up" logic. The 6-second and
10-second windows are measured values — do not round them.

---

## 1. Blocker: `role` is typed on the controller

```swift
var role: GameNightController.Role = .guest      // GameNightSession.swift:20
```

`Role` is a nested enum on `GameNightController`, which stays in SyFive. The
package cannot reference it.

Move it to the package as a top-level type:

```swift
public enum GameNightRole: Sendable {
    case host
    case guest
    case spectator   // joined after the match started; no seat, read-only
}
```

In SyFive, replace the nested enum with `typealias Role = GameNightRole` on
`GameNightController` so existing call sites (`gameNight.role == .host`, the
`Role` references in views) keep compiling unchanged. Do not do a
find-and-replace across the app.

The controller writes `session.role = .spectator` (`GameNightController:446`), so
`role` needs a public setter.

## 2. Blocker: `GameNightActivity` cannot be shared

```swift
struct GameNightActivity: GroupActivity, Codable {
    static let activityIdentifier = "com.syzygy.syfive.gamenight"
    var metadata: GroupActivityMetadata { … m.title = "SyFive Game Night" … }
}
```

`activityIdentifier` is a `static let` on the conforming type. It is not
instance-configurable, so the package cannot own one activity type with a
per-app identifier — and it must not own a *shared* identifier, because then a
SyFive user could be offered a seat at a Sideral table.

**Make the session generic over the activity type:**

```swift
@MainActor @Observable
public final class GameNightSession<Activity: GroupActivity> {
    private var session: GroupSession<Activity>?
    …
}
```

`listenForSessions()` iterates `Activity.sessions()`; `configureSession` takes
`GroupSession<Activity>`.

**`GameNightActivity` stays in SyFive**, unchanged — same identifier, same title.
Do not alter either; the identifier is registered with the system and the title
appears in the FaceTime UI. Delete its vestigial `import SyLibScoring`.

SyFive's controller becomes:

```swift
let session = GameNightSession<GameNightActivity>(keyPrefix: "syfive")
```

Sideral later declares its own activity with its own identifier and title.

Add a doc comment on the generic parameter explaining that each app supplies its
own `GroupActivity` so sessions from different apps cannot cross-join.

## 3. `GameNightLogBuffer` moves as-is

No app-specific strings — it writes `<Documents>/gnlogs/current.log`, renamed to
`<matchID>.log`. Move it and make `shared`, `startSession()`,
`associateMatch(matchID:)`, `flushToDisk()`, `hasLog(for:)`, and
`logContent(for:)` public.

Five SyFive files call it outside the Game Night folder —
`ContentView+Persistence:169`, `MatchDetailView:64`, `GameNightLogSheet:15`,
`UnfinishedMatchDetailView:64` and `:90` — and need `import SyLibGameNight`.

Note in your report that `gnlogs/` is now shared between any Syzygy apps on the
device. Filenames are match UUIDs so collision is not a practical concern, but
if it ever matters the directory should gain the `keyPrefix`. Do not change it
now.

---

## 4. The facade

**Make public exactly what has a proven caller. Everything else is `internal` or
stays `private`.**

This is evidence-driven, not a redesign. Do **not** invent a cleaner-looking API,
merge members, rename them, or introduce a protocol. Adding public API later is
source-compatible; removing it is not, so minimal is the safe direction.

### Public — observable state

```
role                          (get/set — controller sets .spectator)
phase                         (get/set — controller sets .inProgress/.completed)
seats                         (get)
localSeatClaimID              (get/set)
pendingSeatClaim              (get/set)
sessionEndedDuringPlay        (get/set)
isGuestAwaitingReconnect      (get/set)
isSessionActive               (private(set))
isSessionPending              (private(set))
isEligibleForGroupSession     (private(set))
sessionActivationCount        (private(set))
versionMismatchedCount        (private(set))
lastMismatchedProtocolVersion (private(set))
hostVersionMismatch           (private(set))
```

### Public — methods

```
init(keyPrefix:)
listenForSessions()  prepareAsHost()  cancelHostPreparation()
endSession()  leaveSession()  playAgain()  abandonSession()  tearDownSession()
claimSeat(displayName:displayInitials:themeID:playerID:isLocal:)
updateOwnSeat(name:initials:themeID:)  moveSeat(fromOffsets:toOffset:)
removeSeat(seatClaimID:)
broadcastTableState()
send(_:payload:)                    // both String and GameNightSessionKind overloads
clearSessionEndedFlag()  clearHostVersionMismatch()
gnParticipantID(for:)  setGnParticipantID(_:for:)
gnWasHost(for:)  setGnWasHost(for:)
```

### Public — hooks

```
onAppMessage  onTableStateReceived  onTearDown
onNeedsMatchStateBroadcast  appSettingsProvider
```

### Internal or private — no external caller

`session`, `messenger`, `messageListenTask`, `groupStateObserver`, `keyPrefix`,
`pendingHostSessionActivation`, `versionMismatchedIDs`,
`versionMismatchTimeoutTask`, `isAudioInterrupted`,
`sessionDroppedDuringInterruption`, `interruptionRecoveryTask`,
`configureSession(_:)`, `handle(_:from:)`, `handleHello`, `handleTableState`,
`handleSeatClaim`, `handleSeatRelease`, `addSeat`, `sendHello`,
`listenForMessages`, `startObservingAudioInterruptions`,
`handleAudioInterruption`, `cancelInterruptionRecovery`, `gnIsHost(for:)`,
`setGnIsHost(for:)`, `removeGnIsHost(for:)`.

`configureSession` is called only from `listenForSessions`. If the build shows an
external caller, report it rather than making it public on the spot.

If any member on the internal list turns out to be needed by SyFive, make it
public and **say so in your report** — that is a finding about the facade, not a
routine fix.

---

## 5. `UserDefaults` — verify, don't touch

The three keys stay exactly as they are:

```
\(keyPrefix).gn.host.\(sessionID.uuidString)
\(keyPrefix).gn.participantID.\(matchID.uuidString)
\(keyPrefix).gn.wasHost.\(matchID.uuidString)
```

With `keyPrefix: "syfive"` these are byte-identical to the shipped build.
**Print all three from a debug build before and after the move and compare the
strings.** Inventory 2.1 is the best behavior in the feature and it rests
entirely on these resolving.

---

## 6. Verify

```bash
# In sylib-swift
swift build && swift test
grep -rn "SyLibScoring\|MatchController\|Yatzy\|Commentary\|SyFive" Sources/SyLibGameNight
# must return nothing
```

Then, two physical devices on a FaceTime call.

**Full inventory sweep — all 27 entries.** This step moves the session wholesale,
so nothing is out of scope. Pay particular attention to:

- **2.1** — host force-quits mid-session and relaunches; resumes as host, no
  prompt, guests unaffected. The single most important check.
- **2.2** — end a session, join a different one as guest; must join as guest.
- **2.3** — guest force-quits and relaunches; same seat, score intact.
- **3.1, 3.2** — unanswered call to voicemail mid-match: no premature "session
  ended" alert; an unrecovered interruption shows it once after ~6 s.
- **4.2, 4.3** — guest joins via **Messages** and claims a seat before the host
  arrives. The old failure was a dead end recoverable only by restarting Game
  Night.
- **8.1** — export a log; it covers the session start through teardown.

---

## 7. Definition of done

- [ ] `GameNightSession<Activity: GroupActivity>` lives in `SyLibGameNight`.
- [ ] `GameNightRole` in the package; `GameNightController.Role` is a typealias.
- [ ] `GameNightActivity` still in SyFive, identifier and title unchanged,
      vestigial `import SyLibScoring` removed.
- [ ] `GameNightLogBuffer` in the package; the five outside call sites import it.
- [ ] The §4 members are public; everything on the internal list is not.
- [ ] Zero references to `SyLibScoring`, `MatchController`, `Yatzy`,
      `Commentary`, or `SyFive` in the package.
- [ ] The three `UserDefaults` key strings verified byte-identical, by printing
      and comparing.
- [ ] Load-bearing orderings preserved, with their comments.
- [ ] The four Game Night views are **still in SyFive**.
- [ ] All 27 inventory entries verified on two devices; sign-off table updated.
- [ ] Report: any member that had to be made public beyond §4, and why.
