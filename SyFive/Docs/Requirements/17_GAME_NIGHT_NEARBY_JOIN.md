# Game Night: join by bringing iPhones together (SharePlay over AirDrop)

**Status:** **Built (17.1, 17.2); S1 to S9 open on TestFlight.** Version 1.3, 7 November 2026. In SyFive 1.2.0
(Pops, 6 November 2026). Every question is ruled (§2). There is no throwaway spike: Pops can't test
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

**2.2 Nothing new is visible; a hint explains the gesture** (D-172). The system needs the screen
to carry the activity. Two ways, in order:
- **A:** a hidden `ShareLink` carrying the activity, if iOS still offers the prompt for a hidden
  link. Apple documents hiding it only on visionOS, so the spike's **S2** decides.
- **C:** otherwise a UIKit responder whose `activityItemsConfiguration` holds an `NSItemProvider`
  with the activity registered (`registerGroupActivity(_:)`), through a small representable.
  Apple's documented path, with nothing visible.

A visible SharePlay button (v1.0's option B) is excluded (§7).

**2.3 It lives in SyLib's Game Night** (D-173). The advertising and the hint go in
`SyLibGameNight`, so Syderal can adopt them. SyFive supplies its activity and the condition.

**2.4 Only before or after a game** (D-172). Advertised only while Game Night is idle
(`GameNightEntryState` is `.idle`) **and** no local match is in progress (`!model.hasStarted ||
model.isGameOver`). Otherwise a second iPhone near the table during pass-and-play, or a phone
passed across it, would raise the prompt.

**2.5 The hint, in the Game Night help sheet** (D-174). Pops's copy, verbatim:
- A new section in SyLib's `GameNightHelpSheet`, in the part about starting a game night, after
  "Start with a call or a conversation":
  - Heading: **Sitting together?**
  - Body: **With \(appName) open, hold your iPhone near a friend's iPhone. Yours offers to start
    Game Night, theirs offers to join, and Messages makes a group for the table. If nothing
    appears, check Settings › General › AirDrop › Bringing Devices Together.**
- The sheet's first line (`GameNightHelpSheet.swift` 62) changes from "…you need one of these open
  with your players:" to **"…you need one of these open with your players, or be sitting together
  (see below):"**.

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

## 6. Validation, on TestFlight (two iPhones)

The TestFlight build is the spike (Pops, 7 November 2026). Run with the deferred Game Night pass
(26 §12). iOS 17 or later, Bringing Devices Together on.

| # | Check | Pass |
|---|---|---|
| S1 | Host on the game screen before a game, bring the iPhones together | Host offered to start, guest offered to join; both reach the table; a full match plays |
| S2 | **The same: does the prompt appear at all with the hidden link?** | **If not, 17.1's modifier switches to C (§2.2) in the next TestFlight build** |
| S3 | During a game, and while at the table | No prompt |
| S4 | Lock and unlock either phone; background briefly; the guest leaves the room | The session holds |
| S5 | A third, remote player through the group's Messages thread | Joins as a normal guest |
| S6 | Bringing Devices Together off | No prompt; Start Game Night still works |
| S7 | The existing Messages and FaceTime starts | Unchanged |
| S8 | Proximity Mute on a bump-joined table (UWB iPhones) | Guests muted as D-GNP-004 rules |
| S9 | Game Night Help before a session | "Sitting together?" appears; the first line ends "or be sitting together (see below):" |

If neither A nor C produces the prompt, 17 comes out of 1.2.0 and the rest ships.

## 7. Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| A visible SharePlay button | A second start control for one feature (Pops, 6 Nov 2026) |
| MultipeerConnectivity | Drops when the app backgrounds or the phone locks; finicky reconnection; a local-network prompt and Bonjour entries. Rejected twice |
| Custom networking, a Bonjour lobby | The same costs, duplicating a session layer that works |
| An NFC-style tap | Not available to third-party apps |
| Advertising during a game | Every pass of a phone would offer a new session (§2.4) |

## 8. Ledger rows (paste into `00_DECISION_LEDGER.md`)

| ID | Ruling | Source |
|---|---|---|
| D-171 | **Game Night can start by bringing iPhones together (SharePlay over AirDrop), in 1.2.0.** `GameNightActivity` is `Transferable`; the session layer, payloads and versions are unchanged. The group Messages conversation iOS creates is accepted. | `17 §2.1` (Pops, 6 Nov 2026) |
| D-172 | **Nothing new is visible.** The activity is advertised by a hidden `ShareLink` if iOS honors it (spike S2), otherwise by a UIKit `activityItemsConfiguration` responder; only while Game Night is idle and no local match is in progress. No visible SharePlay button. | `17 §2.2, §2.4` |
| D-173 | **The advertising and its hint live in `SyLibGameNight`**, so Syderal can adopt them; Syderal's check waits for its next release. | `17 §2.3` |
| D-174 | **The hint is a "Sitting together?" section in SyLib's Game Night help sheet, with Pops's copy (`17` §2.5), and the sheet's first line adds "or be sitting together (see below)".** | `17 §2.5` |

## 9. Results log

| Task / check | Date | Result | Notes |
|---|---|---|---|
| 17.1 | 7 Nov 2026 | Done (checked by Claude against the SyLib tree) | `gameNightNearbyInvite(_:title:isAdvertising:)` in `GameNightNearbyInvite.swift`, hidden `ShareLink` in the background; help sheet line 62 and the "Sitting together?" section (87–93) verbatim; `GAME_NIGHT.md` documents it. The first attempt stopped on `GroupActivity.metadata` being async (v1.3). Claude fixed one line in `GAME_NIGHT.md`'s example (`entryState == .idle` can't compile: `.idle` carries `isEligible`). SyLib 1560; Syderal skipped (D-173) |
| 17.2 | 7 Nov 2026 | Done (checked by Claude against the tree) | `GameNightActivity: GroupActivity, Codable, Transferable` with `static let title`, used by `metadata`; `isNearbyInviteAdvertised` in `ContentView+GameNight.swift`; the modifier at `ContentView.swift` 231. SyFive 20 expected |
| S1–S9 | | **Open: TestFlight, two iPhones** (§6) | S2 decides A or C |

## Changelog

| Version | Date | Change |
|---|---|---|
| 0 | 3 Nov 2026 | Note filed as `Docs/SyLib/27_SHAREPLAY_NEARBY.md` |
| 1.0 | 6 Nov 2026 | Rewritten in house style, as `Requirements/17`; corrected against the tree |
| 1.3 | 7 Nov 2026 | The modifier takes `title:`: `GroupActivity.metadata` is async and can't be read in a view (17.1's agent). SyFive's activity gets `static let title`, used by its metadata and passed in (Pops) |
| 1.2 | 7 Nov 2026 | No throwaway spike (no two-iPhone testing before TestFlight): 17.1 and 17.2 written, with the hidden link (A); S1 to S9 run on TestFlight; C is the fallback (Pops) |
| 1.1 | 6 Nov 2026 | Moved into 1.2.0; every question ruled (§2), including the hint's copy; `Transferable` needs no body (GroupActivities' default representation); spike written as Task 17.0; 17.1 and 17.2 follow it; rows D-171 to D-174 |
