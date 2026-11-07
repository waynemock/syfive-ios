# `SyLibCommentary` — extraction brief

Extract SyFive's commentary engine, tier model, and settings UI into a shared
package target so Sideral and future games inherit them.

**Scope:** `sylib-swift` (new target) and `SyFive`.

Decisions already made — do not revisit:
- **Token model: dictionary** (`tokens: [String: String]`), not the current eight
  typed fields.
- **Views: all three move**, including `CommentarySettingsView`.
- **`keyPrefix` on any `UserDefaults` key that enters the package.** Standing
  rule, applies here without asking.
- **The three-tier model ships as-is.** See §8.
- **The Game Night relay stays as-is.** See §9.

---

## ⚠️ What must not change

The four packs are SyFive's voice and the reason commentary is fun. **No line
text changes.** `{player}` stays `{player}`; only the mechanism that substitutes
it moves.

No behaviour changes: same lines for the same events, same tier interrupts, same
level gating, same voice, same prosody. If something looks wrong, report it.

---

## 1. Target

```swift
.library(name: "SyLibCommentary", targets: ["SyLibCommentary"]),

.target(name: "SyLibCommentary"),      // Foundation, AVFoundation, SwiftUI, UIKit
```

**No dependencies.** The engine uses no `AppLogger` (grep confirms zero uses), so
it needs neither `SyLibCore` nor anything else.

⚠️ `CommentaryEngine.swift:4` has `import SyLibFeel`, which exists only to support
a *comment* on line 30 about not interrupting `FeelAudioEngine`'s audio session.
Delete the import; keep the comment. If the build then fails, something real is
using it — stop and report.

Guard the module `#if os(iOS)` — `AddVoicesSheet` uses UIKit for a Settings deep
link.

Add `"SyLibCommentary"` to the `SyLibTests` target dependencies.

---

## 2. Step 1 — move the value types

No generics yet, no behaviour change. Move to `Sources/SyLibCommentary/`:

| Type | From | Notes |
|---|---|---|
| `CommentaryEventTier` | `CommentaryEvent.swift` | celebration/highlight/playByPlay, `Comparable` |
| `CommentaryLevel` | `CommentaryLevel.swift` | The level gate |
| `CommentaryProsody` | `CommentaryPersonality.swift` | rate, pitch, pre/post delay |
| `CommentaryMode` | `Persistence/Models/AppSettingsModel.swift:28` | allGames/gameNightOnly/off |
| `CommentaryPayload` | `App/GameNight/Protocol/GameNightPayloads.swift:109` | text + tierRaw |

All `public`, with public memberwise inits.

**`CommentaryMode` moves but its storage does not.** `AppSettingsModel` keeps
`commentaryModeRaw: String` and stays app-side — same treatment `AppSoundMode`
got in the Feel wave.

**`CommentaryPayload` leaves `SyLibGameNight` entirely.** It references
`CommentaryEventTier`, so it belongs here. `SyLibGameNight` stays ignorant of
commentary; SyFive keeps sending it as an app message kind, which already works
and needs no change.

**✅ C1:** both repos build, commentary behaves identically.

---

## 3. Step 2 — generic engine and dictionary tokens

The risky step. Do it in one commit so the two halves land together.

### 3.1 The event-kind protocol

```swift
public protocol CommentaryEventKind: Hashable, Sendable {
    var tier: CommentaryEventTier { get }
}
```

SyFive's existing `CommentaryEventKind` enum conforms **unchanged** — it already
has `var tier`. It keeps its name and stays app-side; the protocol and the enum
sharing a name across modules is fine and reads correctly at the conformance.

### 3.2 Dictionary tokens

```swift
public struct CommentaryEvent<Kind: CommentaryEventKind>: Sendable {
    public let kind: Kind
    public let tokens: [String: String]

    public init(kind: Kind, tokens: [String: String] = [:])
}
```

`fillTokens` becomes vocabulary-agnostic:

```swift
private func fillTokens(_ line: String, with event: CommentaryEvent<Kind>) -> String {
    event.tokens.reduce(line) { partial, pair in
        partial.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
    }
}
```

⚠️ **Add a debug guard for unsubstituted tokens.** The dictionary trades away the
compiler, and the failure mode is a line shipping with `{player}` read aloud.
After substitution, in `#if DEBUG`, assert that no `{…}` remains:

```swift
assertionFailure("Unsubstituted token in commentary line: \(result)")
```

This is the safety net for the whole decision — do not skip it.

### 3.3 Typed constructors stay app-side

There are **13** `CommentaryEvent(...)` construction sites, 11 of them in
`Session/MatchController.swift:650–689`. Do not convert them to raw dictionary
literals at the call site — that is where typos would land.

Add an app-side extension so call sites stay typed:

```swift
// SyFive: App/Commentary/CommentaryEvent+SyFive.swift
extension CommentaryEvent where Kind == CommentaryEventKind {
    static func scored(player: String, category: String, value: Int) -> Self {
        .init(kind: .categoryScored,
              tokens: ["player": player, "category": category, "value": "\(value)"])
    }
    // …one per event kind actually constructed
}
```

Call sites become `sink(.scored(player: name, category: cat.displayName, value: v))`.
Only these constructors know SyFive's token vocabulary, and they are the only
place a token name is spelled.

### 3.4 Generic personality and engine

```swift
public struct CommentaryPersonality<Kind: CommentaryEventKind>: Sendable {
    public let id: String
    public let displayName: String
    public let blurb: String
    public let prosody: CommentaryProsody
    public let previewLine: String
    public let lines: [Kind: [String]]
}

@MainActor
public final class CommentaryEngine<Kind: CommentaryEventKind>: NSObject, AVSpeechSynthesizerDelegate {
    public init(personality: CommentaryPersonality<Kind>,
                voice: AVSpeechSynthesisVoice?,
                level: CommentaryLevel)
    public func update(personality: CommentaryPersonality<Kind>,
                       voice: AVSpeechSynthesisVoice?,
                       level: CommentaryLevel)
    public func handle(_ event: CommentaryEvent<Kind>)
    public func receiveText(_ text: String, tier: CommentaryEventTier)
    public func preview()
    public func stopSpeaking()
    public var isMuted: Bool
    public var onWillSpeak: ((String, CommentaryEventTier) -> Void)?
}
```

Preserve exactly: the no-repeat shuffle (`remainingIndices` / `lastUsedIndex`),
the tier-based interrupt in `speak`, `passesLevelGate`, and the
`speechSynthesizer(_:didFinish:)` handling. These are the behaviour.

The four packs become `CommentaryPersonality<CommentaryEventKind>` values.
`CommentaryPersonality.all` and `find(id:)` stay in SyFive with the packs.

**✅ C2 — the commentary checklist.** Before starting this step, write down what
"works" means for each of the eleven event kinds. Afterwards, trigger each one in
a real game and tick it off. "It seemed to talk" is not a check.

| Kind | How to trigger | Expect |
|---|---|---|
| `turnStart` | Any turn begins | Player-name line, playByPlay tier |
| `categoryScored` | Score any category | Line names player, category, value |
| `categoryScratched` | Zero any category | Line names player and category |
| `bigTurn` | High-value category | Distinct from `categoryScored` |
| `yatzyRolled` | Roll a Yatzy | Celebration tier, interrupts |
| `yatzyBonusEarned` | Second Yatzy | Celebration tier |
| `yatzyScratched` | Zero the Yatzy box | Highlight tier |
| `upperBonusEarned` | Upper section ≥ 63 | Highlight tier |
| `leadChange` | Lead changes hands | Names new leader |
| `winnerDeclared` | Finish a match | Names winner and score |
| `winnerTie` | Finish tied | Names both, no runner-up token |

Run the list on all four packs at least once between them, and confirm no line
speaks a literal `{token}`.

---

## 4. Step 3 — the views

All three move. Each takes `accentColor: Color` in place of
`@Environment(\.theme)` — same treatment as the Game Night sheets.

### 4.1 `VoicePickerView` (173) and `AddVoicesSheet` (76)

`AVFoundation` plus theme and `@Environment(\.dismiss)`. No Yatzy, no SwiftData,
no `MatchController`. Straight moves.

```swift
public struct VoicePickerView<Kind: CommentaryEventKind>: View {
    public init(personality: CommentaryPersonality<Kind>,
                selectedVoiceID: Binding<String?>,
                accentColor: Color)
}

public struct AddVoicesSheet: View {
    public init(accentColor: Color)
}
```

`AddVoicesSheet` is not generic — it has no personality reference.

### 4.2 `CommentarySettingsView` (186)

Reads and writes `AppSettingsModel` at three sites via SwiftData. That model
stays in SyFive.

```swift
public struct CommentarySettingsView<Kind: CommentaryEventKind>: View {
    public init(
        personalities: [CommentaryPersonality<Kind>],
        selectedPersonalityID: Binding<String>,
        level: Binding<CommentaryLevel>,
        mode: Binding<CommentaryMode>,
        voiceID: Binding<String?>,
        accentColor: Color,
        onPreview: @escaping (CommentaryPersonality<Kind>) -> Void
    )
}
```

The view holds no storage. SyFive binds each argument to `AppSettingsModel` in a
thin wrapper, following the `GameNightScreens.swift` pattern — put it in
`App/Commentary/CommentaryScreens.swift`.

`onPreview` exists because previewing a personality needs an engine, and the
engine's lifecycle is owned by `ContentView+Commentary.swift`. Do not construct
an engine inside the view.

### 4.3 Voice ID storage

`UserDefaults.commentaryVoiceID` is read at `ContentView+Commentary.swift:42`.

Per the standing rule, if it moves into the package it gets a prefix. **The
simplest correct answer here is that it does not move** — voice ID is a
`Binding<String?>` on the settings view, and SyFive persists it however it
likes. Keep the key app-side and pass the value in.

If you find a reason the package must own it, use
`"\(keyPrefix).commentary.voiceID"` with `keyPrefix` supplied by the app, and say
in your report why it was necessary.

**✅ C3:** settings screen renders identically; changing personality, level, mode,
and voice all still take effect; voice preview still speaks.

---

## 5. Step 4 — tests

`Tests/SyLibTests/SyLibCommentary/`. Everything here is a pure function except
the speech itself.

- **Token substitution.** Multiple tokens in one line; a token appearing twice;
  a token absent from the dictionary is left intact; empty dictionary returns the
  line unchanged.
- **No-repeat selection.** With a pool of N lines, N successive selections return
  all N before any repeats.
- **Level gate.** `passesLevelGate` admits the right tiers for each
  `CommentaryLevel`.
- **Tier ordering.** `celebration < highlight < playByPlay`.
- **`CommentaryPayload`** round-trips through JSON.

Use a small test-only `enum TestEventKind: CommentaryEventKind` fixture so the
package tests don't depend on SyFive's packs.

---

## 6. Step 5 — docs

`Docs/Commentary.md`, following the `Docs/Cache.md` format, with a short
integration walkthrough: define your event kinds, write a personality, construct
typed events, own the engine's lifecycle, present the settings view.

State plainly that the token vocabulary is app-defined and that the debug
assertion catches unsubstituted tokens.

Add the `SyLibCommentary` row to the README components table and its commented
line to the Installation snippet.

---

## 8. Known risk — the tier model is a one-consumer guess

`CommentaryEventTier` has three cases and `CommentaryLevel` has three matching
settings. `passesLevelGate` binds them tightly:

```swift
case .celebrations: return tier == .celebration
case .highlights:   return tier <= .highlight
case .playByPlay:   return true
```

That is not just a priority ordering — it is an **interrupt policy**. A
`celebration` cuts off a `playByPlay` mid-sentence, and the level gate decides
which tiers speak at all.

Three tiers map well onto Yatzy because turns are discrete and a Yatzy is
unambiguously bigger than a category score. **Sideral's commentary is not yet
designed**, so whether the same arbitration suits a game where pieces move
constantly is unknown.

Ship it as-is — designing an arbitration model against zero consumers is worse
than shipping the one that works. But know what it costs to change:

- `CommentaryEventTier` and `CommentaryLevel` are public enums. Adding a case is
  source-breaking for exhaustive `switch`es in consumers. Since the consumers are
  Syzygy apps, that is a compile error to fix, not a shipped break.
- The two enums must change together. A fourth tier means a fourth level, a new
  gate case, and a migration for every persisted `commentaryLevelRaw`.
- The natural escape hatch, if it comes to it, is making the gate and the
  interrupt policy injectable rather than adding tiers. **Do not build that now.**

Keep `passesLevelGate` and the interrupt check in `speak` adjacent and commented
as a pair, so whoever revisits this finds both.

## 9. The Game Night relay is intentional

Confirmed behaviour, not an accident — document it, do not "fix" it.

The host generates commentary locally and relays the resulting **text** to guests
via `CommentaryPayload`; guests speak it verbatim through
`receiveText(_:tier:)`. Guests never run line selection.

Consequences, all deliberate:

- Guests need no packs, and cannot drift from the host's wording.
- **The host's personality choice is the whole table's voice.**
- `ContentView+Commentary.swift` forces guests to `.playByPlay` with a nil local
  event sink, so the level gate does not double-filter text the host already
  chose to send.

`receiveText(_:tier:)` is therefore load-bearing and must stay public. Preserve
the guest-side forcing exactly; it looks like a bug and is not.

### The boundary: table-scoped vs device-local

The governing principle is **"the host's table, the host's experience"** — the
same rule that already gives the host seat authority, match start, rematch, and
session end. Commentary personality is that rule applied to a preference rather
than a control, and it is deliberate: Game Night exists to share an experience,
so everyone hears the same commentator saying the same words.

But it stops at *what is said*, not *how it reaches the ear*:

| Table-scoped — host decides, relayed | Device-local — each player decides |
|---|---|
| Personality (which pack) | Voice (`AVSpeechSynthesisVoice`) |
| Level (which tiers speak) | Mute (`isMuted`, from `soundMode`) |
| The line text itself | Volume, output routing |

`GameNightPayloads.swift:107` already documents the voice half: guests speak the
relayed text using their **local** voice. `isMuted` is set from the local
`director.soundMode` at `ContentView+Commentary.swift:58` and `:81`.

This split is currently implicit in the code. **Make it explicit in
`Docs/Commentary.md`**, because a device-local setting is the accessibility path
— someone using a specific speech voice, or playing muted, must keep that during
Game Night — and "unifying" it later would look like a consistency improvement.

---

## 7. Definition of done

- [ ] `SyLibCommentary` target and product; no dependencies; `#if os(iOS)`.
- [ ] `import SyLibFeel` removed from the engine, comment kept.
- [ ] `CommentaryPayload` out of `SyLibGameNight`; that module has no commentary
      references.
- [ ] Engine and personality generic over `Kind: CommentaryEventKind`.
- [ ] `CommentaryEvent.tokens` is `[String: String]`; debug assertion for
      unsubstituted tokens present.
- [ ] All 13 construction sites go through app-side typed constructors.
- [ ] Zero references to Yatzy, `MatchController`, `AppSettingsModel`, SwiftData,
      or `Theme` in the package.
- [ ] Four packs unchanged in line text.
- [ ] All eleven event kinds verified in a real game across all four packs; no
      literal `{token}` spoken.
- [ ] Tests added; `swift test` green.
- [ ] `Docs/Commentary.md` and README updated.
- [ ] `receiveText(_:tier:)` still public; guest-side `.playByPlay` forcing
      preserved and commented.
- [ ] Report: anything that resisted the generic parameter, and whether the debug
      assertion fired during testing.
