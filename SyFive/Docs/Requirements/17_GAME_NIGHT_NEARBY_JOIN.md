# Game Night: join by bringing iPhones together (SharePlay over AirDrop)

**Status:** **v2.12: Built (17.1 to 17.10); S1 to S20 open on TestFlight.** Version 2.12, 13 November 2026. In SyFive 1.2.0 (Pops, 6 November 2026). v2.0 makes advertising a
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

**2.6 On iPhone, Start Game Night offers a choice** (D-213, *v2.8*, Pops, 13 November 2026). A
SyLib sheet (`GameNightStartChoiceSheet`) that asks one question and offers two cards that look
tappable. *v2.0's list-style sheet was hard to read on device: nothing looked like a button and
the copy was too long (Pops, 13 November 2026).* Copy, verbatim:
- Headline, at the top of the content in a large title style: **How do you want to host Game
  Night?**
- Card 1: icon `iphone.radiowaves.left.and.right`, label **Tap to Play**, line **Bring iPhones
  together.**, then (*v2.8*) **Best for just iPhones at the same table.** (*v2.5:* v2.3's "iPads join from the Messages group" is dropped: an iPad joins only
  if someone adds its owner to the group, so the line promised more than it delivers.)
- Card 2: icon `shareplay`, label **FaceTime or Messages**, line **Invite from a call or a chat.**,
  then (*v2.8*) **Best if players aren't at the same table, or iPads are in the mix.**
- *v2.8:* the "Best for" sentence is a second line under the first, in the same secondary style,
  so each card says what it does and when to pick it (Pops).
- Footer under the cards: **You'll be the host.**
- Toolbar: **Cancel**. No navigation title (the headline is the title).

Each card is a full-width rounded-rectangle button with a filled background, the icon in
`accentColor`, the label in a bold headline style and the line in secondary text, with a pressed
state, so it reads as a button. Tap to Play only works iPhone to iPhone; the help sheet carries
that (§2.5). *v2.5:* the sheet is full height, like SyFive's other sheets (no detents; v2.3's
medium detent is dropped, Pops).

FaceTime or Messages runs today's `beginHosting` unchanged. On iPad (no SharePlay over AirDrop)
Start Game Night goes straight to the picker, as today. The reconnect paths ("Resume as Host",
`onHostReconnect`) stay on the picker.

**2.7 Tap to Play advertises from a waiting sheet; only the host's phone advertises** (D-214,
*v2.0*). Tap to Play calls SyLib's new `beginNearbyHosting()`: the device prepares as host (as
`beginHosting` does), mints a host token (§2.8), and shows SyLib's
`GameNightNearbyWaitingSheet`, which carries the hidden `ShareLink` itself, so the link is on
screen exactly while the host is waiting. Copy (Claude's draft, rec.):
- Title: **Bring iPhones Together**
- *Before anyone joins* (v2.5): body "Hold this iPhone near a player's iPhone. Theirs offers to
  join Game Night, even if \(appName) isn't open." Button **Cancel Game Night** (destructive).
- *Once at least one player has joined* (v2.5): body "\(count) players are in. Hold this iPhone
  near the next player's iPhone, or tap Everyone's In." (`count` includes the host.) Button
  **Everyone's In** (prominent). Cancel Game Night is gone at this point; ending a session that
  exists stays with the existing End Game Night controls.
- The sheet can't be swiped away.
- **The icon** (*v2.11*, Pops, 13 November 2026): the Tap to Play card's symbol,
  `iphone.radiowaves.left.and.right`, large (about 96 pt) and centered above the body text in both
  states. The iPhone in the primary color, the radio waves in green, animated with the symbol's
  variable color effect (iterative, dimming inactive layers, repeating) so the waves pulse outward
  in varying shades of green. It ties the sheet to the card the host just tapped and shows the
  phone is "on the air". With Reduce Motion on, it's static (the waves fully green). Decorative:
  hidden from VoiceOver.

**Keep tapping** (*v2.5*, Pops, 13 November 2026). The waiting sheet stays up, and keeps
advertising, after the first guest joins, so each iPhone at the table can tap the host's in turn.
Advertising stops when the host taps Everyone's In, cancels before anyone joins, the match
starts, the session ends, or the app goes to the background (which, before anyone has joined,
cancels, so a stale host preparation can't claim an unrelated session later; after a join, it
only stops advertising). **No timeout** (Pops, 13 November 2026). Guests' phones advertise
nothing. Everyone's In closes the sheet and the host's table opens, as a session arrival does
today.

**Spike-gated (S14).** Whether iOS adds a later bump to the session that's already live is
undocumented. While the host holds a live session and is still advertising, a **different**
session arriving is **ignored and logged** (it must not tear down the table). If S14 shows a later
bump arrives as a separate session, or nothing happens, keep tapping comes out: the waiting sheet
closes on the first join (v2.4 behavior), and the help copy says further players join from the
Messages group iOS makes (S5).

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
- **Done when:** the build and SyFive's suite pass (33; *v2.2:* v2.0 said 20, which was stale).

## 5C. Task 17.5 · SyLib: restyle the choice sheet (v2.3)

- **Inputs:** §2.6 (v2.3); `Sources/SyLibGameNight/Views/GameNightSharingViews.swift`
  (`GameNightStartChoiceSheet`); SyLib `Docs/GAME_NIGHT.md`.
- **Change (SyLib):** rebuild `GameNightStartChoiceSheet`'s body to §2.6: the headline, two card
  buttons (icon, label, line, filled rounded background, pressed state), the footer, Cancel in the
  toolbar, no navigation title, `.presentationDetents([.medium, .large])`. Copy verbatim. Keep
  the init signature and behavior unchanged (each card and Cancel dismiss, then call their
  closure), so SyFive needs no change. Card colors come from `accentColor` and system fills; no
  hard-coded colors. The cards must stay legible at accessibility text sizes (they grow; the
  sheet scrolls at the large detent).
- **Docs (SyLib):** `GAME_NIGHT.md`'s description of `GameNightStartChoiceSheet` follows the new
  layout and copy.
- **Tests:** none (a view).
- **Must not touch:** the waiting sheet, the session, the help sheet, any app.
- **Done when:** SyLib builds and its suite passes unchanged (1603, 1 skipped); SyFive builds
  unchanged. Log it in §9.

## 5D. Task 17.6 · SyLib: keep tapping, and a full-height choice sheet (v2.5)

- **Inputs:** §2.6, §2.7 (v2.5); `GameNightSession.swift`, `Views/GameNightSharingViews.swift`;
  `Docs/GAME_NIGHT.md`.
- **Change (SyLib), `GameNightSession`:**
  - `public private(set) var participantCount = 0`: the live session's `activeParticipants`
    count, set on arrival and updated by the existing participant observation (host and guest);
    0 when there is no session.
  - `configureSession`: when this device takes `.host` **and** a local nearby token matched,
    leave `isAdvertisingNearby` true and keep `nearbyHostToken` (so the advertised activity
    doesn't change). Every other case clears both, as today.
  - **Second-session guard:** at the top of `configureSession`, when a session is already active,
    `role == .host`, `isAdvertisingNearby` is true and the incoming session's id differs, log it
    as `nearby: ignoring second session id=… while advertising (S14)` and return without
    adopting it. Nothing else about session adoption changes.
  - New `public func finishNearbyInvites()`: clears `isAdvertisingNearby` and `nearbyHostToken`,
    and logs. No other effect.
  - Also clear both when `phase` leaves `.settingTable` and at every teardown.
  - `cancelHostPreparation()` is unchanged (still clears both first).
- **Change (SyLib), `GameNightNearbyWaitingSheet`:** add `participantCount: Int` and
  `onEveryoneIn: () -> Void` to the init. With `participantCount < 2` it shows the
  before-anyone-joins state; otherwise the joined state (§2.7, copy verbatim): Everyone's In
  dismisses, then calls `onEveryoneIn`. It still applies `gameNightNearbyInvite(…, isAdvertising:
  true)` in both states.
- **Change (SyLib), `GameNightStartChoiceSheet`:** remove `.presentationDetents`; card 1's line
  becomes "Bring iPhones together." Nothing else.
- **Docs (SyLib):** `GAME_NIGHT.md`: `participantCount`, `finishNearbyInvites()`, the
  advertising lifetime after a join, the second-session guard and that S14 gates it, and both
  sheets' changes.
- **Tests (SyLib):** the second-session guard and the keep-advertising rule as pure decisions,
  like `takesHostRole` (static functions over plain values): keep advertising only for a host by
  token match; ignore a second session only while hosting, active and advertising, with a
  different id. Report the count added.
- **Must not touch:** payloads and versions, seats, Proximity Mute, `beginHosting`, the help
  sheet, any app.
- **Done when:** SyLib builds and its suite passes (1603 + the new tests); syfive-ios is
  expected **not** to build until 17.7 (the waiting sheet's init changes). Log it in §9.

## 5E. Task 17.7 · SyFive: keep tapping (v2.5)

- **Inputs:** §2.7 (v2.5); SyLib `GAME_NIGHT.md` after 17.6. Runs after 17.6.
- **Change:**
  - The waiting sheet gets `participantCount: gameNight.session.participantCount` and
    `onEveryoneIn`, which calls `gameNight.session.finishNearbyInvites()` and then presents the
    table after `seatingSheetDelay`, through the existing `presentGameNightSheetOrAlert()`.
  - `onChange(sessionActivationCount)`: when the host arrives with `isAdvertisingNearby` still
    true, leave the waiting sheet up and **don't** present the table; Everyone's In does that.
    Every other arrival behaves as today (a guest, the picker path, a reconnect).
  - `scenePhase` → `.background`: before anyone has joined, as today (cancel and close); with a
    live session, call `finishNearbyInvites()` and close the waiting sheet, without cancelling.
  - When `phase` becomes `.inProgress`, close the waiting sheet if it's up.
- **Must not touch:** the reconnect paths, the picker path, payloads.
- **Done when:** SyFive builds and its suite passes (33). Log it in §9.

## 5F. Task 17.8 · SyLib: the cards' "Best for" line (v2.8)

- **Inputs:** §2.6 (v2.8); `Views/GameNightSharingViews.swift` (`GameNightStartChoiceSheet`);
  `Docs/GAME_NIGHT.md`.
- **Change (SyLib):** each card shows a second line under its first, copy verbatim from §2.6, in
  the same secondary style and wrapping. Nothing else in the sheet changes; the init is unchanged.
- **Docs (SyLib):** `GAME_NIGHT.md`'s description of the sheet gains the two lines.
- **Tests:** none (copy in a view).
- **Done when:** SyLib builds and its suite passes unchanged (1613, 1 skipped); syfive-ios builds
  unchanged. Log it in §9.

## 5G. Task 17.9 · SyFive: present after the sheet is gone, not after a delay (v2.9)

- **Why:** on device (13 November 2026), tapping **FaceTime or Messages** on the full-height
  choice sheet shows no picker. `chooseFaceTimeOrMessages()` (`ContentView+GameNight.swift` 160)
  sleeps `seatingSheetDelay` (500 ms) and then calls `beginHosting`, which presents
  `GroupActivitySharingController` over the topmost view controller. A full-height sheet can still
  be dismissing at 500 ms, so the picker is presented over a controller on its way out and UIKit
  drops it without an error. `prepareAsHost()` has already run, so the device is left with an
  invite pending and nothing on screen. Tap to Play's waiting sheet and Everyone's In's table use
  the same fixed delay and can lose the same race.
- **Change (SyFive only):**
  - A pending next step, e.g. `@State var pendingStartStep: StartStep?` with cases for Tap to
    Play, FaceTime or Messages, and Everyone's In. The choice sheet's and waiting sheet's closures
    only **record** the step (and, for Tap to Play, call `beginNearbyHosting()` as today; for
    Everyone's In, `finishNearbyInvites()` as today).
  - Both sheets get `onDismiss:` on their `.sheet(isPresented:…)`. `onDismiss` takes the pending
    step, clears it, and runs it with **no** delay: FaceTime or Messages → `beginHostingFromStart()`;
    Tap to Play → present the waiting sheet if `isAdvertisingNearby` is still true; Everyone's In →
    `presentGameNightSheetOrAlert()` if `isSessionActive`. Cancel records nothing.
  - Remove the `seatingSheetDelay` sleeps from `chooseTapToPlay()`, `chooseFaceTimeOrMessages()` and
    `finishNearbyInvitesAndPresentTable()`. The delays elsewhere (the session-arrival path, which
    waits for the system picker's own dismissal) stay.
  - Log the recorded step and the step `onDismiss` runs.
- **Must not touch:** SyLib, the reconnect paths, the session-arrival presentation.
- **Done when:** SyFive builds and its suite passes (33). Log it in §9.

## 5H. Task 17.10 · SyLib: the waiting sheet's animated icon (v2.11)

- **Inputs:** §2.7 (v2.11, "The icon"); `Views/GameNightSharingViews.swift`
  (`GameNightNearbyWaitingSheet`); `Docs/GAME_NIGHT.md`.
- **Change (SyLib):** add the icon at the top of the waiting sheet's content in both states:
  `Image(systemName: "iphone.radiowaves.left.and.right")`, about 96 pt, centered;
  `.symbolRenderingMode(.palette)` with the iPhone in `.primary` and the waves in `.green`;
  `.symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating,
  isActive: !reduceMotion)` reading `@Environment(\.accessibilityReduceMotion)`;
  `.accessibilityHidden(true)`. No other change; the init is unchanged.
- **If the symbol doesn't split into the layers the palette and variable color need** (the iPhone
  separate from the waves), stop and report what it renders rather than substituting another
  symbol.
- **Docs (SyLib):** `GAME_NIGHT.md`'s description of the waiting sheet mentions the icon and its
  Reduce Motion behavior.
- **Tests:** none (a view).
- **Done when:** SyLib builds and its suite passes unchanged (1613, 1 skipped); syfive-ios builds
  unchanged. Log it in §9.

## 6. Validation, on TestFlight (two iPhones)

The TestFlight build is the spike (Pops, 7 November 2026).

**Guests can run the App Store build** (*v2.11*, checked by Claude, 13 November 2026). Tap to Play
changes only the host: a guest never calls `prepareAsHost()`, so the old role rule already makes
it a guest; `hostToken` is optional and older builds' synthesized `Codable` ignores it; and the
wire versions are unchanged (SyLib `currentProtocolVersion` 3 since 29 Aug, SyFive
`appProtocolVersion` 1 since 28 Aug), so `hello` passes. Only the host needs this build, except
S12 (both phones choose Tap to Play). An older guest doesn't log tokens; the host's log carries
them. Run with the deferred Game Night pass
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
| S14 | *v2.5, decisive:* a third iPhone bumps the host's waiting sheet after the first guest joined | It joins the **same** session: the host's `participantCount` goes to 3, its log shows no new session adopted. If the host logs `ignoring second session`, or nothing happens, keep tapping comes out (§2.7) |
| S15 | *v2.0:* FaceTime or Messages from the choice sheet; Start Game Night on iPad; Resume as Host | Picker flow unchanged; iPad shows no choice; reconnect unchanged |
| S16 | *v2.3:* the choice sheet, at default and accessibility text sizes, light and dark | The question reads first; both cards look tappable; nothing truncates; full height (v2.5) |
| S17 | *v2.5:* after the first join, the host's waiting sheet | Shows "2 players are in…" and Everyone's In; Everyone's In opens the table; guests see the table as usual |
| S20 | *v2.11:* the waiting sheet's icon, with Reduce Motion off and on, light and dark | Big and centered; the waves pulse in shades of green with Reduce Motion off and hold still with it on |
| S19 | *v2.9:* FaceTime or Messages from the choice sheet, five times in a row | The picker appears every time; Tap to Play's waiting sheet and Everyone's In's table appear every time |
| S18 | *v2.5:* background the host's app after a join; start the match from the table | The session holds; advertising has stopped in both cases. *v2.7:* after the background case the waiting sheet is gone and the table doesn't open by itself; the host opens it from the Game Night control (Set Up). Note if that feels wrong |

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
| D-213 | **On iPhone, Start Game Night asks "How do you want to host Game Night?" with two card buttons: Tap to Play ("Bring iPhones together. Best for just iPhones at the same table.") and FaceTime or Messages ("Invite from a call or a chat. Best if players aren't at the same table, or iPads are in the mix.")**, footer "You'll be the host.", full height (`17` §2.6). iPad goes straight to the picker; the reconnect paths stay on the picker. | `17 v2.0 §2.6` → `v2.3` → `v2.5` → `17 v2.8 §2.6` (Pops, 13 Nov 2026) |
| D-214 | **Tap to Play advertises from a waiting sheet; only the host's phone advertises, and it keeps advertising after the first join so each iPhone can tap the host's in turn, until Everyone's In.** It also stops on Cancel (before anyone joins), when the match starts or the session ends, and in the background. No timeout. The sheet shows Tap to Play's symbol, large, with its waves pulsing in shades of green (static under Reduce Motion). While advertising with a live session, a different arriving session is ignored. Spike-gated by S14: if a later bump doesn't join the live session, the sheet closes on the first join and further players join through the Messages group. | `17 v2.0 §2.7` → `17 v2.5 §2.7` (Pops, 13 Nov 2026) |
| D-215 | **The phone that chose Tap to Play hosts, with a host token as backstop.** `GameNightActivity` carries `hostToken`; a phone holding a nearby token hosts only if the session's activity carries it, so two phones that both chose Tap to Play still get one host. A persisted host flag (reconnect) still wins; the picker path is unchanged. *Why:* v1.x left both bump-joined phones as guests (S1, 12 Nov 2026). | `17 v2.0 §2.8` (Pops, 13 Nov 2026) |
| D-216 | **Guests need nothing open:** the system's join prompt launches the app on the guest's iPhone (assumed; S10 confirms, and only copy changes if not). | `17 v2.0 §2.9` (Pops, 13 Nov 2026) |

## 9. Results log

| Task / check | Date | Result | Notes |
|---|---|---|---|
| 17.3 | 13 Nov 2026 | **Done** (checked by Claude against the SyLib tree, 13 Nov 2026; the +7 was the spec's miscount, fixed in v2.1, and the agent's seven tests stand; the agent's choices below are accepted) | SyLib `main`. The suite is **1603 passed, 1 skipped (1678 runs), 0 failed**, against 1596 passed, 1 skipped (1671 runs) before, on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`; totals come from the result bundles. That is **+7, not +6**: §5A's list is 5 cases if "persisted wins (with matching, mismatched and no tokens)" counts as one, and 7 if it counts as three. The agent wrote 7, one per token variant, and Pops picks any merge. syfive-ios builds unchanged, with no new SyLibGameNight warnings; Syderal isn't built (D-173). **Files:** new `GameNightHostToken.swift` (the protocol, verbatim); `GameNightSession.swift` (the entry and COMPLETE log lines show `localToken=`/`activityToken=`, `prepareAsHost()` is `@discardableResult -> Bool`, adds `nearbyHostToken`, `isAdvertisingNearby` and `beginNearbyHosting()` (logs the token), `cancelHostPreparation()` clears both before its guard, and `configureSession` uses `takesHostRole` verbatim with the dynamic cast, then clears both); `Views/GameNightSharingViews.swift` (`GameNightStartChoiceSheet` and `GameNightNearbyWaitingSheet`, copy verbatim, the waiting sheet `.interactiveDismissDisabled()` with the modifier on its content, plus a choice-sheet `#Preview`); `Views/GameNightHelpSheet.swift` ("Sitting together?" body only, §2.5 v2.0); `Docs/GAME_NIGHT.md` (the new state and method rows, the arrival precedence, a new "Nearby hosting" section, both sheets, advertising only from the waiting sheet); new `Tests/…/GameNightHostRoleTests.swift` (7). **Choices to review:** each sheet's buttons call `dismiss()` and then their closure, as `GameNightPendingSheet` does; on the choice sheet the two titles are in `accentColor` and Cancel is top-leading; on the waiting sheet `accentColor` is applied as `.tint`. No preview for the waiting sheet, since the package has no `Transferable` activity outside tests. The visual and on-device checks are Pops's. GIT: `git status --short`, `git branch --show-current` (read-only) |
| 17.1 | 7 Nov 2026 | Done (checked by Claude against the SyLib tree) | `gameNightNearbyInvite(_:title:isAdvertising:)` in `GameNightNearbyInvite.swift`, hidden `ShareLink` in the background; help sheet line 62 and the "Sitting together?" section (87–93) verbatim; `GAME_NIGHT.md` documents it. The first attempt stopped on `GroupActivity.metadata` being async (v1.3). Claude fixed one line in `GAME_NIGHT.md`'s example (`entryState == .idle` can't compile: `.idle` carries `isEligible`). SyLib 1560; Syderal skipped (D-173) |
| 17.2 | 7 Nov 2026 | Done (checked by Claude against the tree) | `GameNightActivity: GroupActivity, Codable, Transferable` with `static let title`, used by `metadata`; `isNearbyInviteAdvertised` in `ContentView+GameNight.swift`; the modifier at `ContentView.swift` 231. SyFive 20 expected |
| S1 (first run) | 12 Nov 2026 | **Failed** | Both iPhones were idle with SyFive open, so both advertised. Neither had called `prepareAsHost()`, so `configureSession` made both `.guest` (reported as both acting as host; the logs' `role=` line confirms which). Led to v2.0 |
| 17.6 | 13 Nov 2026 | **Done** (checked by Claude against the SyLib tree, 13 Nov 2026; the choices are accepted; syfive-ios's build break is the expected init change, fixed by 17.7) | SyLib `main`. The suite is **1613 passed, 1 skipped (1688 runs), 0 failed**, against 1603 passed, 1 skipped (1678 runs) before (17.5's run, same tree), on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`, from the result bundle: **+10 tests**. No warnings in the changed files. syfive-ios is expected not to build until 17.7 (the waiting sheet's init changed) and was not touched. *Built after the fact at Pops's prompt:* it fails with one error, `ContentView.swift:286: the compiler is unable to type-check this expression in reasonable time`. That is the expected init mismatch: the 17.4 call at `ContentView.swift` 558–566 passes the old arguments, inside `body`'s long modifier chain, so it surfaces as a type-check timeout rather than a missing-argument error. SyLib compiled with no errors or warnings in the same build. **Files:** `GameNightSession.swift`: adds `participantCount` (set on arrival, kept current by both participant observations, 0 at teardown); `phase` gets a `didSet` that stops advertising when it leaves `.settingTable`; `finishNearbyInvites()`; a private `stopNearbyAdvertising(_ reason:)`, used by `cancelHostPreparation()` (still first, unchanged in effect), `finishNearbyInvites()`, the phase change, every teardown and a non-matching arrival, which logs `nearby: isAdvertisingNearby true→false token=… reason=…` whenever either value was set; the static `keepsAdvertisingNearby(takesHost:localToken:activityToken:)` and `ignoresSecondSession(isSessionActive:role:isAdvertisingNearby:currentSessionID:incomingSessionID:)`; in `configureSession`, the guard right after the entry log line, logging `nearby: ignoring second session id=… while advertising (S14)` with the current id and `participantCount`, then the keep-advertising decision; the COMPLETE line adds `isAdvertisingNearby=` and `participantCount=`; the host's observation logs each `participantCount` change. `Views/GameNightSharingViews.swift`: the choice sheet loses `.presentationDetents` and card 1's line is "Bring iPhones together."; the waiting sheet has both §2.7 v2.5 states, verbatim. `Docs/GAME_NIGHT.md`: `participantCount`, `finishNearbyInvites()`, the advertising lifetime after a join, the second-session guard and its S14 gate, both sheets, the logging and the Testing note. New `Tests/…/GameNightNearbyAdvertisingTests.swift`: 5 keep-advertising cases (host by match; host with mismatched tokens; no local token; no activity token; a guest with matching tokens) and 5 guard cases (ignored while active, host and advertising with a different id; same id; not advertising; guest; no active session). **Choices to review:** (1) **Teardown ordering:** `configureSession` calls `tearDownSession(.adoptingNewSession)` after it decides the role, and §5D says every teardown clears the nearby state. So for a host by token match, the teardown clears both and `configureSession` sets them back straight after (`nearby: isAdvertisingNearby false→true … reason=kept, host by token match`). The log shows a clear and a restore within one synchronous call; SwiftUI sees no change. (2) The guard sits before the existing duplicate-id check and needs a non-nil current session id. (3) **Waiting sheet init:** the new order is `(activity:title:appName:accentColor:participantCount:onCancel:onEveryoneIn:)`. With two closures, 17.7 can't keep 17.4's trailing-closure call as is. (4) The before-anyone-joins body also takes v2.5's copy, dropping the Messages-group sentence. (5) Everyone's In is `.borderedProminent`, `.controlSize(.large)`, full width, headline font, with a clear row background and no row insets, tinted by `accentColor`. (6) `participantCount` is also updated on guests (as §5D says) but logged only on the host, to keep guest logs quiet. GIT: `git status --short` (read-only) |
| 17.10 | 13 Nov 2026 | **Done** (checked by Claude against the SyLib tree, 13 Nov 2026; the choices are accepted; the colors and animation are S20's) | SyLib `main`. The suite is unchanged at **1613 passed, 1 skipped (1688 runs), 0 failed**, on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`, from the result bundle. No warnings in `GameNightSharingViews.swift`. syfive-ios builds with no change from this task. **Files:** `Views/GameNightSharingViews.swift`: `GameNightNearbyWaitingSheet` reads `@Environment(\.accessibilityReduceMotion)` and has a new first `Section`, shown in both states, holding `Image(systemName: "iphone.radiowaves.left.and.right")` with `.font(.system(size: 96))`, `.symbolRenderingMode(.palette)`, `.foregroundStyle(.primary, .green)`, `.symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating, isActive: !reduceMotion)` and `.accessibilityHidden(true)`, centered (`.frame(maxWidth: .infinity)`) on a clear row background. The init, the copy, the buttons and the advertising are unchanged. `Docs/GAME_NIGHT.md`: the waiting sheet's paragraph describes the icon and its Reduce Motion behavior. **The layer check (§5H's stop condition), as far as a session can see without rendering:** CoreGlyphs' `symbol_categories.plist` lists `iphone.radiowaves.left.and.right` under `"variable"`, so the symbol supports variable color, which animates the waves as layers separate from the iPhone; palette rendering follows the same layers. Whether the iPhone actually draws in the primary color and the waves in green can only be seen rendered, so it's an S20 check, not a ✅ here. **Choices to review:** (1) The icon is its own `List` section, above the body text, on a clear row background, so it sits where the body's section already sits rather than in a new container. (2) 96 pt is fixed, not scaled with Dynamic Type, per "about 96 pt". (3) "The waves fully green" under Reduce Motion relies on an inactive `symbolEffect` drawing the plain palette. GIT: `git status --short` (read-only) |
| 17.9 | 13 Nov 2026 | **Done** (checked by Claude against the tree, 13 Nov 2026; S19 on device is Pops's) | syfive-ios `main`, SyLib unchanged. The build is clean, with no warnings in the changed files. **Suite:** before, 33 passed, 0 failed (36 runs); after, 33 passed, 0 failed (36 runs). Both on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`, from the result bundles. **Files:** `Views/ContentView.swift`: `@State var pendingStartStep: StartStep?`; `onDismiss: { runPendingStartStep(after: "startChoice") }` on the choice sheet and `onDismiss: { runPendingStartStep(after: "nearbyWaiting") }` on the waiting sheet. `Views/ContentView+GameNight.swift`: `enum StartStep { tapToPlay, faceTimeOrMessages, everyoneIn }` beside `LeadingNavSlot`. `chooseTapToPlay()` calls `beginNearbyHosting()` and records `.tapToPlay`; `chooseFaceTimeOrMessages()` records `.faceTimeOrMessages`; `finishNearbyInvitesAndPresentTable()` logs Everyone's In, calls `finishNearbyInvites()` and records `.everyoneIn`. The three `seatingSheetDelay` sleeps are gone, and the session-arrival delay (`ContentView.swift` 407) is the only one left. New `runPendingStartStep(after:)` takes the step, clears it and runs it with no delay: `.faceTimeOrMessages` → `beginHostingFromStart()`; `.tapToPlay` → the waiting sheet if `isAdvertisingNearby`, otherwise logs the skip; `.everyoneIn` → `presentGameNightSheetOrAlert()` if `isSessionActive`, otherwise warns. **Logging:** `startStep: recorded <step> isAdvertisingNearby= isSessionActive= token=`, and `startStep: <sheet> dismissed, running <step>: …`, `… <step> skipped: …` or `… nothing pending`. **Choices to review:** (1) `onDismiss` also fires when the app closes the waiting sheet itself (a session arrival, the background, the match starting). Nothing is recorded then, so it logs "nothing pending" and does nothing. (2) The recording helper is private to the extension, while `pendingStartStep` is internal `@State`, like the file's other sheet flags. (3) No sheet route enum (00A §12): the step is the one new state, alongside the existing `Bool` flags. GIT: `git status --short` (read-only) |
| 17.8 | 13 Nov 2026 | **Done** (checked by Claude against the SyLib tree, 13 Nov 2026) | SyLib `main`. The suite is unchanged at **1613 passed, 1 skipped (1688 runs), 0 failed**, on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`, from the result bundle. No warnings in `GameNightSharingViews.swift`. syfive-ios builds with no change from this task. **Files:** `Views/GameNightSharingViews.swift`: the private `choiceCard` takes a `bestFor:` line, drawn under the first line in the same style (`.subheadline`, `.secondary`, wrapping); Tap to Play's is "Best for just iPhones at the same table." and FaceTime or Messages's is "Best if players aren't at the same table, or iPads are in the mix.", verbatim. The init, layout, spacing, footer, Cancel and behavior are unchanged. `Docs/GAME_NIGHT.md`: the sheet's paragraph gains both lines. **Choice to review:** the two lines sit in the card's existing `VStack` at its 4 pt spacing, so the "Best for" line is as far below the first line as the first line is below the label. **Not this task's:** syfive-ios's tree now also shows `SyFive/Utilities/AppConfig.swift` modified (next to 17.7's `MARKETING_VERSION` bump in `project.pbxproj`); the session didn't make it and left it alone. GIT: `git status --short` (read-only) |
| 17.7 | 13 Nov 2026 | **Done** (checked by Claude against the tree, 13 Nov 2026; the choices are accepted; the one failed UI launch test was a simulator connection loss and passed on re-run) | syfive-ios `main`, against SyLib as 17.6 left it (unchanged). The build is clean, with no warnings in the changed files. The type-check timeout at `ContentView.swift` 286 went with the fixed call, so the waiting sheet wasn't moved out of `body`. **Suite:** before, 33 passed (36 runs), from 17.4's run, the last time the app built (it couldn't build at the start of this task). After, the **first run had 32 passed and 1 failed (35 of 36 runs)**: `SyFiveUITestsLaunchTests.testLaunch()` in "Light Appearance, Portrait" failed with "Failed to get matching snapshot: Lost connection to the application… Couldn't communicate with a helper application", a simulator connection loss, while its other three configurations passed. **Re-run once, unchanged: 33 passed, 0 failed (36 runs).** Both on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`, from the result bundles. **Files:** `Views/ContentView.swift`: the waiting sheet's call passes `participantCount: gameNight.session.participantCount`, a labelled `onCancel:` (unchanged behavior) and `onEveryoneIn:`. `onChange(sessionActivationCount)` computes `keepsNearbyWaiting` (`role == .host && isAdvertisingNearby`): if true, it leaves the sheet up and skips the delayed table presentation, logging both. Otherwise it closes the sheet as before, and the reconnect branch (`consumePendingHostResume()`) still runs first. `scenePhase` `.background` while advertising: with a live session, `session.finishNearbyInvites()` and close; with none, `cancelHostPreparation()` and close, as before; both logged. `onChange(phase)` `.inProgress` closes the waiting sheet if up, logged. `Views/ContentView+GameNight.swift`: new `finishNearbyInvitesAndPresentTable()` (logs Everyone's In with `participantCount` and the token, calls `finishNearbyInvites()`, waits `seatingSheetDelay`, then `presentGameNightSheetOrAlert()`). **Choices to review:** (1) Everyone's In presents the table only if `isSessionActive` is still true after the delay, logging a warning otherwise, like the arrival path's own guard. It doesn't add the arrival path's `phase != .inProgress` check. (2) "Before anyone has joined" in the background path is read as `!isSessionActive`. A live session with only the host in it (`participantCount` 1) takes the finish path, not the cancel path. (3) `keepsNearbyWaiting` keys on the role and the session's flag, not on whether the sheet is showing. A host still advertising whose sheet happened to be closed doesn't get the table on arrival; Everyone's In, the `.inviteSent` control or the menu reopens the sheet. (4) **Not this task's:** `SyFive.xcodeproj/project.pbxproj` shows `MARKETING_VERSION` 1.3.0 → 1.3.1 in both app configurations. The session didn't make it and left it alone. GIT: `git status --short`, `git diff --stat` and `git diff` on `project.pbxproj` (read-only) |
| 17.5 | 13 Nov 2026 | **Done** (checked by Claude against the SyLib tree, 13 Nov 2026; the styling choices below are accepted, and S16 decides whether the cards need a chevron) | SyLib `main`. The suite is unchanged at **1603 passed, 1 skipped (1678 runs), 0 failed**, on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`, from the result bundle. syfive-ios builds with no change from this task (its tree still holds only 17.4's four files). No warnings in `GameNightSharingViews.swift`. **Files:** `Sources/SyLibGameNight/Views/GameNightSharingViews.swift`: `GameNightStartChoiceSheet`'s body rebuilt to §2.6, with the init signature, the stored properties and the dismiss-then-call behavior (each card and Cancel) unchanged; a new private `ChoiceCardButtonStyle`; the waiting sheet untouched. `Docs/GAME_NIGHT.md`: the sheet's paragraph follows the new layout and copy. **Layout:** `NavigationStack` › `ScrollView` › a leading-aligned `VStack` (spacing 16, horizontal padding 20). The headline is `.largeTitle.bold()` with the `.isHeader` trait, then the two cards, then the footer. The toolbar has Cancel (top-leading, as before), with no navigation title and the inline display mode, and `.presentationDetents([.medium, .large])` on the stack. Copy is verbatim. **Styling choices to review:** (1) Card: an `HStack` (first-text-baseline, spacing 14) with the icon in `.title2` and `accentColor`, hidden from VoiceOver; the label in `.headline.bold()` and `.primary`; the line in `.subheadline` and `.secondary`, wrapping; padding 16. (2) Fill: `Color(.secondarySystemBackground)` on a continuous rounded rectangle with radius 16. (3) Pressed state: an `accentColor` overlay at 0.18 opacity plus 0.85 opacity on the card, with no scale and no animation (so nothing to gate for Reduce Motion). (4) Footer: `.footnote`, secondary, centered under the cards. (5) No chevron on the cards, since §2.6 doesn't list one; one would make the cards read more clearly as buttons if S16 finds they don't. (6) `appName` is no longer shown in the copy; it stays stored so the init is unchanged. The sheet's background is the system default (not grouped), so the secondary fill reads as a raised card in light and dark. GIT: `git status --short` (read-only) |
| 17.4 | 13 Nov 2026 | **Done** (checked by Claude against the tree, 13 Nov 2026; the agent's choices below are accepted) | syfive-ios `main`, against SyLib as 17.3 left it (unchanged). The build is clean, with no warnings in the changed files. The suite is **33 passed, 0 failed, 0 skipped (36 runs)** before and after, on `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6`; totals come from the result bundles. §5B's done-when says 20, which is stale: 33 was already the total before this task, and 17.4 adds no tests. **Files:** `App/GameNight/GameNightActivity.swift` (`var hostToken: UUID? = nil`, conforms to `GameNightHostTokenCarrying`, `import SyLibGameNight`; `metadata` and `title` unchanged); `App/GameNight/GameNightController.swift` (`beginNearbyHosting()` pass-through beside `prepareAsHost()`); `Views/ContentView+GameNight.swift` (`isNearbyInviteAdvertised` removed; `.start` and `onStart` call a new `startGameNight()`, which presents the choice sheet on `.phone` and otherwise calls `beginHosting` exactly as before, through `beginHostingFromStart()`; `chooseTapToPlay()`, `chooseFaceTimeOrMessages()`, and `showInviteSent()` for `.inviteSent`; the menu's `onCancelInvite` reopens the waiting sheet while `isAdvertisingNearby`, and otherwise raises the cancel alert as before); `Views/ContentView.swift` (the `.gameNightNearbyInvite` modifier removed; `showsGameNightStartChoice` and `showsGameNightNearbyWaiting` state and their two sheets, with `appName: "SyFive"` and `theme.primaryAccent`; `onChange(sessionActivationCount)` closes the waiting sheet in its existing close-sheets block, before the existing `seatingSheetDelay` presentation; `scenePhase` `.background` while advertising calls `cancelHostPreparation()` and closes the sheet). The reconnect paths (Resume as Host, `onHostReconnect`) are untouched. **Choices to review:** (1) Two more `Bool` sheet flags, following the file's existing pattern, not a route enum (00A §12). (2) Tap to Play presents the waiting sheet after the delay only if `isAdvertisingNearby` is still true, so no sheet appears if `prepareAsHost()` was ignored or a session arrived during the 500 ms. (3) The sheets dismiss themselves, so the closures don't close them again; the waiting sheet's Cancel closure only calls `cancelHostPreparation()`. The choice sheet's Cancel only logs. (4) Logging is `ContentView` info lines (a default `GameNightLogBuffer` category), as `startGameNight:`, `startChoice:` (Tap to Play with token, FaceTime or Messages, cancelled, presenting or skipping the waiting sheet), `nearbyWaiting: Cancel Game Night token=`, `inviteSent:`/`menu cancelInvite: reopening…`, `onChange(sessionActivationCount): closing nearby waiting sheet role=`, and `scenePhase background: cancelling nearby hosting token=`. (5) Both new sheets get `.sheetTextSizeCeiling()`, like the others. The visual and on-device checks (S1–S15) are Pops's. GIT: `git status --short` (read-only) |
| S1–S20 | | **Open: TestFlight, two iPhones** (§6) | S2 and S11 decide A or C |

## Changelog

| Version | Date | Change |
|---|---|---|
| 0 | 3 Nov 2026 | Note filed as `Docs/SyLib/27_SHAREPLAY_NEARBY.md` |
| 1.0 | 6 Nov 2026 | Rewritten in house style, as `Requirements/17`; corrected against the tree |
| 2.12 | 13 Nov 2026 | 17.10 done; every task built. Guests may run the App Store build (§6). Next: the TestFlight run (Claude) |
| 2.11 | 13 Nov 2026 | The waiting sheet gets Tap to Play's symbol, large, with the waves pulsing in shades of green (static under Reduce Motion) (§2.7). Task 17.10; S20; D-214 notes it (Pops) |
| 2.10 | 13 Nov 2026 | 17.9 done; every task built. Next: S19 on device, then the TestFlight run (Claude) |
| 2.9 | 13 Nov 2026 | 17.8 done. FaceTime or Messages showed no picker on device: the 500 ms wait loses to the full-height sheet's dismissal. Task 17.9 presents each next step from the sheet's `onDismiss` instead; S19 (Claude, Pops) |
| 2.8 | 13 Nov 2026 | Each choice card gains a "Best for" line (§2.6): Tap to Play, "Best for just iPhones at the same table."; FaceTime or Messages, "Best if players aren't at the same table, or iPads are in the mix." Task 17.8; D-213 revised (Pops) |
| 2.7 | 13 Nov 2026 | 17.7 done; every task built; S18 notes how the host gets back to the table after backgrounding. Next: the TestFlight run (Claude) |
| 2.6 | 13 Nov 2026 | 17.6 done (SyLib 1613, +10 tests) (Claude) |
| 2.5 | 13 Nov 2026 | Keep tapping: the waiting sheet stays up after the first join so each iPhone can tap the host's, with Everyone's In; a second session is ignored while advertising; spike-gated by S14 (§2.7). The choice sheet is full height and Tap to Play's line is "Bring iPhones together." (§2.6). Tasks 17.6, 17.7; S17, S18; D-213, D-214 revised (Pops) |
| 2.4 | 13 Nov 2026 | 17.5 done. Every task is built; next is the TestFlight run, S1 to S16 (Claude) |
| 2.3 | 13 Nov 2026 | The choice sheet is restyled (§2.6): a question as the headline, two card buttons with an icon and one short line each, "You'll be the host.", a medium detent. Tap to Play's line says iPads join from the Messages group. Task 17.5; S16; D-213 revised. Cause: on device the v2.0 sheet didn't read as buttons and its copy was too long (Pops) |
| 2.2 | 13 Nov 2026 | 17.4 done; §5B's suite count corrected to 33. Next: the TestFlight run, S1 to S15 (Claude) |
| 2.1 | 13 Nov 2026 | 17.3 done. §5A's test count corrected to seven (v2.0 listed seven cases and said six); the agent's 7 tests stand (Claude) |
| 2.0 | 13 Nov 2026 | Advertising becomes a choice: on iPhone, Start Game Night offers Tap to Play or FaceTime or Messages (§2.6); only the host's phone advertises, from a waiting sheet, until Cancel, a session or the background, with no timeout (§2.7); the phone that chose Tap to Play hosts, with a host token as backstop (§2.8); guests need nothing open (§2.9). Tasks 17.3 and 17.4; S10–S15; D-172 and D-174 revised, D-213 to D-216 added. Cause: the first TestFlight bump left neither phone as host (§9) (Pops) |
| 1.3 | 7 Nov 2026 | The modifier takes `title:`: `GroupActivity.metadata` is async and can't be read in a view (17.1's agent). SyFive's activity gets `static let title`, used by its metadata and passed in (Pops) |
| 1.2 | 7 Nov 2026 | No throwaway spike (no two-iPhone testing before TestFlight): 17.1 and 17.2 written, with the hidden link (A); S1 to S9 run on TestFlight; C is the fallback (Pops) |
| 1.1 | 6 Nov 2026 | Moved into 1.2.0; every question ruled (§2), including the hint's copy; `Transferable` needs no body (GroupActivities' default representation); spike written as Task 17.0; 17.1 and 17.2 follow it; rows D-171 to D-174 |
