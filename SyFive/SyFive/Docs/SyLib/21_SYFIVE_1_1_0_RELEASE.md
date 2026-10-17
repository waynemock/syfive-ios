# SyFive 1.1.0: release close-out

**Status:** Ready for the agent. Written 11 October 2026. This is the last document of the 1.1.0
reintegration (`15` to `21`).

**Scope:** `SyFive` docs (§4.1, §4.3), `sylib-swift` docs on branch `syfive-reintegration` (§4.2), and
the ledger (§4.3). **No code changes.**

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document.

---

## Supersessions

| Overrides | With | Why |
|---|---|---|
| `19` §2.2 (two styles, `.link` and `.prominent`) and §4.1's button body | One look in every app: a centred `.accent` `CapsuleButton`, with no style parameter. D-145 is already reworded | Pops's change after `19` §4.2, recorded in `19` §8. Recorded here so `19`'s text is not mistaken for what shipped |
| `15` Supersessions row 3: on disk, SyLib's docs are `Commentary.md`, `Feel.md` and `Scoring.md` | SyLib's docs are now all upper-case on disk (`COMMENTARY.md`, `FEEL.md`, `SCORING.md`, `LOGGING.md`, and so on), matching SyLib's README | Renamed in SyLib after `18`. Older SyFive docs keep the names they were written with (D-001); on macOS either case opens the file |

---

## 1. Where 1.1.0 stands

Done and recorded:
- **`15` to `20`**: every agent task, with suites green at the end of `20`. SyLib 1133 tests in 121
  suites; Syderal 897 / 893 passed / 4 skipped / 0 failed, with no source edit; SyFive 19/19. All
  0 warnings.
- **Device checks recorded so far**: R1 to R18 (`15`), H1 (`19`), P1 (`20`).
- **CloudKit**: Production deployed from Development by Pops on 10 October 2026 (`17` §10). No model
  has changed since.

**Done but not yet written down:** the 1.1.0 release gate. That is the full device regression
from `17` §6 (R1 to R22, F1 to F6, A1 to A11) plus `18`'s C1, C3 and C4. Pops ran it, and all passed,
on 11 October 2026. §4.1 records it.

---

## 2. Locked decisions

**2.1 The release gate passed** (Pops, on device, 11 October 2026). Recorded as "confirmed by Pops on
device" (`00A` §6), not in the session's voice.

**2.2 `18` §4.6's diagnostic logging ships in 1.1.0 at info level** (D-147). It is the best chance
of catching the lost-restart-button / lost-save report in the field. It costs a few log lines per
score. Remove it once that report is resolved. *(rec.)*

**2.3 Carried forward, not blocking 1.1.0:**
- The RealityKit launch assertion (D-144). The device check is still to run.
- The restart-button / lost-save report, waiting for a reproduction with the new logs.
- Whether SyFive's root Dynamic Type limit reaches its sheets (`15` R15, still unanswered).

---

## 3. Before starting

- `20` is complete.

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 Record the release gate

Append rows to the results logs only. Every row reads **"Pass (confirmed by Pops on device, 11 Oct
2026)"** unless stated otherwise. Do not edit any other text in these documents (D-001).

| Document | Rows to fill |
|---|---|
| `16` §10 | F1 to F6, R19 (both parts), R20, R21, and the R1 to R3 and R11 re-runs. Each existing "Not run" row gets a new line beneath it with the pass |
| `17` §10 | A1 to A11, one row each. The "Full regression (R1 to R22, F1 to F6, A1 to A11) on Release" row: pass, with the Debug-only checks (F1, F6, R22, A9) run on Debug, as `17` §6 allows |
| `18` §10 | C1, C3 and C4: pass. C2: pass, read at source by `18` §4.2. "Restart-button / lost-save report": **not reproduced as of 11 Oct 2026**. "RealityKit device check": **not run as of 11 Oct 2026; carried forward (D-144)** |

**Done when:** every row above is present with that wording, and no other text changed.

### 4.2 SyLib: two doc lines

On `sylib-swift`, branch `syfive-reintegration`:

1. `Docs/COMMENTARY.md` line 361, the shuffle paragraph: replace the closing sentence "SyFive
   adoption: optional; nothing changes unless it calls them." with "SyFive adoption: adopted in SyFive
   1.1.0 (`17` §4.6)." Nothing else in the paragraph changes.
2. `Docs/GAME_NIGHT.md` line 519: replace "(see `Logging.md`)" with "(see `LOGGING.md`)". That doc is
   now upper-case on disk, and a mixed-case link breaks on a case-sensitive host.
3. Search `Docs/` and `README.md` for any other link to a mixed-case doc name. Report it; do not edit
   it. The search before this document found only item 2.

**Done when:** both lines read as above; the search is reported; SyLib's suite passes at 1133. These
are docs, so the total is unchanged.

### 4.3 Docs and ledger

1. **Ledger:** paste D-147 from §7 under **Platform & data**.
2. **`IMPLEMENTATION_STATUS.md`:** change the 1.1.0 line `17` §5 added to "Rebuilt on the post-Syderal
   SyLib; see `15` to `21`."
3. **`project.pbxproj`:** add `Docs/SyLib/21_SYFIVE_1_1_0_RELEASE.md` to the docs list beside `15` to
   `20`, as was done for `18` to `20`.

**Done when:** the three edits are in; `BuildProject` is clean; the suite passes at 19/19.

---

## 5. Release steps (Pops)

After §4, in this order. Agents never run `git` (`00A` §9).

1. **Pre-archive checklist** (`00B` §6):
   - every `AppConfig` flag is `false`;
   - `MARKETING_VERSION` is 1.1.0 in both configurations;
   - CloudKit Production matches Development (unchanged since 10 October).
2. **Merge SyLib** `syfive-reintegration` into `main`. Syderal's `24` waits for this.
3. **Merge SyFive's** reintegration branch.
4. **Archive** 1.1.0, set the build number, and write the App Store "What's New" copy, which is
   yours (`00B` §2).

---

## 6. Open decisions

None.

---

## 7. Ledger row

**Platform & data**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-147 | **1.1.0 ships `18` §4.6's diagnostic logging at info level** (Play Again state, score changes, the leading toolbar slot, `saveMatch` outcomes and failures), to catch the lost-restart-button / lost-save report in the field. It is removed once that report is resolved. | `18` §4.6 → `21` §2.2 *(rec.)* |

---

## 8. Results log

| Item | Value |
|---|---|
| §4.1 rows recorded | **Done 11 Oct 2026.** `16` §10: F1–F6, R19 (a) and (b), R20, R21 and the R1–R3/R11 re-runs, each on a new row beneath its "Not run" row. `17` §10: A1–A11, one row each, plus the Full regression row (Release, Debug-only checks on Debug). `18` §10: C1, C3, C4 pass; C2 pass, read at source; restart report not reproduced; RealityKit device check not run, carried forward (D-144). No other text changed |
| §4.2: the two lines; search report; SyLib total | **Done 11 Oct 2026.** `COMMENTARY.md` line 361 ends "SyFive adoption: adopted in SyFive 1.1.0 (`17` §4.6)."; nothing else in the paragraph changed. `GAME_NIGHT.md` line 519 reads "(see `LOGGING.md`)". **Search:** every `.md` doc name in SyLib `Docs/` and `README.md` was checked against the files on disk; no other mixed-case reference remains. **SyLib 1133 in 121 suites, passed** (unchanged), 0 warnings |
| §4.3: ledger, status line, project file; SyFive suite | **Done 11 Oct 2026.** D-147 pasted under Platform & data, after D-145; no other ledger row changed. `IMPLEMENTATION_STATUS.md`'s 1.1.0 line reads "Rebuilt on the post-Syderal SyLib; see `15` to `21`." `project.pbxproj` already lists `Docs/SyLib/21_SYFIVE_1_1_0_RELEASE.md` beside 15 to 20 (line 95, added when the doc was dropped in), so no edit was needed. BuildProject clean; **SyFive 19/19** on the pinned destination. Also this session: the seven multi-line results-log rows in `18`, `19` and `20` were joined onto single lines (`<br>` for breaks), formatting only, with every word unchanged |
| §5 (Pops): archive date, build number | |
