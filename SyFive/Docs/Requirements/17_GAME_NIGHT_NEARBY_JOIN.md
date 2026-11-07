# Game Night: join by bringing iPhones together (SharePlay over AirDrop)

**Status:** **Design, for Pops's review. Not for the agent.** Version 1.0, 6 November 2026. It
rewrites the note filed as `Docs/SyLib/27_SHAREPLAY_NEARBY.md` (3 November 2026) in SyFive's house
style, and checks it against the tree. It runs **after `26`'s Phase 2** (Pops, 6 November 2026).
Its questions (§6) are ruled before a task is written. The one exception is the spike (§5), which
Pops may release on its own, because it only reports.

**Scope:**
- **SyFive:** `syfive-ios` on `sylib-reintegration`, as of `26`.
- **SyLib** (`syfive-integration`): read only, unless Q2 rules the link into SyLib.
- **Syderal:** out of scope. If Q2 puts it in SyLib, Syderal can adopt it later.

**Ship with every prompt, once tasks exist:** `00_DECISION_LEDGER.md`, `00A`, `00B`,
`16_GAME_NIGHT_PROXIMITY_MUTE.md`, this document.

---

## Supersessions

None proposed. Game Night's session layer, payloads and versions (D-131, D-156), Proximity Mute
(D-GNP-001 to D-GNP-022) and the entry controls (D-140) all stand as they are. The proposals add a
way to **start** a session, and change nothing once the session exists.

---

## 1. Why

Game Night runs on Messages and FaceTime with SharePlay. Once a session is going it stays connected
all evening, which matters more than how quickly it starts. But for people sitting at the same
table, starting one is heavy. Since iOS 17, bringing two iPhones together can start a SharePlay
activity, with the same gesture as NameDrop. The system creates the Messages group, and the session
that results is the same kind SyFive already handles.

**Goal:** people in the same room join by bringing their iPhones together. **Kept as it is:**
Messages and FaceTime for remote players, and the whole session layer.

---

## 2. What SyFive has today (read 6 November 2026)

- **The activity is SyFive's own type and is SwiftUI.**
  `App/GameNight/GameNightActivity.swift` 7:
  `nonisolated struct GameNightActivity: GroupActivity, Codable`, with
  `activityIdentifier = "com.syzygy.syfive.gamenight"` and the title "SyFive Game Night". It isn't
  `Transferable` yet. Version 0 asked whether the start screen was "SwiftUI or UIKit". It is
  SwiftUI, so this question is settled.
- **There is no lobby screen.** Game Night starts from SyLib's entry views (D-140), on the game
  screen itself: `GameNightMenuSection` and `GameNightLeadingControlButton`
  (`SyLibGameNight/Views/GameNightEntryViews.swift`), wired in `Views/ContentView+GameNight.swift`
  (41, 89). Their state is SyLib's `GameNightEntryState`:

  | State | Leading control | Menu |
  |---|---|---|
  | `.idle(isEligible:)` | `.start` when eligible, otherwise none | Start Game Night |
  | `.invitePending` | `.inviteSent` | Cancel Game Night Invite |
  | `.atTable(isHost:)` | `.setup` | Game Night Setup (and End, for a guest) |
  | `.inProgress(isHost:)` | `.end` (host) or `.active` | End Game Night or Game Night Active |
  | `.matchOver(isHost:)` | none (host) or `.active` | none |

  Version 0's rule, "only the lobby advertises the activity", becomes "only `.idle` advertises it"
  (§4.2).
- **Incoming sessions are received in one place.** SyLib's `GameNightSession` loops
  `for await incomingSession in Activity.sessions()` (`GameNightSession.swift` 262). A session
  started by bringing phones together arrives there like any other, so the pipeline needs no
  change.
- **Proximity Mute already uses Nearby Interaction**, and Version 0 listed Nearby Interaction as
  out of scope. They don't collide. Ranging starts at seat claiming (D-GNP-010) and resolves once
  per match (D-GNP-006). Bringing phones together happens in `.idle`, before any session exists.
  A table joined this way is in one room by definition, so Proximity Mute will usually mute the
  guests, which is correct (D-GNP-004).
- **The floor is iOS 18.6** (`IPHONEOS_DEPLOYMENT_TARGET`), above the iOS 17 this needs.

---

## 3. How SharePlay over AirDrop works (Apple)

From Apple's *Presenting SharePlay activities from your app's UI* (Group Activities documentation,
read 6 November 2026):

- **The flow:** the initiator opens the app on their iPhone, on a page that has the activity. When
  the iPhone comes close to other people's iPhones, the system offers to start it. Once it is
  started, the system prompts the others to join and creates a Messages conversation for the group.
  Anyone in that group can then invite more people, including people who aren't nearby.
- **SwiftUI:** the system enables SharePlay over AirDrop when the UI contains a `ShareLink` whose
  activity conforms to `Transferable`.
- **UIKit:** the system searches the responder chain for an `activityItemsConfiguration` whose item
  provider has the activity registered (`registerGroupActivity(_:)`).
- **iPhone only.** The documentation describes it between iPhones. iPads at the table join through
  the Messages group, as remote players do.
- **A hidden `ShareLink`** (`.hidden()`) is documented for **visionOS**'s Share menu only. Whether
  a hidden link still enables AirDrop on iOS is not documented. The spike tests it (§5, S2), and the
  answer decides Q1.
- **People can turn it off:** Settings › General › AirDrop › Bringing Devices Together. Then there
  is no prompt.
- **Tapping a `ShareLink`** starts the activity when a FaceTime call is active, and otherwise opens
  the share sheet.

---

## 4. Proposals

### 4.1 `GameNightActivity` becomes `Transferable` *(rec.)*

Use `GroupActivityTransferRepresentation`, as Apple's examples do. This is SyFive-only (§2), and it
adds no payload, schema or version change.

### 4.2 The activity is advertised only in `.idle` *(rec.)*

It is advertised only while `GameNightEntryState` is `.idle(isEligible:)`, whatever the
eligibility. It is withdrawn from `.invitePending` onward. *Rationale:* advertising during a session
would offer a second session every time phones come close, including when a phone is passed across
the table.

**Whether a local game in progress also withdraws it is Q3.** During a pass-and-play game, a second
iPhone that happens to be close would raise the prompt.

### 4.3 Where it lives (Q1 and Q2)

| Option | What players see | Where the code is | Notes |
|---|---|---|---|
| **A. A hidden `ShareLink`** on the game screen, while §4.2 holds | Nothing new, except the hint (§4.4) | SyFive (`ContentView+GameNight.swift`) | Depends on S2. Recommended if S2 passes |
| **B. A visible `ShareLink`** beside or inside the Game Night entry | A new SharePlay control, which is a second way to start | SyFive, or SyLib's entry views (Q2) | Two start controls for one feature; needs a design pass |
| **C. A UIKit responder** (`activityItemsConfiguration` on the hosting controller, through a small representable) | Nothing new | SyFive | Apple's documented path with nothing visible. A bridge layer, but no UI. The fallback if S2 fails and Pops doesn't want B |

**Q2:** SyLib's entry views are shared with Syderal, and Syderal would want this too. Putting the
link in SyLib (`GameNightMenuSection` or a modifier) is a SyLib addition, which needs `00B` §2's
named task and Syderal's compatibility build. Keeping it in SyFive is smaller and can move later.

### 4.4 The hint

A short line telling players the gesture exists, which can't promise it always works (§3, the
setting). **Its words are Pops's** (`00B` §2: no copy that a task doesn't give word for word).
Where it appears (Help, the Game Night setup sheet, or near the entry) is part of Q4.

---

## 5. The spike (Task 17.0, report only)

Pops may release this before the questions are ruled. It changes code only in a throwaway form, and
its deliverable is a report.

- **Change (spike branch only):** `GameNightActivity: Transferable` (§4.1), plus a `ShareLink` with
  the activity on the game screen, shown only in `.idle`.
- **Pops, on two iPhones** (both iOS 17 or later, Bringing Devices Together on). The Simulator can't
  do this:

| # | Check | Report |
|---|---|---|
| S1 | With a visible `ShareLink`, bring the phones together while the host is in `.idle` | Is there a prompt on the host, then a join prompt on the guest? Do both reach `.atTable` and does a full match play? Exact prompt wording; time to the table |
| S2 | The same with the link `.hidden()` | Does the prompt still appear? This decides option A |
| S3 | Phones together while the host is `.atTable` and `.inProgress` (the link withdrawn) | No prompt |
| S4 | Lock and unlock either phone; background the app briefly; the guest leaves the room | The session holds, as a Messages-started one does |
| S5 | A third, remote player added through the group's Messages conversation | Joins as a normal guest |
| S6 | Bringing Devices Together off | No prompt; Start Game Night still works |
| S7 | The existing Messages and FaceTime starts | Unchanged |
| S8 | Proximity Mute on a table joined this way (iPhones with UWB) | Guests are muted as D-GNP-004 rules; report anything else |

---

## 6. Questions for Pops

1. **Where the advertisement lives (§4.3):** A (hidden, if S2 passes), B (visible) or C (UIKit
   responder)? *Recommendation: A, with C as the fallback.*
2. **SyFive or SyLib (§4.3):** in SyFive now, or in SyLib's Game Night entry for Syderal too?
   *Recommendation: SyFive now; move it when Syderal asks.*
3. **During a local game (§4.2):** withdraw the advertisement while a local match is in progress
   (`!model.canEditPlayers`), so it shows only before a game starts and after one ends?
   *Recommendation: yes.*
4. **The hint (§4.4):** where it goes, and its words.
5. **The Messages group:** joining this way creates a group Messages conversation for the table. Is
   that acceptable for couch play? (It is how the feature works, and there is no option to turn it
   off.)

---

## 7. Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| MultipeerConnectivity | Connections drop when the app backgrounds or the phone locks; reconnection is finicky; it needs a local-network prompt and Bonjour entries that confuse first-time players. Rejected twice |
| Custom networking, or a Bonjour lobby | The same costs, and it would duplicate a session layer that already works |
| An NFC-style tap | Not available to third-party apps |
| Advertising during a session | Every pass of a phone would offer a new session (§4.2) |

---

## 8. Proposed ledger rows (filed when ruled, at the next free IDs)

| ID | Ruling |
|---|---|
| next | **Game Night can start by bringing iPhones together** (SharePlay over AirDrop). `GameNightActivity` is `Transferable`. The session layer, payloads and versions are unchanged |
| next | **The activity is advertised only while Game Night is idle** (and, per Q3, only when no local match is in progress), as Q1 and Q2 place it |
| later | The hint's place and words (Q4) |

---

## Changelog

| Version | Date | Change |
|---|---|---|
| 0 | 3 Nov 2026 | Note filed as `Docs/SyLib/27_SHAREPLAY_NEARBY.md` |
| 1.0 | 6 Nov 2026 | Rewritten in house style, as `Requirements/17`. Corrected against the tree: there is no lobby (the entry is D-140's, keyed on `GameNightEntryState`); the activity is SwiftUI and SyFive's own; it doesn't collide with Proximity Mute (D-GNP-006, D-GNP-010); iPhone only. Added options A to C, the spike, questions, exclusions and ledger rows |
