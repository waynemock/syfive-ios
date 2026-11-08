# SyLib's Players sheet: Score It \*'s roster, shared, and SyFive on it

**Status:** **Done (30.1, 30.2); V7 with the Game Night pass.** Version 1.1, 7 November 2026. In SyFive 1.2.0,
before the first TestFlight build (Pops, 7 November 2026).

**Scope:**
- **SyLib:** `sylib-swift` on `syfive-integration`. Additive: a new `PlayersSheet` and `NameStatsRow`
  in `SyLibScoringUI`. Score It \* adopted both on 7 November 2026 (Score It \* `26`, Tasks 26.1 and 26.2): SyLib's sheet
  gained a second, additive init that takes the app's route and path, and SyFive's call is unchanged.
  Syderal's check waits for its next release (26 §12).
- **SyFive:** `syfive-ios` on `sylib-reintegration`.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A`, `00B`, this document, SyLib
`Docs/SCORING_UI.md`.

---

## Supersessions

- **SyFive's delete moves.** Today an **archived** player with no matches has a "Delete Player"
  button on their profile (`PlayerProfileView` 109–138). It goes; delete becomes a swipe on an
  **active** player with no matches, as Score It \* does (D-177).
- **SyFive's archive alert copy changes** from "They'll be moved to the archive and removed from
  your roster." to Pops's §2.6 copy.
- Nothing else in the ledger is superseded. D-160 (Score It \*'s look) applies throughout.

---

## 1. Why

Pops likes Score It \*'s Players sheet. Read side by side on 7 November 2026, it and SyFive's
`PlayersView` are the same screen, and the hard parts (the palette editor, `PlayerMergeSheet`,
`PlayerLinkSheet`, `absorbPlayer`) are already SyLib's.

| | Score It \* `Views/Players/PlayersSheet.swift` | SyFive `Views/PlayersView.swift` |
|---|---|---|
| Rows | `NameStatsRow`: initials, name, "N matches" | Initials, name, a pencil, a list icon |
| Add | Toolbar **+** | A "New Player" row |
| Edit | Leading swipe | The pencil |
| Archive | Trailing swipe, asks | Trailing swipe, asks |
| Delete | Trailing swipe, active players with no matches, asks | Profile button, archived players with no matches |
| Archived | Collapsed "Archived" disclosure: Merge, Unarchive (asks) | Its own section, dimmed: Unarchive (doesn't ask), Merge |
| Profile | Pushed on the sheet's stack | A second sheet |
| Empty | `EmptyStateView` | An empty list |
| Look | Palette list, rows and bar | System list |
| Game Night players | n/a | "From Game Night" section: Add to Roster, Link, Archive |
| Writes | `LibraryEditor` | `modelContext`, `absorbPlayer` |

---

## 2. Locked decisions (Pops, 7 November 2026)

**2.1 Shared in SyLib, data in and callbacks out** (D-176). `SyLibScoringUI` gets `PlayersSheet`:
the app passes its players, its copy, and callbacks; the sheet draws the list, the swipes, the
alerts, the empty state and the palette look, and pushes the app's profile view. **Writes stay in
each app.** An app's own sections (SyFive's Game Night players) go in a leading slot. Score It \*'s
`NameStatsRow` moves into `SyLibScoringUI` with it. *Rationale:* one roster for the studio, without
making either app change its data layer.

**2.2 In 1.2.0** (Pops).

**2.3 Delete: a swipe on active players who have never played a match, and nowhere else** (D-177).
The profile's Delete button goes. An archived player with no matches is unarchived first, then
deleted.

**2.4 The profile is pushed** on the Players sheet's stack; Back returns to the list (D-178).
`PlayerProfileView` still opens as a sheet elsewhere (`PlayerScoreCardView` 110), so it learns to
be either.

**2.5 Each row shows "N games"** (D-179): the player's completed games. "1 game" for one.

**2.6 Copy** (Pops, verbatim; D-180):

| Where | Text |
|---|---|
| Archive alert | Title "Archive {name}?"; message "They won't appear in New Game. Their history stays." |
| Unarchive alert | Title "Unarchive {name}?"; message "They'll appear in New Game again." |
| Delete alert | Title "Delete this player?"; message "This can't be undone." |
| Empty | Title "No players yet"; message "Add players here, or when you start a new game." |

Buttons: "Archive", "Unarchive", "Delete" (destructive), "Cancel", "Done", "Edit", "Merge", as
Score It \* has them. SyFive's Game Night rows' Archive uses the same archive alert.

### 2.7 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| Moving `LibraryEditor` into SyLib | Score It \*'s writer; SyFive writes its own way. The sheet only calls back |
| Delete on archived players | One way to delete (§2.3) |
| Profile as a second sheet | Pushed (§2.4) |

---

## 3. Task 30.1 · SyLib: `PlayersSheet` and `NameStatsRow`

- **Inputs:** §2; Score It \*'s `Views/Players/PlayersSheet.swift` and `Views/Game/NameStatsRow.swift`
  (`score-it-all-ios` at `3c26af0`; read only); SyLib `Docs/SCORING_UI.md`.
- **New `Sources/SyLibScoringUI/Roster/NameStatsRow.swift`:** Score It \*'s `NameStatsRow`, made
  `public` (the struct, its stored properties' init, `body`), with its doc comment and previews.
  Nothing else changes.
- **New `Sources/SyLibScoringUI/Roster/PlayersSheet.swift`:**

  ```swift
  /// One player in the list.
  public struct PlayerListEntry: Identifiable, Hashable, Sendable {
      public let id: UUID
      public let name: String
      public let initials: String
      public let themeID: String
      /// The row's stats, e.g. "12 games".
      public let stats: String
      public let isArchived: Bool
      /// Whether the row offers Delete (the app decides; Score It and SyFive: no matches).
      public let canDelete: Bool
      public init(id: UUID, name: String, initials: String, themeID: String,
                  stats: String, isArchived: Bool, canDelete: Bool)
  }

  /// The sheet's words.
  public struct PlayersSheetCopy: Sendable {
      public var archiveMessage: String
      public var unarchiveMessage: String
      public var deleteTitle: String
      public var deleteMessage: String
      public var emptyTitle: String
      public var emptyMessage: String
      public init(archiveMessage: String, unarchiveMessage: String, deleteTitle: String,
                  deleteMessage: String, emptyTitle: String, emptyMessage: String)
      /// Score It *'s words.
      public static let scoreIt = PlayersSheetCopy(
          archiveMessage: "They won't appear in setup. Their history stays.",
          unarchiveMessage: "They'll appear in setup again.",
          deleteTitle: "Delete this player?", deleteMessage: "This can't be undone.",
          emptyTitle: "No players yet", emptyMessage: "Add players here, or when you start a match.")
  }

  public struct PlayersSheet<Profile: View, Leading: View>: View {
      public init(players: [PlayerListEntry],
                  copy: PlayersSheetCopy,
                  hasLeadingContent: Bool = false,
                  onAdd: @escaping () -> Void,
                  onEdit: @escaping (UUID) -> Void,
                  onArchive: @escaping (UUID) -> Void,
                  onUnarchive: @escaping (UUID) -> Void,
                  onDelete: @escaping (UUID) -> Void,
                  onMerge: @escaping (UUID) -> Void,
                  @ViewBuilder profile: @escaping (UUID) -> Profile,
                  @ViewBuilder leadingSections: @escaping () -> Leading)
  }
  ```

  Its body is Score It \*'s `PlayersSheet` body, with these substitutions and nothing else:

  | Score It \* | `PlayersSheet` |
  |---|---|
  | `@Query` rows, `onePerID`, sorting, `matchCounts` | `players` as given (the app sorts); active = `!isArchived`, archived = `isArchived` |
  | `NavigationStack(path: $path)`, `navigationDestination(for: DetailRoute.self)` | `NavigationStack`, `navigationDestination(for: UUID.self) { profile($0) }`; rows are `NavigationLink(value: entry.id)` |
  | `EmptyStateView(...)` when `players.isEmpty` | the same, with `copy.emptyTitle`, `copy.emptyMessage`, when `players.isEmpty && !hasLeadingContent` |
  | `IconButton("plus", context: .toolbar) { route = .newPlayer }` | `… { onAdd() }` |
  | Leading swipe Edit → `route = .edit` | `onEdit(id)` |
  | Delete swipe shown when the count is 0 | shown when `canDelete` |
  | `route = .merge` | `onMerge(id)` |
  | Alert actions through `libraryEditor` | `onDelete(id)`, `onArchive(id)`, `onUnarchive(id)` |
  | Alert messages, empty state | `copy`'s |
  | `row(_:matches:)`, `count` string | `NameStatsRow(name:initials:color:stackedLine: entry.stats) { Text(entry.stats) … }` |
  | `routeContent`, `PlayerEditor`, `PlayerMergeSheet`, the save-failure alert | removed: the app presents its own editor and merge sheets over this one, and reports its own failures |

  `leadingSections()` goes at the top of the `List`, before the active section. Everything else
  (the palette list, row and bar backgrounds, `.tint`, the Archived disclosure, Done, the inline
  title "Players", the alert titles "Archive {name}?" and "Unarchive {name}?") is Score It \*'s as
  it stands. Previews: active, archived, empty, a leading section, each alert.
- **Docs:** `SCORING_UI.md` documents `PlayerListEntry`, `PlayersSheetCopy`, `PlayersSheet` and
  `NameStatsRow`: what the app supplies, that writes stay with the app, and that a presented
  sheet doesn't take the root's text-size cap (apply the app's own at its presentation).
- **Tests (SyLib), total + 1:** `PlayersSheetCopy.scoreIt` holds Score It \*'s six strings.
- **Must not touch:** Score It \*; every existing SyLib type.
- **Done when:** SyLib's suite passes at its previous total + 1; SyFive builds. Syderal skipped
  (26 §12).

## 4. Task 30.2 · SyFive: Players on SyLib's sheet

- **Inputs:** §2; SyLib `SCORING_UI.md` (`PlayersSheet`). Runs after 30.1.
- **`Views/PlayersView.swift`:** its `body` becomes `PlayersSheet(...)`:

  | Parameter | Value |
  |---|---|
  | `players` | `allPlayers` where `source == .local` or `isArchived`, sorted by name; for each, `PlayerListEntry(id:name:initials:themeID:stats:isArchived:canDelete:)` with `stats` = "1 game" or "\(n) games", `n` = completed matches with a participant whose `playerID` is the player's; `canDelete` = no participant anywhere has that `playerID` |
  | `copy` | §2.6's, as a `PlayersSheetCopy` |
  | `hasLeadingContent` | `!gameNightPlayers.isEmpty` |
  | `onAdd` | `playerEditMode = .create` |
  | `onEdit` | `playerEditMode = .edit(player, matchSlot: nil)` |
  | `onArchive`, `onUnarchive` | set `isArchived`, then `try? modelContext.save()` |
  | `onDelete` | `modelContext.delete(player)`, then `try? modelContext.save()` |
  | `onMerge` | `pendingMerge = player` |
  | `profile` | `PlayerProfileView(playerID:playerName:themeType:isArchived:isPushed: true)` |
  | `leadingSections` | today's "From Game Night" section and its rows, unchanged. Their Archive swipe keeps SyFive's own alert (the sheet's alerts are internal to it), with title "Archive {name}?" as today and the message now §2.6's "They won't appear in New Game. Their history stays."; the button stays "Archive" |

  Its existing `.sheet`s (editor, link, merge), each with `.sheetTextSizeCeiling()`, and its
  failure alert stay, attached to the `PlayersSheet`. Delete `rosterRow`, `archivedRow`, the New
  Player row, and `selectedProfile` and its sheet. `pendingArchive` and its alert stay, now used by
  the Game Night rows only.
- **`Views/Stats/PlayerProfileView.swift`:** add `var isPushed: Bool = false`. When `true`: no
  `NavigationStack` of its own and no Done; the rest unchanged. Remove the Delete Player button,
  `showsDeleteAlert` and its alert (109–138) in both forms (§2.3).
- **Must not touch:** `PlayerScoreCardView`'s profile sheet (it keeps `isPushed: false`); the
  Game Night link and merge logic; SyLib.
- **Done when:** the build and SyFive's suite pass (20).

## 5. Validation (Pops, iPhone and iPad)

| # | Check | Pass |
|---|---|---|
| V1 | Players | Score It \*'s look; rows "N games"; **+** adds; leading swipe edits |
| V2 | Swipe an active player with no games | Delete and Archive; Delete asks "Delete this player?" |
| V3 | Archive, then open Archived | Collapsed disclosure; Unarchive asks; Merge opens the merge sheet |
| V4 | Tap a player | Profile pushes; Back returns; no Delete button |
| V5 | A pre-game card's View profile | Still a sheet, with Done |
| V6 | No players | "No players yet" / "Add players here, or when you start a new game." |
| V7 | With Game Night players (deferred Game Night pass) | "From Game Night" sits above the roster; Add to Roster, Link, Archive work |
| V8 | At AX5 | The sheet holds at AX2 (29) |

## 6. Ledger rows

| ID | Ruling | Source |
|---|---|---|
| D-176 | **The Players sheet is SyLibScoringUI's `PlayersSheet`** (with `NameStatsRow`), data in and callbacks out; writes stay in each app; SyFive's Game Night section sits in its leading slot. SyFive adopts it in 1.2.0. | `30 §2.1` (Pops, 7 Nov 2026) |
| D-177 | **A player is deleted only by a swipe on an active player who has never played**; the profile's Delete button is removed. | `30 §2.3` |
| D-178 | **A player's profile is pushed on the Players sheet**; elsewhere it stays a sheet. | `30 §2.4` |
| D-179 | **Players rows show "N games"** (completed games). | `30 §2.5` |
| D-180 | **The Players sheet's copy is `30` §2.6's**, Score It \*'s with "setup" as "New Game" and "a match" as "a new game". | `30 §2.6` |

## 7. Results log

| Task / V | Date | Result | Notes |
|---|---|---|---|
| 30.1 | 7 Nov 2026 | Done (checked by Claude against the SyLib tree) | `Roster/PlayersSheet.swift` (`PlayerListEntry`, `PlayersSheetCopy` with `.scoreIt`, `PlayersSheet`) and `Roster/NameStatsRow.swift` in SyLibScoringUI; Score It's body with §3's substitutions; 7 sheet previews; `SCORING_UI.md` Roster section; `PlayersSheetCopyTests`. SyLib 1561 expected; Syderal skipped |
| 30.2 | 7 Nov 2026 | Done (checked by Claude against the tree) | `PlayersView` is `PlayersSheet` (298 lines): entries with "1 game"/"N games" and `canDelete` from any participant; §2.6's copy verbatim; profile `isPushed: true`; Game Night section in the leading slot, its archive alert with §2.6's message. `PlayerProfileView` has `isPushed` and no Delete button. SyFive 20 expected |
| V1–V6, V8 | 7 Nov 2026 | **Pass** (Pops, iPhone and iPad) | |
| V7 | | **Deferred** to the Game Night pass on TestFlight | |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 7 Nov 2026 | First version |
| 1.1 | 7 Nov 2026 | Score It \* adopted `PlayersSheet` and `NameStatsRow` (Score It \* `26`); the sheet's route form is additive, SyFive's call unchanged |
