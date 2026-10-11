# SyFive 1.1.0 close-out: fix-ups from the post-implementation review

**Status:** Ready for the agent. Written 11 October 2026.

**Scope:** `SyFive` (§4.1, §4.2, §4.6), `sylib-swift` on branch `syfive-reintegration` (§4.2, §4.3, §4.4),
and `00_DECISION_LEDGER.md` (§4.5). These ship in 1.1.0, before archive.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document, and `17_SYLIB_REINTEGRATION_ADOPTIONS.md` for reference.

**Written from:** the SyFive and SyLib trees as uploaded on 10 October 2026, after `15` to `17` and
Pops's own changes; the §10 logs of `15` to `17`; `17` §11; and a separate source review of every
change against `16` and `17`. That review found the implementation matches both specs, with the
exceptions below.

---

## Supersessions

| Overrides | With | Why |
|---|---|---|
| `17` §4.6 step 2: "In the existing `.task`, after `director.warmUp()`: `await commentaryVoices.refresh()`" | The voice scan runs in a `.task` of its own (§4.1) | Spec error, found in review. Behind the App Store check, which can wait up to 8 s, the scan delays the saved voice. Until the scan lands, `voiceInUse` is nil and the engine speaks in the system voice |
| `17` §2.10, §4.9 step 4, the §8 invariant ("never covers the roll controls"), and A11 ("the status row keeps its own text") | The toast hangs from the Roll button and draws over the status row, including the stuck-dice warning and the proxy controls, for its two seconds | Pops's direction, 10 October 2026, already in D-141. Confirmed acceptable by Pops, 11 October 2026 |
| `17` §10, "Open findings closed: traps on repeated ids" | **Partly closed.** `hydrate` now keeps duplicate participant rows, which then reach five dictionary initialisers that still trap. §4.2 closes the rest | Found in review |
| `17` §11.4, "Suggested next steps (Pops's call)" | **Devices first, no code** (D-144). 1.1.0 is not held for it | Pops, 11 October 2026 |
| `16` §2.1 and `00B` §2: SyLib changes "keep every default" | Applies to `Toast`'s `.overBottom` default, which drifted slightly. §4.3 restores it | Found in review |

---

## 1. What this does

| § | Fix | Where | Check |
|---|---|---|---|
| 4.1 | The voice scan runs in its own `.task` | SyFive | C1 |
| 4.2 | No dictionary traps on a duplicate participant id | SyFive + SyLib | C2 |
| 4.3 | `Toast` `.overBottom` geometry restored exactly | SyLib | C3 |
| 4.4 | SyLib's "SyFive adoption" lines say what SyFive now does | SyLib docs | — |
| 4.5 | Ledger: D-GNP-022 to D-GNP-036 reconstructed; D-144 | Ledger | — |
| 4.6 | Logging for the lost-restart-button / lost-save report (diagnosis only) | SyFive | C4 |

The order follows `00A` §2: the one player-facing regression comes first.

---

## 2. Locked decisions

**2.1 The voice scan never waits on the network.** It runs in its own `.task`, started when
`ContentView` appears. *Rationale:* §Supersessions row 1.

**2.2 A duplicate participant id never traps.** Every by-id dictionary over a match's participants
keeps the first row and drops the rest, matching what `hydrate` and `MatchController` already do
(`17` §10). Rows that share an id are still not resolved. *Rationale:* `16` §11; a sync conflict
can leave such rows, and a trap at that point crashes History.

**2.3 A SyLib default stays byte-for-byte what it was.** `Toast` with no `placement` lays out and
animates exactly as it did before `ToastPlacement` was added. *Rationale:* Syderal's `GameHUD`
toast uses the default, and Syderal is not edited from SyFive's sessions (`00B` §5.4).

**2.4 The RealityKit launch assertion is held for device evidence** (D-144). The first step is
Pops's: repeated launches on an iOS 18 device, and watching TestFlight and App Store crash reports
for its stack (`17` §11.1). No SyLib dice code changes until that shows it on hardware. If it does,
a diagnosis task comes first (`17` §11.4 step 2), then a fix task that says how the fairness
certification is kept (`00B` §2, D-037). *Rationale:* 1 in 48 launches on the iOS 18.6 simulator,
0 in 48 on iOS 27, never seen on a device, and the code sits next to the certified physics.

**2.5 Reconstructed ledger rows are marked as such.** A D-GNP ruling recovered from a code comment
is ledgered with that comment's meaning and the tag *(reconstructed from code, 11 Oct 2026)*. It
holds until Pops confirms or rewrites it. IDs that no code or doc cites are ledgered as unknown,
never invented. *Rationale:* Pops's ruling, 11 October 2026; `00A` §6, cite or say not known.

---

## 3. Before starting

- `17` is complete except for its device checks, as its §10 records.
- The SyLib working tree on `syfive-reintegration` holds `16`'s and `17`'s uncommitted changes.
  Leave them in place (`00A` §9).

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 SyFive: the voice scan runs in its own `.task`

**File:** `Views/ContentView.swift`, the `.task` at lines 237-241.

Remove `await commentaryVoices.refresh()` from that `.task`, and add a second `.task` directly
after it:

```swift
.task {
    // Never behind the App Store check: until the scan lands, voiceInUse is nil and
    // commentary speaks in the system voice (18 §4.1).
    await commentaryVoices.refresh()
}
```

The first `.task` keeps `await updateState.check()` and `await director.warmUp()` in that order.

**Done when:** the two `.task`s are as above; `BuildProject` is clean; the suite passes on the
pinned destination.

**Check:** C1 (Pops, on device).

### 4.2 No dictionary traps on a duplicate participant id

**SyFive.** At each of these four sites, `Dictionary(uniqueKeysWithValues: …)` becomes
`Dictionary(…, uniquingKeysWith: { first, _ in first })`, with the same key-value pairs:

| File | Line | Map |
|---|---|---|
| `Views/Stats/MatchDetailView.swift` | 45 | participants by id |
| `Views/Stats/MatchDetailView.swift` | 51 | participants by id |
| `Views/Stats/UnfinishedMatchDetailView.swift` | 41 | participant id → display name |
| `Views/Stats/UnfinishedMatchDetailView.swift` | 45 | participants by id |

**SyLib.** `Sources/SyLibYatzy/Stats/MatchProgression.swift` line 108: the `currentTotals` seed
becomes `Dictionary(participantProgressions.map { ($0.participantID, Decimal(0)) },
uniquingKeysWith: { first, _ in first })`.

**Test (SyLib)**, in `Tests/SyLibTests/SyLibYatzy/StatsTests.swift`, named after the rule:
`matchProgression_toleratesDuplicateParticipantIDs`. Build a completed match with timestamped
entries in which two participants share one id. Expect a non-nil progression and no trap.

**Also:** append one row to `17` §10's results log, "Traps on repeated ids: the remaining five
sites closed by `18` §4.2", with the counts below. `17`'s other text is not edited (D-001).

**Done when:**
- No `uniqueKeysWithValues` remains over a match's participants, in SyFive or in SyLib's
  `MatchProgression.swift`.
- The new test passes.
- SyLib's suite passes (`00B` §5.3), and its total is the previous 1130 plus 1.
- Syderal builds and passes (`00B` §5.4).
- SyFive's suite passes.

**Check:** C2.

### 4.3 SyLib: `Toast`'s `.overBottom` geometry restored exactly

**File:** `Sources/SyLibUI/Components/Toast.swift`.

Before `ToastPlacement` was added, `bottomPadding` was applied inside the moving capsule (on the
`HStack`, after `.padding(.horizontal, 16)` and before `.allowsHitTesting(false)`). Since the
change, `.overBottom` applies it outside the stage (line 88). The capsule rests in the same
place, but its rise-in travel is shorter by `bottomPadding`.

- Give `stage` the padding for `.overBottom` only: `.padding(.bottom, placement == .overBottom ?
  bottomPadding : 0)`, at the position the original code had it.
- In `body`'s `.overBottom` case, remove `.padding(.bottom, bottomPadding)` from `stage`.
- The `.belowBottom` case is unchanged, including its `.clipped()`.

After the edit, the default path's modifier chain on the capsule matches the code as it stood at
`1e2729fd`, quoted here so that no session needs `git`:

```swift
.shadow(color: .black.opacity(0.3), radius: 8, y: 2)
.padding(.horizontal, 16)
.padding(.bottom, bottomPadding)
.allowsHitTesting(false)
.transition(.move(edge: .bottom).combined(with: .opacity))
.id(toast.id)
```

Before this change the overlay held the `ZStack` directly, with no padding outside it. Report the
new chain beside this one in the session summary.

**Done when:** the default path matches as described; `aToastMovesForItsPlacement` and every other
test pass; SyLib's total is unchanged from §4.2's; Syderal builds and passes; SyFive's suite passes.

**Check:** C3 (Pops).

### 4.4 SyLib docs: "SyFive adoption" lines say what SyFive now does

Each line below describes an API SyFive adopted in 1.1.0 as still optional, or describes SyFive's
old code. Rewrite each one to say SyFive has adopted it, citing the task. For example: "SyFive
adoption: adopted in SyFive 1.1.0 (`17` §4.3)." Nothing else in these files changes.

| File | Line | API | Adopted in |
|---|---|---|---|
| `Docs/GAME_NIGHT_MATCH.md` | 95 | `routeMatchMessage` | `17` §4.3 |
| `Docs/GAME_NIGHT_MATCH.md` | 255 | `abandonSessionNotifyingGuests` | `17` §4.1 |
| `Docs/GAME_NIGHT_MATCH.md` | 376 | `restoreRejoiningGuest`, `prepareForGuestReconnect` | `17` §4.3 |
| `Docs/GAME_NIGHT_MATCH.md` | 500 | `GNHistoryStore` | `17` §4.4 |
| `Docs/GAME_NIGHT_ADOPTION.md` | 476 | ending as host | `17` §4.1 |
| `Docs/GAME_NIGHT_ADOPTION.md` | 755 | `GNHistoryStore` | `17` §4.4 |
| `Docs/Commentary.md` | 397 | `CommentaryShuffleStore` | `17` §4.6 |
| `Docs/Commentary.md` | 774 | `CommentaryVoices` | `17` §4.6 |
| `Docs/UI_COMPONENTS.md` | 225 | `MoreMenu` | `17` §4.7 |
| `Docs/UI_COMPONENTS.md` | 387 | `Toast` placement | Replace with: "SyFive adoption: the commentary on/off toast hangs from the Roll button, `placement: .belowBottom`, `bottomPadding: 4`, over the status row (`17` §4.9; placement by Pops, 10 Oct 2026; D-141)." |

Then search all of SyLib's `Docs/` for other "SyFive adoption" lines that name `AppUpdateState`,
`GameNightMenuSection`, `GameNightLeadingControlButton`, `GameNightEntryState`,
`upsertGameNightRoster` or `GameNightLogBuffer`'s categories. **Report** each one with file and
line, and do not edit it. Pops rules on those in review.

**Done when:** the ten lines are rewritten; the search result is reported; no other doc text has
changed.

### 4.5 Ledger: D-GNP-022 to D-GNP-036, and D-144

**File:** `Docs/Requirements/00_DECISION_LEDGER.md`.

1. Under **Game Night proximity**, after D-GNP-021, append these rows exactly. Each is
   reconstructed from the code comments cited (§2.5). IDs 023, 026 and 029 are cited nowhere in
   either tree.

| ID | Current ruling | Source → chain |
|---|---|---|
| D-GNP-022 | The host's election (`onDecisionsElected`) carries an explicit decision for every registered participant. *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 82 |
| D-GNP-023 | *Not known.* No code or doc in either tree cites this ID. | — |
| D-GNP-024 | Ranging begins at seat claiming when `commentaryEnabled` is true (extends D-GNP-010). *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 153 |
| D-GNP-025 | `begin` needs a non-nil `localSharePlayID`; a caller without one defers. It is called from three places (session activation, the first `tableState`, seat claiming), so the first moment the id exists wins. It is idempotent once begun. *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 155; `GameNightController.swift` 49, 194, 239 |
| D-GNP-026 | *Not known.* No code or doc in either tree cites this ID. | — |
| D-GNP-027 | Presence is re-announced every 3 s until the resolution window opens. Directed tokens retry per peer, and each peer's retry is cancelled once a reading from it arrives. *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 104-106 |
| D-GNP-028 | A non-UWB device announces that it cannot range (`ProximityTokenPayload.supportsRanging == false`), and the host leaves it out of `expectedPairs` so the remaining pairs can still resolve early. The field defaults to `true` for older builds. *(reconstructed from code, 11 Oct 2026)* | `GameNightPayloads.swift` 141-155; `GameNightProximity.swift` 88, 111; `GameNightSession.swift` 118 |
| D-GNP-029 | *Not known.* No code or doc in either tree cites this ID. | — |
| D-GNP-030 | The proximity callbacks are wired once for the controller's lifetime and never cleared at teardown. Clearing them left every session after the first sending nothing ("nine presence announcements, zero transmissions"). *(reconstructed from code, 11 Oct 2026)* | `GameNightController.swift` 510; `GameNightProximity.swift` 179 |
| D-GNP-031 | The host runs the same match-start path as its guests (`lockSeatMap`, `openResolutionWindow`, through `onMatchStarted`). Without it the host arms no arbitration deadline and broadcasts no verdict. *(reconstructed from code, 11 Oct 2026)* | `GameNightMatchCoordinator.swift` 225-228 |
| D-GNP-032 | Presence retry interval 3 s, at most 10 attempts (30 s in all). *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 44-47 |
| D-GNP-033 | The presence retry checks NISession coverage against rangeable peers only (`allSharePlayIDsProvider`), leaving out this device and incapable peers. *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 114; `GameNightController.swift` 136 |
| D-GNP-034 | A peer's presence is answered once (`answeredPresencePeers`), so repeated broadcasts produce no duplicate announcements. *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 122 |
| D-GNP-035 | The presence retry stops when the phase moves past `.settingTable` (`phaseProvider`), not only on task cancellation, and logs a searchable line when it does. *(reconstructed from code, 11 Oct 2026)* | `GameNightProximity.swift` 118; `GameNightController.swift` 141 |
| D-GNP-036 | The `begin` call at session activation is effectively host-only. Guests have no `commentaryEnabled` until the host's `tableState` arrives, so their effective call site is the `tableState` handler. *(reconstructed from code, 11 Oct 2026)* | `ContentView.swift` 296-299 |

2. Under **Platform & data**, append D-144 from §9.
3. Re-point any line number above that has moved, by the declaration named, and report it.

**Done when:** the rows are present as given; no other ledger row has changed.

### 4.6 SyFive: logging for the lost restart button and the lost save (diagnosis only)

**Why.** Pops saw this on device on 10 October 2026 and could not reproduce it. He finished a solo
game, then tapped Play Again. In game 2, after scoring several categories, the restart button was
missing. Killing and relaunching the app lost game 2. Game 1 was in History. A later attempt from a
fresh launch behaved correctly. No Game Night session or call was involved. The restart button and
`saveMatch()` share one gate, `model.hasGameActivity` (`Session/MatchController.swift` 101). Reading the
code found no path that makes both fail while scores show. These were ruled out: both Play Again paths
(each keeps the finished game, then resets scores and the persisted id); the solo-only branches
(`soloFinished` and the lead-change check); the two launch repairs; and Game Night state. It
is probably as old as 1.0. This task adds logging so that the next occurrence says which of two
things happened: the gate read false, or `ContentView` stopped reacting to score changes.

**Behaviour must not change.** Every edit below only adds log lines, or replaces `try?` with an
equivalent `do`/`catch` that logs. Use `ContentView`'s existing `logger` (category
`"ContentView"`). Every line below is `.info` or above, so it shows in Console on a TestFlight or
App Store build.

1. **`saveMatch()`** (`Views/ContentView+Persistence.swift`, from line 142):
   - Before each of its three early returns, log one line naming the guard that returned:
     `"saveMatch: skipped — no score yet"`, `"saveMatch: skipped — no players"`, and
     `"saveMatch: skipped — no Yatzy GameModel"`.
   - Replace `try? modelContext.save()` with `do { try modelContext.save() } catch {
     logger.error(self, "saveMatch: save failed: \(error)") }`.
   - After a successful save, log `"saveMatch: saved matchID=<persistedMatchID> players=<n>
     scored=<categories filled, summed over players> over=<isGameOver>"`.
2. **The leading toolbar button** (`Views/ContentView+GameNight.swift`, `leadingNavButton`, lines
   20-58):
   - Add `enum LeadingNavSlot: Equatable { case gameNight, hostRematch, newGame, playAgain, empty }`
     in the same file, and a computed `var leadingNavSlot: LeadingNavSlot` that holds the
     `if`/`else if` conditions now in `leadingNavButton`, in the same order.
   - Rewrite `leadingNavButton` as a `switch leadingNavSlot`, so the conditions exist in one place.
     Each case draws exactly what that branch draws today. For `.gameNight`, read
     `gameNightEntry.leadingControl` inside the case.
   - In `ContentView.swift`, beside the other `.onChange` modifiers, add
     `.onChange(of: leadingNavSlot) { old, new in logger.info(self, "leading slot: \(old) → \(new) hasGameActivity=\(model.hasGameActivity) over=\(model.isGameOver) players=\(model.playerCount)") }`.
3. **Score changes reaching `ContentView`.** In the existing `.onChange(of: model.playerScores)`
   (`ContentView.swift` 391), log `"playerScores changed: scored=<categories filled> hasGameActivity=<…>"`
   before calling `saveMatch()`.
4. **Play Again.** Add a helper on `ContentView`, `func logModelState(_ label: String)`. It logs one
   line: the label, `playerCount`, `hasGameActivity`, `isGameOver`, `persistedMatchID`,
   `isGameNight`, and `gameNight.isSessionActive`. Call it twice, before `abandonMatch` and after
   `resetGame()`, in both Play Again paths: the Roll button's `onPlayAgain` (`ContentView+Layout.swift`
   26-35, local branch) and the toolbar `+` (`ContentView+GameNight.swift` 50-57). Labels:
   `"playAgain(roll) before"`, `"playAgain(roll) after"`, `"playAgain(toolbar) before"`,
   `"playAgain(toolbar) after"`.
5. **At launch**, at the end of `loadMatchIfNeeded()`'s in-progress branch and its completed branch,
   call `logModelState("launch: resumed in-progress")` or `logModelState("launch: pre-populated from
   last completed")`. This shows whether a saved game 2 existed.

**Done when:**
- The five edits are in place, and `leadingNavButton` draws exactly what it drew before, state for
  state (`17` §6.1).
- `BuildProject` is clean with 0 warnings, and the suite passes on the pinned destination.
- The session summary quotes each new log string.

**Check:** C4.

**How Pops reads it if it happens again:** with the phone connected, open Console.app, select the
device, and filter on `SyFive` with category `ContentView`. Reproduce, then save the log around
the Play Again tap and the next few scores. The deciding lines are:
- `leading slot` stays `empty` while `playerScores changed` reports scores: the gate.
- No `playerScores changed` lines at all: `ContentView` stopped reacting.
- `saveMatch: save failed`: the store.

---

## 5. Validation

| ID | After | Check | Expect |
|---|---|---|---|
| C1 | 4.1 | **Pops, device.** Save a voice. Turn on Airplane Mode, force-quit, launch, and start a game with commentary on at Play-by-Play | The first line is in the saved voice |
| C2 | 4.2 | Unit: §4.2's SyLib test. Plus a read of the four SyFive sites | Pass; all four use `uniquingKeysWith` |
| C4 | 4.6 | **Pops, device, Debug build.** Solo game: score twice, finish, tap Play Again, score twice in game 2, open the menu and close it | Console shows the `playAgain(...)` before/after pair, `playerScores changed` and `saveMatch: saved` for each score, and `leading slot` moving `empty → newGame` at game 2's first score. Then the restart button behaves exactly as before |
| C3 | 4.3 | **Pops, device.** Syderal, current build against this SyLib: turn commentary off in its HUD. SyFive: tap the commentary button | Syderal's toast rises from its usual distance, as before 10 Oct. SyFive's toast hangs from the Roll button, unchanged |

**Then the 1.1.0 release gate, unchanged from `17` §6:** the full device regression of R1 to R22,
F1 to F6 and A1 to A11, with C1 and C3. Results go in `17` §10's rows, which are still open. Also
the RealityKit device check of §2.4: launch repeatedly on an iOS 18 device if one is to hand.
Record the count and any crash in §10. A crash there reopens D-144, and is not a release blocker
by itself; Pops rules.

---

## 6. Not touched

SyLib dice code (D-144). Syderal's source, including its two stale comments (`16` §10). Every design
doc from `01` to `17`, except the one row appended to `17` §10 in §4.2.

---

## 7. Open decisions

None. `17` §11's RealityKit question is decided for 1.1.0 by D-144.

---

## 8. Invariants quick reference

- Nothing at launch that speaks waits on the network. (§2.1)
- Diagnostic logging never changes behaviour. (§4.6)
- No `uniqueKeysWithValues` over participant ids. (§2.2)
- A SyLib default is byte-for-byte unchanged by an additive parameter. (§2.3)
- No SyLib dice edit without a named task. (D-144, `00B` §2)
- A reconstructed ruling says so, and an unknown one is not invented. (§2.5)

---

## 9. Ledger rows

D-GNP-022 to D-GNP-036 are in §4.5.

**Platform & data**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-144 | **The RealityKit launch assertion (`17` §11) is held for device evidence.** No SyLib dice change until it appears on hardware. Then a diagnosis task comes first, and a fix task must state how the fairness certification is kept (D-037). 1.1.0 is not held for it. | `17` §11 → `18` §2.4 (Pops, 11 Oct 2026) |

---

## 10. Results log

| Item | Value |
|---|---|
| §4.1 | **Done 11 Oct 2026.** `ContentView.swift`: the first `.task` keeps `await updateState.check()` then `await director.warmUp()`; a second `.task` directly after it runs `await commentaryVoices.refresh()`, with the given comment. BuildProject clean, 0 warnings; SyFive suite on the pinned destination: see row below |
| §4.2 | **Done 11 Oct 2026.** The four SyFive sites (`MatchDetailView.swift` 45, 51; `UnfinishedMatchDetailView.swift` 41, 45) and SyLib `MatchProgression.swift` 108 use `uniquingKeysWith: { first, _ in first }`. No `uniqueKeysWithValues` remains in SyFive or `MatchProgression.swift`. Test `matchProgression_toleratesDuplicateParticipantIDs` added and passing. Row appended to `17` §10 |
| §4.3 | **Done 11 Oct 2026.** `Toast.swift`: `stage` applies `.padding(.bottom, placement == .overBottom ? bottomPadding : 0)` after `.padding(.horizontal, 16)` and before `.allowsHitTesting(false)`, where the original had it. The `.overBottom` overlay holds `stage` directly, with no padding outside it. `.belowBottom` is unchanged, `.clipped()` included. The default capsule chain is now `.shadow` → `.padding(.horizontal, 16)` → `.padding(.bottom, bottomPadding)` → `.allowsHitTesting(false)` → `.transition(.move(edge: .bottom)…)` (`transitionEdge` is `.bottom` for `.overBottom`) → `.id`, matching `1e2729fd` |
| §4.4 | **Done 11 Oct 2026.** All ten lines are rewritten, each paragraph replaced whole:
- `GAME_NIGHT_MATCH.md` 95, 255, 376, 500
- `GAME_NIGHT_ADOPTION.md` 476, 755 (multi-line paragraphs)
- `Commentary.md` 397, 774
- `UI_COMPONENTS.md` 225, 387

Each reads "SyFive adoption: adopted in SyFive 1.1.0 (`17` §4.n).", except UI_COMPONENTS 387, which carries the given Toast text. UI_COMPONENTS keeps its italics on both lines. No other doc text changed |
| §4.5 | **Done 11 Oct 2026.** Ledger: D-GNP-022 to D-GNP-036 appended under Game Night proximity, after D-GNP-021, as given. 023, 026 and 029 are "Not known"; the rest are tagged *(reconstructed from code, 11 Oct 2026)*. D-144 appended under Platform & data, after D-139. Script check: 16 lines added, 0 existing lines changed, no duplicate IDs. **Line check:** every cited line was located by its `D-GNP-0xx` comment. All match except **D-GNP-036**: `ContentView.swift` 296-299 is now **300-303**, moved by `18` §4.1's added `.task`, and the ledger row cites 300-303. Other citations of the same IDs exist that the rows do not list (e.g. D-GNP-022 also at `GameNightProximity.swift` 419; D-GNP-030 also at 329, 529, 618). They were left as given |
| §4.6 | **Done 11 Oct 2026.** Logging only. Five edits:
- `saveMatch()`: a log line before each guard return, `do`/`catch` around the save, and a saved line.
- `LeadingNavSlot` + `leadingNavSlot`, and `leadingNavButton` as a `switch` on it, with the conditions in their original order.
- `.onChange(of: leadingNavSlot)`.
- A `playerScores changed` line before `saveMatch()`.
- `logModelState(_:)` in both Play Again paths and both `loadMatchIfNeeded()` branches.

BuildProject clean, 0 warnings; SyFive 19/19 |
| SyLib test total after §4.2 and after §4.3 | After §4.2: **1131 in 119 suites, passed** (1130 + 1), 0 warnings. After §4.3: **1131, passed** (unchanged), `aToastMovesForItsPlacement` included, 0 warnings |
| Syderal build and test counts | After §4.2: builds, no source edit; **897 total, 893 passed, 4 skipped, 0 failed**; 0 warnings. After §4.3: the same |
| SyFive suite | After §4.1: **19/19 passed** on `iPhone SE (3rd generation), OS=18.6`, 0 warnings, 11 Oct 2026. After §4.2: 19/19. After §4.3: 19/19. After §4.6: 19/19 |
| §4.4 search report | Every "SyFive adoption" line in SyLib `Docs/` was read with its section heading. **Names one of the six APIs:**
- `GAME_NIGHT.md:551` (Logging): "SyFive configures the buffer with its own categories, `packageCategories` and `FeelAudioEngine` (`16` §4.1)." Already accurate; written by `16` §4.1.

**No adoption line exists** for `AppUpdateState`, `GameNightMenuSection`, `GameNightLeadingControlButton`, `GameNightEntryState` or `upsertGameNightRoster`.

**Also stale, outside the search list, not edited:**
- `Commentary.md:361` (Keeping the shuffle between launches) ends "SyFive adoption: optional; nothing changes unless it calls them." SyFive adopted the shuffle save/restore in `17` §4.6. |
| C1 to C4 | |
| Restart-button / lost-save report (§4.6), if reproduced: date, steps, log excerpt | |
| RealityKit device check: device, iOS version, launches, crashes | |
