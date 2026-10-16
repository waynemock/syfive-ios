# SyLib: the iOS 27 fairness certification and the ±1 point standard

**Status:** Ready for the agent once `22` is complete, §4.5 included. Written 13 October 2026.
**Revision 2, 14 October 2026:** the certification plan, recorded before the runs, goes in the
pooled folder as `PLAN.md` (§4.2). No task had run.
**Revision 3, 14 October 2026:** from now on, one full run certifies (§2.6, D-153). It's added to the
history index and the ledger. No task had run.

**Scope:** `sylib-swift` on branch `syfive-reintegration` (§4.1 to §4.3), and `SyFive` docs and
ledger (§4.4). Ships in 1.1.0. This is the last document before the SyLib merge (`21` §5). Syderal
doesn't import SyLibDice, so it only has to build (`00B` §5.4).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md` (v1.2), this document. For §4.2, Pops places the five run files himself
(§3).

**Authorisation:** `00B` §2 makes any change to the fairness certification a stop condition. This
document authorises exactly these changes:
- §4.1: the certification's pass rule and its numbers;
- §4.2: the history and the top-level fairness files;
- §4.3: the fairness screens' copy, which Pops approved on 13 Oct 2026.

`DiceRoller.Config`, `Config.batch` and the physics stay untouched.

---

## Supersessions

| Overrides | With | Why |
|---|---|---|
| `22` §2.3 and D-149: the top-level `DICE_FAIRNESS_REPORT.txt` **and** `DICE_FAIRNESS_RUN.csv` are copies of what is certified | The top-level report is a copy of the certified pool's summary. The top-level CSV is removed; the run CSVs live only in the history | A pooled CSV would be about 32 MB, duplicating the five run CSVs already in the history. Pops, 13 Oct 2026 |
| `FairnessCertification.passes`: chi² p > 0.05 | `passes` is the ±1 point standard (§2.2). Chi²'s pass is kept as `chiSquarePasses` | The standard was set before the full runs (D-151). Chi² at 250,000 results flags differences no player could notice |
| `22` §4.3 folder names, `<yyyy-MM-dd>_iOS-<n>` | Several runs on one day add `_run-<k>`. A pool adds `_pooled` | Five runs were handed over together on 13 Oct 2026 |
| `21` §5 step 2: merge SyLib after `22` | Merge SyLib after `23` too. Step 1's pre-archive checks include V1 below | 1.1.0 ships this certification |
| `IMPLEMENTATION_STATUS.md` line 47, as `22` §4.5 left it | The iOS 27 pooled certification (§4.4) | Same |

---

## 1. Why

`22`'s five full iOS 27 runs are done. Each is a 10,000-roll batch, with 50,000 dice results and
roll IDs 1 to 10,000, all from the batch with no dice held. They were made on the same iPad Pro
(M5), `iPad17,1`, on iPadOS 27.0.0 (24A437), with app 1.1.0 (1). Every report reads "Tuning: batch
preset (Config.batch); app tuning at batch start: certified".

**Under the rules set before the runs** (`22` §2.6, and the plan in
`FairnessHistory/2026-10-13_iOS-27_pooled/PLAN.md`), all five pool into one certification, and **it passes**:

| | Pooled: 250,000 dice results, 50,000 rolls |
|---|---|
| Face counts, 1 to 6 | 41,327 · 42,026 · 41,316 · 42,105 · 41,855 · 41,371 |
| Shares | 16.531% · 16.810% · 16.526% · 16.842% · 16.742% · 16.548% |
| **Standard: every face's 99% interval within 16.667% ± 1 point** | **PASS.** The largest deviation is 0.175 points. The intervals span 16.335% to 17.035% |
| Chi² (information) | 16.3796, p 0.0060 |
| Serial r / runs Z (runs joined in order 1 to 5) | −0.000521 / +1.2795 |
| The runs agree with each other | homogeneity p 0.16 |
| Faces through each batch (by fifths) | p 0.995 |
| Distinct faces per roll against theory | p 0.88; 43 five-of-a-kind rolls, against 38.6 expected |

Chi² flags the pool at p 0.006. That is the case the standard was chosen for: with 250,000 results,
chi² detects differences of a few tenths of a point. The fairness screens' copy is rewritten so it
doesn't claim otherwise (§4.3).

Physics notes for the history (they don't affect fairness):
- **Rescues rise through every batch,** from 489 in the pooled first fifth to 725 in the last, and
  rolls slow by 3–5%. The iPad heats up, and the rescue timers and forces run per rendered frame.
- **The windowed runs' die 0 stacking came from the old HUD's CSV rebuild on every roll.** The same
  stretch of the full runs shows almost none.

---

## 2. Locked decisions

**2.1 The five full runs certify iOS 27, pooled** (D-152). None is dropped. `builtIn` takes the
pooled numbers. Pops, 11–13 Oct 2026, set before the runs.

**2.2 The standard is ±1 point at 99% confidence** (D-151). `passes` is true when every face's
interval, p̂ ± 2.576·√(p̂(1 − p̂)/n) in percent, lies within the expected share ± 1.0 point. Chi²,
serial r and the runs test are reported as information. Pops, 12 Oct 2026, set before the runs.

**2.3 The top-level fairness files.** `Docs/DICE_FAIRNESS_REPORT.txt` becomes a copy of the pool's
summary (§4.2). `Docs/DICE_FAIRNESS_RUN.csv` is removed. Pops, 13 Oct 2026.

**2.4 The fairness screens' copy is as in §4.3, word for word.** Claude drafted it and Pops approved
it, 13 Oct 2026 (`00B` §2).

**2.6 Next time, one full run certifies** (D-153). A new certification, after an OS or tuning
change, needs one full 10,000-roll run that passes the standard. Add runs only if:
- the first run's widest interval comes within 0.25 points of the bar (outside 15.917%–17.417%); or
- its Compare against the previous certified run flags something.

Extra runs are pooled under the existing rule, and none is dropped. *Why:* each of the five iOS 27
runs passed on its own. At 50,000 results the 99% range is about ±0.43 points, which leaves room
under the ±1 point bar, and the Compare catches drift. Pops, 14 Oct 2026.

**2.5 The debug HUD keeps its chi² badges.** They're a live harness view, and the HUD is debug-only.
*(rec.)*

---

## 3. Before starting

- `22` is complete, §4.5 included. SyLib is at 1146.
- Pops has placed the five runs' files at their final paths (§4.2 step 1). Check each with a Python
  script:
  - `REPORT.txt` reads "Samples: 50000  Rolls: 10000" and "Tuning: batch preset (Config.batch); app
    tuning at batch start: certified";
  - `RUN.csv` has 50,000 data rows, with roll IDs 1 to 10,000.

  Under Overall, the reports' chi² values are: run 1 6.1132, run 2 12.7756, run 3 8.3994, run 4
  11.8454, run 5 3.3806. If any check fails, stop (`00A` §4).

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 SyLib: the ±1 point standard, and the pooled certification

**1. `FairnessCertification`** (`Analytics/FairnessCertification.swift`). Add:

```swift
/// How far a face's share may sit from the expected share, in percentage points.
public static let toleranceHalfWidthPct: Double = 1.0
/// z for a two-sided 99% interval.
public static let confidenceZ: Double = 2.576

/// A face's 99% interval in percent: p̂ ± z·√(p̂(1 − p̂)/n), times 100. Nil for an unknown face or
/// no samples.
public func confidenceIntervalPct(forFace face: Int) -> ClosedRange<Double>?
/// The lowest lower bound and the highest upper bound across faces. 0 with no samples.
public var lowestIntervalBoundPct: Double { get }
public var highestIntervalBoundPct: Double { get }
/// The largest |share − expected| across faces, in percentage points. 0 with no samples.
public var largestDeviationPct: Double { get }
/// How far chance alone moves a face, in percentage points: 1.96·√(q(1 − q)/n)·100, with
/// q = 1 / faceCount. 0 with no samples.
public var chanceSwingPct: Double { get }
/// Chi² p > 0.05. Reported as information; it is not the standard.
public var chiSquarePasses: Bool { get }
```

Replace `passes` with:

```swift
/// The fairness standard: every face's 99% interval lies within the expected share ± 1 point.
/// False with fewer than two faces or no samples.
public var passes: Bool { get }
```

The chi² members and the Wilson-Hilferty p are unchanged.

**2. `builtIn`.** Replace the values; keep the comment that `22` §4.3 wrote, except its step 5
(below):

```swift
    static let builtIn = FairnessCertification(
        testDate: "October 2026",
        totalRolls: 50_000,
        faceCounts: [1: 41_327, 2: 42_026, 3: 41_316, 4: 42_105, 5: 41_855, 6: 41_371],
        serialCorrelation: -0.000521,
        runsTestZ: +1.279517
    )
```

The counts sum to 250,000. Serial r and runs Z are computed on the five runs' values joined end to
end in run order, with `DiceStatistics`'s formulas.

Change the comment's step 5 to: "5. Copy the certified run's or pool's `REPORT.txt` to
`Docs/DICE_FAIRNESS_REPORT.txt`, update the values below, and re-pin the regression tests in
`FairnessCertificationTests`."

**3. Tests** (`Tests/SyLibTests/SyLibDice/Analytics/FairnessCertificationTests.swift`):
- **The chi² tests now test chi².** In `uniformDistributionPasses`, `skewedDistributionFails`,
  `d4UniformDistributionPasses`, `d4SkewedDistributionFails` and
  `degreesOfFreedomDeriveFromFaceCount`, replace each `passes` with `chiSquarePasses`, and "passes"
  with "chiSquarePasses" in each test's title. Nothing else in them changes.
- **The regression pins:**
  - `builtInChiSquareUnchanged`: `before = 16.379648`;
  - `builtInChiSquarePValueUnchanged`: `before = 0.0059988046821906485`.

  Change both comments to "Recorded October 2026 (iOS 27, five full runs pooled)". These come from
  the type's formulas on the counts above. If the suite computes other values, stop and report
  them.
- **Five new tests**, named after the rule:
  - `aLargeEvenRunMeetsTheStandard`: 50,000 of each face gives `passes`.
  - `aSmallEvenRunCannotMeetTheStandard`: 600 of each face gives `!passes`, and `chiSquarePasses`.
  - `aFaceAtEighteenPercentFails`: face 1 at 45,000 and faces 2 to 6 at 41,000 each gives
    `!passes`.
  - `aFaceAtSeventeenPointTwoPasses`: face 1 at 43,000 and faces 2 to 6 at 41,400 each gives
    `passes`.
  - `theBuiltInStandardIsPinned`: on `builtIn`:
    - `passes` and `!chiSquarePasses`;
    - `largestDeviationPct` 0.1753333, `lowestIntervalBoundPct` 16.3350451 and
      `highestIntervalBoundPct` 17.0348078, each within 1e-6.
- In `DiceStatisticsTests`, rename `certifiedRunPassesChiSquare` to `certifiedRunMeetsTheStandard`,
  titled "Certified run meets the fairness standard". Its expectation is unchanged. The serial r
  (< 0.05) and runs Z (< 2.0) tests are unchanged, and both still pass (−0.0005 and 1.28).

**4. Docs.** `Docs/DICE.md`, the `FairnessCertification` section:
- the member table gains the seven new members, and `passes` describes the standard;
- the sentence "`passes` tests chi-square alone…" becomes "`passes` is the fairness standard:
  every face's 99% interval within the expected share ± 1 percentage point. `chiSquarePasses`
  (p > 0.05) is reported as information. With large samples chi-square detects differences far
  smaller than the standard.";
- the `builtIn` paragraph says it is "five full iOS 27 runs pooled (October 2026): 50,000 rolls,
  250,000 dice results. Every run, and the pool, is in
  `Sources/SyLibDice/Docs/FairnessHistory/README.md`." Remove the sentence naming
  `DICE_FAIRNESS_RUN.csv`, and the "July 2026" sentence and the windowing note that `22` added.

**Done when:**
- The members, `passes`, `builtIn`, the comment, the tests and the docs are as above.
- SyLib's suite passes on the pinned destination at 1151 (1146 plus these 5).
- Syderal builds and passes with no source edit.

**Do not:**
- Change the chi² formulas, `DiceStatistics`, the HUD or `DiceRoller`.
- Touch the fairness views (that's §4.3).

### 4.2 SyLib: the history and the top-level files

After §4.1. Use a Python script for the copies, checks and removal, not a shell pipeline.

**1. The folder.** Pops places the run files; you write `README.md` and the pooled report.

```
Sources/SyLibDice/Docs/FairnessHistory/
  2026-10-13_iOS-27_run-1/REPORT.txt, RUN.csv   ← Pops (his REPORT1.txt, RUN1.csv)
  2026-10-13_iOS-27_run-2/REPORT.txt, RUN.csv   ← Pops (REPORT2, RUN2)
  2026-10-13_iOS-27_run-3/REPORT.txt, RUN.csv   ← Pops (REPORT3, RUN3)
  2026-10-13_iOS-27_run-4/REPORT.txt, RUN.csv   ← Pops (REPORT4, RUN4)
  2026-10-13_iOS-27_run-5/REPORT.txt, RUN.csv   ← Pops (REPORT5, RUN5)
  2026-10-13_iOS-27_pooled/REPORT.txt           ← you (step 2)
  2026-10-13_iOS-27_pooled/PLAN.md              ← Pops (the certification plan, set before the runs)
  README.md                                     ← you replace (step 3)
```

Don't rename or edit Pops's files, `PLAN.md` included.

**2. The pooled report,** `2026-10-13_iOS-27_pooled/REPORT.txt`, verbatim:

```
══ Dice Fairness Certification ══
Pooled: five full runs, history #4 to #8 (2026-10-13_iOS-27_run-1 to run-5)
Run: iPad17,1 · iPadOS 27.0.0 (24A437) · device · app 1.1.0 (1)
Tuning: batch preset (Config.batch); app tuning at batch start: certified
Samples: 250000  Rolls: 50000

Standard: every face's 99% interval within 16.667% ± 1.000 point
Result:   PASS — largest deviation 0.175 points; intervals 16.335%–17.035%

counts:  1:41327 2:42026 3:41316 4:42105 5:41855 6:41371
freqs:   16.53% 16.81% 16.53% 16.84% 16.74% 16.55%

Information (not the standard):
chi²:     16.3796  p: 0.005999
serial r: -0.000521  (runs joined in order 1 to 5)
runs Z:   +1.279517
runs agree: homogeneity across the five runs p 0.16
```

Then copy it over `Docs/DICE_FAIRNESS_REPORT.txt`, and confirm by byte comparison that the two are
identical. **Remove `Docs/DICE_FAIRNESS_RUN.csv`.** If deletion isn't permitted, stop and tell Pops;
the removal is his in git anyway.

**3. The index,** `FairnessHistory/README.md`. Replace the whole file with this, verbatim:

```markdown
# Dice fairness certification history

Every certification run of SyLibDice's dice, newest first. A run is never edited or deleted. What
`FairnessCertification.builtIn` certifies is marked Current, and its report is copied to
`Docs/DICE_FAIRNESS_REPORT.txt`. Run CSVs live only here.

**When to add a run:** when the OS changes, when `DiceRoller.Config` changes, or when D-037 requires
one. A run is a 10,000-roll batch of five free dice in the debug HUD's harness, which gives 50,000
dice results. Steps are in `Sources/SyLibDice/Analytics/FairnessCertification.swift`.

**How many runs:** one full run certifies, if it passes the standard. Add runs only if its widest
interval comes within 0.25 points of the bar (outside 15.917%–17.417%), or its Compare against the
previous certified run flags something. Any extra runs are pooled with it (D-153). The iOS 27
certification used five runs, and each passed on its own.

**The standard.** Dice are fair when every face's 99% interval, p̂ ± 2.576·√(p̂(1 − p̂)/n), lies
within the expected share ± 1 percentage point. Chi², serial r and the runs test are reported as
information.

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

## Certified

| Pool | Status | Runs | Platform | Hardware | Samples / rolls | Standard | Largest deviation | Chi² p (info) | Serial r | Runs Z | Folder |
|---|---|---|---|---|---|---|---|---|---|---|---|
| iOS 27 | **Current** | #4 to #8 | iPadOS 27.0.0 (24A437) | iPad Pro (M5), iPad17,1 | 250,000 / 50,000 | **PASS** (16.335%–17.035%) | 0.175 pt | 0.0060 | −0.000521 | +1.280 | `2026-10-13_iOS-27_pooled/` |

## Runs

| # | Status | Date | Platform | Hardware | Tuning | Kept: samples / rolls | Chi² | p | Serial r | Runs Z | Rescued (stacked) | Stuck rerolls | Avg alignment | Folder |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 8 | Full; in the iOS 27 pool | 13 Oct 2026 | iPadOS 27.0.0 | iPad Pro (M5) | `Config.batch`; app tuning certified | 50,000 / 10,000 | 3.3806 | 0.6441 | −0.006745 | +1.780 | 635 (57) | 490 (4.90%) | 0.9966 | `2026-10-13_iOS-27_run-5/` |
| 7 | Full; in the iOS 27 pool | 13 Oct 2026 | iPadOS 27.0.0 | iPad Pro (M5) | `Config.batch`; app tuning certified | 50,000 / 10,000 | 11.8454 | 0.0367 | −0.001141 | −0.277 | 635 (65) | 492 (4.92%) | 0.9967 | `2026-10-13_iOS-27_run-4/` |
| 6 | Full; in the iOS 27 pool | 13 Oct 2026 | iPadOS 27.0.0 | iPad Pro (M5) | `Config.batch`; app tuning certified | 50,000 / 10,000 | 8.3994 | 0.1343 | −0.004339 | +1.119 | 658 (77) | 511 (5.11%) | 0.9966 | `2026-10-13_iOS-27_run-3/` |
| 5 | Full; in the iOS 27 pool | 13 Oct 2026 | iPadOS 27.0.0 | iPad Pro (M5) | `Config.batch`; app tuning certified | 50,000 / 10,000 | 12.7756 | 0.0255 | +0.002713 | +0.259 | 631 (79) | 468 (4.68%) | 0.9967 | `2026-10-13_iOS-27_run-2/` |
| 4 | Full; in the iOS 27 pool | 13 Oct 2026 | iPadOS 27.0.0 | iPad Pro (M5) | `Config.batch`; app tuning certified | 50,000 / 10,000 | 6.1132 | 0.2948 | +0.006823 | −0.030 | 598 (56) | 459 (4.59%) | 0.9968 | `2026-10-13_iOS-27_run-1/` |
| 3 | History only (windowed) | 12 Oct 2026 | iOS 27 | iPad Pro (M5) | `Config.batch`; app tuning certified | 10,805 / 2,161 (last of 10,000) | 7.9190 | 0.1595 | −0.002625 | +0.054 | 145 (37) | 95 (4.40%) | 0.9968 | `2026-10-12_iOS-27/` |
| 2 | History only (windowed) | 11 Oct 2026 | iOS 27 | iPad Pro (M5) | `Config.batch`; app tuning certified | 10,805 / 2,161 (last of 10,000) | 4.0863 | 0.5389 | −0.021965 | +0.282 | 177 (41) | 114 (5.28%) | 0.9963 | `2026-10-11_iOS-27/` |
| 1 | Superseded by the iOS 27 pool; certified SyFive 1.0 | July 2026 | iOS 26 | iPad Pro (M5) | `Config.batch`; app tuning certified | 10,805 / 2,161 (last of 10,000) | 3.6554 | 0.6024 | +0.000442 | −0.086 | 584 (433) | 129 (5.97%) | 0.9960 | `2026-07_iOS-26/` |

## Notes

- **The iOS 27 pool:**
  - The rules were set before the runs. They are in `2026-10-13_iOS-27_pooled/PLAN.md`, with the
    result and the full analysis.
  - It passes the standard, with a largest deviation of 0.175 points.
  - Chi² flags it at p 0.006, which is chi²'s sensitivity at 250,000 results: it sees differences
    of a few tenths of a point. The largest pattern is the 1/6 face pair (the die's local Y axis)
    at 33.08% against 33.33%, found after looking.
  - The five runs agree with each other (p 0.16), and faces stay even through each batch.
- **#4 to #8, physics:**
  - Rescues rise through every batch, from 489 in the pooled first fifth to 725 in the last, and
    rolls slow by 3–5%. That fits the iPad heating up: rescue timers and forces run per rendered
    frame.
  - Per die, stuck dice are lowest on die 2 (the centre slot) and highest on dice 1 and 3. Stacked
    rescues gather on die 2.
- **The windowed runs' hints were chance.** Both face 6 running low and rescued dice leaning toward
  1 disappear in the full runs.
- **Die 0 stacking in #2 and #3 came from the old HUD,** which rebuilt the CSV on every roll and
  slowed frames. The same late stretch of #4 to #8 shows almost none.
- **#1 to #3 are windowed.** Until SyLib's 1.1.0 changes, the harness kept only about the last
  10,000 samples of a batch, so each holds the last 2,161 of its 10,000 rolls. The window ignores
  faces, so the kept rolls are an unbiased sample.
- **#2 against #1:**
  - On iOS 26, 386 of 584 rescues were die 0 (367 stacked); on iOS 27, die 0 is in line.
  - Rescues fell by about 70% with the same tuning.
  - See `2026-10-11_iOS-27/DIFF.md`.
- **#1:** the certification SyFive 1.0 shipped with.
- Earlier runs on older builds, including a full 50,000-result run at p 0.217, are described in
  `DICE_FAIRNESS_TESTING.md`. They have no report or CSV here.
```

**Done when:**
- §3's checks pass, `PLAN.md` is in place, and the pooled report and index are as above.
- The top-level report is byte-identical to the pooled report, and the top-level CSV is gone.
- SyLib's suite still passes at 1151.

### 4.3 SyLib: the fairness screens' copy

After §4.1. The copy below is approved by Pops and goes in **verbatim**. `{…}` marks values the view
computes. Use the formats given, and the view's existing `formattedSamples` for sample counts.

**1. `Views/DiceFairnessDeepDiveView.swift`.**

**(a) A new first section, "Fairness Standard",** before Chi-Square. Use the same layout as the
Chi-Square section: a row of `statPill`s ending in `passFailBadge(certification.passes)`, then
`.subheadline` secondary text, under an `accentColor` header.
- Pills:
  - "largest gap": `String(format: "%.3f pp", certification.largestDeviationPct)`
  - "standard": `"±\(String(format: "%.1f", FairnessCertification.toleranceHalfWidthPct)) pp"`
  - "confidence": `"99%"`
- Text 1: "We call the dice fair when every face's share is within 1 percentage point of the ideal
  {expectedFrequencyPct, %.1f}%, with 99% confidence. That margin is far smaller than anything a
  player could notice over a lifetime of games."
- Text 2: "Across {formattedSamples} dice results, the 99% range for every face falls between
  {lowestIntervalBoundPct, %.2f}% and {highestIntervalBoundPct, %.2f}%."

**(b) The Chi-Square section.**
- Remove its `passFailBadge`; its pills stay.
- Replace the sentence starting "A p-value of" with: "A p-value of {chiSquarePValue, %.4f} means
  that if the dice were perfectly fair, face counts at least this uneven would turn up
  {chiSquarePValue × 100, %.1f}% of the time by chance. With {formattedSamples} results,
  chi-square can pick up differences of a few tenths of a percentage point, far below anything a
  player could notice, so we report it for completeness and judge fairness by the standard above."
- The formula and degrees-of-freedom sentences are unchanged.

**(c) The Per-Face Results caption** becomes: "Ideal frequency is {expectedFrequencyPct, %.1f}% per
face. pp = percentage points from ideal. With {formattedSamples} results, chance alone moves each
face by about ±{chanceSwingPct, %.2f}pp."

**(d) Methodology Notes, first paragraph,** becomes: "Fairness is judged by the standard above: a 99%
confidence interval for each face's share must lie within ±1 percentage point of the ideal.
Chi-square, serial correlation and the runs test are reported for completeness, computed on the same
ordered sequence of {formattedSamples} dice results pooled from separate test runs. The chi-square
p-value uses the Wilson-Hilferty normal approximation, accurate to within 0.1% for df ≥ 5." The
second paragraph and the test-date line are unchanged.

The serial correlation and runs test sections are unchanged.

**2. `Views/DiceFairnessView.swift`, the "How We Test" section.**
- **Paragraph 2:** replace "roll all five dice thousands of times" with "roll all five dice tens of
  thousands of times". Nothing else in it changes.
- **Paragraph 3** becomes: "Real casino dice are precision-machined and statistically certified
  before deployment, typically tested across tens of thousands of throws. Our test holds every face
  to within one percentage point of {expectedFrequencyPct, %.1f}%, with 99% confidence, across
  {formattedSamples} dice results. The result: the same verified fairness, without the felt table."
- The headline, its verification line and the face chart are unchanged.

**3. Previews** still build, in light and dark.

**Done when:**
- Both views read as above.
- `BuildProject` is clean with 0 warnings, and SyLib's suite passes at 1151.

**Do not:** change any other text in either view, or `DiceDebugHUD`.

**Check:** V1.

### 4.4 SyFive: docs and ledger

1. **Ledger:** paste D-151, D-152 and D-153 from §7 under **Dice system**, and replace D-149's row
   with §7's.
2. **`IMPLEMENTATION_STATUS.md` line 47** ("Fairness validated"): change the notes cell to "iOS 27,
   five full runs pooled (250,000 results): every face within 0.175 pt of ideal, inside the ±1 pt
   standard at 99%. History: SyLibDice `Docs/FairnessHistory/`".
3. **`IMPLEMENTATION_STATUS.md`**: the 1.1.0 line reads "Rebuilt on the post-Syderal SyLib; see `15`
   to `23`."
4. **`project.pbxproj`**: add `Docs/SyLib/23_SYLIB_IOS27_CERTIFICATION.md` beside `15` to `22`, and
   `22` too if `22` §4.5 hasn't.

**Done when:** the edits are in; `BuildProject` is clean with 0 warnings; the suite passes at 19/19.

---

## 5. Validation

| ID | After | Check | Expect |
|---|---|---|---|
| V1 | 4.3 | **Pops, device, SyFive.** Open the dice fairness screen, then the Statistical Deep Dive | Main screen: "These dice are fair." and "Verified across 250,000 dice results — each face landed within 0.2% of perfectly equal." How We Test reads as §4.3.2, with "250,000 dice results", and "Tested October 2026". Deep dive, in order: Fairness Standard (pills "0.175 pp", "±1.0 pp", "99%"; PASS; "between 16.34% and 17.03%"); Chi-Square with no badge (p-value 0.0060; "0.6% of the time"); the independence tests, both PASS; Per-Face Results ending "±0.15pp"; Methodology Notes as §4.3.1(d) |
| V2 | 4.2 | **Pops, iPad, Debug build with the harness on (as `22` V1).** Make each full run's `DIFF.md`: run 1 against `2026-10-12_iOS-27`, then each run against the one before | Five files, each saved unedited as `DIFF.md` in its run's folder. Run 1 against #3 should flag the rescued totals (windowed against full), but no face homogeneity |

V1 joins `21` §5 step 1's pre-archive checks. V2 is a debug-only check, and its files can follow on
`main` after the merge.

---

## 6. Open decisions

None.

Noted, not changed: `14_APPSTORE_COPY.md` §4 says "we tested it across 10,000 rolls". That's still
true, and now an understatement: the certification covers 50,000 rolls (250,000 dice results).
Rewording is Pops's call (`00B` §2, D-148).

Carried forward, not for 1.1.0:
- Certification batches roll under `Config.batch`, not the gameplay tuning (`DICE.md` 225, 329,
  878).
- Rescue timers and forces run per rendered frame, so rescue rates depend on device load. Moving
  them to the physics step would remove that.

---

## 7. Ledger rows

**Dice system**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-149 | **Fairness certifications are kept as a history** in SyLibDice `Docs/FairnessHistory/`: one folder per run (report, CSV, and a `DIFF.md` against the run before, made by `DiceRunComparison` from the harness's Compare button), a folder per pool (its report), and an index. Runs are never edited or deleted. `FairnessCertification.builtIn` carries what is certified, and `Docs/DICE_FAIRNESS_REPORT.txt` is a copy of its report. Run CSVs live only in the history. The report's header names the device, OS build, app version, and what the rolls ran under. A run is added when the OS changes, `DiceRoller.Config` changes, or D-037 requires one. **Only full runs certify** (D-150); windowed runs are history only. **Pool, never pick:** every full run on the same OS, rolled under an unchanged `Config.batch` from the certified app tuning, counts, none is dropped, and the pool is certified. | `22` §2 → `23` §2.3 (Pops, 11–13 Oct 2026) |
| D-151 | **The fairness standard is ±1 percentage point at 99% confidence.** `FairnessCertification.passes` is true when every face's interval, p̂ ± 2.576·√(p̂(1 − p̂)/n), lies within the expected share ± 1 point. Chi² (`chiSquarePasses`), serial r and the runs test are reported as information. Set before the full runs: chi² on large samples flags differences far below anything a player could notice. | `23` §2.2 (Pops, 12 Oct 2026) |
| D-152 | **iOS 27 certification: five full runs pooled**, iPad Pro (M5), iPadOS 27.0.0 (24A437). 250,000 dice results from 50,000 rolls. **PASS**: the largest deviation is 0.175 points, and the intervals span 16.335% to 17.035%. For information: chi² p 0.006, serial r −0.0005, runs Z +1.28. It ships in SyFive 1.1.0. | `23` §2.1 (Pops, 13 Oct 2026) |
| D-153 | **One full run certifies.** A new certification (after an OS or tuning change) needs one full 10,000-roll run that passes D-151. Add runs only if its widest interval comes within 0.25 points of the bar (outside 15.917%–17.417%), or its Compare against the previous certified run flags something. Extra runs are pooled (D-149). Each of the five iOS 27 runs passed on its own. | `23` §2.6 (Pops, 14 Oct 2026) |

---

## 8. Results log

| Item | Value |
|---|---|
| §3: five-run file checks | **Pass, 14 Oct 2026** (Python). Runs 1 to 5: each `REPORT.txt` reads "Samples: 50000  Rolls: 10000" and "Tuning: batch preset (Config.batch); app tuning at batch start: certified"; Overall chi² 6.1132, 12.7756, 8.3994, 11.8454, 3.3806 as listed; each `RUN.csv` has 50,000 data rows with roll IDs 1 to 10,000. All five Run lines read `iPad17,1 · iPadOS 27.0.0 (24A437) · device · app 1.1.0 (1)`. `PLAN.md` is in the pooled folder; the top-level CSV is already gone. Pooled from the CSVs: counts as §1, chi² 16.379648, p 0.0059988046821906485, serial r −0.000521, runs Z +1.279517, largest deviation 0.1753333, bounds 16.3350451 to 17.0348078, all as `23` states |
| §4.1: SyLib total (1151); Syderal build and total | **Done 14 Oct 2026.** `FairnessCertification` gains `toleranceHalfWidthPct`, `confidenceZ`, `confidenceIntervalPct(forFace:)`, `lowestIntervalBoundPct`, `highestIntervalBoundPct`, `largestDeviationPct`, `chanceSwingPct` and `chiSquarePasses`; `passes` is the ±1 point standard; chi² members unchanged. `builtIn` takes the pooled values; comment step 5 replaced. The five chi² tests use `chiSquarePasses`; regression pins 16.379648 and 0.0059988046821906485, which the suite computes; five new standard tests; `certifiedRunMeetsTheStandard` renamed. `DICE.md` FairnessCertification section updated. **SyLib 1151 passed**, 0 warnings from source. **Syderal 897 / 893 passed / 4 skipped / 0 failed**, no source edit |
| §4.2: pooled report, index, top-level report byte check, top-level CSV removed; SyLib total | **Done 14 Oct 2026** (Python). `2026-10-13_iOS-27_pooled/REPORT.txt` written word for word from §4.2 step 2 (17 lines) and copied over `Docs/DICE_FAIRNESS_REPORT.txt`: byte-identical. `FairnessHistory/README.md` replaced word for word from step 3 (81 lines). `Docs/DICE_FAIRNESS_RUN.csv` confirmed gone (removed by Pops in git); not deleted here. Pops's run folders and `PLAN.md` untouched. Checked read-only: five-run homogeneity recomputes to p 0.162 ("p 0.16"); the index's rows #4 to #8 (chi², p, serial r, runs Z, rescued (stacked), stuck rerolls, avg alignment) match the five reports. **SyLib 1151 passed**, 0 warnings from source |
| §4.3: both views; previews; SyLib total | **Done 14 Oct 2026.** `DiceFairnessDeepDiveView`: new first section "Fairness Standard" (pills "largest gap", "standard", "confidence"; `passFailBadge(certification.passes)`; Texts 1 and 2); Chi-Square badge removed, the "A p-value of" sentence replaced; Per-Face caption and Methodology's first paragraph replaced; formula, degrees-of-freedom, second methodology paragraph, test-date line and independence sections unchanged. `DiceFairnessView` How We Test: paragraph 2's phrase and paragraph 3 replaced; headline, verification line and chart unchanged. All six paragraphs checked word for word against §4.3 by script. Previews unchanged and compile (not rendered; Pops looks, V1). BuildProject clean, 0 warnings from source. **SyLib 1151 passed** |
| §4.4: ledger rows; status lines; project file; SyFive suite | **Done 14 Oct 2026.** Ledger, by script from §7: D-149's row replaced; D-151, D-152 and D-153 pasted under Dice system after D-150; no other row changed. `IMPLEMENTATION_STATUS.md`: line 47's notes and the 1.1.0 line ("see `15` to `23`") read as §4.4 steps 2 and 3. `project.pbxproj`: already lists `22` and `23` in the target's exception list (Pops, 14 Oct 2026); checked read-only, no edit. BuildProject clean, 0 warnings from source. **SyFive 19/19** on the pinned destination |
| V1 | Pass (confirmed by Pops on device, 14 Oct 2026) |
| V2 | Pass (confirmed by Pops on device, 16 Oct 2026) |
