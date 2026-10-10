# SyFive — Project Guard Rails

**Project-level. SyFive only.** Companion to `00A_STUDIO_CONVENTIONS.md`.
Version 1.1 · 10 October 2026 · Ships in every agent prompt, alongside `00A`, `00_DECISION_LEDGER.md`
and the task's own documents.

---

## 0. What this is

`00A` holds the studio's conventions. It is identical in every project and is canonical: this
document does not restate it. `00B` holds what only SyFive has: its exceptions to `00A`, its
stop conditions and prohibitions that name SyFive's documents, types and ledger rows, its build
and test commands, and its pre-archive checklist.

**Authority, in order:**

1. `00_DECISION_LEDGER.md` is HEAD for every design ruling (D-001).
2. `00A` governs how any agent session runs.
3. `00B` governs what is specific to SyFive.
4. `ENGINEERING_GUIDELINES.md` governs how SyFive's code is written.
5. The task's design document governs the task.

Where two of them seem to disagree, that is a stop condition (`00A` §4). Do not prefer either.

**How `00B` grows.** As `00A` §0 says: a lesson from SyFive goes into SyFive's ledger first, and
into `00B` once it is a standing rule for SyFive's sessions. When Syderal or a later project needs
the same rule, it is promoted to `00A` in project-neutral terms, and this document cites it instead.

---

## 1. Exceptions to `00A`

There is one exception, ledgered as `00A` requires.

**E-1 · Document history (D-001). Exception to `00A` §1.** SyFive's design documents are
**immutable once delivered**. A newer document that changes an earlier ruling carries a
**Supersessions** block quoting what it overrides, and the ledger row is rewritten with its source
chain extended. Nothing else in `00A` §1 changes for SyFive: numeric prefixes, SCREAMING_SNAKE_CASE,
letter suffixes for companions, and a permanent, append-only ledger.

*Why it stays:* SyFive's whole corpus, `00` to `17`, is built this way, and its ledger chains
(`09 §1.5 → 14 §2.1 → 15 §9`) are the record of how rulings moved. Switching to rewrite-in-place
mid-release would leave half the corpus in each style. Decided by Pops, 10 October 2026.

What `00A` §1 calls a decision log is, in a SyFive design document, its **Locked decisions**
section: each ruling with its rationale.

---

## 2. Stop conditions (SyFive)

These are in addition to `00A` §4. Halt and ask; do not resolve inline.

| Condition | Why |
|---|---|
| A change to any Game Night payload's shape, to `GameNightMessageKind.appProtocolVersion`, or to SyLib's transport version | A host declines any joiner whose app version differs. Shipped and new builds would stop sharing a table (D-131) |
| A change to any SwiftData model or attribute, in SyFive or in SyLib's shared models | Each app's CloudKit schema must be deployed to Production first (D-026), and SyLib's shared models are in **both** apps' schemas (`14 §1.4`) |
| A SyLib edit the task does not name, or a SyLib edit that changes a default or a public signature | SyLib is shared with Syderal. Additive changes with tests only, and only when named (`16 §2.1`) |
| Player-facing text the task does not give verbatim: UI copy, alerts, commentary lines, Help, App Store metadata | Copy is Pops's. The agent pastes it; it never writes it |
| A change that would move `onWillSpeak` below the mute, or alter what proximity mutes | A host muted by its button or by Sound Off still broadcasts to its guests (D-130, D-GNP-019). Proximity's rules are D-GNP-001 to D-GNP-021 (`16_GAME_NIGHT_PROXIMITY_MUTE`) |
| A scoring case not settled by D-003 to D-005 or `02_DATAMODEL_DESIGN` §4 | The rules register is the ledger plus `02`. Do not improvise a ruling |
| A change to dice physics tuning, `DiceRoller.Config`, or the fairness certification | The certification was measured at one tuning (p = 0.217 over 10,000 rolls) and is shown to players |
| SyLib's or SyFive's suite total falls without a deletion the task names | A suite that silently shrinks has stopped testing something (§5) |
| The pinned test destination (§5) is unavailable | `00A` §7. Never substitute another device or runtime |

---

## 3. Standing prohibitions (SyFive)

In addition to `00A`. These apply to every task, in perpetuity.

- **"Yahtzee" never appears** in any player-facing string or in App Store metadata. The game is
  **Yatzy**, and the award is the **Yatzy bonus** (`14_APPSTORE_COPY`, the trademark note;
  `15_HELP_SCREEN` §L7). Internal identifiers that already contain it, such as
  `LegacyYahtzeeRepair`, are renamed only by a task that names them.
- **The calm ethos is a product filter** (D-006). No burst or explosion motion and no casino
  grammar (D-069). In UI copy, the exclamation point is reserved for the Yatzy celebration
  (`13_HOLD_HINT_DESIGN`).
- **Snark targets dice and decisions, never people** (D-082). The commentator never refers to House
  Records (D-111). No anti-titles, ever (D-103).
- **The store and the catalogue seed are SyFive's own** (D-129). Never adopt
  `makeScoringContainer`, `makeInMemoryScoringContainer` or `seedCatalogGame`. The Yatzy catalogue
  row keeps its fixed id, `Game.builtInYatzyID`.
- **No stored aggregates.** Statistics and records are computed on read (D-114). Game Night adds no
  schema (D-064).
- **Commentary keeps SyLib's default queue policy**, `.dropWhileSpeaking` (D-078). Never `.queue`.
- **`matchAbandoned` is sent only by a host that is ending Game Night** (D-135).
  `leaveSessionOnThisDevice()` is never used at the table (`14 §3.12`).
- **The Syderal-style reshape is deferred** (D-128). Without a task that names it, do not introduce a
  bridge type for `GameNightMatchHost`, module import boundaries, or a change to the app target's
  default actor isolation.
- **Unit tests use Swift Testing** (`@Test`, `#expect`). UI tests stay on XCTest, which UI testing
  requires. Never both in one target.
- How code is written (one view per file, previews, theming, enums over strings, `AppLogger` and
  never `print()`) is in `ENGINEERING_GUIDELINES.md`, and is not repeated here.

---

## 4. Session start

1. Read `00_DECISION_LEDGER.md`. It comes first because it is the only place a superseded ruling is
   visibly current.
2. Read `00A` and this document.
3. Read the task, and only the documents it names as inputs. SyFive's design documents are in
   `Docs/Requirements/` and `Docs/SyLib/`. SyLib's usage docs are in the package's `Docs/`.
4. Inspect the existing tree, and extend what is there.

---

## 5. Validation (SyFive's commands)

`00A` §7 and §8 govern, and override any agent-side memory that says otherwise (for example,
"fix every warning after every build"). These are SyFive's actual commands.

1. **`BuildProject`** after any code change, incrementally across multi-file edits
   (`ENGINEERING_GUIDELINES.md`, Validation).
2. **SyFive's suite** on the pinned destination:

   ```
   xcodebuild test -project SyFive.xcodeproj -scheme SyFive -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6'
   ```

   The destination is the deployment floor (iOS 18.6) on the smallest supported phone. Report the
   destination string and the run's own test total in the session summary. Redirect output to a
   file if it will be searched more than once, and do not re-run a suite just to read it
   differently. This command is the one sanctioned use of `xcodebuild` from the shell for testing:
   no Xcode tool can pin a destination.
3. **SyLib's suite**, when a task touches SyLib, from the package folder:

   ```
   xcodebuild test -scheme SyLib-Package -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6'
   ```

   Never `swift test`: on macOS every `#if os(iOS)` suite compiles away and the run reports success
   without running it. Check the total against the previous run's, plus additions, less named
   deletions.
4. **Syderal compatibility**, when a task changes SyLib: build Syderal against the changed SyLib and
   run its suite on the same destination, from Syderal's project folder. Syderal is never edited or
   archived from a SyFive session. A Syderal failure is a stop condition (§2).

---

## 6. Pre-archive checklist

Before any archive, TestFlight or App Store build:

- In `Utilities/AppConfig.swift`, every flag is `false`: `DebugLayout.isEnabled`,
  `DebugFeel.showFeelBoard`, `DebugDice.showPhysicsSliders`, `DebugDice.showHarness`,
  `DebugDice.logRollDiagnostics`, `DebugCloudKit.runSchemaExercise` and
  `DebugGameNight.showLogs`.
- `MARKETING_VERSION` is the release version in **both** of the app target's configurations.
- CloudKit Production matches Development for `iCloud.com.syzygysoftwerksllc.SyFive` (D-026).

---

## 7. Adopting `00A` and `00B`

`00A` §11 says a project adopts it by **removing what it duplicates**, not by adding beside it. This
is SyFive's version of `00A`'s Task A-1. Run it **before `15`**: nothing is in flight.

### Task A-1 · SyFive · Adopt `00A` and `00B`

**Inputs:** `00A`, `00B`, `ENGINEERING_GUIDELINES.md`, `00_DECISION_LEDGER.md`, `IMPLEMENTATION_STATUS.md`,
the repo-root `README.md`, `SyFive.xcodeproj/project.pbxproj`, and the §9 ledger sections of `15`, `16`
and `17` and §12 of `16_GAME_NIGHT_PROXIMITY_MUTE.md` (for item 4).

**Deliverable:** both documents in `Docs/Requirements/`; every rule they carry removed from where
SyFive restated it; the test targets lowered to the floor.

**Done when:**

1. `00A_STUDIO_CONVENTIONS.md` (Syderal's v1.7, byte for byte) and `00B_SYFIVE_GUARDRAILS.md` sit in
   `Docs/Requirements/` beside `00_DECISION_LEDGER.md`.
2. The ledger's "How this file works" section gains one bullet: "`00A` (studio, canonical) and `00B`
   (SyFive) ship with this file in every agent prompt." The repo-root `README.md` gains a short
   **Documentation** section that lists `Docs/Requirements/00A_STUDIO_CONVENTIONS.md` (studio-level,
   canonical, cited rather than restated), `00B_SYFIVE_GUARDRAILS.md` (SyFive's rails) and
   `00_DECISION_LEDGER.md` (HEAD for design rulings). Nothing else in the README changes. Its stale
   platform line ("iOS 17+"; the app's floor is iOS 18.6) is reported, not fixed.
3. Each of these `ENGINEERING_GUIDELINES.md` sections is changed as stated, and nothing else in the
   file changes:

   | Section | Change |
   |---|---|
   | Folder Structure | "New feature areas get their own subfolder." becomes "A new folder is a stop condition (`00A` §10)." The root rule ("Do not add files to the root `SyFive/` target directory") and the file map stay |
   | Enums Over Strings | The last bullet ("If a strings/numbers smell is found during a task, fix it in the same PR…") becomes "A strings/numbers smell outside the task is reported, not fixed (`00A` §3)." |
   | Scope Control | The opening sentence ("Keep refactors mechanical unless the task explicitly asks for design or behavior changes.") stays. Add after it: "Scope: `00A` §3." The four mechanics bullets stay |
   | File Access | Add one line at the end: "Anything beyond one plain command is a short `python3` script (`00A` §9)." |
   | Validation | Insert a new step 3: "Run the suites on the pinned destination (`00B` §5)." The current steps 3 and 4 become 4 and 5. Add after the list: "Warnings: `00A` §8." |
   | Testing | "Tests are opt-in. Add or run tests only when explicitly requested." becomes "Tests are added or run when a task names them. When they run, `00A` §7 and `00B` §5 apply." The rest of the section is deleted |
   | AppConfig Guards | The flag list is replaced by "Before shipping: `00B` §6." The section's first sentence stays |

4. **The ledger is brought up to date in one pass**, so that every row this series cites exists before
   `15` starts:
   - **D-001** is rewritten to the text in §9, keeping its ID. **D-142** and **D-143** are added.
   - Every row in `15` §9, `16` §9 and `17` §9 is pasted as written: D-078, D-077 and D-081 replace their
     rows; D-128 to D-141 are new. `15` §9 names the headings, including the new **Platform & data**
     heading, placed after Governance.
   - **D-GNP-001 to D-GNP-021** from `16_GAME_NIGHT_PROXIMITY_MUTE.md` §12 are pasted under a new
     heading, **Game Night proximity**, after the Game Night Theater Feel table. Each row keeps its
     ruling text verbatim, with its rationale after it in italics, and the source
     `16_GAME_NIGHT_PROXIMITY_MUTE §12`.
   - **D-023**'s container name is corrected to `iCloud.com.syzygysoftwerksllc.SyFive`, the container
     `SyFiveApp.swift` builds. Nothing else in that row changes.
5. `project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET` is `18.6` for `SyFiveTests` and `SyFiveUITests`, in
   both configurations (the four lines that read `26.2`). The app target is untouched.
6. SyFive's suite builds and passes on the pinned destination (§5.2). **If a test uses an API newer
   than iOS 18.6, stop and report it.** Do not edit the test (`00A` §7).
7. **The grep test** (`00A` §11): each phrase below returns no hit, or one, outside `00A` and `00B`:
   "fix it in the same PR", "Tests are opt-in", and "New feature areas get their own subfolder".
8. `IMPLEMENTATION_STATUS.md`'s pre-ship flag list (line 376) is replaced by "Before shipping: `00B` §6."
9. Report, without fixing: `ENGINEERING_GUIDELINES.md`'s file map no longer matches the tree. It lists
   `Dice/`, `Domain/Scoring/`, `Domain/Values/` and `Persistence/Conversion/`, which are gone; it
   leaves out `App/`, `Feel/`, `Persistence/Migration/`, `Views/Stats/` and `Views/HouseRecords/`; and it
   says `Utilities/` holds `AppLogger` and `AppUpdateChecker`, where it holds only `AppConfig.swift`.

**Do not:** change any rule's meaning; delete a ledger ID; touch a design document `01` to `17` (item 4
reads them; it does not edit them); touch `ENGINEERING_GUIDELINES.md` sections not in the table; change
the app target's deployment target or any other line of Pops's `project.pbxproj` edits.
A rule that seems to need revising is a stop condition here.

---

## 8. Changes to `15`, `16` and `17` that come with adoption

Those three were written before `00A` reached SyFive. Pops replaces them with the revised copies
delivered with this document. They differ only as follows:

- Each document's "Ship with every prompt" line names `00A` and `00B`.
- **No task asks the agent to run `git`** (`00A` §9). Creating branches (`15` §3, `16` §3) and
  merging (`17` §5) are Pops's steps.
- Test runs cite the pinned destination in `00B` §5, and `16` §2.1's Syderal check cites `00B`
  §5.4.
- **Revised again on 10 October 2026** after the agent's first read: the release is **1.1.0**
  (already set by Pops; the live store version is 1.0.3); SyLib work goes on the existing branch
  `syfive-reintegration`; Pops's `project.pbxproj` edits are the baseline; the ledger rows are pasted
  by A-1, not by each phase; `16` §4.2 names the SyLib test it re-pins and the stale comment it
  fixes; `16` §4.6 authorises `SyFiveTests/Commentary/` and carries twenty lines per pack; D-130 and
  D-132 are reworded to match what `GameNightProximity` does; and `17` §6.1 gives A10 a state table.
- "Stop and report after each one" now reads: one task per session, reported in `00A` §6's
  form.

---

## 9. Ledger rows

D-001 replaces its row. D-142 and D-143 are new, under Governance.

| ID | Current ruling | Source → chain |
|---|---|---|
| D-001 | **SyFive exception to `00A` §1: documents are immutable once delivered.** Overrides travel through a Supersessions block in the newer document, plus a rewrite of the affected row here. This ledger is HEAD and accompanies every agent prompt, with `00A` and `00B`. | Session 05 · `05 §1` → `00B` E-1 (exception kept by Pops, 10 Oct 2026) |
| D-142 | **`00A_STUDIO_CONVENTIONS.md` is canonical for how sessions run, and `00B_SYFIVE_GUARDRAILS.md` holds SyFive's own rails.** Project documents cite them rather than restate them. Where `00A` and a SyFive rule conflicted on folders and on fixing out-of-scope smells, `00A` won. | `00A` §11 → `00B` §7 |
| D-143 | **Tests run at the deployment floor**: iPhone SE (3rd generation), iOS 18.6, pinned in `00B` §5. Both test targets are set to iOS 18.6. | `00A` §7 → `00B` §5 |

---

## 10. Decision log

| Version | Decision | Rationale |
|---|---|---|
| 1.1 | A-1 also lists `00A` in the README, pastes the series' ledger rows and the D-GNP rows, corrects D-023, and covers `IMPLEMENTATION_STATUS.md`; the Scope Control sentence is kept | The agent's first read found a README requirement in `00A` §11, rows cited before they existed, a container-name typo, and a fourth copy of the flag list. Keeping "Keep refactors mechanical…" avoids a meaning change A-1 forbids |
| 1.1 | `00A` §8 overrides agent-side memory about warnings | The agent's own memory said to fix every warning; `00A` §8 says report those outside the task |
| 1.0 | `00A` is adopted verbatim, with a SyFive companion rather than a SyFive rewrite | `00A` is identical in every project by its own rule; a rewritten copy would drift. Pops, 10 Oct 2026 |
| 1.0 | D-001 is kept as SyFive's one exception to `00A` §1 | The corpus and its ledger chains are built on immutable documents and Supersessions; switching mid-release would split the corpus. Pops, 10 Oct 2026 |
| 1.0 | `00A` wins over SyFive's folder rule and its fix-smells-in-the-same-PR rule | Both let a session act outside its task, which `00A` §3 and §10 exist to stop. Pops, 10 Oct 2026 |
| 1.0 | Adoption runs before `15` | Nothing is in flight, and `15` to `17` then run under the rails. Pops, 10 Oct 2026 |
| 1.0 | The test floor is iPhone SE (3rd generation) at iOS 18.6; the test targets are lowered from 26.2 | `00A` §7 requires the floor. Matching Syderal's destination keeps one simulator for the studio. Pops, 10 Oct 2026 |
| 1.0 | Player-facing copy the task does not supply is a stop condition | Copy is Pops's to write or approve. Copy is drafted upstream and pasted verbatim, as `16` §5 does |
