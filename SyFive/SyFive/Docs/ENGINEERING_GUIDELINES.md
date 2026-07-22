# Engineering Guidelines — SyFive

## Purpose

Project-specific implementation rules for SyFive, a SwiftUI Yatzy game for iOS/iPadOS.

Follow these guidelines when adding or refactoring code so the project stays consistent and easy to navigate as it grows.

---

## SwiftUI View Structure

SyFive follows a **one view per file** rule.

Each SwiftUI `View` should live in its own `.swift` file under `Views/`.

Current views:

```text
Views/
  ContentView.swift          — top-level navigation shell
  ScorecardView.swift        — horizontal card scroll + layout orchestration
  PlayerScoreCardView.swift  — single player's score card
  ScoreRow.swift             — individual score cell(s) for a category row
  DiceAreaView.swift         — dice tray + roll controls
  DiceRKView.swift           — RealityKit dice renderer
  DicePill.swift             — dice value badge
  DiceDebugHUD.swift         — debug overlay (AppConfig-gated)
  PlayerPickerSheet.swift    — player roster management sheet
  PlayerEditSheet.swift      — create/edit a single player
  SafeAreaDebugView.swift    — layout debug overlay (AppConfig-gated)
```

Private helper methods are fine inside a view file. Separate visual components should become their own view file.

Do not hide reusable or visual SwiftUI subcomponents as `private struct ...: View` inside a screen file. If a piece of UI has its own layout, state, animation, preview need, or can be named as a component, give it its own file.

Screen files may keep only trivial, non-visual helpers inline: computed text, colors, formatting, or one-off layout functions that are not themselves `View` types.

---

## Preview Requirement

**Every SwiftUI view file must include a `#Preview`. No exceptions.**

A missing preview is treated as an incomplete implementation. Previews are the primary tool for fast visual iteration and catching layout regressions without a full build.

Rules:

- Screen-level views (`ContentView`, `ScorecardView`) preview with representative game state.
- Component views preview all meaningful states: empty, filled, current-player highlighted, winner, game-over, etc.
- Use `inMemory: true` SwiftData model containers in previews — never a live store.
- If a view requires environment objects or model context, inject them in the preview.
- Write the preview immediately when the view is created — do not leave a `// TODO: add preview` comment.

---

## Folder Structure

```text
SyFive/
  Dice/                — RealityKit dice physics, audio, and rolling logic
    Docs/              — Dice-specific design docs and test results
  Docs/                — Engineering guidelines and design documents
  Domain/              — Pure value types, enums, and scoring rules
    Enums/             — YatzyCategory, MatchStatus, etc.
    Scoring/           — YatzyScoring rules
    Values/            — Match, Participant, Player, ScoreEntry, etc.
  Extensions/          — Swift/Foundation extensions
  Persistence/         — SwiftData models and domain↔model conversion
    Conversion/        — GameModel+Conversion, MatchModel+Conversion, etc.
    Models/            — GameModel, MatchModel, ParticipantModel, PlayerModel
  Session/             — MatchController: game state machine and scoring logic
  Theme/               — Theme struct, ThemeType enum, color definitions
  Utilities/           — AppConfig, AppLogger, AppUpdateChecker
  Views/               — All SwiftUI views (one per file)
```

New feature areas get their own subfolder. Do not add files to the root `SyFive/` target directory.

---

## ContentView

`ContentView.swift` is the top-level navigation shell: `NavigationStack`, toolbar, layout split between `DiceAreaView` and `ScorecardView`, and the SwiftData persistence wiring (`saveMatch`, `loadMatchIfNeeded`).

Do not place feature-specific UI inside `ContentView.swift`. New top-level destinations get their own file under `Views/`.

---

## Naming

Use clear, product-oriented names that describe the user-facing role.

Examples:

- `ScorecardView` — the score tracking area
- `PlayerScoreCardView` — one player's card within the scorecard
- `DiceAreaView` — the tray + roll controls area
- `PlayerPickerSheet` — the sheet for managing players

Prefer names that describe what the user sees or does, not what the code does internally.

---

## Theming

All new views must read the theme from `@Environment(\.theme)` when a theme is available in the environment, or construct one from `model.themeType(for:)` + `colorScheme` when per-player theming is required.

```swift
@Environment(\.theme) private var theme
@Environment(\.colorScheme) private var colorScheme

// Per-player theme:
let theme = Theme(type: model.themeType(for: playerIndex), colorScheme: colorScheme)
```

Never use `Color.blue`, `Color.green`, or other hardcoded colors for interactive or branded UI elements. Use `theme.primaryAccent`, `theme.cellBackgroundColor`, etc. Use `Color.primary`, `Color.secondary`, and semantic system colors only for non-branded text and backgrounds.

Inject the theme in previews:

```swift
.environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
.preferredColorScheme(.dark)
```

---

## Enums Over Strings and Magic Numbers

**Whenever a value belongs to a fixed, known set, model it as an enum — not a `String`, `Int`, or other raw type.**

This applies everywhere: function parameters, stored properties, dictionary keys, persistence fields, UserDefaults keys, and inter-module APIs.

Bad:

```swift
// String parameter with implicit vocabulary
func markDieStuck(_ index: Int, reason: String) {
    if reason == "wall-blocked" { ... }   // silent typo risk, no exhaustiveness
}

// Int magic number for state
if phase == 2 { ... }

// String dictionary key with a fixed key set
var counts: [String: Int] = [:]
counts["floor-stuck"] = 1
```

Good:

```swift
enum StuckReason: String {
    case floorStuckTimeout = "floor-stuck-timeout"
    case stackedTimeout    = "stacked-timeout"
    case wallBlocked       = "wall-blocked"
}

func markDieStuck(_ index: Int, reason: StuckReason) {
    if reason == .wallBlocked { ... }   // exhaustive, compiler-checked
}
```

Rules:

- If an API accepts a `String` or `Int` but only a fixed set of values is valid, define an enum.
- Enum `rawValue` is acceptable *only* at system boundaries where a `String` or `Int` is forced (JSON, UserDefaults, logging, external APIs). The raw value must never be used for branching inside the app.
- `switch` on an enum must be exhaustive — no `default:` catch-alls that hide new cases.
- Dictionary keys that form a fixed vocabulary use the enum as the key type, not `String`.
- If a strings/numbers smell is found during a task, fix it in the same PR rather than deferring it.

---

## Localisation Safety

**Never use a displayed string as a conditional or state discriminator.**

A string shown to the user belongs to the presentation layer. Branching on it couples logic to copy in a way that silently breaks under translation or any wording change.

Bad:

```swift
if title == "Upper" { ... }
if section == "Roster" { ... }
```

Good — pass a semantic value alongside the display string:

```swift
scoreSection(title: "Upper", isUpper: true, ...)
// Inside: if isUpper { ... }
```

Or use an enum:

```swift
enum ScoreSection { case upper, lower }
```

The display string goes only into `Text(...)`. All branching uses typed values.

---

## Scope Control

Keep refactors mechanical unless the task explicitly asks for design or behavior changes.

When splitting files, moving folders, or renaming types:

- Preserve current behavior.
- Preserve all previews.
- Run per-file diagnostics (`XcodeRefreshCodeIssuesInFile`).
- Run a full build (`BuildProject`) before marking the task done.

---

## File Access

When reading or searching project files, use the dedicated Xcode tools — never bash `grep`, `find`, or `cat`.

| Task | Tool |
|---|---|
| Known file path | `Read` or `XcodeRead` |
| Search for a pattern | `XcodeGrep` |
| List files in a folder | `XcodeLS` or `XcodeGlob` |
| Move or rename a file | `XcodeMV` |
| Delete a file | `XcodeRM` |

Bash `grep` and `find` trigger a permission prompt on every call. The Xcode tools are faster and don't have that overhead.

---

## Validation

Before marking any task complete:

1. **Run `BuildProject`** — mandatory after any code change. A passing build catches errors that per-file diagnostics miss: missing imports, type mismatches across files, broken argument labels, linker failures. Do not say "this should work" without a passing build.

2. **Build incrementally** when touching multiple files — especially after deletions or cross-file renames. Do not accumulate edits across many files and build only at the end. If you removed a public API, build immediately to surface every broken call site.

3. Use `XcodeRefreshCodeIssuesInFile` as a fast sanity check during implementation — not as a substitute for a full build.

4. Confirm each new view has its own file and a `#Preview`.

---

## Testing

Tests are opt-in. Add or run tests only when explicitly requested.

Default validation: targeted diagnostics + a full Xcode build. Do not spend conversation time on tests unless the request explicitly makes testing the focus.

---

## Logging

**Never use `print()`. Always use `AppLogger`.**

`AppLogger` wraps Swift's unified logging system (`os.Logger`). Messages at `.debug` level are suppressed in production — no `#if DEBUG` guards needed. Messages at `.info` and above are visible in Console.app in production.

Usage:

```swift
// Instance property (views, classes, structs):
private let logger = AppLogger(category: "MyType")

// Instance methods:
logger.debug(self, "detail only useful during development")
logger.info(self, "notable event — visible in production logs")
logger.warning(self, "unexpected condition: \(error)")
logger.error(self, "unrecoverable failure: \(error)")

// Static methods — pass the type's metatype as the object:
private static let logger = AppLogger(category: "MyType")
logger.debug(MyType.self, "static context message")
```

Rules:

- Every type that logs must declare its own `AppLogger` with a descriptive `category` matching the type name.
- `#if DEBUG` guards around logging are banned — they are redundant with `logger.debug` and create inconsistency.
- `print()` is banned everywhere in app source. Use `logger.debug` for developer-only output.
- Log errors and warnings at the appropriate level so they surface in production diagnostics without being noisy.

---

## AppConfig Guards

Debug-only features (dice diagnostic logging, layout overlays, debug HUD) must be gated behind `AppConfig` flags. Before shipping, confirm:

- `AppConfig.DebugDice.showHarness = false`
- `AppConfig.DebugDice.logRollDiagnostics = false`
- `AppConfig.DebugLayout.isEnabled = false`
