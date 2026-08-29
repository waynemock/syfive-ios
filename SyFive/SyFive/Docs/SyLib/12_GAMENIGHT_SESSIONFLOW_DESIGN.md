# Game Night — session-flow and alerts extraction

The last reusability pass on Game Night. Four changes, in value order. The first
two matter; the third is optional; the fourth is unrelated cleanup that showed up
while looking.

---

## 0. What I am *not* recommending

Three of the five types you asked about should stay exactly as they are:

| Type | Lines | Verdict |
|---|---:|---|
| `SeatEditButton` | 44 | Leave |
| `SyFiveGameNightTableView` | 60 | Leave |
| `SyFiveSeatClaimSheet` | 55 | Leave |

These 159 lines are pure app↔package translation and every line earns its place.
`SeatEditButton` owns `PlayerEditSheet` and the SwiftData fetch precisely so
`SyLibGameNight` never sees either — it is the `seatTrailing` slot working as
designed. `SyFiveGameNightTableView` maps theme colours, app name, and version
constants into the package view; `SyFiveSeatClaimSheet` maps `PlayerModel` to
`SeatRosterEntry`.

There is nothing generic left in them. Extracting further would move SyFive's
specifics behind another layer of indirection without removing them.

**This is the wrapper layer succeeding, not unfinished work.** Sideral writes its
own 159-line equivalent, and that is correct — those lines *are* the app-specific
part.

---

## 1. `session.beginHosting(...)` — the duplicated hosting flow

**Highest value in this pass.** `GameNightSharing.present` appears **four times**
in `ContentView+GameNight.swift`, and so does `500_000_000`. The same fifteen
lines, four times:

```swift
gameNight.prepareAsHost()
GameNightSharing.present(
    onRequiresConversation: { gameNight.cancelHostPreparation(); … },
    onDismissed: {
        if gameNight.isSessionActive && gameNight.phase == .settingTable {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard gameNight.isSessionActive && gameNight.phase == .settingTable else { return }
                …
            }
        }
    },
    onCancelled: { gameNight.cancelHostPreparation() }
)
```

Every part of that is hard-won and none of it is obvious:

- **The 500 ms sleep.** With Messages SharePlay the session can arrive while the
  UIKit modal is still on screen; presenting a SwiftUI sheet before the dismiss
  animation finishes fails silently.
- **The re-check after the sleep.** The session can vanish during the delay.
- **`cancelHostPreparation()` on two of three paths**, so a later incoming session
  does not wrongly claim this device as host.

Four copies is four chances to drift, and Sideral would be a fifth written from
scratch.

### The API

On `GameNightSession`, in `SyLibGameNight`:

```swift
/// Prepares this device as host and presents the system SharePlay picker.
///
/// Handles the UIKit/SwiftUI presentation race: with Messages SharePlay the
/// session can arrive while the picker is still on screen, so `onReadyToSeat`
/// fires only after the picker's dismiss animation completes and only if the
/// session is still active and still in `.settingTable`.
///
/// Host preparation is cancelled automatically on both failure paths, so a later
/// incoming session does not wrongly claim this device as host.
@MainActor
public func beginHosting(
    onNeedsConversation: @escaping () -> Void,
    onReadyToSeat: @escaping () -> Void
)
```

`GameNightSharing.present` moves inside it. Callers drop from fifteen lines to
three.

### Migration

Four call sites in `ContentView+GameNight.swift`:

| Site | `onNeedsConversation` | `onReadyToSeat` |
|---|---|---|
| `leadingNavButton` | `showsInviteInstructions = true` | `presentGameNightSheetOrAlert()` |
| `gameNightMenuSection` | `showsInviteInstructions = true` | `presentGameNightSheetOrAlert()` |
| Session-ended alert → Reconnect | clear `pendingResume*` | `showsGameNight = true` |
| Reconnect alert → Resume as Host | clear `pendingResume*` | `showsGameNight = true` |

⚠️ The two reconnect sites also clear `pendingResumeMatchID` / `pendingResumeGameID`
on failure. That is app state — it stays in the closures, not in the package.

⚠️ **Keep the 500 ms constant exactly.** It is a measured value for a UIKit
dismiss animation. Do not round it, do not make it a parameter, do not replace it
with a completion callback that "should" be more correct.

**Verify:** start Game Night from the nav button, from the menu, and via both
reconnect alerts. In each case the seating sheet must appear after the picker
dismisses. Then cancel the picker in each and confirm no session is left pending
and a subsequent join arrives as guest, not host.

---

## 2. `GameNightAlertModifier` — split three ways

162 lines, five alerts, **nine `@Binding`s**. Three of the five alerts are pure
package.

### 2a. Collapse the bindings first

Nine bindings is the reason this is unpleasant to move. Before splitting anything,
give the package a state holder:

```swift
@MainActor @Observable
public final class GameNightAlertState {
    public var showsSessionEnded = false
    public var showsGuestReconnect = false
    public var pendingGuestReconnectMatchID: UUID?
    public var showsHostReconnect = false
    public var showsCancelSession = false

    public init() {}
}
```

`showsGameNightLocalConflictAlert`, `showsGameNight`, `pendingResumeMatchID`, and
`pendingResumeGameID` stay app-side — the first is SyFive's local-game conflict,
the rest are SyFive's resume plumbing.

Sideral then declares one `@State private var alerts = GameNightAlertState()`
instead of getting five `@State` flags correct.

### 2b. Move the three generic alerts

Into `SyLibGameNight` as a `ViewModifier`:

```swift
public extension View {
    /// Presents the session-lifecycle alerts: version mismatch, end/cancel
    /// session, and guest reconnect.
    func gameNightAlerts<Activity: GroupActivity>(
        session: GameNightSession<Activity>,
        state: GameNightAlertState,
        appName: String,
        appStoreURL: URL
    ) -> some View
}
```

Covering:

- **"Can't Join Game Night"** — already fully generic. Currently hardcodes
  `AboutView.appStoreURL` and "SyFive" three times; both become parameters.
- **"End Game Night?" / "Cancel Game Night Invite?"** — the three-way branch on
  `isSessionPending` / `role == .host` / else. Entirely session state.
- **"Reconnect to Game Night?"** (guest) — `prepareForGuestReconnect(matchID:)`
  and a "Play Locally" cancel. Entirely session state.

Also move the `.onChange(of: session.sessionEndedDuringPlay)` that raises the
session-ended flag.

### 2c. Host-reconnect alert — inject the lookup

"Game Night ended" is generic *except* `fetchHostReconnectIDs()`, which queries
`MatchModel` and `GameModel` by `ScoringSystemID.yatzy`. Add a closure to the
modifier:

```swift
hostReconnectIDs: @escaping () -> (matchID: UUID, gameID: UUID)?
```

Returning `nil` hides the Reconnect button, exactly as today.

⚠️ The Reconnect button body calls `beginHosting` from §1. Sequence the two
changes so this alert is migrated after `beginHosting` exists.

### 2d. Stays in SyFive

"Local Game in Progress" — SyFive's copy about setting aside the current game and
resuming from History.

**Verify:** all five alerts still appear in the same situations. Specifically:
end a session mid-match as guest (session-ended, no Reconnect button); as host
with a game in progress (session-ended *with* Reconnect); force-quit a guest and
relaunch (guest reconnect); mismatched builds (can't join). Inventory 7.4 and 5.1.

---

## 3. `TableSettingView` toolbar — optional

~50 of its 154 lines are generic: the Leave button's three-way branch, the
"End Game Night for Everyone?" alert, and the help-context computation.

I recommended in Phase 3b that the toolbar stay app-side so `GameNightTableView`
does not force a `NavigationStack` on consumers, and **that still holds**. But
the *content* could be package-provided without owning the container:

```swift
public struct GameNightLeaveButton<Activity: GroupActivity>: View {
    public init(session: GameNightSession<Activity>,
                role: GameNightRole,
                phase: GameNightPhase,
                onDismiss: @escaping () -> Void)
}
```

⚠️ **The mid-game branch is load-bearing and looks like a bug.** A guest leaving
mid-game must *not* call `leaveSession()`, because that nils `localParticipantID`
and silences every outbound message — it just dismisses. The comment explaining
this must move with the code.

`StartGameButton` stays in SyFive: it fetches `GameModel` by
`ScoringSystemID.yatzy`. The generic half is `.disabled(seats.count < 2)`, which
is not worth a type.

**I would defer this one.** It is the smallest win of the three, and Sideral's
seating screen will say more about whether a shared Leave button is the right
shape than reasoning will.

---

## 4. Unrelated: `Theme.ThemeType(rawValue:)` appears 28 times

Not a package question — pure SyFive duplication, three occurrences inside
`GameNightScreens.swift` alone:

```swift
Theme(type: Theme.ThemeType(rawValue: someID) ?? .midnight,
      colorScheme: colorScheme).primaryAccent
```

One helper collapses all 28:

```swift
extension Theme {
    /// Resolves a stored theme ID to its accent colour, falling back to midnight.
    static func accent(forThemeID id: String, colorScheme: ColorScheme) -> Color
}
```

Cheap, and it removes the `?? .midnight` fallback being independently written 28
times — which is exactly how one of them ends up defaulting to something else.

---

## 5. Recommended order

1. **§1 `beginHosting`** — biggest win, self-contained, and §2c depends on it.
2. **§2a state holder**, then **§2b** the three generic alerts, then **§2c** the
   host-reconnect injection.
3. **§4 theme helper** — independent, do it whenever.
4. **§3 toolbar** — defer until Sideral has a seating screen.

After §1 and §2, `ContentView+GameNight.swift` drops from 443 lines to roughly
250, and Sideral inherits the session-lifecycle alerts and the hosting flow
rather than rediscovering the 500 ms race.

---

## 6. What Sideral still writes itself

Worth stating so the boundary is clear: the ~159-line wrapper layer
(`SeatEditButton`, table-view wrapper, seat-claim wrapper), its own
`StartGameButton`, the local-game-conflict alert if it has one, and its own
commentary section if its table settings differ.

That is the right amount of app-specific code. The goal was never zero.
