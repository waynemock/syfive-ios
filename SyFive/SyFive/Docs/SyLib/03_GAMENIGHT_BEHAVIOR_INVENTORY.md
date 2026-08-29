# Game Night — Behavior Inventory

**Purpose.** GroupActivities cannot be unit tested. This document is the test
suite. Every entry is a behavior that already works and was expensive to get
right — most exist because something failed in the field first.

**When to use it.** Run the whole thing before and after each phase of the
`SyLibGameNight` extraction, and again when a second app adopts the module. Any
entry that behaves differently after a refactor is a regression, regardless of
what the code looks like.

**How to read an entry.** *Trigger* is what to do. *Correct behavior* is what
must happen. *Why it exists* names the state that implements it, so a refactor
that drops the state is caught at review rather than in the field.

**Test rig.** Two physical devices on a FaceTime call, signed into different
iCloud accounts. The simulator cannot reproduce SharePlay session delivery,
audio interruption, or the invite banner. A third device is needed for the
starred (★) entries.

> **Status.** Reconstructed from the controller source, with the original failure
> modes filled in from Pops's recollection (3.1, 3.2, 4.3, 6.3, 7.3). One open
> item remains, marked ⚠️: the missing version-mismatch UI (5.1), which is being
> addressed separately. Nothing here has been verified on device yet — the
> sign-off table at the end is empty by design.
> Section 9 was added before Phase A of the `SyLibGameNightMatch` extraction
> (2026-08-27) to document match-layer behaviors that are about to move into the
> package.

---

## 1. Session establishment

### 1.1 Host starts a session from inside the app
**Trigger:** On a FaceTime call, tap Start Game Night → Game Night in the nav bar.
**Correct behavior:** Table setup appears. Host role is assigned. Guests see the
invite banner.
**Why it exists:** `prepareAsHost()` sets `pendingHostSessionActivation`, which
`configureSession` reads to decide role. Role is *not* derived from who created
the `GroupActivity` — activation intent is tracked separately.

### 1.2 Host starts FaceTime first, then opens the app
**Trigger:** Start a FaceTime call normally, then open SyFive and tap Game Night.
**Correct behavior:** Identical to 1.1.
**Why it exists:** `GroupStateObserver.isEligibleForGroupSession` mirrors into
`isEligibleForGroupSession`, gating the entry point on whether the device is
actually in a shareable context.

### 1.3 Guest accepts the invite banner
**Trigger:** Tap the Game Night notification within ~15 seconds.
**Correct behavior:** Guest joins as guest, receives table state, sees claimable seats.
**Why it exists:** `configureSession` finds no host intent and no persisted flag,
so `role = .guest`, then sends `hello` to request table state.

### 1.4 Guest joins via the SharePlay button after the banner disappears
**Trigger:** Ignore the banner. Later tap the SharePlay button in the status bar
or Control Center.
**Correct behavior:** Same as 1.3.
**Why it exists:** This is the single most confusing part of Apple's SharePlay
UX, and the reason `GameNightHelpSheet` devotes three sections to where that
button lives per device.

### 1.5 Duplicate session delivery
**Trigger:** Hard to force deliberately; watch for it during any join.
**Correct behavior:** The second delivery of the same session is ignored — no
teardown, no re-join, no state reset.
**Why it exists:** `configureSession` guards on `session?.id == incomingSession.id`
and returns early. Without this, the system redelivering a session mid-play
would tear down a live table.

### 1.6 Host cancels before anyone joins
**Trigger:** Tap Game Night, then back out of table setup.
**Correct behavior:** No session remains active. A later Game Night tap starts fresh
as host.
**Why it exists:** `cancelHostPreparation()` clears `pendingHostSessionActivation`,
so the *next* session delivered isn't wrongly claimed as host.

---

## 2. Host role persistence

### 2.1 Host force-quits and relaunches mid-session
**Trigger:** Host swipes the app away during play, reopens it while the FaceTime
call is still live.
**Correct behavior:** Host resumes **as host**, with no prompt and no user action.
Guests keep playing; the table does not reset.
**Why it exists:** `UserDefaults.gnIsHost(for: session.id)` persists the role
against the session ID, which is stable across relaunch because the
`GroupSession` is a system object tied to the call. `configureSession` reads
`persistedAsHost` and restores. **This is the highest-value behavior in the
document and the one most likely to be lost in a refactor** — it depends on a
side effect in `UserDefaults`, not on anything visible in the type's API.

### 2.2 Stale host flag does not auto-promote
**Trigger:** End a session normally. Later join a *different* session as a guest.
**Correct behavior:** Joins as guest.
**Why it exists:** `tearDownSession()` calls `removeGnIsHost(for:)` — and captures
the session ID *before* clearing `session`, because reading it afterward gets nil
and the flag leaks. That ordering is load-bearing.

### 2.3 Guest identity survives relaunch
**Trigger:** Guest force-quits mid-match, relaunches while the session is live.
**Correct behavior:** The guest is recognised as the same participant, in the same
seat, with their score intact.
**Why it exists:** `UserDefaults.gnParticipantID(for: matchID)`, restored by
`prepareForGuestReconnect(matchID:)` before the session arrives, so the UI can
identify the local player during the gap.

---

## 3. Audio interruption ⚠️

### 3.1 Phone call arrives during play
**Trigger:** Call the host's device from a third phone mid-match. Decline or let
it ring out.
**Correct behavior:** **No "session ended" alert appears.** When SharePlay
redelivers the session, play resumes as if nothing happened.
**Why it exists:** An incoming call that went to voicemail — never answered —
still interrupted the audio session hard enough that SharePlay dropped and
redelivered the session, and the drop surfaced a "Game Night ended" alert
mid-match. `handleAudioInterruption(.began)` sets `isAudioInterrupted`, which
suppresses the alert. `.ended` starts a 6-second task; if `configureSession`
fires inside that window it cancels the task and logs "session recovered."
**Test note:** an unanswered call is the reproduction case, not a declined one.
Let it ring through to voicemail.

### 3.2 Interruption where the session genuinely doesn't come back
**Trigger:** Interrupt audio and prevent recovery — answer the call and stay on
it past 6 seconds.
**Correct behavior:** After ~6 seconds, the reconnect alert appears **once**.
**Why it exists:** The delayed task escalates
`sessionDroppedDuringInterruption` → `sessionEndedDuringPlay`.
**On the 6-second constant:** most likely derived from observed redelivery times
in the Game Night logs rather than picked arbitrarily. Treat it as measured —
**do not round it to 5 for tidiness.** If it is ever revisited, re-derive it from
logged `configureSession` timestamps following an interruption rather than
guessing. Worth confirming against an archived log if one survives.

### 3.3 Siri or an alarm during a roll
**Trigger:** Invoke Siri mid-roll.
**Correct behavior:** Same suppression as 3.1 — no premature alert.
**Why it exists:** `AVAudioSession.interruptionNotification` covers all
interruption sources, not just calls.

---

## 4. Seat claiming

### 4.1 Guest claims a seat
**Trigger:** Guest taps an open seat and picks or creates a player.
**Correct behavior:** Seat shows as claimed on every device within a second.
**Why it exists:** `seatClaim` → host authority → `tableState` broadcast to all.

### 4.2 Claim arrives before the session is ready ★
**Trigger:** Guest claims a seat at the moment the host is still configuring.
**Correct behavior:** The claim is not lost. It is applied once the session
settles.
**Why it exists:** `pendingSeatClaim` holds the payload (line 1032). On the next
`tableState`, if the claim isn't reflected in `seats`, it is **resent** (line 727).

### 4.3 Claim acknowledged after a stale local ID ★
**Trigger:** Guest joins via a **Messages** thread and claims a seat *before the
host has joined the session*.
**Correct behavior:** The claim survives. Once the host arrives, the seat appears
claimed and the guest can play.
**Why it exists:** This was a hard dead end. The claim was dropped with nothing
to retry it, and the guest was stuck — **restarting Game Night entirely was the
only recovery.** `effectiveClaimID = localSeatClaimID ?? pendingSeatClaim?.seatClaimID`
(line 757) covers the case where a stale `tableState` clears `localSeatClaimID`
while `pendingSeatClaim` still holds the original, and the resend at line 727
covers the claim never having been seen at all.
**Test note:** the Messages join path is the reproduction case — it makes a
guest-before-host arrival ordering far more likely than the FaceTime path does.
This pairs with 4.2; test them together.

### 4.4 Guest leaves and rejoins
**Trigger:** Guest taps Leave, then rejoins via the SharePlay button.
**Correct behavior:** Their seat is released for others, and rejoining offers seat
selection again. **The session does not end for anyone else.**
**Why it exists:** `leaveSession()` sends `seatRelease` and does *not* call
`session.end()` — deliberately different from `endSession()`.

---

## 5. Version mismatch

### 5.1 Mismatched app versions
**Trigger:** Two devices with different `currentProtocolVersion` values.
**Correct behavior:** The mismatched device is declined a seat. It does not
silently sit on a table that never starts.
**Why it exists:** `hello` is the only version check point; the sender goes into
`versionMismatchedIDs` and subsequent messages are ignored.
⚠️ **Known gap:** `versionMismatchedIDs` is never surfaced to any view. The guest
sees nothing happen and isn't told to update. Worth fixing before a second app
adopts this — with two apps, version skew becomes routine.

### 5.2 Unknown message kind
**Trigger:** A message whose `kind` string isn't in `GameNightMessageKind`.
**Correct behavior:** Ignored silently, session continues.
**Why it exists:** `messageKind` returns nil for unknown strings — forward
compatibility within a protocol version.

---

## 6. Turn flow and roll theater

### 6.1 Guest sees the host's dice
**Trigger:** Host rolls.
**Correct behavior:** The guest sees the same dice tumble and land on the same
faces.
**Why it exists:** `rollBegan` carries a `DiceRollRecipe` (seed + launch
parameters), so the guest *replays* the physics rather than being told the
answer. `rollResult` follows as the authoritative outcome.
**Note:** this is why `pendingAuthoritativeResult` exists — the replay may not
land identically, and the authoritative values win.

### 6.2 Spectator roll doesn't double-fire ★
**Trigger:** Watch a roll as a non-current player while other messages arrive.
**Correct behavior:** One roll animation.
**Why it exists:** `spectatorRollInProgress` guards re-entry (lines 886, 903, 916).

### 6.3 Proxy mode — host plays for an absent player
**Trigger:** During a match, on the host device, when it is *not* the local
player's turn: a **"Play for {name}"** button appears
(`DiceAreaView.swift:224`). Tap it.
**Correct behavior:** The host takes that seat's turn. The label changes to
"Playing for {name}". The remaining players finish the match normally.
**Why it exists:** A player who can't finish — battery dies, has to leave, app
won't reconnect — would otherwise strand everyone else at their turn with no way
to complete the match. This is the escape hatch. Host-only and manual by design:
`enableProxyMode()` guards on `role == .host`, and nothing activates it
automatically.
**Score attribution:** `enableProxyMode()` sets `outboundParticipantID` to the
absent guest's participant UUID. Every scoring broadcast while proxy is active
carries that ID, not the host's own, so the scores land on the correct
participant. If `outboundParticipantID` is nil or wrong, the absent guest's
turns are silently credited to the host — a misattribution invisible until the
match is in history. See also 9.2.
**Test note:** have a guest force-quit mid-match and confirm the host can carry
the match to completion for them. After the match ends, check history on another
device — the absent player's participant must show the scores the host entered,
not the host's own record.

### 6.4 Undo across devices
**Trigger:** Host undoes a score after a guest has seen it.
**Correct behavior:** Both devices return to the same pre-score state, dice included.
**Why it exists:** `onUndoWithDice`, `pendingGuestUndoAvailable`,
`pendingHostUndoAvailable`, and `clearUndoSnapshot()` on the match controller.
The undo window closes the moment another player begins rolling:
`onRollStarted` calls `clearUndoSnapshot()` on the match controller, which
clears `lastScoreSnapshot` and disables the undo button on all devices.

### 6.5 Guest undo snapshot survives the host's state echo
**Trigger:** Guest scores a category. Wait for the host to echo `matchState`
back (happens automatically after every score). Tap undo on the guest device.
**Correct behavior:** The undo button remains active after the echo. Tapping
it reverts the score and restores the pre-score dice.
**Why it exists:** `loadFromGameNightMatch` calls `clearUndoState()` as its
last step. Routing the self-echo through the normal load path would destroy the
guest's undo snapshot the moment the host's echo arrives.

`loadFromGameNightMatchPreservingUndo` saves `lastScoreSnapshot`, calls
`loadFromGameNightMatch`, then restores the snapshot. The call site that
distinguishes self-echo from "another player scored" is in `handleMatchState`:
the condition is whether `currentSeatIndex` in the incoming payload still
points at the local player's seat.

**Extraction risk:** any refactor that routes the self-echo through the standard
`loadFromGameNightMatch` instead of the preserving variant silently breaks guest
undo. The symptom is that the undo button disappears the moment the host echoes
back — which is the wrong trigger; undo should stay alive until the next roll.

---

## 7. Match lifecycle

### 7.1 Guest joins after the match started
**Trigger:** Start a match, then have a third device join. ★
**Correct behavior:** The joiner receives current match state and can spectate.
**Why it exists:** `matchState` messages carry a full `Match`, so late joiners
catch up without replaying history.

### 7.2 Rematch does not overwrite the previous match ★
**Trigger:** Complete a match, tap Play Again, play at least one scoring turn of
the rematch. Then check match history **on every device**.
**Correct behavior:** Both matches appear in history as separate records with
their own scores. The completed match is untouched.
**Why it exists:** This is a **silent data-loss bug** when it regresses — the
first match's completed record is overwritten by the rematch's first incremental
save, and nothing surfaces an error. Both paths sever the SwiftData binding
before loading the new match:

- **Host:** `broadcastRematch` calls `matchController?.clearPersistedMatchBinding()`
  unconditionally (line 1153) — it already knows this is a rematch.
- **Guest:** `handleMatchStart` has to *infer* it, because nothing on the wire
  says so. `isRematch = sessionMatchID != nil && sessionMatchID != payload.match.id`
  (line 786) — a rematch is detected purely by the incoming match UUID differing
  from the one already being tracked.

**Extraction risk:** the guest-side inference depends on `sessionMatchID` still
holding the *previous* match's ID at the moment `handleMatchStart` runs. Any
refactor that clears or reassigns `sessionMatchID` earlier in that method breaks
the detection, and the symptom appears in the history list rather than at the
point of failure.

**Test note:** verify on the guest as well as the host. The two paths reach the
same outcome by different means, and only the guest's is inferred.

### 7.3 History sync
**Trigger:** Play a match with someone, then start a **new match** with them
later — including in a different session.
**Correct behavior:** Devices that missed a match receive it and it appears in
their history.
**Why it exists:** `historyManifest` → `historyRequest` → `historyResponse`, via
the `onHistoryManifestNeeded` / `onHistoryMatchesNeeded` /
`onHistoryMatchesReceived` hooks.
**Correction to earlier note:** the manifest fires on **match start**, not
session start — `broadcastMatchStart` (line 1130) on the host, and
`handleMatchStart` (line 793) on each guest. A session where no match is started
exchanges no history.
**All three match-start paths broadcast the manifest**, so there is no gap:
`broadcastMatchStart` (line 1130), `handleMatchStart` (line 793), and
`broadcastRematch` (line 1157). Keep all three — a refactor that consolidates
them must preserve the call on every path.

### 7.4 Host ends the session mid-match
**Trigger:** Host taps End Game Night during play.
**Correct behavior:** Guests are told the session ended, not left hanging.
**Why it exists:** `sessionEndedDuringPlay`, cleared by `clearSessionEndedFlag()`
after the alert is shown.

---

## 8. Diagnostics

### 8.1 Log buffer captures a session
**Trigger:** Play a session, then export the log.
**Correct behavior:** The log covers the session from start to teardown.
**Why it exists:** `GameNightLogBuffer.shared.startSession()` at the end of
`configureSession`; `flushToDisk()` at the **top** of `tearDownSession` — before
any state is cleared, so the log captures the state at failure time. That
ordering is load-bearing.

---

## 9. Match-layer extraction

These entries document behaviors that are about to move into `SyLibGameNightMatch`.
Added before Phase A (2026-08-27) so the scenarios exist in the test suite
before the code moves. Run these together with §6 and §7 after every phase.

### 9.1 Participant resolution — three paths ★

**Trigger:** Start a match. On each device, check the `handleMatchStart` log
line for the `resolutionPath` field.

**Correct behavior:** Every seated player resolves to exactly one participant
ID. The log line reads `claimID`, `playerID`, or `spectator`. No seated device
logs `spectator`.

**Why it exists:** `handleMatchStart` resolves the local participant ID through
three ordered paths:

1. **claimID** — `seatMappings.first { $0.seatClaimID == effectiveClaimID }` —
   normal case; the guest's seat claim is in the mapping.
2. **playerID** — match against `seat.playerID` in the local roster — reconnect
   case; the claim ID is stale but the player record is present.
3. **spectator** — neither matched; the device is watching but has no seat.

The `resolutionPath` log string exists *only* to name which path fired. If it
disappears after extraction, one of the three paths was dropped. The host always
resolves via claimID; a force-quit-and-rejoin guest should resolve via playerID.

**Extraction risk:** all three paths must move together into the coordinator. A
consolidation that merges claimID and playerID into a single lookup will miss
the fallback ordering and strand reconnecting guests as spectators.

**Test note:** force the playerID path by having a guest force-quit mid-match
and rejoin. The log must say `resolutionPath=playerID`, not `spectator`, and
the guest must land in the correct seat with their score intact.

### 9.2 Proxy mode — scores attributed to the absent player in history

**Trigger:** Enable proxy mode for an absent player (6.3). Play all their
remaining turns until `isGameOver`. Then, in a new session with the returning
device, start a match to trigger history sync.

**Correct behavior:** The absent player's participant record in history shows
the scores the host entered on their behalf, not the host's own scores.

**Why it exists:** `enableProxyMode()` sets `outboundParticipantID` to the
absent guest's UUID. The scoring broadcast path reads `outboundParticipantID`
as the acting participant when it is set. If it is nil, the host's own ID is
used, and the absent guest receives no scores while the host appears to have
scored twice.

**Extraction risk:** `enableProxyMode`, `disableProxyMode`, and the scoring
broadcast path that reads `outboundParticipantID` must move together. If the
enable/disable methods move but the broadcast path does not (or vice versa),
all proxy-mode scores are silently misattributed with no error surfaced.

**Test note:** after the match completes, verify in match history on a third
device that the absent player's participant has the correct scores and the
host's participant does not have duplicates.

### 9.3 Participant resolution recovers after a mid-match reconnect ★

**Trigger:** Guest force-quits mid-match. Rejoin via the SharePlay button.
Observe which resolution path fires (see 9.1) and verify the seat assignment.

**Correct behavior:** Guest lands in the same seat, with their score intact,
without any explicit re-claim action. The resolution log says `playerID`.

**Why it exists:** On rejoining, the guest's `localSeatClaimID` is nil (they
haven't re-claimed). `effectiveClaimID = session.localSeatClaimID ?? session.pendingSeatClaim?.seatClaimID`
covers the case where the claim ID is stale. The playerID fallback then matches
the guest's roster player against the seat that was already assigned to them.
Together these ensure a returning guest restores their seat rather than being
treated as a new spectator.

**Extraction risk:** this recovery depends on `effectiveClaimID`'s nil-coalescing
fallback (inventory 4.3) and the playerID resolution path (9.1) working in
sequence. Either can be broken independently without breaking the other, so both
must be present.

---

## Extraction notes

Behaviors that depend on something other than the type's own API, and so are
invisible to a signature-level review:

| Behavior | Hidden dependency |
|---|---|
| 2.1 host survives relaunch | `UserDefaults.gnIsHost(for:)` keyed by session ID |
| 2.2 no stale promotion | session ID captured **before** `session = nil` |
| 2.3 guest identity | `UserDefaults.gnParticipantID(for: matchID)` |
| 7.4 host reconnect offer | `UserDefaults.gnWasHost(for: matchID)` |
| 3.1–3.2 interruption | 6-second window; cancellation from `configureSession` |
| 4.2–4.3 pending claim | resend-on-next-tableState; claim-ID fallback |
| 8.1 log completeness | `flushToDisk()` before state clearing |
| 7.2 rematch data loss | guest infers rematch from `sessionMatchID` **before** it is reassigned |
| 9.1 participant resolution | three paths logged by `resolutionPath`; claimID → playerID → spectator in order |
| 9.2 proxy attribution | `outboundParticipantID` must travel with the scoring broadcast path |
| 6.5 / 9.3 undo echo | `loadFromGameNightMatchPreservingUndo` on the self-echo path; not the clearing variant |

Two items to resolve during extraction rather than after:

- **`UserDefaults` keys.** There are **three**, all SyFive extensions, all
  hardcoding a `syfive.` prefix:

  ```
  syfive.gn.host.{sessionID}          gnIsHost      — 2.1, 2.2
  syfive.gn.participantID.{matchID}   gnParticipantID — 2.3
  syfive.gn.wasHost.{matchID}         gnWasHost     — host reconnect offer
  ```

  All three move with the session layer, and two Syzygy apps on one device must
  not collide. The `syfive.` literal becomes an app-supplied prefix —
  `GameNightSession(keyPrefix:)` or similar. **Changing the key format orphans
  existing values**, so either keep `syfive.` as SyFive's prefix exactly, or
  accept that in-flight sessions lose host role once on update.
- **5.1's missing UI.** Fix the silent version-mismatch failure before a second
  app adopts the module, not after.

---

## Sign-off

| Section | Verified | Date | Notes |
|---|---|---|---|
| 1 Session establishment | ☐ | | |
| 2 Host role persistence | ☐ | | |
| 3 Audio interruption | ☐ | | |
| 4 Seat claiming | ☐ | | |
| 5 Version mismatch | ☐ | | |
| 6 Turn flow | ☐ | | |
| 7 Match lifecycle | ☐ | | |
| 8 Diagnostics | ☐ | | |
| 9 Match-layer extraction | ☐ | | |
