# Wave: extract `SyLibScoringData`

Move SyFive's SwiftData persistence twins and their conversions into a new
package target, so ScoreIt v2 inherits the schema instead of re-typing it.

**Scope:** `sylib-swift` (new target) and `SyFive`.
Do not touch SydeTwo, SyLibDice, SyLibFeel, or SyLibCore.

---

## ⚠️ This wave touches live user data

`MatchModel`, `ParticipantModel`, `PlayerModel`, `TeamModel`, and `GameModel`
back records that already exist in users' private CloudKit databases under
`iCloud.com.syzygysoftwerksllc.SyFive`.

Moving a `@Model` class between modules **should** be a no-op — SwiftData derives
the entity name from the class name, and the class names do not change. But
"should" is doing real work in that sentence, and a fresh install will look
perfect either way.

**Verification against a device with existing match history is a hard
requirement of this wave, not a nice-to-have.** See §7.

Do not rename any model class, any stored property, or any raw-value string.
Do not add, remove, or reorder stored properties. This wave moves code between
modules and changes nothing else.

---

## 1. Why two targets

`SyLibScoring` imports Foundation and nothing else, and it depends on no other
target. That is enforced by the compiler, and it is the reason the target exists
separately from `SyLibCore`.

If SwiftData lived in the same module, the guarantee would go away, and the
failure it prevents is mundane: someone adds a convenience
`init(from model: ParticipantModel)` to `Participant` because it's right there,
and now the value types can't be used without a store. Persistence depending on
the domain is correct. The reverse is not.

So: `SyLibScoringData` depends on `SyLibScoring`, and the dependency never runs
the other way.

---

## 2. Target graph

```swift
.library(name: "SyLibScoringData", targets: ["SyLibScoringData"]),

.target(
    name: "SyLibScoringData",
    dependencies: ["SyLibScoring"]        // Foundation + SwiftData
),
```

`SyLibScoring` gains no dependencies. Verify after the change that it still
imports Foundation only.

---

## 3. What moves

From `SyFive/SyFive/Persistence/` into `sylib-swift/Sources/SyLibScoringData/`:

| From | To | Lines |
|---|---|---:|
| `Models/PlayerModel.swift` | `Models/PlayerModel.swift` | 20 |
| `Models/TeamModel.swift` | `Models/TeamModel.swift` | 15 |
| `Models/GameModel.swift` | `Models/GameModel.swift` | 20 |
| `Models/MatchModel.swift` | `Models/MatchModel.swift` | 33 |
| `Models/ParticipantModel.swift` | `Models/ParticipantModel.swift` | 27 |
| `Conversion/PlayerModel+Conversion.swift` | `Conversion/PlayerModel+Conversion.swift` | 26 |
| `Conversion/GameModel+Conversion.swift` | `Conversion/GameModel+Conversion.swift` | 32 |
| `Conversion/MatchModel+Conversion.swift` | `Conversion/MatchModel+Conversion.swift` | 49 |
| `Conversion/ParticipantModel+Conversion.swift` | `Conversion/ParticipantModel+Conversion.swift` | 34 |

## What stays in SyFive

- `Models/AppSettingsModel.swift` (84) — imports SwiftUI and SyLibFeel, holds
  SyFive settings.
- `Migration/LegacyYahtzeeRepair.swift` (68) and
  `Migration/LegacyRematchRepair.swift` (168) — SyFive-specific data repairs for
  SyFive's own history.
- `GNMatchIdentity.swift` (69) — Game Night.

---

## 4. Access levels

Every moved type crosses a module boundary and needs `public`. SwiftData's macro
does not widen access for you.

For each of the five models:
- `public final class`
- `public` on **every** stored property
- `public` on the computed accessors (`participants`, `status`, `source`,
  `scoreEntries`)
- `public init() {}` — currently internal; this is easy to miss and produces a
  confusing error at the call sites.

For the four conversion extensions: `public func toDomain()` and
`public func hydrate(from:)`.

`MatchModel.participantsStorage` carries
`@Relationship(deleteRule: .nullify, inverse: \ParticipantModel.match)`. The
inverse keypath now resolves within `SyLibScoringData`, which is fine — both
types move together. Confirm it still compiles rather than assuming.

Two comments to generalize while moving, since they name SyFive:
- `GameModel.swift:6` — "SyFive 1.0 holds exactly one row: Yatzy, seeded at launch."
- `TeamModel.swift:4` — "Frozen schema — SyFive 1.0 never instantiates a team;
  exists for ScoreIt v2 compatibility."

Reword both to describe the type generically. The second one's *intent* — that
the schema is shared and frozen — is now expressed by the code's location, so
say that instead.

---

## 5. Versioned schema

The package owns migrations for the models it owns. Two apps migrating the same
entity independently would produce divergent CloudKit schemas under identical
class names.

Add `Sources/SyLibScoringData/Schema/ScoringSchemaV1.swift`:

```swift
import Foundation
import SwiftData

/// Version 1 of the shared scoring schema. Frozen — it backs records already in
/// production CloudKit databases. Changes go in a new version, never here.
public enum ScoringSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [PlayerModel.self, TeamModel.self, GameModel.self,
         MatchModel.self, ParticipantModel.self]
    }
}

/// The shared scoring models, for composing into an app's own `Schema`.
public enum ScoringSchema {
    public static let current: [any PersistentModel.Type] = ScoringSchemaV1.models
}
```

Do **not** add a `SchemaMigrationPlan` yet — there is one version and nothing to
migrate. Adding an empty plan now invites someone to put an app-specific stage
in it. The `VersionedSchema` conformance is what matters; it pins V1 so a future
V2 has something to migrate from.

⚠️ `versionIdentifier` must be `1.0.0`. SyFive's existing store was created
without an explicit version, which SwiftData treats as the initial version.
Declaring anything else risks the container deciding a migration is required on
first launch after update.

---

## 6. SyFive changes

### 6.1 Container

`SyFiveApp.swift:21–27` composes the schema by hand. Compose from the shared list
instead, so the app's extras are visibly the only local part:

```swift
let schema = Schema(ScoringSchema.current + [AppSettingsModel.self])
```

The order of types within a `Schema` is not significant, but the resulting set
must be identical to today's six. Confirm that.

Leave `ModelConfiguration` untouched — same `cloudKitDatabase`, same identifier.

### 6.2 Imports

`import SyLibScoringData` is needed anywhere the five model types are referenced.
Breadth, by type: `MatchModel` 23 files, `PlayerModel` 19, `ParticipantModel` 18,
`GameModel` 15, `TeamModel` 11. Fifteen files call `toDomain()` or
`hydrate(from:)`.

Do not add the import speculatively — build and let the compiler name each file.

### 6.3 Preview schemas

Eleven files besides `SyFiveApp.swift` build a local `Schema([...])` for
previews: `ContentView`, `CelebrationView`, `PlayerPickerSheet`,
`PlayerMergeSheet`, `PlayerEditSheet`, `PlayerLinkSheet`, `PlayersView`,
`Stats/MatchDetailView`, `Stats/UnfinishedMatchDetailView`,
`HouseRecords/HouseRecordsView`.

These only need the import. Do not rewrite them to use `ScoringSchema.current` —
previews deliberately declare a minimal subset, and widening them makes previews
slower for no benefit.

---

## 7. Verification — required

```bash
# In sylib-swift
swift build && swift test
grep -rh "^import" Sources/SyLibScoring   # must be Foundation only
```

Then, in order:

1. **Build and run SyFive on the simulator.** Catches compile and access-level
   problems. Proves nothing about data.
2. **Run on the device with real match history, upgrading in place** — do not
   delete the app first. Confirm:
   - Match history lists past matches with correct scores and participants
   - Player list is intact, including any Game Night-sourced players
   - The Yatzy catalog row is present and not duplicated
   - Stats and House Records compute the same values as before
   - A new match saves and appears in history
3. **Confirm no unexpected CloudKit schema change.** In the CloudKit Console for
   `iCloud.com.syzygysoftwerksllc.SyFive` (Development), check that no new record
   types appeared and no existing type gained fields.

**If step 2 shows empty or partial history, stop immediately and report.** Do not
attempt a repair migration — that would compound the problem. The correct
response is to revert and investigate why the entity names didn't resolve.

---

## 8. Documentation

- New `Docs/ScoringData.md`, following the `Docs/Cache.md` format. Cover: the
  five models, `toDomain()` / `hydrate(from:)`, composing `ScoringSchema.current`
  with an app's own models, and the rule that migrations belong to the package.
- Update `Docs/Scoring.md` — its persistence-pattern section currently says each
  app declares its own models. That is no longer true; point at
  `SyLibScoringData`.
- README: add the `SyLibScoringData` row and bump the product count in the
  Installation section.

---

## 9. Definition of done

- [ ] `SyLibScoringData` target and product exist, depending only on `SyLibScoring`.
- [ ] `SyLibScoring` still imports Foundation only.
- [ ] Nine files moved; five models and four conversion extensions fully `public`,
      including `init()`.
- [ ] `ScoringSchemaV1` declares version `1.0.0` and lists all five models.
- [ ] No `SchemaMigrationPlan` added.
- [ ] SyFive's container composes `ScoringSchema.current + [AppSettingsModel.self]`
      and resolves to the same six types.
- [ ] No model class, stored property, or raw-value string was renamed.
- [ ] **Device with real history upgraded in place; all data intact.**
- [ ] No new CloudKit record types or fields.
- [ ] `Docs/ScoringData.md` written; `Docs/Scoring.md` and README updated.
- [ ] Report: every access level widened, plus the CloudKit Console check result.
