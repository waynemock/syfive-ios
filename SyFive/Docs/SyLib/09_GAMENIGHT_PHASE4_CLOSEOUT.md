# Game Night Phase 4 — document, test, close out

The extraction is finished. This phase makes `SyLibGameNight` adoptable by a
second app and closes the loose ends left behind by Phases 1–3.

No code moves. Four independent workstreams — do them in this order, but any of
them can be skipped without blocking the others.

**Scope:** `sylib-swift` and `SyFive`.

---

## 1. `Docs/GameNight.md` — the main deliverable

`Docs/` has twelve files and none for Game Night. This one needs more than the
others got, and it's worth being explicit about why.

Adopting `SyLibDice` is "hold a `DiceRoller`, place a `DiceTrayView`." Adopting
`SyLibGameNight` is: declare a `GroupActivity` with your own identifier, choose a
`keyPrefix`, set an `appProtocolVersion`, define your own message kinds and
payloads, install `onAppMessage` and `onTableStateReceived`, map your roster to
`SeatRosterEntry`, and fill two `@ViewBuilder` slots. **None of that is
discoverable from the API surface.**

So this document is a walkthrough first and a reference second — the reverse of
the other module docs.

### Format

Follow `Docs/Cache.md` for the house style: `**Module:**` lines, terse prose,
copy-pasteable snippets with real argument labels. Verify every label against the
source; do not write them from memory.

### Required structure

**Opening — what this is.** One paragraph. A SharePlay session layer for
turn-based games: sessions, seats, envelopes, and explaining SharePlay to a
confused human. It knows nothing about matches, scores, or rosters.

**"Adding Game Night to an app" — the integration walkthrough.** Six steps,
each with a working snippet:

1. **Declare your activity.** Your own `GroupActivity` conformer with your own
   `activityIdentifier` and metadata title. State plainly *why* the package
   doesn't own this: `activityIdentifier` is a `static let`, and a shared one
   would let a player from one app be offered a seat at another app's table.
2. **Create the session.**
   `GameNightSession<YourActivity>(keyPrefix:appProtocolVersion:)`. Explain both
   arguments — `keyPrefix` namespaces `UserDefaults` so two Syzygy apps on one
   device don't collide, and `appProtocolVersion` is your message schema version,
   independent of the package's transport version.
3. **Define your message kinds and payloads.** A `String`-backed enum of your
   own; the package owns only `hello`, `tableState`, `seatClaim`, `seatRelease`.
   Show the `send` convenience extension pattern SyFive uses
   (`App/GameNight/Protocol/GameNightEnvelope.swift`) so `.yourKind` syntax works.
4. **Install the hooks.** `onAppMessage`, `onTableStateReceived`, `onTearDown`,
   `onNeedsMatchStateBroadcast`, `appSettingsProvider`. Say what each is for and
   when it fires.
5. **Build the seating screen.** `GameNightTableView` with `seatColor`,
   `appSettings`, and `seatTrailing`. Note that it renders `List` content only —
   no `NavigationStack`, no toolbar.
6. **Wire the roster.** Map your player type to `SeatRosterEntry`, and note that
   `accentColor` is resolved by the app because the package has no theme system.

**Point at SyFive as the worked example.** `GameNightScreens.swift` is a
complete reference implementation of steps 5 and 6, and
`GameNightController.swift` of steps 3 and 4. Name both files.

**Reference sections** for `GameNightSession`, the protocol types, and the views
— shorter, since the walkthrough carries the weight.

### Things that must appear somewhere

- **Two version numbers.** Transport (`GameNightEnvelope.currentProtocolVersion`,
  owned by the package) and app (`appProtocolVersion`, owned by you). Bump yours
  when your payloads change shape; a transport bump invalidates everyone. Both
  are checked at `hello` and rejection follows the same path.
- **`VersionMismatchKind` matters.** A mismatched version is only comparable
  against the corresponding current value. Comparing an app version against the
  transport version produces confidently wrong advice — this was a real bug.
- **The three `UserDefaults` keys** and what each preserves: host role across
  relaunch, guest participant identity, host-reconnect offer. Note that changing
  `keyPrefix` after shipping orphans in-flight sessions.
- **`GameNightLogBuffer` writes to a shared `gnlogs/` directory.** See §3.
- **Platform:** iOS only. GroupActivities is unavailable on watchOS; tvOS is
  untested and the views assume touch.
- **A pointer to `GameNight-Behavior-Inventory.md`** as the test suite, with the
  note that GroupActivities cannot be unit tested.

### README

Add the `SyLibGameNight` row to the components table, and its commented line to
the Installation snippet. Both currently stop at `SyLibScoringData`.

---

## 2. Tests

`SyLibGameNight` is in the test target's dependencies and has no tests. Three
areas are pure functions and worth covering. **Do not attempt to test session
lifecycle, seat claiming, or anything requiring a `GroupSession`** — that is what
the behaviour inventory is for.

Add `Tests/SyLibTests/SyLibGameNight/`:

**`GameNightEnvelopeTests`**
- Round-trip: encode a payload via `init(kind:payload:)`, decode with
  `decode(_:)`, values survive.
- Both `init` overloads (`GameNightSessionKind` and `String`) produce identical
  envelopes for the same kind string.
- `sessionKind` returns the case for the four owned kinds and `nil` for an
  unrecognised string — this is inventory 5.2's forward-compatibility guarantee.
- `isCurrentProtocolVersion` is true at 2, false at 1 and 3.

**`TableStatePayloadTests`**
- Round-trips with `appSettings` populated and `nil`.
- Decodes successfully when `protocolVersion` is absent — the field is `Int?`
  precisely so an older host's payload still decodes.
- `appSettings` survives as opaque bytes; the package never interprets it.

**`VersionComparisonTests`** — the highest-value suite, because this logic was
wrong once already.
- A transport mismatch and an app mismatch at the *same numeric value* select
  different current-version comparisons.
- The direction is correct in both branches: lower means "they should update,"
  higher means "we should update."
- Cover the case that was broken: app versions 3 vs 4 with transport matched at
  2. Before the fix this compared 3 against 2 and told the wrong device to
  update.

---

## 3. Cleanup

**`.DS_Store` is committed** at `Sources/SyLibGameNight/.DS_Store`, and
`.gitignore` in neither repo covers it. Add `.DS_Store` to both, and
`git rm --cached` the one already tracked.

**Two files share a name across modules.** Neither matches its contents:

| Path | Contains | Rename to |
|---|---|---|
| `SyLibGameNight/Views/GameNightSharingSheet.swift` | `GameNightPendingSheet`, `GameNightInviteInstructions` | `GameNightSharingViews.swift` |
| `SyFive/App/GameNight/Views/GameNightSharingSheet.swift` | `GameNightSharing` enum | `GameNightSharing.swift` |

**Consider moving `GameNightSharing` into the package.** It contains no SyFive
references — grep confirms zero hits for `SyFive`, `Yatzy`, or `Match`. It is
`GroupActivitySharingController` presentation plus the dev-build sandbox
auto-dismiss detection, and that detection is exactly the kind of hard-won
knowledge Sideral would otherwise rediscover from scratch. Its doc comment
explains that the people-picker XPC extension is sandbox-restricted in dev builds
so the controller auto-dismisses with `.cancelled`, detected via elapsed time.

The one thing to check before moving it: whether presenting from "the topmost
`UIViewController`" makes assumptions about SyFive's window structure. If it
does, leave it and say so. If it doesn't, move it — it belongs next to
`GameNightPendingSheet` and `GameNightInviteInstructions`, which it drives.

**`gnlogs/` is shared between apps.** `GameNightLogBuffer` writes to
`<Documents>/gnlogs/`, and filenames are match UUIDs so collisions are not a
practical risk. But two apps writing to one directory means one app's log export
could list another's files.

Decide now rather than after Sideral exists: either add the `keyPrefix` to the
directory path (`gnlogs/<prefix>/`), or document the sharing as intentional. **I'd
add the prefix** — it is a one-line change now and a migration later, and
`hasLog(for:)` returning true for another app's match would be a confusing bug to
chase. If you add it, `GameNightLogBuffer` needs the prefix, which means it stops
being a bare singleton — check that against its five call sites in SyFive first.

---

## 4. Sign-off

The module has stopped moving, so this is the moment the inventory is worth
completing.

Run all 27 entries of `GameNight-Behavior-Inventory.md` against the final shape,
on two physical devices, and fill in the sign-off table with dates.

This becomes the baseline Sideral is checked against — a behaviour that works in
SyFive and not in Sideral is then a Sideral integration bug rather than an open
question about the module.

Priority if you can't do all 27 in one sitting: **2.1** (host survives
force-quit), **4.2** and **4.3** (the Messages-join dead end), **3.1** and **3.2**
(audio interruption), **7.2** (rematch doesn't overwrite history). Those are the
six that were expensive to get right and have no error path when they break.

---

## 5. Definition of done

- [ ] `Docs/GameNight.md` written, walkthrough-first, every snippet's argument
      labels verified against source.
- [ ] README components table and Installation snippet include `SyLibGameNight`.
- [ ] Three test suites added; `swift test` green.
- [ ] `.DS_Store` untracked and ignored in both repos.
- [ ] Both sharing files renamed to match their contents.
- [ ] `GameNightSharing` either moved to the package or left with a stated reason.
- [ ] `gnlogs/` prefixing decided and implemented or documented.
- [ ] All 27 inventory entries verified; sign-off table filled in with dates.
