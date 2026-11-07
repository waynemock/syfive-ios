# SyLib's update check re-runs when the app comes back to the foreground

**Status:** **Closed** 28 October 2026. §4.1 to §4.3 built; U1, U2, U3 and U5 pass; U4 is
confirmed at the next SyFive release. v1.1 revised §2.3 and added §2.8. Written 28 October 2026;
revised the same day.

**Scope:** `sylib-swift` on `main` at `a04f831` (§4.1), and `SyFive` on `main` at `cff4999` (§4.2,
verification only: SyFive needs no source change). Other apps adopt the new SyLib in their own
sessions (§2.6, `00B` §5.4).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document.

---

## Supersessions

None in SyFive's documents. D-139 (the badge, and acknowledging it) is unchanged; this adds when
the check runs (D-154, §7).

In SyLib, `Docs/APP_STORE.md` and the doc comments on `AppUpdateState` and `AppUpdateChecker`
describe `AppUpdateState` as "the app's update state for one launch", say to "call `check()` once
at launch", and describe "the 24-hour cache". §4.1 rewrites them.

---

## 1. Why

A running app only learns of a new App Store version on its next cold launch. Pops noticed that
SyFive's menu badge appears at once after a restart, and not otherwise.

Two things cause it:

- **SyFive and Syderal call `check()` once, at launch** (SyFive `Views/ContentView.swift` 237-240,
  `.task`; Syderal `App/RootView.swift` 285-288). Nothing re-checks when the app returns from the
  background.
- **`AppUpdateChecker` reuses its last answer for 24 hours** (`minimumCheckInterval`), in memory.
  Sydoku, SyWord, SyFLUX and SydeTwo do re-check on each return to the foreground, but within 24
  hours of the last real lookup they get the cached answer back. A release made a few hours after
  someone opened one of them can take most of a day to show. Only a new process starts with an
  empty cache, which is why a restart always shows the badge.

Pops, 28 October 2026: put the foreground check in SyLib so every app gets it, and fix SyFive now.

---

## 2. Locked decisions

**2.1 `AppUpdateState` re-checks by itself each time the app becomes active** (D-154). It observes
the platform's "did become active" notification and calls the same lookup `check()` uses. An app
that already uses `AppUpdateState` gets this with no source change. *Rationale:* Pops's ruling;
one place, not one wiring per app.

**2.2 Only after the app's first `check()`** *(rec.)*. Until the app has called `check()` once, a
foreground event does nothing. *Rationale:* keeps the existing rule that `AppUpdateState` "makes
no network request until `check()` is called", so previews, tests and a second scene stay quiet.

**2.3 A lookup is reused for 15 minutes, not 24 hours** (D-154). `AppUpdateChecker`'s interval
becomes 900 seconds. *Rationale:* Pops's ruling. The cache exists only to stop rapid app-switching
from making a request on every return to the foreground; 15 minutes keeps that protection, and the
App Store's own lookup often lags a release by longer. **v1.0 said 1 hour** (built in §4.1); Pops
shortened it on 28 October 2026 after asking what the hour was for. §4.3 makes the change.

**2.8 A failed lookup is not cached** (D-154). A lookup that returns no store version (a network
or parsing error, no result for the app, or no bundle identifier) leaves the cache as it was, so
the next call tries again. A successful lookup is cached as now, whether or not the store's
version is newer. *Rationale:* Pops, 28 October 2026. Under v1.0 an app opened offline cached
`(false, nil)` and did not try again for the whole interval, even once back online.

**2.4 Concurrent lookups share one request** *(rec.)*. At a cold launch the app's `check()` and
the first "became active" notification arrive together. While a lookup is in flight, a second
`updateStatus()` call waits for that lookup's answer instead of starting another. *Rationale:*
the actor is re-entrant across its `await`, so today two callers with an empty cache both go to
the network.

**2.5 Platforms** *(rec.)*. iOS, iPadOS, tvOS and visionOS (including an iPhone or iPad app
running on a Mac) use `UIApplication.didBecomeActiveNotification`; macOS uses
`NSApplication.didBecomeActiveNotification`. watchOS gets no foreground re-check. *Rationale:*
SyLib supports watchOS, but no Syzygy app uses the update check there.

**2.6 Each app adopts in its own session; nothing is removed here** (`00A` §3).
- **Syderal** gets the foreground check with no source change.
- **Sydoku, SyWord and SyFLUX** call `check()` on foreground themselves. Those calls become
  redundant but harmless (one shared request, §2.4, and a 15-minute cache, §2.3). Each app can remove
  its own call when next in focus.
- **SydeTwo and SeedStorm** call `AppUpdateChecker` directly, so they don't get §2.1, but their
  existing foreground and menu checks get the 15-minute cache. Moving them onto `AppUpdateState` is
  not part of this document.

### 2.7 Considered and excluded (do not revisit)

| Item | Why it is out |
|---|---|
| A SyLibUI view modifier (`.checksForAppUpdates(…)`) that each app applies | Pops chose §2.1: every app would have to adopt it |
| No cache on foreground (a fresh lookup on every return) | Pops chose 1 hour, then 15 minutes (§2.3) |
| A public or per-app setting for the interval | Not asked for; one interval for every app |
| A Debug control to force the badge or the interval | The log lines (§5) and unit tests cover it |

---

## 3. Before starting

- `sylib-swift` is on `main` at `a04f831` (or later), clean. SyFive is on `main` at `cff4999`,
  clean.
- Record SyLib's suite total (`00B` §5.3) and SyFive's (`00B` §5.2) before any change.

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 SyLib: foreground re-check, a 1-hour cache, and one request at a time

**Read:** `Sources/SyLibCore/AppStore/AppUpdateState.swift`,
`Sources/SyLibCore/AppStore/AppUpdateChecker.swift`,
`Tests/SyLibTests/SyLibCore/AppStore/AppUpdateStateTests.swift`,
`Tests/SyLibTests/SyLibCore/AppStore/AppUpdateCheckerTests.swift`, `Docs/APP_STORE.md`. Nothing
else.

1. **`AppUpdateChecker`: the interval.** `minimumCheckInterval` becomes `3600` (1 hour), and an
   `internal static let` so a test can read it. Update its doc comments and the type's
   ("Results are cached for 1 hour").

2. **`AppUpdateChecker`: one lookup at a time** (§2.4). Hold the in-flight lookup (for example, a
   stored `Task<(Bool, String?), Never>?`). `updateStatus()` returns the cached answer when it is
   fresh; otherwise it awaits the in-flight lookup if there is one, or starts one, stores it, and
   clears it when it finishes. The cache is written once per lookup, as now. Public API unchanged.

3. **`AppUpdateState`: a test seam for the lookup.** Add an `internal` initialiser
   `init(userDefaults: UserDefaults = .standard, lookup: @escaping @Sendable () async -> (available: Bool, storeVersion: String?))`.
   The public `init(userDefaults:)` calls it with `{ await AppUpdateChecker.shared.updateStatus() }`.
   `check()` calls `lookup()` and then `apply(available:storeVersion:)`, as it does now with the
   checker.

4. **`AppUpdateState`: the foreground re-check** (§2.1, §2.2, §2.5).
   - A private flag records that `check()` has been called at least once. Set it at the start of
     `check()`.
   - An `internal func appBecameActive() async`: when the flag is set, call `check()`; otherwise
     do nothing.
   - In the initialiser, start observing the platform notification in §2.5 and call
     `appBecameActive()` on the main actor when it arrives. The observation holds the instance
     weakly and ends when the instance is deallocated. Guard the platforms with `#if os(…)`;
     watchOS compiles without it.
   - Rewrite the type's doc comment: create one, call `check()` at launch, and it re-checks by
     itself each time the app becomes active (at most one network lookup an hour, through the
     checker). Drop "for one launch".

5. **Tests.** In `AppUpdateStateTests`, using the seam in item 3 with a fake lookup that counts
   its calls and returns a set answer (no network):
   - `aForegroundEventBeforeCheckDoesNothing`: `appBecameActive()` before any `check()`: zero
     lookups, no badge.
   - `aForegroundEventAfterCheckChecksAgain`: `check()` with the fake answering "not available",
     then the fake answers `(true, "2.0")` and `appBecameActive()` runs: two lookups, and
     `showsBadge` is true.
   - `anAcknowledgedVersionStaysHiddenAfterAForegroundCheck`: badge shown for "2.0",
     `acknowledge()`, then `appBecameActive()` with the same answer: `showsBadge` stays false.

   In `AppUpdateCheckerTests`: `theCacheLastsOneHour`: `minimumCheckInterval == 3600`.

   Item 2 has no test: it is on the network path, which has none today. Say so in the report.

6. **`Docs/APP_STORE.md`.**
   - `AppUpdateState`: "call `check()` once at launch" becomes "call `check()` at launch; it
     re-checks by itself each time the app becomes active". Add the foreground rule and §2.2 to the
     Constraints list, with §2.5's platforms.
   - "The 24-hour cache" becomes "The 1-hour cache", and says that concurrent calls share one
     lookup.
   - An adoption note: Sydoku, SyWord and SyFLUX call `check()` on foreground themselves, which is
     now redundant and can be removed in each app's own session. SydeTwo and SeedStorm call the
     checker directly: they get the 1-hour cache, not the foreground re-check.

**Done when:**
- SyLib's suite passes on the pinned destination (`00B` §5.3), at §3's total plus 4.
- Syderal builds against the changed SyLib and its suite passes, with no source edit (`00B` §5.4).
- `swift build` is not used as evidence; the watchOS path is checked by reading, not building.

**Do not:** change `AppUpdateState`'s public API or D-139's acknowledgement rules; open or edit any
app's repository other than building Syderal; add a public interval setting.

### 4.2 SyFive: build against the new SyLib and confirm

**No source change.** SyFive's `ContentView` keeps its `.task { await updateState.check() }`;
SyLib now does the rest.

1. Build SyFive against the changed SyLib (`BuildProject`). No warnings added.
2. Run SyFive's suite (`00B` §5.2): §3's total, unchanged.
3. `project.pbxproj`: add `Docs/SyLib/25_SYLIB_UPDATE_CHECK_ON_FOREGROUND.md` to the app target's
   resource exceptions, beside `24`. No other change.

**Do not:** edit `ContentView.swift` or any other SyFive source.

### 4.3 SyLib: a 15-minute cache, and failures not cached (v1.1)

**Needs §4.1.** On the same SyLib branch, `fg-update`. **Read:**
`Sources/SyLibCore/AppStore/AppUpdateChecker.swift`,
`Tests/SyLibTests/SyLibCore/AppStore/AppUpdateCheckerTests.swift`, `Docs/APP_STORE.md`. Nothing
else.

1. **The interval** (§2.3). `minimumCheckInterval` becomes `900`. Every "1 hour" in the type's doc
   comments becomes "15 minutes".

2. **Failures are not cached** (§2.8). In `updateStatus()`, after the lookup: when its
   `storeVersion` is non-nil, write `cachedResult`, `cachedStoreVersion` and `lastCheckTime` as
   now; when it is nil, write none of them. Either way, clear `inFlightLookup` and return the
   lookup's answer. Callers waiting on the in-flight lookup get the same answer, as now. Say in
   `updateStatus()`'s doc comment that a failed lookup is not cached.

3. **A test seam for the lookup.** Add an `internal init(lookup: @escaping @Sendable () async -> (Bool, String?))`
   that `updateStatus()` calls in place of `performUpdateCheck()`. `shared` stays
   `AppUpdateChecker()`, whose lookup is `performUpdateCheck()`; there is still no public
   initialiser. Keep the change as small as the actor allows (for example, a stored closure that
   the private `init()` sets to the network lookup).

4. **Tests**, in `AppUpdateCheckerTests`, through item 3 with a fake that counts its calls (no
   network):
   - `theCacheLastsOneHour` is renamed `theCacheLastsFifteenMinutes` and expects `900`.
   - `aSuccessfulLookupIsCached`: the fake answers `(true, "2.0")`; two `updateStatus()` calls make
     one lookup, and both return `(true, "2.0")`.
   - `aFailedLookupIsNotCached`: the fake answers `(false, nil)`, then `(true, "2.0")`; the first
     call returns `(false, nil)`, the second makes a second lookup and returns `(true, "2.0")`.
   - `concurrentCallsShareOneLookup`: a fake that suspends until released; start two
     `updateStatus()` calls, release it, and both return its answer after one lookup. If the test
     cannot be made deterministic, leave it out and say so in the report.

5. **`Docs/APP_STORE.md`.** "The 1-hour cache" becomes "The 15-minute cache", and every "1 hour"
   or "an hour" in the `AppUpdateState` and `AppUpdateChecker` sections becomes "15 minutes". The
   bullet "A failed lookup is cached like any other answer…" becomes: a failed lookup is not
   cached, so the next call (a later `check()`, or the app becoming active again) tries again.
   The Adoption note's "1-hour cache" becomes "15-minute cache".

**Done when:**
- SyLib's suite passes on the pinned destination (`00B` §5.3), at §4.1's total plus 3 (or plus 2
  without the concurrency test).
- Syderal builds against the changed SyLib and its suite passes, with no source edit
  (`00B` §5.4).
- SyFive builds (`BuildProject`) and its suite passes, unchanged.

**Do not:** change `AppUpdateState`, the public API, or any app's source; cache a failed lookup
for any length of time; add retries or backoff.

---

## 5. Validation

| ID | After | Check | Expect |
|---|---|---|---|
| U1 | 4.2 | **Pops, device or Simulator, Debug build, Xcode console filtered to `AppUpdateChecker`.** Launch SyFive | One "Store version: … vs Current: …" line: one network lookup, even though `check()` and the first "became active" arrive together (§2.4) |
| U2 | 4.2 | Send SyFive to the background and bring it back, within the hour | A "Returning cached result" line: the foreground check ran, and the cache answered |
| U3 | 4.3 | Bring it back after more than 15 minutes in the background (no relaunch) | A new "Store version: …" line: a fresh lookup |
| U5 | 4.3 | Turn on Airplane Mode and launch SyFive. Turn Airplane Mode off, then send SyFive to the background and bring it back | At launch, an "Update check failed" line. On return, a new "Store version: …" line at once, with no "Returning cached result" |
| U4 | Next SyFive release | Leave the previous version running in the background. After the new version is live in the store, bring the app back more than 15 minutes after its last lookup | The menu badge appears without a relaunch; Update Available is in the menu |

---

## 6. Open decisions

None. §2.2, §2.4 and §2.5 are Claude's recommendations, accepted with Pops's rulings on the
mechanism (§2.1), the interval (§2.3) and failures (§2.8). Pops may change any of them before
the task runs.

---

## 7. Ledger row

New row, under **Platform & data**, after D-139.

| ID | Current ruling | Source → chain |
|---|---|---|
| D-154 | **The update check re-runs on each return to the foreground.** SyLibCore's `AppUpdateState` observes the app becoming active and re-checks by itself, once the app has called `check()`; SyFive keeps its one launch `check()` and has no foreground code of its own. `AppUpdateChecker` reuses a successful lookup for **15 minutes** (was 24 hours), **never caches a failed one**, and concurrent calls share one request. Other apps adopt in their own sessions. | `25` §2 (Pops, 28 Oct 2026: SyLib mechanism; 1 hour, then 15 minutes; failures not cached; the rest *(rec.)*) |

---

## 8. Close-out (Claude, directly)

- Ledger: D-154 as §7.
- `IMPLEMENTATION_STATUS.md`: wherever the update badge is described, add that it re-checks on
  foreground, at most one lookup every 15 minutes (D-154).

---

## 9. Results log

| Item | Value |
|---|---|
| §4.1 | **Built 28 Oct 2026**, on SyLib branch `fg-update` (uncommitted at review). Reviewed by Claude at source: matches items 1–6. `minimumCheckInterval` is an internal `static let` of 3600. `updateStatus()` returns a fresh cache, else awaits `inFlightLookup` if set, else starts it, caches its answer and clears it. `AppUpdateState`: the public `init(userDefaults:)` is now a `convenience` init over the internal `init(userDefaults:lookup:)` (source-compatible); `hasChecked` is set at the start of `check()`; `appBecameActive()` guards on it. The observer is block-based on `.main`, holds `self` weakly, and its token lives in a private `NotificationObservers` box that removes it in its own `deinit`. Platforms as §2.5. Four tests as item 5 (three `AppUpdateState`, one `AppUpdateChecker`), through a `FakeLookup` actor; no network. `APP_STORE.md` as item 6, with an Adoption note. Suite totals (iPhone SE (3rd generation), iOS 18.6): SyLib 1323 → **1327** (§3's + 4); Syderal **955**, unchanged |
| §4.2 | **Built 28 Oct 2026**, on SyFive branch `fg-update`. No source change. `project.pbxproj`: `25` added to the resource exceptions beside `24`; `MARKETING_VERSION` is also now 1.1.3 in both configurations (Pops's own bump, not this task). Suite total: SyFive **22**, unchanged (iPhone SE (3rd generation), iOS 18.6) |
| U1 | **Pass** (Pops, 28 Oct 2026). One lookup at launch |
| U2 | **Pass** (Pops, 28 Oct 2026). A cached answer on return within the hour |
| §4.3 | **Built 28 Oct 2026**, on SyLib branch `fg-update`. `minimumCheckInterval` is 900. `updateStatus()` writes the cache only when the lookup's `storeVersion` is non-nil, and clears `inFlightLookup` either way. Seam: an internal `init(lookup:)`. The private `init()` passes it `performUpdateCheck()`, now `private static` because it reads no instance state. Tests: `theCacheLastsOneHour` renamed `theCacheLastsFifteenMinutes`, plus `aSuccessfulLookupIsCached`, `aFailedLookupIsNotCached` and `concurrentCallsShareOneLookup`. The concurrency test passed 20 of 20 separate runs. With the in-flight branch disabled, it failed in every run. `APP_STORE.md` as item 5. Suite totals (iPhone SE (3rd generation), iOS 18.6): SyLib 1327 → **1330** (§4.1's + 3); Syderal **955**; SyFive **22** |
| U3 | **Pass** (Pops, 28 Oct 2026). A fresh lookup on return after 15 minutes, with no relaunch; cached answers before it |
| U5 | **Pass** (Pops, 28 Oct 2026, device; accepted by Claude at close-out). Offline: two consecutive "Update check failed" lines, each a fresh lookup, so a failure is not cached. The reconnect step was not seen live, because Xcode's wireless debugging drops in Airplane Mode; it is the same path, and `aFailedLookupIsNotCached` proves a failure followed by a successful lookup |
| U4 | Pending: next SyFive release |
| Ledger and status | D-154 pasted under Platform & data after D-139, as §7 (Claude, 28 Oct 2026); rewritten for v1.1 (15 minutes, failures not cached) the same day. `IMPLEMENTATION_STATUS.md` does not describe the update badge, so it is unchanged |

**Review note (Claude, 28 Oct 2026).** §2.2 earns its place beyond previews and tests: SwiftUI evaluates `@State var updateState = AppUpdateState()` on every `ContentView` init and discards all but the first, and each discarded instance now registers an observer. They never call `check()`, so they never make a request, and their observers are removed when they are released.

**Close-out review, 28 October 2026 (Claude, at source: SyLib and SyFive on `fg-update`, uncommitted).** §4.3 matches items 1–5. `minimumCheckInterval` is 900. `updateStatus()` caches only when the lookup's `storeVersion` is non-nil and clears `inFlightLookup` either way. The internal `init(lookup:)` is the only new initialiser: `shared` still uses the private `init()`, and the public API is unchanged. `performUpdateCheck()` became `private static`, which is harmless because it reads no instance state. `concurrentCallsShareOneLookup` waits for its second call with a fixed number of yields. If the second call ran late it would hit the cache and pass, so the test could pass wrongly but never fail wrongly. The agent's run with the in-flight branch disabled, which failed every time, shows the test does catch a regression. `APP_STORE.md` has no "hour" left in the `AppUpdateState` or `AppUpdateChecker` sections. D-154 in the ledger matches §7 v1.1. `IMPLEMENTATION_STATUS.md` is unchanged (§8). **Ship order:** merge SyLib `fg-update` before archiving SyFive. A running app gets the foreground check only from the first build that includes it, so U4 is the release after that build. This document is **Closed**.
