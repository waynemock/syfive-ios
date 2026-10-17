# SyLib `CommentarySettingsRows`: the Settings commentary summary with Preview, shared

**Status:** Ready for the agent once `19` is complete. Written 11 October 2026.

**Scope:** `sylib-swift` on branch `syfive-reintegration` (§4.1) and `SyFive` (§4.2). Ships in 1.1.0.
Syderal adopts the component in its `24_SYLIB_FROM_SYFIVE.md`, Task 24.4, not from here
(`00B` §5.4).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document.

---

## Supersessions

None. SyFive's Settings commentary row has no earlier design ruling. It changes on Pops's
direction, 11 October 2026.

---

## 1. Why

Both apps' Settings screens open the same shared Commentary screen, SyLib's `CommentarySettingsView`,
which each wraps in its own `CommentaryScreen`. The row that leads there differs:

- **Syderal** (`UI/SettingsView.swift` 41-71) shows four lines (Mode, Level, Commentator, and the
  voice in use, via `CommentaryVoices`) and a Preview button under them. Preview speaks the
  commentator's preview line in that voice, through SyLib's `PreviewSpeaker`; a second tap stops it.
- **SyFive** (`Views/SettingsView.swift` 69-74) shows one line, "Commentary" followed by the mode, and
  no Preview.

Pops wants SyFive to have Syderal's row, built once in SyLib.

---

## 2. Locked decisions

**2.1 SyLibCommentary gains `CommentarySettingsRows`** (D-146). It draws the summary link and the
Preview button, as Syderal's code draws them today. The app supplies the values, the accent and the
link's destination. The section header, the Commentary screen and anything else in the section
stay app-owned. *Rationale:* §1.

**2.2 The personality line's label is a parameter, defaulting to "Personality"**, so each row
matches its own Commentary screen: SyFive's says Personality, Syderal's says Commentator. Pops, 11
October 2026.

**2.3 All four lines and Preview show whatever the mode**, Off included. A player can hear a
personality before turning commentary on. Pops, 11 October 2026.

**2.4 Leaving the row stops a preview.** When the row disappears, for example as the Commentary
screen is pushed, a preview that is speaking stops, so it doesn't talk over that screen's own
Preview. This needs one additive SyLib method, `PreviewSpeaker.stop()`. Pops, 11 October 2026.

**2.5 The voice line names the voice in use**, from `CommentaryVoices.voiceInUse`, and shows "…"
until the voice scan lands. That is the same voice the Commentary screen's Voice row names
(`17` §4.6).

---

## 3. Before starting

- `19` is complete.
- `Views/SettingsView.swift`'s settings form already has `CommentaryVoices` in its environment
  (`17` §4.6, step 4). Confirm it, and stop if it doesn't (`00A` §4).

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 SyLib: `CommentarySettingsRows`, and `PreviewSpeaker.stop()`

**1. `PreviewSpeaker.stop()`.** File: `Sources/SyLibCommentary/Views/PreviewSpeaker.swift`. Add:

```swift
/// Stops a preview that is speaking. Safe when nothing is speaking.
public func stop() {
    guard synthesizer.isSpeaking else { return }
    synthesizer.stopSpeaking(at: .immediate)
    isSpeaking = false
}
```

`preview(line:prosody:voiceID:)` is unchanged, including its tap-again-to-stop behaviour.

**2. The rows.** New file: `Sources/SyLibCommentary/Views/CommentarySettingsRows.swift`, inside
`#if os(iOS)` like `PreviewSpeaker`.

```swift
/// Rows for an app's Settings commentary section: a link showing the current Mode, Level,
/// personality and voice, and a Preview button that speaks the personality's preview line in
/// that voice. Place inside a `Section`; the app supplies the header.
public struct CommentarySettingsRows<Kind: CommentaryEventKind, Destination: View>: View {
    public init(mode: CommentaryMode,
                level: CommentaryLevel,
                personality: CommentaryPersonality<Kind>,
                voice: CommentaryVoices.Voice?,
                personalityTitle: String = "Personality",
                accentColor: Color,
                @ViewBuilder destination: () -> Destination)
}
```

**Body,** as Syderal's rows draw today (`UI/SettingsView.swift` 43-71):
- A `NavigationLink` to `destination`, whose label is a `VStack(alignment: .leading, spacing: 6)` of
  four `LabeledContent` lines, in this order:
  - `"Mode"`: `mode.displayName`
  - `"Level"`: `level.displayName`
  - `personalityTitle`: `personality.displayName`
  - `"Voice"`: `voice?.name ?? "\u{2026}"`
- A `Button` whose action is `speaker.preview(line: personality.previewLine, prosody:
  personality.prosody, voiceID: voice?.identifier)`. Its label is an `HStack` holding `Spacer()`, then
  `Label(speaker.isSpeaking ? "Speaking\u{2026}" : "Preview", systemImage: speaker.isSpeaking ?
  "speaker.wave.2.fill" : "speaker.wave.2")` in `.font(.headline)` and `accentColor`, then `Spacer()`.
- `@State private var speaker = PreviewSpeaker()`, and `.onDisappear { speaker.stop() }` on the
  rows (§2.4).

**Previews:** in a `Form` `Section`, with a stand-in personality: once with a voice, and once with
`voice: nil` to show "…".

**Tests**, named after the rule, in `Tests/SyLibTests/SyLibCommentary/`:
- `stoppingAQuietPreviewIsSafe`: `PreviewSpeaker().stop()` leaves `isSpeaking == false`, with no
  trap.

**Docs:** `Docs/Commentary.md` gains a "Settings rows" section after the settings view's, with a
usage example. It ends with two adoption lines:
- "*SyFive adoption: adopted in 1.1.0 (`20`).*"
- "*Syderal adoption: Syderal `24`, Task 24.4, `personalityTitle: "Commentator"`.*"

It also mentions `PreviewSpeaker.stop()` where `PreviewSpeaker` is described. The README's
components table gains the row.

**Done when:**
- The method, the view, the previews, the test and the docs are as above.
- SyLib's suite passes on the pinned destination (`00B` §5.3), at `19`'s total plus 1.
- Syderal builds and passes with no source edit (`00B` §5.4).

**Do not:** change `CommentarySettingsView`, `preview(line:prosody:voiceID:)` or `CommentaryVoices`;
add parameters; touch Syderal.

### 4.2 SyFive: the Settings commentary section uses `CommentarySettingsRows`

**File:** `Views/SettingsView.swift`, the private `SettingsForm`, the Commentary section
(lines 69-77).

1. Read `@Environment(CommentaryVoices.self) private var commentaryVoices` in `SettingsForm`.
2. Replace the section's `NavigationLink { … } label: { LabeledContent("Commentary", …) }` with:

   ```swift
   let personality = CommentaryPersonality.find(id: settings.commentaryPersonalityID)
   CommentarySettingsRows(
       mode: settings.commentaryMode,
       level: CommentaryLevel(rawValue: settings.commentaryLevelRaw) ?? .highlights,
       personality: personality,
       voice: commentaryVoices.voiceInUse(for: personality.id,
                                          savedID: UserDefaults.standard.commentaryVoiceID),
       accentColor: theme.primaryAccent
   ) {
       CommentaryScreen(settings: settings)
   }
   ```

   The `.highlights` fallback is the one `CommentaryScreen`'s level binding uses
   (`App/Commentary/CommentaryScreens.swift`), so the row and the screen never disagree. The section header
   ("Commentary", in `theme.primaryAccent`) is unchanged. `personalityTitle` keeps its default,
   "Personality", which matches SyFive's Commentary screen.
3. If `SettingsForm` has no `theme`, read it from `@Environment(\.theme)`, as the section header
   already does.
4. `SettingsView`'s `#Preview` already injects `CommentaryVoices()` (line 87). Confirm it still
   builds.

**What will differ:** the Commentary section shows four lines and a Preview button, where it showed
"Commentary" followed by the mode. Preview speaks the chosen personality's preview line in the voice
in use. Leaving for the Commentary screen stops it.

**Done when:** the section is as above; previews build; `BuildProject` is clean with 0 warnings; the
suite passes on the pinned destination.

**Check:** P1.

---

## 5. Validation

| ID | After | Check | Expect |
|---|---|---|---|
| P1 | 4.2 | **Pops, device.** Settings, with commentary Off, then All Games. Tap Preview, then tap it again. Tap Preview, and while it speaks tap the row. Change the personality and the voice on the Commentary screen, then go back | Four lines (Mode, Level, Personality, Voice) in both modes. Preview speaks and the second tap stops it. Tapping the row stops the preview as the screen opens. On return the row shows the new personality and the voice in use |

---

## 6. Open decisions

None.

---

## 7. Ledger row

**Commentary**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-146 | **The Settings commentary section uses SyLib's `CommentarySettingsRows`**: a link showing Mode, Level, Personality and the voice in use (or "…" until the scan lands), and a Preview button that speaks the personality's preview line in that voice. All four lines and Preview show in every mode. Leaving the row stops a preview. Syderal uses the same rows with "Commentator" (Syderal `24`). | `20` §2 (Pops, 11 Oct 2026) |

---

## 8. Results log

| Item | Value |
|---|---|
| §4.1: SyLib total; Syderal build and total | **Done 11 Oct 2026.**<br>• `PreviewSpeaker.stop()` added as given. `preview(line:prosody:voiceID:)` is unchanged.<br>• New `Sources/SyLibCommentary/Views/CommentarySettingsRows.swift` (`#if os(iOS)`) with the given initialiser and body:<br>&nbsp;&nbsp;◦ four `LabeledContent` lines<br>&nbsp;&nbsp;◦ a centred Preview `Label` in `.headline` and `accentColor`<br>&nbsp;&nbsp;◦ `@State` `PreviewSpeaker`<br>&nbsp;&nbsp;◦ `.onDisappear { speaker.stop() }`<br>• Two previews in a `Form` `Section`, with a stand-in personality: one with a voice, one with `voice: nil`.<br>• Test `stoppingAQuietPreviewIsSafe` in a new `Tests/SyLibTests/SyLibCommentary/PreviewSpeakerTests.swift`.<br>• Docs: `Commentary.md` gains a "Settings rows" section after `CommentarySettingsView`, with an example and the two adoption lines. Its `PreviewSpeaker` table gains `stop()`. The README's SyLibCommentary row lists `CommentarySettingsRows`.<br>• Results:<br>&nbsp;&nbsp;◦ SyLib **1133 in 121 suites, passed** (19's 1132 + 1), 0 warnings.<br>&nbsp;&nbsp;◦ Syderal builds with no source edit; **897 / 893 passed / 4 skipped / 0 failed**, 0 warnings. This run also covers 19's later `HelpDismissButton` change.<br>&nbsp;&nbsp;◦ SyFive BuildProject clean |
| §4.2: SyFive suite | **Done 11 Oct 2026.** `SettingsView.swift`, `SettingsForm`:<br>• reads `@Environment(CommentaryVoices.self)`; it already had `theme`<br>• the Commentary section's link is replaced with `CommentarySettingsRows` as given: personality via `CommentaryPersonality.find`, level falling back to `.highlights`, voice from `voiceInUse`, accent `theme.primaryAccent`, destination `CommentaryScreen(settings:)`<br>• the header and `personalityTitle` are unchanged, at the default "Personality"<br>• the §3 precondition is met: the Settings sheet gets `CommentaryVoices` (17 §4.6), and the `#Preview` injects one and builds<br><br>BuildProject clean, 0 warnings; **SyFive 19/19** on the pinned destination. This run also covers 19's `HelpDismissButton` change |
| P1 | **Pass** (confirmed by Pops on device, 11 Oct 2026) |
| Ledger | D-146 pasted 11 Oct 2026 under Commentary, as written in §7 |
