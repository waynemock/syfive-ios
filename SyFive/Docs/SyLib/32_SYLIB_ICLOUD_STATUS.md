# SyLib's iCloud status in SyFive: the toolbar cloud and Settings' iCloud row, as Score It \*

**Status:** **Done (32.1); V1, V2 pass.** Version 1.0, 7 November 2026. In SyFive 1.2.0, before the first
TestFlight build (Pops, 7 November 2026).

**Scope:** `syfive-ios` on `sylib-reintegration`. SyLib is unchanged: every piece is SyLibCloud's
today, and SyFive already links it.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A`, `00B`, this document, SyLib
`Docs/CLOUD.md`.

---

## Supersessions

- **`04` §5.1's "never prompt for sign-in"** goes (D-185). The rest of §5.1 stands: SyFive is fully
  functional signed out, and nothing gates play, resume or history on iCloud.
- **`26` §2's exclusion of `ICloudStatusButton(pulses:)`** ("no iCloud button") is withdrawn (D-185).
- Nothing else in the ledger is superseded.

---

## 1. Why

Score It \* shows iCloud's state in two places, both SyLibCloud's (read 7 November 2026,
`score-it-all-ios` at `3c26af0`):

| Where | Score It \* | SyFive today |
|---|---|---|
| Root | `@State cloudStatus = CloudAccountStatus(containerIdentifier: ScoreItAllApp.cloudKitContainerID)`, `.environment(cloudStatus)`, and `.task { await cloudStatus.refresh() }` skipped in previews (`RootView` 30, 146–151) | Nothing |
| Toolbar | `ICloudStatusButton(tint: syTheme.primaryAccent, pulses: false) { present(.iCloud) }`, first in the Games list's trailing group (`GameListView` 132) | Nothing |
| Settings | Last section "iCloud": a button whose label is `LabeledContent("iCloud Sync", value: cloudStatus.isAvailable ? "On" : "Off")`, `.foregroundStyle(.primary)`, opening the sheet (`SettingsSheet` 91–98) | Nothing |
| Sheet | `ICloudInfoSheet(appName: "Score It *", accentColor:, backgroundColor:)`, standard copy, with the root's text-size cap | Nothing |

The button draws nothing unless `CloudAccountStatus.showsPrompt`: the state is known, iCloud isn't
available, and the user hasn't chosen the sheet's "Don't show this again" (`CLOUD.md`). Today a
SyFive player signed out of iCloud has no way to learn their games aren't syncing or backed up.

---

## 2. Locked decisions (Pops, 7 November 2026)

**2.1 SyFive shows iCloud's state as Score It \* does** (D-185): the toolbar cloud and a Settings
"iCloud" section, both opening `ICloudInfoSheet` with SyLib's standard copy for "SyFive". This
supersedes `04` §5.1's "never prompt" and `26`'s exclusion. *Rationale:* the cloud appears only
while iCloud is off, never blocks play, and can be dismissed for good; the player learns their
data isn't synced or backed up.

**2.2 The cloud is first in the trailing toolbar group**, before How to Play's ? and the ⋯, with no
pulse (Score It \*'s toolbar form).

**2.3 It shows whenever iCloud is off** (D-186), during a game and Game Night too; "Don't show this
again" hides it for good, and Settings' row stays.

**2.4 In 1.2.0** (Pops).

### 2.5 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| A Settings row only | Pops wants the cloud (§2.1) |
| Hiding the cloud mid-game or in Game Night | §2.3 |
| SyFive's own iCloud copy | SyLib's standard text fits SyFive as it fits Score It \* |
| The sheet's ladybug debug action | Score It \* doesn't pass it |

---

## 3. Task 32.1 · SyFive: iCloud status in the toolbar and Settings

- **Inputs:** §1, §2; SyLib `CLOUD.md` (`CloudAccountStatus`, `ICloudStatusButton`,
  `ICloudInfoSheet`); Score It \*'s `RootView`, `GameListView` and `SettingsSheet` at the lines in
  §1 (read only).
- **`SyFiveApp.swift`:** `@State private var cloudStatus =
  CloudAccountStatus(containerIdentifier: SyFiveApp.cloudKitContainerID)`; on `ContentView()`,
  `.environment(cloudStatus)` beside `.environment(gameNight)`, and in the existing `.task`, before
  `listenForSessions`, `await cloudStatus.refresh()` unless
  `ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"`, as Score It \*'s.
- **`Views/ContentView.swift`:** import SyLibCloud. First in the `.topBarTrailing` group:
  `ICloudStatusButton(tint: theme.primaryAccent, pulses: false) { showsICloud = true }`. A new
  `@State var showsICloud = false` beside the others, and
  `.sheet(isPresented: $showsICloud) { ICloudInfoSheet(appName: "SyFive", accentColor:
  theme.primaryAccent, backgroundColor: theme.backgroundColor).sheetTextSizeCeiling() }` beside the
  Settings sheet.
- **`Views/SettingsView.swift`:** import SyLibCloud. `SettingsForm` reads
  `@Environment(CloudAccountStatus.self) private var cloudStatus` and ends with a section, after
  Commentary:

  ```swift
  Section {
      Button { showsICloud = true } label: {
          LabeledContent("iCloud Sync", value: cloudStatus.isAvailable ? "On" : "Off")
              .foregroundStyle(.primary)
      }
  } header: {
      Text("iCloud")
          .foregroundStyle(theme.primaryAccent)
  }
  ```

  with `@State private var showsICloud = false` and, on the `Form`,
  `.sheet(isPresented: $showsICloud) { ICloudInfoSheet(appName: "SyFive", accentColor:
  theme.primaryAccent, backgroundColor: theme.backgroundColor).sheetTextSizeCeiling() }`.
- **Previews:** every preview that draws `ContentView` or `SettingsView` gains
  `.environment(CloudAccountStatus())`, which never asks CloudKit (iCloud Sync shows Off).
- **Must not touch:** SyLib; the container and the schema push; the rest of the toolbar and
  Settings.
- **Done when:** the build and SyFive's suite pass (20).

## 4. Validation (Pops, iPhone and iPad)

| # | Check | Pass |
|---|---|---|
| V1 | Signed into iCloud | No cloud in the toolbar; Settings › iCloud Sync "On"; tapping it opens "SyFive + iCloud", connected |
| V2 | Not signed in (a simulator with no Apple Account, or a device signed out) | The slashed cloud with its red dot, first on the right, no pulse; tapping opens the sheet's how-to; Settings shows "Off" |
| V3 | In the sheet, "Don't show this again" | The cloud goes and stays gone after relaunch; Settings' row still opens the sheet |
| V4 | Mid-game, signed out | The cloud is there; play is unaffected |
| V5 | At AX5 | The sheet holds at AX2 (29) |

## 5. Ledger rows

| ID | Ruling | Source |
|---|---|---|
| D-185 | **SyFive shows iCloud's state as Score It \* does**: SyLibCloud's `ICloudStatusButton` first in the trailing toolbar (no pulse) and a last Settings section "iCloud" with "iCloud Sync" On/Off, both opening `ICloudInfoSheet` (standard copy, "SyFive"). In 1.2.0. Supersedes `04` §5.1's "never prompt for sign-in" (play is still never gated on iCloud) and `26` §2's exclusion of the button. | `32 §2.1` (Pops, 7 Nov 2026) |
| D-186 | **The cloud shows whenever iCloud is off**, during a game and Game Night too, until "Don't show this again"; Settings' row always stays. | `32 §2.3` |

## 6. Results log

| Task / V | Date | Result | Notes |
|---|---|---|---|
| 32.1 | 7 Nov 2026 | Done (checked by Claude against the tree) | `SyFiveApp`: `cloudStatus` for `cloudKitContainerID`, in the environment beside `gameNight`, refreshed in the existing `.task` before `listenForSessions`, skipped in previews. `ContentView`: `ICloudStatusButton(pulses: false)` first in `.topBarTrailing`; `showsICloud` sheet with `.sheetTextSizeCeiling()`. `SettingsView`: last section "iCloud", "iCloud Sync" On/Off, same sheet. Both previews have `CloudAccountStatus()`. SyFive 20 expected |
| V1 | 7 Nov 2026 | **Pass** (Pops, iPhone signed into iCloud) | |
| V2 | 7 Nov 2026 | **Pass** (Pops, iPad with no Apple Account) | |
| V3–V5 | | Not reported | |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 7 Nov 2026 | First version |
