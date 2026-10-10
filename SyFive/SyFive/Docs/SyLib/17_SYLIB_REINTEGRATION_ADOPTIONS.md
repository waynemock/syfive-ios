# SyLib reintegration, Phase 3: adopt SyLib in place of SyFive's own code, then release 1.1.0

**Status:** Ready for the agent once `16` is complete. Written 10 October 2026.

**Phase 3 of 3** of SyFive 1.1.0 (`15` build, `16` fixes, `17` adoptions).

**Scope:** `SyFive` only. No SyLib file changes in this phase. If an adoption seems to need one,
stop and report.

**Ship with every prompt for this phase:** `00_DECISION_LEDGER.md` (with `15`'s and `16`'s rows
pasted in), `00A_STUDIO_CONVENTIONS.md`, `00B_SYFIVE_GUARDRAILS.md`, this document, and `14_SYLIB_SYDERAL_INTEGRATION.md` §3. For how each API is used, read
the SyLib doc named in each task: `GAME_NIGHT_MATCH.md`, `GAME_NIGHT.md`,
`GAME_NIGHT_ADOPTION.md`, `SCORING_DATA.md`, `Commentary.md`, `APP_STORE.md` and
`UI_COMPONENTS.md`, all in the package's `Docs/`.

**Line numbers** are from the 10 October 2026 tree, before `16`. Phase 2 moves some of them.
Find each edit by the declaration named; the line number only says where to look.

---

## Supersessions

| Overrides | With | Why |
|---|---|---|
| D-077: "Full shuffle-bag not required for 1.0" | D-077 amended: shuffle-bag, saved across launches | §4.6. The engine has drawn from a shuffled deck since `SyLibCommentary`; this phase saves the deck between launches. |
| D-081: "Missing voice falls back to an enhanced locale voice" | D-081 amended: the best installed voice in the device's language, through `CommentaryVoices` | §4.6. The old fallback did not run for a deleted voice (`14 §3.7`). |
| `14 §3.3`: SyFive passes `{ showsGameNight = true }` as `onReadyToSeat` on a reconnect | An empty `onReadyToSeat` on a reconnect | Decided with Pops (D-136). A resume that fails falls through to the normal seating sheet. |
| `14 §3.9`: "Recommended: stay on the full initialiser" (the table view) | Unchanged. Not adopted here | Listed so nobody adopts it while in this code. |

---

## 1. What this phase does

Nine adoptions, each of which replaces SyFive code with the SyLib call that Syderal uses. They are
ordered so that the two that fix faults come first, Game Night before persistence, and the visible
UI changes last.

| § | Adoption | Replaces | Fixes | SyLib doc |
|---|---|---|---|---|
| 4.1 | `abandonSessionNotifyingGuests()` | send-then-abandon | The lost `matchAbandoned` (`14 §3.1`) | `GAME_NIGHT_MATCH.md` |
| 4.2 | Pending host resume | `pendingResumeMatchID/GameID`, the literal 500 ms | A cancelled share sheet mislabels the next session (`14 §3.3`) | `GAME_NIGHT_MATCH.md` |
| 4.3 | Guest rejoin routing | The router head, the identity restore, the wrapper | Rejoin into a live session leaves the guest unable to roll (`14 §3.2`) | `GAME_NIGHT_MATCH.md` |
| 4.4 | `GNHistoryStore` | Three history hook bodies | Incomplete matches can be stored; save errors are swallowed (`14 §3.4`) | `GAME_NIGHT_MATCH.md` |
| 4.5 | `upsertGameNightRoster` | Two roster copies | Two same-named people at one table merge into one (`14 §4.2`) | `SCORING_DATA.md` |
| 4.6 | `CommentaryVoices` + shuffle store | The voice fallback | A deleted saved voice is never replaced (`14 §3.7`) | `Commentary.md` |
| 4.7 | `AppUpdateState` + `MoreMenu` | Badge state and the menu label | The badge never clears (`14 §4.5`, `15` R22) | `APP_STORE.md`, `UI_COMPONENTS.md` |
| 4.8 | `GameNightMenuSection` + leading control | Menu branches, toolbar branches | — | `GAME_NIGHT.md` |
| 4.9 | `Toast` | Status-row feedback | — | `UI_COMPONENTS.md` |

§5 is release preparation, and §6 is the full validation pass.

**Not adopted, so nobody should do it while in this code:** the `GameNightTableView(session:)`
initialiser (`14 §3.9`); `upsertMatch`, `competitionRanks` and `playerOpponents` (`14 §3.6`);
`onTearDownWithReason`, `onGuestReconnectDeclined`, `leaveSessionOnThisDevice()` and
`FeelCatalog.validate()` (`14 §3.11`); anything in D-129.

---

## 2. Locked decisions

**2.1 An adoption may change behaviour only as its task says.** Each task lists what will differ.
Anything else that differs is a finding: report it, don't fix it. *Rationale:* every difference
here was read from source and put to Pops; nothing else was.

**2.2 The host's End is one awaited call** (D-135). `matchAbandoned` is sent with `sendAndWait`
(1.5 s bound) before the session is abandoned. *Rationale:* `14 §3.1`.

**2.3 A host reconnect is recorded and consumed by the coordinator, with an empty
`onReadyToSeat`** (D-136). When `consumePendingHostResume()` returns false, the activation handler
falls through to the normal seating sheet. *Rationale:* `14 §3.3`; decided with Pops.

**2.4 Roster upsert protects the table** (D-137). Both call sites pass `seatedPlayerIDs`, and
`remapOntoArchived` stays at its default (`true`, SyFive's behaviour today). *Rationale:*
`14 §3.5`, `§4.2`.

**2.5 History sync shares only completed Game Night matches the table shares** (D-138), as
`GNHistoryStore` does it. *Rationale:* `14 §3.4`; every difference there is a tightening.

**2.6 Voices** (D-081 amended). A personality speaks the saved voice if it is still installed, and
otherwise the best installed voice in the device's language: premium, then enhanced, then default;
never a novelty voice or a Personal Voice. SyFive keeps one saved voice for all four packs.
*Rationale:* `14 §3.7`. *(rec.)*

**2.7 The shuffle is saved across launches, per personality** (D-077 amended), under the key
`com.syzygysoftwerksllc.syfive.commentaryShuffle`. Never change that key. *(rec.)*

**2.8 The update badge clears from the Update Available item, and the acknowledgement is
stored** (D-139). There is no "menu opened" signal to use (Syderal Q-32, Q-33). In the fallback
drawing, where the system lacks `ellipsis.circle.badge`, the dot has no outline. *(rec.)*

**2.9 The Game Night menu items and toolbar control are SyLib's** (D-140). Their titles, icons
and accessibility labels are SyLib's. SyFive's Play Again stays SyFive's, in the section's app
slot and in the leading toolbar. *Rationale:* `14 §3.10`; the toolbar control becomes SyLibUI's
bolder `IconButton`, which Pops accepted with this phase.

**2.10 Commentary on/off feedback is a toast over the bottom of the dice tray** (D-141), never
over the roll controls or the status row beneath them. *(rec.)*

---

## 3. Before starting

- `16` is complete, with every F-check and R19 to R21 passing.
- The second device is still on the App Store's 1.0.3 (for R16 in §6).

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 The host's End: one awaited call

**File:** `App/GameNight/GameNightController.swift`, `abandonSession()` (lines 223-227).

```swift
/// Ends Game Night for everyone as host: tells the guests, waits up to 1.5 s for the send,
/// then abandons the session (17 §4.1, D-135).
func abandonSession() {
    Task {
        let ran = await coordinator.abandonSessionNotifyingGuests()
        logger.info(self, "abandonSession: ran=\(ran)")
    }
}
```

The guard on role and active session moves into the coordinator, which checks the same things and
ignores a second tap while the first is waiting. The caller, `onAbandonSession` in
`Views/ContentView.swift` (line 193), is unchanged.

**What will differ:** the teardown runs up to 1.5 s after the tap, not in the same pass. Guests hear
`matchAbandoned` and raise "Game Night ended" at once, even during an audio interruption. If the
session drops during that wait, the host sees "Game Night ended" with its Reconnect button after
choosing End (`14 §3.1`). The window is the wait.

**Check:** A1.

### 4.2 The host's reconnect: record, consume, clear

**Files:** `Views/ContentView.swift`, `Views/ContentView+Persistence.swift`,
`App/GameNight/GameNightController.swift`.

1. **Remove the state.** Delete `pendingResumeMatchID` and `pendingResumeGameID` (`ContentView.swift`
   lines 31-34, with their comment).
2. **The dropped-call Reconnect** (`gameNightAlerts`'s `onHostReconnect`, lines 196-206):

   ```swift
   onHostReconnect: { matchID, gameID in
       gameNight.coordinator.recordPendingHostResume(matchID: matchID, gameID: gameID)
       gameNight.beginHosting(
           onNeedsConversation: { gameNight.coordinator.clearPendingHostResume() },
           onReadyToSeat: {}   // a reconnect never seats (D-136)
       )
   }
   ```

3. **SyFive's own "Reconnect Game Night?" alert** (lines 208-224). Resume as Host calls
   `beginHosting` with the same two closures as step 2. Play Locally calls
   `gameNight.coordinator.clearPendingHostResume()`.
4. **At launch** (`ContentView+Persistence.swift`, `loadMatchIfNeeded()`, lines 23-31): where the code sets
   `pendingResumeMatchID` and `pendingResumeGameID`, fetch the Yatzy game id as it does now and call
   `gameNight.coordinator.recordPendingHostResume(matchID: matchModel.id, gameID: gameID)` when the
   game id is found. `gnAlerts.showsHostReconnect = true` stays.
5. **At activation** (`ContentView.swift`, the `sessionActivationCount` handler, lines 403-424). Keep its
   place, after `gameNight.attach(matchController: model)` and the hooks:

   ```swift
   if gameNight.coordinator.consumePendingHostResume() {
       // Resumed: guests follow from the matchState it sent. No seating sheet.
   } else {
       Task { @MainActor in
           try? await Task.sleep(for: GameNightSession<GameNightActivity>.seatingSheetDelay)
           // …the existing body of the delayed branch, unchanged (guards, log, presentGameNightSheetOrAlert())
       }
   }
   ```

   Keep the existing comment about the sharing controller's dismiss animation above the delay.
6. **Delete** `GameNightController.resumeAsHost(matchID:gameID:)` (line 312). Nothing calls it now.
   Leave `onHostResumed` unset: SyFive reads `localParticipantID` from the coordinator when it needs
   it, so there is nothing to re-stamp.

**What will differ:** when the session that arrives is not one this device can resume into (it
joined as a guest, or the phase has moved on), the recording is dropped and the seating sheet
opens as for a fresh session. Before, SyFive skipped the sheet and resumed nothing. The resume
itself is unchanged.

**Check:** A2, A3.

### 4.3 A guest's rejoin: routing, restore and prepare

**Files:** `App/GameNight/GameNightController.swift`, `Views/ContentView.swift`.

1. **The router head** (`handleAppMessage`, lines 366-377) becomes:

   ```swift
   if coordinator.routeMatchMessage(kindString, envelope: envelope, from: senderID,
                                    onMatchState: { handleMatchState($0) }) {
       return
   }
   guard let kind = GameNightMessageKind(rawValue: kindString) else { return }
   ```

2. **The identity restore** (`handleMatchState`, lines 421-426). Keep `let isReconnect =
   coordinator.localParticipantID == nil` for the log line, then replace the `if` block with
   `coordinator.restoreRejoiningGuest(from: payload)`. The rest of the function is unchanged.
3. **Prepare.** Delete `GameNightController.prepareForGuestReconnect(matchID:)` (lines 249-254). In
   `ContentView.swift` line 194, `onGuestReconnect` becomes
   `{ gameNight.coordinator.prepareForGuestReconnect(matchID: $0) }`.

**What will differ:** (1) a match id and game id held from an earlier match are replaced by the ids
in the host's state. SyFive used to keep them. A participant id already held is never overwritten,
as before. (2) `isGuestAwaitingReconnect` clears when the host's `matchState`
arrives, as it already does at a match start since `16` §4.2. So a guest that taps Rejoin with a
session already up can roll at the host's next state, without waiting for the session to end.

**Check:** A4.

### 4.4 History sync through `GNHistoryStore`

**File:** `Views/ContentView.swift`, the three hooks in the `sessionActivationCount` handler (lines
352-402).

```swift
gameNight.onHistoryManifestNeeded = {
    let seated = Set(gameNight.seats.compactMap { $0.playerID })
    do { return try GNHistoryStore.manifestIDs(seatedPlayerIDs: seated, in: ctx) }
    catch { logger.error(self, "history manifest failed: \(error)"); return [] }
}
gameNight.onHistoryMatchesNeeded = { matchIDs in
    let seated = Set(gameNight.seats.compactMap { $0.playerID })
    do { return try GNHistoryStore.matches(for: matchIDs, seatedPlayerIDs: seated, in: ctx) }
    catch { logger.error(self, "history matches failed: \(error)"); return [] }
}
gameNight.onHistoryMatchesReceived = { matches in
    do {
        let stored = try GNHistoryStore.storeReceived(matches, in: ctx)
        logger.info(self, "history received: \(matches.count), stored \(stored)")
    } catch { logger.error(self, "history store failed: \(error)") }
}
```

The defaults are SyFive's own numbers: scan 40, cap 20. Pass no `ignoring` set, because SyFive has
no computer players.

**What will differ** (`14 §3.4`): a manifest never lists one id twice, and the fullest row stands
for a match. A request is answered only with completed Game Night matches whose people are all
seated now. A received match that is not completed, or has no completion time, is skipped. A received match is written with `upsertMatch(_:isGameNight: true, in:)`, where SyFive inserted a
`MatchModel` and hydrated it. A save failure is logged rather than swallowed. The two "skipped"
info lines go, replaced by one "stored N" line.

**Check:** A5.

### 4.5 Roster upsert through `upsertGameNightRoster`

**Files:** `Views/ContentView+GameNight.swift` (`upsertGameNightPlayerModels()`, lines 187-224) and
`Views/ContentView+Persistence.swift` (`ensurePlayerModels(for:)`, lines 111-152).

1. `upsertGameNightPlayerModels()` keeps its `guard gameNight.isSessionActive`. Its body becomes:
   build one `GameNightRosterPlayer` per seat index that has a `playerID`, from `model.playerIDs`,
   `model.playerDisplayNames`, `model.playerDisplayInitials` and `model.playerThemes[i].rawValue`.
   Then call:

   ```swift
   let seated = Set(model.playerIDs.compactMap { $0 })
       .union(gameNight.seats.compactMap { $0.playerID })
   do {
       let changes = try upsertGameNightRoster(players, seatedPlayerIDs: seated, in: modelContext)
       if !changes.isEmpty {
           logger.info(self, "roster upsert: inserted \(changes.insertedIDs.count), remapped \(changes.remapped.count)")
       }
   } catch { logger.error(self, "roster upsert failed: \(error)") }
   ```

2. `ensurePlayerModels(for:)` does the same from the participants: one player per participant with
   a `playerID`, from `displayName`, `displayInitials` and `displayThemeID`.
   `seatedPlayerIDs` is the set of those participants' `playerID`s: they are the match's table.
3. Update both doc comments: the name-and-initials rule is now SyLib's, with its two protections.

**What will differ:** a local player seated at this table never captures a different incoming
player of the same name, and one local player captures at most one incoming player per call
(`14 §4.2`). Where several local players match, an active one is chosen before an archived one,
and then the earliest created. Failures are logged rather than swallowed.

**Check:** A6.

### 4.6 Commentary: `CommentaryVoices` and the saved shuffle

**Files:** `Views/ContentView.swift`, `Views/ContentView+Commentary.swift`,
`App/Commentary/CommentaryScreens.swift`.

**Voices.**

1. In `ContentView`, add:

   ```swift
   @State var commentaryVoices = CommentaryVoices(
       answeringFor: CommentaryPersonality.all.map { ($0.id, $0.voiceCriteria) }
   )
   ```

   SyFive's packs pass no criteria, so each means the device's language.
2. In the existing `.task`, after `director.warmUp()`: `await commentaryVoices.refresh()`.
3. Add `import AVFoundation` to `ContentView.swift`. The target sets member import visibility, so
   the import in `ContentView+Commentary.swift` does not reach this file. Then refresh again when
   the system's voices change:

   ```swift
   .onReceive(NotificationCenter.default.publisher(
       for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
       Task { await commentaryVoices.refresh() }
   }
   .onChange(of: commentaryVoices.revision) { _, _ in syncCommentaryEngine() }
   ```

4. Put it in the environment: `.environment(commentaryVoices)` beside `.environment(director)`
   (line 245), and on the Settings sheet's content (line 493), as the sheets already do with
   `theme`.
5. In `syncCommentaryEngine()`, replace the voice lines (69-71) with:

   ```swift
   let savedID = UserDefaults.standard.commentaryVoiceID
   let voice = commentaryVoices.voiceInUse(for: personality.id, savedID: savedID)
       .flatMap { AVSpeechSynthesisVoice(identifier: $0.identifier) }
   ```

   Before the first scan lands, `voice` is nil. The `revision` change re-runs the sync when the
   scan lands.
6. In `CommentaryScreen`, read `@Environment(CommentaryVoices.self) private var voices`. The getter
   of `voiceIDBinding` (lines 35-40) returns
   `voices.voiceInUse(for: settings.commentaryPersonalityID, savedID: saved)?.identifier ?? saved`,
   where `saved` is `UserDefaults.standard.commentaryVoiceID`. The setter is unchanged. This way the
   Voice row and its preview name the voice actually in use.
7. The `#Preview` of any view that now reads `CommentaryVoices` injects one (Engineering
   Guidelines: previews are required).

**The shuffle.**

8. In `ContentView`, add `let commentaryShuffleStore = CommentaryShuffleStore(key:
   "com.syzygysoftwerksllc.syfive.commentaryShuffle")` and
   `@State var shuffleLoadedFor: String? = nil`.
9. In `syncCommentaryEngine()`:
   - **Disabled branch** (before `commentaryEngine = nil`): if `shuffleLoadedFor` is set, save the
     engine's `shuffleState` under it, then set `shuffleLoadedFor = nil`.
   - **Guest branch** (before `engine.update(...)` or creation): the same save-and-forget. A
     guest's engine speaks the host's text and draws nothing.
   - **Host or solo branch:** *before* `engine.update(...)`, if `shuffleLoadedFor` is set and
     differs from `personality.id`, save under `shuffleLoadedFor`. This must happen first, because
     `update` clears the shuffle when the personality changes. *After* the update or creation, if
     `shuffleLoadedFor != personality.id`, call
     `commentaryEngine?.restoreShuffle(commentaryShuffleStore.load(for: personality.id))` and set
     `shuffleLoadedFor = personality.id`.
10. In the `scenePhase` handler's `.background` case (line 443): save the engine's `shuffleState`
    under `shuffleLoadedFor` when both are set.

**What will differ:** a player whose saved voice was deleted, or who never chose one, hears the
best installed voice in the device's language, where they used to hear the system's voice for
the bare language code. The two may differ on a device set to a regional variety (`14 §3.7`). A
pack plays through all its lines across launches before it repeats one.

**Check:** A7, A8.

### 4.7 The update badge: `AppUpdateState` and `MoreMenu`

**File:** `Views/ContentView.swift`.

1. Replace `isUpdateAvailable` and `updateBadgeAcknowledged` (lines 37-38) with
   `@State var updateState = AppUpdateState()`.
2. In `.task` (line 248): `await updateState.check()`.
3. Replace `Menu { … } label: { IconButton(…) }` and its `.simultaneousGesture` (lines 85-150)
   with:

   ```swift
   MoreMenu(showsBadge: updateState.showsBadge,
            badgeColor: theme.successColor,
            accessibilityLabel: "Menu",
            badgedAccessibilityLabel: "Menu, update available") {
       // the same items, in the same order
   }
   ```

4. The Update Available item shows while `updateState.isUpdateAvailable`, and its action is
   `updateState.acknowledge(); openAppStore()`.
5. Delete `shouldShowUpdateBadge` and `acknowledgeUpdateBadge()` (lines 542-549).

**What will differ:** the badge is the system's `ellipsis.circle.badge`, drawn as one glyph. Where
the system lacks it, the drawn dot appears without its outline. The badge clears when Update
Available is tapped, and stays cleared across launches for that store version. Opening the menu
no longer does anything to it.

**Check:** R22 now passes (run as A9 describes); A9.

### 4.8 The Game Night menu section and toolbar control

**Files:** `Views/ContentView+GameNight.swift`, `Views/ContentView.swift`.

1. Add a computed property: `var gameNightEntry: GameNightEntryState { GameNightEntryState(session:
   gameNight.session) }`. It is read from `body`, so the menu and the control follow the session.
2. **The menu.** The body of `gameNightMenuSection` (lines 88-153) becomes:

   ```swift
   GameNightMenuSection(
       state: gameNightEntry,
       onStart: {
           gameNight.beginHosting(
               onNeedsConversation: { showsInviteInstructions = true },
               onReadyToSeat: { presentGameNightSheetOrAlert() })
       },
       onCancelInvite: { gnAlerts.showsCancelSession = true },
       onOpenSetup: { showsGameNight = true },
       onEnd: { gnAlerts.showsCancelSession = true },
       onShowHelp: { showsGameNightHelp = true }
   ) {
       if gameNight.isSessionActive && gameNight.role == .host && gameNight.phase == .completed {
           Button { startGameNightRematch() } label: {
               Label("Play Again", systemImage: "arrow.clockwise.circle")
           }
       }
   }
   ```

3. **The toolbar control.** `leadingNavButton` (lines 15-81) becomes:
   - If `gameNightEntry.leadingControl` is non-nil: draw `GameNightLeadingControlButton(control)`,
     with an action that switches on the control: `.start` calls `beginHosting` exactly as now
     (lines 55-59); `.inviteSent` sets `showsGameNightPendingSheet`; `.setup` sets
     `showsGameNight`; `.end` sets `gnAlerts.showsCancelSession`; `.active` does nothing, and is
     never called.
   - Else, if the session is active, this device hosts, and the phase is `.completed`: SyFive's Play
     Again button (lines 41-47), unchanged.
   - Else: SyFive's two non-Game-Night buttons (lines 64-80), unchanged.
4. Replace `showsGameNightHelpButton` (lines 157-161) with `gameNightEntry.showsLeadingHelp` at its
   one use (`ContentView.swift` line 73), and delete it.
5. `gameNightHelpContext` is unchanged.

**What will differ:** the toolbar control is drawn with SyLibUI's `IconButton`: bolder and larger.
"Game Night Active" gains the accessibility label "Game Night active", and the guest's green
indicator gains "Game Night Active". A host at the `.abandoned` phase, a state nothing reaches,
falls through to SyFive's New Game or Play Again buttons, where today it shows the green indicator. Every menu row and help-button state is otherwise as today (`14 §3.10`).

**Check:** A10.

### 4.9 Commentary on/off feedback as a toast

**File:** `Views/DiceAreaView.swift`.

1. Delete `commentaryFeedback` and `commentaryFeedbackTask` (lines 33-34),
   `showCommentaryFeedback(suppressed:)` (lines 295-303), and the `else if let msg =
   commentaryFeedback` branch of the status row (lines 210-212).
2. Add `@State private var commentaryToast: Toast?`.
3. The commentary button's action (lines 118-122) sets, after `setCommentarySuppressed`:

   ```swift
   commentaryToast = Toast(willSuppress ? "Commentary off" : "Commentary on",
                           systemImage: willSuppress ? "quote.bubble" : "quote.bubble.fill")
   ```

4. Put `.toast($commentaryToast)` on the `DiceTrayView(…) { … }` in `body` (lines 44-64), so the
   capsule rises over the bottom of the tray, directly above the roll controls, and never covers
   them (D-141).
5. Update `DiceAreaView`'s `#Preview` if it needs anything new. `Toast` needs no environment.

**What will differ:** the words leave the status row, so "Choose a category to score" and "No rolls
remaining" no longer give way to them. The stuck-dice message already took priority, and still
does. The toast lasts two seconds and takes no taps.

**Check:** A11.

---

## 5. Release preparation for 1.1.0

1. **Pre-submission flags** (`00B` §6). In `Utilities/AppConfig.swift`, confirm every flag is `false`:
   `DebugLayout.isEnabled`, `DebugFeel.showFeelBoard`, `DebugDice.showPhysicsSliders`,
   `DebugDice.showHarness`, `DebugDice.logRollDiagnostics`, `DebugCloudKit.runSchemaExercise` and
   `DebugGameNight.showLogs`. Confirm `MARKETING_VERSION` is `1.1.0` in **both** configurations: R22
   and A9 lower it in Debug.
2. **CloudKit.** 1.1.0 changes no model, attribute or schema (`14 §1.4`). Confirm in the CloudKit
   Console that Production matches Development for `iCloud.com.syzygysoftwerksllc.SyFive` before
   the TestFlight build, as the promotion gate requires.
3. **SyLib (Pops).** Merge `sylib-swift`'s `syfive-reintegration` branch (`16` §4.1 to §4.3) so that Syderal's next
   build picks those changes up knowingly. Record the merged commit in §10.
4. **SyFive (Pops).** Merge `sylib-reintegration`. Agents never run `git` (`00A` §9). `MARKETING_VERSION` is 1.1.0 (`15` §2.6).
5. **Docs.** Confirm §9's rows are in the ledger (`00B` Task A-1 pasted them). Update
   `IMPLEMENTATION_STATUS.md` with one line for 1.1.0: "Rebuilt on the post-Syderal SyLib; see `15` to `17`."
6. **App Store "What's New"** is Pops's copy. Nothing in this doc drafts it.

---

## 6. Validation matrix

Run A1 to A11 after their tasks. When §4 is complete, run the **full regression**: R1 to R22
(`15 §5`), F1 to F6 (`16 §6`), then A1 to A11 again. Run it on a Release build with §5.1's flags
set, except for the **Debug-only** checks: F1 (log flag), F6 (unit-level), and R22 and A9 (lowered
version). Run those on a Debug build, then restore §5.1's values.

| ID | After | Check | Expect |
|---|---|---|---|
| A1 | 4.1 | Host and guest, match in progress. Host: menu → End Game Night → confirm. Repeat during a phone-call interruption on the guest | The guest raises "Game Night ended" at once, both times. The host's log shows `abandonSession: ran=true` and `matchAbandoned delivered=true` |
| A2 | 4.2 | Host drops mid-match (hang up the call), relaunches, answers "Reconnect Game Night?" with Resume as Host, and starts a new call | No seating sheet. The match resumes; guests rejoin as before (R17 c) |
| A3 | 4.2 | Host: Resume as Host, then cancel the sharing sheet after more than a second. Then join a session another device hosts | The seating sheet opens for the joined session. The log shows `pending host resume dropped` |
| A4 | 4.3 | Guest relaunches mid-match while the host's session is still up, taps Rejoin | The guest leaves "Waiting for Game Night…" at the host's next `matchState`, and can roll on its own turn |
| A5 | 4.4 | Two devices that share at least one completed Game Night match, and one that does not, at one table | History syncs only the shared matches. The log shows "stored N". There are no duplicates in either History |
| A6 | 4.5 | Device A has a local player "Sam S". Device B seats a different "Sam S" (another person, same name and initials) beside A's Sam at one table. Play a match | A holds two players named Sam S. The finished match shows both, with separate results. Players shows no merge |
| A7 | 4.6 | Save a voice, delete it in iOS Settings, return to SyFive and play with commentary on | Commentary speaks in the best installed voice for the device's language. Settings → Commentary → Voice names that voice, and Preview speaks in it |
| A8 | 4.6 | Play with one pack until a few lines have spoken, force-quit, relaunch, play again | No line from the earlier session repeats until the pack's deck has run through (spot check with Steady's `turnStart`) |
| A9 | 4.7 | **Debug only.** `MARKETING_VERSION` set to `1.0.2` in the Debug configuration, as for R22, on a fresh install (the acknowledgement is stored under `SyLib.AcknowledgedUpdateVersion`, so delete the app to repeat). Open and close the menu, tap Update Available, then relaunch. Put the version back afterwards | The badge stays after open and close, clears on the tap, and stays cleared after relaunch. The Update Available item is still in the menu |
| A10 | 4.8 | Walk every row of the table in §6.1 | Each state shows exactly the menu rows, toolbar control and help button that §6.1 gives |
| A11 | 4.9 | Tap the commentary button during play, including while the stuck-dice message shows | A toast rises over the bottom of the tray for two seconds. The status row keeps its own text. The roll controls stay uncovered |

### 6.1 Game Night entry states (A10)

Derived from `GameNightEntryState` (`menuItems`, `leadingControl`, `showsLeadingHelp`) plus SyFive's
own items, and checked against what SyFive shows today (`ContentView+GameNight.swift` 15-161). Every
row matches today except the two marked.

| # | State | Menu rows, in order (Game Night section) | Leading toolbar | `?` help button |
|---|---|---|---|---|
| 1 | No session, not on a call | Start Game Night · Game Night Help | SyFive's own: New Game (`arrow.clockwise`) mid-game, Play Again (`plus`) after a game, nothing before one | Hidden |
| 2 | No session, on a call (eligible) | Start Game Night · Game Night Help | Game Night (`person.3.fill`, accent tint) → starts hosting | Shown |
| 3 | Invite sent | Cancel Game Night Invite (destructive) · Game Night Help | Invite Sent (green) → pending sheet | Shown |
| 4 | At the table, host | Game Night Setup · Game Night Help | Game Night Setup (green) → table | Shown |
| 5 | At the table, guest | Game Night Setup · End Game Night (destructive) · Game Night Help | Game Night Setup (green) → table | Shown |
| 6 | In progress, host | End Game Night (destructive) · Game Night Help | End Game Night (green) → confirm | Hidden |
| 7 | In progress, guest or spectator | Game Night Active · Game Night Help | Game Night Active (green icon, not a button; label "Game Night Active", **new**) | Hidden |
| 8 | Completed, host | Play Again (SyFive's) · Game Night Help | Play Again (`arrow.clockwise.circle`, SyFive's) | Hidden |
| 9 | Completed, guest | Game Night Help | Game Night Active (green icon, label **new**) | Hidden |

The visible change in every live row is the control's drawing: SyLibUI's `IconButton`, bolder and
larger (`14 §3.10`). Spectators are "not host" throughout.

---

## 7. Open decisions

None.

---

## 8. Invariants quick reference

- No SyLib edit in this phase. (Scope)
- `appProtocolVersion` 1, transport 3. (D-131)
- Store and seed stay SyFive's. (D-129)
- `matchAbandoned` only through `abandonSessionNotifyingGuests()`, and only when ending. (D-135)
- Reconnect: record → `beginHosting` with an empty `onReadyToSeat` → consume. (D-136)
- Roster upsert always passes `seatedPlayerIDs`. (D-137)
- The shuffle key never changes. (§2.7)
- Badge: acknowledge from the item, never from the menu. (D-139)
- The toast never covers the roll controls. (D-141)

---

## 9. Ledger rows

**Already pasted by `00B` Task A-1**; listed here as this document's record. D-077 and D-081
replaced their rows. The others are new.

**Commentary**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-077 | **No immediate repeat, and a shuffle-bag.** Each event kind draws from a shuffled deck of its lines, and a refilled deck never starts with the last line used. The deck is saved per personality across launches (`CommentaryShuffleStore`, key `com.syzygysoftwerksllc.syfive.commentaryShuffle`, never changed). | `09 §1.4` → `17 §2.7` *(rec.)* |
| D-081 | **Voice ID is device-local** (UserDefaults); level and personality sync. A personality speaks the saved voice while it is installed, else the best installed voice in the device's language (premium, enhanced, default; never novelty or Personal Voice), resolved through `CommentaryVoices`. The Voice row names the voice in use. | `09 §6.1` → `14 §3.7` → `17 §2.6` *(rec.)* |
| D-141 | **Commentary on/off feedback is a SyLibUI `Toast`** over the bottom of the dice tray: two seconds, no taps, never over the roll controls or the status row beneath them. | `14 §3.11` → `17 §2.10` *(rec.)* |

**Game Night**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-135 | **The host ends Game Night with one awaited call**, `abandonSessionNotifyingGuests()`. `matchAbandoned` is sent only by a host that is ending Game Night, never to discard a match and keep the table. | `14 §3.1, §4.1` (Syderal L-14, Q-16) → `17 §2.2` |
| D-136 | **Host reconnect is recorded and consumed by the coordinator.** Record → `beginHosting` with an empty `onReadyToSeat` → `consumePendingHostResume()` at activation. When it returns false the normal seating sheet opens. `onNeedsConversation` and Play Locally clear the recording. | `14 §3.3` (Syderal L-23) → `17 §2.3` |
| D-137 | **Roster upsert never merges two people at one table.** SyFive uses `upsertGameNightRoster` with `seatedPlayerIDs` at both call sites; `remapOntoArchived` stays `true`. | `14 §3.5, §4.2` (Syderal L-39, L-43) → `17 §2.4` |
| D-138 | **History sync shares only completed Game Night matches the table shares**, judged by a match's fullest row, through `GNHistoryStore`. | `14 §3.4` (Syderal L-18, L-40) → `17 §2.5` |
| D-140 | **Game Night menu items and the leading toolbar control are SyLib's** (`GameNightMenuSection`, `GameNightLeadingControlButton`), with SyLib's titles and labels. Play Again stays SyFive's. | `14 §3.10` (Syderal L-22) → `17 §2.9` |

**Platform & data**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-139 | **The update badge** comes from SyLibCore's `AppUpdateState` and SyLibUI's `MoreMenu`. It clears when Update Available is tapped, and the acknowledgement is stored per store version. Never acknowledge on menu open: SwiftUI's `Menu` has no reliable signal for it. | `14 §3.11, §4.5` (Syderal Q-32, Q-33) → `17 §2.8` *(rec.)* |

---

## 10. Results log

| Item | Value |
|---|---|
| §3 precondition | **Waived by Pops, 10 Oct 2026**: `17` starts before `16`'s F-checks and R19 to R21 have run on devices. Pops runs them, with A1 to A11, in the full regression once the build is done |
| A1 to A11 | One row each |
| SyFive suite during §4 (agent) | §4.1 to §4.3: 19/19 each. §4.4: 18/19. `SyFiveUITests.testLaunchPerformance` lost to an app crash during launch: SIGTRAP in libdispatch `_dispatch_once_wait`, from `Security SecCertificateParse` (`SyFive-2026-10-10-115752.ips`). This is a third kind of framework crash, after the two logged in `16` §10. The history hooks run only inside a Game Night session, which a launch test never starts. Tally since `16` §4.3: 4 of 13 runs. §4.5: 18/19. `SyFiveUITestsLaunchTests.testLaunch` (Unspecified, Portrait) failed with "Lost connection"; crash `SyFive-2026-10-10-120016.ips` is the same SIGSEGV in `UIWindowAccessibility _accessibilityRemoteElement`, under XCTest's own `XCTElementSnapshotRequest`, with no SyFive frame on the stack. Tally 5 of 14 |
| UI-test crash investigation (10 Oct 2026) | **Environmental, not SyFive.** From 09:57 to 12:22 the simulator runtime's own processes crashed about 70 times: `maild` 27, `TypeToSiriWidgetExtension` 34, `UsageTrackingAgent` 8, `biomed` 2, `healthd` 1, all from `/Volumes/VOLUME/*` (the iOS runtime image). The five SyFive launch crashes fall inside that window, each in a different framework, with no SyFive frame beyond `main`. Xcode itself later crashed. After the Xcode restart there were no crashes of any process in 3 runs of the exact failing sequence (`BuildProject`, then the suite). Before the restart: 0 failures in 28 runs of other shapes (UI-only ×6, full ×5 parallel off, full ×5 parallel on, 4 separate, 5 rebuild-first). No code or test changed. If it recurs: restart Xcode, `xcrun simctl shutdown all`, then re-run |
| RealityKit launch assertion (found 10 Oct 2026, **open, reported not fixed; full analysis in §11**) | One crash class is real, not environmental: `assertion failure: Index out of range (operator[]:line 858) index = 0, max = 0` in RealityKit `PhysicsSystem::ecsToSim`, ~1.7 s after launch (app stdout; crashes `SyFive-…-112107.ips` and `-152141.ips`). Reproduced deliberately: `testLaunchPerformance` ×8 gave **1 in 48 launches on iOS 18.6** (iPhone SE (3rd generation)) and **0 in 48 on iOS 27.0** (iPhone 17). It predates §4.6 (first seen at 11:21, during `16` §4.3). The dice scene is SyLib's (`SyLibDice`: `DiceRKView`/`DiceRoller.setup`). One unconfirmed lead: `setup` returns early when dice already exist, so a rebuilt `RealityView` would leave the dice parented to the old scene. A fix is a SyLib dice edit no task names: stop condition (`00B` §2) |
| Toast placement (Pops, 10 Oct 2026, after §4.9) | The commentary toast slides down out from under the **Roll button** (`bottomPadding: 4`), over the status row; the button row has `.zIndex(1)` so the status text does not draw over it. Pops's second direction moved it from below the whole controls strip. SyLib `Toast` gained an additive `placement: ToastPlacement = .overBottom` (`.belowBottom` hangs it under the view's bottom edge, clipped there), so the default and Syderal's `GameHUD.swift:274` are unchanged. One test, `aToastMovesForItsPlacement`. `UI_COMPONENTS.md` updated. SyLib 1129 passed; Syderal builds, 897 / 893 passed / 4 skipped / 0 failed; SyFive 19/19. SyFive changes: `.toast($commentaryToast, bottomPadding: 4, placement: .belowBottom)` on the Roll button, `.zIndex(1)` on the button row, and `.zIndex(1)` on `DiceAreaView` in `ContentView+Layout.swift` so it draws over the scorecard. Ledger D-141 updated |
| SyFive suite after §4.6 | 18/19: `testLaunchPerformance` lost to the RealityKit assertion above. All 16 unit tests pass. BuildProject clean, 0 warnings |
| Open findings closed (Pops, 10 Oct 2026) | **`16` §11, roll-theatre hooks lost on session replacement:** `DiceAreaView` now re-wires on `gameNight.session.sessionActivationCount`, not `isSessionActive`. **`16` §11, traps on repeated ids:** SyLib `MatchModel.hydrate(from:context:)` builds its by-id map with `uniquingKeysWith` (keeps the first), with test `hydrateToleratesDuplicateParticipantIDs`. `MatchController`'s three score-entry maps (formerly 385, 400, 744) do the same. Copies are not resolved. **`CommentaryScreen` `#Preview`** added (in-memory `AppSettingsModel`, `CommentaryVoices()`); built, not rendered. **Docs:** README platform line is now iOS/iPadOS 18.6+, and `ENGINEERING_GUIDELINES.md`'s folder map was rewritten to the tree. **Syderal 894 vs 897** reconciled (`16` §10): Syderal's own latest record is 897. Checks: SyLib 1130 passed; Syderal 897 / 893 / 4 skipped / 0 failed; SyFive 19/19; 0 warnings. **Not done:** the two stale Syderal comments (`GameNightAdapter.swift` 124-128, `GameNightMatchBridge.swift` 282-287), because `00B` §5.4 says Syderal is never edited from a SyFive session |
| Full regression (R1 to R22, F1 to F6, A1 to A11) on Release | One row each |
| §5.1 flags confirmed false | **Confirmed 10 Oct 2026** (`Utilities/AppConfig.swift`): `DebugLayout.isEnabled` (5), `DebugFeel.showFeelBoard` (10), `DebugDice.showPhysicsSliders` (15), `DebugDice.showHarness` (17), `DebugDice.logRollDiagnostics` (19), `DebugCloudKit.runSchemaExercise` (26), `DebugGameNight.showLogs` (32): all `false`. `MARKETING_VERSION = 1.1.0` in the app target's Debug (`project.pbxproj` 413) and Release (465). `CURRENT_PROJECT_VERSION` is 1, which Pops sets at archive. §5.5 docs: all 17 ledger rows from `15`–`17` §9 are present. 16 match their §9 text verbatim; D-141 differs by Pops's placement direction (see the toast row above). `IMPLEMENTATION_STATUS.md` gained the 1.1.0 line |
| CloudKit Production matches Development | **Done by Pops, 10 Oct 2026:** schema pushed with `SyFiveApp.initializeCloudKitSchema` (flag `DebugCloudKit.runSchemaExercise`) and deployed Development → Production. The flag is back to `false` |
| SyLib merged commit | |
| SyFive merged commit | |

---

## 11. Found during this phase, not in scope: a RealityKit assertion at launch

Found by the agent on 10 October 2026 while it was chasing intermittent UI-test failures. **Open.** Nothing has been changed for it. It is recorded here so the analysis survives until Pops picks it up. Fixing it is a SyLib dice edit that no task names, and it sits next to the dice physics the fairness certification was measured on. Both are stop conditions (`00B` §2).

### 11.1 What happens

- About **1.7 s after launch**, before any input, the app aborts on the main thread.
- The app's stdout logs, at the moment of the crash:

  ```
  assertion failure: Index out of range (operator[]:line 858) index = 0, max = 0
  ```

- The faulting stack is entirely RealityKit (`CoreRE`):
  - `PhysicsSystem::update`
  - → `PhysicsSystem::ecsToSim`
  - → `PhysicsSubsystemImpl<PhysicsSimulationComponent, …>::ecsToSim`
  - → `_os_crash_msg` → `abort_with_payload`
- It is driven by RealityKit's `DisplayLinkClock`.
- No SyFive or SyLib frame appears beyond `SyFiveApp.$main()`.
- So RealityKit's per-frame copy of the scene's physics bodies into its simulation read element 0 of an empty array.
- The `.ips` crash reports do not carry the message. It appears only in the app's stdout, which the test result bundle keeps under `StandardOutputAndStandardError-com.syzygysoftwerksllc.SyFive.txt`.

### 11.2 Evidence

| Item | Value |
|---|---|
| Crash reports | `~/Library/Logs/DiagnosticReports/SyFive-2026-10-10-112107.ips` (11:21, during `16` §4.3, before any `17` work) and `SyFive-2026-10-10-152141.ips` (15:21, during `17` §4.6). Both have the same stack |
| Deliberate reproduction, iOS 18.6 | `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6' -only-testing:SyFiveUITests/SyFiveUITests/testLaunchPerformance -test-iterations 8`: **1 assertion in 48 app launches**. The message is identical, at 15:25:20 |
| Same loop, iOS 27.0 | `…name=iPhone 17,OS=27.0…`: **0 in 48** |
| Not caused by the 1.1.0 work | First seen before any `17` change. The SyFive code changed today does not run in the dice scene's setup |
| Not the environmental crashes | The other launch crashes of 10 October (an accessibility SIGSEGV and a Security SIGTRAP) came with about 70 crashes of the simulator's own daemons (`maild`, `TypeToSiriWidgetExtension`, `UsageTrackingAgent`, `biomed`, `healthd`). They stopped after Xcode restarted (§10). This one keeps its message and its stack, and it reproduced on a healthy simulator |

### 11.3 Not known

- **Whether it happens on devices.** It has only been seen on the simulator, and RealityKit's simulator path differs from hardware. If it does happen on devices, it would hit about 1 launch in 50 on iOS 18.
- **Whether iOS 18.6 is the trigger.** 1 in 48 against 0 in 48 suggests it but does not establish it.
- **The root cause.** One lead, read from source and not confirmed:
  - `DiceRoller.setup(in:palette:)` (`sylib-swift/Sources/SyLibDice/Simulation/DiceRoller.swift`, the `guard diceEntities.isEmpty` at line 224) adds the five dice to the `RealityViewCameraContent` only on its first call.
  - If `DiceRKView`'s `RealityView` make closure runs again (`DiceRKView.swift` 50-57), `setup` returns early. The dice then stay parented to the old content, and the new scene has none.
  - A physics step over a scene in that state is a plausible way to index an empty body list.
  - The dice are also created with `isEnabled = false` while holding a `PhysicsBodyComponent` (`DiceRoller.swift` 231; `DiceEntity.swift` 125-128). The timing near launch may matter.

### 11.4 Suggested next steps (Pops's call)

1. **Devices first, the cheapest step.** Launch repeatedly on an iOS 18 phone, and watch TestFlight and App Store crash reports for this stack. If it never appears on hardware, record it as a simulator quirk.
2. **Instrument, diagnosis only.** Log each `RealityView` make call and each `setup` call (first or early return), with the content's entity count. Then re-run the 48-launch loop on iOS 18.6. This changes nothing in the physics, but it is still a SyLib edit, so it needs a task.
3. **Write a fix task** once the cause is known. It must say how the fairness certification is kept: `00B` §2; D-037 requires the harness for any physics change.

### 11.5 How to reproduce

```
xcodebuild test -project SyFive.xcodeproj -scheme SyFive \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6' \
  -only-testing:SyFiveUITests/SyFiveUITests/testLaunchPerformance \
  -test-iterations 8 -resultBundlePath /tmp/rk.xcresult
xcrun xcresulttool export diagnostics --path /tmp/rk.xcresult --output-path /tmp/rk_diag
```

Then search `/tmp/rk_diag/**/StandardOutputAndStandardError*.txt` for `assertion failure`. Expect about one hit per run of 8 iterations (48 launches).

