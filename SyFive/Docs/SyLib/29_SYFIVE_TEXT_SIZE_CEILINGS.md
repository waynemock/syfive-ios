# SyFive's text-size ceilings: the game screen at xxxLarge, everything else at AX2

**Status:** **Done (29.1); V1 to V4 open.** Version 1.0, 7 November 2026. In SyFive 1.2.0,
before the first TestFlight build (Pops, 7 November 2026). Uses SyLibUI's existing helpers; no
SyLib change.

**Scope:** `syfive-ios` on `sylib-reintegration`. SyLib is read, not changed.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document, SyLib `Docs/EXTENSIONS.md` ("`dynamicTypeCeiling(_:)` and `sceneDynamicTypeCeiling(_:)`").

---

## Supersessions

None in the ledger. 00B gains exception **E-2** (§2.3): SyFive's game screen is held below 00A §5's
AX2 bar.

---

## 1. Why

Pops saw menus grow very large. SyFive caps text with `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)`
at its root (`SyFiveApp.swift` 55). That caps SwiftUI content only, and only outside sheets:

| Where | Today |
|---|---|
| The game screen (SwiftUI, `ContentView`) | xxxLarge |
| Sheets (28 presentation sites in SyFive) | Not capped: a cap doesn't cross a presentation, and no sheet re-applies it |
| Menus, picker menus, alerts (drawn by UIKit) | Not capped: SwiftUI's `dynamicTypeSize` doesn't reach them |

SyLibUI has the fix (`EXTENSIONS.md`): `sceneDynamicTypeCeiling(_:)` caps SwiftUI **and** what UIKit
draws in the window scene, by overriding the scene's preferred content size while the system's is
above the ceiling; `dynamicTypeCeiling(_:)` is `dynamicTypeSize(...maximum)`, applied at each
sheet's root. Proven on device in SyFLUX: at AX5, the root, every sheet, menus and alerts held at
AX2.

## 2. Locked decisions (Pops, 7 November 2026)

**2.1 The game screen stays at xxxLarge; sheets, menus and alerts are capped at AX2** (D-175).
A cap applied further in can only narrow, never widen, so:

```swift
// SyFiveApp.swift, at the root
ContentView()
    .dynamicTypeCeiling(.xxxLarge)             // the game screen, as today
    .sceneDynamicTypeCeiling(.accessibility2)  // UIKit (menus, picker menus, alerts) and the scene
```

and `.dynamicTypeCeiling(.accessibility2)` at the root of every sheet SyFive presents.
*Rationale:* the menus Pops saw come down to AX2, sheets stop growing past AX2, and nothing the
game screen draws changes.

**2.2 In 1.2.0, before the first TestFlight build.** Nothing grows past what it is today, and
sheets only shrink (for text sizes above AX2), so the risk is low.

**2.3 00B exception E-2** (Pops). 00A §5 sets the studio's MVP bar at AX2 "unless a project
states otherwise". SyFive states otherwise for its game screen, held at xxxLarge, because the dice
tray and the scorecard are too dense for the accessibility sizes. Its sheets, menus and alerts meet
the AX2 bar.

### 2.4 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| AX2 on the game screen too | It has never been laid out above xxxLarge; that's a layout project, not a cap (Pops, 7 Nov 2026) |
| `applyContentSizeRange` / `systemTextSize` | They set a floor as well; SyFive wants a ceiling only |
| Capping the Safari sheet | Drawn by another process; nothing can cap it (`EXTENSIONS.md`) |

---

## 3. Task 29.1 · Apply the ceilings

- **Inputs:** §2; SyLib `Docs/EXTENSIONS.md` (`dynamicTypeCeiling`, `sceneDynamicTypeCeiling`).
- **Change, `SyFiveApp.swift` 55:** `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` becomes the two
  modifiers in §2.1, in that order (`.dynamicTypeCeiling(.xxxLarge)` then
  `.sceneDynamicTypeCeiling(.accessibility2)`). Import `SyLibUI` if needed.
- **Change, every sheet root:** add `.dynamicTypeCeiling(.accessibility2)` as the last modifier on
  the view each of these presents (inside the `.sheet` closure, on its outermost view):

  | File | Lines |
  |---|---|
  | `Views/ContentView.swift` | 444, 448, 463, 468, 474, 485, 489, 494, 498, 501, 506, 514 |
  | `Views/PlayersView.swift` | 88, 92, 100, 119 |
  | `Views/PlayerScoreCardView.swift` | 107, 116 |
  | `Views/ScorecardView.swift` | 33 |
  | `Views/PlayerPickerSheet.swift` | 91 |
  | `Views/Stats/PlayerProfileView.swift` | 139 |
  | `Views/Stats/MatchDetailView.swift` | 84 |
  | `Views/Stats/UnfinishedMatchDetailView.swift` | 100 |
  | `Views/Stats/MatchHistoryView.swift` | 182, 185 |
  | `App/GameNight/Views/GameNightScreens.swift` | 39 |
  | `App/GameNight/Views/TableSettingView.swift` | 68, 71 |

  That's 28 sites (v1.0 said 27; the table always listed 28). If a closure's content is conditional (e.g. `if let pid …` at
  `PlayerScoreCardView` 107), wrap or apply so the cap covers every branch, and report how.
- **Leave alone:** the `#Preview`s' own `.dynamicTypeSize(...xxxLarge)` lines; SyLib.
- **Report, don't fix:** any `.sheet` or `.fullScreenCover` in SyFive not in this table (there
  should be none); and the sheets SyLib views present inside SyFive's (SeatClaimSheet's new
  player, Commentary's voice pickers), which rely on the scene ceiling.
- **Done when:** `grep -rn "dynamicTypeSize(\.\.\.DynamicTypeSize.xxxLarge)"` outside previews finds
  nothing; all 28 sites carry the cap; the build and SyFive's suite pass (20).

## 4. Validation

| # | Who | Check | Pass |
|---|---|---|---|
| V1 | Pops, iPhone (and iPad) | Settings › Accessibility › Display & Text Size › Larger Text, accessibility sizes on, slider to the top (AX5) | The game screen looks as it does at xxxLarge; the `⋯` menu's list and a picker's menu are no larger than AX2; an alert (e.g. archiving a player) is no larger than AX2 |
| V2 | Pops | At AX5, open each sheet: Settings, Players (and a player's profile and edit), History (and a match), House Records, How to Play, About, Dice Fairness, Feel Board | Each is held at AX2 and reads without clipping or overlap |
| V3 | Pops | At AX5: Settings › Commentary › the voice picker; Game Night seat claim › New Player | No larger than AX2. If either is larger, it's a SyLib follow-up (the nested sheet needs its own cap), not a 1.2.0 blocker |
| V4 | Pops | Back down to Large | Everything follows the system back down |

00A §5's bound applies: this is a static source change plus a visual check at the ceiling, not an
assistive-technology playthrough.

## 5. Ledger row

| ID | Ruling | Source |
|---|---|---|
| D-175 | **SyFive's game screen is capped at xxxLarge; its sheets, menus and alerts at AX2** (SyLibUI's `dynamicTypeCeiling(.xxxLarge)` inside `sceneDynamicTypeCeiling(.accessibility2)` at the root, and `dynamicTypeCeiling(.accessibility2)` at every sheet root). The game screen is 00B's E-2 exception to 00A §5's AX2 bar. | `29 §2` (Pops, 7 Nov 2026) |

## 6. Results log

| Task / V | Date | Result | Notes |
|---|---|---|---|
| 29.1 | 7 Nov 2026 | Done (checked by Claude against the tree) | At Pops's direction, the two SyLib modifiers sit behind SyFive helpers in `Extensions/View+TextSizeCeilings.swift`: `appTextSizeCeilings()` at the root (`dynamicTypeCeiling(.xxxLarge)` then `sceneDynamicTypeCeiling(.accessibility2)`, `SyFiveApp.swift` 56) and `sheetTextSizeCeiling()` (`dynamicTypeCeiling(.accessibility2)`) on all 28 sheet roots; the two sizes are named once (`gameScreenCeiling`, `appCeiling`). Same behavior as §3 specifies, with each size defined once. The conditional profile sheet (`PlayerScoreCardView` 107) is wrapped in a `Group`. Previews' own caps untouched. SyFive 20 expected |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 7 Nov 2026 | First version |
