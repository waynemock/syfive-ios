# SyFive — Game Night Proximity Mute Design Spec

*Design authority for co-located commentary suppression: UWB proximity detection,
the per-device commentary mute control, and the required `SyLibCommentary` broadcast fix.*

> **Status:** Design agreed. All open decisions resolved. This document is the
> implementation brief for the Xcode Claude agent. Read the whole document before
> starting; the SyLib changes and the SyFive changes interlock.

---

## 0. Supersessions

| Document | Effect |
|---|---|
| `12_COMMENTARY.md` (or equivalent commentary spec) | **Amended.** Adds a per-device mute layer beneath the existing host-authoritative relay. The relay itself is unchanged. |
| `00_DECISION_LEDGER.md` | **Append only.** New rows in §11. |
| SyLib `Docs/GameNight.md` | **Amended.** New `GameNightProximity` component, new session-owned message kinds, transport version 2 → 3. |
| SyLib `Docs/Commentary.md` | **Amended.** `isMuted` semantics clarified: local speech only, never suppresses broadcast. |

Nothing is superseded outright.

---

## 1. Why this exists

Game Night commentary is host-authoritative echo. The host's `CommentaryEngine`
generates a line, `onWillSpeak` broadcasts the text over SharePlay, and every guest
calls `receiveText(_:tier:)` to speak **the same string** with their own local voice.

When two players are in the same physical room — a couple on a couch, siblings sharing
a dorm — both devices speak the identical utterance a few hundred milliseconds apart.
This is not two commentators talking over each other; it is one utterance doubled and
smeared. It reads as an echo or a stutter, not as ambience.

Dice audio is deliberately unaffected. Every device continues to play its own roll
sounds; only spoken commentary is suppressed.

This spec adds a per-device commentary mute, initialised automatically by UWB proximity
ranging, overridable by one tap, and scoped to a single match.

---

## 2. Three findings from the code read that shape the design

These are load-bearing. The design is different because of them.

### 2.1 Commentary is echo, not independent generation

`ContentView+Commentary.swift` forces `level: .playByPlay` on guests and nils out
`commentaryEventSink`, because the host already applied the level gate before
broadcasting. Guests never generate their own lines.

**Consequence:** the mute is a pure output-stage decision. Nothing upstream — event
generation, tier gating, line selection — needs to know about proximity.

### 2.2 `isMuted` currently suppresses the broadcast — this is a bug

`SyLibCommentary/CommentaryEngine.swift`:

```swift
private func speak(text: String, tier: CommentaryEventTier) {
    guard !isMuted else { return }
    onWillSpeak?(text, tier)
    …
}
```

The mute guard fires **before** the broadcast. A muted host therefore stops broadcasting
entirely and the whole table goes silent.

This is already wrong independent of this feature: a host who sets `soundMode == .off`
today silences every guest, even though guests have their own sound settings. Broadcast
is a session concern; mute is a local-speaker concern. The coupling is accidental.

**Fixed in §4.1.** Without it the host cannot have a mute button at all.

### 2.3 Seats are not devices

`SeatSnapshot` carries `seatClaimID`, `seat`, `playerID`, display fields, and `isLocal`.
It carries **no device identity**, and `isLocal` means "an additional local seat on the
claiming device" — one device may hold several seats.

UWB ranges devices, not seats. A rule phrased as "lowest seat in the cluster speaks"
cannot be evaluated by a guest, because no guest knows which device owns which seat.
The host does — it sees `senderID` on every inbound `seatClaim`.

**Consequence:** resolution is host-arbitrated (§3, D-GNP-002). This also matches the
existing architecture, where the host is already authoritative for table state, match
state, and commentary text.

---

## 3. Locked decisions

### D-GNP-001 — Suppress commentary only; dice audio is untouched

Every device continues to play its own roll, settle, and hold sounds. The mute applies
solely to `CommentaryEngine` speech output.

*Rationale:* the flam is an artifact of identical speech. Room ambience from dice is
desirable and, being percussive and non-identical in timing, does not read as an echo.

### D-GNP-002 — Host-arbitrated resolution

Guests report pairwise distance observations to the host. The host clusters devices,
picks one speaker per cluster, and broadcasts the verdict. Guests do not compute
clusters.

*Rationale:* forced by §2.3 — only the host holds the device→seat mapping. Also keeps
clustering in one place rather than having N devices independently derive it from
partial data.

### D-GNP-003 — Cluster membership by union-find over sub-threshold pairs

Proximity is not reliably transitive: A–B close, B–C close, A–C ambiguous is a real
reading. Any pair under threshold merges their clusters. A `nil` distance contributes
nothing; it never splits a cluster.

*Rationale:* the ambiguous edge does not matter because the transitive link has already
joined the set. Treating `nil` as "far" would fragment real rooms.

### D-GNP-004 — Speaker selection: host's cluster always speaks; other clusters by lowest seat

The cluster containing the host device always speaks, and the host device is its
speaker. Every other cluster elects the device holding the lowest seat index among its
members. Single-device clusters trivially elect themselves.

*Rationale:* the host's phone is the one that started the session and is most likely on
the table. Lowest-seat is deterministic, requires no negotiation, and needs no UI.

### D-GNP-005 — Guests start muted; unmute-only transitions

Every guest device begins each match with commentary muted. The proximity verdict can
only ever **unmute**. A device never transitions from speaking to silent as a result of
proximity.

*Rationale:* going quiet mid-match is invisible and harmless; starting to talk mid-roll
reads as a glitch. Starting muted also covers the window before the verdict arrives —
two seconds of unexpected silence is invisible, two seconds of unexpected speech is not.

### D-GNP-006 — One-shot resolution, no mid-match re-evaluation

Ranging resolves once. On resolution — or on timeout — all `NISession`s are invalidated
and ranging does not restart for the remainder of the match. A player who walks to the
kitchen stays as they were.

*Rationale:* live re-evaluation means audio popping on and off as people shift on a
couch. It also means holding the radio open for the whole match.

### D-GNP-007 — 10-second timeout from match start; expiry means unmute

The resolution window opens at match start and closes 10 seconds later. Any device
without a verdict at expiry unmutes.

Ranging itself begins much earlier, at seat claiming (§3, D-GNP-010), so in practice
most verdicts are already in hand before the clock starts.

*Rationale:* a false negative is self-correcting — someone hears the flam and taps. A
false positive is invisible: a remote player never gets commentary and has no idea why.
Erring toward speech is correct.

### D-GNP-008 — Manual tap wins permanently and cancels ranging

A tap on the mute button is ground truth for the rest of the match. Any late-arriving
proximity verdict for that device is discarded, and that device's `NISession`s are
invalidated immediately.

*Rationale:* the automatic guess exists to save a tap. Once the tap happens, the guess
has nothing left to contribute. Cancelling also frees the radio early in the common case.

### D-GNP-009 — Session-scoped, no persistence

Mute state is not persisted. Every match re-guesses.

*Rationale:* a stale verdict from last week's couch would override a correct guess
tonight, and the cost of being wrong is one tap. The player who always wants commentary
on their own device re-taps each session; that is an acceptable trade for zero stored
state.

### D-GNP-010 — Ranging starts at seat claiming, gated on `commentaryEnabled`

Token exchange and ranging begin as soon as the SharePlay session is up and players are
claiming seats — but **only if** the table's commentary toggle is on.

*Rationale (timing):* seats and distances resolve in parallel, so both inputs land
before the first roll. It also places the system permission prompt during seat
selection, when nobody is mid-anything, rather than as the dice are about to fly.

*Rationale (gating):* a Game Night with commentary off will never speak, so ranging is
pure cost. More importantly, a first-time host with commentary off would otherwise see
an unexplained Nearby Interaction permission alert. Gating makes the prompt always
correlate with a feature the user just switched on.

### D-GNP-011 — Seat order locks at match start; verdict arrival time is irrelevant

Speaker election uses the seat map as it stands at match start. If a proximity verdict
arrives after that, it is evaluated against the locked map.

*Rationale:* seats can change during setup — late joiners, reclaims. Distances are
stable; seat ordering is not, until it is. Recomputing election from the locked map is
free; re-ranging is not.

### D-GNP-012 — Threshold 3.0 m, four consecutive sub-threshold readings

A pair is considered co-located when four consecutive readings are below 3.0 m. Both
values live in a tunable config struct, not hardcoded.

*Rationale:* a single stray close reading must not mute a remote player. Four
consecutive readings cost under a second at typical update rates. Same-room versus
different-continent is a trivially easy discrimination; precision is not needed.

### D-GNP-013 — Early resolution on confidence

A device that has four consecutive sub-threshold readings against every peer it needs
does not wait for the timeout — it resolves immediately. The timeout governs only the
ambiguous and no-signal cases.

### D-GNP-014 — The button appears only when commentary could actually play

Visible if and only if **all** of:

1. A Game Night session is active, **or** solo play with commentary enabled;
2. the effective commentary source says enabled — `gameNight.commentaryEnabled` in a
   session (never the local `appSettings.commentaryMode`, which is a solo preference the
   relay path deliberately ignores), `appSettings.commentaryMode == .allGames` outside one;
3. `director.soundMode != .off`.

Any one false → no button.

*Rationale:* a control that does nothing is worse than no control. The button is also
the feature's only indicator, so its presence is what tells the player commentary exists.

### D-GNP-015 — The button is uniform across host and guests

The control means "commentary on this device" everywhere. UWB only sets its initial
state. The host may silence their own phone.

*Rationale:* a button that means the same thing everywhere needs no explanation. Depends
on §4.1.

### D-GNP-016 — No settings surface, no alerts

There is no preference for this feature, and nothing is ever announced. The button is
the indicator, the affordance, and the override.

*Rationale:* the earlier "silent muting reads as a bug" objection does not apply here —
there is no silence. Commentary is playing, from the host's phone, three feet away.
Nothing is missing.

### D-GNP-017 — Game Night commentary settings are seeded, never written back

`ContentView.swift` seeds `gameNight.commentaryEnabled / commentaryPackID /
commentaryLevelRaw` from `appSettings` once at session activation. Changes made at the
table are session-scoped and **never** persist to personal settings.

*Rationale:* changing the personality for one Game Night should not silently change the
host's solo-play default. `commentaryEnabled` already behaved this way; pack and level
did not. See §4.3.

### D-GNP-018 — Non-UWB devices fall through to the timeout

No iPad has ever shipped with UWB — the 2020 iPad Pro was widely expected to and does
not. `NISession.deviceCapabilities.supportsPreciseDistanceMeasurement` returns false on
every iPad and on some iPhones. Those devices produce no readings, hit the 10-second
timeout, and unmute.

Only `supportsPreciseDistanceMeasurement` is used. `supportsDirectionMeasurement` is
reported inconsistently across U1 and U2 hardware and is not needed.

---

## 4. Required SyLib changes

### 4.1 `SyLibCommentary` — decouple broadcast from local mute (**prerequisite**)

In `CommentaryEngine.speak(text:tier:)`, `onWillSpeak?` must fire **before** the
`isMuted` guard:

```swift
private func speak(text: String, tier: CommentaryEventTier) {
    onWillSpeak?(text, tier)
    guard !isMuted else { return }
    …
}
```

Update `Docs/Commentary.md`: `isMuted` suppresses **local speech only** and never
suppresses the `onWillSpeak` broadcast.

**Behavior change to expect:** a host with `soundMode == .off` no longer silences
guests. That is the correction, not a regression.

**Add a regression test:** set `isMuted = true` on an engine with an `onWillSpeak`
handler installed, dispatch an event, assert the handler fired and no utterance was
enqueued.

### 4.2 `SyLibGameNight` — new `GameNightProximity` component

**Module placement is deliberate.** Proximity is a fact about *devices in a session* —
the same layer as roles and seats. `SyLibGameNight` already owns the messenger and the
participant IDs the token exchange needs, and is already iOS-only, so a
`NearbyInteraction` import costs nothing.

It does **not** belong in `SyLibCommentary` (zero dependencies today; must not learn
about SharePlay or UWB) and does **not** belong in `SyLibGameNightMatch` (the timeout
anchors to match start, but that is one method call downward, not a dependency
inversion — the match coordinator already depends on `SyLibGameNight`).

The component's output is a `Bool` per device. The package never mentions commentary.

#### Public surface (sketch — the agent may refine names)

```
@Observable @MainActor
public final class GameNightProximity {
    public struct Config: Sendable {
        public var thresholdMeters: Float          // 3.0
        public var consecutiveReadings: Int        // 4
        public var resolutionTimeout: Duration     // .seconds(10)
    }

    /// True when this device should stay silent. Guests start true, host starts false.
    public private(set) var isSuppressed: Bool

    /// Ranging is only meaningful when the app says a voice may play.
    public func begin(config: Config)              // called at seat claiming, gated by app
    public func openResolutionWindow()             // called at match start — starts the timeout
    public func overrideManually(suppressed: Bool) // manual tap: locks state, cancels ranging
    public func end()                              // teardown; invalidates all NISessions
}
```

#### Wire protocol

Three new session-owned kinds alongside `hello`, `tableState`, `seatClaim`,
`seatRelease`:

| Kind | Direction | Payload |
|---|---|---|
| `proximityToken` | all → all | archived `NIDiscoveryToken` as `Data`, plus sender participant ID |
| `proximityReport` | guest → host | sender ID, peer ID, `isNear: Bool` |
| `proximityVerdict` | host → all | list of participant IDs cleared to speak |

`NIDiscoveryToken` is `NSSecureCoding`, not `Codable`. Archive with
`NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding: true)` and unarchive
on receipt. Tokens are per-session — invalidate and restart means re-exchange.

**Transport version bumps 2 → 3.** `GameNightEnvelope.currentProtocolVersion` must be
incremented. Shipped 1.0 builds cannot join a build carrying this feature; the existing
version-mismatch UI handles that path already and needs no change.

#### Fan-out

`NISession` is one-to-one and symmetric — both sides must be running concurrently, with
no listener/advertiser asymmetry. N devices means N(N−1)/2 pairwise sessions, N−1 per
device. Fine at Game Night scale; do not write the code as if there is one session.

#### Teardown paths (all of them)

Invalidate every `NISession` on: verdict resolved, timeout fired, manual override, match
end, player leaving, SharePlay session dropping, and app backgrounding. A live session
left running past the match surfaces later as a battery complaint with no obvious cause.

Nearby Interaction is foreground-only and invalidates on background regardless; do not
add the Background Modes capability.

### 4.3 `SyFive` — remove the commentary settings write-back

In `ContentView.swift`, `gameNight.onCommentarySettingsChanged` becomes:

```swift
gameNight.onCommentarySettingsChanged = {
    syncCommentaryEngine()
}
```

Delete the `if gameNight.role == .host, let settings = appSettings { … }` block.
`syncCommentaryEngine()` must still fire so the engine picks up the new pack or level
for the current session.

**Two comments go stale and must be corrected in the same pass:**

1. The deleted block's own comment claims it persists "voice/personality/level." Voice
   was never in it — `commentaryVoiceID` lives in `UserDefaults` and is device-local by
   design. Only two of the three were ever written back.
2. The "deliberately NOT reset on teardown" comments in `GameNightPayloads.swift` and
   `GameNightController.swift` become misleading **for the host**. Line ~296 re-seeds all
   three from `appSettings` on every session activation; the carry-over only appeared to
   work because the write-back kept `appSettings` in step. With the write-back gone,
   every Game Night starts from personal settings. The comment still holds for guests,
   whose values arrive from the host's broadcast. Reword to say so.

---

## 5. SyFive UI

### 5.1 Placement

`DiceAreaView`, in the existing `HStack` with the Roll button, **leading** side. Undo
already occupies the trailing slot.

The Roll button is `.frame(maxWidth: .infinity)`; a fixed-width leading sibling takes its
space and Roll absorbs the remainder, so the primary control does not shift when the
toggle appears. Use `.frame(width: rollControlHeight)` to match undo's square footprint.

No reserved dead space — the button appears and disappears like undo already does.

### 5.2 Presentation

- Glyph: `quote.bubble.fill` when speaking, `quote.bubble` when muted. **Not**
  `speaker.slash` — dice audio stays on, and a speaker-slash icon will be read as "mute
  everything" and then reported as a bug the first time someone taps it and still hears
  rolling.
- `.buttonStyle(.bordered)`, secondary tint. It must not read as a second CTA.
- Accessibility label: `"Commentary, on"` / `"Commentary, off"`. The icon alone does not
  distinguish voice from all audio for VoiceOver.

### 5.3 Wiring

`ContentView+Commentary.swift` currently sets
`commentaryEngine?.isMuted = (director.soundMode == .off)` in **two** places (the guest
path and the host/solo path). Factor into one computed property that ORs in the
proximity/manual suppression.

`syncCommentaryEngine()` is a full engine rebuild. A mute toggle must set `isMuted`
directly rather than re-running sync.

### 5.4 Mid-game global audio change

If the global sound setting goes to `.off` mid-match the button disappears. If it
returns, the button reappears **unmuted** — state resets rather than restoring the
pre-mute value, consistent with D-GNP-009.

---

## 6. Privacy and capability

**Info.plist:** `NSNearbyInteractionUsageDescription`. One key. No entitlement, no Xcode
capability toggle.

Write the string in the app's voice. Users read these, and a vague one on a dice game
gets declined:

> SyFive checks whether another player's iPhone is in the same room, so only one device
> speaks the commentary out loud.

**Capability check:** `NISession.deviceCapabilities.supportsPreciseDistanceMeasurement`.

**Declined permission** is indistinguishable from no hardware for our purposes: no
readings, timeout, unmute. Do not re-prompt.

**Verify against current documentation before implementing:** the permission-key
situation changed once around iOS 16, and the U1/U2-equipped device list moves. The
capability check is the runtime source of truth regardless.

---

## 7. Implementation stages

Each stage is independently checkable.

1. **`SyLibCommentary` broadcast fix (§4.1).** Move `onWillSpeak?` above the guard; add
   the regression test; update `Docs/Commentary.md`.
   *Check: muted engine still fires `onWillSpeak`; unit test passes on macOS.*

2. **Settings write-back removal (§4.3).** Delete the block, correct both stale comments.
   *Check: change personality at the Game Night table, end the session, open
   Settings › Commentary — the personal value is unchanged.*

3. **`GameNightProximity` skeleton, no UWB.** Component, config, `isSuppressed`, manual
   override, timeout, teardown wiring. Ranging stubbed to never produce readings.
   *Check: guests start muted, unmute at 10 s after match start, manual tap locks state.*

4. **Mute button (§5).** Visibility rule, placement, glyph, accessibility, `isMuted`
   wiring in both engine paths.
   *Check: button appears only under D-GNP-014's conjunction; tapping toggles speech and
   leaves dice audio alone; host tap does not silence guests.*

5. **Wire protocol + transport bump (§4.2).** Three new kinds, token archive/unarchive,
   host arbitration with union-find, verdict broadcast. Version 2 → 3.
   *Check: protocol round-trip unit tests; a v2 build attempting to join a v3 host
   surfaces the existing mismatch UI.*

6. **Live UWB.** Real `NISession` mesh, capability check, Info.plist key, all teardown
   paths.
   *Check: the two-device matrix in §8.*

---

## 8. Validation matrix

Session lifecycle and UWB both require **physical devices** — no simulator support, and
UWB will not range device-to-Mac. Combined with SharePlay's own hardware requirement,
verification needs two iPhones on a FaceTime call. The guest-guest clustering path
genuinely needs a third.

| # | Scenario | Expected |
|---|---|---|
| 1 | Host + guest, same room | Guest stays muted; host speaks; dice audio on both |
| 2 | Host + guest, out of range | Guest unmutes within the window; both speak |
| 3 | Guest carried out of range mid-match | Guest stays muted (one-shot, D-GNP-006) |
| 4 | Guest taps mute before verdict arrives | Tap wins; verdict discarded; ranging cancelled |
| 5 | Host taps mute | Host silent; **guests still speak** (validates §4.1) |
| 6 | Commentary off at the table | No button anywhere; **no permission prompt**; no ranging |
| 7 | Host enables commentary mid-match | Button appears; no verdict; all devices speak; manual fixes |
| 8 | Guest on iPad | No readings; unmutes at timeout; button present and functional |
| 9 | Permission declined | Same as #8 |
| 10 | Global sound → off → on mid-match | Button hides, reappears unmuted |
| 11 | Three devices, two co-located guests, host remote | Lower-seat guest speaks; other guest muted; host speaks |
| 12 | SharePlay session drops mid-match | All `NISession`s invalidated (verify no residual battery drain) |
| 13 | v2 build joins v3 host | Existing version-mismatch UI, correct "update" direction |

---

## 9. Open decisions

**None.** All decisions in §3 are resolved and locked. The agent must not reopen them.

---

## 10. Invariants quick reference

- `isMuted` suppresses **local speech only** — never the `onWillSpeak` broadcast.
- Guests start **muted**; proximity transitions are **unmute-only**.
- Resolution is **one-shot**: no mid-match re-evaluation, no re-ranging.
- **Manual tap is permanent** for the match and cancels ranging on that device.
- **No persistence.** Every match re-guesses.
- Seat order **locks at match start**; verdict arrival time is irrelevant.
- Ranging is **gated on `commentaryEnabled`** — no commentary, no permission prompt.
- Visibility reads the **session** commentary value on guests, never local `appSettings`.
- Game Night commentary settings are **seeded, never written back**.
- Dice audio is **never** affected.
- The button means the **same thing** on host and guest.
- Every `NISession` is invalidated on **every** teardown path.
- Only `supportsPreciseDistanceMeasurement` is consulted; direction is never used.

---

## 11. Dead ends (do not revisit)

### Companion-device UWB proxy for non-UWB participants

Considered using a player's iPhone or Apple Watch (same iCloud account) to range against
the host on behalf of their iPad, which has no UWB hardware. **Declined.**

The proxy device establishes where the *person* is, but the speaking device is still the
iPad — requiring a device-to-person mapping plus an inter-device channel between a
player's own hardware. That is substantial machinery serving only players who chose the
one device that cannot range. A pocketed phone also sits behind the player's body, the
condition most likely to yield `nil` or inflated distance readings, so the added
complexity buys an unreliable answer.

Non-UWB participants fall back to the manual toggle, which is one tap and adjacent to
the roll button. **Do not revisit without new hardware facts.**

### Guest-guest fan-out declined, then reinstated

An earlier pass proposed ranging guests against the host only, dropping the case of
guests co-located with each other but not the host. That was reconsidered: full mesh is
cheap at Game Night scale and the dorm-room case is real. Recorded so the reduced-scope
version is not mistaken for the intended design.

### Auto / Ask / Never setting

A three-state preference was designed and then cut. The setting only described behavior
the button demonstrates directly, and the question it asked can be answered faster by
tapping than by reading. Cutting it removed a Settings row, a persisted preference, a
non-UWB fallback branch, and a room-voice indicator line. **Do not reintroduce.**

---

## 12. Ledger rows (paste into `00_DECISION_LEDGER.md`)

| ID | Decision | Rationale |
|---|---|---|
| D-GNP-001 | Proximity mute suppresses commentary speech only; dice audio unaffected on all devices | The flam is an artifact of identical speech; percussive dice audio reads as room ambience |
| D-GNP-002 | Proximity resolution is host-arbitrated: guests report distances, host clusters and broadcasts the verdict | `SeatSnapshot` carries no device identity; only the host holds the device→seat mapping |
| D-GNP-003 | Clusters are built by union-find over sub-threshold pairs; `nil` distance never splits a cluster | Proximity is not reliably transitive; treating `nil` as "far" would fragment real rooms |
| D-GNP-004 | Host's cluster always speaks; every other cluster elects its lowest-seat device | Deterministic, no negotiation, no setup UI |
| D-GNP-005 | Guests start muted; proximity transitions are unmute-only | Going quiet mid-match is invisible; starting to speak mid-roll reads as a glitch |
| D-GNP-006 | One-shot resolution; no mid-match re-evaluation or re-ranging | Live re-evaluation pops audio as people shift; holds the radio open all match |
| D-GNP-007 | 10-second timeout from match start; expiry unmutes | False negatives self-correct with one tap; false positives are invisible |
| D-GNP-008 | Manual tap wins permanently for the match and cancels ranging on that device | The guess exists to save a tap; once tapped it has nothing to contribute |
| D-GNP-009 | Mute state is session-scoped, never persisted | A stale verdict would override a correct guess; cost of being wrong is one tap |
| D-GNP-010 | Ranging starts at seat claiming, gated on the table's `commentaryEnabled` | Parallel resolution with seats; keeps the permission prompt correlated with the feature |
| D-GNP-011 | Seat order locks at match start; verdict arrival time is irrelevant | Distances are stable, seat ordering is not until lock |
| D-GNP-012 | Threshold 3.0 m, four consecutive sub-threshold readings, both tunable | One stray reading must not mute a remote player |
| D-GNP-013 | Confident pairs resolve early; the timeout governs only ambiguous and no-signal cases | Common couch case unmutes fast |
| D-GNP-014 | Mute button visible only when session/solo commentary is enabled AND `soundMode != .off`; guests read the session value, never local `appSettings` | A control that does nothing is worse than none; local mode is a solo preference the relay ignores |
| D-GNP-015 | The button is uniform on host and guests: "commentary on this device" | Same meaning everywhere needs no explanation |
| D-GNP-016 | No settings surface, no alerts; the button is the only indicator | There is no silence to explain — commentary is playing from the host's phone |
| D-GNP-017 | Game Night commentary settings are seeded from personal settings at session start and never written back | Changing personality for one Game Night must not change the solo default |
| D-GNP-018 | Non-UWB devices (all iPads, some iPhones) and declined permission fall through to the timeout and unmute | Only `supportsPreciseDistanceMeasurement` is consulted; direction is inconsistent across U1/U2 |
| D-GNP-019 | `SyLibCommentary`: `onWillSpeak` fires before the `isMuted` guard | Broadcast is a session concern, mute is a local-speaker concern; corrects a host with sound off silencing the table |
| D-GNP-020 | Transport version bumps to 3 for the three new proximity message kinds | Existing version-mismatch UI handles the incompatibility |
| D-GNP-021 | Companion-device UWB proxy for iPad participants — DEAD END, do not revisit without new hardware facts | Proxy locates the person, not the speaking device; pocketed phones give unreliable readings |
