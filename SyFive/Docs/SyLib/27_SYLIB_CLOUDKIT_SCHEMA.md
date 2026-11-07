# SyLib: one CloudKit schema push for every app (`SyLibCloud.CloudKitSchema`)

**Status:** **Done for SyLib and SyFive** (27.1, 27.2, V1; 6 November 2026); other apps adopt per §6. Version 1.0, 6 November 2026. All of §2 is ruled by Pops,
6 November 2026, including the recommendations in §2.3 to §2.5, ruled as written. Number 27 was previously used by a note that was never filed; that note is now
`Requirements/17`.

**Scope:**
- **`sylib-swift`** on `syfive-integration`, at or after `0ee6219`. This doc adds to `SyLibCloud`
  and `SyLibScoringData` (Task 27.1).
- **`syfive-ios`** on `sylib-reintegration` (Task 27.2), after `26` closes.
- **The other apps** adopt it in their own sessions (§6).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document, and SyLib's `Docs/CLOUD.md` and
`Docs/SCORING_DATA.md`.

---

## Supersessions

None. D-026 (Development is promoted to Production before TestFlight) and D-129 (SyFive keeps its
own store) are unchanged. This doc only replaces the hand-copied tool that fills Development.

---

## 1. Why

A Production schema deploy is complete only when Development already has every record type and
field, including ones the app hasn't written yet. SwiftData has no API for this. Every SwiftData
app has therefore copied the same Apple pattern: open the store through a throwaway
`NSPersistentCloudKitContainer`, call `initializeCloudKitSchema()`, and unload it before
`ModelContainer` opens the store. The Core Data apps call `initializeCloudKitSchema()` directly.

What the apps have today (read 6 November 2026):

| App | Store | Where | How it's gated |
|---|---|---|---|
| SyFive | SwiftData, its own container (D-129) | `SyFiveApp.swift` 32–37 (call), 60–88 (function) | `#if DEBUG` + `AppConfig.DebugCloudKit.runSchemaExercise`, which is in `00B` §6's checklist |
| Score It \* | SwiftData, `makeScoringContainer` | `ScoreItAllApp.swift` 65–68 (call), 187–219 (function) | `#if DEBUG`, call commented out |
| Syderal | SwiftData, `makeScoringContainer` | `App/RecordsStore.swift` 40–43 (call), 82–114 (function) | `#if DEBUG`, call commented out |
| SyWord | Core Data, `NSPersistentCloudKitContainer` | `Providers/GameProvider.swift` 71 | Commented out, not in `#if DEBUG` |
| SyEmber | Core Data, `NSPersistentCloudKitContainer` | `DataProviders/CoreDataStack.swift` 73 | Commented out, not in `#if DEBUG` |

The three SwiftData functions are the same apart from the logger and the container's name.
Score It \* and Syderal also rebuild a `ModelConfiguration` "only to learn where the store is",
because `makeScoringContainer` doesn't expose the one it builds. SyWord and SyEmber don't link SyLib
today.

---

## 2. Locked decisions

**2.1 It lives in `SyLibCloud`** (D-168; Pops). That module already owns the app's view of the
iCloud account (`CLOUD.md`), and the schema push concerns the same container. *Rationale:* no new
product, and the module stays named for its domain. The cost is that `SyLibCloud` gains public
SwiftData and Core Data imports. Both are system frameworks, and every app this serves already uses
one of them. Its rule that "no CloudKit type appears in its public API" still holds: the types in the
new API are SwiftData's and Core Data's.

**2.2 Every Syzygy app with CloudKit uses it eventually** (D-168; Pops). SyFive goes first (27.2).
Each other app adopts it in its own session (§6).

**2.3 Two entry points, and a convenience for scoring apps** (Pops, as recommended):
- **SwiftData:** the app passes its own models and the `ModelConfiguration` it is about to open.
  SyFive uses this, which keeps D-129 intact.
- **Core Data:** the app passes its own loaded `NSPersistentCloudKitContainer`.
- **Scoring:** `SyLibScoringData` adds `initializeScoringCloudKitSchema(additionalModels:
  cloudKitContainerIdentifier:)`. It builds the exact models and configuration that
  `makeScoringContainer` builds, from one internal function both of them call, so the two can't
  drift.

*Rationale:* each app calls with what it already has, and nobody reconstructs a configuration.

**2.4 Failures are returned and logged, never fatal** (Pops, as recommended). Each entry point returns
`Result<Void, Error>`, marked `@discardableResult`. It logs through
`AppLogger(category: "CloudKit")`, which SyLib owns, so there is no logger parameter. Offline, no
iCloud account and the Simulator are all ordinary failures. *Rationale:* this is today's behavior in
every SwiftData app, and the `Result` makes it testable.

**2.5 The gate stays in the app, as a flag** (D-169) (Pops, as recommended). SyLib doesn't decide when the push
runs. Each app keeps `#if DEBUG` + `AppConfig.DebugCloudKit.runSchemaExercise` (SyFive's form) and
lists the flag in its pre-archive checklist. A commented-out call is retired. *Rationale:* a flag
can be checked before an archive; a comment can't. `00A` gets the convention (§5).

### 2.6 Considered and excluded (do not revisit)

| Excluded | Why |
|---|---|
| A new `SyLibCloudKit` product | `SyLibCloud` already exists for this domain (§2.1) |
| `SyLibCore` | It would pull SwiftData and Core Data into the base module |
| A gate inside SyLib (a `DEBUG` check, or a parameter on `makeScoringContainer`) | When to push is the app's release decision, and SyFive can't use `makeScoringContainer` (D-129) |
| A logger parameter | SyLib logs under its own category, as its other modules do |

---

## 3. Task 27.1 · SyLib: `CloudKitSchema` and the scoring convenience

- **Inputs:** this doc §2; SyLib `Docs/CLOUD.md`, `Docs/SCORING_DATA.md`; SyFive's
  `SyFiveApp.swift` 57–88, which is the reference body.
- **Change, `Sources/SyLibCloud/CloudKitSchema.swift` (new):**

  ```swift
  import Foundation
  import SwiftData
  import CoreData
  import SyLibCore

  /// Pushes every record type and field to the CloudKit Development environment, so a
  /// Production deploy is complete (see CLOUD.md). Slow and network-bound. Call it before the app
  /// opens its store, and only from a debug flag the app checks before archiving.
  public enum CloudKitSchema {
      /// SwiftData. Opens the store at `configuration.url` through a throwaway
      /// NSPersistentCloudKitContainer for `containerIdentifier`, initializes the schema built
      /// from `models`, and removes the store before returning, so a ModelContainer can open it
      /// next.
      @discardableResult
      public static func initializeDevelopment(models: [any PersistentModel.Type],
                                               configuration: ModelConfiguration,
                                               containerIdentifier: String) -> Result<Void, Error>

      /// Core Data. Calls `initializeCloudKitSchema()` on the app's own container, whose stores
      /// are already loaded.
      @discardableResult
      public static func initializeDevelopment(_ container: NSPersistentCloudKitContainer) -> Result<Void, Error>
  }
  ```

  - **The SwiftData body** is SyFive's function (`SyFiveApp.swift` 60–88), moved with only these
    changes: it takes `models`, `configuration` and `containerIdentifier` as parameters; it names the
    throwaway container `"CloudKitSchema"`; it logs through `AppLogger(category: "CloudKit")` with
    `CloudKitSchema.self`; and it returns `.success` or `.failure(error)` where SyFive only logs.
    Keep the `autoreleasepool`, `shouldAddStoreAsynchronously = false`, the
    `makeManagedObjectModel(for:)` guard (failing with `CocoaError(.featureUnsupported)`) and the
    store removal, each with SyFive's comment.
  - **The Core Data body:** `try container.initializeCloudKitSchema()`, logged and returned in the
    same way.
  - **Platforms:** no `#if os`. Everything it uses exists on every SyLib platform (iOS 17, macOS 14,
    tvOS 17, watchOS 10).
- **Change, `Package.swift`:** none. `SyLibCloud` already depends on `SyLibCore`, and system
  frameworks need no entry.
- **Change, `SyLibScoringData`:**
  - `Package.swift`: `SyLibScoringData`'s dependencies become `["SyLibScoring", "SyLibCloud"]`.
  - `Operations/ScoringContainer.swift`: add
    `internal func scoringConfiguration(additionalModels:cloudKitContainerIdentifier:) ->
    (models: [any PersistentModel.Type], configuration: ModelConfiguration)`. It returns exactly what
    `makeScoringContainer` builds today: `ScoringSchema.current + additionalModels`, and a
    configuration with that schema and `.private(cloudKitContainerIdentifier)`, nothing else. Then
    `makeScoringContainer` calls it, with its signature, documentation and behavior unchanged.
  - Add, in the same file:

    ```swift
    /// Pushes the schema `makeScoringContainer` would open (the same models and configuration)
    /// to CloudKit Development. Call it before `makeScoringContainer`. See SyLibCloud's
    /// `CloudKitSchema`.
    @discardableResult
    public func initializeScoringCloudKitSchema(additionalModels: [any PersistentModel.Type] = [],
                                                cloudKitContainerIdentifier: String) -> Result<Void, Error>
    ```

    Its body is `scoringConfiguration(…)` followed by `CloudKitSchema.initializeDevelopment(…)`.
- **Docs:**
  - `CLOUD.md` gains a `## CloudKitSchema` section: what it's for (§1), the two entry points and an
    example of each, the app-side flag (§2.5, with SyFive's form as the example), and "run once on
    a device signed into iCloud, then check CloudKit Console › Development". Its Module and Depends
    lines note SwiftData and Core Data.
  - `SCORING_DATA.md` documents `initializeScoringCloudKitSchema` next to `makeScoringContainer`.
- **Tests (SyLib, Swift Testing), total + 3:**
  1. **A Core Data container with no stores loaded** returns `.failure`, and doesn't crash.
  2. **The SwiftData entry point, on a temporary file store** with an identifier that has no
     entitlement, returns `.failure`, and afterwards a `ModelContainer` opens a store at the same
     URL. This shows the throwaway stack was removed. Use a small `@Model` defined in the test.
     *Pre-authorized fallback:* if this test takes longer than 30 seconds on the pinned simulator,
     or depends on the simulator's iCloud state, delete it, report what happened, and the total is
     + 2.
  3. **`scoringConfiguration`'s models** are `ScoringSchema.current + additionalModels`, in that
     order (`@testable import`).
- **Must not touch:** `makeScoringContainer`'s and `makeInMemoryScoringContainer`'s signatures and
  behavior; anything else in `SyLibCloud`; any app.
- **Done when:**
  - SyLib's suite passes at its previous total + 3 (or + 2, under the fallback), on the pinned
    destination.
  - Syderal builds and its suite passes (`00B` §5.4); Syderal isn't edited.
  - SyFive builds; SyFive isn't edited.

## 4. Task 27.2 · SyFive adopts it (after `26` closes)

- **Inputs:** this doc; SyLib `Docs/CLOUD.md`. Link `SyLibCloud` to the SyFive target in Xcode first
  (Pops) if it isn't already linked.
- **Change, `SyFiveApp.swift`:**
  - The flag-gated call (32–37) becomes
    `CloudKitSchema.initializeDevelopment(models: SyFiveApp.models, configuration:
    modelConfiguration, containerIdentifier: SyFiveApp.cloudKitContainerID)`, still inside
    `#if DEBUG` and the `runSchemaExercise` check, with the same comment.
  - Delete `initializeCloudKitSchema(config:)` and its `cloudKitLogger` (50–88, the `#if DEBUG`
    block), along with any `import CoreData` that only they needed.
  - `AppConfig.DebugCloudKit.runSchemaExercise`'s doc comment (`AppConfig.swift` 23) names
    `CloudKitSchema.initializeDevelopment` instead.
- **Must not touch:** the container, its configuration, the seed (D-129); the flag's value.
- **Done when:** the build and SyFive's suite pass. Then Pops runs it once with the flag on, on a
  device signed into iCloud: the log reads "Development schema initialized", and CloudKit Console ›
  Development shows SyFive's record types (V1).

---

## 5. `00A` convention (for Pops to add to the studio copy)

Proposed text, under `00A` §8 or a new "CloudKit" heading:

> **CloudKit schema push.** Every app with CloudKit pushes its Development schema through SyLib's
> `CloudKitSchema` (or `initializeScoringCloudKitSchema` with `makeScoringContainer`). The call sits
> inside `#if DEBUG` and `AppConfig.DebugCloudKit.runSchemaExercise`, and that flag is on the
> app's pre-archive checklist. Never a commented-out call.

---

## 6. The other apps (their own sessions)

| App | Change | Notes |
|---|---|---|
| Score It \* | Call `initializeScoringCloudKitSchema(additionalModels: [], cloudKitContainerIdentifier: Self.cloudKitContainerID)` behind the flag; delete its function (`ScoreItAllApp.swift` 181–219) | Adds the `AppConfig` flag and a checklist line |
| Syderal | Call `initializeScoringCloudKitSchema(additionalModels: appModels, …)` behind the flag; delete its function (`RecordsStore.swift` 71–115) | The same; it also owes its `ScoringSchemaV2` push (`26` §10) |
| SyWord, SyEmber | Call `CloudKitSchema.initializeDevelopment(container)` behind the flag | Each first needs the SyLib package and `SyLibCloud` |

---

## 7. Validation

| # | When | Who | Check | Pass |
|---|---|---|---|---|
| V1 | After 27.2 | Pops, device signed into iCloud | Flag on, one launch, flag off | Log: "Development schema initialized"; Console › Development has every SyFive record type; the app opened its store normally afterwards |

## 8. Invariants

- SyLib never decides when the push runs; the app's flag does.
- `makeScoringContainer`'s store and configuration are unchanged; its configuration comes from one
  internal function shared with the convenience.
- D-129 holds: SyFive passes its own configuration and opens its own container.

## 9. Ledger rows

| ID | Ruling | Source |
|---|---|---|
| D-168 | **CloudKit Development schema pushes go through SyLibCloud's `CloudKitSchema`** (SwiftData and Core Data entry points; `initializeScoringCloudKitSchema` for `makeScoringContainer` apps). Every Syzygy app with CloudKit adopts it, each in its own session; SyFive first. | `27 §2.1–2.3` (Pops, 6 Nov 2026) |
| D-169 | **The push runs only behind `#if DEBUG` and `AppConfig.DebugCloudKit.runSchemaExercise`**, a flag on the pre-archive checklist; never a commented-out call. SyLib holds no gate. | `27 §2.5` |
| D-170 | **A failed push is returned and logged, never fatal** (`Result<Void, Error>`, SyLib's `CloudKit` log category), **for a container identifier in the app's entitlements.** An identifier that isn't traps inside CloudKit and can't be caught, as SyFive's own copy always did (found by 27.1's test, 6 Nov 2026). | `27 §2.4` |

## 10. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| 27.1 | 6 Nov 2026 | Done (code checked by Claude); Syderal check not run | — / 1560 | `CloudKitSchema` (both entry points) in SyLibCloud; `scoringConfiguration` shared by `makeScoringContainer` and `initializeScoringCloudKitSchema`; SyLibScoringData depends on SyLibCloud; `CLOUD.md` and `SCORING_DATA.md` updated. **Test 2 deleted under the pre-authorized fallback:** with an identifier not in the process's entitlements, CloudKit traps inside Core Data's setup queue (`PFCloudKitContainerProvider`, `xctest-2026-11-06-205208.ips`), killing the process; no error reaches the `catch`. SyLib's test host can't hold an iCloud entitlement. Syderal's build is blocked by its pre-existing `Match(… options:)` break (26 §12) |
| 27.2 | 6 Nov 2026 | Done (checked by Claude against the tree) | 20 expected / — | `SyFiveApp` calls `CloudKitSchema.initializeDevelopment(models:configuration:containerIdentifier:)` inside the same `#if DEBUG` and flag; its own copy and `import CoreData` removed (62 lines); `AppConfig`'s comment updated |
| V1 | 6 Nov 2026 | **Pass** (Pops, device) | | Log: "initializeDevelopment: Development schema initialized". `runSchemaExercise` was left `true` after the run: set back to `false` before any archive (`00B` §6) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 6 Nov 2026 | First version, from a survey of the five apps' copies |
