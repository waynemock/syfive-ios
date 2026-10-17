# SyLib reintegration, Phase 2: three SyLib changes and five SyFive fixes

**Status:** Ready for the agent once `15` is complete. Written 10 October 2026.

**Phase 2 of 3** of SyFive 1.1.0 (`15` build, `16` fixes, `17` adoptions).

**Scope:** `sylib-swift` (three changes, §4.1 to §4.3) and `SyFive` (one line in §4.1, then §4.4
to §4.9).

**Ship with every prompt for this phase:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document, `15` with its §10
results filled in, and `14_SYLIB_SYDERAL_INTEGRATION.md` for reference.

**Before starting:** check the line numbers in this document against the working tree. They are
from the 10 October 2026 trees, which match `14`'s snapshot. Find each edit by the declaration
named; the line number only says where to look.

---

## Supersessions

| Overrides | With | Why |
|---|---|---|
| `14 §3.2` "Still SyFive's": clear `isGuestAwaitingReconnect` in SyFive's `onMatchStarted` hook, *or* SyLib's match-start handler gains the clear | SyLib's match-start handler clears it (§4.2). SyFive adds nothing | `14` named the SyLib edit as the cleaner fix and left it until SyFive was open. SyFive is now open. |
| `14 §4.2`: the log buffer's four categories are fixed | The buffer takes its categories at `configure` (§4.1) | `14` named this fix and left it to the app that can test it. |
| `14 §4.5`: the solo `{runnerUp}` finding, which proposed no cure | A solo game ends on a new `soloFinished` event (§4.6, D-133) | Decided with Pops, 10 October 2026. |
| `14 §4.5`: the cure for "turning commentary off lets the line play out", which leaves proximity's choice open | Every change from unmuted to muted cuts the line, proximity included (§4.5, D-132) | Decided with Pops, 10 October 2026. |
| `14 §4.5`: the progression-chart finding, which proposed no cure | SyLibYatzy gains an opt-in for unfinished matches (§4.3) | Decided with Pops, 10 October 2026. |
| GAME_NIGHT_ADOPTION.md line 527 and the doc comment on `restoreRejoiningGuest(from:)`: "a `matchStart` does not [clear it]" | A `matchStart` does clear it | Changed by §4.2. Both texts are corrected in the same task. |

---

## 1. What this phase does

The order follows house practice. Logging comes first, so that every later failure leaves
readable evidence. The SyLib changes come before the SyFive fixes that rely on them. Within
SyFive, the hook-wiring fix (§4.4) comes before the stop-on-mute fix (§4.5), which cannot work
without it.

| § | Change | Where | Re-test that should now pass |
|---|---|---|---|
| 4.1 | The log buffer takes its categories at `configure` | SyLib + SyFive | F1 |
| 4.2 | A guest's `matchStart` clears `isGuestAwaitingReconnect` | SyLib | F2 |
| 4.3 | `matchProgression(from:includeInProgress:)` | SyLib | F3, with §4.7 |
| 4.4 | The suppression hook survives a teardown | SyFive | R19 |
| 4.5 | Muting cuts the line in flight and the queue | SyFive | R20, F4 |
| 4.6 | Solo games end on `soloFinished`; no lead change in solo | SyFive | R21, F5 |
| 4.7 | The unfinished-match screen shows its progression chart | SyFive | F3 |
| 4.8 | The orphan scan cannot trap on a repeated player id | SyFive | F6 |
| 4.9 | Docs and ledger | Both | — |

Two `14 §4.5` findings are not here, because adoptions in `17` fix them: the update badge
(`17` §4.7) and the roster merge of two same-named people (`17` §4.5).

---

## 2. Locked decisions

**2.1 SyLib changes are additive, keep every default, and keep Syderal building.** After each of
§4.1 to §4.3: SyLib's suite passes (count recorded, `00B` §5.3), Syderal builds against the changed
SyLib with no source edit, and Syderal's own suite still passes (894 at its last report; `00B` §5.4). Syderal is in App
Store review; it is rebuilt here only to prove compatibility, never archived. *Rationale:*
the SyLib is shared, and Syderal's next build will pick up whatever lands here.

**2.2 Every unmuted-to-muted change cuts speech at once** (D-132). Whenever the engine goes from
unmuted to muted, it calls `stopSpeaking()`. In SyFive that happens three ways: the commentary
button, Sound set to Off, and proximity muting a guest when its ranging begins (`GameNightProximity`
line 170). Proximity's verdicts and its timeout only ever unmute (D-GNP-005; lines 232, 258 and 437),
and it never mutes the host (D-GNP-004). The broadcast to guests is untouched (D-130). *Rationale:* a
mute that waits out a burst of four lines does not feel like a mute. Decided with Pops; the wording
was corrected on 10 October 2026 after the agent read `GameNightProximity`.

**2.3 A solo game has no winner and no lead** (D-133). With one player, game over emits
`soloFinished(player:score:)` in place of `winnerDeclared`, and `leadChange` is never emitted.
*Rationale:* the winner lines name a runner-up and a margin; in solo the runner-up is missing and
the margin is the whole score. Decided with Pops.

**2.4 Copy for `soloFinished` is in §5 (twenty lines per pack, per `09 §13`), drafted for Pops's approval.** The agent pastes it exactly as
given. If Pops rewrites a line, the rewrite replaces it in §5 before the task runs. Snarky's lines
target the dice and the decisions, never the player (D-082).

**2.5 The Game Night log keeps SyLib's lines.** SyFive configures the buffer with its own
categories (`GameNightController`, `ContentView`, `MatchController`), SyLib's Game Night categories,
and `FeelAudioEngine`. *Rationale:* until now the log never held the session's or the
coordinator's own lines (`14 §4.2`), and `FeelAudioEngine` is what explains a silent launch or an
audio fault during a call (`14 §4.3`). *(rec.)*

**2.6 The progression opt-in reports no winner for an unfinished match.** With
`includeInProgress: true` and a match that is not completed, `comebackFrom` is nil whatever the
ranks say. *Rationale:* a comeback needs a winner, and an unfinished match has none. *(rec.)*

---

## 3. Before starting

- `15` is complete and its §10 is filled in.
- SyLib changes in this phase go on `sylib-swift`'s branch `syfive-reintegration`, which already
  exists (from `1e2729fd`, the commit Syderal was submitted on). Agents never run `git` (`00A` §9).

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 SyLib: the log buffer takes its categories at `configure`

**File:** `Sources/SyLibGameNight/Diagnostics/GameNightLogBuffer.swift`

1. Rename the private `gnCategories` (line 31) to a public constant with the same four names:

   ```swift
   /// The categories kept when `configure(keyPrefix:categories:)` is given none.
   public static let defaultCategories: Set<String> = [
       "GameNightController", "ContentView",
       "GameNightActivity", "SessionController",
   ]

   /// The categories of SyLib's own Game Night loggers. Add them to an app's set to keep the
   /// session's and the coordinator's lines.
   public static let packageCategories: Set<String> = [
       "GameNightSession", "GameNightSharing",
       "GameNightProximity", "GameNightMatchCoordinator",
   ]
   ```

2. Give `configure` a defaulted parameter and store it beside `logSubdirectory`:

   ```swift
   public static func configure(keyPrefix: String,
                                categories: Set<String> = GameNightLogBuffer.defaultCategories) {
       logSubdirectory = "gnlogs/\(keyPrefix)"
       keptCategories = categories
   }
   nonisolated(unsafe) private static var keptCategories = GameNightLogBuffer.defaultCategories
   ```

3. In `startSession()` (declared at line 40), read `Self.keptCategories` where it reads
   `Self.gnCategories` (line 56).
4. Update the type's doc comment to name the parameter.

**Tests:** in `Tests/SyLibTests/SyLibGameNight/GameNightLogSheetTests.swift`, or a new
`GameNightLogBufferTests.swift` beside it:
- With no `categories`, a line under `"GameNightController"` is written and a line under
  `"GameNightSession"` is not. This is the old behaviour.
- With `defaultCategories.union(packageCategories)`, both are written.
- With a set that leaves out `"ContentView"`, a `"ContentView"` line is not written.

Restore the default at the end of each test, because the buffer is a shared singleton.

**Docs:** `Docs/GAME_NIGHT.md` line 519 ("Only four logger categories are kept…") is rewritten to
describe the parameter and the two constants. That line cites `LOGGING.md`; the file on disk is
`Logging.md`, so the rewrite uses the on-disk name. Line 544 (the *SyFive adoption* line) becomes:
"SyFive configures the buffer with its own categories, `packageCategories` and `FeelAudioEngine`
(`16` §4.1)."

**SyFive:** in `App/GameNight/GameNightController.swift`, `listenForSessions()`, line 173 becomes:

```swift
GameNightLogBuffer.configure(
    keyPrefix: session.keyPrefix,
    categories: GameNightLogBuffer.packageCategories.union(
        ["GameNightController", "ContentView", "MatchController", "FeelAudioEngine"])
)
```

**Check:** F1.

### 4.2 SyLib: a guest's `matchStart` clears `isGuestAwaitingReconnect`

**File:** `Sources/SyLibGameNightMatch/GameNightMatchCoordinator.swift`, `handleMatchStart(_:)`
(line 574).

After `sess.phase = .inProgress` (line 578), add:

```swift
// A match start is live state arriving, as a matchState is: whatever wait
// prepareForGuestReconnect(matchID:) began is over (SyFive 16 §4.2).
if sess.isGuestAwaitingReconnect { sess.isGuestAwaitingReconnect = false }
```

Fold whether it cleared into the existing `handleMatchStart:` info line at the end of the
function, as `waitCleared=<true|false>`.

**Doc comments to correct in the same file:**
- `restoreRejoiningGuest(from:)` (around line 504): replace "This is the only place the match
  layer clears `isGuestAwaitingReconnect`: a `matchStart` does not." with "The match layer also
  clears it when a `matchStart` arrives."
- `prepareForGuestReconnect(matchID:)` (around line 466): its first bullet lists who clears the
  flag. Add the match start.

**Also correct** the doc comment on `isGuestAwaitingReconnect` in
`Sources/SyLibGameNight/GameNightSession.swift` (lines 55-57). It names only
`restoreRejoiningGuest(from:)` as the match layer's clear; add the match start.

**Tests:** in `Tests/SyLibTests/SyLibGameNightMatch/GameNightGuestRejoinTests.swift`:
- **This task re-pins one test, as `00A` §7 allows when the spec moves first.** Lines 158-171,
  `@Test("a match start does not end the wait")` (`aMatchStartDoesNotEndTheWait`), and the comment
  above it ("The promise made to SyFive: only restoreRejoiningGuest clears the wait in the match
  layer.") encode the old rule. Replace them with `@Test("a match start ends the wait")`
  (`aMatchStartEndsTheWait`), with the same setup and `#expect(session.isGuestAwaitingReconnect ==
  false)`, and the comment "A match start is live state arriving: it ends the wait, as a
  matchState does (SyFive `16` §4.2)." This is the only existing test this task may change.
- A guest with `isGuestAwaitingReconnect` set receives a `matchStart` that maps its claim: the
  flag is false afterwards.
- The same for a `matchStart` that maps no claim (the spectator path): the flag is false.
- On a host, nothing changes (`handleMatchStart` returns early for a host).

**Docs:** `Docs/GAME_NIGHT_ADOPTION.md` lines 518-527, and `Docs/GAME_NIGHT_MATCH.md` lines 116 and
372 (guest rejoin), say a match start clears the flag. `Docs/GAME_NIGHT.md` line 309 gains "and
when a `matchStart` arrives" in its list.

**Syderal:** no source change. Its `noteLiveStateArrived` (`Multiplayer/GameNightAdapter.swift`
138-152) clears the same flag when a match start lands; after this change it finds the flag
already clear and returns false, so its log line `isGuestAwaitingReconnect cleared` no longer
appears on that path. It still withdraws the Rejoin prompt. Two of its comments go stale
(`GameNightAdapter.swift` 124-128 and `GameNightMatchBridge.swift` 282-287, "still covers a match
start"). They are left for Syderal's next milestone and not edited here. Record them in §10.

**SyFive:** nothing to change. Its roll gate (`Views/DiceAreaView.swift` 318, 351, 368) now opens
for a guest that tapped Rejoin with a session already up, at the next match start.

**Check:** F2.

### 4.3 SyLib: `matchProgression` can replay an unfinished match

**File:** `Sources/SyLibYatzy/Stats/MatchProgression.swift`, `matchProgression(from:)` (line 49).

1. Change the signature, with a default that keeps every caller as it is:

   ```swift
   public func matchProgression(from match: Match,
                                includeInProgress: Bool = false) -> MatchProgression?
   ```

2. The first guard becomes:

   ```swift
   guard match.status == .completed || (includeInProgress && match.status == .inProgress),
         !match.participants.isEmpty else { return nil }
   ```

   An abandoned match still returns nil.
3. Where `soleWinnerParticipantID` is worked out (line 112), it is nil unless
   `match.status == .completed` (§2.6).
4. Rewrite the doc comment: "Replays a match's scorecard entries…"; name the parameter; keep
   the `recordedAt` rule.

**Tests:** in `Tests/SyLibTests/SyLibYatzy/StatsTests.swift`, beside
`matchProgression_nilTimestampEntryReturnsNil`:
- An in-progress match with timestamped entries returns nil by default.
- The same match with `includeInProgress: true` returns a progression whose steps match its
  entries, with `comebackFrom == nil`.
- An abandoned match returns nil with `includeInProgress: true`.
- An in-progress match with one entry missing `recordedAt` returns nil with
  `includeInProgress: true`.

**Docs:** `Docs/Yatzy.md`, the `MatchProgression` section (lines 400-412) and the table row at 257.

**Syderal:** does not import SyLibYatzy. Building it proves the package still compiles.

**Check:** none on its own; F3 with §4.7.

### 4.4 SyFive: the suppression hook survives a teardown

**File:** `App/GameNight/GameNightController.swift`, `performControllerTearDown()` (line 512).

Remove `onCommentarySuppressedChanged = nil` (line 530). In its place, extend the comment above the
block (lines 514-519) so that it names this hook too:

```swift
// onCommentarySuppressedChanged is NOT cleared either. ContentView wires it once, in onAppear,
// for the app's lifetime, and the session tears down at every session arrival
// (.adoptingNewSession). Clearing it here cut the commentary button and proximity off from
// the engine from the first Game Night of a launch until relaunch (16 §4.4, 15 R19).
```

No other hook in that list changes in this task. They are re-wired in three places: ContentView's
`sessionActivationCount` handler wires the match-layer hooks (`Views/ContentView.swift` 317-402);
`syncCommentaryEngine()` wires `onCommentaryReceived` (`ContentView+Commentary.swift` 84 and 100);
and `DiceAreaView.wireGameNightHooks()` wires the four roll-theatre hooks (`DiceAreaView.swift`
89-91 and 251-291). The last of these is keyed on `isSessionActive`, which has a gap of its own: see
§11.

**Check:** R19 passes. The commentary button, during a Game Night match and in a solo game played
after one, stops the next line from being spoken.

### 4.5 SyFive: muting cuts the line in flight and the queue

**File:** `Views/ContentView+Commentary.swift`.

1. Add one helper, and use it everywhere the extension assigns `isMuted`:

   ```swift
   /// Applies shouldMuteCommentary to the engine. On a change from unmuted to muted it also
   /// stops the line being spoken and drops the lines queued behind it (D-132). It does not
   /// touch onWillSpeak, so a muted host still feeds its guests (D-130).
   func applyCommentaryMute() {
       guard let engine = commentaryEngine else { return }
       let wasMuted = engine.isMuted
       engine.isMuted = shouldMuteCommentary
       if !wasMuted && engine.isMuted { engine.stopSpeaking() }
   }
   ```

2. Replace each `commentaryEngine?.isMuted = shouldMuteCommentary` with `applyCommentaryMute()`:
   in `handleSoundModeChanged()` (line 27), `handleCommentarySuppressionChanged()` (33), and the
   guest and host branches of `syncCommentaryEngine()` (85 and 108).
3. Update the doc comment on `handleCommentarySuppressionChanged()`. It still must not re-run
   `syncCommentaryEngine()` (§5.3 of the proximity design).

`stopSpeaking()` cuts the line and empties the queue, and reports idle if the engine was busy
(`CommentaryEngine.swift` 292-297). An engine created muted has nothing to stop.

**Check:** R20 passes. F4 passes.

### 4.6 SyFive: solo games end on `soloFinished`; no lead change in solo

**Files:** `App/Commentary/CommentaryEvent.swift`, `App/Commentary/CommentaryEvent+SyFive.swift`,
`Session/MatchController.swift`, and the four `App/Commentary/Packs/Pack+*.swift`.

1. **The kind.** In `CommentaryEventKind`, add `case soloFinished` after `winnerTie`, in the
   `.celebration` tier. Make the enum `CaseIterable`, for the test in step 5.
2. **The factory.** In `CommentaryEvent+SyFive.swift`:

   ```swift
   static func soloFinished(player: String, score: Int) -> Self {
       .init(kind: .soloFinished, tokens: ["player": player, "score": "\(score)"])
   }
   ```

3. **The emission.** In `MatchController`, in the function that emits a scoring action's events
   (its `gameJustEnded` branch is at line 650):
   - At the top of `if gameJustEnded {`: when `playerCount == 1`, emit
     `.soloFinished(player: playerDisplayNames[0], score: totalScore(for: 0))` and `return`.
   - In the lead-change block, add `playerCount > 1` to the condition on line 688 (the line after
     `let newLeaders = leaderIndices`).
4. **The lines.** Add a `"soloFinished"` key to each pack's `lines` dictionary, after
   `"winnerTie"`, with the twenty lines §5 gives for that pack, verbatim. **Run this step only
   once §10 records Pops's approval of §5.**
5. **The test.** Add `SyFiveTests/Commentary/CommentaryPackTests.swift`, marked `@MainActor`.
   **This task authorises creating the folder `SyFiveTests/Commentary/`** (`00A` §10), beside the
   existing `SyFiveTests/Feel/`. No other new folder is authorised.
   the packs and `allCases` are main-actor isolated under the app target's default isolation.
   - Every pack in `CommentaryPersonality.all` has at least one line for every
     `CommentaryEventKind.allCases`, and at least 20 for `soloFinished` (`09 §13`).
   - Every `{token}` in every line is one that its kind's factory supplies:

     | Kind | Tokens supplied |
     |---|---|
     | `winnerDeclared` | `winner`, `score`, `margin`, `runnerUp` |
     | `winnerTie` | `winner`, `score` |
     | `soloFinished` | `player`, `score` |
     | `leadChange` | `leader`, `runnerUp` |
     | `bigTurn`, `categoryScored` | `player`, `category`, `value` |
     | `categoryScratched` | `player`, `category` |
     | every other kind | `player` |

   `runnerUp` is supplied for the two kinds that carry it because, after step 3, neither is
   emitted with fewer than two players. Write that reason in a comment in the test.

**Check:** R21 passes. F5 passes. The new test passes.

### 4.7 SyFive: the unfinished-match screen shows its progression chart

**File:** `Views/Stats/UnfinishedMatchDetailView.swift`, line 60.

```swift
if let prog = matchProgression(from: match, includeInProgress: true) {
```

`MatchDetailView.swift` line 60 is unchanged: it shows completed matches only.

**Check:** F3.

### 4.8 SyFive: the orphan scan cannot trap on a repeated player id

**File:** `Views/ContentView+Persistence.swift`, `healOrphanedParticipants()`, line 68.

```swift
let playersByID = Dictionary(allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
if playersByID.count < allPlayers.count {
    logger.warning(self, "heal scan: \(allPlayers.count - playersByID.count) PlayerModel row(s) share an id with another row — kept the first of each")
}
```

This stops the trap and nothing else. Resolving rows that share an id is out of scope (`14 §4.2`,
F-26).

**Check:** F6.

### 4.9 Docs and ledger

- Confirm §9's rows are in `00_DECISION_LEDGER.md`; `00B` Task A-1 pasted them.
- In SyLib, check that `Docs/GAME_NIGHT.md`, `GAME_NIGHT_ADOPTION.md`, `GAME_NIGHT_MATCH.md` and
  `Yatzy.md` say what §4.1 to §4.3 now do. Search them for "four logger categories", "`matchStart`
  does not", "matchStart` does not clear" and "not `.completed`".
- Record in §10: SyLib's suite count, Syderal's build result and suite count, and SyFive's tests.

---

## 5. Copy: `soloFinished` lines (for Pops's approval)

Tokens: `{player}` and `{score}` only. **Twenty lines per pack**, so `09 §13`'s "20+ variants per
event kind per pack" holds with no exception. Each pack's lines follow the voice of its
`winnerDeclared` lines. Snarky's lines target the dice and the decisions (D-082). No line uses an
exclamation point outside Sports, whose existing lines already use them throughout.

**Sports**
```
"That's the final! {player} posts {score}!",
"Full card, folks! {player} finishes with {score}!",
"And that's time! {score} on the board for {player}!",
"{player} closes out the card! {score} points!",
"Final whistle! {player} wraps it up at {score}!",
"What a solo run! {player} signs off with {score}!",
"Thirteen boxes, all filled! {player} finishes at {score}!",
"That's the card, and {player} posts {score}!",
"Final tally for {player}, {score}!",
"{player} brings it home with {score}!",
"The card is complete! {score} for {player}!",
"Put it in the books! {player}, {score}!",
"{player} finishes the solo round at {score}!",
"And there it is! {score} to close it out!",
"That's a wrap on the card! {player} with {score}!",
"Last box filled! {player} ends at {score}!",
"{score} on the scoreboard! Nice work, {player}!",
"Game over, and {player} posts {score}!",
"The solo card is in! {player}, {score} points!",
"Final number, {score}! {player} takes a bow!",
```

**Zen**
```
"The card is full. {player} rests at {score}.",
"Every box filled. {score}, and nothing left to chase.",
"{player} completes the journey. {score} points.",
"The dice are still. {player} arrives at {score}.",
"One player, one path. It ends at {score}.",
"The game exhales. {player} finishes with {score}.",
"Thirteen boxes, thirteen moments. {score}.",
"Nothing left to roll. {player} settles at {score}.",
"The card closes softly. {score} for {player}.",
"{player} reaches the end of the path. {score}.",
"All turns complete. {score}, held lightly.",
"The final box is filled. {player}, {score}.",
"A quiet finish. {player} arrives at {score}.",
"{score}. A number, and a game well walked.",
"The dice rest. So does {player}. {score}.",
"Completion. {player} finishes at {score}.",
"The circle closes at {score}.",
"{player} lets the last roll go. {score}.",
"Every choice made, every box filled. {score}.",
"The game is whole. {player}, {score}.",
```

**Steady**
```
"Card complete. {player} finishes with {score}.",
"That's the game. {score} for {player}.",
"Final score, {score}.",
"{player} wraps it up at {score}.",
"Game over. {score} points.",
"All boxes filled. {player}, {score}.",
"{player} finishes at {score}.",
"That's the card. {score}.",
"Final tally, {score} for {player}.",
"Done. {player} ends on {score}.",
"Game complete. {score} points for {player}.",
"{score}. That's the final.",
"Last box filled. {player} finishes with {score}.",
"{player} closes out the card at {score}.",
"That's it. {score} points.",
"Final card for {player}, {score}.",
"Thirteen boxes, {score} points.",
"{player} posts {score}.",
"The game's done. {score} for {player}.",
"Final result, {player} with {score}.",
```

**Snarky** (targets the dice and the decisions, D-082)
```
"Card's full. {score}. The dice would like partial credit.",
"{score}. The dice did their best, and this was their best.",
"Game over at {score}. Every one of those decisions was a decision.",
"Final score, {score}. The scratch box knows what it did.",
"{player} finishes at {score}. Nobody to beat, and the dice still put up a fight.",
"That's {score}. The dice are calling it a team effort.",
"{score}. The dice would like it noted they were under a lot of pressure.",
"Final card, {score}. Somewhere, a Chance box is still recovering.",
"{score}, and no opponent for the dice to blame it on.",
"Game over. {score}. The dice have requested a rematch with themselves.",
"That's the card. {score}. The ones column made some choices.",
"{score}. The dice refuse to comment further.",
"{player} wraps up at {score}. The dice are taking the evening off.",
"Final tally, {score}. Those holds were certainly holds.",
"{score} points. The dice say it was the table's fault.",
"Card complete at {score}. The Yatzy box has opinions, and it's keeping them.",
"{score}. Every roll happened, which is more than the dice promised.",
"That's {score}. The dice are already pretending the third roll never happened.",
"Game over at {score}. A bold strategy, executed by dice.",
"Final score, {score}. Those dice will be hearing from someone.",
```

---

## 6. Validation matrix

Run on device after the task named. R19 to R21 are defined in `15 §5`.

| ID | After | Check | Expect |
|---|---|---|---|
| F1 | 4.1 | **Debug only.** Build with `AppConfig.DebugGameNight.showLogs = true`. Host a Game Night, play a few turns, open the match's log sheet | Lines under `GameNightSession` and `GameNightMatchCoordinator` appear among SyFive's own. `FeelAudioEngine` lines appear if the engine logs during the session, for example a restart after the call changes the route. Its launch-time `engine started` line comes before the session log opens, so it is not expected. Set the flag back to false afterwards |
| F2 | 4.2 | Guest relaunches mid-match with the host's session still up, taps Rejoin, and the host then starts a new match (or a rematch) | The guest's roll button leaves "Waiting for Game Night…" at the match start, and the guest can roll on its turn |
| R19 | 4.4 | As `15 §5` | (a) The host falls silent at the next event after the tap. After the session ends, the button works in a solo game too. (b) The guest proximity started muted starts speaking as soon as the verdict or the timeout unmutes it |
| R20 | 4.5 | As `15 §5` | Speech stops at once; the queued lines are not spoken |
| F4 | 4.5 | (a) Host and guest at Game Night, commentary on at Play-by-Play. Score on the host so a burst queues; tap the host's commentary button during its first line. (b) Solo, set Sound to Off while a line speaks | (a) The host stops at once and drops its queue. The guest keeps speaking the host's lines, the later ones in that burst included (D-130). (b) The line stops at once |
| R21 | 4.6 | As `15 §5`, at least three solo games across two packs, Snarky included | Game over speaks a `soloFinished` line; no "{runnerUp}", no "wins by", no assertion; no lead-change line during the game |
| F5 | 4.6 | Two players, a full game | Game over still speaks `winnerDeclared` or `winnerTie`; lead changes are still spoken |
| F3 | 4.7 | Start a two-player game, score at least four turns each, then Pause. Open History → the unfinished game | "Match Progression" appears and shows both players' running totals so far |
| F6 | 4.8 | Unit-level: insert two `PlayerModel` rows with one id into an in-memory context and run the scan's dictionary line (or `healOrphanedParticipants()` from a test host) | No trap; one warning line |

Also re-run R1, R2, R3 and R11 after §4.5: muting must not change what an unmuted device says.

---

## 7. Open decisions

None, except Pops's approval of the copy in §5 (§2.4).

---

## 8. Invariants quick reference

- Every SyLib change keeps its defaults, ships with tests and docs, and leaves Syderal building
  and passing. (§2.1)
- Unmuted to muted cuts speech; the broadcast is never cut. (D-132, D-130)
- No `leadChange` and no `winnerDeclared` with fewer than two players. (D-133)
- ContentView's hooks that are wired once must not be cleared by the controller's teardown. (§4.4)
- Nothing in this phase changes the wire, the schema or `appProtocolVersion`. (D-131)

---

## 9. Ledger rows

**Commentary**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-132 | **Muting cuts speech at once.** Any change from unmuted to muted stops the line being spoken and drops the queue: the commentary button, Sound set to Off, or proximity muting a guest when ranging begins. (Proximity's verdicts and timeout only unmute, D-GNP-005.) The host's broadcast to guests is unaffected (D-130). | `14 §4.5` (Syderal Q-22) → `16 §2.2` |
| D-133 | **A solo game has no winner and no lead.** With one player, game over emits `soloFinished` (tokens `player`, `score`; celebration tier) in place of `winnerDeclared`, and `leadChange` is never emitted. Every pack carries `soloFinished` lines. | `14 §4.5` → `16 §2.3` |

**Game Night** (append to the Game Night table)

| ID | Current ruling | Source → chain |
|---|---|---|
| D-134 | **The Game Night log keeps SyLib's lines.** SyFive configures `GameNightLogBuffer` with its own categories (`GameNightController`, `ContentView`, `MatchController`), `packageCategories` and `FeelAudioEngine`. The log stays a Debug-only tool behind `AppConfig.DebugGameNight.showLogs`. | `14 §4.2` → `16 §2.5` *(rec.)* |

---

## 10. Results log

| Item | Value |
|---|---|
| SyLib branch and commits for §4.1 to §4.3 | Branch `syfive-reintegration`, base `1e2729fd`. §4.1 to §4.3: uncommitted working tree, for Pops to review and commit (`00A` §9) |
| SyLib test count after §4.3 | After §4.1: **1121 tests in 119 suites, passed** (1118 + 3 in the new `GameNightLogBuffer` suite), 0 warnings, 10 Oct 2026. After §4.2: **1124 tests in 119 suites, passed** (+3 new in `GameNightGuestRejoinTests`; `aMatchStartDoesNotEndTheWait` re-pinned as `aMatchStartEndsTheWait`), 0 warnings. **After §4.3: 1128 tests in 119 suites, passed** (+4 `matchProgression_*` in `StatsTests`), 0 warnings |
| Syderal build against the changed SyLib | After §4.1: **builds, no source edit, 0 warnings** (`syderal-ios/Syderal`, scheme `Syderal`, iPhone SE (3rd generation) iOS 18.6), 10 Oct 2026. After §4.2: **builds, no source edit, 0 warnings**. After §4.3: **builds, no source edit, 0 warnings** |
| Syderal test count | After §4.1: **897 total, 893 passed, 4 skipped (`SkillSpreadTests` scenarios 1–4), 0 failed** (from the result bundle), 10 Oct 2026. §2.1 cites 894 from Syderal's last report. **Reconciled 10 Oct 2026:** 894 is Syderal's count at its 23F/23G records; its latest record, `21B_TOUR_PRONUNCIATION.md` (lines 88, 124), already reports 897 test cases, 893 passed, 0 failed, 4 skipped, which is exactly the count measured here. Nothing is missing. After §4.2: **897 total, 893 passed, 4 skipped, 0 failed** (unchanged). After §4.3: **897 total, 893 passed, 4 skipped, 0 failed** (unchanged) |
| Syderal comments left stale by §4.2, for its next milestone | `GameNightAdapter.swift` 124-128, `GameNightMatchBridge.swift` 282-287 |
| §4.9 doc check (10 Oct 2026) | D-132, D-133 and D-134 are in the ledger verbatim (pasted by `00B` A-1). Searches of SyLib's `GAME_NIGHT.md`, `GAME_NIGHT_ADOPTION.md`, `GAME_NIGHT_MATCH.md` and `Yatzy.md`: "four logger categories", "`matchStart` does not" and "matchStart` does not clear" return none. "not `.completed`" returns three, all correct: `GAME_NIGHT_MATCH.md` 581 and 619 (history filtering, unchanged by this phase) and `Yatzy.md` 427 (the `comebackFrom` row as rewritten by §4.3) |
| `SyFiveTests` (with `CommentaryPackTests`) | After §4.1: 17 total, 17 passed (14 `FeelTests` + 3 UI tests; `CommentaryPackTests` not yet added), 10 Oct 2026. After §4.2: 17 total, 17 passed. After §4.3: **two runs, each 16 of 17**. In each, a different UI launch test failed, and the app crashed inside an Apple framework. Run 1: `SyFiveUITestsLaunchTests.testLaunch` (Light, Portrait), "Lost connection to the application"; crash `SyFive-2026-10-10-111920.ips` is a SIGSEGV in `UIWindowAccessibility _accessibilityRemoteElement` during the test runner's accessibility snapshot. Run 2: `SyFiveUITests.testLaunchPerformance`, "SyFive crashed"; crash `SyFive-2026-10-10-112107.ips` is a SIGABRT in RealityKit `PhysicsSystem::ecsToSim` (the dice scene). All 14 `FeelTests` passed both times. §4.3's only SyFive reach is `matchProgression`, called from `MatchDetailView.swift:60` and `UnfinishedMatchDetailView.swift:60` alone, which a launch test never opens. Reported, not fixed. After §4.4: **17 total, 17 passed** (no crash this run). After §4.6: **19 total, 19 passed** (+2 in the new `SyFiveTests/Commentary/CommentaryPackTests.swift`: every pack has a line for every kind and at least 20 `soloFinished`; every `{token}` is one its factory supplies), 0 warnings. After §4.7: **18 of 19**. `SyFiveUITestsLaunchTests.testLaunch` (Light, Portrait) failed with "Lost connection to the application", the same failure as §4.3 run 1; crash `SyFive-2026-10-10-113227.ips` is again a SIGSEGV in `UIWindowAccessibility` during the test runner's accessibility snapshot. All unit tests passed. Tally so far: 3 of 7 SyFive runs since §4.3 lost one UI launch test. After §4.8: **19 total, 19 passed**, 0 warnings (tally now 3 of 8). After §4.5: **19 total, 19 passed**, 0 warnings (tally 3 of 9) |
| §5 copy approved by Pops (date). §4.6 step 4 waits on this row | **Approved as written by Pops, 10 Oct 2026** (all 80 lines: 20 each for Sports, Zen, Steady, Snarky) |
| F1 (after §4.1) | **Not run**: device check (Debug log flag). Deferred by Pops, 10 Oct 2026 |
| F1 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| F2 (after §4.2) | **Not run**: two devices, mid-match relaunch. Deferred by Pops |
| F2 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| F3 (after §4.7) | **Not run**: device check (paused game → History). Deferred by Pops |
| F3 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| F4 (after §4.5) | **Not run**: §4.5 implemented 10 Oct 2026; device check outstanding (Pops) |
| F4 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| F5 (after §4.6) | **Not run**: device check (two-player game). Deferred by Pops |
| F5 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| F6 (after §4.8) | **Not run**: unit-level check. Deferred by Pops ("we will worry about the test later") |
| F6 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| R19 (after §4.4) | **Not run**: devices. Deferred by Pops. Part (b) from `15` §10 is also still unrecorded |
| R19 (a) (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| R19 (b) (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| R20 (after §4.5) | **Not run**: §4.5 implemented 10 Oct 2026; device check outstanding (Pops) |
| R20 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| R21 (after §4.6) | **Not run**: devices. Deferred by Pops |
| R21 (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |
| R1–R3, R11 re-runs (after §4.5) | **Not run**: §4.5 implemented 10 Oct 2026; device re-runs outstanding (Pops) |
| R1–R3, R11 re-runs (11 Oct 2026) | Pass (confirmed by Pops on device, 11 Oct 2026) |

---

## 11. Seen while writing, not in scope

These were noticed by reading. Each is left for Pops to rule on; none is to be fixed under this
document.

- **The roll-theatre hooks are lost when one live session replaces another.**
  `performControllerTearDown()` clears `onRollBegan`, `onRollResult`, `onHoldToggled` and
  `onUndoWithDice` (`GameNightController.swift` 520-524). `DiceAreaView` re-wires them only from
  `.onChange(of: gameNight.isSessionActive)` (`DiceAreaView.swift` 89-91). When a new session
  replaces a live one, `isSessionActive` goes true, false, true in one render pass, so that
  `onChange` does not fire. `ContentView.swift` 284-286 already notes this and keys its own
  handler on `sessionActivationCount` for that reason. Spectators would then see no roll theatre
  for the rest of that session. This is the same kind of fault as §4.4. The likely cure is to key
  `DiceAreaView`'s re-wire on `gameNight.session.sessionActivationCount`, as ContentView does. Not
  seen on a device.
- `MatchModel+Conversion.swift` line 29 in SyLibScoringData builds
  `Dictionary(uniqueKeysWithValues:)` over a match's participants by id, so two participant rows
  sharing one id, as a sync conflict could leave, would trap when that match is hydrated. SyFive
  reaches it through every `hydrate(from:context:)` call.
- `MatchController.swift` lines 385, 400 and 744 do the same over a participant's score entries,
  keyed by category. They would trap on two entries for one category.
  