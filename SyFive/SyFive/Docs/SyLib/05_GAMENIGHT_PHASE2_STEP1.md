# Game Night Phase 2, Step 1 — protocol split into `SyLibGameNight`

**Scope:** `sylib-swift` (new target) and `SyFive`.
**Not in this step:** `GameNightSession`, `GameNightActivity`,
`GameNightLogBuffer`, and all four Game Night views stay in SyFive. They move in
Step 2 and Phase 3.

This step creates the target and moves only the wire protocol. It is the one
step that changes observable behavior between app versions, so it ships alone.

**Required reading:** `GameNight-Behavior-Inventory.md`. Its 27 entries are the
test suite — GroupActivities cannot be unit tested.

---

## ⚠️ This breaks cross-version play, deliberately

After this change, a device on the current App Store build and a device on this
build **cannot share a Game Night table.** That is intended: the
`TableStatePayload` shape changes and the transport version bumps to 2 so the
break is a clean, logged rejection rather than a silent decode failure.

Everyone must be on the new build to play together. Do not try to preserve
backward compatibility — an attempt to keep the old payload readable would
reintroduce the exact mixing this step exists to remove.

Do not change any behavior beyond what is specified. No logic cleanup, no
reordering, no renaming of anything not listed.

---

## 1. Create the target

```swift
.library(name: "SyLibGameNight", targets: ["SyLibGameNight"]),

.target(
    name: "SyLibGameNight",
    dependencies: ["SyLibCore"]
),
```

**No `SyLibScoring` dependency, and do not add one.** `SeatSnapshot` carries
`playerID: UUID`, never a `Player`. A game with pieces instead of scorecards must
be able to link this without inheriting a match model. If something seems to need
`SyLibScoring`, it belongs in SyFive — stop and report.

Guard the whole module with `#if os(iOS)`. GroupActivities is unavailable on
watchOS, and tvOS is untested.

---

## 2. What moves

Only these, into `Sources/SyLibGameNight/Protocol/`:

| Type | From |
|---|---|
| `GameNightEnvelope` | `Protocol/GameNightEnvelope.swift` |
| `GameNightPhase` | `Protocol/GameNightPayloads.swift` |
| `SeatSnapshot` | same |
| `SeatMapping` | same |
| `HelloPayload` | same |
| `TableStatePayload` | same (reshaped, §4) |
| `SeatClaimPayload` | same |
| `SeatReleasePayload` | same |

Everything else in `GameNightPayloads.swift` stays in SyFive:
`MatchStartPayload`, `RollBeganPayload`, `RollResultPayload`,
`HoldToggledPayload`, `ScoreChosenPayload`, `UndoRequestPayload`,
`MatchStatePayload`, `MatchCompletePayload`, `MatchAbandonedPayload`,
`CommentaryPayload`, `HistoryManifestPayload`, `HistoryRequestPayload`,
`HistoryResponsePayload`.

`SeatMapping` is only used by `MatchStartPayload` today, but "seat identity
becomes in-game identity" is a shape every seated game needs. It goes in the
package.

All moved types and their members become `public`, including memberwise inits —
these are `struct`s crossing a module boundary, so the synthesized internal init
will not be visible to SyFive.

---

## 3. Message kinds split

`GameNightMessageKind` has 17 cases; 13 are SyFive's. Sideral needs none of them
and will want its own. The wire already carries `kind` as a `String`, so this
costs nothing at the protocol level.

**Package** — `Sources/SyLibGameNight/Protocol/GameNightEnvelope.swift`:

```swift
/// Message kinds owned by the session layer. Apps define their own kinds as
/// separate raw strings; the session forwards anything it does not own.
public enum GameNightSessionKind: String, Sendable {
    case hello, tableState, seatClaim, seatRelease
}
```

`GameNightEnvelope.init(kind:payload:)` currently takes `GameNightMessageKind`.
Add a `String` overload so both the package and the app can encode:

```swift
public init<P: Encodable>(kind: String, payload: P) throws
public init<P: Encodable>(kind: GameNightSessionKind, payload: P) throws
```

Replace `messageKind` with:

```swift
public var sessionKind: GameNightSessionKind? { GameNightSessionKind(rawValue: kind) }
```

**SyFive** — keep a 13-case `GameNightMessageKind` with the app's cases only
(`matchStart`, `rollBegan`, `rollResult`, `holdToggled`, `scoreChosen`,
`undoRequest`, `matchState`, `matchComplete`, `matchAbandoned`, `commentary`,
`historyManifest`, `historyRequest`, `historyResponse`). **The raw values must not
change** — they are on the wire.

### The dispatch change

`GameNightSession.handle(_:from:)` currently switches on `messageKind` and drops
unknown strings. It now handles its four kinds and forwards everything else:

```swift
var onAppMessage: ((String, GameNightEnvelope, UUID) -> Void)?
```

SyFive's controller does `GameNightMessageKind(rawValue: kind)` and drops what it
doesn't recognise.

⚠️ **Inventory 5.2 changes code path but not behavior.** Unknown kinds were
dropped by the session; now they are dropped by the app. The observable result is
identical — message ignored, session continues — but re-verify it, because the
guard moved.

`session.send` (14 call sites in the controller) keeps its generic shape; add a
`String` overload alongside the `GameNightSessionKind` one so the controller can
send its own kinds.

---

## 4. `TableStatePayload` reshape

This is the Phase 1 wart. The payload currently mixes session fields with three
SyFive commentary fields.

```swift
public struct TableStatePayload: Codable, Sendable {
    public let phase: GameNightPhase
    public let seats: [SeatSnapshot]
    public let protocolVersion: Int?
    /// Opaque app-scoped settings. The session transmits these without
    /// interpreting them; the app encodes and decodes its own type.
    public let appSettings: Data?

    public init(phase: GameNightPhase, seats: [SeatSnapshot],
                protocolVersion: Int?, appSettings: Data?)
}
```

**In SyFive**, define the settings type the controller owns:

```swift
struct GameNightAppSettings: Codable, Sendable {
    var commentaryEnabled: Bool
    var commentaryPackID: String
    var commentaryLevelRaw: String
}
```

The three opaque properties added in Phase 1 to `GameNightSession`
(`commentaryEnabled`, `commentaryPackID`, `commentaryLevelRaw`) are **deleted**.
So are the controller's pass-throughs for them. The controller holds a
`GameNightAppSettings` directly and exposes the same three names as bindable
properties, so no view file changes.

`broadcastTableState()` needs the encoded blob from the app:

```swift
/// Supplies opaque app settings for outbound tableState. Nil sends no settings.
var appSettingsProvider: (() -> Data?)?
```

The controller installs it; the session calls it when composing the payload.

⚠️ **`tearDownSession()` must not reset `GameNightAppSettings`.** The Phase 1
comment explaining this is deliberate — the host's commentary preference carries
into the next Game Night. Move that comment to wherever the settings now live so
the reasoning survives.

---

## 5. Two version numbers

Transport and app schema are now on different release cycles. SyFive shipping a
new scoring message must not invalidate Sideral's sessions; a package transport
change must invalidate both.

```swift
public struct HelloPayload: Codable, Sendable {
    public let protocolVersion: Int       // package transport version
    public let appProtocolVersion: Int    // app message schema version
    public let appVersion: String         // display string, unchanged
}
```

**Bump transport to 2** — `GameNightEnvelope.currentProtocolVersion = 2` —
because `TableStatePayload` changed shape.

**SyFive's `appProtocolVersion` starts at 1.** Define it app-side, e.g.
`GameNightMessageKind.appProtocolVersion`. It bumps when SyFive's own payloads
change, independently of the package.

`handleHello` (line 408) keeps rejecting on `protocolVersion` mismatch exactly as
it does now — same `versionMismatchedIDs` insert, same
`versionMismatchedCount`, same `lastMismatchedProtocolVersion`. Add a second
check for `appProtocolVersion` that follows the identical path, so an app-schema
mismatch produces the same user-visible outcome as a transport mismatch.

`sendHello` (line 499) populates both fields.

`handleTableState`'s `hostVersion = payload.protocolVersion ?? 1` check (line 429)
stays as written.

---

## 6. Verify

```bash
# In sylib-swift
swift build && swift test
grep -rn "SyLibScoring\|Match\|Participant\|Yatzy" Sources/SyLibGameNight   # must be empty
```

Then, **two physical devices on a FaceTime call.** The simulator cannot deliver
SharePlay sessions.

**Matched versions — no regression.** Both devices on this build. Verify inventory
**1.3, 1.4** (join via banner and via SharePlay button), **4.1–4.4** (seat claim,
pending claim, claim-ID fallback, leave and rejoin), **5.2** (unknown kind — the
dispatch path moved), **7.2** (rematch does not overwrite the previous match —
verify on the guest too), and **7.3** (history sync).

**Mismatched versions — this is the payoff.** Put the current App Store build on
one device and this build on the other. This is the first real exercise of the
version-mismatch UI:

- The **new** device shows "Can't join Game Night" when it is the guest.
- The **new** device shows the inline warning in table setup when it is the host,
  with `versionMismatchedCount` reflecting the declined joiner.
- The **old** device shows nothing — it predates that code. Expected.
- End the session and start a matched one. **The host warning must be gone** —
  `versionMismatchedCount` resets in `tearDownSession`.
- Confirm the rejection happens at `hello`, before any `TableStatePayload` decode
  is attempted. The log should show the version mismatch line, not a decode error.

**Commentary settings still work.** Host changes the pack, guest joins, guest
receives it. Host changes it, ends the session, starts a new one — the change
persists (it must not reset on teardown).

---

## 7. Definition of done

- [ ] `SyLibGameNight` target and product exist, depending only on `SyLibCore`.
- [ ] The eight types in §2 are in the package and `public`, with public inits.
- [ ] Zero references to `SyLibScoring`, `Match`, `Participant`, or `Yatzy` in
      the package. Grep and confirm.
- [ ] `GameNightSessionKind` has four cases; SyFive's `GameNightMessageKind` has
      thirteen, with unchanged raw values.
- [ ] `TableStatePayload` carries `appSettings: Data?`; the three commentary
      properties are gone from `GameNightSession`.
- [ ] The "deliberately not reset on teardown" comment survives the move.
- [ ] `currentProtocolVersion == 2`; `HelloPayload` carries both versions;
      `appProtocolVersion` is 1 in SyFive.
- [ ] `GameNightSession`, `GameNightActivity`, `GameNightLogBuffer`, and all four
      views are **still in SyFive**, unmoved.
- [ ] Mismatched-version testing done in both directions.
- [ ] Report: every symbol made public, and anything that resisted the split.
