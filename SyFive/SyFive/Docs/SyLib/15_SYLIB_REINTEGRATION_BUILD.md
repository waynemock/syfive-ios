# SyLib reintegration, Phase 1: build on the finished SyLib, then baseline on devices

**Status:** Ready for the agent. Written 10 October 2026.

**Phase 1 of 3.** `15` builds and baselines, `16` fixes, `17` adopts. All three ship together as
**SyFive 1.1.0**.

**Scope:** `SyFive` only. SyLib is read, not changed. The first SyLib edit is in `16`.

**Ship with every prompt for this phase:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document, and `14_SYLIB_SYDERAL_INTEGRATION.md`. §1, §2 and §2.6 of `14` give the reasoning behind every step here,
so this document does not repeat it.

---

## Supersessions

| Overrides | With | Why |
|---|---|---|
| D-078 as written (`09 §1.5`) | D-078 amended (§9): the rule as SyLib's `.dropWhileSpeaking` runs it, with bursts | `14 §2.1`. The rule is unchanged. The amendment adds how a burst works and the three narrow differences from 1.0. |
| `14 §3.11` (the `AppUpdateState` row) and `14 §5` ("stale text left in SyLib") | Nothing to do. Syderal Task 13.14d has landed | In the finished SyLib, `AppUpdateState`'s doc comment (lines 8-10) and `APP_STORE.md` (19, 61, 67) already say to acknowledge the badge from the Update Available item, so SyLib's text and `14` now agree. |
| `14 §3.12`: "proximity mutes one device of a pair … when the muted device is the host, its broadcast is how the guests hear anything" | Proximity never mutes the host (D-GNP-004), and its verdicts and timeout only unmute (D-GNP-005). The host's broadcast matters when the host mutes itself, with the button or Sound Off (D-130 as reworded) | Read in `GameNightProximity.swift` (lines 170, 232, 258, 437) by the agent, 10 October 2026 |
| Version 1.0.4 in the first issue of `15` to `17` | **1.1.0**, already set by Pops | Pops, 10 October 2026 |
| The doc file names `COMMENTARY.md`, `FEEL.md` and `SCORING.md` in `14` | On disk the files are `Commentary.md`, `Feel.md` and `Scoring.md` | A case difference only. Cite the on-disk names. |

---

## 1. The programme

| Phase | Doc | What it does | SyLib edits | Ends with |
|---|---|---|---|---|
| 1 | `15` (this) | One-word compile fix, Xcode 27, version check (1.1.0), unit tests, device baseline | None | A recorded baseline of every re-test, failures included |
| 2 | `16` | Three SyLib changes, then five SyFive bug fixes | 3, each with tests and docs | Every Phase-1 failure that `16` owns is passing |
| 3 | `17` | Nine SyLib adoptions in place of SyFive's own code, then release prep | None | The full matrix passes; ready to archive |

The Syderal-style reshape is **deferred, not rejected** (D-128): a bridge type for
`GameNightMatchHost`, import boundaries, and `nonisolated` default isolation. It is not to be
started under any of these three docs.

---

## 2. Locked decisions

**2.1 Phase 1 changes no behaviour on purpose.** The only code edit is the one word in §4.2. The
only other edit is the version number in the project file (§4.4).
Phase 1 records failures in the re-test pass and does not fix them; each failure has an owner in
`16` or `17`, or becomes a new finding. *Rationale:* a baseline is only useful if nothing has
moved under it.

**2.2 Any compile error other than §4.2 stops the agent.** It reports the error verbatim (file, line,
message) and does not attempt a fix. *Rationale:* `14 §1.3` found no second break by reading,
and a surprise from the Xcode 27 compiler is something Pops rules on.

**2.3 Wire versions do not move** (D-131). `GameNightMessageKind.appProtocolVersion` stays **1**
and SyLib's transport version stays **3**. *Rationale:* a host declines any joiner whose app
version differs, so raising it would split 1.1.0 from 1.0.3 at the table (`14 §1.4`).

**2.4 SyFive's store and catalogue seed never move into SyLib** (D-129). `SyFiveApp.swift`'s
container and `seedYatzyGameIfNeeded()` stay exactly as they are. `makeScoringContainer`,
`makeInMemoryScoringContainer` and `seedCatalogGame` are not adopted under any phase.
*Rationale:* `14 §3.12`. The container was matched to Syderal's store, not SyFive's, and the
seed matches on `scoringSystemID`, which SyFive's older rows need.

**2.5 `onWillSpeak` fires while the engine is muted, and must keep doing so** (D-130). No SyFive
change copies Syderal's "broadcast only if the host can hear" guard, and no SyLib change moves
the hook below the mute. *Rationale:* a host that has muted itself, with the commentary button
(D-GNP-008) or with Sound set to Off (D-GNP-019), still feeds its guests. The button means
"commentary on this device" and must not silence the table. Proximity itself never mutes the host:
the host's cluster always speaks (D-GNP-004). `14 §3.12` said otherwise, and is corrected here.

**2.6 Marketing version 1.1.0.** Pops has already set `MARKETING_VERSION = 1.1.0` in the app target's
Debug and Release configurations. The live App Store version is 1.0.3. Build numbers stay as Pops
sets them at archive.

**2.7 Pops's edits to `project.pbxproj` are the baseline.** The file was already modified in the
working tree before this phase, by Pops, and those edits stay as they are. Line numbers in the
project file cited by `14` and by this series come from an older snapshot and have moved (the
version is at 413 and 465, not 408 and 460). Find each setting by name.

---

## 3. Preconditions (Pops, before the agent starts)

1. **Xcode 27** is installed and selected. SyLibUI names iOS 27 SDK symbols
   (`ExternalDisplayContent.swift` 56, 70-77).
2. **The checkout at `../../sylib-swift` is the finished SyLib**, the tree Syderal 1.0 was
   submitted with: branch `syfive-reintegration`, at commit `1e2729fd5be90bf7402860f9c706b361a175d4e2`
   ("Completed Milestone 13"), the same commit as `main`. Check all three:
   - `Sources/SyLibUI/Components/MoreMenu.swift` declares no `onOpen`.
   - `Sources/SyLibCore/AppStore/AppUpdateState.swift`'s doc comment says to call
     `acknowledge()` "from the menu item that leads to the update".
   - `Sources/SyLibFeel/Playback/FeelAudioEngine.swift` observes
     `mediaServicesWereResetNotification`.
3. **SyLib's test suite passes on its own**, run as `00B` §5.3 says. Record the count; it was 1118 at
   Syderal's last report.
4. **A second device has the App Store build of SyFive (1.0.3)** for re-test R16, and stays on
   it until Phase 3 ends.
5. **Task A-1 of `00B` §7 is complete**: `00A` and `00B` are in place, and the test targets are at
   iOS 18.6. The pinned simulator (iPhone SE (3rd generation), iOS 18.6) is installed.
6. **Pops creates the branch `sylib-reintegration`** in the SyFive repo. Agents never run `git`
   (`00A` §9).

---

## 4. Tasks

Do them in order. One task per session, reported in `00A` §6's form.

### 4.1 Record the baseline

- In §10, record: the SyLib commit hash checked out at `../../sylib-swift`; the Xcode version and
  build; SyLib's test count.

*Why:* `14 §5` could not say which SyLib commit SyFive last built against. Every later doc in this
series cites this hash.

### 4.2 The compile fix

| | |
|---|---|
| File | `App/GameNight/GameNightActivity.swift` |
| Declaration | `struct GameNightActivity: GroupActivity, Codable {` (line 7) |
| Edit | Put `nonisolated` before `struct` |

```swift
nonisolated struct GameNightActivity: GroupActivity, Codable {
```

Nothing else in the file changes. The struct has no stored instance property, and nothing in it
needs the main actor (`14 §1.1`).

### 4.3 Build and triage

- Build the `SyFive` scheme for an iOS 27 device and for an iOS 18.6 simulator. The deployment
  target stays 18.6.
- **Errors:** any error is a stop (§2.2).
- **Warnings:** list every warning that `SyLib…` produces, and every warning that is new in the
  SyFive target, as file, line and message, in §10. Do not fix them.

### 4.4 Version

- **No edit.** Confirm `MARKETING_VERSION = 1.1.0` in both of the app target's configurations
  (`project.pbxproj` 413 and 465 in Pops's tree), and record it in §10. Leave the test targets'
  `1.0` alone.

### 4.5 Unit tests

- Run SyFive's suite on the pinned destination (`00B` §5.2). `FeelTests.swift` is the only file that imports SyLib, and every call in it
  matches the finished declarations (`14 §1.3`). Expect a pass.
- Record the result in §10.

### 4.6 Device baseline

Run every check in §5 on devices and record each result in §10 as **Pass**, **Fail** (with what
was seen) or **Not run** (with why). A failure does not stop the pass. Before Game Night checks
that listen on both devices, read `14 §2.6`'s note on proximity muting.

When the matrix is complete, the phase is done. Report the §10 log.

---

## 5. Validation matrix

R1 to R18 are `14 §2.6`, run as written there; the *Expect* column here is a short form of each. R19
to R22 are new. They record evidence for bugs that `16` and `17` fix, so they are **expected to
fail** now. Each says which task fixes it.

| ID | Check | Expect now | Owner if it fails |
|---|---|---|---|
| R1 | A burst of four lines | Score, bonus, lead change, turn: in order, none cut | Finding |
| R2 | No backlog | A small score during a burst is dropped; a score of 25 or more cuts in | Finding |
| R3 | Host and guest speak the same lines | Guest speaks R1's four lines in order | Finding |
| R4 | Zen's long lines | Every line spoken to its last word | Finding (watchdog, `14 §2.1`) |
| R5 | Commentary settings | Checkmark rows; labels grow with type size | Finding |
| R6 | Voices | Spinner, then list; preview; on iOS 27, "Tap Read & Speak, then Voices." | Finding |
| R7 | Other audio at launch | Music continues under Mix and Off; stops under Game Audio Only | Finding |
| R8 | First launch after update | No launch pause; sounds present once warm-up finishes | Finding |
| R9 | Route change | Sound, haptics and commentary on the next event after AirPods or AirPlay on and off | Finding |
| R10 | Media-services reset | Sound and haptics on the next roll; log shows `media services reset: rebuilding the engine`, then `engine started` | Finding |
| R11 | Game Night with proximity | Joins as before; one device muted by proximity | Finding |
| R12 | Sharing sheet | On the device, with and without TV mirroring | Finding |
| R13 | Seating footer | Ends "you'll spectate the game in real time." | Finding |
| R14 | About footer | Opaque, no text showing through | Finding |
| R15 | History at an accessibility size | Record which layout appears. **This answers whether the root Dynamic Type limit reaches sheets** | Information |
| R16 | 1.0.3 (App Store) and 1.1.0 at one table | Both ways round: seat, play to the end, both Histories hold the match | Finding |
| R17 | Game Night endings (a) to (e) | Each behaves as 1.0.3 does. Note (a) for `17` §4.1: the guest sees "Game Night ended" | Finding |
| R18 | Game Night Help | The two new "tap Open" lines, with SyFive's name | Finding |
| **R19** | **Commentary button during a Game Night match.** Host and guest, commentary on at Play-by-Play, match in progress. (a) On the host, tap the commentary button, then score so lines are generated. (b) Two ranging phones in one room: watch the guest that proximity starts muted, through to the verdict or the 10-second timeout | **Expected to fail:** (a) the icon and "Commentary off" change, but the host keeps speaking. It falls silent only after a commentary settings change or when the session ends. (b) Record whether the guest starts speaking when the verdict or timeout unmutes it (D-GNP-005, D-GNP-007). The same lost hook means the unmute may not reach its engine until the next tableState | `16` §4.4 |
| **R20** | **Commentary button while a line speaks** (solo game, Play-by-Play). Score so that R1's four lines queue; tap the button during the first | **Expected to fail:** the line and the queued ones play out | `16` §4.5 |
| **R21** | **Solo game commentary.** One player, Play-by-Play, a full game | **Expected to fail** some of the time: a game-over line with "{runnerUp}" left in it (Release), an assertion stop (Debug), or "wins by" the whole score | `16` §4.6 |
| **R22** | **Update badge** (Debug only). Make the store's 1.0.3 look newer: in the app target's **Debug** configuration only, set `MARKETING_VERSION` to `1.0.2` for this check, and put it back afterwards. Open and close the menu, then relaunch | **Expected to fail:** the badge stays after the menu is opened, and returns at relaunch | `17` §4.7 |

**R19, in detail.** Found while writing this doc, by reading. `GameNightController`'s teardown,
`performControllerTearDown()` (line 512), sets `onCommentarySuppressedChanged = nil` at line 530.
`ContentView` assigns that hook once, in `.onAppear` (`ContentView.swift` 266). The session tears
down every time a session arrives (`GameNightSession.configureSession`, line 362, reason
`.adoptingNewSession`). So from the first Game Night of a launch until relaunch, the commentary
button and proximity's own transitions no longer reach `commentaryEngine.isMuted`. That includes
solo games played after the session ends. The engine picks the state up only when
`syncCommentaryEngine()` next runs. This has not been seen on a device, so R19 is its first check.
Whether 1.0.3 has it depends on whether the SyLib it shipped on tore down on a new session's
arrival, and `14 §2.3` says that SyLib is unknown.

---

## 6. Not touched in Phase 1

Everything in `16` and `17`. No `AppConfig` flag changes, no SyLib file, and no doc other than
this one's §10.

---

## 7. Open decisions

None. Every decision for the three phases was settled with Pops on 10 October 2026.

---

## 8. Invariants quick reference

- `appProtocolVersion` stays 1; transport stays 3. (D-131)
- The container and the Yatzy seed are SyFive's own, always. (D-129)
- `onWillSpeak` fires above the mute; `broadcastCommentary`'s host-only guard stays. (D-130)
- A guest leaves at the table with `leaveSession()`, never `leaveSessionOnThisDevice()`. (`14 §3.12`)
- `matchAbandoned` is sent only by a host that is ending Game Night. (`14 §4.1`)
- `CommentaryQueuePolicy` stays at its default, `.dropWhileSpeaking`; `.queue` is the backlog
  D-078 forbids.
- A compile error the doc does not name is a stop, not a fix.

---

## 9. Ledger rows

**Already pasted by `00B` Task A-1.** They are listed here as this document's record. D-078 replaced
its existing row; the others went under the headings shown.

**Commentary**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-078 | **Higher-tier events interrupt; same-or-lower-tier events drop; never a backlog.** As SyLib's `.dropWhileSpeaking` runs it, lines come in bursts: a burst opens when a line becomes the first in flight and stays open until that line is reported started. While it is open, events append in order (up to four lines). After it closes, a more important event cuts the speaker and the queue, and anything else drops. Known narrow differences from 1.0 are in `14 §2.1`. SyFive never sets `.queue`. | `09 §1.5` (open §12.4 → resolved) → `14 §2.1` → `15 §9` |
| D-130 | **`onWillSpeak` fires while the engine is muted, by design.** A host muted by its commentary button (D-GNP-008) or by Sound set to Off still broadcasts to its guests (D-GNP-019). SyFive does not adopt Syderal's muted-host broadcast guard, and SyLib must not move the hook below the mute. | `16_GAME_NIGHT_PROXIMITY_MUTE §2.2` (D-GNP-019) → `14 §3.12` → `15 §2.5` |

**Platform & data** (new heading, placed after Governance)

| ID | Current ruling | Source → chain |
|---|---|---|
| D-128 | **1.1.0 brings SyFive onto the post-Syderal SyLib in three phases**: build and baseline (`15`), fixes (`16`), adoptions (`17`). The Syderal-style reshape (a bridge type for `GameNightMatchHost`, import boundaries, `nonisolated` default isolation) is **deferred to a later release, not rejected**. | `15 §1` *(rec.)* |
| D-129 | **SyFive's store and catalogue seed never move into SyLib.** The container in `SyFiveApp.swift` and `seedYatzyGameIfNeeded()` stay SyFive's. `makeScoringContainer`, `makeInMemoryScoringContainer` and `seedCatalogGame` are never adopted. | `14 §3.12` (Syderal L-17) → `15 §2.4` |
| D-131 | **Wire versions frozen for 1.1.0:** `appProtocolVersion` stays 1 and the transport stays 3, so 1.0.3 and 1.1.0 share a table. Raise either only with a doc that plans the split. | `14 §1.4` → `15 §2.3` |

---

## 10. Results log (filled in during the phase)

| Item | Value |
|---|---|
| SyLib commit at `../../sylib-swift` | `1e2729fd5be90bf7402860f9c706b361a175d4e2` on branch `syfive-reintegration` ("Completed Milestone 13"), read from `.git/HEAD` and `.git/refs/heads/syfive-reintegration`, 10 Oct 2026 |
| Xcode version and build | Xcode 27.0, build 27A266a |
| SyLib test count, simulator | **1118 tests in 118 suites, passed** (`xcodebuild test -scheme SyLib-Package -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6'`, 10 Oct 2026). Matches Syderal's last report |
| `MARKETING_VERSION` (§4.4) | **1.1.0** in the app target's Debug and Release configurations (`project.pbxproj` 413 and 465; confirmed by `xcodebuild -showBuildSettings -target SyFive` for each configuration). No edit. Test targets stay `1.0` (614, 641, 667, 693). `CURRENT_PROJECT_VERSION` is 1 in both, left for Pops to set at archive |
| Build result, iOS 27 device | **Succeeded, 0 errors** after §4.2. `xcodebuild build -scheme SyFive -destination 'generic/platform=iOS'`, iPhoneOS 27.0 SDK, fresh derived data (every SyFive and SyLib source compiled), 10 Oct 2026. Generic device destination; no physical device attached |
| Build result, iOS 18.6 simulator | **Succeeded, 0 errors** after §4.2. `-destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6'`, iPhoneSimulator 27.0 SDK, deployment target 18.6, fresh derived data, 10 Oct 2026 |
| New warnings (file, line, message) | **None.** Neither build emitted a compiler warning, from SyLib or from SyFive. The only line containing "warning" is the App Intents metadata tool's note, `appintentsmetadataprocessor: warning: Metadata extraction skipped, no AppIntents.framework dependency found`, which is not a compiler diagnostic |
| `SyFiveTests` result | **Passed, 0 failures** (`** TEST SUCCEEDED **`), 10 Oct 2026, on `'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6'` (`00B` §5.2). `SyFiveTests`: 14 of 14 Swift Testing tests in `FeelTests` passed. `SyFiveUITests` (XCTest): `testExample`, `testLaunchPerformance` and `SyFiveUITestsLaunchTests.testLaunch` passed; `testLaunch` ran 4 times, once per UI configuration. That is 17 distinct tests, 20 executions. Also closes `00B` A-1 clause 6, deferred here by Pops's ruling |
| R1 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R2 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R3 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R4 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R5 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R6 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R7 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R8 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R9 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R10 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R11 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R12 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R13 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R14 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R15 | **Run; reported "looks good"** (Pops on device, 10 Oct 2026). This check is Information: *which* History layout appeared at an accessibility size was not recorded, so whether the root Dynamic Type limit reaches sheets is still unanswered |
| R16 | **Pass**, 1.0.3 (App Store) with 1.1.0 (confirmed by Pops on device, 10 Oct 2026) |
| R17 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R18 | **Pass** (confirmed by Pops on device, 10 Oct 2026) |
| R19 | **Fail, as expected** (confirmed by Pops on device, 10 Oct 2026). Owner: `16` §4.4. Whether part (b) was observed was not reported separately |
| R20 | **Fail, as expected** (confirmed by Pops on device, 10 Oct 2026). Owner: `16` §4.5 |
| R21 | **Fail, as expected** (confirmed by Pops on device, 10 Oct 2026). Owner: `16` §4.6 |
| R22 | **Fail, as expected** (confirmed by Pops on device, 10 Oct 2026). Owner: `17` §4.7. Debug `MARKETING_VERSION` is back at 1.1.0 (`project.pbxproj` 413), checked after the run |
