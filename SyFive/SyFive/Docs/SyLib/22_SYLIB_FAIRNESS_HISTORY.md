# SyLib fairness: full batch runs, run info, a certification history, and run comparison

**Status:** Ready for the agent once `21` §4 is complete. Written 11 October 2026. **Revision 2,
12 October 2026**, answers the agent's pre-start questions; no task had run. Changes:
- §4.1 builds the CSV only when Share is tapped.
- §4.2's Tuning line describes the batch preset and the app tuning before the batch.
- §4.3 records #3 and names folders by day.
- Run descriptions say `Config.batch`.
- Test totals are updated.

**Revision 3, 12 October 2026:** §4.1 step 3 is replaced after its stop. `DiceStatistics` isn't
main-actor isolated or `Sendable`, so a `Transferable` can't hold it. The CSV is now built on the
main actor when the button is tapped. §4.1 steps 1, 2, 4 and 5 are done, and only step 3 remains.

**Scope:** `sylib-swift` on branch `syfive-reintegration` (§4.1 to §4.4), and `SyFive` docs and
ledger (§4.5). Ships in 1.1.0. **`22` does not change the certification.** `builtIn` and the
fairness screen keep July 2026's numbers here. The new certification comes in `23`, written once
Pops has made five full iOS 27 runs with §4.1 and §4.2 in the build (§2.5). Syderal doesn't import
SyLibDice, so it only has to build (`00B` §5.4).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md` (v1.2), this document. For §4.3, Pops attaches the iOS 27 run files from
11 and 12 October. Pops places them himself before §4.3 (§3).

**Authorisation:** `00B` §2 makes any change to dice physics, `DiceRoller.Config` or the fairness
certification a stop condition. This document authorises:
- §4.1: a change to how the harness records a run;
- §4.2 and §4.4: additions to the harness;
- §4.3: new history files.

It authorises nothing else. `DiceRoller.Config`, the physics and `FairnessCertification.builtIn`
stay untouched.

---

## Supersessions

| Overrides | With | Why |
|---|---|---|
| `21` header: "the last document of the 1.1.0 reintegration (`15` to `21`)" | The series is `15` to `23`. `22` and `23` both ship in 1.1.0 | Pops, 11 Oct 2026: 1.1.0 ships a full iOS 27 certification (§2.5) |
| `21` §5 step 2: merge SyLib once `21` §4 is done | Merge SyLib once `21` §4, `22` §4.1 to §4.4 **and** `23` are done. `23` adds its own device check to step 1 | Same |
| `00B` v1.1 §2: "p = 0.217 over 10,000 rolls" | `00B` v1.2 names `FairnessCertification.builtIn` and the history, and carries no figures, so it can't go stale | 0.217 came from an earlier pre-SyLib run, recorded in `IMPLEMENTATION_STATUS.md` line 47. The shipped certification has been July 2026's run (§1) |

---

## 1. Why

**The harness throws most of each run away.** `DiceStatistics` keeps a sliding window. Past 11,000
samples it trims back to the latest 10,000 (`Analytics/DiceStatistics.swift`, `maxWindow` and
`targetWindow`). The window dates from the HUD performance fix (`DICE_RETROSPECTIVE.md`, "Trimming:
batched"). It was meant to keep gameplay light, but it applies to batches too.

The HUD's batch buttons run 1,000 or 10,000 rolls, and certification runs use 10,000. That's 50,000
dice results, of which the report and the CSV keep about the last 10,000. Both certification CSVs
show it: roll IDs 7,840 to 10,000, which is 2,161 rolls and 10,805 samples. So
`FairnessCertification.builtIn` describes 21.6% of the July run.

The window keeps the latest rolls whatever their faces, so it isn't biased, and the results stand.
But every run costs 2+ hours for 50,000 results and keeps a fifth of them. §4.1 keeps the whole batch.

**There is no history.** `builtIn` holds one run. Replacing it loses the record that the dice were
fair on the earlier OS. SyFive deploys to iOS 18.6, so players run more than one physics stack.

**Two runs so far**, both on the same iPad Pro (M5), rolled under the batch preset (`Config.batch`,
as every batch is) with the app's tuning at `Config.certified`, and both the last 2,161 rolls of a
10,000-roll batch. A third, #3, came on 12 October; §4.3 records it.

| | #1 · July 2026 · iOS 26 | #2 · 11 Oct 2026 · iOS 27 |
|---|---|---|
| Samples / rolls kept | 10,805 / 2,161 | 10,805 / 2,161 |
| Chi², p | 3.6554, 0.6024 PASS | 4.0863, 0.5389 PASS |
| Serial r / runs Z | +0.000442 / −0.086 | −0.021965 / +0.282 |
| Rescued (stacked) | 584 (433) | 177 (41) |
| Stuck rerolls | 129 (5.97%) | 114 (5.28%) |
| Average alignment | 0.9960 | 0.9963 |

### 1.1 What comparing them found (Claude, by hand, 11 Oct 2026)

Same device, so the OS is the only thing that changed. These findings cover the kept windows.

- **iOS 26 had a die 0 problem.** 386 of its 584 rescues were die 0, and 367 of those were stacked
  rescues: 17% of die 0's rolls. On iOS 27 die 0 had 48, in line with the other dice. Die 0 spawns in
  the (−x, −z) slot. Faces after those rescues were even, so fairness wasn't affected.
- **No change in faces.** Two-run homogeneity gives p 0.829 overall, and 0.19 to 0.90 per die.
  Distinct faces per roll match theory in both runs.
- **Rolls settle faster on iOS 27:** a mean of 0.907 s against 0.938 s (KS D 0.085).
- **Unchanged:** stuck rerolls (z 1.0), clean-die alignment, where dice land, and the per-die stuck
  pattern (die 2, the centre slot, is lowest in both).
- **Rescued dice lean toward 1 in both runs**, about 19–21% ones in every rescue kind, from 760
  pooled dice (z ≈ 2.4). It's weak, and full runs should settle it.

---

## 2. Locked decisions

**2.1 A batch keeps every roll** (D-150). From the moment a batch starts, `DiceStatistics` stops
trimming, and it stays that way until Reset. Gameplay that never starts a batch keeps the window, so
its memory is unchanged. Pops, 11 Oct 2026.

**2.2 The report names where the run was made.** Its header gains the device identifier, OS version
and build, simulator or device, app version, and whether the tuning is certified. The CSV format is
unchanged, so earlier runs still read. Pops, 11 Oct 2026.

**2.3 SyLibDice keeps a certification history** in `Sources/SyLibDice/Docs/FairnessHistory/` (D-149).
- Each run gets a folder holding its report and CSV, plus a `DIFF.md` against the run before it.
- An index `README.md` gives one row per run.
- Runs are never edited or deleted.
- The top-level `Docs/DICE_FAIRNESS_REPORT.txt` and `Docs/DICE_FAIRNESS_RUN.csv` keep their names,
  and always hold copies of what `builtIn` certifies.

Pops, 11 Oct 2026.

**2.4 #1, #2 and #3 are recorded as what they are:** the last 2,161 rolls of a 10,000-roll batch. In
`22`, #1 stays current and `builtIn` is unchanged. *(Follows from §2.5.)*

**2.5 1.1.0 ships a certification from five full iOS 27 runs: 50,000 rolls, 250,000 dice results.**
With §4.1 and §4.2 in a Debug build, Pops runs five separate 10,000-roll batches on the iPad Pro
(M5), resetting before each and exporting after each (V1). Five runs are used instead of one
50,000-roll batch for four reasons:
- each run is saved as it finishes, so a crash or a flat battery loses at most one run;
- the iPad gets breaks, so heat isn't a variable;
- the run-to-run comparisons show whether the runs agree;
- no code change is needed.

Claude then writes `23` from the five reports and CSVs. `23` pools them (§2.6), updates `builtIn`,
the top-level files and the history, and re-pins the tests. The release waits for `23`. Pops,
11 Oct 2026.

**2.6 Only full runs certify. Among them: pool, never pick.** Both rules were set before any full
run existed.
- **Full runs only.** A run certifies only if it was recorded with D-150 in place, so it keeps its
  whole batch. Windowed runs (#1 to #3) are history only. This is about how a run was recorded, not its
  result, and it applies to every run the same way.
- **Pool, never pick.** Every full run on the same OS, rolled under an unchanged `Config.batch` and
  started from the certified app tuning, counts, and none is
  dropped, including one that fails on its own:
  - face counts are summed;
  - serial r and runs Z are recomputed on the runs joined end to end, in run order;
  - each run keeps its own history row, and a pooled row on top becomes Current;
  - runs from different OS versions or tunings are never pooled.

**Same OS** means the same version, major.minor, as the report's Run line shows. All five iOS 27
runs pool into one certification, and none is dropped. If an iOS update lands partway through, stop
and ask before mixing versions. `23` certifies the pool: 50,000 rolls and 250,000 dice results.
Pops, 11 Oct 2026.

**2.7 Runs are compared in Swift.** SyLibDice's `DiceRunComparison` writes the comparison as
Markdown, and the harness's Compare button runs it on device. It follows `DiceReportGenerator`. The
deprecated Python script is removed. Pops, 11 Oct 2026.

**2.8 `FairnessCertification` keeps its fields.** The platform and history live in the docs.
*(rec., Pops chose the docs-only option.)*

---

## 3. Before starting

- `21` §4 is complete, and SyLib's suite is at 1133.
- `git diff` is not available to agents. Pops confirms that `DiceRoller.Config` is unchanged since
  July 2026. It was byte-identical at the fairness ruling on 11 Oct 2026.
- For §4.3: Pops places the two iOS 27 runs' files in the SyLib repo at their final paths (§4.3
  step 1). Check each before starting:
  - `2026-10-11_iOS-27/REPORT.txt` reads "Samples: 10805 Rolls: 2161" and "chi²: 4.0863 p:
    0.538931 PASS" under Overall.
  - `2026-10-12_iOS-27/REPORT.txt` reads "Samples: 10805 Rolls: 2161" and "chi²: 7.9190 p:
    0.159491 PASS".
  - Each `RUN.csv` has 10,805 data rows.

  If any check fails, stop (`00A` §4).

---

## 4. Tasks

One task per session, reported in `00A` §6's form. §4.1 and §4.2 come first, because V1 (the five
full runs) needs both. §4.3 and §4.4 can run while V1 does.

### 4.1 SyLib: a batch keeps every roll

On `sylib-swift`, branch `syfive-reintegration`.

**1. `DiceStatistics`.** In `Analytics/DiceStatistics.swift`:
- Add `public private(set) var keepsEveryRecord = false`, documented as: "True once a batch has
  started. While true, the history is not trimmed. Cleared by `reset()`."
- Add `public func beginKeepingEveryRecord()`, which sets it to `true`.
- In `addRoll`, skip the trim (the `if history.count > maxWindow { … }` block) while
  `keepsEveryRecord` is true. Leave the window's numbers and the trim itself as they are.
- In `reset()`, set `keepsEveryRecord = false`.

**2. `DiceRoller`.** In `startBatch(count:)`, call `statistics.beginKeepingEveryRecord()` before the
first roll. Nothing in `stopBatch()` or batch completion clears it. If it were cleared at the end of
a batch, the next gameplay roll would trim the batch away before it could be exported.

**3. The CSV is built only when the button is tapped** (revision 3). In `Views/DiceDebugHUD.swift`,
the header's `ShareLink` builds `stats.csvString()` every time the header redraws, which is every
roll. With whole batches kept, that grows to 50,000 rows per roll. Build it once, on tap, on the
main actor, where the statistics are written and read:
- Replace the `ShareLink` with a `Button` that has the same label (`Label("CSV", systemImage:
  "square.and.arrow.up")` in `.caption`), the same `.bordered` style, and the same `.disabled(stats.
  totalSamples == 0)`.
- Its action:
  1. calls `stats.csvString()`;
  2. writes the result as UTF-8, atomically, to `FileManager.default.temporaryDirectory` as
     `Dice Fairness.csv`, replacing any earlier file;
  3. stores the URL in a new `@State private var csvShareURL: URL?`.

  If the write throws, nothing is presented. This is debug-only, so no error UI is needed.
- Present `.sheet(isPresented:)`, bound to `csvShareURL != nil` and clearing it on dismiss. The sheet
  holds a new private `UIViewControllerRepresentable`, `CSVShareSheet`, wrapping
  `UIActivityViewController(activityItems: [url], applicationActivities: nil)`.
- Delete the now-unused private `CSVExport`.

The exported file's name, type and contents are unchanged. `DiceStatistics` and its isolation are
not touched.

**4. Tests**, named after the rule, in `Tests/SyLibTests/SyLibDice/Analytics/DiceStatisticsTests.swift`:
- `aBatchKeepsEveryRoll`: call `beginKeepingEveryRecord()`, then add 2,500 five-dice rolls.
  `totalSamples`, `records.count` and the face counts' sum are all 12,500.
- `normalPlayStillUsesTheWindow`: the same 2,500 rolls without it; `totalSamples` is at most 11,000.
- `resetTurnsTheWindowBackOn`: after `beginKeepingEveryRecord()` and `reset()`, `keepsEveryRecord`
  is false.

**5. Docs.** In `Docs/DICE.md`, at "**The history is a window.**" (line 744), add: "A batch turns the
window off: `startBatch(count:)` calls `beginKeepingEveryRecord()`, and every record is kept until
`reset()`. Before SyLib's 1.1.0 changes, batches were windowed too, so a 10,000-roll run kept only
about its last 2,161 rolls." Document the property and the method where `DiceStatistics`'s members
are listed.

**Done when:**
- The property, method, trim condition, reset, roller call, CSV-on-tap, tests and docs are as above.
- SyLib's suite passes on the pinned destination (`00B` §5.3) at 1136 (1133 plus these 3).
- Syderal builds and passes with no source edit (`00B` §5.4).

**Do not:**
- Change the window's sizes, the HUD's batch counts or `Config.batch`.
- Change anything else in how a roll is recorded, or the exported CSV's contents.

**Check:** V1.

### 4.2 SyLib: the report names the device, OS and tuning

After §4.1. Only the report's header changes. The CSV format stays the same, so old runs still read.
For #1 to #3, the device and OS are recorded in the history index.

**1. `DiceRunInfo`.** New file: `Analytics/DiceRunInfo.swift`, inside `#if os(iOS)`.

```swift
/// Where a fairness run was made: the device, OS build and app build.
public struct DiceRunInfo: Sendable, Equatable {
    /// The model identifier, for example "iPad16,6". On the simulator, the simulated model's.
    public let device: String
    /// "iPadOS" for an iPad identifier, otherwise "iOS".
    public let osName: String
    /// Major.minor.patch, for example "27.0.1".
    public let osVersion: String
    /// The OS build, for example "24A335".
    public let osBuild: String
    public let isSimulator: Bool
    /// The app's short version and build, for example "1.1.0 (42)".
    public let appVersion: String

    public init(device: String, osName: String, osVersion: String, osBuild: String,
                isSimulator: Bool, appVersion: String)

    /// This process's values. Safe to read from any isolation domain.
    public static var current: DiceRunInfo { get }

    /// One line, for example "iPad16,6 · iPadOS 27.0.1 (24A335) · device · app 1.1.0 (42)".
    public var summary: String { get }
}
```

Where `current` gets each value:
- `device`: `uname()`'s `machine`. Under `targetEnvironment(simulator)`, use
  `ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]`, falling back to `machine`.
- `osName`: "iPadOS" when `device` starts with "iPad", otherwise "iOS". Don't use `UIDevice`, which
  is main-actor only.
- `osVersion`: `ProcessInfo.processInfo.operatingSystemVersion`, as major.minor.patch.
- `osBuild`: `sysctlbyname("kern.osversion")`. Use "unknown" if the call fails.
- `isSimulator`: `#if targetEnvironment(simulator)`.
- `appVersion`: `Bundle.main`'s `CFBundleShortVersionString` and `CFBundleVersion`, as "1.1.0 (42)".
  Use "unknown" for a missing key.

`summary` writes "simulator" or "device" in the third position.

**2. What the rolls ran under.** Every batch rolls under the fixed `Config.batch` preset. `startBatch`
swaps it in and `stopBatch` puts the app's tuning back. That preset differs from `Config.certified`
in 14 settings, and every certification run so far, July's included, was measured under it
(`DICE.md` lines 225, 329 and 878). So for a batch, the Tuning line must name the preset, plus
whether the app's tuning was certified when the batch started.
- In `Simulation/DiceRoller.swift`, add `public private(set) var appTuningCertifiedAtBatchStart:
  Bool?`, documented as "Whether the app's tuning was `Config.certified` when the most recent batch
  started. Nil until a batch starts."
- In `startBatch(count:)`, set it from `config.isCertifiedTuning` **before** `config = .batch`.
  Nothing clears it.

This adds one stored property to the roller. It's authorised here and changes no physics.

**3. The report header.** New type, in `Analytics/DiceReportGenerator.swift`:

```swift
/// What the rolls in a report ran under.
public enum DiceReportTuning: Sendable, Equatable {
    /// A batch: the rolls ran under `Config.batch`. `appTuningCertified` says whether the app's
    /// tuning was `Config.certified` when the batch started.
    case batch(appTuningCertified: Bool)
    /// Gameplay: the rolls ran under the app's tuning, certified or not, read at report time.
    case app(certified: Bool)
}
```

Change the entry point to:

```swift
public static func generate(from stats: DiceStatistics,
                            runInfo: DiceRunInfo = .current,
                            tuning: DiceReportTuning? = nil) -> String
```

The defaults keep every existing call compiling. Directly after the "══ Dice Fairness Report ══"
line, add two lines:
- `Run: <runInfo.summary>`
- The Tuning line:
  - `.batch(true)`: `Tuning: batch preset (Config.batch); app tuning at batch start: certified`
  - `.batch(false)`: `Tuning: batch preset (Config.batch); app tuning at batch start: MODIFIED`
  - `.app(true)`: `Tuning: app tuning, certified (Config.certified)`
  - `.app(false)`: `Tuning: app tuning, MODIFIED — not the certified tuning`
  - `nil`: `Tuning: not recorded`

Nothing else in the report changes.

**4. The harness passes the tuning.** In `Views/DiceDebugHUD.swift`, the Report sheet passes
`.batch(appTuningCertified:)` with `diceRoller.appTuningCertifiedAtBatchStart` when the statistics
hold any sample whose source is `.batch` and that property isn't nil. Otherwise it passes
`.app(certified: diceRoller.config.isCertifiedTuning)`.

**5. Tests**, named after the rule, in `Tests/SyLibTests/SyLibDice/Analytics/`:
- `theRunInfoDescribesThisBuild`: on the pinned destination, `DiceRunInfo.current` has a non-empty
  `device`, `osVersion` and `osBuild`, `osName == "iOS"`, and `isSimulator == true`.
- `aBatchReportNamesThePreset`: a `DiceStatistics` with one roll, a fixed `DiceRunInfo`, and
  `.batch(appTuningCertified: true)`. The report's second and third lines are exactly `Run:
  iPad16,6 · iPadOS 27.0.1 (24A335) · device · app 1.1.0 (42)` and `Tuning: batch preset
  (Config.batch); app tuning at batch start: certified`.
- `aModifiedAppTuningBeforeABatchIsReported`: the same with `false`; the third line ends
  `app tuning at batch start: MODIFIED`.
- `aGameplayReportNamesTheAppTuning`: `.app(certified: true)`; the third line reads `Tuning: app
  tuning, certified (Config.certified)`.

**6. Docs.** `Docs/DICE.md`:
- a `DiceRunInfo` section next to `DiceReportGenerator`'s;
- `DiceReportTuning`, the new parameters and the header lines in `DiceReportGenerator`'s section;
- `appTuningCertifiedAtBatchStart` with the roller's batch members;
- `DiceRunInfo` in the platform-guard table (`#if os(iOS)` only; no `@available`).

**Done when:**
- The property, the types, the report lines, the HUD call, the tests and the docs are as above.
- SyLib's suite passes on the pinned destination at 1140 (§4.1's 1136 plus these 4).
- Syderal builds and passes with no source edit.

**Do not:**
- Change `csvString()`, `SampleRecord`, `Config.batch`, `Config.certified` or how a batch swaps them.
- Change anything in the report below the two new lines.

**Check:** V1, V2.

### 4.3 SyLib: the history folder, with #1, #2 and #3

After §4.2. Use a Python script for the copies and the row count, not a shell pipeline (`00A`).

**1. The folder:**

```
Sources/SyLibDice/Docs/FairnessHistory/
  README.md                        ← you write (step 2)
  2026-07_iOS-26/REPORT.txt        ← you copy from Docs/DICE_FAIRNESS_REPORT.txt
  2026-07_iOS-26/RUN.csv           ← you copy from Docs/DICE_FAIRNESS_RUN.csv
  2026-10-11_iOS-27/REPORT.txt     ← Pops places (his Dice_Fairness_Report.txt)
  2026-10-11_iOS-27/RUN.csv        ← Pops places (his Dice_Fairness.csv)
  2026-10-12_iOS-27/REPORT.txt     ← Pops places (his Dice_Fairness_01.txt)
  2026-10-12_iOS-27/RUN.csv        ← Pops places (his Dice_Fairness_01.csv)
```

Folders are named by day, so two runs in one month don't collide. July 2026's day isn't recorded,
so that folder keeps its month. Don't rename or edit Pops's files. Run §3's checks on them.

`Docs/DICE_FAIRNESS_REPORT.txt` and `Docs/DICE_FAIRNESS_RUN.csv` stay as they are. #1 is still what
`builtIn` certifies. Confirm by byte comparison that the `2026-07_iOS-26/` copies are identical to
them. `Package.swift` already has `exclude: ["Docs"]` for SyLibDice; confirm it, and don't edit it.

**2. The index,** `FairnessHistory/README.md`, verbatim:

```markdown
# Dice fairness certification history

Every certification run of SyLibDice's dice, newest first. A run is never edited or deleted. What
`FairnessCertification.builtIn` certifies is marked Current, and its report and CSV are also copied
to `Docs/DICE_FAIRNESS_REPORT.txt` and `Docs/DICE_FAIRNESS_RUN.csv`.

**When to add a run:** when the OS changes, when `DiceRoller.Config` changes, or when D-037 requires
one. A run is a 10,000-roll batch of five free dice in the debug HUD's harness, which gives 50,000
dice results. Steps are in `Sources/SyLibDice/Analytics/FairnessCertification.swift`.

**What certifies.** Only full runs, which keep the whole batch, certify. Windowed runs (#1 to #3)
are history only. Full runs on the same OS, rolled under an unchanged `Config.batch` and started
from the certified app tuning, are pooled, and none is ever dropped. A pooled row sits above its
runs and is marked Current.

**Tuning.** Every batch rolls under the `Config.batch` preset, which differs from the gameplay
tuning `Config.certified`. A report's Tuning line names the preset and whether the app's tuning was
certified when the batch started.

**Comparisons.** Each run after the first has a `DIFF.md` in its folder, comparing it with the run
before. Make it in the harness: tap Compare, choose the previous run's `RUN.csv`, then Share the
result into the new run's folder as `DIFF.md`.

| # | Status | Date | Platform | Hardware | Tuning | Kept: samples / rolls | Chi² | p | Serial r | Runs Z | Rescued (stacked) | Stuck rerolls | Avg alignment | Folder |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 3 | History only (windowed) | 12 Oct 2026 | iOS 27 | iPad Pro (M5) | `Config.batch`; app tuning certified; both unchanged since #1 | 10,805 / 2,161 (last of 10,000) | 7.9190 | 0.1595 | −0.002625 | +0.054 | 145 (37) | 95 (4.40%) | 0.9968 | `2026-10-12_iOS-27/` |
| 2 | History only (windowed) | 11 Oct 2026 | iOS 27 | iPad Pro (M5) | `Config.batch`; app tuning certified; both unchanged since #1 | 10,805 / 2,161 (last of 10,000) | 4.0863 | 0.5389 | −0.021965 | +0.282 | 177 (41) | 114 (5.28%) | 0.9963 | `2026-10-11_iOS-27/` |
| 1 | **Current** | July 2026 | iOS 26 | iPad Pro (M5) | `Config.batch`; app tuning certified | 10,805 / 2,161 (last of 10,000) | 3.6554 | 0.6024 | +0.000442 | −0.086 | 584 (433) | 129 (5.97%) | 0.9960 | `2026-07_iOS-26/` |

## Notes

- **#1 to #3 are windowed.** Until SyLib's 1.1.0 changes, the harness kept only about the last
  10,000 samples of a batch, so each of these runs holds the last 2,161 of its 10,000 rolls. The
  window ignores faces, so the kept rolls are an unbiased sample. Later runs keep the whole batch.
- **#2 against #1:**
  - On iOS 26, 386 of 584 rescues were die 0 (367 stacked). On iOS 27 die 0 is in line with the
    other dice.
  - Rescues fell by about 70% overall with the same tuning, which is consistent with
    RealityKit/PhysX changes in iOS 27.
  - Rescued and stuck-reroll dice came up 1 more often in both runs (about 19–24%). That is weak
    evidence (z ≈ 2.4 pooled), and the full runs should settle it.
  - See `2026-10-11_iOS-27/DIFF.md`.
- **#3 against #2:**
  - Faces match (homogeneity p 0.842), and rescues and stuck rerolls are within noise (145 against
    177, 95 against 114).
  - Die 0 still has the most stacked rescues (19), far below iOS 26.
  - Face 6 is a little low in all three windows (16.14%, 16.07%, 15.83%). That's under 1 point,
    and the full runs will measure it.
  - See `2026-10-12_iOS-27/DIFF.md`.
- **#1:** the certification SyFive 1.0 shipped with.
- Earlier runs on older builds, including a full 50,000-result run at p 0.217, are described in
  `DICE_FAIRNESS_TESTING.md`. They have no report or CSV here, so they are not listed.
```

**3. The update comment on `builtIn`.** In `Analytics/FairnessCertification.swift`, replace the doc
comment above `static let builtIn` with the text below. Leave the values alone.

```swift
    /// The certified run shipped with SyLibDice. Batches roll under `DiceRoller.Config.batch`,
    /// started from the certified app tuning (`Config.certified`).
    /// Every run, current and past, is listed in `Sources/SyLibDice/Docs/FairnessHistory/README.md`.
    ///
    /// To certify a new run:
    ///   1. In the debug HUD, tap Reset, then run a 10,000-roll batch with all five dice free.
    ///      The batch keeps every roll (50,000 dice results).
    ///   2. Tap Report and export the CSV. The report's Run and Tuning lines say where it was made.
    ///   3. Add a folder `FairnessHistory/<yyyy-MM-dd>_iOS-<n>/` with the report as `REPORT.txt` and the
    ///      CSV as `RUN.csv`. In the harness, tap Compare against the previous run's `RUN.csv` and
    ///      save the result there as `DIFF.md`.
    ///   4. Add the run's row to the index. Only full runs certify. Pool it with every full run on
    ///      the same OS and tuning, never dropping one, and add or update the pooled row. Never edit
    ///      or delete an old run.
    ///   5. Copy what is now certified to `Docs/DICE_FAIRNESS_REPORT.txt` and
    ///      `Docs/DICE_FAIRNESS_RUN.csv`, update the values below, and re-pin the two regression
    ///      tests in `FairnessCertificationTests`.
```

**4. Docs.**
- `Docs/DICE.md`, the `FairnessCertification` section: after "The built-in run is dated "July
  2026"…", add: "That run is the last 2,161 rolls of a 10,000-roll batch, because batches were
  windowed then. Every certification, current and past, is in
  `Sources/SyLibDice/Docs/FairnessHistory/README.md`."
- `Sources/SyLibDice/Docs/DICE_FAIRNESS_TESTING.md`: under the historical notes at the top, add:
  "**Certification history (2026-10):** this document describes the method and the early runs.
  Runs from July 2026 on, and the current certification, are in `FairnessHistory/README.md`. Until
  SyLib's 1.1.0 changes, the harness kept only about the last 10,000 samples of a batch."

**Done when:**
- The folder, the seven files and the index are as above, and the byte checks pass.
- The comment and the docs are as above. `builtIn`'s values and the top-level files are unchanged.
- SyLib's suite passes at 1140. These are docs and a comment, so the total doesn't change.

**Do not:**
- Change `builtIn`'s values, the regression tests, or the top-level report and CSV. That is `23`.

### 4.4 SyLib: run comparison in Swift, with a Compare button in the harness

After §4.3. This follows how the report already works: `DiceReportGenerator` makes it in Swift.
`analyze_dice_fairness.py` is deprecated, and step 7 removes it.

**1. The CSV header in one place.** In `Analytics/DiceStatistics.swift`, move the header string out
of `csvString()` into `public static let csvHeader: String`, and have `csvString()` use it. The
output doesn't change.

**2. Reading a run back.** New file: `Analytics/DiceRunCSV.swift`, inside `#if os(iOS)` and
`@available(iOS 18, *)`, like `DiceStatistics`.

```swift
/// Reads a run exported by `DiceStatistics.csvString()` back into sample records.
public enum DiceRunCSV {
    public enum ReadError: Error, Equatable {
        /// The first line is not `DiceStatistics.csvHeader`.
        case wrongHeader
        /// A row with the wrong field count or a value that doesn't parse. The line is 1-based.
        case badRow(line: Int)
        /// The row count is not a multiple of five, so the run isn't whole rolls.
        case notWholeRolls(rows: Int)
    }

    public static func records(from csv: String) throws(ReadError) -> [DiceStatistics.SampleRecord]
}
```

- It accepts `\n` or `\r\n` line endings and ignores one trailing empty line.
- `source` parses through `SampleSource(rawValue:)`; an unknown source is a `badRow`.
- `SampleRecord` keeps its internal memberwise init. The reader is in the same module, so no new
  public init is needed.
- A full run is 50,000 rows, so read it in one pass without building intermediate arrays of lines.

**3. The comparison.** New file: `Analytics/DiceRunComparison.swift`, with the same guards.

```swift
/// Compares two runs of the fairness harness and writes the result as Markdown, for a history
/// folder's DIFF.md. `previous` is the older run.
public struct DiceRunComparison {
    public init(previous: [DiceStatistics.SampleRecord], previousName: String,
                previousInfo: DiceRunInfo? = nil,
                current: [DiceStatistics.SampleRecord], currentName: String,
                currentInfo: DiceRunInfo? = nil)

    public let metrics: Metrics       // every number the Markdown shows; see below
    public var flags: [String] { get }
    public func markdown(writtenOn date: Date = .now) -> String
}
```

`Metrics` is a public struct of `let`s holding each value in the sections below, one property per
row, with a pair for previous and current where the row has one. Name the properties after the rows.
The tests read `metrics`, never the Markdown.

**Methods.** These are fixed so results reproduce:
- *p-values for chi²* use the Wilson-Hilferty approximation, the same as `FairnessCertification`.
- *Homogeneity* is a 2×k chi² contingency test with k − 1 degrees of freedom.
- *Two-proportion z* uses the pooled proportion.
- *KS* is the two-sample statistic, with the asymptotic p-value (the Kolmogorov series, 100 terms).
- *Percentiles* are the value at index ⌊p·(n − 1)⌋ of the sorted list.
- *A roll* is the records sharing a `rollID`, in order. Its duration is the first record's
  `rollDurationSecs`.
- A rescue kind containing `floor` counts as floor. Otherwise one containing `wall` counts as wall.
  Anything else counts as stacked.
- Doubles throughout. The CSV's rounding (3 or 4 decimals) is what the run stores.

**Markdown sections**, in this order. Each is a table with one column per run (previous, then
current) and a last column for the test result:
1. **Header:** both names, the samples and rolls of each, each run's `DiceRunInfo.summary` (or "not
   recorded; see the history index" when `nil`), and the date written.
2. **Faces:** counts per face for each run; homogeneity chi² and p, overall and per die.
3. **Shape of rolls:**
   - distinct faces per roll (1 to 5) against theory (6, 450, 3000, 3600 and 720 out of 7776), with
     chi² and p (4 df) for each run;
   - the five-of-a-kind count;
   - the mean sum of five dice (expected 17.5).
4. **Roll timing:** mean, p10, p50 and p90 of roll duration; KS D and p; rolls under 0.1, 0.3 and
   0.5 s.
5. **Rescues and stuck dice:** rescued and stuck totals with two-proportion z; rescue kinds; rescued,
   stacked and stuck counts per die.
6. **Settling:** clean dice (neither rescued nor stuck) with `finalAlign` below 0.999, 0.99 and 0.95.
7. **Where dice land:** mean |x| and |z|, dice beyond 0.10 from centre on either axis, and a chi² of
   face against landing quadrant (sign of x and z; 15 df) for each run.
8. **Rescued faces:** for each run and both pooled, face counts per rescue kind (floor, wall,
   stacked) and for stuck dice, with the share of ones. Give a chi² against even faces for each pooled
   row.
9. **Flags:** the `flags` list, or "None". Flag a line when:
   - any homogeneity p is below 0.01;
   - any two-proportion z has a magnitude of 3 or more;
   - KS p is below 0.001;
   - in either run, one die has more than twice the mean of the other four for rescues, stacked
     rescues or stuck dice (a "slot outlier");
   - any pooled chi² in section 8 has p below 0.05;
   - both runs have a `DiceRunInfo` and their `device` differs. The comparison then mixes hardware
     with OS.

   Each flag names the section and gives the numbers.

**4. The harness's Compare button.** In `Views/DiceDebugHUD.swift`'s `headerRow`, add a **Compare**
button between Report and CSV, in the same bordered caption style. It opens a new internal sheet,
`Views/DiceCompareSheet.swift`:
- A `Form` with two rows:
  - **Previous run:** a "Choose CSV…" button, through `.fileImporter` for `.commaSeparatedText`.
  - **New run:** "This session (N samples)" when the harness has samples, with `DiceRunInfo.current`
    as its info. Otherwise "Choose CSV…". A run from a file can always be chosen instead, and has no
    info.
- A chosen file is shown by name. A file named `RUN.csv` is named by its parent folder, for example
  `2026-10-11_iOS-27`. Open it with `startAccessingSecurityScopedResource()`, and stop accessing once it
  has been read.
- A read error shows under its row in red: "Not a dice run CSV", "Row N doesn't parse", or "Not
  whole rolls (N rows)". This is debug-only text, not player copy (`00B` §2 doesn't apply).
- **Compare** is enabled once both runs are set. It presents `DiceReportSheet` with
  `DiceRunComparison(...).markdown()`. Share is already in that sheet.

The HUD is behind `AppConfig.DebugDice.showHarness`, which is `false` in release builds (`00B` §6).
Nothing here reaches players.

**5. Tests**, named after the rule, in `Tests/SyLibTests/SyLibDice/Analytics/`:
- `aRunSurvivesACSVRoundTrip`: a `DiceStatistics` holding two synthetic rolls → `csvString()` →
  `DiceRunCSV.records` gives the same fields, floats to the CSV's decimals.
- `aCSVWithTheWrongHeaderIsRejected`: throws `.wrongHeader`.
- `aCSVThatIsNotWholeRollsIsRejected`: four rows throws `.notWholeRolls(rows: 4)`.
- `aDeviceChangeIsFlagged`: two runs with different `device` values give a flag naming both.
- `aCrowdedSlotIsFlagged`: synthetic runs where die 0 has five times the other dice's rescues; the
  flags name die 0 as a slot outlier.
- `theIOS26AgainstIOS27ComparisonIsPinned`: reads the two history CSVs by a path built from the test
  file's `#filePath`: the file's folder, then
  `../../../../Sources/SyLibDice/Docs/FairnessHistory/<folder>/RUN.csv`. It checks `metrics` against
  the acceptance table below. If the simulator can't read the files by that path, stop and report
  (`00A` §4). Do not copy the CSVs into the test target.

**Acceptance** (`theIOS26AgainstIOS27ComparisonIsPinned`, previous `2026-07_iOS-26`, current
`2026-10-11_iOS-27`), to the decimals given. If any value differs, stop and report it beside the
expected one. Do not re-pin to what the code prints.

| Item | iOS 26 (#1) | iOS 27 (#2) |
|---|---|---|
| Face homogeneity, overall | chi² 2.153, p 0.829 | |
| Face homogeneity p per die, 0 to 4 | 0.765, 0.191, 0.903, 0.874, 0.424 | |
| Distinct faces per roll, 1 to 5 | 3, 103, 844, 990, 221 (p 0.116) | 3, 139, 823, 1001, 195 (p 0.580) |
| Mean sum of five dice | 17.477 | 17.416 |
| Roll duration mean / p50 | 0.938 / 0.95 | 0.907 / 0.90 |
| KS D | 0.085 | |
| Rolls under 0.5 s | 195 | 160 |
| Rescued / stuck totals | 584 / 129 | 177 / 114 (z 15.0 / 1.0) |
| Rescued per die | 386, 39, 20, 53, 86 | 48, 37, 21, 38, 33 |
| Stacked per die | 367, 4, 7, 3, 52 | 17, 11, 9, 3, 1 |
| Stuck per die | 15, 30, 12, 41, 31 | 22, 23, 11, 30, 28 |
| Clean dice below 0.95 alignment | 35 of 10,221 | 37 of 10,628 |
| Face against quadrant p | 0.985 | 0.110 |
| Pooled share of ones: stacked, floor, wall | 19.4%, 20.8%, 19.6% | |

The flags should include:
- the rescued-total z of 15.0;
- the KS p;
- in #1, die 0 as a slot outlier for rescues and for stacked rescues;
- in #2, die 0 as a slot outlier for stacked rescues (17 against a mean of 6). The numbers are small,
  and the flag is expected.

No section 8 chi² should be flagged.

**6. Docs.** `Docs/DICE.md` gains a `DiceRunComparison` section after `DiceReportGenerator`'s,
covering `DiceRunCSV`, the Compare button and the history folder's `DIFF.md`. Its platform-guard
table at the top lists both new types beside `DiceReportGenerator`. The `DiceDebugHUD` section
mentions Compare.

**7. Remove the Python script.**
- Delete `Tests/SyLibTests/SyLibDice/Analytics/analyze_dice_fairness.py`.
- In `Package.swift`, remove the `SyLibTests` target's
  `exclude: ["SyLibDice/Analytics/analyze_dice_fairness.py"]` line, and the comma that came before
  it. Nothing else in `Package.swift` changes.
- In `Sources/SyLibDice/Docs/DICE_FAIRNESS_TESTING.md`, under the historical notes at the top, add:
  "**Analysis script removed (2026-10):** `analyze_dice_fairness.py` was removed in SyFive 1.1.0
  (`22`). `DiceReportGenerator` makes the report and `DiceRunComparison` compares runs, both in the
  harness. The script's commands below are kept as a record."
- Leave its other mentions in `DICE_FAIRNESS_TESTING.md` and `DICE_RETROSPECTIVE.md` alone. They
  are history.

**Done when:**
- The header move, the two types, the sheet, the button, the tests and the docs are as above.
- The script is gone, `Package.swift` has no reference to it, and the note is in.
- The pinned test matches the acceptance table.
- SyLib's suite passes on the pinned destination at 1146 (§4.3's 1140 plus these 6).
- Syderal builds and passes with no source edit.

**Do not:**
- Change `DiceReportGenerator`, `DiceReportSheet`, `csvString()`'s output or `SampleRecord`.
- Write `DIFF.md` yourself. V3 makes it on device.

**Check:** V3.

### 4.5 SyFive: docs and ledger

1. **Ledger:** paste D-149 and D-150 from §7 under **Dice system**. If D-148 is not in the ledger
   yet, paste it from `14_APPSTORE_COPY.md` §9 under **Governance**.
2. **`IMPLEMENTATION_STATUS.md` line 47** ("Fairness validated"): change the notes cell to "p 0.602,
   all 5 dice pass (July 2026, iOS 26; last 2,161 rolls of a 10,000-roll batch). History: SyLibDice
   `Docs/FairnessHistory/`". Keep the row's status. `23` updates it again.
3. **`00B_SYFIVE_GUARDRAILS.md`**: replace the file with v1.2, attached by Pops.
4. **`project.pbxproj`**: add `Docs/SyLib/22_SYLIB_FAIRNESS_HISTORY.md` beside `15` to `21`.

**Done when:** the four edits are in; `BuildProject` is clean with 0 warnings; the suite passes at
19/19.

---

## 5. Validation

| ID | After | Check | Expect |
|---|---|---|---|
| V1 | 4.1, 4.2 | **Pops, iPad Pro (M5), Debug build with `AppConfig.DebugDice.showHarness` set to `true` locally (set it back afterwards, `00B` §6). These are the five full iOS 27 runs.** Turn off automatic iOS updates until all five are done. For each run: tap Reset; run a 10,000-roll batch with all five dice free and auto-hold off; when it finishes, tap Report and export the CSV, and save both, named run 1 to run 5. Every run counts, whatever its result. Send all ten files to Claude for `23` | For each run: the HUD reads "50000 samples · 10000 rolls". The report opens with the Run line (the iPad's identifier, iPadOS 27 and its build, "device", the app version) and "Tuning: batch preset (Config.batch); app tuning at batch start: certified". Then "Samples: 50000 Rolls: 10000". The CSV has 50,000 data rows. All five Run lines show the same iPadOS version |
| V2 | 4.2 | **Pops, same build, after V1's five runs.** Tap Reset. Move a physics slider, run a 1,000-roll batch, and tap Report. Then put the slider back | The Tuning line reads "batch preset (Config.batch); app tuning at batch start: MODIFIED". Don't keep this run |
| V3 | 4.4 | **Pops, same build.** Put both history folders' `RUN.csv` files in Files. Tap Compare. Choose `2026-07_iOS-26` as Previous and `2026-10-11_iOS-27` as New. Tap Compare, then Share, and save the result as `2026-10-11_iOS-27/DIFF.md`. Then do the same with `2026-10-11_iOS-27` as Previous and `2026-10-12_iOS-27` as New, and save it as `2026-10-12_iOS-27/DIFF.md` | The flags list the rescued total, roll timing (KS), and die 0 slot outliers. Die 0's rescues read 386 then 48. The file goes in the history folder unedited |

V1 is also the data for `23`, which carries its own fairness-screen check into `21` §5 step 1. V2
and V3 are debug-only checks.

---

## 6. Open decisions

None.

Noted, not changed: `14_APPSTORE_COPY.md` §4 says "we tested it across 10,000 rolls". Each batch was
10,000 rolls, but the published numbers covered 2,161 of them. Once `23` certifies 50,000 rolls,
the claim is an understatement: still true, but Pops may want "50,000 rolls" in the store copy. Rewording is Pops's call (`00B` §2), and the store copy is a living
record (D-148).

---

## 7. Ledger rows

**Dice system**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-149 | **Fairness certifications are kept as a history** in SyLibDice `Docs/FairnessHistory/`: one folder per run (report, CSV, and a `DIFF.md` against the run before, made by `DiceRunComparison` from the harness's Compare button), and an index with one row per run. Runs are never edited or deleted. `FairnessCertification.builtIn` carries what is certified, and the top-level `DICE_FAIRNESS_REPORT.txt` and `DICE_FAIRNESS_RUN.csv` are copies of it. The report's header names the device, OS build, app version, and what the rolls ran under (the batch preset and the app tuning at batch start); the CSV format is unchanged. A run is added when the OS changes, `DiceRoller.Config` changes, or D-037 requires one. **Only full runs certify** (recorded with D-150); windowed runs are history only. **Pool, never pick:** every full run on the same OS, rolled under an unchanged `Config.batch` from the certified app tuning, counts, none is dropped, and the pooled result is certified. 1.1.0 ships five full iOS 27 runs pooled: 50,000 rolls, 250,000 dice results (`23`). | `22` §2 (Pops, 11 Oct 2026) |
| D-150 | **A batch keeps every roll.** From `startBatch(count:)` until Reset, `DiceStatistics` doesn't trim, so a 10,000-roll batch records all 50,000 dice results. Gameplay keeps the 10,000-sample window. Earlier runs, July 2026's certification included, kept about the last 2,161 rolls of each batch. | `22` §2.1 (Pops, 11 Oct 2026) |

---

## 8. Results log

| Item | Value |
|---|---|
| §3: Pops's Config confirmation; iOS 27 file checks | |
| §4.1: SyLib total (1136); Syderal build and total | **Done 12 Oct 2026.** `keepsEveryRecord`, `beginKeepingEveryRecord()`, the trim skipped while it is set, and `reset()` clearing it; `startBatch(count:)` calls it after its guard, and nothing at batch end clears it. Step 3 per revision 3: the CSV button writes `Dice Fairness.csv` to the temporary directory on tap and presents `CSVShareSheet` (`UIActivityViewController`); `CSVExport` deleted; `DiceStatistics`'s isolation untouched. Three tests; `DICE.md` paragraph and member rows. **SyLib 1136 passed**, 0 warnings from source. **Syderal 897 / 893 passed / 4 skipped / 0 failed**, no source edit |
| §4.2: SyLib total (1140); Syderal build and total | **Done 12 Oct 2026.** New `Analytics/DiceRunInfo.swift` (`uname`, `SIMULATOR_MODEL_IDENTIFIER`, `kern.osversion`, `Bundle.main`; no `UIDevice`). `DiceRoller.appTuningCertifiedAtBatchStart`, set in `startBatch` before `config = .batch`, never cleared. `DiceReportTuning` and `generate(from:runInfo:tuning:)`: Run and Tuning lines after the title, nothing below them changed. HUD Report passes `.batch` when batch samples exist and the property is set, else `.app(certified:)`. Four tests in `DiceReportGeneratorTests.swift`. `DICE.md`: `DiceRunInfo` section, `DiceReportGenerator` header lines and `DiceReportTuning`, the batch member, the platform-guard table, and the Testing sentence (which said `DiceReportGenerator` had no tests). **SyLib 1140 passed**, 0 warnings from source. **Syderal 897 / 893 passed / 4 skipped / 0 failed**, no source edit. SyFive BuildProject clean |
| V1: for each of the five runs, the date, HUD totals, Run line and CSV rows; files sent to Claude | |
| V1 (13 Oct 2026) | Pass (confirmed by Pops on device, 13 Oct 2026). Five full runs, each 50,000 samples / 10,000 rolls with the Run and Tuning lines as specified. The files are in `FairnessHistory/2026-10-13_iOS-27_run-1` to `run-5` (`23` §3 checks) |
| V2 | Pass (confirmed by Pops on device, 16 Oct 2026). Pops's screenshot: a 1,000-roll batch (5,000 samples) after moving a physics slider; the report reads "Run: iPad17,1 · iPadOS 27.0.0 (24A437) · device · app 1.1.0 (1)" and "Tuning: batch preset (Config.batch); app tuning at batch start: MODIFIED". Run not kept |
| §4.3: file checks (§3) and byte checks; SyLib total (1140) | **Done 12 Oct 2026.** §3 checks (Python): `2026-10-11_iOS-27` reads "Samples: 10805 Rolls: 2161" and, under Overall, "chi²: 4.0863 p: 0.538931 PASS"; `2026-10-12_iOS-27` reads "Samples: 10805 Rolls: 2161" and "chi²: 7.9190 p: 0.159491 PASS"; each `RUN.csv` has 10,805 data rows. `2026-07_iOS-26/REPORT.txt` and `RUN.csv` copied, byte-identical to the top-level files, which are unchanged. `exclude: ["Docs"]` confirmed, not edited. README written word for word from §4.3 step 2. `builtIn` comment replaced; values unchanged. `DICE.md` and `DICE_FAIRNESS_TESTING.md` notes added. Pops's `2026-10-11_iOS-27` report is on disk as `Report.txt`, not `REPORT.txt`; left as placed. **SyLib 1140 passed**, 0 warnings from source |
| §4.4: acceptance test passed; SyLib total (1146); Syderal build and total | **Done 12 Oct 2026.** `DiceStatistics.csvHeader` (output unchanged); `DiceRunCSV`; `DiceRunComparison` with `Metrics`, `flags` and `markdown()`; `DiceCompareSheet` and the HUD's Compare button between Report and CSV. Six tests in `DiceRunCSVTests.swift` and `DiceRunComparisonTests.swift`. **`theIOS26AgainstIOS27ComparisonIsPinned` passed on first run against every acceptance value**; the simulator read both history CSVs by the `#filePath` path. Quadrant sign: a value of exactly 0 counts as negative ("sign of x and z"; the table's 0.985 / 0.110 need it). Flags for #1 against #2: rescued-total z 15.0, KS p 3.7e-07, #1 die 0 slot outlier for rescues and stacked rescues, #2 die 0 for stacked rescues (17 against a mean of 6.0); no section 8 flag. `analyze_dice_fairness.py` deleted, its `Package.swift` exclude and comma removed, note added. `DICE.md`: `DiceRunComparison` section (with `DiceRunCSV`, Compare and `DIFF.md`), platform-guard table, `DiceDebugHUD` and Testing lines. **SyLib 1146 passed**, 0 warnings from source. **Syderal 897 / 893 passed / 4 skipped / 0 failed**, no source edit. SyFive BuildProject clean. No `DIFF.md` written (V3) |
| V3 | Pass (run by Pops on device, 16 Oct 2026). Checked read-only: `2026-10-11_iOS-27/DIFF.md` (07 against 10-11) shows die 0's rescues 386 then 48 and flags the rescued-total z 15.0, the KS p (3.7e-07) and die 0 as a slot outlier (#1 rescues and stacked; #2 stacked). `2026-10-12_iOS-27/DIFF.md` (10-11 against 10-12) flags die 0 stacked in both. Both files saved as made |
| §4.5: ledger rows; status line; 00B v1.2; project file; SyFive suite | **14 Oct 2026; three of four edits in, the project file is Pops's.** D-149 and D-150 pasted under Dice system after D-039. D-148 was not in the ledger, so it is pasted under Governance after D-143 from `14_APPSTORE_COPY.md` §9, worded as there; no other row changed. `IMPLEMENTATION_STATUS.md`'s Fairness validated notes read as §4.5 step 2; status kept. `00B` was already v1.2 (Pops), so no replacement needed. **`project.pbxproj`: not edited** (editing it with Xcode open risks crashing Xcode); Pops to add `Docs/SyLib/22_SYLIB_FAIRNESS_HISTORY.md` beside `21` and `23`. **Done by Pops, 14 Oct 2026**: `22` (and `14_SYLIB_SYDERAL_INTEGRATION.md`, which was also missing) removed from the target; checked read-only, every file under `Docs/` is now excluded. BuildProject clean, 0 warnings from source. **SyFive 19/19** on the pinned destination |
