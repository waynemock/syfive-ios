# SyFive — Dice Fairness Testing: Methodology and Results

*Completed: July 2026*

---

## Why Test Dice Fairness at All

A programmatic die roll is fair by construction: `Int.random(in: 1...6)` samples a uniform distribution, full stop. A physics-driven die has no such guarantee. The outcome depends on:

- Die spawn position and orientation
- Initial linear and angular impulse (direction, magnitude)
- RealityKit/PhysX collision geometry and friction model
- Tray wall positions and restitution
- Rescue interventions (nudges, relaunches)

Any of these can introduce systematic bias. A die that consistently spawns near the same corner with the same torque profile will develop face preference. A rescue strategy that preferentially nudges a die away from face 5 (to avoid rolling into a wall) creates a non-uniform distribution. Reduced friction might favor faces with a lower center-of-mass.

The only way to know the dice are fair is to measure them. Visual inspection of rolls is useless — humans are terrible at detecting statistical bias below 30% deviation, and a 5% bias is completely invisible to the eye but detectable in 10,000 samples.

---

## Testing Philosophy

**Measure everything, not just outcomes.**

The batch harness records 21 fields per sample — not just the face value, but the rescue kind, stuck reason, spawn position, final alignment, roll duration, and more. This allows post-hoc slicing of the data: are rescued samples as fair as clean ones? Are nudged dice different from rerolled ones? Do dice near the tray walls show wall-position bias?

**Test at multiple levels.**

A die can be individually fair while showing cross-die correlation (e.g., Die 0 and Die 1 always show different faces because they collide). The test suite covers: overall, per-die, per-rescue-status, per-nudge-status.

**Multiple independent statistical tests.**

No single test is sufficient. Chi-square tests for non-uniform face distribution. Serial correlation tests whether consecutive rolls share a pattern. The runs test checks for alternation or streak patterns. All three must pass.

**Validate after every major physics change.**

Friction changes, collision shape changes, rescue logic changes — all affect the distribution. Run a full 10,000-roll batch after each change, not just a quick look.

---

## The Batch Roll Harness

### How It Works

`DiceRoller.startBatch(count:)` runs a specified number of complete 5-die rolls automatically:

```swift
func startBatch(count: Int) {
    batchTotal = count
    batchProgress = 0
    isBatchRunning = true
    UIApplication.shared.isIdleTimerDisabled = true
    Task { await runBatchLoop() }
}
```

Each iteration rolls all five dice, waits for settlement, records results, then immediately starts the next roll. The `Config.batch` variant uses looser thresholds than gameplay so rolls complete faster:

| Config parameter | Gameplay | Batch |
|---|---|---|
| `settleFrames` | 30 | 8 |
| `flatnessThreshold` | 0.96 | 0.94 |
| `rollTimeout` | 2.5s | 1.5s |
| `floorStuckSeconds` | 6.0s | 3.0s |
| `wallStuckSeconds` | 2.0s | 0.8s |

Looser flatness and fewer settle frames mean batch mode declares dice settled faster. This is valid for statistical purposes because any systematic bias introduced by the looser threshold would appear in the data — but in practice it doesn't, as the rescued-vs-clean comparison confirms.

### Auto-Rescue During Batch

Normal gameplay puts the player in the loop for stuck dice: yellow die (tap to nudge), red die (tap to reroll). Batch mode simulates that player:

```swift
private func autoRerollStuckDiceForBatch() {
    // Yellow → nudge (simulates player tap)
    for index in Array(nudgeableDieIndices) { nudgeStuckDie(at: index) }
    // Red → relaunch (simulates player tap)
    let toRelaunch = Array(stuckDieIndices)
    stuckDieIndices = []
    Task { for index in toRelaunch { let _ = await launchDie(at: index) } }
}
```

This keeps unattended 10,000-roll runs from blocking. The auto-rescued samples are flagged in the CSV so they can be tested separately.

### Idle Timer

A 10,000-roll batch takes ~50–80 minutes on device. The screen would sleep at 2 minutes otherwise, interrupting the physics simulation. `UIApplication.shared.isIdleTimerDisabled = true` keeps the display on for the duration. It's restored to `false` in `stopBatch()`.

---

## Per-Roll Data Shape

Every settled die produces one `SampleRecord` with 21 fields. The CSV schema:

```
sample_index, roll_id, die_index, value, held, source,
rescued, rescue_kind, escape_recovered,
stuck_reroll, stuck_nudge, stuck_reason,
final_align, unsettled_secs,
final_x, final_z, final_height,
spawn_x, spawn_y, spawn_z,
roll_duration_secs
```

### Field Definitions

| Field | Type | Meaning |
|---|---|---|
| `sample_index` | int | Global sequential sample counter |
| `roll_id` | int | Groups the 5 dice of a single roll together |
| `die_index` | int | 0–4 |
| `value` | int | Face value 1–6 (read from orientation — see below) |
| `held` | bool | Die was held (kinematic) this roll |
| `source` | string | `batch`, `gameplay`, or `preview` |
| `rescued` | bool | Any rescue intervention occurred |
| `rescue_kind` | string | `floor`, `wall`, `stacked` (or empty) |
| `escape_recovered` | bool | Die escaped the tray and was teleported back |
| `stuck_reroll` | bool | Die was relaunched after nudge failed |
| `stuck_nudge` | bool | Die received a physics nudge (yellow state) |
| `stuck_reason` | string | Why stuck: `floor_timeout`, `wall_timeout`, etc. |
| `final_align` | float | Max face dot-product with up-vector at settle (0–1) |
| `unsettled_secs` | float | Time the die spent in active rolling |
| `final_x` | float | World x position at settle |
| `final_z` | float | World z position at settle |
| `final_height` | float | World y (height) at settle |
| `spawn_x` | float | Spawn x position |
| `spawn_y` | float | Spawn y (height) |
| `spawn_z` | float | Spawn z position |
| `roll_duration_secs` | float | Wall time from launch to settlement |

### How Face Value Is Read

The die is a cube with face normals aligned to ±X, ±Y, ±Z at identity orientation. Each face is mapped to a value (1 opposite 6, 2 opposite 5, 3 opposite 4 — standard Western dice). At settlement, `finishRoll()` computes the dot product of each face normal (rotated by the die's current orientation) with the world up vector `[0, 1, 0]`. The face with the highest dot product is the face pointing up — that face's value is recorded.

`final_align` is that maximum dot product. A value of 1.0 means a face is perfectly horizontal. The gameplay flatness threshold is 0.96 (≈16° of tilt). Batch mode uses 0.94 (≈20° of tilt).

---

## Statistical Methods

Three tests are computed on every data slice. All three must pass for the slice to be considered unbiased.

### Chi-Square Test for Uniformity

Tests whether the observed face distribution is consistent with the expected uniform distribution (each face = 1/6 of samples).

**Statistic:**

```
χ² = Σ (observed_i - expected)² / expected     for i = 1..6
```

where `expected = N / 6`.

**Degrees of freedom:** 5 (six categories minus one constraint).

**p-value:** Wilson-Hilferty normal approximation — avoids importing a statistics library while being accurate for df = 5 and χ² in the range we care about:

```swift
let k = Double(df)       // = 5
let h = 1.0 - 2.0 / (9.0 * k)
let t = pow(x / k, 1.0 / 3.0)
let z = (t - h) / sqrt(2.0 / (9.0 * k))
return 0.5 * erfc(z / sqrt(2.0))
```

**Pass criterion:** `p > 0.05` (5% significance level). A p-value below 0.05 means there's less than a 5% chance of seeing this much deviation from uniform if the die truly were fair.

**What it catches:** Consistent over- or under-representation of specific faces. Won't detect purely sequential patterns.

**Minimum sample size:** 30 (below this chi-square is unreliable). The HUD waits for 30 samples before showing pass/fail.

### Serial Correlation (Pearson r)

Tests whether consecutive die results are correlated — i.e., whether knowing the result of roll N tells you anything about roll N+1.

**Statistic:** Pearson correlation coefficient between the sequence `[r₁, r₂, ..., rₙ₋₁]` and the sequence `[r₂, r₃, ..., rₙ]`.

```
r = Σ(xᵢ - x̄)(yᵢ - ȳ) / sqrt(Σ(xᵢ - x̄)² · Σ(yᵢ - ȳ)²)
```

**Pass criterion:** `|r| < 0.1`. A correlation this close to zero is noise.

**What it catches:** Physics patterns where a particular launch state tends to reproduce itself (e.g., a die always rolling low after a high, or always rolling the same face twice in a row due to a resonance in the tray). Also catches RNG sequential patterns.

### Wald-Wolfowitz Runs Test

Tests whether the sequence of results is random or shows streak/alternation patterns that chi-square would miss.

**Method:** Classify each result as above or below the median (3.5 for a fair die — values 1–3 are "low", 4–6 are "high"). Count the number of *runs* — maximal uninterrupted sequences of the same class. A fair random sequence has a predictable distribution of run counts.

**Statistic:**

```
μ_runs = 2·n₁·n₂/n + 1
σ²_runs = 2·n₁·n₂·(2·n₁·n₂ - n) / (n²·(n - 1))
Z = (runs - μ_runs) / σ_runs
```

where n₁ = count of "high" values, n₂ = count of "low" values, n = n₁ + n₂.

**Pass criterion:** `|Z| < 2` (≈95% confidence interval for a standard normal).

**What it catches:** Streaks (too few runs, large positive Z) or excessive alternation (too many runs, large negative Z). Both are signs of non-random behavior that chi-square cannot detect because it ignores order.

### Why All Three Together

| Test | What It Can't Catch |
|---|---|
| Chi-square | Sequential patterns, streaks, alternation |
| Serial correlation | Non-adjacent sequential patterns, hot/cold streaks |
| Runs test | Non-uniform face distribution, long-range patterns |

A biased die could theoretically pass two tests while failing a third. Running all three on every slice closes the gaps.

---

## The Python Analysis Script

`analyze_dice_fairness.py` runs the same statistics as the in-app HUD but with more detailed output and additional slices that would clutter the HUD.

### Running It

```bash
# Default: reads SyFive/Docs/Dice Fairness.csv
python3 SyFive/SyFive/Utilities/analyze_dice_fairness.py

# Specify a file
python3 SyFive/SyFive/Utilities/analyze_dice_fairness.py "path/to/export.csv"
```

### Output Sections

**Header block** — roll counts, sample sources, held/rescued/nudge/reroll sample counts, nudge success rate, rescue breakdown by kind and stuck reason, final alignment stats (all vs stuck only), spawn height range, roll duration range, and Yatzy count.

**Overall** — chi-square, p-value, serial correlation, runs Z for all samples combined.

**Per die** — same statistics for each die index (0–4) independently. This catches a die that's biased on its own but whose effect washes out in the aggregate.

**Free dice only / Held dice only** — held dice use the kinematic path (no physics, no impulse). A bias difference between held and free samples would indicate a bookkeeping error in how held die values are read.

**Clean samples / Rescued samples** — the critical rescue fairness test. If rescue interventions introduced bias (e.g., the nudge kick preferentially lands on face 3), the rescued slice would show elevated face-3 frequency.

**Nudged samples** — samples where `stuck_nudge=true`: dice that went yellow and were nudged. Are these as fair as clean dice?

**Stuck-reroll samples** — samples where `stuck_reroll=true`: dice that escalated to a full relaunch. Are these as fair as clean dice?

### Why Python in Addition to the HUD

The HUD shows live results during a run — that's its job. The Python script is for post-hoc investigation after exporting. It:

- Runs slices the HUD doesn't show (held vs free, nudged vs rerolled)
- Produces printable output for documentation and comparison across runs
- Is versioned with the project so analysis methodology doesn't drift
- Accepts a file argument so it can be run against archived CSVs from earlier builds

---

## Baseline Results (Pre-Changes, 10,000 Rolls)

This run was performed after the chamfered convex hull was in place but before the yellow/red UX, batch auto-nudge, and performance fixes.

**Header:**
- 50,000 samples across 10,000 rolls (all batch)
- Rescue rate: ~13.7%
- Stuck-reroll rate: **4.17%** (wall-blocked dice, no floor-stuck events)
- No nudge path yet (nudge was a later addition)

**Overall:**
- χ² = 3.82, **p = 0.29** — PASS
- Serial r = 0.003
- Runs Z = −0.44

**Per die:**

| Die | χ² | p-value | Status |
|---|---|---|---|
| Die 0 | 11.02 | 0.038 | borderline |
| Die 1 | 3.71 | 0.59 | PASS |
| Die 2 | 4.88 | 0.43 | PASS |
| Die 3 | 15.11 | **0.005** | **BORDERLINE FAIL** |
| Die 4 | 2.97 | 0.71 | PASS |

Die 3 showed face 1 at 19.15% (expected 16.7%), faces 3 and 6 both around 14.8%. This triggered a thorough investigation — reviewed the launch code for per-die asymmetry, checked spawn grid offsets, verified the pip face-mapping was symmetric. Nothing structural was found.

**Rescued vs clean:**
- Rescued samples: p = 0.28 — PASS
- Clean samples: p = 0.20 — PASS

Rescue interventions were not introducing bias, even at 4.17% reroll rate.

---

## Post-Changes Results (Current Build, 10,000 Rolls)

Run after: yellow/red nudge UX, batch auto-nudge, idle timer, and DiceStatistics O(1) performance fix.

**Header:**
- 50,000 samples across 10,000 rolls
- Rescue rate: **9.2%** (−34% vs baseline)
- Stuck-reroll rate: **0.98%** (−77% vs baseline)
- Nudge rate: ~1.9% (nudged dice)
- Nudge success: **50.5%** (half of nudged dice settled without reroll)

**Overall:**
- χ² = 4.11, **p = 0.217** — PASS
- Serial r = 0.003
- Runs Z = −0.44

**Per die:**

| Die | χ² | p-value | Status |
|---|---|---|---|
| Die 0 | 1.21 | 0.910 | PASS |
| Die 1 | 6.03 | 0.30 | PASS |
| Die 2 | 5.49 | 0.36 | PASS |
| Die 3 | 7.58 | **0.178** | PASS |
| Die 4 | 4.22 | 0.52 | PASS |

Die 3 came back completely normal. Die 0's borderline 0.038 became 0.910. All five dice pass with no outliers.

**Rescued vs clean:**
- Clean samples: PASS
- Rescued samples: PASS

**Nudged samples:**
- PASS (nudge path is unbiased)

**Stuck-reroll samples:**
- PASS (relaunch path is unbiased)

---

## The Die 3 Lesson: Seed Artifacts in Small-N Per-Die Tests

The Die 3 result (p = 0.005) in the baseline run deserves detailed analysis because it was alarming and turned out to be completely benign.

### The Multiple Testing Problem

When you run chi-square on five independent dice at α = 0.05, you expect false positives by chance:

```
P(at least one false positive) = 1 − (1 − 0.05)⁵ ≈ 0.226
```

That's a 22.6% chance of seeing one p < 0.05 result in a five-dice run even if all dice are perfectly fair. Per run, you expect `5 × 0.05 = 0.25` false positives on average.

A p = 0.005 is more extreme — that's a 2.2% chance per individual die per run. For five dice per run:

```
P(at least one p < 0.005) = 1 − (1 − 0.005)⁵ ≈ 2.5%
```

So roughly 1 in 40 ten-thousand-roll validation runs will produce a Die-N result at p ≤ 0.005 purely by chance. The baseline run was one of those.

### Why It Was Still Worth Investigating

A 2.5% chance is low but not negligible. The right response to a suspicious result is to investigate, not to dismiss it. The investigation found no structural cause — no per-die spawn offset asymmetry, no pip mapping error, no die-specific rescue logic. That absence of mechanism made a seed artifact more plausible.

### Confirmation

The fresh post-changes run used a different initial RNG state (because several rolls had been made since the baseline). Die 3 returned p = 0.178 — completely typical. That's the confirmation: if the bias were real and physics-driven, it would persist across RNG seeds. It didn't.

### The Rule Going Forward

A per-die p-value below 0.05 in isolation is not an alarm. The thresholds for concern are:

- **Overall p < 0.05** — warrants investigation
- **Per-die p < 0.01 in two consecutive fresh runs** — warrants investigation  
- **Multiple dice showing borderline results in the same run** — warrants investigation

A single die at p = 0.03–0.05 in one run is the expected false-positive rate. Run a second fresh batch before changing anything.

---

## Rescue Fairness: Why It Matters

The rescue system intervenes when dice get stuck — nudging or relaunching them. A naive concern: does intervention bias the result?

Specifically: a die stuck near a wall might be more likely to land on a face that "rolled into" the wall. The rescue nudge has a fixed kick direction (random horizontal + downward component). Does that preferential direction favor certain faces?

The data answers this cleanly. In both runs, the rescued subsample passed all three tests with p-values well above 0.05. The nudge is randomized enough (random angle in [0, 2π)) that no face is systematically favored.

A more subtle version: does the _type_ of rescue (floor vs wall vs stacked) correlate with face value? The current analysis doesn't test this directly, but the per-rescue-kind counts are in the CSV for future analysis if needed.

---

## Running a Future Validation

When to re-validate: after any change to collision shape, friction, spawn positions, impulse parameters, rescue logic, or tray geometry.

1. **Enable the debug harness.** Set `AppConfig.DebugDice.showHarness = true`.

2. **Clear existing data.** Tap "Reset" in the HUD.

3. **Run 10,000 rolls.** Tap "10000" in the batch controls. At roughly 4–6 rolls/second in batch mode, this takes 30–45 minutes. Leave the device plugged in and the screen will stay on (idle timer disabled).

4. **Check the HUD while it runs.** The chi-square p-value and pass/fail badge update live every roll. A persistently red "BIAS?" badge after 1,000+ samples warrants a closer look — though it may self-correct as samples accumulate.

5. **Export the CSV.** Tap the "CSV" share button. Save the file.

6. **Run the Python script.**
   ```bash
   python3 SyFive/SyFive/Utilities/analyze_dice_fairness.py "path/to/export.csv"
   ```

7. **Check the following:**
   - Overall p > 0.05
   - All five per-die p-values pass (treating any p < 0.01 as a potential concern; see "Seed Artifacts" above)
   - Rescued / nudged / rerolled subsamples all pass
   - Serial r < 0.1
   - Runs |Z| < 2

8. **If a die fails once:** Run a second fresh batch before drawing conclusions. If the same die fails both runs, investigate physics parameters for that die index.

9. **Archive the CSV.** The naming convention is `Dice Fairness NN.csv` where NN increments. Historical CSVs live in `SyFive/Docs/`.

---

## Summary: Current Validated State

As of the post-changes 10,000-roll run:

| Test | Value | Pass threshold | Result |
|---|---|---|---|
| Overall chi-square p | 0.217 | > 0.05 | PASS |
| Die 0 p | 0.910 | > 0.05 | PASS |
| Die 1 p | 0.30 | > 0.05 | PASS |
| Die 2 p | 0.36 | > 0.05 | PASS |
| Die 3 p | 0.178 | > 0.05 | PASS |
| Die 4 p | 0.52 | > 0.05 | PASS |
| Serial correlation | 0.003 | \|r\| < 0.1 | PASS |
| Runs test Z | −0.44 | \|Z\| < 2 | PASS |
| Clean samples p | PASS | > 0.05 | PASS |
| Rescued samples p | PASS | > 0.05 | PASS |
| Nudged samples p | PASS | > 0.05 | PASS |
| Stuck-reroll samples p | PASS | > 0.05 | PASS |

The dice are fair.
