# SyFive Game Night audio: no Mix with Other Audio during Game Night, as Syderal

**Status:** **33.1 done and checked, 8 November 2026; open for V1** (Pops, two devices on
FaceTime). The ledger row is filed when V1 passes. Version 1.0, 8 November 2026.

**Scope:** `syfive-ios` on `sylib-reintegration`. SyLib is unchanged: `FeelSettingsRows(soundModes:)`
landed in Syderal `26` Task 26.10 and is on SyLib `main`.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md` (now v1.12),
`00B_SYFIVE_GUARDRAILS.md`, this document, SyLib `Docs/FEEL.md`.

**Studio conventions:** `00A` was brought from v1.7 to v1.12 on 8 November 2026, copied from
Syderal's. These parts matter here:
- **§6:** the session writes its summary as a row at the top of this document's Results log,
  as its last step.
- **§7:** the suite runs with `00B`'s pinned `xcodebuild` command, never Xcode's test action.
- **§8:** an error or warning the session's own change causes, an import for example, is fixed
  without stopping, as long as the fix changes no behavior, test expectation or public API. A task
  isn't done with an error or warning it introduced.
- **v1.8:** this session works in SyFive only.

---

## 1. Why

In a FaceTime Game Night, "Mix with Other Audio" made Syderal's call echo: each device's game
audio mixed into the call. Setting the devices to "Game Audio Only" stopped it (Pops, on device,
Syderal `26` 26.10, S-11). SyFive has the same setup. Its sound default is Mix (`AppSettingsModel.soundModeRaw`),
and its Game Night runs over FaceTime or Messages. Its proximity mute (D-GNP) covers devices in the
same room, not a call.

## 2. Locked decisions (Pops, 8 November 2026)

**2.1 While a Game Night session is active, Mix with Other Audio isn't offered** (D-193):
- **The choices:** Settings' Sound picker shows Off and Game Audio Only. The player can still
  change it, just not to Mix.
- **A saved Mix** plays as Game Audio Only, and the picker shows that.
- **The saved setting isn't rewritten:** after Game Night, a saved Mix is Mix again. A choice made
  during Game Night is saved, as any Settings change is.
- **The footer** adds: "During Game Night, SyFive plays as Game Audio Only, so the call doesn't echo."
- **"Active"** is `GameNightController.isSessionActive`.

**2.2 Commentary is unchanged** (Pops, 8 November 2026, reviewing Syderal's Highlights change for
SyFive). The default stays Celebrations (`AppSettingsModel.commentaryLevelRaw`), turn starts stay
play-by-play, and no existing player's level moves.

### 2.3 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| Highlights as SyFive's default | SyFive is already Celebrations, and Pops keeps it (2.2) |
| A brief turn start at Highlights, as Syderal's `turnStartBrief` | Left as is (Pops) |
| Moving everyone on Celebrations to Highlights | Not wanted. It also can't tell a chosen Celebrations from the default |
| Disabling or hiding the whole Sound row in Game Night | Pops: the player can still change it, just not to Mix |
| A shared `GameNightAudio` in SyLib now | Syderal's and SyFive's copies are the same 15 lines. It's a SyLib candidate when a third app needs it, and moving it now would mean editing Syderal from this session (`00A` v1.8) |

---

## 3. Task 33.1 · Game Night plays as Game Audio Only

- **Inputs:** §2; SyLib `Docs/FEEL.md` (`FeelSettingsRows`, `soundModes:`). Read Syderal's
  `App/GameNightAudio.swift` only as described here; don't open Syderal (`00A` v1.8). Everything
  needed is below.
- **Change:**
  1. New file `SyFive/App/GameNight/GameNightAudio.swift`:
     ```swift
     import SwiftUI
     import SyLibFeel

     // During Game Night, Mix with Other Audio plays as Game Audio Only: mixed game audio echoes in
     // the FaceTime call (33 §2.1, D-193). The saved setting is never rewritten.
     enum GameNightAudio {
         static func effectiveSoundMode(_ saved: AppSoundMode, gameNightActive: Bool) -> AppSoundMode {
             gameNightActive && saved == .mix ? .exclusive : saved
         }
         static func choices(gameNightActive: Bool) -> [AppSoundMode] {
             gameNightActive ? [.off, .exclusive] : AppSoundMode.allCases
         }
         static let footerNote = "During Game Night, SyFive plays as Game Audio Only, so the call doesn't echo."
     }

     extension EnvironmentValues {
         // Whether a Game Night session is active, for Settings' Sound row (33 §2.1).
         @Entry var gameNightAudioActive = false
     }
     ```
  2. `Views/ContentView+Commentary.swift`:
     - Add, in the extension:
       ```swift
       /// The Sound setting as played: Mix plays as Game Audio Only during Game Night (33, D-193).
       var effectiveSoundMode: AppSoundMode {
           GameNightAudio.effectiveSoundMode(appSettings?.soundMode ?? .mix,
                                             gameNightActive: gameNight.isSessionActive)
       }
       ```
     - In `handleSoundModeChanged()`, `director.soundMode = appSettings?.soundMode ?? .mix` becomes
       `director.soundMode = effectiveSoundMode`. Its doc comment adds: "Also called when a Game
       Night session starts or ends."
  3. `Views/ContentView.swift`:
     - In `.onAppear`, `director.soundMode      = appSettings?.soundMode      ?? .mix` becomes
       `director.soundMode      = effectiveSoundMode`.
     - Beside `.onChange(of: appSettings?.soundModeRaw) { _, _ in handleSoundModeChanged() }`, add
       `.onChange(of: gameNight.isSessionActive) { _, _ in handleSoundModeChanged() }`.
     - The Settings sheet (`SettingsView()` … `.environment(director)`) gains
       `.environment(\.gameNightAudioActive, gameNight.isSessionActive)` after `.environment(director)`.
  4. `Views/SettingsView.swift`, in `SettingsForm`:
     - Add `@Environment(\.gameNightAudioActive) private var gameNightAudioActive`.
     - The `FeelSettingsRows(…)` call becomes:
       ```swift
       FeelSettingsRows(soundMode: Binding(
                            get: { GameNightAudio.effectiveSoundMode(settings.soundMode, gameNightActive: gameNightAudioActive) },
                            set: { settings.soundMode = $0 }),
                        hapticsEnabled: $settings.hapticsEnabled,
                        hapticsSupported: director.hapticSupported,
                        soundModes: GameNightAudio.choices(gameNightActive: gameNightAudioActive))
       ```
     - The footer becomes
       `Text(gameNightAudioActive ? FeelSettingsRows.footer + " " + GameNightAudio.footerNote : FeelSettingsRows.footer)`.
  5. **Tests, new `SyFiveTests/GameNightAudioTests.swift`, total + 3:**
     1. In Game Night, Mix becomes Game Audio Only, and Off and Game Audio Only are unchanged.
     2. Outside Game Night, every mode is unchanged.
     3. The choices are `[.off, .exclusive]` in Game Night and `AppSoundMode.allCases` outside it.
- **Must not touch:**
  - `AppSettingsModel` (the saved value) and the commentary level;
  - `shouldMuteCommentary` and the proximity mute, except that `handleSoundModeChanged()` now also
    runs on a Game Night change (its Off-to-on reset still fires only when leaving Off);
  - `FeelBoardView`'s debug sound toggle;
  - SyLib; Syderal.
- **Done when:**
  1. The build passes.
  2. `00B`'s pinned SyFive command passes at the previous total + 3.
  3. The summary row (`00A` §6) is at the top of §5.
  4. Pops checks V1.

## 4. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | Two devices in a FaceTime Game Night, one saved at Mix. Open Settings during Game Night, play a turn, then end Game Night | During: the Sound picker offers Off and Game Audio Only, shows Game Audio Only on the Mix device, and the footer adds the Game Night note. No echo in the call. Choosing Off works. After: the Mix device's Settings shows Mix again |

## 5. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| 33.1 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: every edit is as §3 specifies, nothing outside it changed. Report (1) is fine: the existing `isSessionActive` handler only runs on end (dismiss and `syncCommentaryEngine()`), and the new one just re-derives the sound mode, so their order doesn't matter. Report (2) noted; 20 tests (23 runs) is the new baseline. V1 is Pops's | Before: `** TEST SUCCEEDED **`, 20 tests (23 runs), 0 failed. After: `** TEST SUCCEEDED **`, 23 tests (26 runs), 0 failed: + `GameNightAudioTests`' three, none removed. Runs exceed tests because `SyFiveUITestsLaunchTests.testLaunch()` runs 4 times. Counted from the run's `Test case … passed` lines (xcodebuild prints no summary total). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** new `SyFive/App/GameNight/GameNightAudio.swift` (§3 step 1, verbatim); `Views/ContentView+Commentary.swift` (`effectiveSoundMode`; `handleSoundModeChanged()` uses it, plus the doc-comment sentence); `Views/ContentView.swift` (`.onAppear` uses `effectiveSoundMode`; `.onChange(of: gameNight.isSessionActive) { handleSoundModeChanged() }` beside `soundModeRaw`'s; Settings sheet gets `.environment(\.gameNightAudioActive, …)` after `.environment(director)`); `Views/SettingsView.swift` (`SettingsForm`: environment value, get/set `Binding` with `soundModes:`, conditional footer; the blank line after it lost its trailing spaces); new `SyFiveTests/GameNightAudioTests.swift` (Swift Testing, `@MainActor` like `CommentaryPackTests`); this row. **Build:** `BuildProject` passed before and after (with test targets), 0 warnings both times; no fixes needed. **Git (read-only):** `git status --short`, `git diff --stat HEAD -- Docs/Requirements/`, `git diff`. **Report:** (1) `ContentView` already had `.onChange(of: gameNight.isSessionActive)` (line 282: dismiss the sheet and `syncCommentaryEngine()` on end), so there are now two handlers for that value; SwiftUI runs both, and they're independent. (2) Doc 32's baseline was 19 tests (22 runs); it was 20 (23) before this session, and 35.1 added none, so the extra test came in between. Not investigated. V1 is Pops's |

## 6. Ledger row (Claude files it when 33 closes)

| ID | Ruling | Source |
|---|---|---|
| D-193 | **During a Game Night session, Mix with Other Audio isn't offered and a saved Mix plays as Game Audio Only** (it echoed in FaceTime, Syderal S-11). Settings offers Off and Game Audio Only and says why; the saved setting is never rewritten. SyFive's commentary level default stays Celebrations. | `33 §2` (Pops, 8 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 8 Nov 2026 | First version |
