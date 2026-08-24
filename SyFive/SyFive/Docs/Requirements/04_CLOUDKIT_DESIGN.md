# SyFive — CloudKit Integration Design Spec

*Design authority for iCloud sync of the Player + Game persistence system: container
configuration, seeding under sync, schema deployment, account behavior, and the
validation gate that decides whether sync ships in 1.0.*

> **Status:** Design agreed. Companion to `02_DATAMODEL_DESIGN.md`; this document is the
> implementation brief for the Xcode Claude agent's **Stage 7**, continuing 02's stage
> numbering. 02 made the schema CloudKit-*safe*; this document makes it CloudKit-
> *integrated*. Read 02 first — its §3 (persistence strategy) and §9 (invariants) are
> load-bearing here and are not restated in full.

---

## 0. Decisions locked (and why)

Three decisions were on the table. All three are now resolved:

1. **CloudKit sync ships in 1.0.** "Cross-device continuity — current game + history
   follow the player" is a stated product pillar, not a nice-to-have. Sync is built as
   **Stage 7**, after 02's stages 1–6 are complete and validated locally, with its own
   validation gate (§8) and a documented one-line revert lever (§7). The lever exists so
   that a rocky Stage 7 near ship degrades to "1.0 ships local-only, sync in 1.0.x" —
   a release decision, not an architecture change.

2. **The Game catalog syncs**, using the fixed-UUID seeding pattern (§3), rather than
   living in a second local-only `ModelConfiguration`. A local catalog would dodge the
   duplicate-seed problem entirely, but ScoreIt v2's *user-created* game definitions
   must sync, so the package-era pattern is fixed-UUID seeding — SyFive should exercise
   the pattern that survives extraction, with a catalog of one.

3. **Per-app container**: `iCloud.<SyFive bundle ID>` (match the actual bundle ID
   exactly, e.g. `iCloud.com.syzygysoftwerks.SyFive`). Not a shared "Sy" container.
   SyLib shares *code*, not *data*; a shared container would chain SyFive's and ScoreIt
   v2's release cycles and schema evolution together. ScoreIt v2 gets its own container
   with its own schema lifecycle.

### 0.1 What 02 already settled (inherited here, not re-decided)

- **Checkpoint writes only** — flush on category-scored and match-completed; transient
  turn state never persists (02 §3.4).
- **Last-write-wins at turn boundaries** is the *entire* conflict policy. No merge
  logic, no conflict UI, no CloudKit conflict handling.
- **CloudKit-safe schema** — no `@Attribute(.unique)`, optional relationships with
  inverses, defaults everywhere, `UUID` as a plain property (02 §3.1). The mutable
  match counter was already killed as a sync hazard (02 §2.6).
- **History renders from snapshots** — Participants carry display snapshots; Matches
  snapshot `scoringSystemID`/`version`. Nothing in history depends on a synced row
  still existing (02 §2.6–2.7). This is what makes the whole sync design low-stakes.

### 0.2 Platform floor and the WWDC 2026 check

Minimum deployment target is **iOS 18.6**. Everything in this document uses the
long-stable API surface available there.

Verified July 2026: WWDC 2026 (iOS 27) added SwiftData features — sectioned fetches,
`@Attribute(.codable)`, `ResultsObserver`, `HistoryObserver`, enum/compound predicates —
but **did not change the private-database CloudKit sync path**, and SwiftData still has
no shared/public database sync. None of the iOS 27 additions are usable at an 18.6
floor, so they are informational only. One worth noting: `@Attribute(.codable)` is
Apple formalizing exactly the manual Codable-blob approach 02 §3.2 chose for
scorecards, with the same documented constraints (opaque to predicates, no migration
awareness — evolve the blob Codable-compatibly yourself). The manual approach remains
correct at 18.6 and is validated as idiomatic; if the floor ever rises past iOS 27,
`.codable` is the future spelling of the same decision.

---

## 1. Sync model & scope

**Private CloudKit database only.** One user, their own data, mirrored across their own
devices. No shared database, no public database, no sharing/invite features — SwiftData
cannot do them and SyFive does not want them.

SwiftData's CloudKit mirroring runs on `NSPersistentCloudKitContainer` machinery
underneath. The app **never touches that machinery directly** — no `CKRecord`, no
`CKSubscription`, no zone management. Configuration is declarative (§2); the framework
owns transport, retry, batching, and push subscriptions.

### 1.1 What syncs

Every registered `@Model` twin, which after this document is exactly:

| Twin | Synced content | Notes |
|---|---|---|
| `PlayerModel` | Roster | The reason sync exists |
| `TeamModel` | Nothing in 1.0 | Registered + exercised (§4.2), never instantiated by gameplay |
| `GameModel` | Catalog of one (Yatzy) | Fixed-UUID seeded (§3) |
| `MatchModel` | Sessions + status | The resume/history payload |
| `ParticipantModel` | Per-match join, incl. the scorecard **blob** | `[ScoreEntry]` travels inside as one `Data` field |

### 1.2 `ScoreEntryModel` is NOT registered — resolving an 02 ambiguity

02 §3.1 lists `ScoreEntryModel` among the twins to create; 02 §3.2 then chooses the
**blob** storage path for SyFive (entries encoded on `ParticipantModel`), with
normalized rows reserved as ScoreIt v2's option. CloudKit forces the ambiguity closed:
**every type in `Schema([...])` becomes a Production record type that can never be
removed** (§4.3). SyFive must not mint a permanent record type for a storage path it
explicitly rejected.

**Resolution:** register `PlayerModel`, `TeamModel`, `GameModel`, `MatchModel`,
`ParticipantModel` — and **omit `ScoreEntryModel` from the schema.** Whether the class
file exists is immaterial (an unregistered `@Model` is inert; deferring the file to
Step 3 is equally fine). The frozen cross-app contract is the *domain* `ScoreEntry`
value type, not any CloudKit record type — ScoreIt v2's own container makes its own
storage choice.

`TeamModel` stays registered despite being dormant: 02 ships Team as frozen schema
deliberately, it costs one exercised record type, and a future SyFive teams feature
then needs zero schema work. The asymmetry with `ScoreEntryModel` is principled:
Team is a dormant *capability* SyFive's schema owns; row-based entries are a storage
*path* SyFive declined.

### 1.3 What never syncs

- **Transient turn state** — `diceValues`, `held`, `rollsRemaining`, `isRolling`. Never
  persisted at all (02 §3.4), therefore never synced. This line already does most of
  the sync design's work.
- **Debug / fairness data** — CSVs and roll recipes are files, not SwiftData.
- **Device-local settings** — future `UserDefaults` residents (02 §7).

### 1.4 Conflict policy (restated once, then trusted)

Last-write-wins at checkpoint boundaries. Two devices resuming the same unfinished
match is *possible* and *acceptable*: whichever scores later overwrites, per 02 §3.4's
reasoning (short games, one device in practice). The validation matrix confirms this
**converges without crashing** (§8 item 4) — it does not attempt to make it "merge
correctly," because there is no merge.

**Undo interacts cleanly:** the existing one-level undo emits a compensating checkpoint
write (entry back to `nil`, `yatzyBonus`/turn state restored). To sync it is just
another LWW write. No special handling.

---

## 2. Container, entitlements, configuration

### 2.1 The configuration (and the revert lever)

Container setup in `SyFiveApp`:

```swift
let schema = Schema([
    PlayerModel.self, TeamModel.self, GameModel.self,
    MatchModel.self, ParticipantModel.self
])

let config = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .private("iCloud.com.syzygysoftwerks.SyFive")  // ← the lever
)

let container = try ModelContainer(for: schema, configurations: [config])
```

- Use the **explicit** `.private("iCloud....")` form, not `.automatic`. Intent is
  visible in the diff and immune to entitlement-ordering surprises.
- **The revert lever is that one argument:** `.private(...)` → `.none`. Nothing else
  changes. §7 covers when and why to pull it.
- **02's stages 4–6 must be built with `cloudKitDatabase: .none` written explicitly**
  (not omitted), so Stage 7a's flip is a visible one-line diff and the pre-CloudKit
  builds are unambiguous about their intent.

### 2.2 Project capabilities

1. **iCloud** capability → CloudKit checked → container `iCloud.<bundle ID>` created
   and checked.
2. **Background Modes** → *Remote notifications*. CloudKit drives imports via silent
   pushes; the framework creates and manages the `CKSubscription`s itself. No APNs
   certificate work, no push-handling code.

### 2.3 Environments (the trap, named early)

- **Xcode debug builds → CloudKit Development environment.**
- **TestFlight and App Store builds → Production environment. Always.**

Development has just-in-time schema creation; Production does not (§4). The classic
failure is validating everything in debug builds, shipping to TestFlight without
promoting the schema, and watching sync silently do nothing for testers. The release
checklist (§9) makes promotion a hard pre-TestFlight gate.

---

## 3. Seeding under sync — the duplicate-catalog problem

### 3.1 The problem

02 §8 stage 5 seeds the built-in Yatzy `Game` at launch. Under sync, seeding races:
device B seeds its own Yatzy row before its first CloudKit import delivers device A's
row (fresh install, offline first launch, slow first sync — all realistic). CloudKit
**forbids the unique constraint** that would prevent the duplicate. Naive seeding
yields N catalog rows for N devices.

### 3.2 The fix — four parts, all required

1. **Well-known UUID.** Built-in catalog entries use a fixed, hardcoded `id`. Declare
   in the Domain layer (pure data; Foundation-only rule intact):

   ```swift
   // Domain/Values/Game.swift
   extension Game {
       /// Fixed identity for the built-in Yatzy catalog entry.
       /// Every install seeds this same UUID; dedupe relies on it. Never change.
       public static let builtInYatzyID =
           UUID(uuidString: "BFB7F8F6-87D2-4700-9267-36A8ED4AC3C8")!
   }
   ```

   That value was generated once for this spec and is now **the** constant — use it
   verbatim and never change it. It is an identity, not a secret and not per-build.

2. **Idempotent seed.** At every launch: fetch `GameModel` where
   `id == builtInYatzyID`; insert **only if absent**. Cheap enough to run
   unconditionally; never assume "first launch" is knowable under sync.

3. **Convergent dedupe sweep.** At every launch, after the seed: fetch all `GameModel`
   rows with the well-known `id`. If more than one, **keep the earliest `createdAt`,
   delete the rest.** Properties that make this safe:
   - Every duplicate carries the *same* UUID value, and Matches reference the catalog
     **by that value** (02 §2.6) — so any survivor satisfies every existing reference.
     Deleting duplicates cannot orphan anything.
   - `createdAt` is a synced field, so both devices sort identically and converge on
     the same survivor. Deletions propagate.
   - The sweep is idempotent. Worst case, duplicates survive one sync round and the
     next launch converges. No ping-pong is possible: devices only ever delete
     non-earliest rows.

4. **Duplicate-tolerant reads.** Everywhere the catalog is read: *"first match where
   `id == builtInYatzyID`"*, never fetch-and-assume-unique. Between seed race and
   sweep, two rows may briefly coexist; reads must not care.

### 3.3 Resilience corollary (why this is low-stakes)

Even **total catalog loss** breaks nothing user-visible: `Match` snapshots
`scoringSystemID` + `scoringSystemVersion`, and `Participant` snapshots all display
fields. History renders and scores forever without the `Game` row. The catalog is a
convenience for the new-game flow, not a dependency of anything historical. Never gate
history or resume on catalog presence.

### 3.4 Pattern on file for Settings

When the Settings model arrives (02 §7: single synced row), it inherits this exact
pattern: well-known UUID, idempotent seed, earliest-`createdAt` sweep,
first-match reads. Recording that now so Settings doesn't rediscover the race.

---

## 4. Schema lifecycle & deployment

### 4.1 How CloudKit learns the schema

Record types are **generated from the `@Model` twins at runtime**: in the
**Development** environment, the first time a record of a given type uploads, CloudKit
creates the record type and its fields just-in-time. **Production never does this.**
A Production client writing a record type that was never promoted fails — quietly,
in logs the user never sees.

### 4.2 The schema-exercise routine (required, debug-only)

Because JIT creation only happens for types that actually upload, **every registered
twin must upload at least once in Development before promotion — including dormant
`TeamModel`**, which normal SyFive gameplay never instantiates. Otherwise Production's
schema is incomplete from day one and a future teams feature inherits a deployment
problem.

Ship a debug-flag-gated routine (pattern-match `AppConfig.DebugDice`):

- Inserts one throwaway instance of **each** registered twin — a `PlayerModel`, a
  `TeamModel`, the seeded `GameModel` (already covered), and a `MatchModel` with one
  `ParticipantModel` carrying a small scorecard blob — saves, allows export to
  complete, then deletes the throwaways (deletions propagate; fine in Development).
- Requires a device signed into iCloud, on the Development environment (any debug
  build).
- After running: open the **CloudKit Console** (icloud.developer.apple.com) → the
  app's container → Development → confirm every record type exists with the expected
  fields, including the scorecard blob field on the Participant record and every
  `TeamModel` field.

### 4.3 Promotion, and additive-only forever

- **Promote Development → Production in the CloudKit Console *before* the first
  TestFlight build.** Hard gate on the release checklist (§9).
- After promotion, the Production schema is **additive-only, forever**: new fields may
  be added (optional or defaulted — which 02's CloudKit-safe rules require anyway);
  fields and record types are **never renamed, retyped, or removed**. This is 02's
  frozen-`ScoreEntry` discipline physically enforced at the container level — and the
  reason §1.2 refuses to register a record type SyFive won't use.

### 4.4 The blob is invisible to CloudKit — a feature with a duty

The participant's `[ScoreEntry]` blob crosses CloudKit as **one opaque `Data` field**.
Its internal shape can evolve without any CloudKit schema event — the flexibility 02
wanted. The duty attached: blob evolution must be **Codable-forward-compatible on its
own** (additive optional fields only; old builds must decode new blobs and vice versa),
because neither SwiftData migration nor CloudKit schema tooling can see inside it.
02 §9 already mandates this; CloudKit raises the stakes because *mixed app versions
sharing one iCloud account is the steady state*, not an edge case.

### 4.5 Model versioning posture

With CloudKit attached, treat SwiftData migrations as **lightweight/additive only**.
Custom migration stages against a synced store are a hazard (remote devices on old
schemas keep writing old-shape records). If a change ever seems to require a real
migration, that is a design event to bring back here — not a patch.

---

## 5. Account behavior & privacy

### 5.1 No iCloud account

The container initializes normally; data persists **locally**; mirroring starts if an
account later appears. The app is **fully functional signed-out** — never gate play,
resume, or history on iCloud availability, and never prompt for sign-in. Matrix item 6
validates this on a signed-out device.

### 5.2 Account switch / sign-out — validate, don't assume

Expected framework default: when the iCloud account changes or signs out, the **local
mirror is purged of synced records** so user A's data never appears under user B. This
is privacy-correct behavior and, for a game-history app, acceptable — history lives in
the departing user's iCloud and returns when they do.

**Do not encode this assumption anywhere.** Matrix item 7 observes the actual behavior
on-device; document what is observed; the only hard requirement is that the app remains
playable through the transition (fresh local state is fine).

### 5.3 Privacy posture

Everything lives in the **user's private database**. The developer cannot read it;
nothing reaches any Syzygy-controlled server; there is no analytics side channel here.
For App Store submission, private-database iCloud storage is generally treated as *not*
"data collected" by the developer — **confirm against the current App Privacy
questionnaire wording at submission time** (checklist item; the questionnaire's
definitions shift and this document is not the authority on them).

---

## 6. Sync UX under the calm ethos

Sync is **silent, automatic, and best-effort**. Concretely:

- **No sync UI.** No spinners, progress indicators, badges, banners, error alerts, or
  "syncing…" toasts. A sync delay or failure *looks like nothing* and heals later.
  That is the designed experience, not a gap. (Offline, iCloud-full, and server-error
  states all get the same treatment: local play continues, mirroring resumes when it
  can — all framework behavior, all invisible.)
- **Remote and local unfinished matches are indistinguishable.** One
  `status == .inProgress` query, one resume affordance (02 §3.4). No "from your iPad"
  labeling; a match is a match.
- **Roster duplicates are legitimate, not a bug.** Two offline devices each creating
  "Xander" yields two Player rows with distinct UUIDs — and identical names across a
  family roster are *expected* (02 §3.1 explicitly declined uniqueness). **No
  auto-merge.** Archival (02 §2.3) is the cleanup tool. A merge tool is a ScoreIt v2
  candidate at the earliest.
- **No sync toggle in 1.0.** Sync is how the app works, not a decision to put on the
  user. A toggle imports the "what happens to the data when I flip it" problem for
  zero calm. When the Settings screen exists, at most a passive one-line status
  ("iCloud Sync: On"). Revisit only if support traffic demands it.
- **Debug-only instrumentation:** `NSPersistentCloudKitContainer.eventChangedNotification`
  fires for import/export events even under SwiftData (it is the machinery
  underneath). Debug builds may log these events to watch sync during the validation
  matrix. This is unofficial surface — **diagnostics only, never product logic, never
  UI.**

---

## 7. Failure modes & the revert lever

### 7.1 The lever

One line in `SyFiveApp` (§2.1): `.private("iCloud....")` → `.none`. Local persistence,
resume, history, roster — everything from stages 4–6 — is untouched, because none of
it was ever written against sync.

### 7.2 When it may be pulled

**Pre-release only, in earnest.** If Stage 7d's Production validation fails near ship,
pull the lever, ship 1.0 local-only, land sync in 1.0.x. That is the whole point of
sequencing sync as the final stage with its own gate.

Pulling it **post-release** is a user-visible regression (people who had sync lose it)
— treat as an emergency measure, not an option. Mechanically it is safe: the local
store is the source of truth and retains everything; server records go stale
harmlessly; re-enabling resumes mirroring. No data loss in either direction.

### 7.3 Non-problems (checked, dismissed)

- **Quota.** Private-DB data counts against the *user's* iCloud storage. A completed
  match with blob scorecards is a few KB; a heavy user's lifetime history is well
  under a megabyte. If the user's iCloud is full, the framework pauses mirroring and
  resumes when space frees — invisible, per §6.
- **Record size.** CloudKit's per-record ceiling is ~1 MB; the scorecard blob is
  orders of magnitude under it. No asset/external-storage handling needed.
- **Write rate.** Checkpoint writes are one small transaction per scored category —
  low tens per match. Nowhere near any throttling concern.

---

## 8. Validation matrix

**Two physical devices** on the same Apple ID. The Simulator's CloudKit push delivery
is unreliable (imports tend to happen only on launch/foreground) — usable for smoke
tests, **not for sign-off**. Items 1–9 run against Development (Stage 7c); item 10
against Production (Stage 7d).

1. **Roster propagation.** Create, rename, re-theme, archive a Player on A → each
   change appears on B.
2. **History propagation + snapshot proof.** Complete a match on A → appears in B's
   history with correct names/initials/themes. Then rename that player on B → A's
   *historical* rendering is unchanged (display snapshots doing their job).
3. **Cross-device resume.** Kill the app on A mid-match → match is resumable on B
   (interrupted player's turn restarts, scorecard intact — 02 §3.4) and still on A.
4. **LWW convergence.** Resume the *same* unfinished match on both devices, score
   different categories on each, let sync settle → both devices converge to one
   consistent state, no crash, no duplicated match. The later checkpoint winning is
   **correct by design**; the test is convergence-without-damage, not merge fidelity.
5. **Duplicate-seed convergence.** Fresh install on B in airplane mode → launch (seeds
   Yatzy locally) → go online → within a launch cycle the sweep (§3.2) converges both
   devices to one catalog row; matches and new-game flow work throughout.
6. **Signed-out device.** No iCloud account: full play, local persistence, resume —
   no prompts, no degradation.
7. **Sign-out transition.** Sign out of iCloud on A mid-life: app remains playable;
   observe and document what happens to local synced data (§5.2's expected purge).
8. **Fresh-install hydration.** Wipe A, reinstall, sign in → roster and history arrive
   without user action.
9. **Offline divergence.** Both devices offline; each edits the roster and completes a
   match → reconnect → both matches present on both devices; roster converges
   (legitimate duplicates acceptable per §6); no crash.
10. **Production pass.** After schema promotion, a TestFlight build on both devices
    repeats items 1–3 against the Production environment. **This is the ship gate.**

---

## 9. Stage 7 implementation plan (continues 02 §8)

> Prerequisite: 02's stages 1–6 complete and locally validated, built with
> `cloudKitDatabase: .none` written explicitly.

**7a — Plumbing.** Add capabilities and background mode (§2.2); flip the config to
`.private(...)` (§2.1); confirm the registered schema is exactly the five twins of
§1.1–1.2; write the debug-only schema-exercise routine (§4.2); run it; verify all
record types and fields in the CloudKit Console (Development). *Check: a Player created
on dev-build device A appears on dev-build device B.*

**7b — Seeding hardening.** `Game.builtInYatzyID` constant (real UUID, frozen);
idempotent seed; convergent dedupe sweep; duplicate-tolerant catalog reads (§3.2).
*Check: matrix item 5 passes in Development.*

**7c — Validation.** Full matrix items 1–9 against Development. Fix, re-run, until
clean. *Check: matrix 1–9 signed off.*

**7d — Release gate.** Promote the schema to Production in the Console (§4.3); cut a
TestFlight build; run matrix item 10. *Check: pass → 1.0 ships with sync. Fail → pull
the lever (§7), ship local-only, fix in 1.0.x.*

### 9.1 Release checklist (consolidated, CloudKit-relevant)

- [ ] CloudKit schema **promoted to Production before the first TestFlight build** (§4.3)
- [ ] Schema-exercise routine is debug-flag-gated (ships inert, like the dice harness)
- [ ] Matrix item 10 (Production, two devices) signed off
- [ ] `Game.builtInYatzyID` is a real generated UUID, committed, and referenced by both
      seed and sweep
- [ ] `AppConfig.DebugDice.showHarness = false`, `logRollDiagnostics = false` (carried
      from `IMPLEMENTATION_STATUS.md` — same pre-submission pass)
- [ ] App Privacy questionnaire reviewed for the iCloud private-database answers (§5.3)

---

## 10. Invariants the agent must preserve (quick reference)

- **Private database only; per-app container;** explicit `.private("iCloud....")`.
  The revert lever is `.none` on that one line — nothing else may be entangled with it.
- **No conflict handling, no continuous autosave, no sync UI.** LWW at checkpoint
  boundaries is the *entire* policy (02 §3.4). Do not "improve" it.
- **Registered schema = Player, Team, Game, Match, Participant. `ScoreEntryModel` is
  never registered** (§1.2). Every registered twin is exercised in Development before
  promotion — including dormant `TeamModel`.
- **Production schema is additive-only, forever.** The scorecard blob evolves only
  Codable-forward-compatibly (additive optional fields).
- **Built-in catalog rows:** well-known UUID, idempotent seed, earliest-`createdAt`
  dedupe sweep, duplicate-tolerant reads. Same pattern for the future Settings row.
- **Never gate gameplay, resume, or history rendering** on sync state, iCloud account
  presence, or catalog presence. Signed-out is a first-class configuration.
- **Sync is silent.** No product surface reacts to sync events; the
  `eventChangedNotification` hook is debug diagnostics only.
- **iOS 18.6 floor:** no iOS 27 APIs (`.codable`, observers, sectioned queries) in 1.0.
- **Simulator is not a sync sign-off environment.** Two physical devices, always.
