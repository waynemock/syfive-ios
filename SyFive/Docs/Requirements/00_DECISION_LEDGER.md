# SyFive / SyLib — Decision Ledger

*The single mutable document in the corpus. One row per locked design decision, always
showing the **current** ruling. The numbered design docs are immutable history; this
file is HEAD.*

---

## How this file works

- **Design docs are never edited after delivery.** When a newer doc changes a prior
  ruling, it carries a **Supersessions** section quoting what it overrides, and the
  affected row *here* is updated to the new ruling with the chain extended
  (e.g. `02 §9 → 05 §1`).
- **Rows are append-only; IDs are permanent.** Never renumber, never delete. A dead
  decision's row is rewritten to the current ruling — the old ruling survives in the
  source docs, which is where design progression lives.
- **Precedence:** newest ruling wins. Where doc numbering is ambiguous (two docs share
  `03`), the chain in this ledger is authoritative for ordering.
- **Scope guard:** design decisions only. Implementation status lives in the code and
  the status docs — never here.
- **Operational rule:** this file ships in **every** Xcode-agent prompt, alongside
  whichever design docs the task needs. It exists so an agent holding one older doc in
  isolation cannot enforce a dead rule.
- `(rec.)` marks a ruling that entered as Claude's recommendation and was accepted
  rather than explicitly directed — same force, noted for the record per house practice.
- `00A` (studio, canonical) and `00B` (SyFive) ship with this file in every agent prompt.

---

## Governance

| ID | Current ruling | Source → chain |
|---|---|---|
| D-001 | **SyFive exception to `00A` §1: documents are immutable once delivered.** Overrides travel through a Supersessions block in the newer document, plus a rewrite of the affected row here. This ledger is HEAD and accompanies every agent prompt, with `00A` and `00B`. | Session 05 · `05 §1` → `00B` E-1 (exception kept by Pops, 10 Oct 2026) |
| D-142 | **`00A_STUDIO_CONVENTIONS.md` is canonical for how sessions run, and `00B_SYFIVE_GUARDRAILS.md` holds SyFive's own rails.** Project documents cite them rather than restate them. Where `00A` and a SyFive rule conflicted on folders and on fixing out-of-scope smells, `00A` won. | `00A` §11 → `00B` §7 |
| D-143 | **Tests run at the deployment floor**: iPhone SE (3rd generation), iOS 18.6, pinned in `00B` §5. Both test targets are set to iOS 18.6. | `00A` §7 → `00B` §5 |
| D-148 | **`14_APPSTORE_COPY.md` is a living store record**, edited in place with a version and changelog (§10). It is an exception to D-001, which keeps every other SyFive design document immutable. | `14_APPSTORE_COPY.md` §9 (Pops, 11 Oct 2026) |

## Platform & data

| ID | Current ruling | Source → chain |
|---|---|---|
| D-128 | **1.1.0 brings SyFive onto the post-Syderal SyLib in three phases**: build and baseline (`15`), fixes (`16`), adoptions (`17`). The Syderal-style reshape (a bridge type for `GameNightMatchHost`, import boundaries, `nonisolated` default isolation) is **deferred to a later release, not rejected**. | `15 §1` *(rec.)* |
| D-129 | **SyFive's store and catalogue seed never move into SyLib.** The container in `SyFiveApp.swift` and `seedYatzyGameIfNeeded()` stay SyFive's. `makeScoringContainer`, `makeInMemoryScoringContainer` and `seedCatalogGame` are never adopted. | `14 §3.12` (Syderal L-17) → `15 §2.4` |
| D-131 | **Wire versions frozen for 1.1.0:** `appProtocolVersion` stays 1 and the transport stays 3, so 1.0.3 and 1.1.0 share a table. Raise either only with a doc that plans the split. | `14 §1.4` → `15 §2.3` |
| D-139 | **The update badge** comes from SyLibCore's `AppUpdateState` and SyLibUI's `MoreMenu`. It clears when Update Available is tapped, and the acknowledgement is stored per store version. Never acknowledge on menu open: SwiftUI's `Menu` has no reliable signal for it. | `14 §3.11, §4.5` (Syderal Q-32, Q-33) → `17 §2.8` *(rec.)* |
| D-154 | **The update check re-runs on each return to the foreground.** SyLibCore's `AppUpdateState` observes the app becoming active and re-checks by itself, once the app has called `check()`; SyFive keeps its one launch `check()` and has no foreground code of its own. `AppUpdateChecker` reuses a successful lookup for **15 minutes** (was 24 hours), **never caches a failed one**, and concurrent calls share one request. Other apps adopt in their own sessions. | `25` §2 (Pops, 28 Oct 2026: SyLib mechanism; 1 hour, then 15 minutes; failures not cached; the rest *(rec.)*) |
| D-144 | **The RealityKit launch assertion (`17` §11) is held for device evidence.** No SyLib dice change until it appears on hardware. Then a diagnosis task comes first, and a fix task must state how the fairness certification is kept (D-037). 1.1.0 is not held for it. | `17` §11 → `18` §2.4 (Pops, 11 Oct 2026) |
| D-145 | **The How to Play "Got it" button is SyLibUI's `HelpDismissButton`**: a `CapsuleButton` in the `.accent` style, centred, the same in every app, saying "Got it, hide this", then the alert "Hide the help button?" with the message "How to Play stays in the Menu, in the last section with About. You can open it any time." The How to Play pages stay app-owned. SyFive adopts it in 1.1.0; Syderal in its `24`. | `19` §2 (Pops, 11 Oct 2026; wording *(rec.)*) → Pops, 11 Oct 2026 (single `CapsuleButton` look, centred; the `.link` / `.prominent` styles removed) |
| D-147 | **1.1.0 ships `18` §4.6's diagnostic logging at info level** (Play Again state, score changes, the leading toolbar slot, `saveMatch` outcomes and failures), to catch the lost-restart-button / lost-save report in the field. It is removed once that report is resolved. | `18` §4.6 → `21` §2.2 *(rec.)* |

## Product & rules

| ID | Current ruling | Source → chain |
|---|---|---|
| D-002 | Brand is **SyFive**; the game is called **Yatzy**; standard category vocabulary (Ones–Sixes, Full House, etc.). The brand owns the experience, not the rulebook. | `SyFive.md §2` |
| D-003 | Ruleset is **Classic Hasbro** — Yatzy 50, +100 per extra while the box holds a live 50, joker forced-scoring. *Not* European Yatzy. | `SyFive.md §5` (recommended European ⭐) → superseded by implementation + `02 §4` |
| D-004 | Upper bonus: sum of upper section ≥ **63 → +35**. | implemented · confirmed `02 §4.2` |
| D-005 | **Strict-Hasbro poison rule:** a Yatzy box scratched to 0 disables *both* the +100 bonus *and* joker forced-scoring. `isJokerRoll` gates on `== 50`, not `!= nil`. | `02 §4.3` |
| D-006 | The calm ethos is a **product filter**, not an aesthetic: no ads, no casino noise, no dark patterns, no fake currency. It decides scope, monetization, and features. | `SyFive.md §1, §14` |

## Architecture & layering

| ID | Current ruling | Source → chain |
|---|---|---|
| D-007 | Three-layer architecture (Domain → Persistence → App), dependency arrows downward only. The Foundation-only import rule defines the domain layer and is enforced **per SPM target**, not per package. | `02 §1` → scope refined by `05 §1` |
| D-008 | **SyLib is a multi-target umbrella package.** `SyLibCore` (Foundation-only), `SyLibDice` (RealityKit legal), `SyLibFeel` (AVFoundation + CoreHaptics legal). Apps depend per-target; scoring-only consumers never link RealityKit. | `05 §2` |
| D-009 | The dice engine **ships in SyLib** as `SyLibDice`. The `[Int]` hand-off seam to scoring is retained unchanged. | `02 §5.2/§9` ("App-only, never in the package") → **superseded** `05 §1` |
| D-010 | SwiftData twins carry the `Model` suffix (`PlayerModel`, `MatchModel`…); domain values keep clean names; no `Sy` type prefix anywhere. | `02 §1.2` |
| D-011 | The in-memory engine formerly `GameModel` is **`MatchController`** (App layer, `Session/`). | `02 §5` |
| D-012 | No `ScoringSystem` protocol/registry until a second conformer exists (ScoreIt v2). Yatzy rules stay pure free functions. | `02 §4.5` |
| D-013 | `Theme` never crosses below the App layer. Domain stores `themeID: String`; the dice system takes an injected tint palette, never `Theme`. | `02 §6` → extended `05 §10` |

## Data model & persistence

| ID | Current ruling | Source → chain |
|---|---|---|
| D-014 | `ScoreEntry` shape is **frozen**. `value: Decimal?` — `nil` = unscored, `0` = deliberately scratched. Completeness tests non-nil, never `> 0`. | `02 §2.2` |
| D-015 | `metadata: [String: ScoreValue]?` is typed and **dormant** — `nil` everywhere in SyFive 1.0; activates in ScoreIt v2. | `02 §2.2` |
| D-016 | `yatzyBonus` is a field on `Participant`, not a `ScoreEntry` and not metadata. | `02 §2.7` |
| D-017 | Winner direction is **declared by the scoring system**, never stored. | `02 §2.5` |
| D-018 | `Participant` carries a display snapshot (`displayName/Initials/ThemeID`); rendering never depends on roster refs. `playerID` xor `teamID` enforced in code, not schema. | `02 §2.7` |
| D-019 | `Team` ships as frozen schema, never instantiated in SyFive 1.0. | `02 §2.4` |
| D-020 | **Checkpoint-only persistence**: flush at category-scored and match-completed boundaries. No continuous autosave, no CloudKit conflict handling, no cross-device mid-game continuation. Resume restarts the interrupted turn. | `02 §3.4` |
| D-021 | SyFive stores scorecards as a `Codable` blob on `ParticipantModel`. Blob-vs-rows is a per-app Layer-2 choice; the domain `ScoreEntry` is identical either way. | `02 §3.2` |
| D-022 | Settings live in a synced SwiftData model (`AppSettingsModel`); genuinely device-local debug/UI state may use `UserDefaults`. | `02 §7` · shipped |

## CloudKit

| ID | Current ruling | Source → chain |
|---|---|---|
| D-023 | CloudKit ships at 1.0. Per-app private container `iCloud.com.syzygysoftwerksllc.SyFive` (not a shared "Sy" container), with a one-line revert lever. *(rec.)* | `03_CLOUDKIT` |
| D-024 | The built-in Yatzy catalog entry seeds with the fixed well-known UUID `BFB7F8F6-87D2-4700-9267-36A8ED4AC3C8` for cross-device deduplication. Constant lives in `Domain/Game+BuiltIn.swift` (SyFive extension on `SyLibScoring.Game`) — kept app-side so `SyLibScoring` stays game-agnostic. *(rec.)* | `03_CLOUDKIT` |
| D-025 | `ScoreEntryModel` is **not** registered in the CloudKit schema — scorecards travel inside the participant blob. | `03_CLOUDKIT` |
| D-026 | **Dev → Production schema promotion is a hard gate** before any TestFlight build. | `03_CLOUDKIT` |
| D-027 | Sync UX is calm and silent: no spinners, no toggles, no sync status chrome. | `03_CLOUDKIT` |

## Stats & insights

| ID | Current ruling | Source → chain |
|---|---|---|
| D-028 | Two-tier stats mirroring the scoring split: Tier 1 generic (`SyLibScoring`), Tier 2 Yatzy-specific (`SyLibYatzy` in sylib-swift). `legalValues(for:)` / `isLegalValue(_:for:)` added to `YatzyScoring` for manual-entry validation (ScoreIt v2 consumer). | `03_STATS` → `13_SYLIB_YATZY` |
| D-029 | **Compute-on-read, no stored aggregates.** All stats and insights derivable retroactively with zero schema additions — a hard constraint. | `03_STATS` |
| D-030 | `ScoreEntry.recordedAt` is always written at checkpoint flush; `nil` means legacy data only. | `03_STATS` |
| D-031 | Dice telemetry is excluded from the stats contract. | `03_STATS` |
| D-032 | Elo ratings deferred on ethos grounds; fully retroactively derivable if ever wanted. | `03_STATS` |
| D-033 | Head-to-head displays match-wins as the headline, pairwise-ahead as the second line. | `03_STATS` |
| D-034 | Insights lead with the plain-language archetype sentence; numbers demoted beneath identity. Every player-facing read is neutral-to-affirming. | `04` |
| D-035 | Insights architecture rests on the outcomes-vs-decisions spine, with an explicit honesty constraint where dice data is absent. | `04` |

## Dice system

| ID | Current ruling | Source → chain |
|---|---|---|
| D-036 | Dice are **full RealityKit/PhysX physics** — the simulation never cheats; randomness comes entirely from seeded initial conditions. | `REQUIREMENTS.md` (SpriteKit physics-lite) → superseded by `DICE_IMPLEMENTATION_PLAN` / retrospective |
| D-037 | The fairness harness **must run before shipping any physics change** (collision shape, friction, spawn, impulse, rescue logic, tray geometry). | `DICE_REQUIREMENTS` |
| D-038 | Stuck-die UX: yellow (tap to nudge) → red (tap to reroll). **Never auto-reroll during gameplay** — the player stays in the loop. | `DICE_RETROSPECTIVE` |
| D-039 | The jumping-bean die (a die bouncing off another) is intentionally kept. | `DICE_RETROSPECTIVE` |
| D-149 | **Fairness certifications are kept as a history** in SyLibDice `Docs/FairnessHistory/`: one folder per run (report, CSV, and a `DIFF.md` against the run before, made by `DiceRunComparison` from the harness's Compare button), a folder per pool (its report), and an index. Runs are never edited or deleted. `FairnessCertification.builtIn` carries what is certified, and `Docs/DICE_FAIRNESS_REPORT.txt` is a copy of its report. Run CSVs live only in the history. The report's header names the device, OS build, app version, and what the rolls ran under. A run is added when the OS changes, `DiceRoller.Config` changes, or D-037 requires one. **Only full runs certify** (D-150); windowed runs are history only. **Pool, never pick:** every full run on the same OS, rolled under an unchanged `Config.batch` from the certified app tuning, counts, none is dropped, and the pool is certified. | `22` §2 → `23` §2.3 (Pops, 11–13 Oct 2026) |
| D-150 | **A batch keeps every roll.** From `startBatch(count:)` until Reset, `DiceStatistics` doesn't trim, so a 10,000-roll batch records all 50,000 dice results. Gameplay keeps the 10,000-sample window. Earlier runs, July 2026's certification included, kept about the last 2,161 rolls of each batch. | `22` §2.1 (Pops, 11 Oct 2026) |
| D-151 | **The fairness standard is ±1 percentage point at 99% confidence.** `FairnessCertification.passes` is true when every face's interval, p̂ ± 2.576·√(p̂(1 − p̂)/n), lies within the expected share ± 1 point. Chi² (`chiSquarePasses`), serial r and the runs test are reported as information. Set before the full runs: chi² on large samples flags differences far below anything a player could notice. | `23` §2.2 (Pops, 12 Oct 2026) |
| D-152 | **iOS 27 certification: five full runs pooled**, iPad Pro (M5), iPadOS 27.0.0 (24A437). 250,000 dice results from 50,000 rolls. **PASS**: the largest deviation is 0.175 points, and the intervals span 16.335% to 17.035%. For information: chi² p 0.006, serial r −0.0005, runs Z +1.28. It ships in SyFive 1.1.0. | `23` §2.1 (Pops, 13 Oct 2026) |
| D-153 | **One full run certifies.** A new certification (after an OS or tuning change) needs one full 10,000-roll run that passes D-151. Add runs only if its widest interval comes within 0.25 points of the bar (outside 15.917%–17.417%), or its Compare against the previous certified run flags something. Extra runs are pooled (D-149). Each of the five iOS 27 runs passed on its own. | `23` §2.6 (Pops, 14 Oct 2026) |

## Feel — audio & haptics

| ID | Current ruling | Source → chain |
|---|---|---|
| D-040 | Audio is **math synthesis**: parametric `Codable` recipes rendered offline to PCM buffers at startup, played via `AVAudioEngine`. The recipes are the spec; the agent implements a renderer, never invents a sound. | `05 §3–4` |
| D-041 | Rendered sounds are cached **content-addressed**: SHA-256 over canonical sorted-keys recipe JSON + renderer version + format tag (+ variant selector). `Library/Caches`, CAF / Float32 / 48 kHz mono. Recipe change ⇒ automatic re-render of exactly that sound. | `05 §4` |
| D-042 | Variant jitter is **baked into the spec deterministically** (tables / fixed seeds), never rolled at render time. Every install sounds identical. | `05 §3` |
| D-043 | Sounds form one **tonal family**: D-root, D/A open-fifth register map. Root is a single tunable constant (feel board may move it). | `05 §5` *(rec.)* |
| D-044 | Roll rattle is a **quiet, pre-rendered Poisson grain bed** (deterministic seeds): starts at roll start scaled by unheld count, ducks per settled die, kills with a short fade on all-settled. Collision-driven impact audio deferred to the reserved hooks. | `05 §5.2` · user-locked |
| D-045 | Haptics use **CoreHaptics** (parametric intensity/sharpness patterns). No `UIImpactFeedbackGenerator`, no fallback tier; non-Taptic hardware (iPad) no-ops via capability gate. | `IMPLEMENTATION_STATUS` note → superseded `05 §6` |
| D-046 | **Co-design mapping rule:** haptic sharpness tracks the sound's spectral centroid, haptic intensity tracks its perceived level, both fire from the same director call. | `05 §6` |
| D-047 | Haptics fire only for **direct die touch and state punctuation** — never ambience. The rattle is sound-only; mid-air collisions are silent to the hand. | `05 §6` |
| D-048 | `DiceAudioControlling` keeps its exact current shape — **physics-lifecycle only**. Hold, score, Yatzy, and game-end feel events fire app-side through `FeelDirector`, not through the dice protocol. | `IMPLEMENTATION_STATUS` ("hold hook needs addition") → overruled `05 §7` |
| D-049 | Per-die settle hooks fire from `tick()` at the **first still-and-flat frame**, debounced per landing episode; `onAllDiceSettled` stays in `finishRoll()` and carries the authoritative values. | `05 §8` |
| D-050 | Batch mode is **feel-silent**: all `audioController` calls guarded by `!isBatchRunning`, roller-side. *(rec.)* | `05 §8` |
| D-051 | Audio session is **`.ambient`**: silent switch respected, mixes with the user's audio. Sound and haptics toggles are independent (`AppSettingsModel.soundEnabled` / `.hapticsEnabled`), both default on. | `05 §9` |
| D-052 | **Yatzy-moment predicate** (celebrate at settle, app-side): all five dice equal **and** the Yatzy box is `nil` or holds 50. A poisoned five-of-a-kind gets no celebration. | `05 §7.3` |
| D-053 | The Feel module is extractable from day one: imports **Foundation + AVFoundation + CoreHaptics only**; no Feel↔Dice dependency in either direction; the `DiceAudioControlling` adapter lives app-side. Engine is package material; SyFive's recipe values are app content. | `05 §2` |
| D-117 | **Undo feel: tiny D3 "set-down" tick.** Silent rejected — the tick correctly frames undo as a deliberate mechanical action, not an erasure. | `05 §11` (open → resolved on device) |
| D-118 | **Settle haptic pattern: per-die transients.** Single all-settled pulse rejected — per-die transients preserve the one-die-at-a-time narrative that the settle thunk sounds already establish. | `05 §11` (open → resolved on device) |
| D-119 | **Yatzy haptic: 200 ms continuous swell.** Canonical soft tick rejected — the swell reads as earned and sustained in a way the tick does not; matches the scale of the Yatzy moment. | `05 §11` (open → resolved on device) |

## Game Night

| ID | Current ruling | Source → chain |
|---|---|---|
| D-054 | Transport: **GroupActivities / SharePlay**. MultipeerConnectivity (sessions die seconds after backgrounding) and Game Center (4-player real-time cap, unwanted chrome) rejected. | `06 §0` |
| D-055 | **Host-authoritative, no host migration.** Received host state replaces guest render state unconditionally. No conflict-resolution machinery. | `06 §3.2` |
| D-056 | **Versioned envelope** (`protocolVersion` + `kind` + `payload`). Version gated at `hello` only; unknown `kind` values ignored silently (forward compat within a version). | `06 §4.2` |
| D-057 | **Completion broadcast:** host sends final `Match` value; every guest device upserts by match UUID into its own private store. No CKShare / shared CloudKit zone. | `06 §8` |
| D-058 | **Snapshots on the wire, not deltas.** `matchState` shape = the checkpoint shape. Transient dice state (`diceValues`, `held`, `rollsRemaining`) never in `matchState`. | `06 §4.3` |
| D-059 | **Never stream per-frame transforms.** The theater budget is **one `rollResult` message per roll**, carrying settled faces. `rollBegan` remains on the wire for its held-mask and turn-boundary signalling only. | `06 §2.1` → amended by D-126 |
| D-060 | **No guest render replica.** Guests bind `MatchController` directly; host state arrives via `loadFromGameNightMatch(_:currentSeatIndex:)` and replaces local state wholesale (D-055). The planned `MatchPresenting` / `TableReplica` split was never wired and both files are deleted. Interactive affordances still route by role at the call site. | `06 §10` → superseded by implementation |
| D-061 | GroupActivities imports confined to `App/GameNight/`. **Domain and Persistence layers never learn Game Night exists.** | `06 §10` |
| D-062 | **Roller physics untouched, and the roller is the only simulation.** Spectator devices run no physics for a remote roll; there are no spectator render corrections because there is nothing to correct. Fairness harness unaffected; no re-validation triggered by Game Night work. | `06 §3.1, §6.2` → amended by D-126 |
| D-063 | Only the host checkpoints during play. **Guests write exactly once, at completion**, upserting by match UUID. `02` single-writer invariant preserved. | `06 §3.3` |
| D-064 | **Zero schema change.** Game Night adds no persisted fields, entities, or migrations. `02 §2.7` display snapshots + preserved `playerID`s carry it all. | `06 §0, §14` |
| D-065 | No chat, timers, meters, matchmaking, session chrome. **The FaceTime call (or the room) is the social layer; the app builds none of it.** | `06 §1` |
| D-066 | **Spectator stuck dice: not applicable.** Spectators display settled values and never simulate, so the stuck-die and batch-rescue paths exist on the roller's device only. | `06 §6.2` → superseded by D-126 |
| D-067 | **Dropped-session resume ships in v1.** Host's `inProgress` match resurfaces as resumable; new SharePlay session; guests re-claim seats; interrupted turn restarts. *(rec.)* | `06 §7` (open §13.4 → recommended in; shipped) |
| D-120 | **Game Night undo: scorer-until-next-rollBegan via host.** Scorer's device sends `UndoRequestPayload`; host applies `undoLastScore()` and broadcasts with `diceValues` so scorer can rescore. `clearUndoSnapshot()` closes the window on `rollBegan`. | `06 §13.3` (open → shipped) |
| D-121 | **Guest drop mid-turn: host plays as proxy.** When a guest drops mid-turn, host rolls and scores on their behalf. No auto-scratch; host can play the turn fairly. Returning guest rejoins from current matchState. | `06 §13.2` (open → resolved) |
| D-126 | **Cross-device physics replay abandoned.** Replaying a `DiceRollRecipe` through each spectator's own RealityKit simulation does not converge: PhysX timestep is display-linked, solver iteration and contact ordering are not stable across devices, and float behaviour differs by chip generation. Identical impulses diverge within a few hundred ms, so spectators landed different faces than the roller and had to be corrected on-screen. Spectators now **hide the unheld dice on `rollBegan` and display the settled faces from `rollResult`.** No spectator simulation runs. | `06 §2.1, §6.2` → superseded by implementation |
| D-127 | **Wire rule: send outcomes, never inputs a receiver must re-derive.** `rollResult` (settled faces) is authoritative and sufficient; `rollBegan`'s recipe attempted to save bandwidth by having receivers recompute the outcome, and recomputation is precisely where it broke. Any future cross-device presentation payload carries the resolved result, not the parameters that produce it. Generalised from D-126; binds SyLib consumers, not just SyFive. | implementation · generalised from `06 §2.1` |
| D-134 | **The Game Night log keeps SyLib's lines.** SyFive configures `GameNightLogBuffer` with its own categories (`GameNightController`, `ContentView`, `MatchController`), `packageCategories` and `FeelAudioEngine`. The log stays a Debug-only tool behind `AppConfig.DebugGameNight.showLogs`. | `14 §4.2` → `16 §2.5` *(rec.)* |
| D-135 | **The host ends Game Night with one awaited call**, `abandonSessionNotifyingGuests()`. `matchAbandoned` is sent only by a host that is ending Game Night, never to discard a match and keep the table. | `14 §3.1, §4.1` (Syderal L-14, Q-16) → `17 §2.2` |
| D-136 | **Host reconnect is recorded and consumed by the coordinator.** Record → `beginHosting` with an empty `onReadyToSeat` → `consumePendingHostResume()` at activation. When it returns false the normal seating sheet opens. `onNeedsConversation` and Play Locally clear the recording. | `14 §3.3` (Syderal L-23) → `17 §2.3` |
| D-137 | **Roster upsert never merges two people at one table.** SyFive uses `upsertGameNightRoster` with `seatedPlayerIDs` at both call sites; `remapOntoArchived` stays `true`. | `14 §3.5, §4.2` (Syderal L-39, L-43) → `17 §2.4` |
| D-138 | **History sync shares only completed Game Night matches the table shares**, judged by a match's fullest row, through `GNHistoryStore`. | `14 §3.4` (Syderal L-18, L-40) → `17 §2.5` |
| D-140 | **Game Night menu items and the leading toolbar control are SyLib's** (`GameNightMenuSection`, `GameNightLeadingControlButton`), with SyLib's titles and labels. Play Again stays SyFive's. | `14 §3.10` (Syderal L-22) → `17 §2.9` |

## Celebrations

| ID | Current ruling | Source → chain |
|---|---|---|
| D-068 | **Frequency governs intensity.** Yatzy = repeatable whisper; game-over = earned generous moment once per game. Never equal treatment. | `08 §0` |
| D-069 | **No burst/explosion motion, ever.** Yatzy motes rise; game-over particles slow-fall. No outward blast, no casino grammar, no hard sparkle or casino red. | `08 §0, §10` |
| D-070 | Yatzy celebration: **sparse rising accent motes** (15–30 total, ceiling not target), inserted into existing rim-light / push-in / title-card sequence. Three consecutive Yatzys must feel identical; no escalation or accumulation. Fallback if motes feel like too much: single soft accent-ring pulse. *(rec. motes — see open O-2)* | `08 §2` |
| D-071 | Game-over celebration: **winner-accent slow-fall + scorecard glow/scale + grand-total count-up + theme-gradient wash**, in the winner's `displayThemeID` accent. | `08 §3` |
| D-072 | Celebration colors are **participant-scoped:** current scorer's accent for Yatzy; winner's accent for game-over. Both sourced from `displayThemeID` snapshot. | `08 §2.3, §3.2` |
| D-073 | **Reduce Motion is honoured, and the particles are already its form.** With Reduce Motion on, the Yatzy motes and the game-over slow-fall play unchanged: each `ParticleBurst` passes its factory as both `particles:` and `reducedMotion:`. No flashing in either path. Celebrations are non-blocking and cancel cleanly on early dismissal. The rainbow border and card transitions are not gated (`24` §2.4). | `08 §4` → `24` §2 (Pops, 28 Oct 2026) |
| D-074 | Celebrations are **App-layer SwiftUI overlay only.** Nothing runs inside the RealityKit dice scene. No third-party dependency, no persistence, domain untouched. | `08 §6` |
| D-122 | **Game-over confetti: slow-fall stays.** On-device calibration confirmed slow-fall earns its place as the once-per-game moment. Keep as implemented. | `08 O-3` (open → resolved) |
| D-123 | **Tie celebration: interleaved accents.** Blend and alternate tied winners' accent colors and scorecard glow. No fallback to neutral. | `08 O-4` (open → resolved) |
| D-124 | **Count-up under Reduce Motion: keep animated.** Grand-total count-up is not a particle or flash; it stays animated even when Reduce Motion is on. | `08 O-5` (open → resolved) |
| D-125 | **Game-over audio companion: already shipped.** `game_end` sound (falling D5→A4→D4) + two-transient haptic fire via `FeelDirector.gameEnded()` on the scoring tap that ends the game. No additional work. | `08 O-6` (open → resolved; pre-existing) |

## Commentary

| ID | Current ruling | Source → chain |
|---|---|---|
| D-075 | **Off by default**; no engine instantiated when off. **Adding a personality = adding one data file** (`lines` dict + prosody row + blurb + preview line); no engine code per pack. | `09 §0, §1` |
| D-076 | Three-tier level: **Celebrations / Highlights / Play-by-Play.** Off is expressed by the master toggle, not a fourth level position. | `09 §2` |
| D-077 | **No immediate repeat, and a shuffle-bag.** Each event kind draws from a shuffled deck of its lines, and a refilled deck never starts with the last line used. The deck is saved per personality across launches (`CommentaryShuffleStore`, key `com.syzygysoftwerksllc.syfive.commentaryShuffle`, never changed). | `09 §1.4` → `17 §2.7` *(rec.)* |
| D-078 | **Higher-tier events interrupt; same-or-lower-tier events drop; never a backlog.** As SyLib's `.dropWhileSpeaking` runs it, lines come in bursts: a burst opens when a line becomes the first in flight and stays open until that line is reported started. While it is open, events append in order (up to four lines). After it closes, a more important event cuts the speaker and the queue, and anything else drops. Known narrow differences from 1.0 are in `14 §2.1`. SyFive never sets `.queue`. | `09 §1.5` (open §12.4 → resolved) → `14 §2.1` → `15 §9` |
| D-079 | Audio session **ducks** (`.mixWithOthers + .duckOthers`). Never takes `.playback` in a way that halts other audio; respect the game-night playlist. | `09 §1.5` |
| D-080 | **VoiceOver running = suppress commentary.** Accessibility layer wins; the engine never competes with it. | `09 §1.5` |
| D-081 | **Voice ID is device-local** (UserDefaults); level and personality sync. A personality speaks the saved voice while it is installed, else the best installed voice in the device's language (premium, enhanced, default; never novelty or Personal Voice), resolved through `CommentaryVoices`. The Voice row names the voice in use. | `09 §6.1` → `14 §3.7` → `17 §2.6` *(rec.)* |
| D-082 | **Snarky targets roll / decision / dice, never the person.** Snark never stored, transmitted, or reaches any player-facing read; never leaves the live commentary room. | `09 §11` |
| D-083 | `yatzyRolled` utterance lands **after** the existing title-card animation, not during it. | `09 §8` (open §12.5 → resolved: after title card) |
| D-130 | **`onWillSpeak` fires while the engine is muted, by design.** A host muted by its commentary button (D-GNP-008) or by Sound set to Off still broadcasts to its guests (D-GNP-019). SyFive does not adopt Syderal's muted-host broadcast guard, and SyLib must not move the hook below the mute. | `16_GAME_NIGHT_PROXIMITY_MUTE §2.2` (D-GNP-019) → `14 §3.12` → `15 §2.5` |
| D-132 | **Muting cuts speech at once.** Any change from unmuted to muted stops the line being spoken and drops the queue: the commentary button, Sound set to Off, or proximity muting a guest when ranging begins. (Proximity's verdicts and timeout only unmute, D-GNP-005.) The host's broadcast to guests is unaffected (D-130). | `14 §4.5` (Syderal Q-22) → `16 §2.2` |
| D-133 | **A solo game has no winner and no lead.** With one player, game over emits `soloFinished` (tokens `player`, `score`; celebration tier) in place of `winnerDeclared`, and `leadChange` is never emitted. Every pack carries `soloFinished` lines. | `14 §4.5` → `16 §2.3` |
| D-141 | **Commentary on/off feedback is a SyLibUI `Toast`** that slides down out from under the Roll button (`placement: .belowBottom`, 4 pt gap), over the status row beneath it: two seconds, no taps, never over the roll controls themselves. | `14 §3.11` → `17 §2.10` *(rec.)* → Pops, 10 Oct 2026 (placement) |
| D-146 | **The Settings commentary section uses SyLib's `CommentarySettingsRows`**: a link showing Mode, Level, Personality and the voice in use (or "…" until the scan lands), and a Preview button that speaks the personality's preview line in that voice. All four lines and Preview show in every mode. Leaving the row stops a preview. Syderal uses the same rows with "Commentator" (Syderal `24`). | `20` §2 (Pops, 11 Oct 2026) |

## Game Night Commentary

| ID | Current ruling | Source → chain |
|---|---|---|
| D-084 | **Game Night commentary is host-authoritative echo.** The host's engine draws every line using the session's pack and level, and relays the text to every other device in the session (`CommentaryPayload`, envelope kind `.commentary`). Each device speaks it in its own voice (D-081). The host's personality is the whole table's voice. A FaceTime call still carries the host's audio to remote rooms. | `10 §1` → SyLib `10 §9` → `16 §1` |
| D-085 | **Guest and spectator devices run a receive-only commentary engine** in Game Night. It is built at the composition root by role, pinned to `.playByPlay`, has no event sink, and speaks only relayed text via `receiveText(_:tier:)`. It never draws lines, and its shuffle deck is saved and forgotten. Each device's speaker follows its own mute (D-GNP-015, D-130). The `09` engine stays Game-Night-ignorant. | `10 §3` → SyLib `10 §9` → `16 §1` |
| D-086 | **Synced Shared Booth** (cue protocol, Director/Voice split, booth roles) — designed in full (`10 §4`); **explicitly deferred to vNext.** Do not implement. Re-confirm `10 §4.4` table at scheduling. | `10 §4` |
| D-087 | The **call device has no SyFive job** in Game Night 1.0. Unseated spectator join (stage + PiP) is optional and user-driven, never required or steered toward. | `10 §1.4` |
| D-088 | **Two-device player pattern** (call on iPad/Mac, game on iPhone) is the recognized primary configuration; preserves full FaceTime video; iPhone joins via invite link or same-account prompt. | `10 §1.4` · extends `06 §2.1` |
| D-089 | **Commentary half of `06 §13.1`: spectator devices speak relayed commentary**, like guests (D-085), subject to their own mute. `06 §13.1` stays closed, with the opposite answer to the one recorded. | `10` Supersessions · closes `06 §13.1` commentary side → **superseded** by SyLib `10 §9` / `16 §1` |
| D-090 | **Mic mode is user-set only.** SyFive's tool: one sentence of Wide Spectrum copy, shown only when a call is active on the playing device. Never automated. | `10 §2.3, §7.2` |
| D-091 | **Table-row commentary override is session-scoped.** Host's solo settings never rewritten by a Game Night session. | `10 §7.1` |

## Game Night Theater Feel

| ID | Current ruling | Source → chain |
|---|---|---|
| D-092 | **Spectator devices produce no dice audio and no dice haptics.** Neither the rattle bed nor per-die settle thunks ever fire on a spectating device: `rollStarted` is called only from the roller's local tap, and `onDieSettled` requires a local simulation that no longer exists (D-126). `onAllDiceSettled` still fires on `rollResult` and is a no-op, killing a bed that was never started. `settle_all` remains an unused catalog entry per D-118. The sole feel event reaching a spectator is Yatzy celebration audio, which is D-095's sanctioned exception and is not dice audio. `06 §13.1` stays closed — with the opposite answer to the one recorded. | `11` Supersessions · closes `06 §13.1` → **superseded** by D-126 |
| D-093 | **Retired — no spectator interventions exist.** The row governed correction wobble and spectator auto-resolve, both of which were properties of the replay simulation removed by D-126; its claims are now vacuous rather than wrong. Its one surviving clause (one thunk per die at true rest, rattle bed unbroken to final settle) is roller-local behaviour already owned by D-044 and D-049. Do not reinstate from `11 §3`. | `11 §3` → retired by D-126; roller-side content held by D-044, D-049 |
| D-094 | **Retired — spectator dice audio is unconditionally off.** The hear-the-real-dice defaulting rule and its device-local override toggle governed a choice that no longer exists: with no spectator simulation (D-126) and no spectator dice audio (D-092), there is nothing for a default or a toggle to select between. No user-facing control ships. Do not reinstate from `11 §4`. | `11 §4` → retired by D-126, D-092 |
| D-095 | **App-layer feel events in Game Night are actor-local** (hold / score / undo). Yatzy celebration audio is the sole sanctioned exception: it fires on every device on receipt of `rollResult`, computed locally from the settled faces, with no wire traffic and no gating setting. Suppressed when the Yatzy box was scratched to 0, per D-005. | `11 §1, §5` · wording corrected under D-126, D-092 |
| D-096 | **`07` feel system stays Game-Night-ignorant.** The rule holds, but there is no longer a gating point: with no replay path (D-126), spectator devices run no feel code to gate. This row now constrains future work rather than describing a mechanism — any reintroduction of cross-device feel gates at the composition root, never inside `07`, mirroring `10 §3`. | `11 §2` → mechanism removed by D-126; rule retained |

## Game Night proximity

| ID | Current ruling | Source → chain |
|---|---|---|
| D-GNP-001 | Proximity mute suppresses commentary speech only; dice audio unaffected on all devices *The flam is an artifact of identical speech; percussive dice audio reads as room ambience* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-002 | Proximity resolution is host-arbitrated: guests report distances, host clusters and broadcasts the verdict *`SeatSnapshot` carries no device identity; only the host holds the device→seat mapping* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-003 | Clusters are built by union-find over sub-threshold pairs; `nil` distance never splits a cluster *Proximity is not reliably transitive; treating `nil` as "far" would fragment real rooms* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-004 | Host's cluster always speaks; every other cluster elects its lowest-seat device *Deterministic, no negotiation, no setup UI* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-005 | Guests start muted; proximity transitions are unmute-only *Going quiet mid-match is invisible; starting to speak mid-roll reads as a glitch* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-006 | One-shot resolution; no mid-match re-evaluation or re-ranging *Live re-evaluation pops audio as people shift; holds the radio open all match* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-007 | 10-second timeout from match start; expiry unmutes *False negatives self-correct with one tap; false positives are invisible* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-008 | Manual tap wins permanently for the match and cancels ranging on that device *The guess exists to save a tap; once tapped it has nothing to contribute* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-009 | Mute state is session-scoped, never persisted *A stale verdict would override a correct guess; cost of being wrong is one tap* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-010 | Ranging starts at seat claiming, gated on the table's `commentaryEnabled` *Parallel resolution with seats; keeps the permission prompt correlated with the feature* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-011 | Seat order locks at match start; verdict arrival time is irrelevant *Distances are stable, seat ordering is not until lock* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-012 | Threshold 3.0 m, four consecutive sub-threshold readings, both tunable *One stray reading must not mute a remote player* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-013 | Confident pairs resolve early; the timeout governs only ambiguous and no-signal cases *Common couch case unmutes fast* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-014 | Mute button visible only when session/solo commentary is enabled AND `soundMode != .off`; guests read the session value, never local `appSettings` *A control that does nothing is worse than none; local mode is a solo preference the relay ignores* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-015 | The button is uniform on host and guests: "commentary on this device" *Same meaning everywhere needs no explanation* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-016 | No settings surface, no alerts; the button is the only indicator *There is no silence to explain — commentary is playing from the host's phone* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-017 | Game Night commentary settings are seeded from personal settings at session start and never written back *Changing personality for one Game Night must not change the solo default* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-018 | Non-UWB devices (all iPads, some iPhones) and declined permission fall through to the timeout and unmute *Only `supportsPreciseDistanceMeasurement` is consulted; direction is inconsistent across U1/U2* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-019 | `SyLibCommentary`: `onWillSpeak` fires before the `isMuted` guard *Broadcast is a session concern, mute is a local-speaker concern; corrects a host with sound off silencing the table* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-020 | Transport version bumps to 3 for the three new proximity message kinds *Existing version-mismatch UI handles the incompatibility* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
| D-GNP-021 | Companion-device UWB proxy for iPad participants — DEAD END, do not revisit without new hardware facts *Proxy locates the person, not the speaking device; pocketed phones give unreliable readings* | `16_GAME_NIGHT_PROXIMITY_MUTE §12` |
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
| D-GNP-036 | The `begin` call at session activation is effectively host-only. Guests have no `commentaryEnabled` until the host's `tableState` arrives, so their effective call site is the `tableState` handler. *(reconstructed from code, 11 Oct 2026)* | `ContentView.swift` 300-303 |

## House Records

| ID | Current ruling | Source → chain |
|---|---|---|
| D-097 | Records surface form: **distributed titles**, not a ranked leaderboard. Eight titles mixed across skill / luck / participation so no single strong player sweeps the board. | `12 §1` |
| D-098 | **Nothing ages out.** All-time records; no rolling window, no expiry, no seasonal reset. | `12 §2.1` |
| D-099 | **Archived players remain eligible.** Rendering uses Participant display snapshot, never the live Player record. | `12 §2.2` |
| D-100 | **Game Night guests are part of the house.** Eligible for all titles; no special-casing, no visual flag. | `12 §2.3` |
| D-101 | Ties: **all holders listed**; per-name dates; collapsed to one date when all holders share it (same-match tie). | `12 §2.4` |
| D-102 | **Silent recalculation.** Title changes carry no notification, no animation, no game-over acknowledgment. | `12 §2.5` |
| D-103 | **Anti-titles permanently prohibited.** No Worst Game, no Most Scratched Yatzys, no title whose held state is a negative attribute of the holder, under any framing, ever. | `12 §2.6` |
| D-104 | Average-type title gate: **N ≥ 10 completed matches**; sample count always rendered on the card. Shrinkage / regression to house mean **rejected** — displayed value must match Player Insights. | `12 §2.7` |
| D-105 | **Rank-derived titles require `participants.count > 1`.** Solo `rank = 1` is excluded; ungated "Most Wins" would become "how often did you play alone." | `12 §2.8` |
| D-106 | **Tenure resets on retake.** "Held since" = start of the current continuous hold; losing and reclaiming resets to the reclaim date. | `12 §2.9` |
| D-107 | **Unclaimed titles are shown** in two flavors: `Unclaimed` (nobody qualifies) and `Unclaimed — after 10 games` (gate unmet by all). | `12 §2.10` |
| D-108 | **Screen hidden until first completed match.** After one match, Best Game and Most Games Played are both claimed by construction. | `12 §2.11` |
| D-109 | **First menu item, standalone destination.** Not a section inside Player Insights; different scope. | `12 §2.12` |
| D-110 | **Title definitions stay App-layer for 1.0.** Do not enter Domain or SyLib. Per-game records are a future scoring-system responsibility (Step 2/3). | `12 §2.13` |
| D-111 | **Commentator never references House Records.** Any pack, any level. Hard prohibition; extends `09`. | `12 §6.2` |
| D-112 | **House Records never renders on the external display.** Stage is for the table; records are a browsing destination. | `12 §6.3` |
| D-113 | Records are **per-device by construction.** Two households may legitimately disagree about who holds a record. Do not reconcile across devices; divergence is correct. | `12 §6.4` |
| D-114 | **No stored aggregates.** Compute-on-read from `MatchModel` / `ParticipantModel`; zero new schema. | `12 §4.1` |
| D-115 | **Only `status == .completed` matches count.** In-progress and abandoned excluded everywhere, including Most Games Played. | `12 §4.1` |
| D-116 | **No runner-up or partial ordering on any card.** A card names the holder(s) and nothing about who does not hold the title. | `12 §3.3` |

---

## Open decisions (pointers only — resolved rows get promoted above)

- `04_PLAYER_INSIGHTS_DESIGN.md` leaves **three decisions explicitly open** for Pops — see that doc's open-decisions section.
- `08 O-2` — **Yatzy: rising motes vs. ring pulse**: ship recommended rising motes (§2.2), or fall back to single soft accent-ring pulse if motes feel like too much on device?
*(No open decisions — all resolved.)*
- `11 §7` — **Shared Yatzy haptic pulse**: fire a soft haptic on theater-audio devices at the synchronized bloom (four phones pulsing mid-call), or remain roller-only per the touch rule?
