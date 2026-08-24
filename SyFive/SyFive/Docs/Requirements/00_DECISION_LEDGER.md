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

---

## Governance

| ID | Current ruling | Source → chain |
|---|---|---|
| D-001 | Docs are immutable once delivered. Overrides travel via a Supersessions block in the newer doc plus a row update here. This ledger is HEAD and accompanies every agent prompt. | Session 05 · recorded here & `05 §1` |

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
| D-023 | CloudKit ships at 1.0. Per-app private container `iCloud.com.syzygysoftwerks.SyFive` (not a shared "Sy" container), with a one-line revert lever. *(rec.)* | `03_CLOUDKIT` |
| D-024 | The built-in Yatzy catalog entry seeds with the fixed well-known UUID `BFB7F8F6-87D2-4700-9267-36A8ED4AC3C8` for cross-device deduplication. *(rec.)* | `03_CLOUDKIT` |
| D-025 | `ScoreEntryModel` is **not** registered in the CloudKit schema — scorecards travel inside the participant blob. | `03_CLOUDKIT` |
| D-026 | **Dev → Production schema promotion is a hard gate** before any TestFlight build. | `03_CLOUDKIT` |
| D-027 | Sync UX is calm and silent: no spinners, no toggles, no sync status chrome. | `03_CLOUDKIT` |

## Stats & insights

| ID | Current ruling | Source → chain |
|---|---|---|
| D-028 | Two-tier stats mirroring the scoring split: Tier 1 generic (SyLib), Tier 2 Yatzy-specific (Yatzy module). | `03_STATS` |
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
| D-059 | **Never stream per-frame transforms.** One `DiceRollRecipe` message per roll is the theater budget. | `06 §2.1` |
| D-060 | **`MatchPresenting` protocol:** `MatchController` and `TableReplica` both adopt it; views bind either without knowing which. Interactive affordances route by role at the call site. | `06 §10` |
| D-061 | GroupActivities imports confined to `App/GameNight/`. **Domain and Persistence layers never learn Game Night exists.** | `06 §10` |
| D-062 | **Roller physics untouched.** Recipe broadcast is presentation only; corrections act on spectator render entities only. Fairness harness unaffected; no re-validation triggered by Game Night work. | `06 §3.1, §6.2` |
| D-063 | Only the host checkpoints during play. **Guests write exactly once, at completion**, upserting by match UUID. `02` single-writer invariant preserved. | `06 §3.3` |
| D-064 | **Zero schema change.** Game Night adds no persisted fields, entities, or migrations. `02 §2.7` display snapshots + preserved `playerID`s carry it all. | `06 §0, §14` |
| D-065 | No chat, timers, meters, matchmaking, session chrome. **The FaceTime call (or the room) is the social layer; the app builds none of it.** | `06 §1` |
| D-066 | Spectator stuck dice **auto-resolve silently** via batch rescue path. Spectators never see yellow/red intervention states. | `06 §6.2` |
| D-067 | **Dropped-session resume ships in v1.** Host's `inProgress` match resurfaces as resumable; new SharePlay session; guests re-claim seats; interrupted turn restarts. *(rec.)* | `06 §7` (open §13.4 → recommended in; shipped) |
| D-120 | **Game Night undo: scorer-until-next-rollBegan via host.** Scorer's device sends `UndoRequestPayload`; host applies `undoLastScore()` and broadcasts with `diceValues` so scorer can rescore. `clearUndoSnapshot()` closes the window on `rollBegan`. | `06 §13.3` (open → shipped) |
| D-121 | **Guest drop mid-turn: host plays as proxy.** When a guest drops mid-turn, host rolls and scores on their behalf. No auto-scratch; host can play the turn fairly. Returning guest rejoins from current matchState. | `06 §13.2` (open → resolved) |

## Celebrations

| ID | Current ruling | Source → chain |
|---|---|---|
| D-068 | **Frequency governs intensity.** Yatzy = repeatable whisper; game-over = earned generous moment once per game. Never equal treatment. | `08 §0` |
| D-069 | **No burst/explosion motion, ever.** Yatzy motes rise; game-over particles slow-fall. No outward blast, no casino grammar, no hard sparkle or casino red. | `08 §0, §10` |
| D-070 | Yatzy celebration: **sparse rising accent motes** (15–30 total, ceiling not target), inserted into existing rim-light / push-in / title-card sequence. Three consecutive Yatzys must feel identical; no escalation or accumulation. Fallback if motes feel like too much: single soft accent-ring pulse. *(rec. motes — see open O-2)* | `08 §2` |
| D-071 | Game-over celebration: **winner-accent slow-fall + scorecard glow/scale + grand-total count-up + theme-gradient wash**, in the winner's `displayThemeID` accent. | `08 §3` |
| D-072 | Celebration colors are **participant-scoped:** current scorer's accent for Yatzy; winner's accent for game-over. Both sourced from `displayThemeID` snapshot. | `08 §2.3, §3.2` |
| D-073 | **Reduce Motion mandatory** for both moments: reach same end state with no particle motion and no flashing. Celebrations non-blocking; cancel cleanly on early dismissal. | `08 §4` |
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
| D-077 | **No-immediate-repeat** selection rule: exclude the last-used line per event kind per session. Full shuffle-bag not required for 1.0. | `09 §1.4` |
| D-078 | **Higher-tier events interrupt; same-or-lower-tier events drop.** Never build a backlog; speech must always be behind the live game. | `09 §1.5` (open §12.4 → resolved: interruptions preferred) |
| D-079 | Audio session **ducks** (`.mixWithOthers + .duckOthers`). Never takes `.playback` in a way that halts other audio; respect the game-night playlist. | `09 §1.5` |
| D-080 | **VoiceOver running = suppress commentary.** Accessibility layer wins; the engine never competes with it. | `09 §1.5` |
| D-081 | **Voice ID is device-local** (UserDefaults). Level + personality sync (AppSettingsModel / SwiftData). Missing voice falls back to an enhanced locale voice. *(rec.)* | `09 §6.1` (open §12.2 → resolved: device-local) |
| D-082 | **Snarky targets roll / decision / dice, never the person.** Snark never stored, transmitted, or reaches any player-facing read; never leaves the live commentary room. | `09 §11` |
| D-083 | `yatzyRolled` utterance lands **after** the existing title-card animation, not during it. | `09 §8` (open §12.5 → resolved: after title card) |

## Game Night Commentary

| ID | Current ruling | Source → chain |
|---|---|---|
| D-084 | **Game Night commentary 1.0:** single announcer on the host's seated device; host's pack, level, and voice; FaceTime call carries it to remote rooms. Zero wire changes to the `06` message table. | `10 §1` · supersedes `09` implicit single-device assumption |
| D-085 | **Guest and spectator devices never instantiate the commentary engine** in Game Night. Gate at composition root by role; `09` engine stays Game-Night-ignorant. | `10 §3` |
| D-086 | **Synced Shared Booth** (cue protocol, Director/Voice split, booth roles) — designed in full (`10 §4`); **explicitly deferred to vNext.** Do not implement. Re-confirm `10 §4.4` table at scheduling. | `10 §4` |
| D-087 | The **call device has no SyFive job** in Game Night 1.0. Unseated spectator join (stage + PiP) is optional and user-driven, never required or steered toward. | `10 §1.4` |
| D-088 | **Two-device player pattern** (call on iPad/Mac, game on iPhone) is the recognized primary configuration; preserves full FaceTime video; iPhone joins via invite link or same-account prompt. | `10 §1.4` · extends `06 §2.1` |
| D-089 | **Commentary half of `06 §13.1` resolved:** spectator devices produce no commentary audio in Game Night 1.0. Dice-feel half handled by `11`. | `10` Supersessions · closes `06 §13.1` commentary side |
| D-090 | **Mic mode is user-set only.** SyFive's tool: one sentence of Wide Spectrum copy, shown only when a call is active on the playing device. Never automated. | `10 §2.3, §7.2` |
| D-091 | **Table-row commentary override is session-scoped.** Host's solo settings never rewritten by a Game Night session. | `10 §7.1` |

## Game Night Theater Feel

| ID | Current ruling | Source → chain |
|---|---|---|
| D-092 | **Spectator theater audio fully resolved:** dice audio (rattle bed + per-die settle thunks) renders on theater-eligible devices; haptics never fire for spectated rolls. Own-turn feel pixel-identical to today. | `11` Supersessions · closes `06 §13.1` · extends `07` |
| D-093 | **Interventions are feel-silent:** correction wobble makes no sound; spectator auto-resolves are silent inside the live bed. One thunk per die at true rest; rattle bed unbroken to final settle. | `11 §3` |
| D-094 | **Theater audio defaults** follow hear-the-real-dice rule: unseated + call-sheet-on-playing-device ON; tap/link/prompt-seated + no-call hosts OFF. One device-local `UserDefaults` toggle overrides. | `11 §4` |
| D-095 | App-layer feel events in Game Night are **actor-local** (hold/score/undo). Yatzy celebration audio is the sole sanctioned exception: fires on all theater-audio-ON devices, timed to local theater settle, via local computation — no wire traffic. | `11 §1, §5` |
| D-096 | **`07` feel system stays Game-Night-ignorant.** Theater gating lives at the replay path (the composition root), mirroring `10 §3`'s rule for the commentary engine. | `11 §2` |

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
