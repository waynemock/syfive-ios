# SyLib's profile header: Score It \*'s player card, with Edit, on SyFive's profile

**Status:** **Done (31.1, 31.2); V1–V6 pass.** Version 1.0, 7 November 2026. In SyFive 1.2.0, before the first
TestFlight build (Pops, 7 November 2026).

**Scope:**
- **SyLib:** `sylib-swift` on `syfive-integration`. Additive: a new `PlayerProfileHeader` in
  `SyLibScoringUI`. Score It \* keeps its own header until it adopts this one in its own session.
  Syderal's check waits for its next release (26 §12).
- **SyFive:** `syfive-ios` on `sylib-reintegration`.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A`, `00B`, this document, `30`, SyLib
`Docs/SCORING_UI.md`.

---

## Supersessions

- **SyFive's profile title** changes from large to inline (D-183).
- Nothing else in the ledger is superseded. D-160 (Score It \*'s look) applies throughout; D-177
  and D-178 stand.

---

## 1. Why

30.2 replaced the Players rows' pencil with Score It \*'s leading swipe, and SyFive's profile has
no edit control of its own, so a player opened from Players, or from a pre-game card's View
profile, can't be edited from there (Pops, 7 November 2026: "we lost the edit button").

Score It \*'s profile (`Views/Players/PlayerProfileView.swift`, `score-it-all-ios` at `3c26af0`,
lines 138–156) opens with a header card: a 44-point `InitialsCircle` in the player's accent, the
name (title3 semibold, up to two lines), "Archived" under it for an archived player, and a pencil
`IconButton` labelled "Edit Player", tinted the theme's primary accent. Its parts are already
SyLib's (`InitialsCircle`, `IconButton`).

---

## 2. Locked decisions (Pops, 7 November 2026)

**2.1 Shared in SyLib, data in and a callback out** (D-181). `SyLibScoringUI` gets
`PlayerProfileHeader`, Score It \*'s header as it stands. The app passes the name, initials, accent,
archived flag and an edit callback; with no callback there is no pencil. **Writes stay in each
app.** *Rationale:* the studio's player card in one place, as with `PlayersSheet` (D-176).

**2.2 In 1.2.0** (Pops).

**2.3 SyFive's profile opens with the header, and its pencil edits the player, in both forms**
(D-182): pushed on Players, and as the sheet from a pre-game card. The profile presents SyFive's
`PlayerEditSheet` itself; from a pre-game card the edit also updates that seat, as the card's own
edit does. The header reads the player live, so a saved edit shows at once (name, initials, accent
and the profile's theme).

**2.4 The title is inline**, as Score It \*'s (D-183): the name is in the header, so it isn't shown
twice in large type.

**2.5 "Archived"** shows under an archived player's name, Score It \*'s word (D-184).

### 2.6 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| A large title over the header | The name twice (§2.4) |
| Score It \*'s ⋯ menu with Edit | The pencil is the edit; not asked for |
| Moving `LibraryEditor` or `PlayerEditSheet` into SyLib | Each app's writer (§2.1) |

---

## 3. Task 31.1 · SyLib: `PlayerProfileHeader`

- **Inputs:** §2; Score It \*'s `Views/Players/PlayerProfileView.swift` 138–156 (`header`; read
  only); SyLib `Docs/SCORING_UI.md`.
- **New `Sources/SyLibScoringUI/Roster/PlayerProfileHeader.swift`:**

  ```swift
  /// A player profile's opening card: initials, name, "Archived" when archived, and an Edit pencil.
  public struct PlayerProfileHeader: View {
      public init(name: String,
                  initials: String,
                  color: Color,
                  isArchived: Bool = false,
                  onEdit: (() -> Void)? = nil)
  }
  ```

  Its body is Score It \*'s `header`, with these substitutions and nothing else:

  | Score It \* | `PlayerProfileHeader` |
  |---|---|
  | `player?.initials ?? ""`, `player?.name ?? ""` | `initials`, `name` |
  | `playerAccent` | `color` |
  | `player?.isArchived == true` | `isArchived` |
  | `IconButton("pencil") { sheet = .edit }` | `if let onEdit { IconButton("pencil") { onEdit() } … }` |

  Everything else (spacing 12 and 2, the 44-point circle, `.title3.weight(.semibold)`,
  `.lineLimit(2)`, "Archived" in subheadline secondary, the full-width leading frame,
  `.accessibilityLabel("Edit Player")`, `.tint(syTheme.primaryAccent)`) is Score It \*'s as it
  stands. Previews: active with Edit, archived with Edit, no Edit, a long name.
- **Docs:** `SCORING_UI.md`'s Roster section documents `PlayerProfileHeader`: what the app
  supplies, that a nil `onEdit` hides the pencil, and that writes stay with the app.
- **Tests:** none (a view with no logic); the total stays 1561.
- **Must not touch:** Score It \*; every existing SyLib type.
- **Done when:** SyLib's suite passes at 1561; SyFive builds. Syderal skipped (26 §12).

## 4. Task 31.2 · SyFive: the header on the profile, with Edit

- **Inputs:** §2; SyLib `SCORING_UI.md` (`PlayerProfileHeader`). Runs after 31.1.
- **`Views/Stats/PlayerProfileView.swift`:**
  - New parameters: `matchModel: MatchController` (for `PlayerEditSheet`) and
    `matchSlot: Int? = nil` (the seat to update, from a pre-game card).
  - Read the player live: a `@Query` of `PlayerModel` filtered to `playerID` (set in `init`), and
    `player` = its first row. Name, initials and theme come from `player` when there is one, and
    from the passed `playerName` and `themeType` (initials: the name's first letter, uppercased)
    when there isn't. `theme` uses that theme, so the profile's accent follows an edit.
  - `content`'s `VStack` opens with `PlayerProfileHeader(name:initials:color: theme.primaryAccent,
    isArchived: player?.isArchived ?? isArchived, onEdit:)`, before the PvP/Solo picker.
    `onEdit` is `nil` when there is no `player`; otherwise it sets `editMode =
    .edit(player, matchSlot: matchSlot)`.
  - `.sheet(item: $editMode) { PlayerEditSheet(mode: $0, matchModel: matchModel)
    .environment(\.syTheme, theme).sheetTextSizeCeiling() }`, on the body beside the head-to-head
    sheet.
  - `.navigationTitle` uses the live name; `.navigationBarTitleDisplayMode(.inline)`.
  - Nothing else changes: the picker, the stats, the empty state, Done when not pushed.
- **`Views/PlayersView.swift`:** the `profile` closure passes `matchModel: matchController`.
- **`Views/PlayerScoreCardView.swift`** (110): passes `matchModel: model, matchSlot: playerIndex`.
- **Preview** (444): passes `matchModel: MatchController()`.
- **Must not touch:** `PlayerEditSheet`; `PlayersView`'s leading swipe; SyLib.
- **Done when:** the build and SyFive's suite pass (20).

## 5. Validation (Pops, iPhone and iPad)

| # | Check | Pass |
|---|---|---|
| V1 | Players → a player | Header: circle, name, pencil; title inline in the bar; Back returns |
| V2 | Tap the pencil, change name, initials and color, Save | Editor sheet with SyFive's palette editor; header, title and accent update at once; Back shows the new row |
| V3 | An archived player's profile | "Archived" under the name; the pencil edits |
| V4 | A pre-game card's View profile → pencil, change the name | The sheet's header updates; Done; the card shows the new name |
| V5 | VoiceOver on the pencil | "Edit Player, button" |
| V6 | At AX5 | Profile and editor hold at AX2 (29); a long name wraps to two lines |

## 6. Ledger rows

| ID | Ruling | Source |
|---|---|---|
| D-181 | **A player profile opens with SyLibScoringUI's `PlayerProfileHeader`**, Score It \*'s header (initials, name, "Archived", Edit pencil), data in and an edit callback out; no callback, no pencil. SyFive adopts it in 1.2.0. | `31 §2.1` (Pops, 7 Nov 2026) |
| D-182 | **SyFive's profile pencil edits the player in both forms** (pushed and as a sheet), through `PlayerEditSheet`; from a pre-game card it updates that seat too. The header reads the player live. | `31 §2.3` |
| D-183 | **SyFive's profile title is inline.** | `31 §2.4` |
| D-184 | **An archived player's header reads "Archived".** | `31 §2.5` |

## 7. Results log

| Task / V | Date | Result | Notes |
|---|---|---|---|
| 31.1 | 7 Nov 2026 | Done (checked by Claude against the SyLib tree) | `Roster/PlayerProfileHeader.swift`: Score It's `header` with §3's substitutions only, `public`, inside `#if os(iOS)`; nil `onEdit` hides the pencil; the four previews; `SCORING_UI.md` Roster section and iOS-only table. No tests (none specified); SyLib 1561 expected; Syderal skipped |
| 31.2 | 7 Nov 2026 | Done (checked by Claude against the tree) | `PlayerProfileView` takes `matchModel` and `matchSlot`; a `@Query` of `PlayerModel` filtered to `playerID` drives the live name, initials and theme (passed values as fallback); `PlayerProfileHeader` opens the content, `onEdit` nil with no player; `PlayerEditSheet` from `editMode` with the theme and `.sheetTextSizeCeiling()`; title live and inline. `PlayersView` passes `matchController`; `PlayerScoreCardView` passes `model` and `playerIndex`; preview updated. SyFive 20 expected |
| V1–V6 | 7 Nov 2026 | **Pass** (Pops: "tested fine") | |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 7 Nov 2026 | First version |
