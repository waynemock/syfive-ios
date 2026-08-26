
# SyLibDice — Standalone Dice Wave

**Audience:** the Xcode coding agent.
**Workspace:** `sylib-swift` and `SyFive`. Both change.
**Goal:** make `SyLibDice` a complete, self-contained dice product — engine,
certification, and UI — so that adding physical dice to any app is a few lines
and one package product.

Nothing about dice behaviour changes in this wave. This is re-homing, one
extraction, and one type reshape.

---

## 1. Rules of engagement

**Do:**
- Move files; change imports; add `public` where the move requires it.
- Replace `@Environment(\.theme)` reads with explicit init parameters.
- Commit at each checkpoint on `wave/standalone-dice` in both repos.

**Do not:**
- Do not change physics, tuning defaults, or any value in `Config`.
- Do not change the certification numbers.
- Do not touch `SydeTwo`, `SyLibScoring`, `SyLibFeel`, or SyFive's scoring code.
- Do not add third-party dependencies. Charts and UniformTypeIdentifiers are
  Apple frameworks and are allowed in `SyLibDice`.
- Do not redesign any view's appearance. Pixel-identical output is the goal.

**Report, don't decide:** anything that seems to need a new public API beyond
what §4 specifies, or any view that turns out to depend on SyFive state not
listed here.

---

## 2. Target layout when done

```
Sources/SyLibDice/
  Simulation/   DiceRoller, DiceRandSource, DiceRollRecipe
  RealityKit/   DiceEntity, DiceTrayEntity, DiceRKView
  Analytics/    DiceStatistics, DiceReportGenerator, FairnessCertification
  Audio/        DiceAudioController
  Theming/      DiceTintPalette
  Views/        DiceTrayView, DicePill, DiceReportSheet,
                DiceFairnessView, DiceFairnessDeepDiveView,
                DiceDebugHUD, PhysicsTuningPanel
  Docs/         (excluded from the target — see T1)
```

---

## 3. T1 — Manifest fix

`Sources/SyLibDice/Docs/` holds six non-source files, including a 1.4 MB CSV.
With no declaration, SPM emits an unhandled-files warning on every build.

```swift
.target(
    name: "SyLibDice",
    dependencies: ["SyLibCore"],
    exclude: ["Docs"]
),
```

The docs stay in the package — they are the evidence behind the certification —
but they must not be compiled or bundled.

While there: the four markdown files reference `SyFive/Docs/` and
`SyFive/SyFive/Utilities/analyze_dice_fairness.py`. Update those paths to their
new locations, or note in each header that the paths are historical.

**✅ C1:** `swift build` produces no unhandled-file warnings.

---

## 4. T2 — `CertifiedFairnessTest` → `FairnessCertification`

Currently an `enum` of `static let`s. It becomes a value type so a consumer can
supply their own run, with SyFive's existing numbers as the package default.

### 4.1 The type

```swift
/// A completed dice fairness certification: the measured counts plus the
/// statistics derived from them.
public struct FairnessCertification: Sendable {
    public let testDate: String
    public let totalRolls: Int
    public let faceCounts: [Int: Int]
    public let serialCorrelation: Double
    public let runsTestZ: Double

    public init(
        testDate: String,
        totalRolls: Int,
        faceCounts: [Int: Int],
        serialCorrelation: Double,
        runsTestZ: Double
    )

    // Derived — move across unchanged, `static var` → `var`:
    public var totalSamples: Int
    public var frequencies: [Int: Double]
    public var minFrequencyPct: Double
    public var maxFrequencyPct: Double
    public var chiSquare: Double
    public var chiSquarePValue: Double
    public var passes: Bool
}
```

The existing values become the package default, verbatim — do not recompute or
adjust them:

```swift
public extension FairnessCertification {
    /// The certified run shipped with SyLibDice, measured with `DiceRoller.Config.certified`.
    static let builtIn = FairnessCertification(
        testDate: "July 2026",
        totalRolls: 2_161,
        faceCounts: [1: 1_797, 2: 1_778, 3: 1_834, 4: 1_811, 5: 1_841, 6: 1_744],
        serialCorrelation: +0.000442,
        runsTestZ: -0.086436
    )
}
```

Carry the existing "how to update after a fresh batch run" doc comment onto
`builtIn`, and correct step 4 to point at the package's `Docs/` folder.

### 4.2 Certified tuning

A certification is only meaningful for the tuning it was measured against, and
`Config` is fully mutable by consumers. Make that checkable:

```swift
public extension DiceRoller.Config {
    /// The tuning `FairnessCertification.builtIn` was measured with.
    static let certified = Config()

    /// True when the physics parameters match `.certified`.
    /// Compares physics only — `logDiagnostics` and `appVersion` are runtime fields.
    var isCertifiedTuning: Bool { … }
}
```

Do **not** make `Config` `Equatable` — `appVersion` and `logDiagnostics` would
wrongly break equality. Compare the ~20 physics fields explicitly.

### 4.3 Call sites

28 sites across `DiceFairnessView` and `DiceFairnessDeepDiveView`, all of the
form `CertifiedFairnessTest.<member>`. Those views move to the package in T3 and
take the certification as a parameter (§5.3), so the references become
`certification.<member>`.

**✅ C2:** package builds; the three existing assertions in
`DiceStatisticsTests` pass against `.builtIn`.

---

## 5. T3 — Move the views

### 5.1 Move as-is (no blockers)

| From `SyFive/Views/` | Lines | Notes |
|---|---:|---|
| `DiceDebugHUD.swift` | 359 | Already imports only SwiftUI, Charts, UniformTypeIdentifiers, SyLibDice |
| `DicePill.swift` | 37 | `(value, isHeld, isEnabled, onTap)` — already generic |
| `DiceReportSheet.swift` | 33 | Takes a `String` report |

### 5.2 Move with one parameter added

`DiceFairnessView.swift` (142) and `DiceFairnessDeepDiveView.swift` (198) each
read `@Environment(\.theme)` for exactly one thing — `theme.primaryAccent`, at
`DiceFairnessView:79, 91, 121` and `DiceFairnessDeepDiveView:46, 96, 138, 162`.

Replace the environment read with:

```swift
public init(
    certification: FairnessCertification = .builtIn,
    accentColor: Color
)
```

SyFive's call sites pass `accentColor: theme.primaryAccent`.

### 5.3 Extract `PhysicsTuningPanel`

`DiceAreaView.swift:421–487` (`physicsDebugPanel` + `debugSlider`) is entirely
`diceRoller.config.*` bindings. Move it as a standalone view:

```swift
public struct PhysicsTuningPanel: View {
    public init(roller: DiceRoller)
}
```

The `#if DEBUG` guard and the `AppConfig.DebugDice.showPhysicsSliders` check stay
in SyFive — the app decides whether to show it.

---

## 6. T4 — Extract `DiceTrayView`

The one genuine extraction. `DiceAreaView` is 487 lines; roughly 140 of them are
generic tray hosting.

### 6.1 What moves

- `trayFillFactor` (101–106) — the iPad-landscape heuristic. Fully generic.
- `trayView` (108–125) — geometry tracking, `DiceRKView` hosting,
  `SpatialTapGesture`, corner clipping. Generic apart from the overlay.
- `handleDiceTap` (253–271) — **the top half only.** Everything above
  `guard model.canScore` is stuck-die handling against the engine
  (`hasStuckDice`, `isStuckDie`, `isNudgeableDie`, `nudgeStuckDie`,
  `rerollStuckDie`). That is package behaviour.

### 6.2 What stays in SyFive

Everything below `guard model.canScore else { return }` at line 274 — hold
semantics belong to the game: `model.toggleHold(at:)`,
`gameNight.sendHoldToggled(…)`, `director.holdToggled(engaged:)`. Also
`rollControls`, `proxyModeControls`, `wireGameNightHooks`, all turn logic, the
Yatzy predicate, and `DiceTrayOverlayView` (which lives in
`CelebrationView.swift:53` and needs `MatchController`).

### 6.3 The API

```swift
public struct DiceTrayView<Overlay: View>: View {
    public init(
        roller: DiceRoller,
        palette: DiceTintPalette,
        backgroundColor: Color,
        cornerRadius: CGFloat = 16,
        isInteractive: Bool = true,
        canToggleHold: Bool = true,
        onHoldToggled: ((Int) -> Void)? = nil,
        onNudge: (() -> Void)? = nil,
        onReroll: (() -> Void)? = nil,
        @ViewBuilder overlay: () -> Overlay = { EmptyView() }
    )
}
```

Behaviour:
- Tap on a stuck die → nudge or reroll internally, then fire `onNudge`/`onReroll`
  so the host can play its own feel cue. This preserves SyFive's current
  `director.dieNudged()` / `director.dieRerolled()` calls.
- Tap on a normal die → fire `onHoldToggled(index)` **only**. The tray does not
  mutate hold state; the app owns the truth and calls `roller.setHeld(_:)`
  itself, exactly as `DiceAreaView` does today.
- `isInteractive` gates all taps (SyFive passes `isLocalTurn`);
  `canToggleHold` gates only the hold branch (SyFive passes `model.canScore`).

**Callback ordering matters.** In today's code `director.dieNudged()` fires
*before* `diceRoller.nudgeStuckDie(at:)`, and `director.dieRerolled()` fires
before the `await rerollStuckDie`. Preserve that ordering — the audio cue leads
the physics deliberately.

### 6.4 SyFive's new call

```swift
DiceTrayView(
    roller: diceRoller,
    palette: theme.dicePalette,
    backgroundColor: theme.backgroundColor,
    isInteractive: isLocalTurn,
    canToggleHold: model.canScore,
    onHoldToggled: { index in
        model.toggleHold(at: index)
        diceRoller.setHeld(model.held)
        let engaged = model.held.indices.contains(index) ? model.held[index] : false
        if gameNight.isSessionActive && gameNight.phase == .inProgress {
            gameNight.sendHoldToggled(dieIndex: index, isHeld: engaged)
        }
        director.holdToggled(engaged: engaged)
    },
    onNudge:  { director.dieNudged() },
    onReroll: { director.dieRerolled() }
) {
    DiceTrayOverlayView(model: model)
}
```

**✅ C4:** SyFive builds; dice render identically; tap-to-hold, nudge on a yellow
stuck die, and reroll on a red stuck die all behave as before, with the same
sounds and haptics.

---

## 7. T5 — Tests

Keep the three existing assertions in `DiceStatisticsTests` (they now read
`FairnessCertification.builtIn`) and add synthetic fixtures alongside, because
asserting that real measured data passes mostly tests that the batch run was
good — it doesn't test the maths.

Add to `Tests/SyLibTests/SyLibDice/Analytics/`:

- Perfectly uniform counts (six faces × equal N) → `chiSquare` ≈ 0,
  `chiSquarePValue` ≈ 1, `passes == true`.
- A deliberately skewed set (e.g. one face at 3× the others) → `passes == false`.
- `frequencies` sums to 1.0 within tolerance; `minFrequencyPct` ≤
  `maxFrequencyPct`.
- `Config().isCertifiedTuning == true`; a Config with a mutated `impulseMax`
  returns `false`; mutating only `logDiagnostics` or `appVersion` still returns
  `true`.

---

## 8. Definition of done

- [ ] `exclude: ["Docs"]` added; no unhandled-file warnings on any platform.
- [ ] `FairnessCertification` is a struct; `.builtIn` carries the July 2026 data
      unchanged; `Config.certified` and `isCertifiedTuning` exist.
- [ ] Seven views live in `Sources/SyLibDice/Views/`; none reads
      `@Environment(\.theme)`.
- [ ] `DiceAreaView` is down to roughly 350 lines and contains no
      `DiceRKView`, `SpatialTapGesture`, or `config.*` slider code.
- [ ] SyFive builds and the dice area is visually and behaviourally identical.
- [ ] Package tests green, including the new fixtures.
- [ ] `Docs/Dice.md` written for SyLib, documenting the module and showing the
      minimal "add dice to an app" snippet.
- [ ] README component table gains rows for `SyLibDice`.
- [ ] Report: every symbol whose access level was widened.

---

## 9. Net effect

| | Lines |
|---|---:|
| Moves to `SyLibDice` | ~909 |
| SyFive delta | −909 |
| `DiceAreaView` | 487 → ~350 |

Afterwards, adding physical dice to a new app is: link `SyLibDice`, hold a
`DiceRoller`, and place a `DiceTrayView`. Fairness UI, debug HUD, report sheet,
and certification come with it.
