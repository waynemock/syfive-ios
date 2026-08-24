# SyFive — Game Night Design Spec

*Design authority for multi-device play: the SharePlay transport, the split-authority
session model, recipe-replay roll theater, seating, absence handling, and completion
persistence.*

> **Status:** Design agreed; four decisions left explicitly open (§13). Game Night is a
> **post-1.0 feature** — nothing here blocks or modifies SyFive 1.0. This document is
> the implementation brief for the Xcode Claude agent. Read `02_DATAMODEL_DESIGN.md`
> first: Game Night builds on its entities and invariants and **changes none of them**.
> Zero schema change is a designed property of this feature, not an accident.

---

## 0. Why this exists (context the agent must not lose)

The motivating scenario is not "online multiplayer." It is a family game night where
some of the players no longer live at home: the table is a FaceTime call, and SyFive
lets everyone sit at it from their own device. The same mechanism, pointed at people in
the same room, gives each local player their own device instead of passing one around.

That framing kills entire categories of scope before they exist. There is no
matchmaking, no lobby of strangers, no friend codes, no separate accounts, no chat, no
emotes, no turn timers, no presence meters, no spectator counts. **The FaceTime call
(or the room) is the social layer; the app builds none of it.** Someone saying "Dad,
your turn" *is* the notification system.

Locked constraint decisions, in the order they were made:

1. **No self-hosted servers.** Apple-relayed infrastructure is acceptable (CloudKit
   already is one).
2. **Transport: GroupActivities / SharePlay.** Chosen over MultipeerConnectivity
   (sessions die seconds after backgrounding; remote play impossible) and Game Center
   (4-player real-time cap — an arbitrary regression from pass-and-play's open table —
   plus unwanted chrome). Accepted cost: internet is required even when every device is
   in the same room.
3. **Tap-to-join = SharePlay proximity start.** The bring-together gesture starts the
   session app-to-app on iOS 17+ iPhones. There is no public NFC phone-to-phone API;
   this is the system-sanctioned equivalent of the original wish.
4. **Spectator rolls are replayed, not revealed.** The roller's actual
   `DiceRollRecipe` is rebroadcast and physically replayed on every device (§6.2).
5. **Held dice are visible to spectators**, live, mirroring the roller's kinematic
   held line.
6. **Host-authoritative; no host migration.** Host absence pauses the table.
7. **Mixed tables.** One device may own multiple seats (host plus a local player on
   one phone; two remote daughters on their own phones). Seats lock at match start;
   late joiners spectate.
8. **Versioned message envelope from day one.**
9. **Completion model:** the host broadcasts the final `Match` value; every device
   writes its own copy under the same match UUID. No shared CloudKit zone.
10. **Name: Game Night.** Entry points read "Start Game Night" / "Join Game Night."
    Interior vocabulary uses table language ("setting the table," "Waiting for
    Sarah"). Marketing line: *one table, any distance.*

A path explicitly rejected during design, so the agent does not rediscover it: a
**CKShare shared-record zone** for the live match. SwiftData does not expose shared
zones at the iOS 18.6 deployment floor, and dropping to raw CloudKit for one zone is
heavy machinery. The write-once-at-completion broadcast (§8) replaces it at the cost of
exactly one message.

---

## 1. What Game Night is NOT (product guardrails)

Any of these appearing in a build is a bug against this spec:

- No chat, reactions, emotes, or stickers. The call carries the banter.
- No turn timers, countdowns, or "nudge" buttons. Nobody is on the clock at a kitchen
  table.
- No connection-quality meters, signal bars, or latency readouts. Presence is rendered
  positively (who is at the table), never as diagnostics.
- No matchmaking, public rooms, friend codes, or invitations to strangers. Joining
  requires being on the call or in the room.
- No host migration, no conflict-resolution machinery, no operational transforms. The
  02 single-writer invariant survives intact.
- No changes to the 02 schema. If an implementation direction appears to require a new
  persisted field, stop — the design almost certainly routes around it (§8 shows how).
- **The player's own turn is pixel-identical to SyFive today.** Same tray, same
  physics, same stuck-die yellow/red interactions, same scorecard. Game Night, from
  the roller's chair, is invisible.

---

## 2. Transport: GroupActivities / SharePlay

### 2.1 Session shape

- One `GroupActivity` type: **`GameNightActivity`** (App layer — it imports
  GroupActivities). Its metadata title is `"SyFive Game Night"`, which the system
  surfaces in the FaceTime call UI.
- Three doors into the same session, one code path after entry:
  1. **On a FaceTime call:** starting Game Night offers the system SharePlay sheet;
     everyone on the call gets the join affordance.
  2. **In the room, iPhone-to-iPhone:** the iOS 17+ proximity gesture (bringing two
     iPhones together) starts/joins the same activity. System preconditions the agent
     must know: both devices unlocked, AirDrop on, and sender and recipient in each
     other's contacts. A tap that produces nothing is therefore **not a bug** — it is
     system behavior for, say, a houseguest not in your contacts. Never surface an
     error for it; door 3 is the fallback. No iPad supports the gesture (iPadOS has
     no bring-together feature).
  3. **Invite link:** the host shares the `GameNightActivity` through the standard
     share sheet (GroupActivities' built-in share-sheet activation — build no custom
     invite plumbing). AirDrop it to the iPad across the room, or Message it to
     anyone. This is the iPad's in-room door and the universal fallback when the tap
     doesn't fire.
- All messaging uses **`GroupSessionMessenger`** in reliable mode. One channel, one
  delivery guarantee, no unreliable fast path — game messages are human-paced and tiny.
- **Never stream per-frame physics transforms.** The messenger is rate-limited and
  intended for small control payloads. Recipe replay (§6.2) exists precisely so theater
  costs one small message per roll, not a stream. A serialized `DiceRollRecipe` (seed +
  five sets of spawn/orientation/impulse/torque + physics snapshot) is a few hundred
  bytes.

### 2.2 System behaviors we get for free (build nothing)

- **Backgrounding survival.** SharePlay sessions are system-managed; a guest answering
  a text does not drop the table. This is the decisive advantage over
  MultipeerConnectivity and the reason absence handling (§7) can be calm.
- **App Store prompt.** A call participant without SyFive installed gets the system
  prompt to download it. No App Clip, no invite infrastructure.
- **Session UI.** The green SharePlay indicator, the leave/end controls in the system
  sheet — all system-provided. SyFive adds no session chrome of its own.

### 2.3 Requirements and floor check

- Everyone needs SyFive installed and an Apple Account. Accepted.
- GroupActivities is available well below the iOS 18.6 floor; the proximity start
  gesture requires iOS 17+ (also below floor). No floor conflicts.
- FaceTime group limits far exceed any plausible Yatzy table. Impose no artificial
  seat cap beyond what the seating UI comfortably renders (`Game.maxParticipants` is
  already 0 = unlimited); design the seat list to stay comfortable to ~8.

---

## 3. The split-authority model

Two authorities, cleanly divided, never overlapping:

### 3.1 Roller authority — dice

Each seat's rolls are generated by **full physics on the seat-owning device**, exactly
as today. The simulation never cheats, and now that principle extends across the table:
your rolls are *your device's* physics, witnessed by everyone else. The roller's
settled face values are authoritative for that roll; every other device receives
theater plus the authoritative values (§6.2). The dice engine itself changes only where
§6.2 says so — generation, fairness, and the stuck-die UX are untouched.

### 3.2 Host authority — match state

The host device owns the live `Match`: seat order, turn index, score entries,
`yatzyBonus` tallies, status. Guests **propose** (their roll results, hold toggles,
category choices); the host **validates, applies, and broadcasts**.

Validation is free: the Layer 1 scoring functions are pure and identical on every
device, so the host validating a guest's category choice (legality, joker
forced-scoring, strict-poison rule) is just calling the same
`legalScoreCategories` / `jokerScoreValue` / `validate()` the guest's own UI used. The
Foundation-only domain layer is what makes a wire protocol this thin possible — every
device already carries the complete rulebook.

Discrepancy rule, stated once and absolutely: **received host state replaces local
render state.** Guests never argue.

### 3.3 Persistence discipline

- **Only the host checkpoints during play**, at the existing 02 §3.4 boundaries
  (category scored, match completed). Game Night adds no new checkpoint triggers.
- **Guests write exactly once, at completion** (§8). A guest device that dies mid-match
  has nothing on disk, by design — the host's checkpoint is the durable record.
- The single-writer invariant from 02 survives untouched: at any moment, exactly one
  device is writing a given match.

---

## 4. Message protocol

### 4.1 Placement and the SyLib question

All wire payload types are **plain Foundation-only `Codable` structs** — same
discipline as the domain layer — but they live in the **App layer**
(`App/GameNight/Protocol/`) for now, because the theater payload references
`DiceRollRecipe`, which is App-forever (the dice engine never enters the package).

Do **not** design a generic session abstraction for SyLib yet — this is the
ScoringSystem-protocol restraint applied again: an audience of one. Record the future
seam and move on: the table/seating messages are game-agnostic and could migrate to
SyLib at Step 2; per-game theater would travel as an **opaque payload the game module
interprets** (Yatzy's is a `DiceRollRecipe`; a ScoreIt game's might be nothing). That
sentence is the entire extraction plan; build none of it now.

### 4.2 Envelope

```
struct GameNightEnvelope: Codable {
    var protocolVersion: Int      // starts at 1
    var kind: String              // message kind rawValue
    var payload: Data             // the Codable payload, encoded
}
```

- Version is checked at `hello` (§4.3) and only there. A joiner whose protocol version
  differs from the host's is declined a seat with calm copy ("Update SyFive to join
  this Game Night") and may spectate nothing — they simply aren't seated. Because the
  gate is at join, mid-session version mismatch cannot occur.
- Unknown `kind` values are ignored silently (forward compatibility within a version).

### 4.3 Message kinds

| Kind | Direction | Payload | Notes |
|---|---|---|---|
| `hello` | joiner → all | protocolVersion, appVersion | Sent on session join |
| `tableState` | host → all | full seating snapshot + phase | Idempotent; also the late-join catch-up |
| `seatClaim` | guest → host | display snapshot + `playerID` + local-seat flag | §5.3 |
| `matchStart` | host → all | initial match snapshot | Seats lock here |
| `rollBegan` | roller → all | seatID, turn-roll index (1–3), `DiceRollRecipe` | Theater starts |
| `rollResult` | roller → all | seatID, five face values | Correction target; host folds into state |
| `holdToggled` | roller → all | seatID, die index, held flag | Mirrors the kinematic line |
| `scoreChosen` | scorer → host | seatID, category | Host validates via Layer 1 |
| `undoRequest` | scorer → host | seatID | Policy: §6.3, open decision §13.3 |
| `matchState` | host → all | full match snapshot | After every applied action |
| `matchComplete` | host → all | the final `Match` value | The one guest write trigger |
| `matchAbandoned` | host → all | — | Tables close gracefully |

**Snapshots, not deltas — a locked simplifier.** `tableState` and `matchState` carry
complete snapshots every time. A Yatzy match snapshot is small (≤ 8 participants × 13
entries plus turn state); full snapshots are idempotent, self-healing after any missed
message, and make late-join catch-up a non-event. Do not build delta bookkeeping.

**The wire snapshot is the checkpoint shape.** `matchState` carries exactly what 02
persists at a boundary: entries, bonuses, turn/seat index, status. Transient dice state
(`diceValues`, `held`, `rollsRemaining`) is **never** in `matchState` — spectators
derive roll count from the `rollBegan` stream and dice state from theater. This keeps
the 02 rule ("transient turn state never persists") true on the wire as well as on
disk.

---

## 5. Setting the table (seating)

### 5.1 Entry

New Game presents **Pass & Play** and **Game Night** side by side; the pairing explains
itself. Tapping Game Night: if a FaceTime call is active, the system SharePlay sheet
appears; otherwise a single calm guidance screen ("Bring iPhones together, start a
FaceTime call, or send an invite") — no tutorial, one sentence. The guidance screen
and the table-setting screen both carry a quiet **Invite** affordance opening the
system share sheet (§2.1 door 3), so an iPad in the room — or a tap that didn't fire —
never dead-ends the host.

### 5.2 The table appears

On guest devices the activity arrives and SyFive opens directly into the table view.
Seats fill visibly as people claim them — the host watches the table set itself. No
ready-up buttons, no lobby countdown: the host starts the match when the table looks
right, the way someone deals cards when everyone's sat down.

### 5.3 Claiming a seat

A guest picks themselves from **their own roster** (or creates a player inline — the
existing roster CRUD). The `seatClaim` carries:

- the **display snapshot** (`displayName`, `displayInitials`, `displayThemeID`) — the
  02 §2.7 mechanism doing exactly what it was designed for, unmodified;
- the guest's **`playerID`** — which resolves against a roster only on devices that
  have that player, and renders from the snapshot everywhere else. A `playerID` that
  resolves to nothing locally is *already a supported render state* (the
  deleted-player path). **This is why Game Night needs zero schema changes.**

The host arranges seat order (drag), and adds **local seats** for shared-device
players — a mixed table. Any device, not just the host's, may own multiple seats via
additional local claims; seat ownership is simply "the device that claimed it."

### 5.4 Locking

`matchStart` locks the seats. Later arrivals to the session spectate: they receive
`tableState`/`matchState` and render the table read-only. Their tray shows the live
theater from the next `rollBegan` onward; before that, an empty tray with "Sarah is
rolling" is sufficient — do not engineer mid-turn dice catch-up.

Teams: not in Game Night v1. `supportsTeams` is false for Yatzy anyway; the seat model
extends to teams later without wire changes (a seat's snapshot can describe a team).

---

## 6. Live play

### 6.1 Turn flow

The host advances turns inside `matchState`. On the device owning the active seat: soft
haptic, tray wakes, roll button breathes in — a breath, not an alarm (haptic depends on
the haptics workstream landing; note the dependency, don't block on it). On every other
device, the **stage** (§9.2). Local seats on any device hand off within that device
exactly as pass-and-play does today.

### 6.2 Roll theater — recipe replay (locked decision)

**Roller side: zero changes.** Full physics, authoritative face read at settle,
yellow/red stuck-die interactions, everything identical to solo play. Two sends are
added: `rollBegan` (the captured `DiceRollRecipe`, at launch) and `rollResult` (the
settled values).

**Spectator side:**

- On `rollBegan`, replay the recipe through the real physics engine —
  **promote the existing debug replay path** into a spectator mode (no "REPLAY"
  overlay; that stays debug-only). Theater starts one message-latency after the real
  roll; on the call you hear "here goes" anyway. No clock synchronization protocol.
- Cross-device PhysX determinism is weak (known risk-register item), so **assume
  divergence is common. The replay is the theater; the correction pass is the
  guarantee.** At spectator-side settle, compare each die's face to the authoritative
  `rollResult` values. Mismatched dice get a short reorientation to the correct face,
  styled as a settle wobble — the chamfered hull already produces a natural rocking
  motion at rest (see `DICE_RETROSPECTIVE.md`), and the correction hides inside that
  exact motion. Duration ~0.25–0.4 s, only ever applied at rest, never a snap or flash.
- If a spectator die settles before `rollResult` arrives (unlikely — the roller settles
  first in wall time), hold the rest pose and correct on arrival.
- **Spectator stuck dice auto-resolve silently** — reuse the batch auto-rescue path
  (`autoRerollStuckDiceForBatch` behavior). Yellow/red are roller interactions;
  spectators never see intervention states.
- A roller-side red-die relaunch uses launch parameters not in the original recipe; the
  spectator's copy of that die simply settles wherever its replay put it and corrects.
  Accepted imperfection — do not add a supplementary relaunch message in v1.
- `holdToggled` mirrors held dice into the spectator tray's kinematic line, live
  (locked decision). Between rolls, everyone sees what you're keeping — real-table
  behavior.
- Spectator theater audio: **open decision §13.1** (blocked on audio existing at all).

**Fairness note for the agent:** nothing here touches roll *generation*. Recipes are
broadcast after capture; corrections act on spectator render entities only. The
fairness harness and its conclusions are unaffected, and no re-validation is triggered
by Game Night work unless physics parameters change (they must not).

### 6.3 Scoring

The active scorer picks a category on their device — same UI, same legal-category
computation, joker forcing included. `scoreChosen` goes to the host; the host validates
with Layer 1, applies, checkpoints (existing boundary), and broadcasts `matchState`.
Score entries tick into every scorecard.

**Undo (recommendation, open §13.3):** the seat that scored may undo until the next
`rollBegan`, via `undoRequest` → host applies the existing one-level
`LastScoreSnapshot` undo → broadcast. This is the "wait, wrong box" moment at a real
table — the mis-tapper fixes it, socially announced on the call.

### 6.4 The shared Yatzy moment

Every device computes Yatzy from the authoritative values and fires the full signature
celebration — lavender rim light, push-in, title card — as its own theater settles.
Rough simultaneity across the call is the feature; skew of a second is fine and needs
no sync protocol. Four phones blooming at once mid-FaceTime is the App Store
screenshot.

---

## 7. Absence, pause, resume, abandon

- **Guest backgrounds, not their turn:** nothing changes on any screen.
- **Guest backgrounds, their turn:** the stage shows "Waiting for Sarah" (display
  name). No timer, no countdown, no escalation. The call handles the heckling.
- **Guest drop mid-turn (recommendation, open §13.2):** the table waits. No skip
  mechanism in v1; the host's abandon control is the escape hatch for a night that's
  over.
- **Host absent/backgrounded:** the table quietly pauses ("Table paused"). Guests can
  still browse scorecards.
- **Host drop (app killed, network gone):** guest tables close gracefully to a "Game
  Night ended" state — no error styling. The host retains a checkpointed `inProgress`
  match on disk, because the host was checkpointing at boundaries all along.
- **Resume (recommendation, ships in v1 — open §13.4):** the host's unfinished Game
  Night match surfaces as resumable exactly like any `inProgress` match. Resuming opens
  a **new** SharePlay session; rejoining guests re-claim their seats, matched by
  `playerID` (fallback: display-snapshot confirm). Unclaimed remote seats wait. The
  interrupted player's turn restarts — scorecard intact, dice reset — the natural 02
  §3.4 behavior, now across devices. Losing a family game night to a dropped call is
  precisely the frustration SyFive exists to avoid, which is why this is recommended
  in rather than deferred.
- **Abandon:** a tucked-away host control sets `status = .abandoned` (existing enum
  case), broadcasts `matchAbandoned`, and every table closes gracefully. Abandoned
  matches are already excluded from stats — no new rule needed.

---

## 8. Completion & persistence

1. Host resolves `finalScore` and `rank` for all participants (existing Layer 1
   completion path), sets `completed`, writes locally — the existing checkpoint,
   unchanged.
2. Host broadcasts `matchComplete` carrying the **final `Match` value**.
3. **Every guest device upserts by match UUID** into its own store — insert if new,
   replace if present (the resume path can legitimately deliver the same UUID twice).
   This is each guest's single write, and it is their `recordedAt`-stamped flush per
   the stats contract.
4. Each device's copy then syncs through **its own private CloudKit database** exactly
   per `03_CLOUDKIT_DESIGN.md`. Identical UUIDs across different Apple Accounts never
   meet — private databases are per-account. The one convergence case: two devices on
   the *same* account both seated (Mom's iPhone and iPad) both write the same UUID to
   the same private database → CloudKit converges identical records. Benign; it's on
   the validation matrix.

**Stats and insights need zero changes.** A Game Night match is indistinguishable from
a local match in the data: participants with snapshots, entries, `recordedAt`, status.
Each family member's stats accrue on the devices whose roster resolves their
`playerID` — the daughter's Yatzy count grows in *her* history, rendered in *her*
theme, while the host's device renders her from the snapshot and aggregates only the
players it knows. H2H, insights, archetypes — all downstream machinery from
`03_STATS_DESIGN.md` and `04_PLAYER_INSIGHTS_DESIGN.md` just works.

---

## 9. UX specification

One principle generates every screen: **what happens at a real table?** And one
invariant: the roller's own turn is pixel-identical to SyFive today.

### 9.1 Setting the table

Seats fill live as claims arrive; each seat renders the claimer's initials circle in
their theme accent. Host drags to arrange, adds local seats, starts when ready. Copy
stays in table language. No lobby furniture.

### 9.2 The stage (spectating)

Off-turn, the tray becomes a stage: the roller's initials circle glows in their theme
accent, their roll plays out as theater, held dice sit in the mirrored kinematic line.
A subtle roll indicator ("Roll 2 of 3," derived from the `rollBegan` stream) is
permitted but optional — UI-polish latitude. **Scorecards remain freely browsable**
while spectating — studying your card mid-hand is real tabletop behavior — and entries
tick in live as `matchState` arrives.

### 9.3 Copy exemplars

Calm, named, positive: "Waiting for Sarah." "Table paused." "Game Night ended."
"Update SyFive to join this Game Night." Never: "Connection lost," "Player 3
disconnected," error iconography.

### 9.4 Ending

Standings settle on every device; the winner's device gets the push-in. Writes happen
silently (§8). The host gets one-tap **re-deal, same seats** — a fresh match with the
locked seating carried forward.

---

## 10. Architecture placement

```
SyFive/
  Domain/                          ← UNTOUCHED by Game Night
  Persistence/                     ← UNTOUCHED (upsert-by-UUID uses existing paths)
  App/
    GameNight/
      Protocol/                    Envelope + payload structs (Foundation-only style,
                                   App-resident — §4.1)
      GameNightActivity.swift      GroupActivity definition (imports GroupActivities)
      GameNightController.swift    Session orchestration: join, messenger, routing,
                                   host/guest role, seat map
      TableReplica.swift           Guest-side render model fed by matchState snapshots
    Session/
      MatchController.swift        Gains NOTHING structural; host role drives it
```

- **`MatchController` stays the authoritative engine and runs only on the host.**
  Guests do not run its mutation paths; they render from **`TableReplica`**.
- The scorecard views already consume `MatchController` through stable read accessors
  (`playerNames`, `scores(for:)`, `canScore(category:for:)`, `totalScore(for:)`).
  **Formalize that seam as a small read-only protocol — `MatchPresenting` — adopted by
  both `MatchController` and `TableReplica`,** so the views bind either without
  knowing which. Interactive affordances route by role: host → direct calls; guest →
  proposal messages. This is the entire view-layer cost of Game Night.
- GroupActivities imports appear **only** inside `App/GameNight/`. Nothing below the
  App layer learns Game Night exists.
- `DiceRoller` gains: a spectator replay entry point (the debug replay path, un-gated
  for this mode, overlay-free), a theater-settle callback with per-die face read for
  the correction pass, and reuse of batch auto-rescue for spectator stuck dice.

---

## 11. Implementation stages (ordered; each independently checkable)

1. **Protocol types + envelope.** Payload structs, encode/decode round-trips,
   version-gate behavior. *Check: unit tests pass, including unknown-kind tolerance
   and version mismatch.*
2. **Session plumbing.** `GameNightActivity`, join via call and via proximity,
   messenger up, `hello`/`tableState` skeleton. *Check: two physical devices exchange
   tableState.*
3. **Seating.** Claim from roster, display snapshots travel, host arranges, local
   seats, lock at `matchStart`, late joiner receives snapshots read-only. *Check: a
   mixed table seats and locks; initials circles render in claimers' themes on all
   devices.*
4. **Headless live match.** Turns, holds, scoring through host authority with values
   simply appearing (no theater yet). *Check: a full remote match plays start to
   finish, correct scoring on every screen, host checkpoints at boundaries.*
5. **Roll theater.** `rollBegan`/`rollResult`, spectator replay, correction wobble,
   held-line mirroring, silent auto-resolve. *Check: mismatched dice correct
   unremarkably; a roller's red-die relaunch corrects cleanly on spectators.*
6. **Completion.** `matchComplete`, upsert-by-UUID on every device, exactly one guest
   write, stats accrue only where rosters resolve. *Check: same UUID on all devices;
   daughter-device stats grow, host renders her from snapshot.*
7. **Absence machinery.** Waiting states, host pause, abandon broadcast, dropped-host
   resume with seat re-claim. *Check: kill the host app mid-match; resume into a new
   session; guests re-seat; play continues with the interrupted turn restarted.*
8. **Polish.** Shared celebration, handoff haptic (if haptics exist by then), copy
   pass, re-deal-same-seats.

---

## 12. Validation matrix (physical devices; two minimum, three preferred incl. an iPad)

1. Proximity tap-join between two iPhones.
2. Join via FaceTime call SharePlay sheet.
3. iPad joins via call, and separately via an AirDropped invite link with no call
   active (no proximity path exists for iPad).
4. Mixed table: one device owns two seats; handoff within that device matches
   pass-and-play.
5. Guest backgrounds off-turn → no visible change anywhere.
6. Guest backgrounds on-turn → "Waiting for {name}" on all other devices; returns and
   plays.
7. Host backgrounds → table pauses calmly; resumes on return.
8. Host app killed → guests close gracefully; host resumes from checkpoint into a new
   session; guests re-claim seats.
9. Late joiner after `matchStart` spectates; sees live theater from next roll.
10. Forced replay divergence corrects via settle wobble — visually unremarkable at
    normal viewing distance.
11. Roller red-die relaunch → spectator correction clean.
12. Completion: identical match UUID present on every device; each participant's stats
    accrue only on devices whose roster resolves their `playerID`.
13. Same-Apple-Account iPhone + iPad both seated → CloudKit converges the duplicate
    UUID benignly.
14. Version-mismatch joiner declined with calm copy; session unaffected.
15. Shared Yatzy: celebration fires on all devices within ~1 s of each other.
16. Proximity tap between iPhones not in each other's contacts produces no session
    (system behavior, no error shown); the Invite door succeeds immediately after.

---

## 13. Open decisions (Pops resolves; the agent must not decide these)

1. **Spectator theater audio** — parked until the audio workstream exists at all
   (still ❌ in `IMPLEMENTATION_STATUS.md`). Decide alongside audio.
2. **Guest drop mid-turn** — wait-only (recommended) vs. a host "play on" skip
   control. Recommendation rationale: a skip control is timer-adjacent furniture; the
   abandon control already covers the night-is-over case.
3. **Game Night undo policy** — scorer-until-next-roll via host (recommended) vs.
   none vs. host-only.
4. **Dropped-session resume in v1** — recommended in (§7 rationale) vs. deferring to
   a Game Night point release.

---

## 14. Invariants quick reference

- **Zero schema change.** Game Night adds no persisted fields, no new entities, no
  migrations. §2.7 display snapshots + preserved `playerID`s already carry it.
- Roller physics is untouched: generation stays pure on the roller's device; broadcast
  is presentation; corrections act on spectator render entities only.
- Host-authoritative; received host state replaces guest render state; no host
  migration; no conflict resolution.
- Only the host checkpoints during play; guests write exactly once, at completion,
  upserting by match UUID.
- No CKShare / shared CloudKit zones. Completion broadcast + per-account private-DB
  sync is the whole persistence story.
- Snapshots on the wire, never deltas; the `matchState` shape equals the checkpoint
  shape; transient dice state never rides in `matchState`.
- Version gate at `hello` only; unknown message kinds ignored.
- GroupActivities imports live only in `App/GameNight/`; Domain and Persistence layers
  never learn Game Night exists.
- Never stream per-frame transforms; one recipe message per roll is the theater budget.
- No chat, timers, meters, matchmaking, or session chrome. The FaceTime call is the
  social layer.
- The roller's own turn is pixel-identical to SyFive today.
