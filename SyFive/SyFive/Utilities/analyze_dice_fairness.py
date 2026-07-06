#!/usr/bin/env python3
"""
Analyze exported SyFive dice fairness CSV data.

Run from the repo root:
    python3 SyFive/SyFive/Utilities/analyze_dice_fairness.py

Run against a specific export:
    python3 SyFive/SyFive/Utilities/analyze_dice_fairness.py "SyFive/Dice/Docs/Dice Fairness.csv"

Show command help:
    python3 SyFive/SyFive/Utilities/analyze_dice_fairness.py --help
""",

import csv
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path


def load_rows(csv_path: Path) -> list[dict[str, str]]:
    with csv_path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def chi_square_p_value(chi_square: float, degrees_of_freedom: int) -> float:
    if chi_square <= 0:
        return 1.0
    k = float(degrees_of_freedom)
    h = 1.0 - 2.0 / (9.0 * k)
    t = (chi_square / k) ** (1.0 / 3.0)
    z = (t - h) / math.sqrt(2.0 / (9.0 * k))
    return 0.5 * math.erfc(z / math.sqrt(2.0))


def serial_correlation(values: list[int]) -> float:
    if len(values) < 2:
        return 0.0
    x = values[:-1]
    y = values[1:]
    mean_x = sum(x) / len(x)
    mean_y = sum(y) / len(y)
    numerator = sum((a - mean_x) * (b - mean_y) for a, b in zip(x, y))
    denominator_x = sum((a - mean_x) ** 2 for a in x)
    denominator_y = sum((b - mean_y) ** 2 for b in y)
    if denominator_x <= 0 or denominator_y <= 0:
        return 0.0
    return numerator / math.sqrt(denominator_x * denominator_y)


def runs_test_z(values: list[int]) -> float:
    if len(values) < 10:
        return 0.0
    signs = [value > 3 for value in values]
    runs = 1
    for index in range(1, len(signs)):
        if signs[index] != signs[index - 1]:
            runs += 1

    positives = sum(signs)
    negatives = len(signs) - positives
    total = positives + negatives
    if positives == 0 or negatives == 0 or total <= 1:
        return 0.0

    mean_runs = 2 * positives * negatives / total + 1
    variance = (
        2
        * positives
        * negatives
        * (2 * positives * negatives - total)
        / (total * total * (total - 1))
    )
    if variance <= 0:
        return 0.0
    return (runs - mean_runs) / math.sqrt(variance)


def summarize_values(values: list[int]) -> dict[str, object]:
    sample_count = len(values)
    counts = Counter(values)
    expected = sample_count / 6 if sample_count else 0.0
    chi_square = (
        sum((counts[face] - expected) ** 2 / expected for face in range(1, 7))
        if expected
        else 0.0
    )
    return {
        "samples": sample_count,
        "counts": {face: counts[face] for face in range(1, 7)},
        "freqs": {
            face: (counts[face] / sample_count if sample_count else 0.0)
            for face in range(1, 7)
        },
        "expected": expected,
        "chi_square": chi_square,
        "p_value": chi_square_p_value(chi_square, 5),
        "serial_corr": serial_correlation(values),
        "runs_z": runs_test_z(values),
    }


def print_summary(label: str, values: list[int]) -> None:
    summary = summarize_values(values)
    print(label)
    print(f"  samples: {summary['samples']}")
    print(f"  counts:  {summary['counts']}")
    freq_str = ", ".join(
        f"{face}: {freq * 100:.2f}%" for face, freq in summary["freqs"].items()
    )
    print(f"  freqs:   {{{freq_str}}}")
    print(f"  expected per face: {summary['expected']:.3f}")
    print(f"  chi-square: {summary['chi_square']:.4f}")
    print(f"  p-value:    {summary['p_value']:.6f}")
    print(f"  serial r:   {summary['serial_corr']:.6f}")
    print(f"  runs z:     {summary['runs_z']:.6f}")


def print_usage(script_name: str) -> None:
    print(f"Usage: python3 {script_name} [csv_path]")
    print()
    print("Examples:")
    print(f"  python3 {script_name}")
    print(f'  python3 {script_name} "SyFive/Dice/Docs/Dice Fairness.csv"')
    print()
    print("If no CSV path is provided, the script reads SyFive/Dice/Docs/Dice Fairness.csv.")


def main() -> int:
    default_csv = Path(__file__).resolve().parent.parent / "Dice" / "Docs" / "Dice Fairness.csv"

    if len(sys.argv) > 1 and sys.argv[1] in {"-h", "--help"}:
        print_usage(Path(sys.argv[0]).name)
        return 0

    csv_path = Path(sys.argv[1]) if len(sys.argv) > 1 else default_csv

    if not csv_path.exists():
        print(f"CSV not found: {csv_path}", file=sys.stderr)
        print_usage(Path(sys.argv[0]).name)
        return 1

    rows = load_rows(csv_path)
    if not rows:
        print("CSV contains no data rows.", file=sys.stderr)
        return 1

    values = [int(row["value"]) for row in rows]
    roll_ids = [int(row["roll_id"]) for row in rows]
    held_flags = [row["held"].lower() == "true" for row in rows]
    die_indices = [int(row["die_index"]) for row in rows]
    sources = Counter(row["source"] for row in rows)
    rescued_flags = [row["rescued"].lower() == "true" for row in rows]
    escape_recovered = [row["escape_recovered"].lower() == "true" for row in rows]
    stuck_reroll = [row["stuck_reroll"].lower() == "true" for row in rows]
    stuck_nudge = [row.get("stuck_nudge", "false").lower() == "true" for row in rows]
    rescue_kinds = Counter(row["rescue_kind"] for row in rows if row["rescue_kind"])
    stuck_reasons = [row.get("stuck_reason", "") for row in rows]
    stuck_reason_counts = Counter(r for r in stuck_reasons if r)
    final_aligns = [float(row["final_align"]) for row in rows if row.get("final_align")]
    unsettled_secs = [float(row["unsettled_secs"]) for row in rows if row.get("unsettled_secs")]
    roll_values: dict[int, list[int]] = defaultdict(list)
    for row in rows:
        roll_values[int(row["roll_id"])].append(int(row["value"]))

    yatzys = [
        values_for_roll[0]
        for values_for_roll in roll_values.values()
        if len(values_for_roll) == 5 and len(set(values_for_roll)) == 1
    ]
    yatzy_counts = Counter(yatzys)

    print(f"File: {csv_path}")
    print(f"Rolls: {len(set(roll_ids))}")
    print(f"Sources: {dict(sources)}")
    print(f"Held samples: {sum(held_flags)}")
    print(f"Rescued samples: {sum(rescued_flags)}")
    print(f"Escape-recovered samples: {sum(escape_recovered)}")
    print(f"Stuck-nudge samples: {sum(stuck_nudge)}")
    print(f"Stuck-reroll samples: {sum(stuck_reroll)}")
    nudge_then_reroll = sum(n and r for n, r in zip(stuck_nudge, stuck_reroll))
    if sum(stuck_nudge) > 0:
        nudge_success = sum(stuck_nudge) - nudge_then_reroll
        print(f"  nudge settled: {nudge_success}  nudge→reroll: {nudge_then_reroll}  ({nudge_success / sum(stuck_nudge) * 100:.1f}% success)")
    print(f"Rescue kinds: {dict(rescue_kinds)}")
    print(f"Stuck reasons: {dict(stuck_reason_counts)}")
    if final_aligns:
        stuck_aligns = [float(row["final_align"]) for row in rows if row.get("stuck_reason")]
        stuck_unsettled = [float(row["unsettled_secs"]) for row in rows if row.get("stuck_reason")]
        print(f"Avg final alignment (all): {sum(final_aligns)/len(final_aligns):.4f}")
        if stuck_aligns:
            print(f"Avg final alignment (stuck only): {sum(stuck_aligns)/len(stuck_aligns):.4f}  avg unsettled: {sum(stuck_unsettled)/len(stuck_unsettled):.2f}s")
            xs = [float(row["final_x"]) for row in rows if row.get("stuck_reason")]
            zs = [float(row["final_z"]) for row in rows if row.get("stuck_reason")]
            hs = [float(row["final_height"]) for row in rows if row.get("stuck_reason") and row.get("final_height")]
            print(f"Stuck positions — x range: [{min(xs):.3f}, {max(xs):.3f}]  z range: [{min(zs):.3f}, {max(zs):.3f}]")
            if hs:
                print(f"Stuck final heights — min: {min(hs):.4f}  max: {max(hs):.4f}  avg: {sum(hs)/len(hs):.4f}")

    spawn_ys = [float(row["spawn_y"]) for row in rows if row.get("spawn_y")]
    if spawn_ys:
        print(f"Spawn heights — min: {min(spawn_ys):.4f}  max: {max(spawn_ys):.4f}  avg: {sum(spawn_ys)/len(spawn_ys):.4f}")

    durations = [float(row["roll_duration_secs"]) for row in rows if row.get("roll_duration_secs")]
    if durations:
        unique_durations = list({row["roll_id"]: float(row["roll_duration_secs"]) for row in rows if row.get("roll_duration_secs")}.values())
        print(f"Roll durations — min: {min(unique_durations):.2f}s  max: {max(unique_durations):.2f}s  avg: {sum(unique_durations)/len(unique_durations):.2f}s")

    print(f"Yatzys rolled: {len(yatzys)}")
    print(f"Yatzy faces: {dict({face: yatzy_counts[face] for face in range(1, 7) if yatzy_counts[face]})}")
    print()

    print_summary("Overall", values)
    print()

    per_die_values: dict[int, list[int]] = defaultdict(list)
    for die_index, value in zip(die_indices, values):
        per_die_values[die_index].append(value)

    print("Per die")
    for die_index in sorted(per_die_values):
        print_summary(f"  Die {die_index}", per_die_values[die_index])
    print()

    free_values = [value for value, held in zip(values, held_flags) if not held]
    held_values = [value for value, held in zip(values, held_flags) if held]
    if free_values:
        print_summary("Free dice only", free_values)
        print()
    if held_values:
        print_summary("Held dice only", held_values)
        print()

    rescued_values = [value for value, rescued in zip(values, rescued_flags) if rescued]
    clean_values = [value for value, rescued in zip(values, rescued_flags) if not rescued]
    if clean_values:
        print_summary("Clean samples", clean_values)
        print()
    if rescued_values:
        print_summary("Rescued samples", rescued_values)
        print()

    nudged_values = [value for value, nudged in zip(values, stuck_nudge) if nudged]
    rerolled_values = [value for value, rerolled in zip(values, stuck_reroll) if rerolled]
    if nudged_values:
        print_summary("Nudged samples", nudged_values)
        print()
    if rerolled_values:
        print_summary("Stuck-reroll samples", rerolled_values)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
