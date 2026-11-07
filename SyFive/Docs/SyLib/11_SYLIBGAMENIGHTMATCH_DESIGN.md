# `SyLibGameNightMatch` — design

Extract the match-layer Game Night logic — the part that knows about matches,
turns, rematches, and history — so Sideral inherits it instead of rebuilding it.

**Design document.** §6 has two decisions. The sequencing in §7 is the plan.

---

## 0. Why this one is different

Every previous extraction was justified by "SyFive has it, another app will want
it." This one has a stronger justification and a weaker safety net, and both are
worth naming.

**Stronger:** these 400 lines are the expensive ones. Rematch binding is what
stops a rematch overwriting the previous match's record. History sync is a real
distributed reconciliation. Late-joiner catch-up, turn ownership, and participant
resolution across reconnects each took a bug to get right.

**Weaker:** Sideral is being designed to fit this rather than testing it. A second
consumer's value is that it *reveals* design mistakes; one built to conform
inherits them instead.

**But breaking changes are cheap here.** SyLib has exactly one author and two
consumer apps, both of which can be recompiled the same afternoon. So the seam
does not need to be right the first time — it needs to be *close enough that
Sideral is worth starting*, and then corrected in place when Sideral pushes back.

That reverses the usual guidance. Do not optimise these for source stability:
protocol shape, facade width, type names, view signatures, generic-vs-concrete.
Pick the shape that reads best and change it later.

Two things are still expensive, and the distinction matters:

- **Shipped user data.** CloudKit fields cannot be deleted once deployed, and a
  SwiftData type change needs a versioned schema and a backfill. That is not a
  source break you can absorb by fixing call sites — it is someone's match
  history.
- **The wire protocol, during a rollout window only.** Free once everyone has
  updated; expensive only for devices mid-upgrade. The two-version handshake and
  the "Can't join Game Night" path already handle it.

---

## 1. Target

```swift
.library(name: "SyLibGameNightMatch", targets: ["SyLibGameNightMatch"]),

.target(
    name: "SyLibGameNightMatch",
    dependencies: ["SyLibGameNight", "SyLibScoring", "SyLibCore"]
),
```

**Concrete over `Match`, not generic.** A generic `M: Codable` would push a type
parameter through every payload and the whole message router to serve a consumer
that may not exist. Instead the target says plainly: *this is for games that use
the SyLibScoring match model.* Games that do get four hard problems free; games
that don't simply don't adopt it.

That's the same opt-in shape as `SyLibScoringData`, and it costs nothing to be
wrong about — an app that can't use it just doesn't link it.

No `SyLibScoringData` dependency. History sync is expressed as hooks
(`onHistoryManifestNeeded` and friends), so the coordinator never touches
SwiftData. Keep it that way.

---

## 2. What moves

Roughly 400 of `GameNightController`'s 721 lines.

| Section | Lines | Content |
|---|---:|---|
| Match start / rematch / resume | 98 | `broadcastMatchStart`, rematch, resume-as-host |
| Match-layer handlers | ~90 | `handleMatchStart`, `handleMatchState`, `handleMatchComplete`, `handleMatchAbandoned`, `handleUndo` |
| Coordinator wiring | 48 | `attach`, `detach`, the three callback installs |
| Match state broadcasts | 39 | `broadcastMatchState`, `broadcastMatchComplete`, `broadcastMatchUndo` |
| History sync | 36 | manifest → request → response, all four methods |
| Helpers | ~30 | participant resolution, `persistLocalParticipantID` |

Plus the payloads: `MatchStartPayload`, `MatchStatePayload`,
`MatchCompletePayload`, `MatchAbandonedPayload`, `HistoryManifestPayload`,
`HistoryRequestPayload`, `HistoryResponsePayload`, and their message kinds.

## 3. What stays in SyFive

| Section | Lines | Why |
|---|---:|---|
| Roll theater (send + handle) | 60 | `DiceRollRecipe` — see §5 |
| Guest scoring proposals | 21 | `YatzyCategory` |
| Commentary | 27 | Moving to `SyLibCommentary` separately |
| Proxy mode | 23 | See §6.2 |
| `MatchPresenting`, `TableReplica` | 103 | SyFive render models |

---

## 4. The hard seam: `MatchController`

The coordinator's whole reason to exist is driving a game in progress, and today
that means a concrete `MatchController`. It uses eleven members:

```
playerCount  currentPlayerIndex  isGameOver  diceValues
participantIDs  playerIDs  playerDisplayNames  persistedMatchID
loadFromGameNightMatch(_:currentSeatIndex:)
clearPersistedMatchBinding()  clearUndoSnapshot()
```

plus three callbacks it installs: `onScoreApplied`, `onUndone`, `onRollStarted`.

**This becomes a protocol**, and it is the single most important design decision
in the extraction:

```swift
@MainActor
public protocol GameNightMatchHost: AnyObject {
    var playerCount: Int { get }
    var currentPlayerIndex: Int { get }
    var isGameOver: Bool { get }
    var participantIDs: [UUID] { get }
    var playerIDs: [UUID?] { get }
    var playerDisplayNames: [String] { get }
    var persistedMatchID: UUID? { get }

    func loadFromGameNightMatch(_ match: Match, currentSeatIndex: Int)
    func clearPersistedMatchBinding()
    func clearUndoSnapshot()

    var onUndone: (() -> Void)? { get set }
    var onRollStarted: (() -> Void)? { get set }
}
```

⚠️ **`onScoreApplied` is the problem.** Its signature is
`(YatzyCategory, [Int]) -> Void` — a Yatzy category and dice values. It cannot go
in the protocol as written.

Three options, in my order of preference:

1. **Split the callback.** The coordinator only needs to know *that* a score was
   applied, so it can broadcast state and check for game over. The Yatzy specifics
   (`proposeScore(category:diceValues:)` on the guest path) stay in SyFive. So the
   protocol declares `var onMoveApplied: (() -> Void)?` and SyFive's controller
   keeps its own `onScoreApplied` alongside, calling into the coordinator.
   **Start here** — it cleanly separates "a turn happened" from "here is what the
   turn was," and it is the smallest thing that works.
2. **Associated type.** `protocol GameNightMatchHost { associatedtype Move: Codable }`.
   Type-safe, and it would give Sideral compile-time checking on its move type
   instead of a bare `() -> Void`. The cost is a parameter propagating into the
   coordinator and every payload.
3. **Opaque move blob.** `onMoveApplied: ((Data) -> Void)?`. Loses type safety and
   duplicates what `onAppMessage` already does one layer down.

⚠️ **Treat option 1 as a first draft, not a commitment.** I preferred it partly to
avoid a generic parameter hardening into public API — a concern that mostly
evaporates when both consumers recompile together. When Sideral is actually
building against this, revisit option 2 with a real second move type in hand.
That is exactly the kind of decision Phase C exists to settle.

`diceValues` is likewise dice-specific and stays out — SyFive already reads it
from its own controller inside the closure.

---

## 5. The dice payloads are a third thing

`RollBeganPayload`, `RollResultPayload`, and `HoldToggledPayload` (~60 lines)
reference `DiceRollRecipe` from `SyLibDice`. They are generic for *any* dice game
over SharePlay, but they are not match-layer.

**Don't give them a target.** Either leave them in SyFive for now, or add them to
`SyLibDice` as an optional `SharePlay/` folder — `SyLibDice` would then need
`SyLibGameNight` for `GameNightEnvelope`, which is a dependency worth thinking
about before taking.

Decide separately, after this lands. Sideral is a Sorry-like game and may not roll
dice at all, in which case the question answers itself.

---

## 6. Decisions

### 6.1 Does proxy mode move?

`isProxyMode` lets the host play an absent player's turn so the rest can finish —
genuinely generic for any seated game, and Sideral will want it.

But `enableProxyMode()` guards on role and the UI trigger reads
`model.currentPlayerIndex`. The mechanism is ~23 lines and mostly seat logic.

**I'd move it.** It's the same shape as the rest of the match layer, and a
board game where someone's battery dies has exactly the same problem.

### 6.2 What is this target called?

`SyLibGameNightMatch` is accurate and ugly. Alternatives: `SyLibTableMatch`,
`SyLibMatchSync`, or folding it into `SyLibGameNight` as a second product from
the same target (SPM allows one target per product but not the reverse cleanly —
this would need two targets regardless).

I'd keep `SyLibGameNightMatch`. It reads as "the match layer of Game Night,"
which is exactly what it is, and the name makes the dependency direction obvious.

---

## 7. Sequencing — split first, move second

Use the pattern that worked for the session layer. The risky part is finding the
seam, and that is cheapest to iterate on inside SyFive.

**Phase A — split inside SyFive.** `GameNightController` becomes
`GameNightMatchCoordinator` + `GameNightController`, both in
`App/GameNight/`, nothing public, no package. Define `GameNightMatchHost` and
have `MatchController` conform. Ship it and live on it.

**Phase B — move the file.** Create the target, move the coordinator and the
seven payloads, add `public`. Should be mechanical if Phase A found the right
seam.

**Phase C — Sideral builds against it.** The real test, and the only one that can
find a wrong seam.

**Do not over-polish Phase B.** Get the coordinator moved, get Sideral compiling
against it, and let the second consumer do the work only a second consumer can.
A protocol refined against one caller is a guess with better formatting.

### Load-bearing details for whoever does Phase A

- **`handleMatchStart` line 476.** `isRematch` is computed one line before
  `sessionMatchID` is reassigned. Reassigning first silently breaks rematch
  detection and destroys the previous match's record. Inventory 7.2. The comment
  is already there — keep it.
- **Participant resolution has three paths** — claimID, playerID fallback,
  spectator — and the `resolutionPath` string exists purely so the log says which
  one fired. Preserve all three and the logging.
- **`effectiveClaimID = session.localSeatClaimID ?? session.pendingSeatClaim?.seatClaimID`**
  is the Messages-join fix. Inventory 4.3.
- **`detachMatchController` clears six things** including `sessionMatchID` and
  `sessionGameID`. Order matters less here than completeness.
- **History sync fires on match start, not session start** — from
  `broadcastMatchStart`, `handleMatchStart`, and `broadcastRematch`. All three
  call it; a consolidation must preserve all three.

### Before Phase A

Extend `GameNight-Behavior-Inventory.md` with the match-layer entries. Section 7
covers rematch, late-join, history sync, and host-ends-mid-match, but there is
nothing for participant resolution across reconnect, proxy mode's completion
path, or undo across devices. Those are about to become package behaviour and
need to be in the test suite before they move.

This is the one discipline that does **not** relax now that breaking changes are
cheap, and for a different reason than API stability. GroupActivities cannot be
unit tested. The reason you would lose entry 2.1 or 4.3 is not that another
consumer depends on it — it is that six months into Sideral nobody will remember
why `pendingSeatClaim` gets resent. **The inventory is memory, not consumer
protection.**

---

## 8. What this buys

SyFive's `GameNightController` drops from 721 lines to roughly 250 — roll theater,
scoring proposals, and the `GameNightMatchHost` conformance.

Sideral's Game Night integration becomes: declare an activity, conform to
`GameNightMatchHost`, define its own move payloads, and build a board. Not
"reimplement rematch binding and history reconciliation."

Which is the point.

---

## 9. This is the last thing blocking Sideral

`SyLibCommentary` is in flight and `SyLibGameNightMatch` is designed. Of the two,
**only this one blocks starting Sideral** — rematch binding, history sync,
participant resolution, and late-joiner catch-up are needed on day one, and they
are precisely the plumbing you do not want to write twice.

Commentary is different. Its engine and views are nearly done, but the tier model
is the one decision in all of SyLib made against zero knowledge of a second
consumer. **That argues for building Sideral's commentary early rather than
late** — if three tiers turn out wrong for a game where pieces move constantly,
you want to know in Sideral's second week, not its third month.

The bar for this target is not "finished." It is "finished enough that Sideral is
worth starting."
