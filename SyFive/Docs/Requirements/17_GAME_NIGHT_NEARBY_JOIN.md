# Game Night: join by bringing iPhones together (SharePlay over AirDrop)

**Status:** **v2.1: Task 17.4 to build; 17.1, 17.2 and 17.3 built; S1 to S15 open on TestFlight.**
Version 2.1, 13 November 2026. In SyFive 1.2.0 (Pops, 6 November 2026). v2.0 makes advertising a
choice the host makes (§2.6), because the first TestFlight bump left neither iPhone as host (§9,
12 November 2026). Every question is ruled (§2). There is no throwaway spike: Pops can't test
with two iPhones before TestFlight, so **the TestFlight build is the spike** (§6, Pops, 7 November
2026). If S2 fails there, the modifier switches to C; if neither works, 17 comes out of 1.2.0.
Rewrites the note once filed as `Docs/SyLib/27_SHAREPLAY_NEARBY.md` (3 November 2026).

**Scope:**
- **SyFive:** `syfive-ios` on `sylib-reintegration`.
- **SyLib:** `sylib-swift` on `syfive-integration`; the shared pieces go in `SyLibGameNight` (§2.3).
- **Syderal:** inherits the SyLib piece and can adopt it later. Its compatibility check waits for
  Syderal's next release, like the rest of this round's SyLib work (26 §12).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A`, `00B`, `16_GAME_NIGHT_PROXIMITY_MUTE.md`,
this document.

---

## Supersessions

None. Game Night's session layer, payloads and versions (D-131, D-156), Proximity Mute (D-GNP-001 to
D-GNP-022) and the entry controls (D-140) stand. This adds a way to **start** a session, and
changes nothing once one exists.

**v2.0 (13 November 2026)** revises D-172 (advertising is no longer automatic) and D-174 (the
hint's copy) in place, and adds D-213 to D-216. The payloads and versions still stand; v2.0
changes only how a bump-started session decides who hosts (§2.8).

---

## 1. Why

Game Night runs on Messages and FaceTime with SharePlay. A session, once going, stays connected all
evening. But for people at the same table, starting one is heavy. Since iOS 17, bringing two iPhones
together can start a SharePlay activity (the NameDrop gesture). The system creates the Messages
group, and the session that results is the kind SyFive already handles.

---

## 2. Locked decisions (Pops, 6 November 2026)

**2.1 It ships in 1.2.0, and the Messages group is accepted** (D-171). Joining this way makes iOS
create a group Messages conversation for the table; there's no way around it, and it's fine for
couch play. `GameNightActivity` becomes `Transferable`. The session pipeline doesn't change.

**2.2 How the activity is advertised; a hint explains the gesture** (D-172; *v2.0:* when it is
advertised moved to §2.6–2.7). The system needs the screen
to carry the activity. Two ways, in order:
- **A:** a hidden `ShareLink` carrying the activity, if iOS still offers the prompt for a hidden
  link. Apple documents hiding it only on visionOS, so the spike's **S2** decides.
- **C:** otherwise a UIKit responder whose `activityItemsConfiguration` holds an `NSItemProvider`
  with the activity registered (`registerGroupActivity(_:)`), through a small representable.
  Apple's documented path, with nothing visible.

A visible SharePlay button (v1.0's option B) is excluded (§7).

**2.3 It lives in SyLib's Game Night** (D-173). The advertising and the hint go in
`SyLibGameNight`, so Syderal can adopt them. SyFive supplies its activity and the condition.

**2.4 Only when the host chooses Tap to Play** (D-172, *v2.0*). *v1.x advertised whenever Game
Night was idle and no local match was in progress; superseded by §2.6–2.7, because every idle
phone advertised and none of them knew it was the host.* Advertising now starts only from Start
Game Night, which is offered only before or after a game (D-140), so a phone passed across the
table during pass-and-play still raises nothing. The choice sheet appears where `beginHosting` is
called today, so anything that runs before it today still runs before the sheet.

**2.5 The hint, in the Game Night help sheet** (D-174). *v2.0 body copy is Claude's draft (rec.);
Pops to confirm before 17.3.* The heading and first line are Pops's, verbatim:
- A new section in SyLib's `GameNightHelpSheet`, in the part about starting a game night, after
  "Start with a call or a conversation":
  - Heading: **Sitting together?**
  - Body (*v2.0*): **Tap Start Game Night and choose Tap to Play, then hold your iPhone near a
    friend's iPhone. Theirs offers to join, even if \(appName) isn't open, and Messages makes a
    group for the table. If nothing appears, check Settings › General › AirDrop › Bringing
    Devices Together.**
  - *v1.x body, retired:* "With \(appName) open, hold your iPhone near a friend's iPhone. Yours
    offers to start Game Night, theirs offers to join, …\"
- The sheet's first line (`GameNightHelpSheet.swift` 62) changes from "…you need one of these open
  with your players:" to **"…you need one of these open with your players, or be sitting together
  (see below):"**.

**2.6 On iPhone, Start Game Night offers a choice** (D-213, *v2.0*, Pops, 13 November 2026). A
two-button sheet from SyLib (`GameNightStartChoiceSheet`), with enough copy that the host knows
what each one does. Copy is Claude's draft (rec.); Pops to confirm before 17.3:
- Title: **Start Game Night**
- **Tap to Play**: "Everyone's at the table. Hold your iPhone near a player's iPhone and theirs
  offers to join, even if \(appName) isn't open."
- **FaceTime or Messages**: "Someone's somewhere else, or you're already on a call. Choose a
  FaceTime call or a Messages conversation and invite everyone at once."
- Footer: "Whoever starts Game Night is the host."
- Toolbar: **Cancel**.

FaceTime or Messages runs today's `beginHosting` unchanged. On iPad (no SharePlay over AirDrop)
Start Game Night goes straight to the picker, as today. The reconnect paths ("Resume as Host",
`onHostReconnect`) stay on the picker.

**2.7 Tap to Play advertises from a waiting sheet; only the host's phone advertises** (D-214,
*v2.0*). Tap to Play calls SyLib's new `beginNearbyHosting()`: the device prepares as host (as
`beginHosting` does), mints a host token (§2.8), and shows SyLib's
`GameNightNearbyWaitingSheet`, which carries the hidden `ShareLink` itself, so the link is on
screen exactly while the host is waiting. Copy (Claude's draft, rec.):
- Title: **Bring iPhones Together**
- Body: "Hold this iPhone near a player's iPhone. Theirs offers to join Game Night, even if
  \(appName) isn't open. Once they're in, anyone else at the table can join from the Messages
  group iOS makes."
- Button: **Cancel Game Night** (destructive). The sheet can't be swiped away.

Advertising stops when the host cancels, when a session arrives, or when the app goes to the
background (which cancels, so a stale host preparation can't claim an unrelated session later).
**No timeout** (Pops, 13 November 2026). Guests' phones advertise nothing. Once the first guest
is in, advertising has stopped; further players join through the Messages group iOS creates, as
in v1 (S5). S14 records what iOS does if a third phone bumps anyway; it's an observation, not a
design input.

**2.8 The phone that chose Tap to Play hosts; a host token is the backstop** (D-215, *v2.0*,
Pops, 13 November 2026). Normally the host is decided as it is for the picker: `prepareAsHost()`
sets the pending flag on that phone only. The backstop covers two people both choosing Tap to
Play, where both phones would be waiting to host:
- `GameNightActivity` carries `hostToken: UUID?`. The advertising phone mints it in
  `beginNearbyHosting()` and keeps it on `GameNightSession`; the activity on the waiting sheet is
  built from it, so a redraw never makes a new token.
- A session carries exactly one activity. In `configureSession`, a phone holding a nearby token
  hosts only if the session's activity carries that token. The phone whose activity iOS shared
  finds its token; the other finds a token it never minted and becomes a guest.
- Precedence: a persisted host flag (reconnect) wins first; then a token comparison when both
  tokens exist; otherwise the pending flag, so the picker path is unchanged.
- *Why:* on 12 November 2026 two iPhones, both idle with SyFive open, both advertised under
  v1.x. Neither had called `prepareAsHost()`, so `configureSession` made both guests (§3, §9).

**2.9 Guests need nothing open** (D-216, *v2.0*, Pops, 13 November 2026). The system's join prompt
appears on the guest's iPhone and launches \(appName), whether or not it was open. Assumed; S10
confirms. If it's wrong, only the copy in §2.5–2.7 changes.

---

## 3. What SyFive and SyLib have (read 6 November 2026)

- **The activity:** `App/GameNight/GameNightActivity.swift` 7,
  `nonisolated struct GameNightActivity: GroupActivity, Codable`. Every `GroupActivity` gets a
  default `transferRepresentation` from GroupActivities (iOS 17+), so `Transferable` needs no
  body, as Apple's `BoardGameActivity` shows.
- **No lobby.** Game Night starts from SyLib's `GameNightMenuSection` and
  `GameNightLeadingControlButton` on the game screen (D-140). `ContentView+GameNight.swift` 15:
  `var gameNightEntry: GameNightEntryState { GameNightEntryState(session: gameNight.session) }`.
- **Incoming sessions:** SyLib's `GameNightSession` loops `Activity.sessions()`
  (`GameNightSession.swift` 262). A bump-started session arrives there like any other.
- **Proximity Mute** ranges from seat claiming (D-GNP-010), once per match (D-GNP-006). The bump
  happens before any session exists. A table joined this way is in one room, so its guests will
  usually be muted, which is correct (D-GNP-004).
- **The help sheet** is SyLib's, `SyLibGameNight/Views/GameNightHelpSheet.swift`, and uses
  `\(appName)`.
- **iPhone only**, per Apple. iPads join through the Messages group, as remote players do.
- **Role assignment (read 12 November 2026, v2.0):** `GameNightSession.configureSession` sets
  `takingHostRole = pendingHostSessionActivation || persistedAsHost`. Only `prepareAsHost()` sets
  the pending flag, and only `beginHosting(activity:onNeedsConversation:onReadyToSeat:)` calls
  it, so under v1.x a bump-started session made **both** phones `.guest`: each sent `hello` and
  waited 15 s for a `tableState` nobody sent. The `sessions()` loop is now at
  `GameNightSession.swift` 333.
- **Entry points (v2.0):** `ContentView+GameNight.swift`'s `leadingNavButton` (`.start`) and
  `gameNightMenuSection` (`onStart`) both call `gameNight.beginHosting(onNeedsConversation:
  onReadyToSeat:)`. The reconnect paths (`onHostReconnect`, "Resume as Host") call it too and
  don't change.
- **Pending state (v2.0):** `prepareAsHost()` sets `isSessionPending`, so `GameNightEntryState`
  reads `.invitePending` and the leading control is `.inviteSent`, which opens
  `GameNightPendingSheet` (its copy is about Messages).

---

## 4. Task 17.1 · SyLib: the nearby invite and the hint

- **Inputs:** §2, §3; SyLib `Docs/GAME_NIGHT.md` (### Views);
  `Sources/SyLibGameNight/Views/GameNightHelpSheet.swift`.
- **Change (SyLib), new `Sources/SyLibGameNight/Views/GameNightNearbyInvite.swift`:**

  ```swift
  #if os(iOS)
  import SwiftUI
  import GroupActivities

  public extension View {
      /// Lets iOS offer `activity` when this iPhone is brought close to another iPhone (SharePlay
      /// over AirDrop), while `isAdvertising` is true. Draws nothing and takes no touches.
      /// iPhone only, per Apple; elsewhere it does nothing. The activity must be `Transferable`
      /// (a `GroupActivity` gets a default representation, so the conformance needs no body).
      /// `title` is the share preview's title: pass the activity's own metadata title (it can't be
      /// read here, because `GroupActivity.metadata` is async).
      func gameNightNearbyInvite<Activity: GroupActivity & Transferable>(
          _ activity: Activity, title: String, isAdvertising: Bool) -> some View {
          background {
              if isAdvertising {
                  ShareLink(item: activity, preview: SharePreview(title))
                      .hidden()
                      .accessibilityHidden(true)
                      .allowsHitTesting(false)
              }
          }
      }
  }
  #endif
  ```

  This is option A (§2.2). The rest of the app sees only this modifier, so a switch to C changes
  this file alone. **v1.3:** the title is a parameter. v1.2 read `activity.metadata.title`, which
  doesn't compile: `GroupActivity.metadata` is an `async` property on this SDK (found by 17.1's
  agent, 7 Nov 2026). Pops chose the caller-passed title over an async read.
- **Change (SyLib), `GameNightHelpSheet.swift`:**
  - Line 62's text becomes, verbatim: "Game Night plays alongside FaceTime or Messages. Before you
    can start a game night, you need one of these open with your players, or be sitting together
    (see below):"
  - In `preSessionSections`, **after** the `if !isEligibleForGroupSession { … }` block and
    **before** the "Hosting a game night" section, a new section shown whenever the sheet is in
    `.preSession`, in the first section's style:

    ```swift
    Section {
        Text("With \(appName) open, hold your iPhone near a friend's iPhone. Yours offers to start Game Night, theirs offers to join, and Messages makes a group for the table. If nothing appears, check Settings › General › AirDrop › Bringing Devices Together.")
            .listRowBackground(Color.clear)
    } header: {
        Text("Sitting together?")
            .foregroundStyle(accentColor)
    }
    ```
- **Docs (SyLib):** `GAME_NIGHT.md`'s Views reference documents `gameNightNearbyInvite(_:title:isAdvertising:)`:
  what it does, iPhone only, the `Transferable` conformance with no body, and that an app should
  advertise only while Game Night is idle and no local match is in progress (SyFive's rule, §2.4).
- **Tests:** none. It's a view modifier and copy; SyLib's total stays 1560.
- **Must not touch:** every other part of the help sheet; `GameNightSession`; the entry views;
  any app.
- **Done when:** SyLib builds and its suite passes at 1560 (1 skipped); SyFive builds. Syderal's
  check waits for its next release (D-173).

## 5. Task 17.2 · SyFive: advertise before and after a game

- **Inputs:** §2, §3; SyLib `GAME_NIGHT.md` (`gameNightNearbyInvite`). Runs after 17.1.
- **Change:**
  - `App/GameNight/GameNightActivity.swift` 7: `nonisolated struct GameNightActivity:
    GroupActivity, Codable, Transferable` (no body for `Transferable`). Add
    `static let title = "SyFive Game Night"`, and `metadata` sets `m.title = Self.title` in place
    of the literal, so the title has one source.
  - `Views/ContentView+GameNight.swift`, next to `gameNightEntry` (15):

    ```swift
    /// Bump to join is offered only while Game Night is idle and no local match is in progress
    /// (17 §2.4, D-172).
    var isNearbyInviteAdvertised: Bool {
        guard case .idle = gameNightEntry else { return false }
        return !model.hasStarted || model.isGameOver
    }
    ```
  - `Views/ContentView.swift`: in the body's modifier chain, beside `.tint(theme.primaryAccent)`
    (230), add `.gameNightNearbyInvite(GameNightActivity(), title: GameNightActivity.title,
    isAdvertising: isNearbyInviteAdvertised)`.
- **Must not touch:** `GameNightController`'s session code, the entry views, anything else.
- **Done when:** the build and SyFive's suite pass (20).

## 5A. Task 17.3 · SyLib: nearby hosting, the host token, the two sheets (v2.0)

- **Inputs:** §2.5–2.9, §3; `Sources/SyLibGameNight/GameNightSession.swift`,
  `GameNightEntryState.swift`, `Views/GameNightSharingViews.swift`,
  `Views/GameNightNearbyInvite.swift`, `Views/GameNightHelpSheet.swift`; `Docs/GAME_NIGHT.md`.
- **Change (SyLib), new `Sources/SyLibGameNight/GameNightHostToken.swift`:**

  ```swift
  #if os(iOS)
  import Foundation

  /// An activity that can carry the host's token for a Tap to Play start (17 §2.8, D-215).
  /// Read with a dynamic cast in `configureSession`, so `GameNightSession`'s generic constraint
  /// doesn't change and an app that doesn't adopt it is unaffected.
  public protocol GameNightHostTokenCarrying {
      var hostToken: UUID? { get }
  }
  #endif
  ```
- **Change (SyLib), `GameNightSession`:**
  - `prepareAsHost()` gains `@discardableResult` and returns whether it took effect (`false`
    when its guard ignores the call). No other change to it.
  - New state: `public private(set) var nearbyHostToken: UUID?` and
    `public private(set) var isAdvertisingNearby = false`.
  - New `public func beginNearbyHosting()`: if `prepareAsHost()` returns `true`, set
    `nearbyHostToken = UUID()` and `isAdvertisingNearby = true`, and log the token.
  - `cancelHostPreparation()` also clears `nearbyHostToken` and `isAdvertisingNearby`, before
    its existing guard.
  - `configureSession`: `takingHostRole` comes from a new pure function, and both tokens go in
    the existing log line. Then clear `nearbyHostToken` and `isAdvertisingNearby`.

    ```swift
    /// 17 §2.8, D-215. A persisted host flag (reconnect) wins; a device holding a nearby token
    /// hosts only if the session's activity carries that token; otherwise the pending flag
    /// decides, as before.
    static func takesHostRole(persistedAsHost: Bool, pendingHost: Bool,
                              localToken: UUID?, activityToken: UUID?) -> Bool {
        if persistedAsHost { return true }
        if let localToken, let activityToken { return localToken == activityToken }
        return pendingHost
    }
    ```
    `activityToken` is `(incomingSession.activity as? any GameNightHostTokenCarrying)?.hostToken`.
- **New views (SyLib), `Views/GameNightSharingViews.swift`:**
  - `GameNightStartChoiceSheet(appName:accentColor:onTapToPlay:onInvite:onCancel:)`: the §2.6
    sheet, copy verbatim; two full-width buttons, each a title over its line of copy.
  - `GameNightNearbyWaitingSheet<Activity: GroupActivity & Transferable>(activity:title:appName:
    accentColor:onCancel:)`: the §2.7 sheet, copy verbatim, `.interactiveDismissDisabled()`, and
    `.gameNightNearbyInvite(activity, title: title, isAdvertising: true)` on its content, so the
    link is on screen while the sheet is.
- **Change (SyLib), `GameNightHelpSheet.swift`:** the "Sitting together?" body becomes §2.5's
  v2.0 copy, verbatim. Nothing else in the sheet.
- **Docs (SyLib):** `GAME_NIGHT.md` documents `beginNearbyHosting()`, `nearbyHostToken`,
  `isAdvertisingNearby`, `GameNightHostTokenCarrying`, `takesHostRole`'s precedence, the two
  sheets, and that an app advertises only from the waiting sheet (no longer from its own view
  while idle).
- **Tests (SyLib):** `takesHostRole`, seven cases (*v2.1:* v2.0 said six, but listed seven):
  persisted wins, three cases (matching, mismatched and no tokens); tokens match → host; tokens differ → guest even when pending; local token with no
  activity token → the pending flag; no local token → the pending flag (picker path). Suite total
  +7.
- **Must not touch:** payloads and versions, the messenger, seats, Proximity Mute,
  `beginHosting`, `GameNightSharing.present`, `GameNightEntryState`, any app.
- **Done when:** SyLib builds and its suite passes (previous total + 7); SyFive builds
  unchanged. Syderal's check waits for its next release (D-173).

## 5B. Task 17.4 · SyFive: the choice, Tap to Play and the token (v2.0)

- **Inputs:** §2.6–2.9, §3; SyLib `GAME_NIGHT.md` after 17.3. Runs after 17.3.
- **Change:**
  - `App/GameNight/GameNightActivity.swift`: add `var hostToken: UUID? = nil` and conform to
    `GameNightHostTokenCarrying`. `metadata` and `title` unchanged.
  - `App/GameNight/GameNightController.swift`: `func beginNearbyHosting()` beside
    `prepareAsHost()`, passing through to the session.
  - Remove `isNearbyInviteAdvertised` (`ContentView+GameNight.swift`) and the
    `.gameNightNearbyInvite(…)` modifier (`ContentView.swift` 232). Advertising now lives on the
    waiting sheet (§2.7).
  - Start Game Night (`leadingNavButton`'s `.start` and `gameNightMenuSection`'s `onStart`): on
    iPhone (`UIDevice.current.userInterfaceIdiom == .phone`), present `GameNightStartChoiceSheet`;
    elsewhere call `beginHosting` exactly as today. The reconnect paths don't change.
  - Choice sheet: **Tap to Play** dismisses it, calls `gameNight.beginNearbyHosting()`, and after
    `GameNightSession.seatingSheetDelay` presents the waiting sheet. **FaceTime or Messages**
    dismisses it and, after the same delay, calls `beginHosting` as today (the picker can't be
    presented under a dismissing sheet). **Cancel** dismisses it.
  - Waiting sheet: `GameNightNearbyWaitingSheet(activity: GameNightActivity(hostToken:
    gameNight.session.nearbyHostToken), title: GameNightActivity.title, appName: "SyFive", …)`;
    Cancel Game Night calls `gameNight.cancelHostPreparation()` and closes it.
  - When a session arrives (`onChange(sessionActivationCount)`) with the waiting sheet up, close
    it first and present the table after `seatingSheetDelay`, as `beginHosting` does for the
    picker.
  - The `.inviteSent` control (and the menu's cancel-invite path) reopens the waiting sheet
    while `gameNight.session.isAdvertisingNearby`; otherwise `GameNightPendingSheet`, as today.
  - `scenePhase` → `.background` while `isAdvertisingNearby`: `cancelHostPreparation()` and
    close the waiting sheet.
- **Must not touch:** `GameNightController`'s session code beyond the pass-through, the
  reconnect paths, payloads, the entry views.
- **Done when:** the build and SyFive's suite pass (20).

## 6. Validation, on TestFlight (two iPhones)

The TestFlight build is the spike (Pops, 7 November 2026). Run with the deferred Game Night pass
(26 §12). iOS 17 or later, Bringing Devices Together on.

| # | Check | Pass |
|---|---|---|
| S1 | *v2.0:* host taps Start Game Night › Tap to Play, then brings the iPhones together | The guest is offered to join; the host's Game Night log shows `role=host`, the guest's `role=guest`; both reach the table; a full match plays |
| S2 | **The same: does the prompt appear at all with the hidden link?** | **If not, 17.1's modifier switches to C (§2.2) in the next TestFlight build** |
| S3 | During a game, and while at the table | No prompt |
| S4 | Lock and unlock either phone; background briefly; the guest leaves the room | The session holds |
| S5 | A third, remote player through the group's Messages thread | Joins as a normal guest |
| S6 | Bringing Devices Together off | No prompt; Start Game Night still works |
| S7 | The existing Messages and FaceTime starts | Unchanged |
| S8 | Proximity Mute on a bump-joined table (UWB iPhones) | Guests muted as D-GNP-004 rules |
| S9 | Game Night Help before a session | "Sitting together?" appears with §2.5's v2.0 body; the first line ends "or be sitting together (see below):" |
| S10 | *v2.0:* the guest's SyFive is closed when the phones meet | The guest's iPhone still offers to join and opens SyFive at the table (§2.9); if not, only copy changes |
| S11 | *v2.0:* the waiting sheet is up when the phones meet | The prompt appears (the link is on the sheet now; read with S2) |
| S12 | *v2.0:* both people choose Tap to Play, then bring the iPhones together | Exactly one host; the logs show one token match and one mismatch (§2.8) |
| S13 | *v2.0:* Cancel; background while waiting; bump two phones that never chose Tap to Play | Advertising stops; idle phones raise no prompt |
| S14 | *v2.0:* a third phone bumps the host after the first guest joined | Observation only: record what iOS does. Design stays: extra players join through the Messages group (§2.7) |
| S15 | *v2.0:* FaceTime or Messages from the choice sheet; Start Game Night on iPad; Resume as Host | Picker flow unchanged; iPad shows no choice; reconnect unchanged |

If neither A nor C produces the prompt, 17 comes out of 1.2.0 and the rest ships.

## 7. Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| A visible SharePlay button | A second start control for one feature (Pops, 6 Nov 2026) |
| MultipeerConnectivity | Drops when the app backgrounds or the phone locks; finicky reconnection; a local-network prompt and Bonjour entries. Rejected twice |
| Custom networking, a Bonjour lobby | The same costs, duplicating a session layer that works |
| An NFC-style tap | Not available to third-party apps |
| Advertising during a game | Every pass of a phone would offer a new session (§2.4) |
| Advertising automatically while idle (v1.x) | Every idle phone advertised, iOS shared an arbitrary one's activity, and neither phone knew it was host (S1, 12 Nov 2026) |
| A timeout on Tap to Play | Advertising lasts until Cancel, a session or the background (Pops, 13 Nov 2026) |
| Electing the host by lowest participant ID | The host is the person who chose to host; the token settles the one tie (§2.8) |

## 8. Ledger rows (paste into `00_DECISION_LEDGER.md`)

| ID | Ruling | Source |
|---|---|---|
| D-171 | **Game Night can start by bringing iPhones together (SharePlay over AirDrop), in 1.2.0.** `GameNightActivity` is `Transferable`; the session layer, payloads and versions are unchanged. The group Messages conversation iOS creates is accepted. | `17 §2.1` (Pops, 6 Nov 2026) |
| D-172 | **Advertising is a choice, not automatic** (v2.0). The activity is advertised only after the host picks Tap to Play (D-213, D-214), by a hidden `ShareLink` on SyLib's waiting sheet if iOS honors it (S2, S11), otherwise by a UIKit `activityItemsConfiguration` responder. No visible SharePlay button. *Was:* advertised whenever Game Night was idle and no local match was in progress. | `17 §2.2, §2.4` → `17 v2.0 §2.6–2.7` (Pops, 13 Nov 2026) |
| D-173 | **The advertising and its hint live in `SyLibGameNight`**, so Syderal can adopt them; Syderal's check waits for its next release. | `17 §2.3` |
| D-174 | **The hint is a "Sitting together?" section in SyLib's Game Night help sheet** (copy in `17` §2.5; v2.0: Tap to Play, guests need nothing open), **and the sheet's first line adds "or be sitting together (see below)".** | `17 §2.5` → `17 v2.0 §2.5` |
| D-213 | **On iPhone, Start Game Night opens a two-button sheet: Tap to Play, or FaceTime or Messages**, each with a line saying what happens (`17` §2.6). iPad goes straight to the picker; the reconnect paths stay on the picker. | `17 v2.0 §2.6` (Pops, 13 Nov 2026) |
| D-214 | **Tap to Play advertises from a waiting sheet with Cancel; only the host's phone advertises.** It stops on Cancel, when a session arrives, or when the app goes to the background. No timeout. Further players join through the Messages group iOS creates. | `17 v2.0 §2.7` (Pops, 13 Nov 2026) |
| D-215 | **The phone that chose Tap to Play hosts, with a host token as backstop.** `GameNightActivity` carries `hostToken`; a phone holding a nearby token hosts only if the session's activity carries it, so two phones that both chose Tap to Play still get one host. A persisted host flag (reconnect) still wins; the picker path is unchanged. *Why:* v1.x left both bump-joined phones as guests (S1, 12 Nov 2026). | `17 v2.0 §2.8` (Pops, 13 Nov 2026) |
| D-216 | **Guests need nothing open:** the system's join prompt launches the app on the guest's iPhone (assumed; S10 confirms, and only copy changes if not). | `17 v2.0 §2.9` (Pops, 13 Nov 2026) |

## 9. Results log

| Task / check | Date | Result | Notes |
|---|---|---|---|
| 17.3 | 13 Nov 2026 | **Done** (checked by Claude against the SyLib tree, 13 Nov 2026; the +7 was the spec's miscount, fixed in v2.1, and the agent's seven tests stand; the agent's choices below are accepted) | SyLib `main`. The suite is **1603 passed, 1 skipped (1678 runs), 0 failed**, against 1596 passed, 1 skipped (1671 runs) before, on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`; totals come from the result bundles. That is **+7, not +6**: §5A's list is 5 cases if "persisted wins (with matching, mismatched and no tokens)" counts as one, and 7 if it counts as three. The agent wrote 7, one per token variant, and Pops picks any merge. syfive-ios builds unchanged, with no new SyLibGameNight warnings; Syderal isn't built (D-173). **Files:** new `GameNightHostToken.swift` (the protocol, verbatim); `GameNightSession.swift` (the entry and COMPLETE log lines show `localToken=`/`activityToken=`, `prepareAsHost()` is `@discardableResult -> Bool`, adds `nearbyHostToken`, `isAdvertisingNearby` and `beginNearbyHosting()` (logs the token), `cancelHostPreparation()` clears both before its guard, and `configureSession` uses `takesHostRole` verbatim with the dynamic cast, then clears both); `Views/GameNightSharingViews.swift` (`GameNightStartChoiceSheet` and `GameNightNearbyWaitingSheet`, copy verbatim, the waiting sheet `.interactiveDismissDisabled()` with the modifier on its content, plus a choice-sheet `#Preview`); `Views/GameNightHelpSheet.swift` ("Sitting together?" body only, §2.5 v2.0); `Docs/GAME_NIGHT.md` (the new state and method rows, the arrival precedence, a new "Nearby hosting" section, both sheets, advertising only from the waiting sheet); new `Tests/…/GameNightHostRoleTests.swift` (7). **Choices to review:** each sheet's buttons call `dismiss()` and then their closure, as `GameNightPendingSheet` does; on the choice sheet the two titles are in `accentColor` and Cancel is top-leading; on the waiting sheet `accentColor` is applied as `.tint`. No preview for the waiting sheet, since the package has no `Transferable` activity outside tests. The visual and on-device checks are Pops's. GIT: `git status --short`, `git branch --show-current` (read-only) |
| 17.1 | 7 Nov 2026 | Done (checked by Claude against the SyLib tree) | `gameNightNearbyInvite(_:title:isAdvertising:)` in `GameNightNearbyInvite.swift`, hidden `ShareLink` in the background; help sheet line 62 and the "Sitting together?" section (87–93) verbatim; `GAME_NIGHT.md` documents it. The first attempt stopped on `GroupActivity.metadata` being async (v1.3). Claude fixed one line in `GAME_NIGHT.md`'s example (`entryState == .idle` can't compile: `.idle` carries `isEligible`). SyLib 1560; Syderal skipped (D-173) |
| 17.2 | 7 Nov 2026 | Done (checked by Claude against the tree) | `GameNightActivity: GroupActivity, Codable, Transferable` with `static let title`, used by `metadata`; `isNearbyInviteAdvertised` in `ContentView+GameNight.swift`; the modifier at `ContentView.swift` 231. SyFive 20 expected |
| S1 (first run) | 12 Nov 2026 | **Failed** | Both iPhones were idle with SyFive open, so both advertised. Neither had called `prepareAsHost()`, so `configureSession` made both `.guest` (reported as both acting as host; the logs' `role=` line confirms which). Led to v2.0 |
| 17.4 | | **Open** | v2.0 task; runs after 17.3 |
| S1–S15 | | **Open: TestFlight, two iPhones** (§6) | S2 and S11 decide A or C |

## Changelog

| Version | Date | Change |
|---|---|---|
| 0 | 3 Nov 2026 | Note filed as `Docs/SyLib/27_SHAREPLAY_NEARBY.md` |
| 1.0 | 6 Nov 2026 | Rewritten in house style, as `Requirements/17`; corrected against the tree |
| 2.1 | 13 Nov 2026 | 17.3 done. §5A's test count corrected to seven (v2.0 listed seven cases and said six); the agent's 7 tests stand (Claude) |
| 2.0 | 13 Nov 2026 | Advertising becomes a choice: on iPhone, Start Game Night offers Tap to Play or FaceTime or Messages (§2.6); only the host's phone advertises, from a waiting sheet, until Cancel, a session or the background, with no timeout (§2.7); the phone that chose Tap to Play hosts, with a host token as backstop (§2.8); guests need nothing open (§2.9). Tasks 17.3 and 17.4; S10–S15; D-172 and D-174 revised, D-213 to D-216 added. Cause: the first TestFlight bump left neither phone as host (§9) (Pops) |
| 1.3 | 7 Nov 2026 | The modifier takes `title:`: `GroupActivity.metadata` is async and can't be read in a view (17.1's agent). SyFive's activity gets `static let title`, used by its metadata and passed in (Pops) |
| 1.2 | 7 Nov 2026 | No throwaway spike (no two-iPhone testing before TestFlight): 17.1 and 17.2 written, with the hidden link (A); S1 to S9 run on TestFlight; C is the fallback (Pops) |
| 1.1 | 6 Nov 2026 | Moved into 1.2.0; every question ruled (§2), including the hint's copy; `Transferable` needs no body (GroupActivities' default representation); spike written as Task 17.0; 17.1 and 17.2 follow it; rows D-171 to D-174 |
