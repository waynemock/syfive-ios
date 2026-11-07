# Game Night Phase 3 — move the views into `SyLibGameNight`

Revised after Phase 2 landed. Supersedes the earlier Phase 3 draft.

**Prerequisite:** Phase 2 complete, including the three follow-up fixes
(`lastMismatchKind`, `appProtocolVersion` as an init parameter, test-target
dependency).

**Required reading:** `GameNight-Behavior-Inventory.md`, entries 4.1–4.4.

---

## 0. What changed since the first draft

**`TableSettingView` is not a component.** The first draft treated all four views
as movable with injection. Reading the file properly after Phase 2, it is a
*composing screen* — the same shape as `DiceAreaView`, not `DiceFairnessView`:

- takes `matchModel: MatchController` and passes it down to `SeatRow`
- `StartGameButton` fetches `GameModel` by `ScoringSystemID.yatzy` from
  `@Environment(\.modelContext)` and calls `gameNight.broadcastMatchStart(gameID:)`
- `SeatRow` holds `MatchController`, `GameNightController`, a `modelContext`, and
  presents `PlayerEditSheet`
- the Leave button encodes SyFive's host/guest/phase policy, including a comment
  about `leaveSession()` nil-ing `localParticipantID` mid-game

That is app policy composing generic pieces. Moving it wholesale with slots would
mean pushing five or six callbacks and two `@ViewBuilder`s through the boundary
just to preserve behaviour — a redesign, not a move.

**So Phase 3 splits in two.** 3a is a genuine move of the parts that are already
generic. 3b extracts a `GameNightTableView` from `TableSettingView`, the way
`DiceTrayView` came out of `DiceAreaView`. Ship 3a first.

Three smaller changes since the draft: `TableSettingView` gained
`versionMismatchSection` (~25 lines, package-shaped but naming SyFive three
times), the commentary pickers gained `onCommentarySettingsChanged` hooks, and
line counts moved to 903 total.

---

## 1. The two hard dependencies

Unchanged from the draft, and both still apply.

### 1.1 Theme

Every view reads `@Environment(\.theme)`, and **every use is `primaryAccent`** —
11 in the help sheet, 3 plus two `Theme(...)` constructions in the sharing sheet,
2 plus `InitialsCircle`'s resolution in table setting. `Theme` is app-local and
does not move.

One init parameter covers all of it, as `DiceFairnessView` did:

```swift
public init(…, accentColor: Color)
```

### 1.2 Roster

`SeatClaimSheet` does `@Query(sort: \PlayerModel.name)`; `TableSettingView` runs
`FetchDescriptor<PlayerModel>` and `FetchDescriptor<GameModel>`.

`PlayerModel` lives in `SyLibScoringData`, so **the dependency now genuinely
resolves** — which makes this warning more load-bearing than when it was
hypothetical. **Do not add it.** It would mean every seated game inherits
SwiftData and the scoring schema, and a board game with pieces instead of
scorecards may keep its own roster entirely.

```swift
/// One selectable player in the seat-claim roster.
///
/// `accentColor` is resolved by the app — the package has no theme system and
/// cannot turn `themeID` into a colour. `themeID` travels separately because it
/// goes on the wire in `SeatSnapshot.displayThemeID`.
public struct SeatRosterEntry: Identifiable, Sendable {
    public let id: UUID          // the app's player identity
    public let name: String
    public let initials: String
    public let themeID: String
    public let accentColor: Color

    public init(id: UUID, name: String, initials: String,
                themeID: String, accentColor: Color)
}
```

`availablePlayers`' filtering (drop archived, drop already-seated) moves app-side
— "archived" is a SyFive concept.

---

# Phase 3a — the straightforward move

~600 lines. No new abstractions beyond `SeatRosterEntry`.

## ⚠️ No visual or behavioural changes

Pixel-identical output. Do not restyle, relayout, or reword. The help sheet's
copy in particular is the accumulated answer to "why can't my friend join" —
change nothing except the `appName` substitutions.

## 3a.1 `InitialsCircle`

Currently defined at `TableSettingView.swift:300`. It resolves
`Theme.ThemeType(rawValue: themeID)` to a colour — rendering is generic,
resolution is not.

Move it to its own file, taking a `Color` directly:

```swift
public struct InitialsCircle: View {
    public init(initials: String, color: Color)
}
```

Keep the `@ScaledMetric` sizes (32 / 11) exactly. Both remaining call sites in
`TableSettingView` resolve the colour app-side and pass it in.

## 3a.2 `GameNightHelpSheet` (255)

The highest-value file in the whole extraction and the easiest. Only
`theme.primaryAccent` (11×) and two `SyFive` literals.

```swift
public struct GameNightHelpSheet: View {
    public init(appName: String, accentColor: Color)
}
```

Delete its vestigial `import SyLibScoring` — it uses no scoring types.

## 3a.3 `GameNightSharingSheet` (205)

`theme.primaryAccent` (3×) plus two `Theme(...)` constructions. `import UIKit` is
fine; the module is already `#if os(iOS)`.

```swift
public struct GameNightSharingSheet: View {
    public init(appName: String, accentColor: Color, …)
}
```

Also delete its vestigial `import SyLibScoring`. Report each `Theme(...)` site you
convert and any app-name copy you find.

## 3a.4 `SeatClaimSheet` (123)

Three app dependencies:

- **`InitialsCircle`** — resolved by 3a.1.
- **`PlayerEditSheet(mode:matchModel:onCreated:)`** needs a `MatchController` and
  stays in SyFive. The "New Player" flow becomes a callback.
- **`@State private var dummyMatchModel = MatchController()`** exists only to
  satisfy that sheet, and disappears with it.

```swift
public struct SeatClaimSheet: View {
    public init(
        roster: [SeatRosterEntry],
        accentColor: Color,
        onClaim: @escaping (SeatRosterEntry) -> Void,
        onCreatePlayer: (() -> Void)?
    )
}
```

The sheet no longer takes `GameNightController`. `onClaim` fires and SyFive calls
`gameNight.claimSeat(...)`. `onCreatePlayer` only signals intent — SyFive presents
`PlayerEditSheet` itself and, on creation, calls `claimSeat` and dismisses. That
keeps the escaping-closure dance out of the package.

If that split fights SwiftUI's sheet presentation, use a `@ViewBuilder` slot for
the creation sheet instead and say so in your report. Either is acceptable; do
not leave `PlayerEditSheet` referenced from the package.

⚠️ **The two previews build an in-memory `ModelContainer` of `PlayerModel`.**
Rewrite them with plain `SeatRosterEntry` arrays — the package must not reference
SwiftData.

## 3a.5 SyFive call-site layer

Add `App/GameNight/Views/GameNightScreens.swift` holding the wrappers that bind
package views to app state: the `PlayerModel` → `SeatRosterEntry` mapping, the
`accentColor: theme.primaryAccent` supply, and `appName: "SyFive"`.

This is the manager-wrapper house rule applied to views — it keeps the injection
mapping in one place instead of scattered across call sites, and 3b will reuse it.

## 3a.6 Verify

```bash
swift build && swift test
grep -rn "SwiftData\|PlayerModel\|MatchController\|PlayerEditSheet\|Theme\|SyFive" \
  Sources/SyLibGameNight     # must return nothing
```

Two physical devices on a FaceTime call:

- **4.1** — guest claims a seat; visible on every device within a second.
- **4.2** ★ — guest joins via **Messages** and claims a seat *before the host
  joins*. The claim must survive. The old failure was a dead end recoverable only
  by restarting Game Night.
- **4.3** ★ — claim acknowledged after a stale local ID; guest keeps their seat
  highlight.
- **4.4** — guest leaves and rejoins.
- **New player during claim** — create a player from the seat-claim sheet and
  confirm they get seated. This path was rewritten, not moved, so it is the
  likeliest regression.
- **Help sheet** — open and read it through; `appName` substitutes correctly and
  no section lost its formatting.

Confirm every preview in the moved files still renders.

---

# Phase 3b — extract `GameNightTableView`

Design work, not a move. Scope it properly once 3a has shipped; this section is
the shape, not a brief.

`TableSettingView` (320) splits the way `DiceAreaView` did.

**Generic, moves to the package:**

- `versionMismatchSection` (~25) — reads only session state. Needs `appName`,
  since its message names SyFive three times. After Fix 1 it reads
  `session.appProtocolVersion`, so it carries no SyFive types.
- `claimSection` — the claim button and the spectator footer.
- `SeatRow`'s presentation: initials circle, name, local marker, reorder and
  remove affordances.
- Seat list plumbing: `moveSeat`, `removeSeat`, edit mode.

**Stays in SyFive:**

- `StartGameButton` — fetches `GameModel` by `ScoringSystemID.yatzy` and calls
  `broadcastMatchStart(gameID:)`. Pure SyFive.
- `PlayerEditSheet` presentation from `SeatRow`, and the `modelContext` it needs.
- `commentarySection` — the pickers and their `onCommentarySettingsChanged`
  hooks. This is the UI half of the `appSettings: Data?` split from Phase 2
  Step 1; the two should read as the same decision.
- The Leave button's host/guest/phase policy, including the comment about
  `leaveSession()` nil-ing `localParticipantID` mid-game.
- The "End Game Night for Everyone?" alert.

**Likely shape:**

```swift
public struct GameNightTableView<Settings: View, Trailing: View>: View {
    public init(
        seats: [SeatSnapshot],
        localSeatClaimID: UUID?,
        phase: GameNightPhase,
        role: GameNightRole,
        versionMismatchCount: Int,
        versionMismatch: (version: Int, kind: VersionMismatchKind)?,
        appName: String,
        accentColor: Color,
        onClaimSeat: () -> Void,
        onMoveSeat: (IndexSet, Int) -> Void,
        onRemoveSeat: (UUID) -> Void,
        @ViewBuilder appSettings: () -> Settings,
        @ViewBuilder seatTrailing: (SeatSnapshot) -> Trailing
    )
}
```

`seatTrailing` is what lets SyFive attach its pencil-to-edit affordance without
the package knowing `PlayerEditSheet` exists.

Two open questions for 3b, both better decided with Sideral's seating screen at
least sketched: whether the toolbar (Leave, Help, Start) belongs inside the
package view or stays in the app's `NavigationStack`, and whether the package
should own the "End Game Night for Everyone?" confirmation or just expose
`onLeave`.

---

## 2. Definition of done — Phase 3a only

- [ ] `InitialsCircle`, `SeatRosterEntry`, `GameNightHelpSheet`,
      `GameNightSharingSheet`, `SeatClaimSheet` in
      `Sources/SyLibGameNight/Views/`.
- [ ] Zero references to SwiftData, `PlayerModel`, `MatchController`,
      `PlayerEditSheet`, `Theme`, or `SyFive` in the package.
- [ ] No moved view takes `GameNightController`; all take values and callbacks.
- [ ] `appName` substituted in the help sheet; all other copy byte-identical.
- [ ] Vestigial `import SyLibScoring` removed from both sheets.
- [ ] Previews rewritten without `ModelContainer`.
- [ ] `GameNightScreens.swift` created in SyFive.
- [ ] `TableSettingView` still in SyFive, working, using the moved
      `InitialsCircle` with an app-resolved colour.
- [ ] Inventory 4.1–4.4 verified on two devices, plus the new-player path.
- [ ] Report: the `onCreatePlayer` shape you settled on, each `Theme(...)` site
      converted, and anything that resisted injection.
