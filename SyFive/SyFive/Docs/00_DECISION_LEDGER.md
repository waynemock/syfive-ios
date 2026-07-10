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
| D-003 | Ruleset is **Classic Hasbro** — Yahtzee 50, +100 per extra while the box holds a live 50, joker forced-scoring. *Not* European Yatzy. | `SyFive.md §5` (recommended European ⭐) → superseded by implementation + `02 §4` |
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
| D-016 | `yahtzeeBonus` is a field on `Participant`, not a `ScoreEntry` and not metadata. | `02 §2.7` |
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

---

## Open decisions (pointers only — resolved rows get promoted above)

- `04_PLAYER_INSIGHTS_DESIGN.md` leaves **three decisions explicitly open** for Pops — see that doc's open-decisions section.
- `05 §11` — **Undo feel**: tiny D3 "set-down" tick vs. silent. Lean recorded in 05.
- `05 §11` — **Settle haptic pattern**: per-die transients vs. single pulse on all-settled. Both spec'd; feel board decides on device.
- `05 §11` — **Yatzy haptic**: canonical soft tick (dossier canon) vs. 200 ms continuous swell alternative.
