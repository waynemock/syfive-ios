# Game Night Phase 3b — extract `GameNightTableView`

**Scope:** `sylib-swift` (`SyLibGameNight`) and `SyFive`.
**Prerequisite:** Phase 3a shipped — `SeatClaimSheet`, `GameNightHelpSheet`,
`GameNightSharingSheet`, `InitialsCircle`, and `SeatRosterEntry` are in the
package, and `GameNightScreens.swift` exists in SyFive.

This is the last extraction, and unlike 3a it is design work. `TableSettingView`
(320 lines) is a composing screen — the same shape as `DiceAreaView` — so the
generic seating UI comes *out* of it rather than the whole file moving.

**Required reading:** `GameNight-Behavior-Inventory.md`, entries 4.1–4.4 and 7.4.

---

## ⚠️ No visual or behavioural changes

Pixel-identical output. The seating screen is the first thing anyone sees in Game
Night and every affordance in it — the remove button appearing only for your own
seat as a guest, reorder only for the host before the game starts, the "You"
caption — encodes a rule. Do not restyle, relayout, reword, or simplify any
predicate.

---

## 1. What moves

Roughly 140 lines of `TableSettingView` become `GameNightTableView` in the
package.

| Piece | Lines | Note |
|---|---|---|
| `seatsSection` | 83–109 | The list, empty state, `onMove`, `moveDisabled` |
| `versionMismatchSection` | 115–135 | Needs `appName` — names SyFive 3× |
| `claimSection` | 136–150 | Claim button plus the spectator footer |
| `SeatRow` presentation | 228–288 | Initials, name, "You", remove, reorder grip |

`SeatRow`'s **presentation** moves; its `PlayerEditSheet` presentation and
`fetchPlayerEditMode()` do not — see §3.

## 2. What stays in SyFive

- **`StartGameButton`** (238–258) — fetches `GameModel` by
  `ScoringSystemID.yatzy` from `@Environment(\.modelContext)` and calls
  `broadcastMatchStart(gameID:)`. Pure SyFive.
- **`commentarySection`** (152–200) — the pickers and their
  `onCommentarySettingsChanged` hooks. This is the UI half of the
  `appSettings: Data?` split from Phase 2 Step 1; the two should read as one
  decision.
- **The Leave button policy** (33–45), including the comment explaining that
  mid-game Leave must *not* call `leaveSession()` because it would nil
  `localParticipantID` and silence outbound messages. That comment is
  load-bearing — preserve it verbatim where the logic lands.
- **The "End Game Night for Everyone?" alert** (60–68). See §4.
- **`PlayerEditSheet`** presentation and the `modelContext` it needs.
- **`TableSettingView`** itself, as the `NavigationStack` + toolbar host.

---

## 3. The `SeatRow` seam

`SeatRow` is where app and package interleave most tightly. It renders generic
content (initials, name, "You", remove, grip) but also owns a pencil affordance
that presents `PlayerEditSheet` — which needs `PlayerModel`, a `modelContext`,
and `MatchController`.

Split it with a trailing-content slot:

```swift
@ViewBuilder seatTrailing: (SeatSnapshot) -> Trailing
```

The package renders the row and calls `seatTrailing(seat)` for the inline
affordance. SyFive passes the pencil button plus its `.sheet(item:)`
presentation, keeping `fetchPlayerEditMode()` app-side.

⚠️ **The pencil currently sits between the name and the "You" caption**, inside
the inner `HStack`, and only shows when `isLocal && phase == .settingTable`.
Place the slot at that exact position, and let SyFive decide when to render
anything — the package must not know why the slot is sometimes empty.

---

## 4. Two open questions — decide before building

### 4.1 Does the toolbar belong in the package?

`TableSettingView`'s toolbar holds Leave, Help, and Start. Leave and Help are
generic in shape; Start is entirely SyFive.

**Recommendation: keep the whole toolbar app-side.** A package view that owns a
toolbar forces every consumer into the same `NavigationStack` structure, and
`GameNightTableView` becomes hard to embed anywhere else — a Mac sidebar, a
Sideral screen that already has its own chrome. The package renders `List`
content; the app hosts and decorates it.

That means `GameNightTableView` is a `List`-content view, not a `NavigationStack`.
Say so in its doc comment, since it's the kind of thing a caller assumes wrongly.

### 4.2 Who owns "End Game Night for Everyone?"

**Recommendation: the app.** The package exposes `onLeave` and nothing more.

The alert's copy, its destructive-role button, and the `endSession()` +
`dismiss()` pairing are policy. More importantly the *decision* is policy — SyFive
branches three ways on role and phase, including the mid-game case that must not
call `leaveSession()`. Sideral will have its own rules about abandoning a game in
progress.

Package-owning the alert would mean pushing that whole decision tree through the
boundary to reproduce today's behaviour.

If you disagree with either recommendation after building it, say so in your
report rather than changing course silently.

---

## 5. The API

```swift
/// The Game Night seating list: seats, claim affordance, and version warnings.
///
/// Renders `List` content only — no `NavigationStack`, no toolbar. The host app
/// supplies navigation chrome, the start control, and any app-specific settings
/// via the `appSettings` slot.
public struct GameNightTableView<Settings: View, Trailing: View>: View {
    public init(
        seats: [SeatSnapshot],
        localSeatClaimID: UUID?,
        phase: GameNightPhase,
        role: GameNightRole,
        appName: String,
        accentColor: Color,
        versionMismatchCount: Int,
        lastMismatchedVersion: Int?,
        lastMismatchKind: GameNightSession<…>.VersionMismatchKind?,
        currentTransportVersion: Int,
        currentAppVersion: Int,
        onClaimSeat: @escaping () -> Void,
        onMoveSeat: @escaping (IndexSet, Int) -> Void,
        onRemoveSeat: @escaping (SeatSnapshot) -> Void,
        @ViewBuilder appSettings: @escaping () -> Settings,
        @ViewBuilder seatTrailing: @escaping (SeatSnapshot) -> Trailing
    )
}
```

⚠️ **`VersionMismatchKind` is currently nested inside `GameNightSession`, which is
generic over `Activity`.** Referencing it from a non-generic view means naming a
generic parameter for no reason. **Move it to a top-level `public enum
VersionMismatchKind`** in the package as part of this change, and leave a
`typealias` on `GameNightSession` if any call site depends on the nested spelling.

Passing both current-version values in — rather than reading
`GameNightEnvelope.currentProtocolVersion` inside the view — keeps the view free
of any assumption about which app is hosting it. The app already knows both.

**`onRemoveSeat` takes the whole `SeatSnapshot`, not the ID.** The existing
closure branches on role: host removes the seat, guest leaves the session. Handing
back the seat lets the app make that call with full context, exactly as it does
today at lines 96–102.

### Predicates to preserve exactly

```swift
isLocal    = seat.seatClaimID == localSeatClaimID
canRemove  = phase == .settingTable && (role == .host || isOwnSeat)
canReorder = role == .host && phase == .settingTable
moveDisabled(role != .host || phase != .settingTable)
```

Empty state: `"Claim a seat to join the table"`, secondary, italic.
Claim section shows only when `localSeatClaimID == nil`, with the spectator
footer under the same condition. Header is `"Table"` in `accentColor`.

---

## 6. SyFive after the change

`TableSettingView` drops to roughly 180 lines: `NavigationStack`, toolbar, the
Leave decision tree, the end-session alert, `commentarySection`,
`StartGameButton`, and the sheet presentations. It calls `GameNightTableView`
with the slots filled.

Put the construction in `GameNightScreens.swift` alongside the 3a wrappers if it
reads better there — the injection mapping (`accentColor`, `appName`, seat
colour resolution) is already in that file.

---

## 7. Verify

```bash
swift build && swift test
grep -rn "SwiftData\|PlayerModel\|GameModel\|MatchController\|PlayerEditSheet\|Commentary\|Theme\|SyFive" \
  Sources/SyLibGameNight    # must return nothing
```

Two physical devices on a FaceTime call. This screen is where seat behaviour
lives, so the seat entries matter most:

- **4.1** — guest claims a seat; appears on every device within a second.
- **4.2** ★ — guest joins via **Messages** and claims a seat *before the host
  joins*. The claim must survive.
- **4.3** ★ — claim acknowledged after a stale local ID; guest keeps their seat
  highlight.
- **4.4** — guest leaves and rejoins; seat released, session continues for others.
- **7.4** — host ends the session mid-match; guests are told, not left hanging.

Then walk the affordance matrix, which is easy to break and easy to miss:

| As | Phase | Expect |
|---|---|---|
| Host | settingTable | Remove on every seat; reorder grips; Start enabled at 2+ seats |
| Host | inProgress | No remove, no reorder |
| Guest | settingTable | Remove on **own seat only**; no grips; no Start |
| Guest, unseated | settingTable | Claim button and spectator footer visible |
| Guest, seated | settingTable | Claim section hidden |

Also: the pencil affordance appears only on your own seat before the game starts,
and editing your player still updates the seat on every device
(`updateOwnSeat`). And with a deliberately mismatched build, the version warning
appears with the correct direction and names the app correctly.

---

## 8. Definition of done

- [ ] `GameNightTableView` in `Sources/SyLibGameNight/Views/`, rendering `List`
      content with no `NavigationStack` or toolbar.
- [ ] `VersionMismatchKind` promoted to top level in the package.
- [ ] Zero references to SwiftData, `PlayerModel`, `GameModel`,
      `MatchController`, `PlayerEditSheet`, `Commentary*`, `Theme`, or `SyFive`
      in the package.
- [ ] All four predicates in §5 byte-identical to today.
- [ ] The mid-game Leave comment preserved verbatim in SyFive.
- [ ] `TableSettingView` still in SyFive, ~180 lines, owning toolbar, alert,
      commentary, and Start.
- [ ] Inventory 4.1–4.4 and 7.4 verified on two devices, plus the full affordance
      matrix.
- [ ] Report: whether you kept both §4 recommendations, and anything that
      resisted the slot boundary.
