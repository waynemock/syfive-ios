# SyLib after Syderal: bringing SyFive onto the finished SyLib

SyLib changed while Syderal was built, and Syderal's last milestone then fixed SyLib, moved into it
code that both apps had written, and brought its tests and docs up to date. SyFive was not opened,
edited, built or tested during any of that. This document is what SyFive's developer and coding
agent work from when SyFive is rebuilt against that SyLib.

**Scope:** `SyFive`. SyLib is read here, not changed, except where §3 and §4 name a SyLib change
that waits for SyFive to be open.

**Written:** 7 October 2026, at the close of Syderal's Milestone 12.

**Revised:** 9 October 2026, after Syderal's Milestone 13 ("Polish") changed SyLib again. What the
revision adds is listed at the end of §0.

**Written from:** the finished SyLib source as it stood on 7 October 2026; the SyLib source as it
stood on 2 October 2026, before Syderal's Milestone 12; the SyFive tree as supplied on 2 October
2026; and the five documents of Syderal's Milestone 12 ("SyLib review"). **Revised from:** the SyLib
source as it stood on 9 October 2026, compared file by file with the source of 7 October; the same
SyFive tree, read again where the revision names a SyFive file; and the documents of Syderal's
Milestone 13 (`23_MILESTONE_13.md` and `23A` to `23F`). All of it is from reading: nothing was
compiled, built or run, on a simulator or a device, except where a step says it was seen on one of
Syderal's devices. §5 says what was not read.

**Status:** a plan. No part of SyFive has been changed, and every edit named here is still to do.

---

## 0. How to use this document

It answers four questions, in this order.

1. **§1. What must SyFive change before it will build?** One word in one file, and a newer Xcode.
2. **§2. What will players see, hear or feel differently once it is rebuilt with no other change,
   and what must be re-tested on a device?** §2.6 is the re-test list.
3. **§3. What could SyFive adopt from SyLib in place of its own code, what would each adoption
   change, and what must it not adopt?** Every adoption is optional. One of them, §3.1, is also the
   fix for a fault SyFive's own code has today.
4. **§4. What known gaps does it inherit?**

§5 says what was not read and what could not be checked. Appendix A is the record: the sentence
each of Syderal's forty-four Milestone 12 rulings wrote for SyFive, word for word. Appendix B does
the same for the Milestone 13 rulings that touched SyLib. §1 to §4 are the same material arranged
for use.

**Paths and line numbers.** A SyFive path starts at the app folder (`App/…`, `Views/…`,
`Session/…`); the project file is `SyFive.xcodeproj/project.pbxproj` beside it. A SyLib path starts
at the package's `Sources/`. **Every SyFive line number is from the snapshot of 2 October 2026 and
must be checked against the working tree before an edit is made.** Find an edit by the declaration
named; the line number only says where to look. SyLib line numbers are from the finished source of
9 October 2026. Of the files Milestone 13 changed, only `FeelAudioEngine.swift` and
`GameNightHelpSheet.swift` are cited by line, and both were re-pointed in the revision. `MoreMenu`
is cited by declaration only.

**Citations in square brackets** such as [L-7], [SYD-357] or [F-13] are Syderal's ruling, ledger
and finding numbers. They say where the reasoning is recorded and nothing in this document needs
them to be understood. `D-nnn` is a decision in SyFive's own ledger.

**Four SyLibs are spoken of.** "The finished SyLib" is the one SyFive will build against: the
SyLib of 9 October 2026, after Syderal's Milestone 13. "The SyLib of 7 October" is the one this
document was first written from, at the close of Milestone 12. "The SyLib of 2 October" is the one
Milestone 12 started from. "The SyLib SyFive shipped on" is older than all three, and its source
was not available: the snapshot does not record which commit SyFive last built against. Where the
text written on 7 October says "Syderal's last milestone", it means Milestone 12.

**SyLib's own docs** were rewritten in the same pass and renamed. This document points to them by
their new file names (`GAME_NIGHT.md`, `COMMENTARY.md` and so on, in the package's `Docs/`) for how
an API is used, and does not repeat them. Milestone 13 added to three of them, `FEEL.md`,
`GAME_NIGHT.md` and `UI_COMPONENTS.md`, each with a *SyFive adoption* line.

**What the revision of 9 October adds.** Syderal's Milestone 13 was mostly Syderal's own polish,
but it opened SyLib for seven tasks (13.8, 13.9, 13.9b, 13.10, 13.13, 13.13a and 13.14c), with
one docs fix-up, 13.14d, still to land. Every change is additive, and every default is what it was, so nothing new is needed
before SyFive builds. For SyFive:

- **One gap is closed.** Sound effects now come back after a media-services reset without a
  relaunch, and commentary was heard again too on Syderal's device [F-14]. §2.2; re-test 10 is
  rewritten to expect it; §4.3 marks the gap closed.
- **The audio engine logs more** [F-16]. §2.2.
- **Game Night Help gains a line** about tapping Open in FaceTime the first time [F-17]. §2.3; new
  re-test 18.
- **Three new SyLibUI components, each optional:** `Toast`, a countdown on `CapsuleButton`, and
  `MoreMenu`. §3.11. One of them, `MoreMenu`, comes with a lesson that applies to SyFive's code
  today: §4.5.
- **Two faults in SyFive's own code**, found by holding it against what Syderal learned. Turning
  commentary off lets the line already speaking, and the burst behind it, play out; and the menu's
  update badge is acknowledged by a tap gesture that recent iOS does not deliver. §4.5.
- **One thing SyFive depends on that SyLib must keep:** the commentary engine's `onWillSpeak` fires
  while the engine is muted. Syderal now guards its own broadcast against that; SyFive needs it.
  §3.12.
- **Appendix B**, Milestone 13's rulings that touched SyLib, each with its sentence for SyFive.

---

## 1. Before it builds

### 1.1 The one compile break

| | |
|---|---|
| File | `App/GameNight/GameNightActivity.swift` |
| Declaration | `struct GameNightActivity: GroupActivity, Codable {` (line 7) |
| Edit | add the word `nonisolated` in front of `struct` |

After the edit the line reads:

```swift
nonisolated struct GameNightActivity: GroupActivity, Codable {
```

**Why.** SyFive's app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
(`SyFive.xcodeproj/project.pbxproj` 417 and 469), so the struct, and with it its conformance to
`GroupActivity`, is isolated to the main actor. SyLib's Game Night generics require
`Activity: GroupActivity & Sendable`: `GameNightSession`
(`Sources/SyLibGameNight/GameNightSession.swift` 34), `GameNightMatchCoordinator`
(`Sources/SyLibGameNightMatch/GameNightMatchCoordinator.swift` 21) and `gameNightAlerts(…)`
(`Sources/SyLibGameNight/Alerts/GameNightAlertsModifier.swift` 112). A conformance isolated to an
actor cannot satisfy a requirement on a `Sendable` type parameter, so the places SyFive uses its
activity as that parameter are expected to stop compiling. It names it at
`App/GameNight/GameNightController.swift` 26, 72 and 73, and `Views/ContentView.swift` 188 passes
that session to `gameNightAlerts(…)`, which infers it. Which of those lines the compiler reports
was not checked. The constraint is deliberate and stays: the session iterates
`Activity.sessions()`, whose `next()` runs off the main actor (`GameNightSession.swift` 17-22).

The error was recorded when a SyFive build was last attempted against this constraint, during
Syderal's Milestone 7: "main actor-isolated conformance of 'GameNightActivity' to 'GroupActivity'
cannot satisfy conformance requirement for a 'Sendable' type parameter" [SYD-357]. The constraint
was already in the SyLib of 2 October; the last milestone did not add it.

**What the word changes in SyFive.** The struct and its members stop being main-actor isolated. It
has no stored instance property, `activityIdentifier` is a constant string, and `metadata` only
builds and returns a value, so nothing in it needs the main actor. Its one construction site,
`GameNightActivity()` at `GameNightController.swift` 209, is unchanged.

**Not verified by compiling.** The fix is the one Syderal's records name. Syderal's own activity is
declared without the word because Syderal's project sets `nonisolated` as its default isolation, so
the exact spelling above has not been through a compiler in either app.

### 1.2 The toolchain floor

- **Xcode 27.** `SyLibUI` names two iOS 27 SDK symbols in its external-display path,
  `sceneAccessory` and `ExternalNonInteractiveAccessory`
  (`Sources/SyLibUI/ExternalDisplay/ExternalDisplayContent.swift` 56 and 70-77). They sit behind an
  availability check, but the SDK must still declare them for the file to compile. SyFive imports
  `SyLibUI` in eight files and also reaches it through `SyLibScoringUI`, `SyLibGameNight` and
  `SyLibGameNightMatch`, which depend on it. That the iOS 27 SDK means Xcode 27 is from Syderal's
  record; the source shows only the availability marks.
- **SyFive's deployment target does not move.** It stays iOS 18.6 (`project.pbxproj` 404 and 456).
  The package's own floor is iOS 17.
- **`Package.swift` declares Swift tools version 6.3** (line 1) and builds the package in the Swift 6
  language mode. The file is identical in the SyLib of 2 October and the finished one.
- **SyFive takes SyLib by local path**, `../../sylib-swift` (`project.pbxproj` 748). There is no
  version to raise. SyFive builds against whatever is checked out at that path, so the checkout must
  be the finished SyLib before the first build.
- **The package builds for macOS again.** An `IconButton` preview used toolbar placements that do
  not exist on macOS, so the package stopped building there; Milestone 13 gated that preview to
  iOS (Syderal Task 13.13a). Nothing for SyFive, which builds for iOS only. tvOS and watchOS were
  not built.

### 1.3 Nothing else was found to break

No second break was found. This is the result of reading, not of a build, and §5 says what reading
cannot show.

**What was compared.** Every `import SyLib…` in the snapshot was listed: 49 of the app's 55 Swift
files and one test file import eleven of SyLib's thirteen modules. No file imports `SyLibCache` or
`SyLibDSP`. Because the SyLib commit SyFive last built against is not known, "what changed" could
not be the measure. Each call was compared with the finished declaration itself.

| Module | SyFive files | How it was compared | Result |
|---|---|---|---|
| `SyLibGameNight` | 13 | Every member SyFive reads or calls on the session (42), the proximity component (15), the log buffer (10) and the alert state; every initialiser of `GameNightTableView`, `GameNightHelpSheet`, `SeatClaimSheet`, `SeatRosterEntry`, `GameNightPendingSheet`, `GameNightInviteInstructions`, `GameNightLogSheet` and the payload types; the `gameNightAlerts(…)` call. Labels, order and closure shapes read side by side | All match. `gameNightAlerts(…)` gained one defaulted parameter that SyFive does not pass (`ContentView.swift` 188-207) |
| `SyLibGameNightMatch` | 6 | Every coordinator member SyFive uses (28), the payload types, `GNMatchIdentity`, and every requirement of `GameNightMatchHost` against `Session/MatchController.swift` | All match. `resumeAsHost` now returns a discardable `Bool`; SyFive's one call (`GameNightController.swift` 312) ignores it. The protocol's two newer requirements, `appStateBlob` and `loadAppState(_:)`, have default implementations (`Sources/SyLibGameNightMatch/GameNightMatchHost.swift` 64-68), so the conformance at `MatchController.swift` 841 still holds |
| `SyLibCommentary` | 17 | The engine's initialiser and the six members SyFive uses; `CommentaryPersonality`, `CommentaryProsody` and `CommentaryEvent` initialisers as the four packs and the event factories call them; `CommentarySettingsView`; the `CommentaryEventKind` protocol | All match. The newer parameters (`ipaTable`, `prosodyOverrides`, `voiceCriteria`, `personalityTitle`, `personalityFooter`) are defaulted |
| `SyLibFeel` | 14 | The 19 `FeelDirector` members SyFive uses; every recipe initialiser in `Feel/SyFiveCatalog.swift` and `Views/FeelBoardView.swift`; `SoundRenderer` and `SoundCache` as `SyFiveTests/Feel/FeelTests.swift` calls them | All match. The newer `reverbSend`, `reverbPreset` and `reverbWetMix` are defaulted |
| `SyLibCore` | 18 | `AppLogger` (initialiser, four level methods, `appName`), `AppUpdateChecker.shared.isUpdateAvailable()`, `Bundle.appVersionShort` | All match |
| `SyLibUI` | 8 | `AboutView`, `IconButton` (both initialisers), `InitialsCircle`, `ParticleBurst`, `Particle`, `rainbowBorderIfNeeded`, `PlayerLinkSheet`, `PlayerMergeSheet`, `PlayerRosterEntry` | All match |
| `SyLibScoringUI` | 4 | All eight view and record initialisers SyFive calls | All match. `numericDate` and `numericMatchDates` are defaulted |
| `SyLibScoring`, `SyLibScoringData` | 28, 21 | By name: every function and member SyFive calls exists as a public declaration. Not label by label | No name missing. The value types, enums, models, schema and conversions are byte-identical in the SyLib of 2 October and the finished one |
| `SyLibYatzy`, `SyLibDice` | 14, 5 | By name, as above | No name missing. Both modules are byte-identical in the SyLib of 2 October and the finished one, and every file in them is dated before SyFive's newest source file |

**Kinds of break looked for, and what was found.**

- **Removed or narrowed declarations.** One public declaration is gone:
  `sessionCheckpoint(_:)` in `SyLibFeel`, a DEBUG-only function. SyFive does not call it [L-25]. One
  setter changed, and widened, not narrowed: `GameNightSession.isSessionActive` is
  `public internal(set)` where it was `public private(set)` (`GameNightSession.swift` 47), and
  SyFive only reads it. The session's `handle(_:from:)` is internal where it was private (662), so
  that SyLib's tests can deliver a message; an app cannot call it either way. No name SyFive uses
  as a member or a call matches a SyLib declaration that is internal or private.
- **Enums that gained a case.** `PlayerSource` gained `.computer`
  (`Sources/SyLibScoring/Enums/PlayerSource.swift` 11). SyFive never switches over it; it compares
  with `==` (`Views/PlayersView.swift` 27, 31 and 103). SyFive switches over three SyLib enums,
  `SoundRecipe.Layer` (`Views/FeelBoardView.swift` 205) and `SectionLean` and `BonusApproach`
  (`Views/Stats/PlayerProfileView.swift` 399 and 407), and none of them has gained a case.
- **A name SyFive and SyLib now both declare.** `SyLibUI` has a new public `PlayerEditSheet`, and
  SyFive has its own (`Views/PlayerEditSheet.swift` 6). A type declared in the app shadows an
  imported one of the same name, which is how SyFive's `AboutView` already lives beside
  `SyLibUI.AboutView` (`Views/AboutView.swift` 4 and 11). So SyFive's existing uses keep meaning
  SyFive's sheet [L-20]. Not compiled.
- **The test target.** `FeelTests.swift` is the only test file that imports SyLib. Its calls match.
- **Milestone 13's additions** (checked 9 October 2026). Four new public names: `Toast`, the view
  modifier `toast(_:duration:bottomPadding:)`, `MoreMenu` and `CapsuleButton.Countdown`. A search of
  the snapshot finds none of the four names, nor `toast`, declared or used in SyFive, so nothing is
  shadowed and nothing is ambiguous. `CapsuleButton`'s initialiser gained `countdown`, defaulted
  and placed before `action`, so a trailing-closure call compiles unchanged; SyFive does not use
  `CapsuleButton`. `IconButton` changed only in a preview. `FeelAudioEngine` gained no public
  member, and `GameNightHelpSheet` changed only in its text.

### 1.4 Wire and schema need no change

**Do not raise SyFive's `appProtocolVersion`.** It is 1
(`App/GameNight/Protocol/GameNightEnvelope.swift` 21). No SyFive payload changes shape, and a host
declines any joiner whose value differs (`GameNightSession.swift` 696-703), so a raise would stop
the rebuilt app and the shipped app from sharing a table.

**The transport version is unchanged.** `GameNightEnvelope.currentProtocolVersion` is 3
(`Sources/SyLibGameNight/Protocol/GameNightEnvelope.swift` 15), the value SyFive's own proximity
work set (`Docs/Requirements/16_GAME_NIGHT_PROXIMITY_MUTE.md`).

**The payloads are compatible.** The session payloads and the match payloads are byte-identical in
the SyLib of 2 October and the finished one. By Syderal's records three fields were added earlier,
while Syderal was built, and all three are optional and default to nil:
`TableStatePayload.hostSeatClaimID`
(`Sources/SyLibGameNight/Protocol/GameNightPayloads.swift` 95) and `appState` on
`MatchStartPayload` and `MatchStatePayload` (`Sources/SyLibGameNightMatch/MatchPayloads.swift` 18
and 42). A build that has them reads nil when the key is absent, and a build that lacks them
ignores the key. SyFive's match controller supplies no `appState`, so a rebuilt SyFive sends none.
Neither version number separates the rebuilt app from a build of the snapshot's source, so the two
can meet at one table; §2.6 lists that as a re-test. Whether the build now on the App Store is
such a build was not checked. SyFive's proximity document records that 1.0 builds from before
that work, on transport version 2, cannot join a version 3 build
(`Docs/Requirements/16_GAME_NIGHT_PROXIMITY_MUTE.md` 349-351). That is SyFive's own earlier
change, not SyLib's, and a rebuild neither causes it nor cures it.

**There is no migration.** No model, attribute or schema version changed in SyLib's shared schema
[L-1]. The model, schema and conversion files are byte-identical in the two SyLib trees.
`PlayerSource.computer` is a new raw value of an existing string attribute, not a schema change,
and SyFive creates no such player.

**A later schema addition needs a deploy in each app.** Syderal's CloudKit schema went to
Production on 2 October 2026. SyLib's shared models are part of both apps' schemas, so a model or
an attribute added to them later must be created in each app's CloudKit Development environment
and deployed to Production before the build that writes it ships [L-31]. Syderal keeps a DEBUG-only
helper for the first half of that. Syderal's documents say no such helper was found in SyFive. The
snapshot does hold one, of a different kind: `runCloudKitSchemaExercise()`
(`Views/ContentView+Persistence.swift` 225-248), called under `#if DEBUG` at
`Views/ContentView.swift` 255 and switched by `AppConfig.DebugCloudKit.runSchemaExercise`
(`Utilities/AppConfig.swift` 26, false in the snapshot). It inserts and deletes one default row of
each model. Whether a default row creates a CloudKit field for a new attribute whose default is
nil was not checked.

---

## 2. What changes with no change to SyFive

Each entry says what SyLib now does, what a SyFive player or developer would notice, where it is
in SyLib, and whether SyFive can have the old behaviour back. Entries marked *earlier* changed
while Syderal was being built, before its last milestone; no earlier SyLib tree exists to compare
with, so those rest on Syderal's records and on what the finished source shows. Entries marked
*Milestone 13* were added by the revision of 9 October and were compared with the SyLib of
7 October line by line. The others are Milestone 12's.

### 2.1 Commentary

**The queue rule is SyFive's own again, with three narrow differences** [L-7].

- *Now.* `CommentaryEngine.queuePolicy` defaults to `.dropWhileSpeaking`
  (`Sources/SyLibCommentary/Engine/CommentaryEngine.swift` 73 and 241-281;
  `Sources/SyLibCommentary/Model/CommentaryQueuePolicy.swift` 11-32). Lines are accepted in bursts.
  A burst opens when a line becomes the first line in flight and stays open until that line is
  reported started. While it is open every event is appended in order, whatever its tier, up to
  four lines. Once it has closed, an event more important than the line speaking stops that line,
  discards everything waiting and speaks at once; any other event is dropped.
- *Noticed as.* This is D-078, "Higher-tier events interrupt; same-or-lower-tier events drop. Never
  build a backlog", as the shipped SyFive runs it. It differs from the SyLib of 2 October, which
  queued up to three lines behind the speaker and let a highlight cut a play-by-play line from the
  same scoring action. Against that SyLib a rebuilt SyFive regains three things: commentary never
  runs behind the dice; the lines of one scoring action all speak, in order; and at Game Night
  guests speak the lines the host speaks, because the host no longer relays a line and then cuts
  it.
- *The three differences from the shipped SyFive.* (a) During the later lines of a burst, a new
  event is compared with the tier of the line actually speaking. The shipped engine kept one
  current tier, which after a burst is inferred to have been the tier of the last line handed
  over, so whether a middle-tier event interrupts during those later lines can differ. This is
  inferred: the shipped engine's source was not available. (b) A guest holds at most four relayed
  lines and drops the newest beyond that (`CommentaryEngine.swift` 388-389). The shipped engine is
  inferred to have handed every relayed line to the synthesizer's own queue. The last milestone
  did not change this. (c) A burst stays open until its first line is reported started. In the
  shipped engine it stayed open only until the synthesizer's `isSpeaking` turned true, on the next
  run-loop pass. The difference is a fraction of a second.
- *When a burst closes.* AVFoundation reports a line's start when the line is handed to it, before
  the line's pre-utterance delay, not when the line is first heard. That was seen on a device in
  Syderal, on a line with a 0.8 second delay [F-20]. Zen's delay is 0.35 seconds
  (`App/Commentary/Packs/Pack+Zen.swift` 9). So an event that arrives in that silent gap is already
  treated as arriving while a line speaks. One assumption is still unverified on any device: that
  the start is not reported in between the events an app emits together. It matters only under
  this policy, which is SyFive's and not Syderal's, so re-test 1 in §2.6 is its first check.
- *Old behaviour back.* There is nothing to restore: this is the shipped rule. `.queue` exists and
  is what Syderal sets, but it is the backlog D-078 forbids, and this document does not propose it.
  SyFive's ledger row D-078 and `Docs/Requirements/09_COMMENTATOR_DESIGN.md` §1.5 are SyFive's to
  amend, to describe the burst and the three differences.

**Commentary recovers by itself from a lost callback, and a route change cuts the line in flight**
(*earlier*) [SYD-409].

- *Now.* Each line has a watchdog. If neither a finish nor a cancel is reported within the larger
  of 6 seconds and 0.12 seconds per character of the line, the engine rebuilds its synthesizer and
  moves on (`CommentaryEngine.swift` 86-87, 481-489 and 504-511). When an audio device joins or
  leaves the route, when media services reset, and when an audio interruption begins, the engine
  rebuilds or stops and clears its queue (566-625).
- *Noticed as.* Commentary no longer goes silent for the rest of a match after AirPlay or
  headphones are connected or removed. A line being spoken at that moment is cut, and lines
  waiting behind it are dropped.
- *The risk to check.* A line still being spoken when its allowance runs out would be cut. The
  allowance has never run against SyFive's packs. Zen is the slowest (rate 0.42, with 0.35 seconds
  before and 0.30 after each line), and 171 of its 434 lines are longer than 50 characters, the
  length at which the per-character allowance passes the 6 second floor. Re-test 4.
- *Old behaviour back.* No. The two watchdog values are internal.

**Five commentary rulings change nothing for SyFive.** Pronunciation-table terms match whole words
only; SyFive's four packs pass no table, so that code never runs for it [L-8]. `onIdle` now fires on
every change from busy to idle and the engine can be waited on; SyFive sets no `onIdle` and waits
for nothing [L-9]. The automatic voice and the shuffle store are new types SyFive does not use
[L-10, L-11, L-32].

### 2.2 Sound and haptics

**The audio session's category is set when the engine is created** (*earlier*).

- *Now.* `FeelAudioEngine.init` sets the ambient, mix-with-others category before it attaches any
  node (`Sources/SyLibFeel/Playback/FeelAudioEngine.swift` 46-75). The source gives the reason:
  attaching nodes engages the session, and without the call it engaged under the system default,
  which interrupts other audio.
- *Noticed as.* Creating the director (`Views/ContentView.swift` 15) should no longer interrupt
  music from another app. With Sound set to Game Audio Only the category changes when the mode is
  applied, a moment later (`ContentView.swift` 261), and other audio stops then, as the Settings
  footer says it will.
- *Old behaviour back.* No.

**The audio engine starts at warm-up, in every sound mode** (*earlier*) [SYD-302].

- *Now.* `FeelDirector.warmUp()` ends by starting the engine with nothing to play
  (`Sources/SyLibFeel/FeelDirector.swift` 79; `FeelAudioEngine.swift` 398-400). It does not look at
  the sound mode.
- *Noticed as.* The first sound of a launch no longer waits for the engine to start. With Sound
  set to Off the app still activates its audio session and runs the engine from launch, silently.
- *Old behaviour back.* No.

**A reverb bus is in the audio graph, with its return at zero for SyFive** (*earlier*) [SYD-192].

- *Now.* Each one-shot player feeds a dry path and a reverb send (`FeelAudioEngine.swift` 79-107).
  The return gain is the catalog's `reverbWetMix`, which defaults to 0
  (`Sources/SyLibFeel/Recipes/FeelRecipes.swift` 180). `Feel/SyFiveCatalog.swift` passes no reverb
  value.
- *Noticed as.* Nothing is meant to be heard: the design intent recorded for it is that SyFive's
  output is unchanged. It has not been listened to in SyFive.
- *A first-launch effect, if the shipped SyLib had no `reverbSend`.* Each sound recipe now carries a
  `reverbSend` field (`FeelRecipes.swift` 12), and the sound cache names each file by a hash of the
  recipe's encoded form (`Sources/SyLibFeel/Render/SoundCache.swift` 84-95). If the SyLib SyFive
  shipped on had no such field, every sound's cache name changes, so the first launch after the
  update renders all sounds again once and sweeps the old files (`FeelDirector.swift` 47-86). The
  rendered sound itself does not depend on the field. Whether the shipped SyLib had the field could
  not be checked.
- *Old behaviour back.* No.

**Sound effects and haptics survive a route change** (*earlier*) [SYD-428].

- *Now.* When AirPlay or headphones change the output, the engine stops its players, and the next
  sound restarts the engine and reconnects the output (`FeelAudioEngine.swift` 159-193 and
  331-386). The haptic engine restarts on the next haptic after any stop other than suspension
  (`Sources/SyLibFeel/Playback/FeelHapticEngine.swift` 90-114).
- *Noticed as.* Sound effects and haptics keep working after AirPlay is turned on or off. A sound
  playing at the moment of the change is cut.
- *Old behaviour back.* No.

**Haptics come back after a haptic server reset** [L-30].

- *Now.* The haptic engine keeps the recipes it was prepared with and rebuilds its players after a
  reset, at once or at the next foreground or the next haptic (`FeelHapticEngine.swift` 50-58,
  85-89 and 118-141).
- *Noticed as.* After such a reset, haptics return without a relaunch. Since Milestone 13, sound
  effects do too (the next entry).
- *Old behaviour back.* No, and nothing is asked of the app.

**Sound effects come back after a media-services reset** (*Milestone 13*) [F-14, SYD-499,
SYD-505].

- *Now.* The audio engine observes `AVAudioSession.mediaServicesWereResetNotification` on every
  platform but macOS (`FeelAudioEngine.swift` 117-122) and, on the main queue (148-152), rebuilds
  itself the way it was built: a new `AVAudioEngine`, new one-shot, bed and reverb nodes, connected
  as before, the last `setReverb` applied again, and the configuration-change observer moved to the
  new engine (195-227). It keeps every loaded sound and the sound mode. The session is not touched
  at the reset; the next sound's start sets the category and activates it, as every start does.
  A start that was in flight when the reset came works on the engine it began with, and its result
  is dropped when it lands (343-346, 358-360 and 376-377), so the sounds waiting on it are dropped
  too. One new test drives that case.
- *Noticed as.* After Settings, Developer, Reset Media Services, the next roll has its sounds, with
  no relaunch. A sound asked for in the moment of the reset can be lost. On Syderal's device
  commentary also spoke again after the reset; the commentary engine was not changed for that, as
  it already rebuilt its synthesizer on the same notification (`CommentaryEngine.swift` 566-625).
  Re-test 10.
- *Old behaviour back.* No, and nothing is asked of the app. The rebuild is internal.

**The audio session's errors are logged** [L-34], **and more of the engine's life** (*Milestone 13*)
[F-16, SYD-501].

- *Now.* A failed `setCategory` or `setActive` is logged as a warning, and each engine start logs
  one line with the session's category, whether other audio is playing, and the output route
  (`FeelAudioEngine.swift` 283-320). Milestone 13 added four info lines: `engine started: output
  <rate> Hz <channels> ch` on each successful start that is not a restart after a configuration
  change (364); `audio session interruption began` and `audio session interruption ended` (135 and
  139); and `media services reset: rebuilding the engine (was running=<true or false>)` (202).
- *Noticed as.* New lines in SyFive's log under the `FeelAudioEngine` category. Nothing else. They
  are what would explain a launch that stays silent (§4.3).

### 2.3 Game Night

**A guest is told the host is newer only when it is** [L-12].

- *Now.* The "Can't Join Game Night" alert offers Update, and says the host runs a newer version,
  only when the host's transport version is higher than this build's
  (`Sources/SyLibGameNight/Alerts/GameNightAlertsModifier.swift` 72-89;
  `Sources/SyLibGameNight/Alerts/VersionMismatch.swift` 39-41). It used to compare the host's
  transport version with the app's own protocol version, which is 1 in SyFive, so a host on any
  transport version above 1 read as newer, an older one included.
- *Noticed as.* A visible bug fix. A SyFive guest whose host is on an older build is told the host
  runs a different version and is not offered Update.
- *Old behaviour back.* No.

**`GroupSession.join()` runs off the main thread, and has never run beside proximity ranging**
(*earlier*).

- *Now.* The session hands `join()` to a serial queue (`GameNightSession.swift` 170-180 and
  442-445).
- *Noticed as.* Nothing is intended to show. Syderal has no proximity ranging, so this ordering has
  never run with it. SyFive begins ranging in the same pass that a session becomes active
  (`Views/ContentView.swift` 307; `App/GameNight/GameNightController.swift` 52-62). Re-test 11.
- *Old behaviour back.* No.

**The SharePlay sharing sheet is presented on the device's own scene** (*earlier*).

- *Now.* The sheet is presented over the topmost view controller of the foreground scene whose role
  is the device's own window (`Sources/SyLibGameNight/Views/GameNightSharing.swift` 58-66), where it
  used to take the first active scene, which with a TV connected could be the TV's.
- *Noticed as.* Nothing on a device with no external display. With one connected, the sheet stays
  on the device.

**The seating screen's footer for someone with no seat reads differently** (*earlier*).

- *Now.* The footer under "Claim a seat" ends "you'll spectate the game in real time."
  (`Sources/SyLibGameNight/Views/GameNightTableView.swift` 211). By Syderal's record it used to end
  with "live dice and scores".
- *Noticed as.* Different words on SyFive's seating screen. There is no parameter for the text.

**Game Night Help tells a first-time guest to tap Open in FaceTime** (*Milestone 13*) [F-17,
SYD-502].

- *Now.* Two lines are added to `GameNightHelpSheet`, with the app's name filled in. In the
  pre-session help, under "Already invited?": "First time playing on this device? If SyFive doesn't
  open on its own, go back to FaceTime and tap **Open** next to SyFive."
  (`Sources/SyLibGameNight/Views/GameNightHelpSheet.swift` 105). In the host's help, under "If a
  guest missed the notification": "A guest playing on a device for the first time may need to go
  back to FaceTime and tap **Open** next to SyFive." (138). The joining and joined help are
  unchanged.
- *Noticed as.* One more line in each of those two places. SyFive presents the sheet from its
  help button with the derived context (`Views/ContentView.swift` 528-535;
  `Views/ContentView+GameNight.swift` 163-171), so both lines reach it. Its table's help passes
  `.joining` (`App/GameNight/Views/TableSettingView.swift` 71-74) and shows neither. The wording
  was checked against FaceTime on Syderal's devices. Re-test 18.
- *Old behaviour back.* No. There is no parameter for the text.

**A teardown reports its reason, and its log line changed** [L-13].

- *Now.* `onTearDown` fires at the same moment for the same teardowns as before
  (`GameNightSession.swift` 617), so SyFive's hook (`GameNightController.swift` 175) is unaffected.
  A second hook, `onTearDownWithReason`, is nil unless wired. The log line now begins
  `tearDownSession: reason=… role=…` (578), where it began `tearDownSession: role=…`.
- *Noticed as.* Only by something that reads that line. It is logged under the `GameNightSession`
  category, which SyFive's Game Night log file does not keep (§4.2).

**The log sheet's Share button shares the file that exists** [L-15].

- *Now.* `GameNightLogSheet(matchID:)` shares the file the log buffer wrote, under
  `gnlogs/syfive/` (`Sources/SyLibGameNight/Diagnostics/GameNightLogSheet.swift` 9-13).
- *Noticed as.* Only in a build with `AppConfig.DebugGameNight.showLogs` set. It is false in the
  snapshot (`Utilities/AppConfig.swift` 32), and both places that present the sheet are behind it
  (`Views/Stats/MatchDetailView.swift` 64 and 82; `Views/Stats/UnfinishedMatchDetailView.swift` 64
  and 99).

**Three changes SyFive never meets** [L-25, L-44]. `resumeAsHost` refuses, with an error in the log,
a match host whose per-player arrays are shorter than its player count, where it used to trap;
SyFive's arrays move together (`Session/MatchController.swift` 205-318). It now returns whether it
resumed. `absorbPlayer` does nothing when asked to absorb a player into itself, where it used to
delete the player; neither of SyFive's two callers can ask for that (`Views/PlayersView.swift` 111
and 132, with the filter at 126).

### 2.4 Screens

**Commentary settings: Mode and Level are lists of checkmark rows** (*earlier*).

- *Now.* Each choice is a row with a checkmark on the selected one, drawn like the personality
  rows (`Sources/SyLibCommentary/Views/CommentarySettingsView.swift` 78-117). They were segmented
  controls.
- *Noticed as.* SyFive's Commentary screen (`App/Commentary/CommentaryScreens.swift` 11-18) looks
  different, and the labels now grow with Dynamic Type.
- *Old behaviour back.* No parameter chooses the old controls.

**The voice picker and the Add Voices sheet** (*earlier*).

- *Now.* On iOS 27 and later, step 3 of Add Voices reads "Tap Read & Speak, then Voices."; on
  earlier versions it reads "Tap Spoken Content, then Voices."
  (`Sources/SyLibCommentary/Views/AddVoicesSheet.swift` 16-29). The settings view and the picker
  pass the Dynamic Type size in effect to the sheets they present (`CommentarySettingsView.swift`
  64-75; `Sources/SyLibCommentary/Views/VoicePickerView.swift` 54-60). The picker builds its lists
  off the main actor and shows a spinner until they are ready (30-38 and 74-79); when that arrived
  is not in the documents read.
- *Noticed as.* The new wording on iOS 27. For the type size: SyFive limits Dynamic Type at its
  root (`SyFiveApp.swift` 40) and shows Settings in a sheet with no limit of its own. If the root
  limit does not reach that sheet, which is what Syderal's device checks found in Syderal, nothing
  changes. That has not been looked at in SyFive.

**About: the footer is opaque** (*earlier*) [SYD-418].

- *Now.* `AboutView` hands its background colour to the footer
  (`Sources/SyLibUI/Branding/AboutView.swift` 141-143), where the footer used to be drawn on a clear
  background.
- *Noticed as.* SyFive passes its theme's background (`Views/AboutView.swift` 17), so its footer is
  opaque in the colour it already sits on, and the description no longer shows through it while
  scrolling.

**History rows at accessibility text sizes** (*earlier*).

- *Now.* At accessibility sizes `MatchHistoryRow` puts the date and the winner on separate lines
  (`Sources/SyLibScoringUI/History/MatchHistoryRow.swift` 65-75). The same row draws the shared
  games in the head-to-head detail.
- *Noticed as.* Only where SyFive can reach an accessibility size, which depends on the same
  unanswered question about its root limit and its sheets.

### 2.5 Rulings that left SyLib alone

Fourteen of the forty-four rulings changed nothing in SyLib, and a fifteenth changed only its
docs [L-26]. Of the fourteen, one set the terms on which code moved into SyLib. The other thirteen
changed only Syderal's app: its history sync, Feel and the scene phase, its snapshot times, its
speech payload, a guest's rematch, its two Reconnect offers, the host's ended alert, its CloudKit
helper, its Rejoin prompt, its mid-turn board, its game view's callbacks and its display wordmark.
For SyFive each of the fourteen begins "nothing"; Appendix A has every sentence. One of them
leaves a question, in §5: whether SyFive's own Reconnect offer has the
fault Syderal fixed in its own [L-28].

### 2.6 Device re-tests

Run these on devices after the first successful build. Two devices on one FaceTime call are needed
where a step says host and guest. When both are in one room on phones that range, proximity mutes
commentary on one of them (re-test 11). For a step that listens to both, first tap the commentary
button beside the roll button on the muted device (`Views/DiceAreaView.swift` 118), which unmutes
it for the match.

1. **A burst of four lines.** Two players on one device, Commentary on for all games, level
   Play-by-Play. With nothing being spoken, score so that one scoring both earns the upper bonus
   and takes the lead. *Expect* four lines, in order and none cut: the score, the upper bonus, the
   lead change, and the next player's turn.
2. **No backlog.** As 1, then have the next player roll and score a small, ordinary category, one
   that neither changes the lead nor earns the upper bonus, while those lines are still being
   spoken. *Expect* no line for the new score. Repeat with a score of 25 or more while a turn line
   or an ordinary score line (under 25 points) is being spoken. *Expect* that line to stop and the
   new score's lines to speak. Nothing is held back to be spoken after a later score.
3. **Host and guest say the same.** Host and guest at Game Night, commentary on at Play-by-Play.
   Repeat 1 on the host. *Expect* the guest to speak the same four lines in the same order.
4. **Zen's long lines.** Personality Zen, Play-by-Play, a full game. *Expect* every line to be
   spoken to its last word. A line that stops early with no new event is the watchdog (§2.1).
5. **Commentary settings.** Settings, Commentary. *Expect* Mode and Level as rows with a
   checkmark; a tap moves the checkmark and takes effect; the labels grow at larger text sizes.
6. **Voices.** Open the voice picker, choose a voice, tap Preview, open "Add more voices".
   *Expect* a spinner and then the list; the preview in the chosen voice; and on iOS 27 step 3
   reading "Tap Read & Speak, then Voices."
7. **Other audio at launch.** Play music in another app, then launch SyFive with Sound set to Mix
   with Other Audio, to Off, and to Game Audio Only in turn. *Expect* the music to keep playing
   through launch and the first roll in the first two, and to stop in the third.
8. **First launch after the update.** Install over the shipped app and roll at once. *Expect* no
   pause at launch, and every sound once warm-up has finished. A sound whose buffer is not loaded
   yet is skipped, not delayed (`Sources/SyLibFeel/FeelDirector.swift` 46;
   `Sources/SyLibFeel/Playback/FeelAudioEngine.swift` 404-405), so a roll made while the sounds are
   being rendered again (§2.2) may be silent. A sound still missing after that is a fault.
9. **A route change.** Mid-game, connect and then disconnect AirPods or AirPlay. *Expect* sound and
   haptics on the next roll each time, and commentary on the next event. A line being spoken at
   the change is cut.
10. **A media-services reset.** Mid-game, with commentary on, use Settings, Developer, Reset Media
    Services, then return. *Expect* sound effects and haptics on the next roll, and commentary on
    the next event, all with no relaunch (§2.2). In the console, `media services reset: rebuilding
    the engine` once, then `engine started` with the next sound. A sound effect still silent after
    the second roll is a fault; write down whether commentary spoke, because Syderal's device is
    the only one that has shown it does.
11. **Game Night with proximity.** Host and guest in one room on phones that range, commentary on.
    Start Game Night, seat both, start. *Expect* the session to join as before and one device's
    commentary to be muted by proximity.
12. **The sharing sheet.** Start Game Night on a call, once with nothing connected and once while
    mirroring to a TV. *Expect* the sheet on the device both times.
13. **The seating screen.** On a device with no seat claimed. *Expect* the footer ending "you'll
    spectate the game in real time."
14. **About.** Open About on the smallest phone and scroll. *Expect* an opaque footer with no text
    showing through it.
15. **History at a large text size.** Set an accessibility text size and open History. *Expect*
    either the usual row or the date above the winner. Write down which: it answers the question
    about the root limit in §2.4.
16. **Old build and new build at one table.** The rebuilt app hosts and the shipped app joins;
    then the reverse. Use a shipped build on transport version 3: an older one is declined at the
    table, as it was before the rebuild (§1.4). Seat, play a match to its end, with commentary on.
    *Expect* both to seat, scores and relayed lines to arrive, and the match in both Histories.
17. **The Game Night endings.** Host and guest, a match in progress. (a) The host ends Game Night
    from the menu. (b) The call is hung up. (c) The host relaunches and answers "Reconnect Game
    Night?" with Resume as Host. (d) The guest relaunches and answers "Reconnect to Game Night?"
    with Rejoin. (e) The match is finished and the host taps Play Again. *Expect* what the shipped
    app does in each. SyLib's session and coordinator were edited throughout, so this is a
    regression pass; no change is intended.
18. **Game Night Help.** On a FaceTime call with no Game Night started, tap the Game Night help
    button. *Expect* under "Already invited?" the line "First time playing on this device? If
    SyFive doesn't open on its own, go back to FaceTime and tap **Open** next to SyFive." Then
    start Game Night as host and, while the table is being set, open help again. *Expect* under "If a guest missed the
    notification" the line about a first-time guest tapping **Open**, with SyFive's name in both.
    If a fresh install is to hand, have it join as a guest: *Expect* it to need that tap once, as
    the line says [F-17].

Two changes cannot be staged without extra builds: the version alert of §2.3 needs a host on a
different transport version, and the log sheet needs a build with the log flag on.

---

## 3. What SyFive could adopt, and must not

SyFive adopts nothing by being rebuilt. Each entry below is optional and independent. Each says
what the SyLib API is, what it would replace in the snapshot, what would behave differently
afterwards, what stays SyFive's to do, and which SyLib doc shows the usage.

### 3.1 The host's End: one awaited call, and the lost `matchAbandoned`

This is the one adoption that fixes a fault SyFive has today [L-14].

- **The fault.** `GameNightController.abandonSession()` (`App/GameNight/GameNightController.swift`
  223-227) sends `matchAbandoned` and then calls `session.abandonSession()`. `send` only schedules
  its send in a task (`GameNightSession.swift` 792-808, reached through the match-kind overload
  at `Sources/SyLibGameNightMatch/GameNightMatchKind.swift` 23-25), and `abandonSession()` ends the
  session and drops the messenger before that task runs (496-500 and 576-592). So the message is
  lost and the guest never hears that the host ended Game Night. Its session ends anyway, because
  the host ended the activity, and the guest treats that as a dropped call.
- **What it costs SyFive today.** Little that a player sees: when a match was in progress, a drop
  and a heard ending both raise "Game Night ended" on a SyFive guest. The difference shows when
  the call's audio is interrupted. A heard ending raises the alert at once
  (`GameNightMatchCoordinator.swift` 639-640). A drop in the six seconds after the interruption
  ends has its alert held until those six seconds are up, and a drop while the interruption is
  still going on raises no alert at all (`GameNightSession.swift` 524-548, 612 and 644-656; §4.6).
  It would also matter to any code that tells an ending from a drop (§3.11).
- **The SyLib API.** `GameNightMatchCoordinator.abandonSessionNotifyingGuests(timeout:)`
  (`Sources/SyLibGameNightMatch/GameNightMatchCoordinator.swift` 416-426). It awaits the send for
  up to 1.5 seconds by default, then abandons the session whether or not the send was delivered,
  and returns true when it ran the ending. It does nothing and returns false unless this device
  hosts an active session, and while an earlier call is still waiting. One case the return value
  does not tell apart: if the session drops while the send is awaited, `abandonSession()` then
  fails its own guard and does nothing (`GameNightSession.swift` 497), the teardown has already
  run as a drop, and the method still returns true. On a SyFive host in a match that drop raises
  "Game Night ended" with its Reconnect button after the host chose End. The window is the wait,
  1.5 seconds at most. Read from source, not seen.
- **What it replaces.** The body of `abandonSession()` at 223-227, which becomes one awaited call
  to `coordinator.abandonSessionNotifyingGuests()` from a task. Its one caller is the alert's
  `onAbandonSession` (`Views/ContentView.swift` 193).
- **What would differ.** The session, and so SyFive's teardown hook, ends up to 1.5 seconds after
  the tap, not in the same pass. Guests hear the message. Each guest that hears it ends the
  activity itself, which is harmless here because the host is ending it too (§4.1).
- **Still SyFive's.** Nothing new. `performControllerTearDown()` still runs from `onTearDown`.
- **Doc.** `GAME_NIGHT_MATCH.md`, on ending Game Night as host; `GAME_NIGHT_ADOPTION.md` §5.

### 3.2 A guest's rejoin: routing, restore and prepare

- **The SyLib API.** Three coordinator methods [L-19, L-41]:
  `routeMatchMessage(_:envelope:from:onMatchState:)` (`GameNightMatchCoordinator.swift` 547-556),
  `restoreRejoiningGuest(from:)` (506-533) and `prepareForGuestReconnect(matchID:)` (479-486).
- **What they replace.** The head of SyFive's router (`GameNightController.swift` 366-377), the
  identity restore at the top of `handleMatchState` (421-426), and SyFive's own
  `prepareForGuestReconnect(matchID:)` (249-254).
- **What would differ.** (1) SyFive restores the match id and the game id only when it held no
  participant id, and each only when nil. SyLib restores the participant id only when none is held,
  and takes the match id and game id from the host's state whenever they differ, so ids held from
  an earlier match are replaced. (2) SyLib clears `session.isGuestAwaitingReconnect` when the
  host's `matchState` arrives. SyFive's roll button reads that flag (`Views/DiceAreaView.swift` 351,
  and 318 and 368), and today only a new session or a teardown clears it
  (`GameNightSession.swift` 429 and 611). So a SyFive guest that taps Rejoin while a session is
  already up cannot roll until that session ends. This is read from source and has not been seen
  on a device.
- **Still SyFive's.** Decoding the payload, loading the match and everything else in
  `handleMatchState` (427-448). And one path SyLib does not cover: a guest that catches up by a
  match start, not a `matchState`, keeps the flag. Either SyFive clears
  `session.isGuestAwaitingReconnect` in its `onMatchStarted` hook (`GameNightController.swift`
  161-167), or SyLib's match-start handler gains the clear. Syderal's milestone left that SyLib
  edit undone because it would change a path SyFive uses and SyFive was not open to test it, and
  recorded it as the cleaner fix.
- **Doc.** `GAME_NIGHT_MATCH.md`, on routing incoming messages and on guest rejoin.

### 3.3 A host's reconnect: the pending resume, the delay, and the answer

- **The SyLib API.** On the coordinator [L-23, L-44]: `recordPendingHostResume(matchID:gameID:)`,
  `hasPendingHostResume`, `pendingHostResumeMatchID`, `clearPendingHostResume()`,
  `consumePendingHostResume()` and `onHostResumed` (`GameNightMatchCoordinator.swift` 313-389). On
  the session: `GameNightSession.seatingSheetDelay`, 500 milliseconds (`GameNightSession.swift`
  301). And the coordinator's `resumeAsHost(matchID:gameID:)` now returns whether it resumed
  (`GameNightMatchCoordinator.swift` 266-309).
- **What they replace.** SyFive's `pendingResumeMatchID` and `pendingResumeGameID`
  (`Views/ContentView.swift` 33-34): set at 197-198 and at `Views/ContentView+Persistence.swift`
  26-31, cleared at 201-202, 212-213 and 219-220, and consumed at 405-408. And the literal delay at
  `ContentView.swift` 416.
- **What would differ.** SyFive today calls `resumeAsHost` whenever its two ids are set and skips
  its seating sheet whatever that call did. `consumePendingHostResume()` returns false when the
  session that arrived is not one this device can resume into, and SyFive would then fall through
  to its seating sheet. One case this repairs, read from source and not seen: a host cancels the
  sharing sheet after more than a second, which leaves SyFive's ids set (only the fast cancel at
  201-202 and 212-213 clears them); the next session to arrive, even one this device joins as a
  guest, takes the resume branch, resumes nothing and shows no seating sheet.
- **A smaller step.** Without adopting the rest, SyFive may read `resumeAsHost`'s answer at
  `ContentView.swift` 408 and show its seating sheet on false. Its own wrapper,
  `GameNightController.resumeAsHost(matchID:gameID:)` (`GameNightController.swift` 312), returns
  nothing today and would have to pass the answer on.
- **Still SyFive's.** Calling `beginHosting`; its own "Reconnect Game Night?" alert
  (`ContentView.swift` 208-224), which SyLib's alerts do not present; and the rule for when the
  seating sheet opens. SyLib's doc comment advises an empty `onReadyToSeat` on a reconnect, because
  a reconnect never seats and the guard that usually stops the callback is a race. SyFive passes
  `{ showsGameNight = true }` there (`ContentView.swift` 204 and 215).
- **Why a recording survives `detach()`.** SyFive detaches in its teardown hook
  (`GameNightController.swift` 298-303 and 536), and the session tears its old state down each time
  a new session arrives (`GameNightSession.swift` 362), before the resume can be consumed.
- **Doc.** `GAME_NIGHT_MATCH.md`, on resuming as host and on host reconnect;
  `GAME_NIGHT_ADOPTION.md` §5 and §7.

### 3.4 The history-sync store

- **The SyLib API.** `GNHistoryStore.manifestIDs(…)`, `matches(for:…)` and `storeReceived(…)`
  (`Sources/SyLibGameNightMatch/GNHistoryStore.swift` 43, 96 and 145) [L-18, L-40].
- **What it replaces.** The bodies of SyFive's three hooks (`Views/ContentView.swift` 352-369,
  370-376 and 377-402). Each becomes one call with the defaults, which are SyFive's own numbers.
- **What would differ, and nothing else.** A manifest never lists one id twice. Where several rows
  share an id, the row with the most participants stands for the match. A request is answered only
  with completed Game Night matches whose people are all seated now, each id once; today any row
  with the id is sent. A received match that is not completed, or has no completion time, is
  skipped; today it is inserted. The save happens only when something was stored, and a failure is
  thrown, where today it is swallowed (401). SyFive's two "skipped" log lines (387 and 393) go. The
  order by completion time, the scan of 40, the cap of 20, the roster test and the duplicate test
  are the same.
- **Still SyFive's.** Assigning the three hooks, supplying the seated ids (355), and catching what
  the calls throw.
- **Doc.** `GAME_NIGHT_MATCH.md`, on history sync; `GAME_NIGHT_ADOPTION.md` §6.

### 3.5 The roster upsert

- **The SyLib API.** `upsertGameNightRoster(_:remapOntoArchived:seatedPlayerIDs:in:)`
  (`Sources/SyLibScoringData/Operations/GameNightRoster.swift` 77-130) [L-17, L-39, L-43].
- **What it replaces.** SyFive's two copies: `upsertGameNightPlayerModels()`
  (`Views/ContentView+GameNight.swift` 187-224) and `ensurePlayerModels(for:)`
  (`Views/ContentView+Persistence.swift` 111-152).
- **What would differ.** With the default, an archived local player can still capture an incoming
  player of the same name and initials, as in SyFive today. When several local players match, an
  active one is chosen first and then the earliest created, where SyFive takes whichever the fetch
  returns. One local player captures at most one incoming player in a call. If SyFive also passes
  `seatedPlayerIDs`, a local player seated at this table never captures one. SyFive's copies have
  neither of those two protections (§4.2). A failure is thrown, where SyFive's copies swallow it
  (223 and 151).
- **Still SyFive's.** When to call it, building the incoming players from its seats or
  participants, and its orphan repair.
- **Doc.** `SCORING_DATA.md`; `GAME_NIGHT_ADOPTION.md` §4.

### 3.6 Match upsert, ranks and opponents

- **`upsertMatch(_:isGameNight:in:)`**
  (`Sources/SyLibScoringData/Operations/MatchModel+Operations.swift` 24) would replace the upsert
  in SyFive's `onMatchComplete` (`Views/ContentView.swift` 336-350).
  One difference: a fetch that fails throws and nothing is written, where SyFive's `try?` goes on
  to insert a second row. It does not save; SyFive still saves (350). `fetchCompletedMatches(in:)`
  (52) reads one row per id and deletes nothing. SyFive has no code it replaces: SyFive reads
  through queries and removes duplicate rows in `Persistence/Migration/LegacyRematchRepair.swift`,
  which stays SyFive's. Doc: `SCORING_DATA.md`.
- **`competitionRanks(_:direction:)`** (`Sources/SyLibScoring/Stats/CompetitionRanks.swift` 16) would
  replace `computeRank(for:)` (`Session/MatchController.swift` 607-611) with one call passing
  `.highest`. The rule is the same and no result changes [L-16]. Doc: `SCORING.md`.
- **`playerOpponents(playerID:matches:)`** (`Sources/SyLibScoring/Stats/PlayerOpponents.swift` 37)
  would replace the collection in `opponentRecords` (`Views/Stats/PlayerProfileView.swift` 49-69).
  One difference: an opponent is named from the last match the two shared, where SyFive names them
  from the opponent's last match with anyone (51-56). The result comes in first-met order and
  SyFive keeps its own sort by last meeting (68). Doc: `SCORING.md`; `SCORING_UI.md`.

### 3.7 The voice in use

- **The fault it cures.** By SyLib's own comment, `AVSpeechSynthesisVoice(identifier:)` returns a
  default voice, not nil, for an identifier that is no longer installed
  (`Sources/SyLibCommentary/Engine/CommentaryVoices.swift` 23-24). That is AVFoundation behaviour
  and was not checked here. If so, SyFive's fallback to the device's language
  (`Views/ContentView+Commentary.swift` 69-71) does not run when a saved voice has been deleted.
  SyLib's settings screen names its Voice row the same way (`CommentarySettingsView.swift` 46-50),
  so the row can name a voice that is not the one in use, and its voice preview resolves the saved
  identifier the same way (`PreviewSpeaker.swift` 30-32). Syderal's milestone left both, because
  curing either means wiring the inventory into SyFive.
- **The SyLib API.** `CommentaryVoices` (`CommentaryVoices.swift` 26-95): `init(answeringFor:)`,
  `refresh()`, `revision` and `voiceInUse(for:savedID:)` [L-10, L-32].
- **What it replaces.** The two lines at `ContentView+Commentary.swift` 69-71, and the getter of
  `voiceIDBinding` (`App/Commentary/CommentaryScreens.swift` 35-40), which would return the
  identifier of the voice in use so that the row and the preview follow it.
- **What would differ.** A player with no saved voice, or whose saved voice is gone, hears the best
  installed voice in the device's language: premium, then enhanced, then default, never a novelty
  voice or a Personal Voice. Today that player hears the system's voice for the language. The two
  also name the language differently: SyFive asks for the bare language code of the app's locale
  (`ContentView+Commentary.swift` 71), and SyLib matches voices against the speech system's
  current language code, which carries a region
  (`Sources/SyLibCommentary/Engine/AutomaticVoice.swift` 26-39 and 48-59). Which voice each gives a
  device set to a regional variety was not determined by reading. Until the first scan lands there
  is no answer, and the engine has no voice set.
- **Still SyFive's.** Creating the inventory, refreshing it at launch and when the system posts
  that the installed voices changed, and re-applying the engine's voice when `revision` moves.
  SyFive saves one voice for all four packs (`Extensions/UserDefaults+Extension.swift` 26-29),
  which fits.
- **Doc.** `COMMENTARY.md`, on voices and on building the settings screen.

### 3.8 The player edit sheet

- **The SyLib API.** `SyLibUI.PlayerEditSheet` (`Sources/SyLibUI/Roster/PlayerEditSheet.swift`
  28-164) [L-20]. It is a name and initials form that hands back the trimmed name and resolved
  initials; the caller writes.
- **What it replaces.** The form inside `Views/PlayerEditSheet.swift`, which becomes a wrapper
  that keeps `Mode`, `matchModel`, `onSave`, `onCreated` and its `themeType` state. The Color
  section and `themePicker` (98-103 and 119-152) go in the sheet's trailing slot. The body of
  `save()` (154-184) moves into the `onSave` closure. SyFive passes
  `deriveInitials: { deriveInitials(from: $0) }`, no limits, no background colour, and its theme's
  primary accent. Inside SyFive the type must be written `SyLibUI.PlayerEditSheet`, because
  SyFive's own type has the same name.
- **What would differ.** Names and initials are trimmed of newlines as well as spaces; SyFive trims
  spaces only (62, 155 and 157). And SyLib's sheet sets its own tint from the `accentColor` it is
  passed (`PlayerEditSheet.swift` 136), where SyFive's sheet sets none and takes whatever tint
  reaches it. So Cancel, Save and the field cursors can change colour wherever the theme's accent
  is not the tint the sheet has today. By reading, one such place is the sheet opened from the
  Players screen (`Views/PlayersView.swift` 88-91), which is presented outside the root tint
  (`Views/ContentView.swift` 242 and 487-491). Not seen. Nothing else, while no limit is passed.
- **Not settled.** SyFive's stacked layout for accessibility sizes (78-84) is the same in SyLib's
  sheet. Whether SyFive can reach it depends on whether its root limit reaches a sheet (§2.4).
- **Doc.** `UI_COMPONENTS.md`.

### 3.9 The table view from a session, and the help context

- **The SyLib API.** A second `GameNightTableView` initialiser that takes the session
  (`Sources/SyLibGameNight/Views/GameNightTableView.swift` 100-138), and
  `GameNightHelpSheet.Context(session:)` (`Sources/SyLibGameNight/Views/GameNightHelpSheet.swift`
  262) [L-21].
- **The help context is a safe swap.** `gameNightHelpContext`
  (`Views/ContentView+GameNight.swift` 163-171) is the same rule as SyLib's (271-279) and would
  become one call with no change in result. The literal `.joining` at
  `App/GameNight/Views/TableSettingView.swift` 72 is not derived by either and stays.
- **The table initialiser would change one behaviour.** It would replace the call at
  `App/GameNight/Views/GameNightScreens.swift` 81-111. A guest removing its own seat would then
  call `session.leaveSession()` directly and no longer SyFive's wrapper, which also clears
  `coordinator.localParticipantID` (`GameNightController.swift` 217-220). The clearing matters: a
  device with no seat claim that still holds a participant id from an earlier match is not made a
  spectator at the next match start (`GameNightMatchCoordinator.swift` 583-606). In the snapshot
  the routes to that are narrow, because every teardown detaches the coordinator
  (`GameNightController.swift` 536) and SyFive never calls `playAgain()`; one is a Rejoin tapped
  with a session already up at the table (249-254). The wrapper is still the only thing that clears
  the id there. Nothing in the finished SyLib gives the coordinator its own handling of a seat
  release.
- **Recommended: stay on the full initialiser.** It costs nothing but the eleven forwarded values,
  and its `onRemoveSeat` closure (`GameNightScreens.swift` 100-106) is where SyFive clears the id.
  The session initialiser takes no closure for a guest's leaving. Adopting it would mean clearing
  the id from somewhere else, for example by watching `session.localSeatClaimID`, which also goes
  nil when the host removes the seat (`GameNightSession.swift` 733-735), so that would clear the id
  in a case where SyFive keeps it today.
- **No hook is asked of SyLib.** Syderal's milestone left it to this document whether the session
  initialiser should gain a hook for what else a guest's leaving does. It should not for now.
  SyFive is the only app that would use one, and the full initialiser already gives it that hook.
  If SyFive later wants the session initialiser, the SyLib change is one optional closure on it,
  called after `session.leaveSession()` in the guest's branch (`GameNightTableView.swift`
  127-133), added and tested with SyFive open.
- **Doc.** `GAME_NIGHT.md`, on building the seating screen.

### 3.10 The Game Night menu section and toolbar control

- **The SyLib API.** `GameNightEntryState(session:)` with `leadingControl` and `showsLeadingHelp`
  (`Sources/SyLibGameNight/GameNightEntryState.swift` 9-55), `GameNightMenuSection` and
  `GameNightLeadingControlButton` (`Sources/SyLibGameNight/Views/GameNightEntryViews.swift` 18 and
  110) [L-22]. They were extracted from SyFive's own branching.
- **What they replace.** `gameNightMenuSection` (`Views/ContentView+GameNight.swift` 88-153), the
  Game Night branches of `leadingNavButton` (16-63), and `showsGameNightHelpButton` (157-161).
- **What would differ.** Every menu row and every help-button state is SyFive's, compared state by
  state against the snapshot for this document. "Play Again" goes in the section's slot for the
  app's own items when SyFive hosts a completed match. Four things change. The toolbar control is
  drawn with SyLibUI's `IconButton`, bold and larger, where SyFive draws a plain image in a button:
  a visible change. "Game Night Active" gains the accessibility label "Game Night active". The
  guest's green indicator gains the label "Game Night Active", where today it has none. And in one
  state that nothing reaches, a host at the `.abandoned` phase, SyLib shows no control where
  SyFive's chain falls through to the green indicator (48-52).
- **Still SyFive's.** Its rematch button and its two buttons outside Game Night (41-47 and 64-80),
  its help button (`Views/ContentView.swift` 73-78), and the closures behind each item.
- **Doc.** `GAME_NIGHT.md`; `GAME_NIGHT_ADOPTION.md` §7.

### 3.11 Smaller things, each optional

| SyLib API | What SyFive would do with it | What changes | Doc |
|---|---|---|---|
| `AppUpdateState` (`Sources/SyLibCore/AppStore/AppUpdateState.swift` 21-64) [L-3, SYD-514] | Replace its two state values and badge rule (`Views/ContentView.swift` 37-38, 248 and 542-549). Call `acknowledge()` from the Update Available item's action (92-96), not from a gesture on the menu | The acknowledgement is stored, so the badge does not return at every launch for a version already seen. SyFive's own rule does not have the fault Syderal's had at Milestone 12. **Where to acknowledge changed at Milestone 13** [SYD-514]: on the item, because SwiftUI's `Menu` gives no reliable "opened" signal (§4.5). `AppUpdateState`'s doc comment (8-9) and `APP_STORE.md` (19, 58, 69 and 87) still say to acknowledge when the menu opens, and the doc's example uses the tap gesture that does not fire; follow this row, not them, until Syderal's Task 13.14d brings SyLib's text into line (§5). Pairs with `MoreMenu`, below | `APP_STORE.md` |
| `GameNightSession.onTearDownWithReason` (`GameNightSession.swift` 107) [L-13] | Wire it beside or in place of `onTearDown` | Nothing by itself. It is how to tell an ending from a session arriving: SyFive's teardown hook also runs each time a new session arrives, the first of a launch included | `GAME_NIGHT.md` |
| `onGuestReconnectDeclined` on `gameNightAlerts(…)` (`GameNightAlertsModifier.swift` 119) [L-12] | Pass a closure | Nothing by itself. SyFive has no decline handling today; Play Locally only clears the pending id | `GAME_NIGHT.md` |
| `FeelCatalog.validate()` (`Sources/SyLibFeel/Recipes/FeelCatalog+Validation.swift` 42) [L-25] | One line in `FeelTests.swift` expecting an empty result for `FeelCatalog.syFive` | A test. All twenty of SyFive's recipes have a key equal to their id, checked by script for this document. The peak rule was not run | `FEEL.md` |
| `holdSpeechForTesting(speaking:queued:)`, `queuedTiers`, `queuedTexts` (`CommentaryEngine.swift` 340-368) [L-25] | Drive the engine's queue in SyFive's tests with no audio | Tests only. Never call it from app code: it cannot be switched off, and the engine would stay silent while its lines still went to guests | `COMMENTARY.md` |
| `CommentaryShuffleStore`, `shuffleState`, `restoreShuffle(_:)` [L-11] | Save each pack's shuffle when leaving the foreground and restore it after `update` | A pack plays through all its lines across launches before repeating | `COMMENTARY.md` |
| `waitUntilIdle(timeout:)` (`CommentaryEngine.swift` 312) [L-9] | Pace something automatic to the commentary | Nothing unless called | `COMMENTARY.md` |
| `leaveSessionOnThisDevice()` (`GameNightSession.swift` 478-483) [L-33] | Only if SyFive adds a way for a guest to leave during a match. Today its Leave button only closes the sheet once play has started (`TableSettingView.swift` 39-42) and its menu offers a guest nothing (`ContentView+GameNight.swift` 142-148) | The guest leaves the session on its own device and the others carry on. See §3.12 for where it must not be used | `GAME_NIGHT.md` |
| `DynamicTypeSize.tvViewing(forDisplayWidth:)`, `EdgeInsets.tvContentMargins(forDisplayHeight:)` [L-24] | Only if SyFive gains an external display | Nothing today: SyFive has no external display code | `EXTERNAL_DISPLAY.md` |
| `Toast` and `.toast(_:duration:bottomPadding:)` (`Sources/SyLibUI/Components/Toast.swift` 20-94) (*Milestone 13*) [SYD-507] | Replace the commentary button's "Commentary on/off" feedback: the `commentaryFeedback` and `commentaryFeedbackTask` state, `showCommentaryFeedback(suppressed:)` and the status-row branch that shows it (`Views/DiceAreaView.swift` 33-34, 295-303 and 210-212) become one `@State` `Toast?`, set on the tap and shown with `.toast(_:)` | The words leave the status row and rise from the bottom of the view the modifier is on, in a material capsule, for two seconds by default. The status row keeps its own line, so "Choose a category to score" no longer disappears for two seconds, and the stuck-dice message no longer hides the feedback. The toast takes no taps. Put the modifier on a view whose bottom edge sits above the roll controls if they should stay uncovered; Syderal anchors it just above its button row. Optional: SyFive's text fits where it is, which Syderal's did not | `UI_COMPONENTS.md`, Toast |
| `CapsuleButton.Countdown` (`Sources/SyLibUI/Components/CapsuleButton.swift`) (*Milestone 13*) [SYD-509] | Nothing proposed. SyFive does not use `CapsuleButton`, and it has no screen that should time out | A countdown, when set, fills the capsule with the tint and drains it toward the leading edge, then calls the action once, as a tap would. Nil, the default, draws the button as before | `UI_COMPONENTS.md`, CapsuleButton |
| `MoreMenu` (`Sources/SyLibUI/Components/MoreMenu.swift`) (*Milestone 13*) [SYD-510 to SYD-512, SYD-514, SYD-515] | Replace the toolbar menu's label and badge (`Views/ContentView.swift` 85-151): `Menu { … } label: { IconButton("ellipsis.circle", …, badge: …) }` with its `.simultaneousGesture` becomes `MoreMenu(showsBadge:badgeColor:badgedAccessibilityLabel:) { … }` with the same items. Acknowledge the badge from the Update Available item's action, beside `openAppStore()`, and drop the gesture | The badged label is the system's `ellipsis.circle.badge`, drawn as one glyph, so no separate dot sits over the toolbar button. Where the system lacks that symbol, `MoreMenu` falls back to `IconButton`'s drawn dot, at run time. On Syderal's device on 8 October it drew the system symbol, badge in the badge colour and circle in the tint. The badge clears when Update Available is tapped, not when the menu opens, which also cures the fault in §4.5. The accessibility labels are SyFive's own two strings, passed in. In the fallback the dot has no outline: `MoreMenu` passes none, where SyFive passes `badgeOutline` today. `MoreMenu` has no "opened" callback: an earlier `onOpen`, built on the same tap gesture, was removed before SyFive could copy it (Syderal Task 13.14c, SYD-515), and its example now acknowledges from the item | `UI_COMPONENTS.md`, MoreMenu |

### 3.12 What SyFive must not adopt

- **`makeScoringContainer(…)`, `makeInMemoryScoringContainer(…)` and `seedCatalogGame(_:in:)`**
  (`Sources/SyLibScoringData/Operations/ScoringContainer.swift` 16 and 34;
  `Sources/SyLibScoringData/Operations/GameModel+Operations.swift` 23) [L-17]. SyFive's production
  store must be built exactly as it is today (`SyFiveApp.swift` 21-34). SyLib's function builds its
  configuration with a different initialiser call from SyFive's, and it was matched argument for
  argument to Syderal's store, not SyFive's. SyFive's seed (`Views/ContentView+Persistence.swift`
  187-219) matches catalogue rows on `scoringSystemID` and removes extra rows under any id, which it
  needs for rows older builds wrote; SyLib's matches on the id alone and never touches a row under
  another id, and the rest of SyFive finds its game by `scoringSystemID`
  (`TableSettingView.swift` 147-153). Syderal's milestone ruled this out, not deferred it. The
  in-memory function is on the list with the other two. The reason given is about the production
  store, which a preview or a test never opens, and no ruling says whether SyFive's previews may
  use it; this document does not propose it.
- **`leaveSessionOnThisDevice()` at the table** [L-33]. SyFive's guest leaves only at the table
  (`TableSettingView.swift` 35-38; `GameNightScreens.swift` 100-106), where `leaveSession()` is
  right: the guest stays in the session and the host removes its seat. The new method leaves the
  session before its seat release is sent (`GameNightSession.swift` 463-483), so at the table the
  host would be left holding a seat for a device that has gone.
- **Syderal's host-broadcast guard, or any SyLib change that stops `onWillSpeak` while the engine
  is muted** (*Milestone 13*) [SYD-513]. The engine calls `onWillSpeak` before it checks `isMuted`
  (`Sources/SyLibCommentary/Engine/CommentaryEngine.swift` 117 and 433-435), so a muted host still
  hands every line to its broadcast. Syderal found that this let a host that could not hear
  commentary keep sending it to guests who had no way to stop it, and ruled that its host
  broadcasts only when it could hear commentary itself. It put that rule in its own app, at the
  broadcast closure, and left SyLib alone, because SyFive needs the opposite. SyFive moved the hook
  above the mute on purpose (`Docs/Requirements/16_GAME_NIGHT_PROXIMITY_MUTE.md` §2.2 and §4.1):
  proximity mutes one device of a pair in one room, and when the muted device is the host, its
  broadcast is how the guests hear anything; its commentary button is a per-device mute (D-GNP-008)
  that must not silence the table. So SyFive must not copy Syderal's guard, and nobody should
  "tidy" the engine so that a muted engine stops calling `onWillSpeak`. What keeps SyFive's guest
  from sending lines back is the guard in `broadcastCommentary` (§4.6), which stays.

---

## 4. Known gaps left as they are

None of these was introduced by rebuilding. Each was seen during Syderal's milestone, or by the
review that opened it, and left. Each entry says whether it applies to SyFive. §4.6 adds what was
found afterwards, in SyLib's source, while its docs were rewritten.

### 4.1 Game Night session and match

- **A guest that hears `matchAbandoned` ends the activity for every device** [F-13]. The guest's
  handler tears its session down with the call that ends the activity for the whole call
  (`GameNightMatchCoordinator.swift` 634-641; `GameNightSession.swift` 590). *SyFive:* the code is
  the same, and it is harmless as SyFive uses it, because SyFive's host sends that message only
  while ending Game Night itself. The rule for SyFive is never to send `matchAbandoned` and stay.
  Milestone 13 kept that rule rather than change SyLib: Syderal's host, discarding a match while
  the table stays, now sends a message of its own app's kind instead [SYD-498]. The handler in
  SyLib is unchanged.
- **Six behaviours that look like accidents and were deliberately not pinned by tests** [F-7].
  *All six are in code SyFive runs.* (1) A relayed celebration line stops whatever a guest is
  speaking, another celebration included (`CommentaryEngine.swift` 385-387). (2) `MatchHistoryRow`
  sorts a participant whose rank is 0 ahead of the winner; SyFive writes real ranks for a finished
  match, so its rows should not meet it. (3) Every `claimSeat` makes a new claim id and overwrites
  the device's own (`GameNightSession.swift` 854-877). (4) A rematch and a host's resume do not
  call `onMatchStarted` on the host, though a first match start does
  (`GameNightMatchCoordinator.swift` 229, against 232-256 and 266-309). SyFive wires that hook to
  lock the proximity seat map, open the resolution window and run its own hook, which clears the
  celebration cards and the winner announcement (`GameNightController.swift` 161-167;
  `Views/ContentView.swift` 330-333), so its host runs none of the three on a rematch or a resume.
  By SyLib's comment at the first match start (225-228), a host that never runs that path arms no
  arbitration deadline and broadcasts no proximity verdict. (5) A guest whose claim maps to no
  seat at a match start keeps a participant id from an earlier match and is not made a spectator
  (583-606);
  SyFive's leave wrapper clears the id on the one route it controls (§3.9). (6) The handler for
  `matchAbandoned` has no role check (634-641).
- **A device works out what history it is missing from its own manifest, not from its store**
  [F-9]. With a filtered manifest it asks for matches it already holds and drops them on receipt
  as duplicates (`GameNightMatchCoordinator.swift` 651-661). *SyFive:* applies; it costs a message.
- **A first-time guest must tap Open in FaceTime** [F-17]. On a fresh install the session reaches
  the app only after the guest goes back to FaceTime and taps Open. It is the ordinary first join,
  once per install, and no code can remove it. *SyFive:* true of SyFive too. Since Milestone 13 the
  Game Night Help says so, to the guest and to the host (§2.3) [SYD-502].
- **A rejoined guest's stored board keeps an earlier match's id** [F-34]. This is in Syderal's own
  guest code, not in SyLib. *SyFive:* the finding does not transfer as written. Whether SyFive's
  guest has a fault of the same shape was not traced: its match controller keeps a
  `persistedMatchID` it already holds when a snapshot of another match is loaded
  (`Session/MatchController.swift` 771-773).
- **A reconnect recording left by a cancelled share sheet** [F-35]. In Syderal it can hold a host
  on its waiting overlay. *SyFive:* has no such overlay; its form of the same leftover is the one
  described in §3.3, where the next session to arrive opens no seating sheet.

### 4.2 History sync, the roster and the log

- **History sync does nothing for a person two devices hold under different ids** [F-4]. Where the
  roster upsert took an incoming player to be a local player of the same name and initials, stored
  matches carry the local id and the seat carries the other device's id, so those matches are
  neither offered nor accepted. Nothing is over-shared. *SyFive:* behaves the same way.
- **A participant with no player id is not counted as a person by the history test** [F-27]. A
  match is judged only by its participants that have an id. *SyFive:* its own copy does the same
  (`Views/ContentView.swift` 366-367 and 384-386). Its seat claims always carry an id
  (`GameNightScreens.swift` 145-150).
- **The roster remap is worked out again, by name, at every match start** [F-25]. Nothing records
  that an incoming id was taken to be a local player. If the local player is renamed afterwards,
  the next call inserts a new player and that person's history is split across two ids.
  *SyFive:* its two copies work the same way, at each match start and at launch.
- **SyFive's own roster upsert can merge two different people who are at one table** [L-39, L-43].
  Both copies test each incoming player against every local player of that name and initials
  (`Views/ContentView+GameNight.swift` 197-212; `Views/ContentView+Persistence.swift` 124-140). So a
  local player who is seated at this very table can capture a different person of the same name,
  and two incoming players of one name can both be captured by one local player. A stored match
  then holds one player twice, and one person's result is lost from the statistics. SyLib's
  function closes both cases (§3.5); SyFive's copies are SyFive's to change.
- **Two devices on one iCloud account can each insert a player row under one id** [F-26]. A guest's
  player reaches both devices at a match start before either's new row has synced. Not seen in
  Syderal's check. *SyFive:* its copies insert in the same way. One thing in the snapshot would
  make it worse there: `healOrphanedParticipants()` builds a dictionary keyed by player id with an
  initialiser that traps on a repeated key (`Views/ContentView+Persistence.swift` 68), and it runs
  at launch (`Views/ContentView.swift` 259).
- **Extra history traffic for a match held as a full row and a short row** [F-37]. Since the
  history store judges a match by its fullest row, such a device no longer lists the match, so a
  peer that lists it sends its copy at each exchange and the copy is dropped as a duplicate.
  *SyFive:* only after adopting the history store (§3.4).
- **The Game Night log keeps only four logger categories.** The buffer's filter is fixed at
  "GameNightController", "ContentView", "GameNightActivity" and "SessionController"
  (`Sources/SyLibGameNight/Diagnostics/GameNightLogBuffer.swift` 31-34). None of SyLib's own
  loggers is among them, so the session's and the coordinator's lines are never written to the
  file. *SyFive:* its snapshot has loggers under two of the four names, "GameNightController" and
  "ContentView", so those are the lines its log holds. The fix is a categories parameter on the
  buffer. Syderal does not use the log, so nothing there would have called it; SyFive is the app
  that can add it and test it.

### 4.3 Sound, haptics and speech

- **No sound after a media-services reset** [F-14]. *Closed at Milestone 13* (§2.2). Listed here
  on 7 October as a gap; the audio engine now rebuilds itself, and Syderal's device heard sound
  effects and commentary after a reset with no relaunch. *SyFive:* re-test 10 confirms it.
- **The haptic players are never built if the haptic engine's first start fails** [F-22]. The
  recipes are stored, but nothing rebuilds from them unless a reset follows
  (`FeelHapticEngine.swift` 50-58). It was the same before the milestone. *SyFive:* applies.
- **The audio session's `setCategory` can fail during a call** [F-24]. Seen in Syderal, once the
  failure was logged, on each match start during a FaceTime call. In a later check on a call,
  sound effects and commentary were heard on both devices. *SyFive:* it sets the mode at launch
  and when the setting changes (`Views/ContentView.swift` 261;
  `Views/ContentView+Commentary.swift` 21), and the engine re-applies the category at each start.
  A failure would now show as a warning in the log. Not seen in SyFive.
- **The app was silent from launch, twice, unexplained** [F-16]. Seen in Syderal on two launches
  from Xcode, with sound restored by a trip to the background. It has not recurred, and nothing in
  the source explains it. Milestone 13 closed the finding with logging, not a fix [SYD-501]: with
  the lines of §2.2, a log shows whether the engine started, on what output, and whether an
  interruption or a reset came first. *SyFive:* same engine; not seen. If it is, the log is the
  first thing to read.
- **`ReverbPreset.largeMediumRoom` is AVFoundation's large room** [F-8]. The case's raw value is 2
  (`FeelRecipes.swift` 162). *SyFive:* does not apply while its reverb return is zero.
- **The voice scan still reads the speech system off the main actor** [F-19]. A race with a line
  being spoken was narrowed, not closed. *SyFive:* does not apply until it adopts the voice
  inventory (§3.7).

### 4.4 The edit sheet

- **Two edge cases in SyLib's edit sheet when a limit is passed** [F-32]. Initials that were
  following the name are derived again after a paste that goes over the name's limit, and a space
  typed in the initials field counts toward the initials limit. *SyFive:* would pass no limit, so
  neither applies.

### 4.5 Five findings in SyFive's own code that no SyLib change causes

The first three were found for this document on 7 October. The last two were added on 9 October,
by holding SyFive's code against what Syderal's Milestone 13 learned; each is read from source and
neither has been seen in SyFive.

- **An unfilled `{runnerUp}` in a solo game.** With one player there is no runner-up, so the two
  events that carry one are sent without that token (`Session/MatchController.swift` 658-661 and
  691-692; `App/Commentary/CommentaryEvent+SyFive.swift` 8 and 46). Each pack has lines for those
  events that use it: between 5 and 9 of 42 for the winner, and between 10 and 28 of 40 for a lead
  change. When one is chosen, a Release build hands the synthesizer text with the token still in
  it, and a Debug build stops on SyLib's assertion (`CommentaryEngine.swift` 427).
- **A voice fallback that trusts `AVSpeechSynthesisVoice(identifier:)`.** §3.7.
- **A progression chart that an unfinished game can never show.** `UnfinishedMatchDetailView` asks
  SyLibYatzy's `matchProgression(from:)` for the match it shows
  (`Views/Stats/UnfinishedMatchDetailView.swift` 60-62). That function returns nil unless the match
  is completed (`Sources/SyLibYatzy/Stats/MatchProgression.swift` 50), and this view is only given
  matches in progress (`Views/Stats/MatchHistoryView.swift` 27-29 and 95-97). So the call always
  gives nil and `progressionCard` (127) is never drawn. The guard is the same in the SyLib of
  2 October, and the function's doc comment does not mention it (43-48). This was found for this
  document, by reading, and is not in Syderal's records.
- **Turning commentary off lets the line already speaking, and the lines queued behind it, play
  out** (*9 October*). The commentary button (`Views/DiceAreaView.swift` 118-128) calls
  `gameNight.setCommentarySuppressed(_:)`, whose hook sets only `commentaryEngine?.isMuted`
  (`Views/ContentView+Commentary.swift` 32-34, with the rule at 13-15). The engine reads `isMuted`
  in one place, before it accepts a new line (`CommentaryEngine.swift` 435). A line already handed
  to the synthesizer finishes, and each line waiting in the queue is still submitted as the one
  before it completes (520-538), without a second look. Under SyFive's queue policy a burst holds
  up to four lines (§2.1), so a tap while a scoring action's lines are being spoken can be followed
  by several more seconds of commentary. The same is true of a proximity verdict that mutes this
  device mid-line, which takes the same hook, and of Sound set to Off while a line speaks
  (`handleSoundModeChanged()`, 19-28). Syderal found this in its own button [SYD-504] and cured it
  in its app, not in SyLib. *The cure for SyFive:* when the device goes from unmuted to muted, call
  `commentaryEngine?.stopSpeaking()` after setting `isMuted`, in
  `handleCommentarySuppressionChanged()` and in `handleSoundModeChanged()`. `stopSpeaking()`
  (`CommentaryEngine.swift` 292-297) cuts the line and drops the queue, and reports idle if it was
  busy. It does not touch the broadcast, so a muted host still feeds its guests (§3.12). Whether a
  proximity verdict should cut a line already speaking, or let it finish, is SyFive's call; cutting
  it is consistent with the button. *Check:* at Play-by-Play, score so that four lines are queued
  (re-test 1) and tap the commentary button during the first: speech stops at once.
- **The menu's update badge is acknowledged by a tap that recent iOS does not deliver**
  (*9 October*). SyFive clears the badge with `.simultaneousGesture(TapGesture().onEnded { … })` on
  the toolbar `Menu` (`Views/ContentView.swift` 148-150, calling `acknowledgeUpdateBadge()` at
  546-549). Syderal built exactly that at Milestone 13, and at its check F on Pops's device the
  gesture never fired and the badge stayed. Why the gesture is not delivered was not established;
  Syderal's ruling records only that it is not, on recent iOS. Its second attempt, the menu content's
  `onAppear`, fired at launch, because iOS builds a menu's content when its label is drawn
  [SYD-514]. So, by reading, a SyFive player with an update waiting sees the badge for the whole
  launch, however often the menu is opened. The acknowledgement is in memory only (37-38), so it
  would have returned at the next launch anyway. *The cure:* acknowledge from the Update Available
  item (92-96), in its action before `openAppStore()`, and remove the gesture. With `MoreMenu` and
  `AppUpdateState` (§3.11) the cure comes with a stored acknowledgement; without them it is a
  two-line change. *Check:* only with an update on the App Store newer than the build installed,
  or by setting `isUpdateAvailable` to true in a Debug build: the badge shows; open and close the
  menu, and the badge is still there; tap Update Available, and it is gone.

### 4.6 Found in SyLib's source while its docs were rewritten

These are not from Syderal's milestone. They were found by reading SyLib's source while its docs
were rewritten, and each was then confirmed at source by a second reader. None was seen on a
device, and none is fixed in SyLib. Almost all are older than Syderal's last milestone: the same
code is in the SyLib of 2 October. So SyFive may already ship with them. They are listed because
SyFive's developer has probably not seen them written down, not because the finished SyLib
introduces them. The one case that is new says so. Only what reaches SyFive is listed, and each
SyFive call site named was opened in the snapshot for this document. Where §4.1 to §4.3 already
carry an entry, this one points there and gives only what the reading added.

**What a player can meet.**

- **No settle haptic when Sound is off and Haptics are on.** `FeelDirector.dieSettled(index:)`
  returns at its first line when sound is off, before its `settle_die` haptic
  (`Sources/SyLibFeel/FeelDirector.swift` 103-109). Every other event there that has a haptic
  tests sound and haptics separately. *SyFive:* calls it for every die (`App/DiceFeelAdapter.swift` 15-17), so with
  Sound off the dice settle with no haptic, while a hold or a score still has its own.
- **A rattle started during the previous fade is cut off by it.** When all dice have settled the
  rattle is faded out over 80 milliseconds, in steps queued on the main queue with nothing kept to
  cancel them (`Sources/SyLibFeel/Playback/FeelAudioEngine.swift` 450-468; `FeelDirector.swift`
  111-113). A rattle started before the last step has its volume overwritten and is stopped by
  that step. *SyFive:* needs a Roll tap within 80 milliseconds of the last die settling
  (`Views/DiceAreaView.swift` 147). Narrow.
- **A reroll's rattle can come late.** `startBed(key:volume:)` schedules its buffer with no
  options, so a rattle started while one is playing waits behind it, and only the volume changes
  at once (`FeelAudioEngine.swift` 435-443). *SyFive:* a stuck die rerolled while the roll's rattle
  is still playing gets its own after the first has ended (`Views/DiceAreaView.swift` 61;
  `FeelDirector.swift` 136-140; the rattle lasts 1.8 seconds, `Feel/SyFiveCatalog.swift` 115).
- **No "Game Night ended" alert for a call that drops while an audio interruption is still going
  on.** The teardown clears the session's interruption flag
  (`Sources/SyLibGameNight/GameNightSession.swift` 612), and the handler for the interruption's end
  returns unless that flag is set (536-548). So a match that drops during an interruption, an
  answered phone call for example, defers its alert (644-656) and then never raises it. The alert
  comes only for a drop in the six seconds after the interruption ends. *SyFive:* that alert is
  its only notice of a dropped match, and it carries the host's Reconnect button
  (`Views/ContentView.swift` 188-207). Without it the host is next offered a reconnect at launch
  (`Views/ContentView+Persistence.swift` 21-31). Adopting §3.1 takes the host's own End out of
  this, because a guest that hears the ending raises the alert at once.
- **A rematch does not run the host's match-start hook.** §4.1, the fourth of the six.
- **The head-to-head screen shows initials worked out from the names.**
  `HeadToHeadDetailContent` takes no initials and passes `deriveInitials(from: name)` to its
  initials circles (`Sources/SyLibScoringUI/HeadToHead/HeadToHeadDetailContent.swift` 154), where
  the opponent row shows the stored initials (`OpponentSummaryRow.swift` 32). *SyFive:* shows both
  (`Views/Stats/PlayerProfileView.swift` 358; `Views/Stats/HeadToHeadDetailView.swift` 40-48) and
  lets a player set initials by hand, so such a player has one set of initials in the opponents
  list and another on the detail screen.
- **A head-to-head win is counted for a player who shared first place with a third.**
  `headToHead` gives A a win over B whenever A is at rank 1 and B is below
  (`Sources/SyLibScoring/Stats/HeadToHead.swift` 76). Its comments call these sole wins (12-13),
  and `playerSummary` leaves every shared first place out of its own win count
  (`PlayerSummary.swift` 49-51). *SyFive:* in a match of three or more where two tie for the top
  score, each of the two gains a head-to-head win over everyone below
  (`Views/Stats/PlayerProfileView.swift` 64; `Views/Stats/HeadToHeadCard.swift` 23) that the
  profile's Wins badge (221) does not count.
- **"Tap Invite Players again" names no control.** The invite instructions say it
  (`Sources/SyLibGameNight/Views/GameNightSharingViews.swift` 71), and "Invite Players" is only
  that sheet's own title (93). *SyFive:* presents the sheet (`Views/ContentView.swift` 520-522).
  Its controls that start Game Night are the menu's "Start Game Night" and the toolbar button
  (`Views/ContentView+GameNight.swift` 91-98 and 53-63).
- **The certification on the fairness screen was measured with the batch tuning.** Two comments
  say the built-in certification was measured with `DiceRoller.Config.certified`, which is the
  gameplay tuning (`Sources/SyLibDice/Analytics/FairnessCertification.swift` 71;
  `Sources/SyLibDice/Simulation/DiceRoller.swift` 1340). The run it carries was a batch, and a
  batch swaps in `Config.batch` (369-370). The report shipped beside it says so
  (`Sources/SyLibDice/Docs/DICE_FAIRNESS_REPORT.txt` 3 and 20). *SyFive:* shows this certification
  on its Dice Fairness screen (`Views/ContentView.swift` 496-498) for dice it rolls with the
  gameplay tuning (`Views/DiceAreaView.swift` 29).
- **The fairness screen's headline and bars.** `DiceFairnessView` shows "These dice are fair."
  whatever the certification says (`Sources/SyLibDice/Views/DiceFairnessView.swift` 39, against
  the icon at 34-36), draws faces 1 to 6 on a fixed scale (58 and 76), and colours its bars with
  `Color.accentColor`, not the `accentColor` it is passed (63, against 88). *SyFive:* passes the
  built-in certification, which passes and fits the chart, so only the colour applies. By reading,
  the bars take the app's accent and not the theme colour SyFive passes, because the sheet is
  presented outside the root tint (`Views/ContentView.swift` 242 and 496-498). Not run.
- **The haptic players are never built if the first start fails.** §4.3. The reading added that
  the start in question is the one at launch warm-up (`Views/ContentView.swift` 249), that a later
  return to the foreground can start the engine but still builds no player
  (`Sources/SyLibFeel/Playback/FeelHapticEngine.swift` 41-46 and 127-141), and that haptics then
  stay off until a relaunch.
- **History traffic from comparing manifests.** §4.1. The reading added when SyFive meets it: once
  a device holds a shared match that is not among its 40 newest completed matches of any kind, or
  holds more than 20 shared with the table (`Views/ContentView.swift` 352-368). The answer to a
  request goes to the whole session (`GameNightMatchCoordinator.swift` 669).
- **A relayed celebration cuts a guest's line.** §4.1, the first of the six. The reading added
  that the host and its guests then differ. Under the default queue policy a rebuilt host adds a
  celebration to a burst that is still open and speaks both lines (`CommentaryEngine.swift`
  263-265), where a guest speaks only the second (385-387). This is the one case here that comes
  with the finished SyLib, through the new default (§2.1).
- **A guest's End Game Night ends it for everyone.** §4.1, the first entry: every teardown but
  `leaveSessionOnThisDevice()` ends the activity for the whole call, a guest's `endSession()`
  included (`GameNightSession.swift` 449-452 and 590). *SyFive:* its guest reaches that from the
  menu's End Game Night at the table (`Views/ContentView+GameNight.swift` 134-141;
  `Sources/SyLibGameNight/Alerts/GameNightAlertsModifier.swift` 57-64), and the alert says that it
  ends the session for all players.
- **The log's four categories.** §4.2.

**What a developer would trip over.**

- **A guest on a different app protocol version is never told.** The host records the mismatch at
  `hello` and then silently declines that guest's seat claims (`GameNightSession.swift` 686-711
  and 752-757). The guest compares the transport version only, and the table state carries no app
  version, so on the host's table state it clears its failure, cancels its 15-second timer and
  goes on showing itself seated (713-750). Only the host is told. *SyFive:* its value is 1 and has
  never changed (`App/GameNight/Protocol/GameNightEnvelope.swift` 21), so no player meets this
  today. It is what a guest on the other build will see the first time that value is raised.
- **`GNMatchIdentity.duplicateExists` treats any row with the id as a duplicate.** Its comment says
  it finds a completed Game Night match. Its first check fetches by id alone, with no test of
  status (`Sources/SyLibGameNightMatch/GNMatchIdentity.swift` 37-49). *SyFive:* calls it on every
  match it receives (`Views/ContentView.swift` 392), so a completed match is skipped when the
  device holds any row with its id, an unfinished one included. The history store calls the same
  function (§3.4).
- **`onWillSpeak` fires for every line, not only a generated one.** Its comment says a generated
  line (`CommentaryEngine.swift` 120-123). Relayed lines and the preview go through the same call
  (434, from 391 and 289). *SyFive:* a guest's engine can keep the hook from an earlier session as
  host, because the guest's branch does not clear it (`Views/ContentView+Commentary.swift` 73-87,
  against 102-107). What stops a guest sending the host's lines back is the guard in
  `broadcastCommentary` (`GameNightController.swift` 485-488). Keep that guard.
- **Nothing in SyLib shows that the host has left the call.** The comment on
  `hostLostDuringPlay` points to the alerts modifier (`GameNightSession.swift` 149-152), which
  never reads it; under `Sources/` only the session touches it. *SyFive:* does not read it either,
  so `gameNightAlerts(…)` does not cover a host that drops out of the call while the session stays
  up. `GameNightAlertState.showsHostReconnect` is alike
  (`Sources/SyLibGameNight/Alerts/GameNightAlertState.swift` 10): SyLib stores it and presents
  nothing for it, and SyFive's own alert is what reads it (§3.3).
- **Two dice audio hooks are never called.** `onDieHitFloor(index:)` and `onDieHitWall(index:)`
  are declared (`Sources/SyLibDice/Audio/DiceAudioController.swift` 9-10), and nothing in SyLibDice
  calls them: the roller calls only the launch hook and the two settle hooks. *SyFive:* its adapter
  marks them reserved and implements neither (`App/DiceFeelAdapter.swift` 23). Implementing them
  would do nothing.
- **The debug fairness HUD.** Its live statistics count held dice as fresh samples on every roll
  (`Sources/SyLibDice/Analytics/DiceStatistics.swift` 184-193), and its hold mode runs two free
  rolls after four dice are held, where its text says one
  (`Sources/SyLibDice/Simulation/DiceRoller.swift` 885-894;
  `Sources/SyLibDice/Views/DiceDebugHUD.swift` 305). *SyFive:* no player sees the HUD. It is
  compiled in Debug builds only and switched off (`Views/DiceAreaView.swift` 66-73;
  `Utilities/AppConfig.swift` 17). It matters to whoever measures a new certification with dice
  held.

---

## 5. What was not read or could not be checked

- **Nothing was built or run.** §1.3 is a comparison by reading. It cannot show what the Xcode 27
  compiler newly reports in SyFive's own code, which builds in the Swift 5 language mode with
  main-actor default isolation. It cannot show a runtime fault.
- **The SyFive read is the snapshot of 2 October 2026.** The working tree may differ. The
  snapshot does not say which SyLib commit SyFive last built against.
- **Not checked: which build of SyFive is on the App Store.** §1.4 and re-test 16 hold for a build
  of the snapshot's source, which uses the proximity API that came with transport version 3 and
  is marked version 1.0.3 (`SyFive.xcodeproj/project.pbxproj` 408 and 460). Nothing read says
  whether a released build carries that proximity work.
- **The engine the shipped SyFive runs was not available.** Two of the three differences in §2.1
  are inferred from Syderal's records of it.
- **There is no SyLib tree older than 2 October 2026.** What changed in SyLib before Syderal's last
  milestone is known from Syderal's records and from the finished source. A change with no record
  could have been missed; Syderal's own review says the same.
- **Not read by Syderal's milestone, and still open:** whether SyFive's own Reconnect offer has the
  fault Syderal fixed in its own [L-28]. Syderal's fault was deciding who may reconnect from the
  session's role when there is no session. For this document one function was read,
  `fetchHostReconnectIDs()` (`Views/ContentView+GameNight.swift` 240-256). It decides from the
  stored match: the newest in-progress match must be a Game Night match that this device hosted. It
  does not read the session's role, so that fault is not in this function. The paths around it
  were not traced: what a Reconnect that finds no call leaves behind, and whether the offer can
  appear for a match that is not the one on screen.
- **Not traced in SyFive:** whether a sheet can open over one of its reconnect alerts. Syderal
  found that a sheet presented over a SwiftUI alert takes the alert down with neither button run.
  SyFive raises its alerts at launch (`Views/ContentView+Persistence.swift` 25 and 35) and presents
  its seating sheet half a second after a session arrives (`Views/ContentView.swift` 415-423).
- **Call sites checked by name only:** `SyLibScoring`, `SyLibScoringData`, `SyLibYatzy` and
  `SyLibDice` (§1.3).
- **Taken from records, not from source:** that the iOS 27 SDK means Xcode 27; the compiler's
  message in §1.1; the earlier wording of the seating footer; and every "seen on a device", all of
  which were Syderal's devices.
- **Taken from SyLib's comments, not tested:** that `AVSpeechSynthesisVoice(identifier:)` returns a
  default voice for an identifier that is not installed.
- **Not settled:** whether SyFive's root Dynamic Type limit reaches its sheets (§2.4, §3.8).
  Re-test 15 answers it.
- **SyLib's rewritten docs** are pointed to by file name and, in §3 and §4, by section. Each pointer
  was checked against the docs as they were delivered with this document.
- **The line numbers inside Appendix A's quoted sentences** are Syderal's, from the trees as they
  stood on 2 October 2026 or as built at a later review. They were not re-pointed. The body of
  this document gives the lines as they stand now.

**Added on 9 October 2026, for the revision.**

- **What the revision compared.** The SyLib of 9 October against the SyLib of 7 October, every
  file. Eleven differ or are new: `FeelAudioEngine.swift` and its tests, `GameNightHelpSheet.swift`,
  `CapsuleButton.swift`, `IconButton.swift`, the new `Toast.swift`, `MoreMenu.swift` and
  `ToastAndCountdownTests.swift`, and the docs `FEEL.md`, `GAME_NIGHT.md` and `UI_COMPONENTS.md`.
  `Package.swift` and every other source file are identical, so §1 and every entry not marked
  *Milestone 13* stand as written on 7 October. SyLib's suite was 1118 tests at the last report.
- **Syderal's Task 13.14c landed during the revision** and was read in the source it produced. It
  removed `MoreMenu`'s `onOpen` and rewrote its example and its section of `UI_COMPONENTS.md`
  [SYD-515], exactly as specified; SyLib's suite stayed at 1118 and Syderal's at 894. If a checkout
  still has `onOpen`, it predates the finished SyLib.
- **Stale text left in SyLib.** `AppUpdateState`'s doc comment
  (`Sources/SyLibCore/AppStore/AppUpdateState.swift` 8-9) and `APP_STORE.md` (19, 58, 69 and 87)
  still tell an app to acknowledge the badge when the menu opens, and the doc's example and its
  description of Syderal use the tap gesture that SYD-514 found does not fire. Task 13.14c does not
  touch them; Syderal's Task 13.14d, a docs fix-up, brings both into line and had not landed when
  this revision was written. Until it does, §3.11's `AppUpdateState` row is the guidance.
- **Seen only on Syderal's devices:** that sound effects and commentary return after a
  media-services reset; that FaceTime's Open matches the Help line's wording; that
  `ellipsis.circle.badge` draws as one glyph with its badge in the badge colour; and that a tap
  gesture on a `Menu` is not delivered. Which iOS release first ships `ellipsis.circle.badge` was not
  checked; `MoreMenu` asks at run time and falls back to the drawn dot.
- **The two findings added to §4.5 are read from SyFive's source of 2 October**, against
  Syderal's device results. Neither has been seen in SyFive.

---

## Appendix A. Every ruling's sentence for SyFive

Syderal's Milestone 12 made forty-four rulings, numbered L-1 to L-44. Each ruling ends with a
sentence that says what it means for SyFive. They are quoted here in full, unchanged, from the
ruling rows of the milestone's five documents. The ledger number of L-n is SYD-(438+n).

**Reading the quotations.** `SF/` is SyFive's app folder. `LIB/` is the SyLib package root.
`SYD/` is Syderal's app folder and `MVP/` its requirements folder. `Engine` is
`Sources/SyLibCommentary/Engine/CommentaryEngine.swift`. "1.0" is SyFive as shipped. "The handoff"
is this document.

**Which rulings do what.** Five change what a rebuilt SyFive does with no edit: L-7, L-12, L-15,
L-30 and L-34 (§2). L-25 changes three behaviours on paths SyFive does not reach. L-13 changes one
log line and L-44 one return type. L-26 is SyLib's docs
and this document. Twenty-one more only add API or fix code that SyFive does not call: L-3, L-8 to
L-11, L-14, L-16 to L-24, L-32, L-33, L-39 to L-41 and L-43 (§3 says which SyFive could adopt).
The remaining fourteen left SyLib's source alone: L-1, L-2, L-4 to L-6, L-27 to L-29, L-31, L-35
to L-38 and L-42.

| Ruling | Ledger | What the ruling is | For SyFive, as written |
|---|---|---|---|
| L-1 | SYD-439 | The terms on which code moved into SyLib. | **For SyFive:** nothing until it is rebuilt. SYD-357's suspension of "recompiles with zero source edits" stands; the handoff lists the edits. |
| L-2 | SYD-440 | Syderal's history sync shares a match only with a table that seats everyone in it. Syderal's app only. | **For SyFive:** nothing. No SyLib file changes, and SyFive already applies both tests (`SF/Views/ContentView.swift` 352–402). |
| L-3 | SYD-441 | The update badge shows only for an available update. `AppUpdateState` added to `SyLibCore`. | **For SyFive:** nothing. `AppUpdateState` is a new type SyFive does not reference, `AppUpdateChecker`'s behaviour is unchanged, and SyFive calls only `isUpdateAvailable()` (`SF/Views/ContentView.swift` 248) and keeps its in-memory acknowledgement (37–38, 542–549). The new type is `@MainActor` and constrains no app-supplied type, so a MainActor-default client can adopt it later. |
| L-4 | SYD-442 | Syderal tells Feel when the app leaves and returns to the foreground. Syderal's app only. | **For SyFive:** nothing. No SyLib file changes. |
| L-5 | SYD-443 | Syderal's match snapshot carries the match's own times. Syderal's app only. | **For SyFive:** nothing. No SyLib file changes. |
| L-6 | SYD-444 | Syderal relays spoken lines in SyLib's `CommentaryPayload`. Syderal's app only. | **For SyFive:** nothing. No SyLib file changes; SyFive's own app protocol version and payload are untouched. |
| L-7 | SYD-445 | The commentary engine has a queue policy. The default drops an event that arrives while a line is being heard. | **For SyFive:** a rebuilt SyFive, which sets nothing, gets the default and regains three things: (1) no backlog: an event that arrives while a line is being heard is dropped unless it is more important, so commentary never runs behind the dice (today: up to four lines behind); (2) the lines of one scoring action all speak, in order: a `leadChange` no longer cuts the `categoryScored` line from the same action before a word of it is heard; (3) at Game Night the host no longer broadcasts a line and then cuts it inside the burst, so guests speak the lines the host speaks. **Residual differences from 1.0, all narrow:** (a) after the burst's first line, an event is compared with the tier of the line **actually speaking**; 1.0 kept one `currentTier` (`MVP/13B_WIRING.md:628–629`), which after a burst is inferred to have held the tier of the last line handed to AVFoundation, so whether a mid-tier event interrupts during a burst's later lines can differ. The 1.0 source is not in this tree, so (a) is inferred, not verified. (b) A guest still holds at most four relayed lines and drops the newest beyond that (`Engine:274–275`, since 13B.9); 1.0 handed every relayed line to AVFoundation's unbounded queue (inferred). L-7 does not change (b). (c) A burst now stays open until its first line starts speaking; in 1.0 it stayed open only until `isSpeaking` turned true, "the next runloop pass" by Task 13B.9's note (`MVP/13B_WIRING.md:652–655`). The difference is a fraction of a second, in which SyFive cannot score a second time. **For the SyFive handoff (a device check, kept by decision):** at Play-by-Play, score so that an upper bonus and a lead change fall on one action: four lines are spoken, in order; score again while they speak: nothing is added unless it is more important than the line being heard. Whether `didStart` arrives before or after the pre-utterance delay (Zen: 0.35 s) only changes how long that window is; Task 12.5's Pops check reports it. |
| L-8 | SYD-446 | Pronunciation-table terms match whole words. | **For SyFive:** nothing. Its four packs pass no `ipaTable` (`SF/App/Commentary/Packs/Pack+*.swift:9`), and `makeUtterance` takes the plain-string path when the table is empty (`CommentaryProsody.swift:36–38`), so `attributed` never runs. |
| L-9 | SYD-447 | The engine can be waited on until idle, and reports every change to idle. | **For SyFive:** nothing. It sets no `onIdle` and waits for nothing; `enterIdle()` with no waiters and a nil `onIdle` does nothing. |
| L-10 | SYD-448 | The automatic voice and the voice inventory are in SyLib. | **For SyFive:** nothing. The types are new, and SyFive has no symbol of either name; it resolves its one voice itself (`SF/Views/ContentView+Commentary.swift:69–71`), and nothing it calls is touched. |
| L-11 | SYD-449 | The shuffle store is in SyLib. | **For SyFive:** nothing. It does not save a shuffle (no use of `shuffleState` or `restoreShuffle` in `SF/`), and the type is new. |
| L-12 | SYD-450 | A guest's version alert compares transport with transport. A declined rejoin is reported. | **For SyFive:** its call (`SF/Views/ContentView.swift` 188–207) passes every argument by label and compiles unchanged; Play Locally does what it did. A rebuilt SyFive guest stops being told that an older host is newer: with (a) it is offered Update only when the host's transport version is higher than its own. That is a visible bug fix. |
| L-13 | SYD-451 | A teardown reports its reason. | **For SyFive:** nothing. Its `onTearDown` (`SF/App/GameNight/GameNightController.swift` 175) fires at the same moment for the same teardowns; the new hook is nil; no public signature it uses changes. |
| L-14 | SYD-452 | Ending Game Night as host is one awaited call. | **For SyFive:** nothing until it adopts the method. `abandonSession()` is unchanged, and SyFive's own send-then-abandon keeps its lost-message race until the handoff. |
| L-15 | SYD-453 | The log sheet shares the file the log was written to. | **For SyFive:** the Share button in its match-log sheet (`SF/Views/Stats/MatchDetailView.swift` 82, `UnfinishedMatchDetailView.swift` 99) shares `gnlogs/syfive/<matchID>.log`, the file that exists. Nothing else changes; its four categories are still the ones kept. |
| L-16 | SYD-454 | Competition ranks and a player's opponents are in `SyLibScoring`. | **For SyFive:** nothing. Both functions are new declarations and SyFive calls neither; `computeRank` and `opponentRecords` are untouched. If SyFive adopts later, `computeRank` becomes one call with `.highest`, and `opponentRecords` would name an opponent from the last match the two shared, not from the opponent's last match with anyone. |
| L-17 | SYD-455 | Roster upsert, match upsert, completed-match fetch, catalogue seed and container functions are in `SyLibScoringData`. | **For SyFive:** nothing. All of it is new declarations; SyFive calls none and keeps its three roster copies, its upsert, its seed and its container. **SyFive is never moved onto the container or the seed function**: its production store must be built exactly as today, and its seed matches on `scoringSystemID`. If it later adopts the roster upsert with the default, the one difference is the fixed choice among several matching local players. |
| L-18 | SYD-456 | The history-sync store is in `SyLibGameNightMatch`. | **For SyFive:** nothing until it adopts. When it does, its three closures become three calls with the defaults, and it would differ from today in these ways and no others: a manifest never lists one id twice; a request is answered only with completed Game Night matches whose people are all seated now, each id once, where today any row with the id is sent; a received match that is not completed, or has no completion time, is skipped, where today it is inserted as a new row; the save happens only when something was stored, and a failure is thrown, not swallowed; its two "skipped" log lines go. The order key, the fetch of 40, the cap of 20, the roster skip and the duplicate skip are the same. |
| L-19 | SYD-457 | A guest's rejoin is three coordinator methods. | **For SyFive:** nothing. It calls none of the three, and `isGuestAwaitingReconnect` is cleared only inside the new method. |
| L-20 | SYD-458 | The player edit sheet is in `SyLibUI`. | **For SyFive:** nothing. The files are new, SyFive names none of the new symbols, and its own `PlayerEditSheet` shadows the package's inside its module, as Syderal's `AboutView` shadows `SyLibUI.AboutView`. |
| L-21 | SYD-459 | The table view can be built from a session, and the help context is derived. | **For SyFive:** nothing. Both additions are new initialisers; SyFive calls neither. |
| L-22 | SYD-460 | The Game Night menu section and toolbar control are in `SyLibGameNight`. | **For SyFive:** nothing. Three new files; `GameNightHelpSheet` is not edited. |
| L-23 | SYD-461 | A host's reconnect is recorded and consumed by the coordinator. The seating delay is a constant. | **For SyFive:** nothing. It calls none of this, and `beginHosting` waits the same 500 ms, now read from the constant. |
| L-24 | SYD-462 | The TV type size and margins are in `SyLibUI`. | **For SyFive:** nothing; it has no external display code. **For SydeTwo:** nothing; `scaled(for:)` and its tests are unchanged. |
| L-25 | SYD-463 | SyLib's tests cover SyLib. Two bug fixes and one removal came with them. | **For SyFive:** nothing from the tests, the seams or the access changes: every default is unchanged and SyFive calls none of the new symbols (`holdSpeechForTesting`, `queuedTiers`, `queuedTexts`, `FeelCatalog.validate()`). Three things change behaviour or surface: `absorbPlayer(p, into: p.id, …)` now leaves the player alone (it deleted it), which SyFive never asks for: its two callers are `SF/Views/PlayersView.swift:111` (the link sheet, whose candidates are local players while its subject is a Game Night player) and `:132` (the merge sheet, whose candidate list filters the retiring player out at `:126`), and Syderal does not call `absorbPlayer` at all; `resumeAsHost` no longer traps on a match host with short arrays, which a host whose arrays match its count (SyFive's, and Syderal's bridge, `SYD/Multiplayer/GameNightMatchBridge.swift:91–108`) never meets; and `sessionCheckpoint(_:)` is gone, which SyFive does not call (the only match for it in the three trees is the file that declares it). |
| L-26 | SYD-464 | SyLib's docs are rewritten and renamed, and this document is written. | **For SyFive:** the docs it is handed describe the SyLib it will build against. |
| L-27 | SYD-465 | A guest's rematch does not delete a match the device hosted earlier. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. |
| L-28 | SYD-466 | Syderal offers Reconnect by the match it holds, not by the session's role. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. Its own offer (`fetchHostReconnectIDs`, `SF/Views/ContentView.swift` 195) was not read for the same fault. |
| L-29 | SYD-467 | Syderal's host that ends Game Night is not then told that it ended. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. |
| L-30 | SYD-468 | Haptics come back after a haptic server reset. | **For SyFive:** after a haptic server reset its haptics come back without a relaunch. No source edit is needed. |
| L-31 | SYD-469 | Syderal's CloudKit schema is in Production. The schema helper stays in Syderal. | **For SyFive:** nothing now. A later addition to SyLib's shared models is a schema change in SyFive too, and no such helper was found in `SF/`; that goes in the handoff. |
| L-32 | SYD-470 | The automatic voice trusts the system voice only when the inventory lists it. | **For SyFive:** nothing. It does not use `CommentaryVoices`. |
| L-33 | SYD-471 | A guest can leave the session on its own device only. | **For SyFive:** nothing changes: `leaveSession()` and every existing teardown are as they were. SyFive calls `leaveSession()` only at the table (`SF/App/GameNight/Views/TableSettingView.swift` 35–38, `GameNightScreens.swift` 100–106), where it is right. It must not adopt `leaveSessionOnThisDevice()` there: the release would be lost and the host would keep the seat. |
| L-34 | SYD-472 | The audio session's errors are logged. | **For SyFive:** new lines in its log under the `FeelAudioEngine` category, and nothing else. |
| L-35 | SYD-473 | Syderal's Reconnect needs a saved match. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. |
| L-36 | SYD-474 | Syderal's Rejoin prompt comes before its table sheet. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. |
| L-37 | SYD-475 | Syderal's board is playable when built or handed over mid-turn. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. |
| L-38 | SYD-476 | Syderal's game view rewires its callbacks. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. |
| L-39 | SYD-477 | The roster upsert never merges an incoming player into a local player seated at the table. | **For SyFive:** nothing. The function is new in this milestone and SyFive does not call it; its own copy has the same gap, and is SyFive's to change. |
| L-40 | SYD-478 | The history store judges a match by its fullest row. | **For SyFive:** nothing. `GNHistoryStore` is new in this milestone and SyFive does not call it. |
| L-41 | SYD-479 | A rejoining guest takes the match id the host's state names. | **For SyFive:** nothing. The method is new in this milestone and SyFive does not call it. If SyFive adopts it, an id held from an earlier match is replaced where SyFive's own code keeps it. |
| L-42 | SYD-480 | Syderal's wordmark on an external display. Syderal's app only. | **For SyFive:** nothing. No SyLib source changes. |
| L-43 | SYD-481 | The roster upsert merges at most one incoming player into a local player per call. | **For SyFive:** nothing. SyFive does not call the function; its own copy has the same gap, and is SyFive's to change. |
| L-44 | SYD-482 | `resumeAsHost` returns whether it resumed. | **For SyFive:** nothing to do. Its one call, in `GameNightController.resumeAsHost`, compiles unchanged, because the result is discardable. It may read the answer where it skips its seating sheet (`SF/Views/ContentView.swift` 405–408). |

---

## Appendix B. Milestone 13's rulings that touched SyLib

Syderal's Milestone 13 ("Polish", 8 and 9 October 2026) made thirty-three rulings, Q-1 to Q-33.
The ledger number of Q-n is SYD-(482+n). Unlike Milestone 12's, these rulings did not each end with
a sentence for SyFive, because most of them are Syderal's alone. The table lists the ones that
changed SyLib, and three Syderal-only rulings whose lesson reaches SyFive. The "For SyFive" column
is this document's, written on 9 October; where SyLib's docs carry a *SyFive adoption* line for the
change, it is quoted after it.

**Which rulings do what.** One opened SyLib (Q-15). Three changed what a rebuilt SyFive does with no
edit: Q-17, Q-19 and Q-20 (§2.2, §2.3). One added a test (Q-23). Six added optional API or settled
its shape: Q-25, Q-27, Q-28, Q-29, Q-30 and Q-33 (§3.11). One changed where an app acknowledges the
update badge (Q-32). The rest changed Syderal's app alone. Of those, Q-16, Q-22 and Q-31 carry a
lesson for SyFive and are listed; the others (the five-space corridor, Syderal's commentary button
and its forfeit timeout, and its Game Night endings) are nothing for SyFive. SyLib's macOS build was
also fixed, at Pops's direction and without a ruling (Task 13.13a; §1.2).

| Ruling | Ledger | What the ruling is | For SyFive |
|---|---|---|---|
| Q-15 | SYD-497 | SyLib is opened for three of Milestone 12's findings: F-14, F-16's logging and F-17's help line. | Nothing to do. Every SyLib change of the milestone is additive and keeps SyFive's defaults; §1.3 lists what was checked. |
| Q-16 | SYD-498 | F-13: Syderal's host no longer sends `matchAbandoned` when it discards a match and keeps the table; it sends a message of its own kind. *Syderal's app only.* | Nothing; SyLib's handler is unchanged. It confirms the rule in §4.1: never send `matchAbandoned` and stay. |
| Q-17 | SYD-499 | F-14: `FeelAudioEngine` rebuilds itself after a media-services reset, keeping its sounds, mode and reverb. | Sound effects come back after a reset with no relaunch, and on Syderal's device commentary did too (§2.2; re-test 10). *SyLib's `FEEL.md`: "SyFive adoption: nothing to change. Sound now recovers from a media-services reset without a relaunch."* |
| Q-19 | SYD-501 | F-16 is closed with logging: a successful start, an interruption beginning or ending, and a media-services reset. | Four new info lines under `FeelAudioEngine` (§2.2). *SyLib's `FEEL.md`: "SyFive adoption: nothing to change. The log gains these lines under the `FeelAudioEngine` category; a failed `setCategory` or `setActive` left nothing in the log before, and the start, interruption and reset lines are new with Syderal's Milestone 13."* |
| Q-20 | SYD-502 | F-17: Game Night Help tells a first-time guest to tap Open in FaceTime, and tells the host the same about its guests. | Both lines appear in SyFive's help, with its name (§2.3; re-test 18). *SyLib's `GAME_NIGHT.md`: "SyFive adoption: nothing to change. `.preSession` and `.hosting` each gain the line about tapping Open in FaceTime."* |
| Q-22 | SYD-504 | Turning Syderal's commentary off stops it at once: the mute also calls `stopSpeaking()`. *Syderal's app only.* | SyFive's button has the same gap; §4.5 gives the cure, which is SyFive's to make. |
| Q-23 | SYD-505 | A test for a start in flight across a media-services reset. | Nothing. A SyLib test. |
| Q-25 | SYD-507 | Syderal's "Commentary on/off" feedback is a toast, and the toast is a SyLib component. | Optional (§3.11): it could replace SyFive's feedback text. *SyLib's `UI_COMPONENTS.md`: "SyFive adoption: nothing to change. The toast is opt-in."* |
| Q-27 | SYD-509 | The draining fill is an optional countdown on `CapsuleButton`. | Nothing; SyFive does not use `CapsuleButton` (§3.11). *SyLib's `UI_COMPONENTS.md`: "SyFive adoption: nothing to change. The countdown is opt-in."* |
| Q-28 | SYD-510 | SyLib gains `MoreMenu`, a menu wrapper whose label is the system's `ellipsis.circle`, or `ellipsis.circle.badge` when badged. Named so because SwiftUI already declares a `MenuButton`. | Optional (§3.11): it would replace the toolbar menu's label and badge. *SyLib's `UI_COMPONENTS.md`: "SyFive adoption: optional. It would replace any hand-badged "more" menu."* Its "tap that acknowledges the badge" is amended by Q-32 and Q-33. |
| Q-29 | SYD-511 | `IconButton`'s drawn badge stays, for counts and for icons with no badge symbol. | Nothing. SyFive's `IconButton` calls are unchanged. |
| Q-30 | SYD-512 | `MoreMenu` checks at run time that the system has `ellipsis.circle.badge`, and falls back to the drawn dot. | Nothing to do. On a release without the symbol, an adopted `MoreMenu` looks as SyFive's menu does today. |
| Q-31 | SYD-513 | Syderal's host broadcasts commentary only when it could hear commentary itself. Guarded in Syderal's app; SyLib's `onWillSpeak` still fires while muted. *Syderal's app only.* | SyFive must not copy the guard, and SyLib must keep the hook above the mute: SyFive's proximity design needs a muted host to keep broadcasting (§3.12). |
| Q-32 | SYD-514 | The update badge clears when Update Available is tapped, not when the menu opens: SwiftUI's `Menu` gives no reliable "opened" signal. Amends Milestone 12's L-3 (SYD-441). | SyFive acknowledges by such a gesture today; §4.5 gives the cure, and §3.11's `AppUpdateState` row the place to acknowledge. |
| Q-33 | SYD-515 | `MoreMenu` has no `onOpen`; acknowledge a badge from one of the menu's items (Task 13.14c). | Nothing to do: the finished SyLib has no `onOpen`. Acknowledge from the Update Available item (§3.11). Filed in Syderal's ledger v4.91. |
