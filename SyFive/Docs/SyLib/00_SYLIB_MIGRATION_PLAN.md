# SyFive → SyLib Migration Plan

Complete plan, revised against the shipped four-target SyLib. Supersedes all
earlier versions — nothing else needs to be read alongside it.

This is the **roadmap**, not a hand-off brief. Each wave gets its own
implementation brief when its turn comes, the way the SyLib restructure did.
Handing an agent four waves at once is how you get a 5,000-line commit nobody can
review.

---

## 1. Starting position

SyLib is `SyLibCore` / `SyLibCache` / `SyLibDSP` / `SyLibUI`, with SydeTwo
consuming it and the wrapper pattern documented as a house rule.

SyFive has **zero** SyLib imports today. That makes this greenfield: no adapter
period, no dependency to preserve, no existing call sites to keep compiling.
Every wave is purely additive from SyFive's side.

SyFive is in App Store review. Branch off the review tag, not `main` — if review
kicks back you want a hotfix path that isn't sitting on a refactor.

**Workspace note.** Xcode lets only one open window claim a local package as an
editable workspace member. With SyFive's workspace open, verify SydeTwo from the
command line rather than closing and reopening:

```bash
xcodebuild build -scheme SydeTwo -destination 'platform=iOS Simulator,name=iPhone 16'
```

`xcodebuild` doesn't take the editable claim. Every wave changes SyLib, so
"SydeTwo still builds" is a gate on all of them.

---

## 2. Manifest delta

Three targets get added to SyLib across the migration. Design the graph once:

```swift
.library(name: "SyLibScoring", targets: ["SyLibScoring"]),
.library(name: "SyLibFeel",    targets: ["SyLibFeel"]),
.library(name: "SyLibDice",    targets: ["SyLibDice"]),

.target(name: "SyLibScoring"),                                // Foundation only
.target(name: "SyLibFeel", dependencies: ["SyLibCore"]),      // AVFoundation, CoreHaptics
.target(name: "SyLibDice", dependencies: ["SyLibCore"]),      // RealityKit, simd, Observation
```

Verified edges:

- Feel uses `AppLogger` in 6 places → depends on `SyLibCore`.
- Dice uses `AppLogger` in 20 places → depends on `SyLibCore`.
- Domain uses `AppLogger` **zero** times → `SyLibScoring` depends on nothing, as
  intended. Keep it that way.
- **No `SyLibFeel` → `SyLibDSP` edge.** `AudioDSP` is analysis (FFT, spectrum
  bands, waveform); `SoundRenderer` is synthesis (tone/noise generation, biquad
  filtering). Different jobs, no shared code. Don't merge them.
- No `SyLibFeel` ↔ `SyLibDice` edge, ever (D-053).

SyFive never needs `SyLibCache` (no image caching) or `SyLibDSP`.

Platform floor is unchanged: package-level iOS 17. SyFive targets 18.6, so
nothing it brings can raise the floor — but if a migrated component turns out to
need iOS 18, gate it with `@available`, don't move the package.

---

## 3. Wrapper pattern

SyFive should follow SydeTwo's house rule rather than inventing its own. Copy the
wrapper-pattern section from SydeTwo's engineering guidelines into SyFive's
**before Wave 1**, so the convention lands before the first wrapper does. Both
shapes will come up:

- **View wrapper** — same name as the SyLib type, qualified inner call
  (`SyLibUI.AboutView(...)`). Wave 1's `AboutView` is exactly this.
- **Manager wrapper** — distinct name, `private let` instance, facade over it.
  `DiceFeelAdapter` is already this shape, and whatever holds `DiceRoller`
  alongside SyFive's palette and `FeelDirector` after Wave 3 will be another.

---

## Wave 1 — Adopt `SyLibCore` + `SyLibUI`

Pure subtraction, no new SyLib code, and a bigger deletion than earlier estimates
because SyLib's `AboutView` absorbs four SyFive files at once.

### 1.1 `AppLogger` → `SyLibCore`

The two implementations are **API-identical**: same `init(subsystem:category:)`,
same five methods with the same `(_ object: Any, _ message: String,
functionName: String = #function)` shape. All 121 call sites
(`logger.debug(self, "…")` etc.) compile unchanged.

- Delete `Utilities/AppLogger.swift` (79 lines).
- One real difference: SyLib's `sinks` is
  `[String: @Sendable (String, String, String) -> Void]`. SyFive's is not
  `@Sendable`. `App/GameNight/GameNightLogBuffer.swift:41` registers a
  `[weak self]` closure — it needs `@Sendable` to conform.
- SyLib adds `appName` and `mutedCategories`. Set `AppLogger.appName = "SyFive"`
  at launch; `mutedCategories` is optional and probably useful for the Game Night
  chatter.

### 1.2 `AppUpdateChecker` → `SyLibCore`

- Delete `Utilities/AppUpdateChecker.swift` (105 lines).
- One call site: `Views/ContentView.swift:208` calls
  `AppUpdateChecker.shared.isUpdateAvailable()`. Identical in SyLib. No change.
- SyLib adds `updateStatus()`, `isNewer(storeVersion:than:)`,
  `shouldShowUpdateBadge`, `acknowledgeVersion` — available if wanted, not
  required.

### 1.3 `Bundle` extensions → `SyLibCore` / `SyLibUI`

- Delete `Extensions/Bundle+Extension.swift` (33 lines).
- `Bundle.main.appVersion` and `Bundle.main.appVersionShort` live in
  `SyLibCore`; `Bundle.main.icon` lives in `SyLibUI`
  (`Branding/Bundle+Icon.swift`). Both call sites compile unchanged.
- Optional tidy: `Views/DiceAreaView.swift:50` reads
  `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` by hand. Replace
  with `Bundle.main.appVersionShort`.

### 1.4 The About stack → `SyLibUI.AboutView` wrapper

SyLib's `AboutView` already renders the app icon, name, version, tagline,
description, share button, Done button, and the Syzygy footer — so it replaces
four SyFive files, not one.

**Delete:**

| File | Lines | Why it goes |
|---|---:|---|
| `Views/AboutView.swift` | 87 | Becomes a ~20-line wrapper |
| `Views/AppIconView.swift` | 35 | `SyLibUI.AboutView` renders the icon itself |
| `Views/SyzygyInfo.swift` | 35 | `SyLibUI.AboutView` renders the footer itself |
| `Views/SafariView.swift` | 12 | `SyLibUI.SyzygyInfo` owns Safari presentation |

Note the behavioural difference: SyFive's `SyzygyInfo` takes an `action` closure
and makes the *host* present Safari (hence `@State isSafariPresented` and the
`.sheet` in `AboutView`). SyLib's `SyzygyInfo` has `showLink: Bool` and presents
its own sheet. So the state variable and the sheet modifier disappear too.

**Add** — the view-wrapper case of the house rule, verbatim:

```swift
// Views/AboutView.swift
import SwiftUI
import SyLibUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(type: .midnight, colorScheme: colorScheme) }

    var body: some View {
        SyLibUI.AboutView(          // ← qualify to disambiguate from this wrapper
            appName: "SyFive",
            tagline: "The classic dice game, elevated.",
            description: ...,
            appStoreURL: Self.appStoreURL,
            accentColor: theme.primaryAccent,
            backgroundColor: theme.backgroundColor
        )
    }
}
```

Call sites (`ContentView.swift:469` and two previews) stay `AboutView()`.

> ⚠️ **Live bug, unrelated to this migration.** `Views/AboutView.swift:10` is
> `URL(string: "https://apps.apple.com/app/id000000000")!` with a
> `// TODO: replace with real App Store ID before submission` above it. The app
> is in review; the Share button currently shares a dead link. Fix this
> regardless of whether Wave 1 happens.

### 1.5 `UserDefaults`

Adopt `SyLibCore`'s `acknowledgedUpdateVersion`. **Keep** SyFive's `Key` enum and
every Game Night / commentary key app-side.

### Wave 1 net

≈ **390 lines deleted**, ≈ 25 added. SyFive links `SyLibCore` and `SyLibUI`.

**Gate:** app builds and launches; About sheet renders with icon, version, share,
Done, and the Syzygy footer with a working link; update badge still fires; Game
Night log buffer still captures sink output.

---

## Wave 2 — `SyLibFeel` (≈991 lines)

The rehearsal for Dice. Already extraction-ready per D-053: catalog injection
exists and there's no Feel↔Dice edge in either direction.

**Moves:** `FeelDirector`, `FeelRecipes` (SoundRecipe / RattleRecipe /
HapticRecipe / FeelCatalog), `FeelAudioEngine`, `FeelHapticEngine`,
`SoundRenderer`, `SoundCache`.

**Stays app-side:** `SyFiveCatalog.swift` (193 — recipe *values*, SyFive's voice
per 07 §2.1), `DiceFeelAdapter.swift` (22), `FeelBoardView.swift`.

**Work:**

- Drop `FeelDirector.init()`'s hardcoded `catalog = .syFive`; `init(catalog:)`
  becomes the only initializer. `FeelCatalog.syFive` becomes an app-side
  extension.
- Move `AppSoundMode` out of `AppSettingsModel` into the Feel module as a plain
  enum; the SwiftData model stores its `rawValue`.
- Guard `FeelHapticEngine` with `#if canImport(CoreHaptics)`; audio-only fallback
  elsewhere.
- Move `FeelTests.swift` into `Tests/SyLibTests/`, with a small fixture catalog in
  the test target so package tests don't depend on app content.

**Gate:** the byte-identical PCM render determinism test passes inside SyLib.
That test is the entire safety net for this wave — do not let it get dropped in
the move.

---

## Wave 3 — `SyLibDice` (≈2,875 lines)

The crown jewel, and nearly lift-and-shift: of `07 §10`'s nine extraction leaks,
**items 1–6 and 8 are already closed**. `DiceTintPalette` is injected,
`keepScreenAwake` is a closure, `AppConfig.logRollDiagnostics` became
`DiceRoller.Config.logDiagnostics`, `appVersion` is injected via Config. The only
app-layer type left anywhere in `Dice/` is `AppLogger`, which Wave 1 resolves.

**Open leak — item 7:** `DiceTrayEntity` hardcodes two `UIColor` values for floor
and walls. Decide before the move: add `trayFloor` / `trayWall` to
`DiceTintPalette`, or leave them constants. **I'd add them** — a light-themed
consumer will want them, and adding fields to a public struct later is
source-breaking.

**Moves:** `DiceRoller` (1429), `DiceEntity` (492), `DiceStatistics` (346),
`DiceReportGenerator` (303), `DiceTrayEntity` (209), `DiceAudioController` (32,
the `DiceAudioControlling` port), `DiceRandSource` (27), `DiceRollRecipe` (24),
`DiceTintPalette` (13).

**Stays app-side:** `CertifiedFairnessTest` (61 — SyFive's certification data;
move the type, keep the values, same machinery/content split as Feel), every dice
view (`DiceAreaView`, `DicePill`, `DiceDebugHUD`, `DiceFairnessView`,
`DiceFairnessDeepDiveView`, `DiceReportSheet`), and `Dice/Docs/`.

**Judgment call:** `Views/DiceRKView.swift` (180) is the RealityKit host —
generic, and a consumer handed a dice engine but no renderer host hasn't really
been handed a dice engine. I'd move it. `DiceAreaView` (469) is app layout and
stays.

**Scope `SyLibDice` to iOS.** RealityKit rules out tvOS and watchOS anyway, and
the four `import UIKit` files would need AppKit shims for macOS nobody is asking
for.

**Expect Swift 6 work.** SyFive is on language mode 5, SyLib on 6.
`@MainActor @Observable final class DiceRoller` with an escaping
`roll(held:onResults:)` callback is the likeliest friction point.

**Gate:** run a 10,000-roll batch in the debug HUD against the packaged engine and
match `CertifiedFairnessTest`. Non-negotiable — a physics regression is invisible
until a player notices their dice are biased.

---

## Wave 4 — `SyLibScoring` (≈715 lines)

Foundation-only, zero dependencies, compiler-enforced. Mechanically easy; the
decisions inside it are not.

**Moves:** `Player`, `Match`, `Participant`, `ScoreEntry`, `Team`, `Game`,
`PlayerInitials`, `MatchStatus`, `PlayerSource`, `ScoreValue`,
`ValidationResult`, `WinnerDirection`, all of `Stats/Generic/`, `StatsSeries`.

**Stays app-side (Tier 2, D-028):** `YatzyCategory`, `YatzyScoring`,
`ScoringSystemID`, all of `Stats/Yatzy/` (~897), and all of `Views/Stats/` —
`import Charts` must never reach the package (03 §4).

**Persistence stays app-side.** `02`'s own layer table says so and I agree: the
`@Model` twins are 111 lines of mirror code, conversion is 137 more, and the
CloudKit container is per-app by design (04 §0.3). The reusable asset is the
*pattern* — value type ↔ `@Model` twin ↔ conversion extension — not the code.
Document it in `Docs/Scoring.md`; let ScoreIt v2 declare its own models. A
`SyLibData` target earns its keep after ScoreIt v2 exists, not before.

### 4.1 Blocker — `Participant.yatzyBonus` → `bonusPoints`

`Participant` is the generic currency of `SyLibScoring`, and it currently carries
a Yatzy-specific `Int`:

```swift
var yatzyBonus: Int          // cumulative +100 per extra Yatzy beyond first
```

Both the name and the doc comment encode a Yatzy rule. This has to be settled
before the type crosses into the package — a field called `yatzyBonus` in a
module ScoreIt v2 depends on is exactly the leak the target split exists to
prevent.

**Ship this as its own release, before the package move.** Steps 1–5 under
"Order of operations" are a standalone change. Doing it separately keeps the
CloudKit verification isolated from target-split noise.

#### What is and isn't in scope

A naive `yatzyBonus` grep returns ~80 hits. **Only about 25 are the rename.** The
rest are Tier 2 Yatzy code that stays app-side and must **keep** its Yatzy
naming:

| Keep as-is | Why |
|---|---|
| `YatzyScoring.grandTotal(scorecard:yatzyBonus:)` | Tier 2 scoring, stays in SyFive |
| `qualifiesForExtraYatzyBonus(dice:scorecard:)` | Tier 2 rule |
| `MatchController.playerYatzyBonuses`, `yatzyBonus(for:)` | App-layer game loop |
| `MatchPresenting.yatzyBonus(for:)` | App-layer protocol |
| `TableReplica.yatzyBonusesStore` | App-layer Game Night replica |
| `CommentaryEvent.yatzyBonusEarned` + the four packs | App content |
| `YatzyStats` fields and comments | Tier 2 stats |

Tell the agent explicitly: rename the **property on `Participant` and
`ParticipantModel` and its call sites**, nothing else. A blanket find/replace
would strip the Yatzy vocabulary out of the layer where it belongs.

#### The 25 call sites

```
Domain/Values/Participant.swift              13 (decl + doc), 41, 64
Persistence/Models/ParticipantModel.swift     9
Persistence/Conversion/ParticipantModel+Conversion.swift   10, 25
Persistence/Migration/LegacyYahtzeeRepair.swift            39, 48  (+ comments 9, 11–12, 38)
Session/MatchController.swift               382, 585, 737
App/GameNight/GameNightController.swift    1226
App/HouseRecords/HouseRecords.swift         340, 341  (+ comment 333)
Domain/Stats/Yatzy/MatchProgression.swift    56
Domain/Stats/Yatzy/YatzyStats.swift          33  (+ comments 4, 8–10)
Views/Stats/MatchDetailView.swift           220, 237
Views/Stats/MatchHistoryRow.swift            65
Views/Stats/UnfinishedMatchDetailView.swift 217, 230
Views/Stats/UnfinishedMatchRow.swift         69
SyFiveTests/StatsFixtures.swift             177, 186
SyFiveTests/StatsTests.swift                457
```

The last seven files are previews and fixtures — mechanical.

#### Compatibility surface 1: CloudKit — keep the old name in the store

`ParticipantModel` is backed by
`cloudKitDatabase: .private("iCloud.com.syzygysoftwerksllc.SyFive")`. CloudKit
schema fields cannot be renamed or removed once deployed to production — a
renamed property becomes a *new* field, and every existing record reads back the
default (`0`).

Use SwiftData's rename identifier so the Swift name changes and the store name
doesn't:

```swift
@Attribute(originalName: "yatzyBonus") var bonusPoints: Int = 0
```

**This makes the persistence side a zero-migration change.** No schema version,
no backfill, no CloudKit deployment, no risk to shipped records. The string
`"yatzyBonus"` survives as a one-line compatibility artifact — and it lives in
`ParticipantModel`, which stays in SyFive, so the Yatzy word never enters the
package. The layering does the work.

#### Compatibility surface 2: SharePlay — clean break, bump the protocol

`Participant` is `Codable` and it *is* on the wire:
`MatchStartPayload.match: Match` → `Match.participants: [Participant]`. Renaming
the property renames the JSON key.

Do **not** solve this with `CodingKeys` on `Participant` — that would put the
literal string `"yatzyBonus"` inside `SyLibScoring`, defeating the point.

Bump the protocol version instead:

```swift
// App/GameNight/Protocol/GameNightEnvelope.swift:9
static let currentProtocolVersion = 2
```

The handshake already enforces strict equality —
`payload.protocolVersion == GameNightEnvelope.currentProtocolVersion`, with
mismatched senders logged and ignored — so a bump cleanly refuses cross-version
peers.

> ⚠️ **Bumping is mandatory, not optional.** `bonusPoints` is a non-optional
> `Int` with no default, so a v1 peer's `MatchStartPayload` fails to decode with
> `keyNotFound` on a v2 device. Without the bump, both sides claim
> `protocolVersion: 1`, the hello handshake succeeds, and then match-start
> messages are silently dropped — the guest sits on a table that never starts.
> That failure mode is invisible in testing unless you deliberately run two app
> versions against each other.

#### Type: keep `Int` for now

`finalScore` is `Decimal` and `ScoreValue.number` wraps `Decimal`, so there's a
real consistency argument for widening `bonusPoints` at the same time.

**Don't — unless 1.0 has not yet reached users.** The cost is asymmetric:

- `Int` → `Int` rename with `originalName` is **free**. Lightweight migration
  handles it; nothing in the store changes.
- `Int` → `Decimal` is a **type change**, which lightweight migration does not
  support. It needs a versioned schema plus a backfill pass — exactly the work
  `originalName` was letting you skip.

If 1.0 is live: rename now, and treat the widening as a separate decision ScoreIt
v2 can force later, at the same cost whenever it happens. If 1.0 has *not*
shipped: no data to migrate, so do both at once — and check
`YatzyStats.swift:33`, where `p.yatzyBonus / 100` derives a Yatzy count and would
need explicit rounding under `Decimal`.

#### Semantics and documentation

The field means **points already earned as bonus**, not a count of bonuses. The
×100 rate and the ÷100 count derivation are Yatzy rules and stay app-side
(`MatchController.swift:497` writes `+= 100`; `YatzyStats.swift:33` reads
`/ 100`). The package documents only the general contract:

```swift
/// Bonus points earned outside the normal score entries, already summed.
/// The scoring system owns the rate and the meaning; this is the running total.
var bonusPoints: Int
```

Two app-side sites also *derive* this value from `finalScore` arithmetic and are
worth a second look while renaming:

- `LegacyYahtzeeRepair.swift:39–48` — infers the value from the
  `finalScore − cardSum − upperBonus` gap for pre-repair records, gated on
  `gap % 100 == 0`. Still correct after the rename; `originalName` keeps it
  pointed at the same column.
- `HouseRecords.swift:340–341` — the same inference as a runtime fallback for
  records the repair hasn't touched.

Both stay in SyFive. Neither needs logic changes — only the property name.

#### Order of operations

1. Rename on `Participant` + the 25 call sites; update the doc comment.
2. Add `@Attribute(originalName: "yatzyBonus")` to `ParticipantModel`.
3. Bump `currentProtocolVersion` to `2`.
4. Run the full suite — `StatsTests`, `YatzyScoringTests`, `StatsFixtures`.
5. **Verify against real data**: launch on a device with existing CloudKit
   records and confirm historical matches still show their Yatzy bonuses. This is
   the one step that proves `originalName` did its job; a passing test suite will
   not.
6. Only then move `Participant` into `SyLibScoring`.

---

## 5. Deferred

**Game Night.** `GameNightController` braids 1,247 lines of GroupActivities
lifecycle (generic), seat claim/release (generic to turn-based games), and Yatzy
payload semantics (not). You cannot locate that seam with one consumer — you'd be
guessing at ScoreIt v2's needs and living with the guess. Worst value-to-risk
ratio in the migration, on the code that just shipped and is least battle-worn.

Cheap down-payment if wanted: `Protocol/GameNightEnvelope.swift` (60 lines —
versioned wrapper, typed encode/decode, unknown-kind tolerance) is real generic
transport and moves to `SyLibCore` at near-zero risk. `GameNightPayloads.swift`
stays.

**Commentary.** Same engine/content shape as Feel: `CommentaryEngine` (141) +
`CommentaryLevel` + `CommentaryPersonality` + voice picking is generic; the four
packs (1,008 lines) are app content; `Settings/` drags in UIKit. Clean
extraction, lower value than Feel or Dice. Do it on momentum or skip it.

---

## 6. Does not move

`App/HouseRecords/` (app-layer by D-110 and in-source), `MatchController` (821 —
SyFive's game loop, imports SwiftData and SwiftUI), all of `Persistence/`
including `Migration/`, `Theme/` (app-local by decision — SydeTwo has `hifi`,
SyFive has `ember`; the palettes genuinely diverge), `Utilities/AppConfig.swift`,
`Views/` minus the Wave 1 branding files and possibly `DiceRKView`, and all of
`Docs/Requirements/`.

---

## 7. Open decisions

**Has 1.0 reached users, or is it still in review?** Decides whether the
`bonusPoints` type widening happens now (free, no data to migrate) or is deferred
(§4.1). Doesn't block Waves 1–3.

**Tray colours (Wave 3, item 7).** Palette fields or constants. Recommend
palette.

---

## 8. Net effect

| Wave | Target | Moves | SyFive delta | Risk |
|---|---|---:|---:|---|
| 1 | Core + UI | 0 | −390 | trivial |
| 2 | SyLibFeel | ~991 | −991 | medium |
| 3 | SyLibDice | ~2,875 | −2,875 | medium-high |
| 4 | SyLibScoring | ~715 | −715 | medium |

SyFive drops from ~21,700 Swift lines to roughly 16,700. SyLib gains three
opt-in targets that ScoreIt v2 inherits for free.
