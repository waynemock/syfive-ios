# SyLib `HelpDismissButton`: the How to Play "Got it" button, shared

**Status:** Ready for the agent once `18` is complete. Written 11 October 2026.

**Scope:** `sylib-swift` on branch `syfive-reintegration` (§4.1) and `SyFive` (§4.2). Ships in 1.1.0.
Syderal adopts the component in its own `24_SYLIB_FROM_SYFIVE.md`, not from here (`00B` §5.4).

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md`,
`00B_SYFIVE_GUARDRAILS.md`, this document.

---

## Supersessions

None. Nothing in an earlier document governs this button. SyFive's behaviour is unchanged; the
code moves.

---

## 1. Why

Both apps end their first-run How to Play page with a button that hides the help, and both do the
same thing on that tap: the toolbar `?` disappears, and How to Play moves into the menu's last
section, beside About.

- **SyFive** (`Views/HowToPlayView.swift` 49-58 and 70-78) labels it "Got it, hide this". It asks
  first, with an alert that says where help can still be found.
- **Syderal** (`UI/HowToPlayView.swift`, `gotItButton`) labels it "Got it", and hides at once with no
  alert. The player isn't told where How to Play went.

Pops, 11 October 2026: move the alert into SyLib, so both apps behave the same. The How to Play
pages themselves stay in each app, because their content, page styling and the setting they
write are all different.

---

## 2. Locked decisions

**2.1 SyLibUI gains `HelpDismissButton`** (D-145). It draws the button and owns the confirmation
alert. The app supplies the look's accent and what Hide does. *Rationale:* §1; one copy of the
wording, like `MoreMenu` and `Toast`.

**2.2 Two styles, so neither app's page changes look** *(rec.)*. `.link` is SyFive's quiet accent
text; `.prominent` is Syderal's full-width bordered button.

**2.3 The default wording is SyFive's, and is accurate for both apps** *(rec.)*. Button: "Got it,
hide this". Alert: "Hide the help button?" with the message "How to Play stays in the Menu, in the
last section with About. You can open it any time." The two alert buttons are "Cancel" and "Hide".
In Syderal, How to Play also moves into the menu's last section, beside About (`ShellMenu.swift`
265-270). *Rationale:* the label says what the tap does, which "Got it" alone does not.

**2.4 The copy is fixed in SyLib, and overridable.** It lives in public static constants, which
the initialiser's parameters default to. A test pins each constant, because it is player-facing
text (`00B` §2).

---

## 3. Before starting

- `18` is complete.
- SyLib's suite total after `18` is recorded in `18` §10. This task adds to it.

---

## 4. Tasks

One task per session, reported in `00A` §6's form.

### 4.1 SyLib: `HelpDismissButton`

**New file:** `Sources/SyLibUI/Components/HelpDismissButton.swift`.

```swift
import SwiftUI

/// The button at the foot of a first-run How to Play page that hides the help. Tapping it asks
/// first, with an alert that says where help can still be found; Hide calls `onHide`.
public struct HelpDismissButton: View {

    /// How the button is drawn.
    public enum Style: Sendable {
        /// Subheadline text in the accent colour. SyFive's look.
        case link
        /// A full-width bordered-prominent button. Syderal's look.
        case prominent
    }

    public static let defaultTitle = "Got it, hide this"
    public static let defaultAlertTitle = "Hide the help button?"
    public static let defaultAlertMessage =
        "How to Play stays in the Menu, in the last section with About. You can open it any time."

    /// - Parameters:
    ///   - title: The button's label.
    ///   - style: `.link` or `.prominent`.
    ///   - accentColor: The link text colour, or the prominent button's tint. Nil uses the
    ///     environment's tint.
    ///   - alertTitle: The confirmation alert's title.
    ///   - alertMessage: The confirmation alert's message.
    ///   - onHide: Called when the player taps Hide. The app records the dismissal and closes
    ///     the page.
    public init(_ title: String = HelpDismissButton.defaultTitle,
                style: Style = .link,
                accentColor: Color? = nil,
                alertTitle: String = HelpDismissButton.defaultAlertTitle,
                alertMessage: String = HelpDismissButton.defaultAlertMessage,
                onHide: @escaping () -> Void)
}
```

**Body:**
- A `Button` whose action sets a private `@State var showsAlert` to `true`.
- **`.link`:** the label is `Text(title).font(.subheadline)`, with its foreground style set to
  `accentColor` when given, else `.tint`.
- **`.prominent`:** the label is `Text(title).frame(maxWidth: .infinity)`, with
  `.buttonStyle(.borderedProminent)`. Apply `.tint(accentColor)` only when an accent is given.
- `.alert(alertTitle, isPresented: $showsAlert) { Button("Cancel", role: .cancel) {}; Button("Hide") {
  onHide() } } message: { Text(alertMessage) }`.

These match SyFive's existing button and alert exactly (`Views/HowToPlayView.swift` 49-58, 70-78),
and Syderal's existing button (`UI/HowToPlayView.swift`, `gotItButton`).

**Previews:** `.link` and `.prominent`, each in light and dark.

**Test**, named after the rule: `Tests/SyLibTests/SyLibUI/HelpDismissButtonTests.swift`,
`theDefaultWordingIsPinned`. Assert the three constants equal the exact strings in §2.3.

**Docs:** `Docs/UI_COMPONENTS.md` gains a `HelpDismissButton` section after `MoreMenu`, with a usage
example for each style. It ends with two adoption lines:
- "*SyFive adoption: adopted in 1.1.0, `.link` (`19`).*"
- "*Syderal adoption: `.prominent`, Syderal `24`.*"

The README's components table gains its row.

**Done when:**
- The file, previews, test and docs are as above.
- SyLib's suite passes on the pinned destination (`00B` §5.3), at `18`'s total plus 1.
- Syderal builds and passes with no source edit (`00B` §5.4). It doesn't use the component yet.

**Do not:** touch Syderal; add any other parameter; change `MoreMenu` or `Toast`.

### 4.2 SyFive: How to Play uses `HelpDismissButton`

**File:** `Views/HowToPlayView.swift`.

1. Replace the `Button { showsDismissAlert = true } … .padding(.top, 4)` block (lines 49-58) with:

   ```swift
   if settings?.helpDismissed != true {
       HelpDismissButton(style: .link, accentColor: theme.primaryAccent) {
           settings?.helpDismissed = true
           dismiss()
       }
       .padding(.top, 4)
   }
   ```

2. Delete the `.alert("Hide the help button?", …)` modifier (lines 70-78) and the
   `showsDismissAlert` state (line 7).
3. Add `import SyLibUI` if the file lacks it.

**What will differ:** nothing a player can see. The label, look, alert and outcome are the same.

**Done when:** the two edits are in; the previews build; `BuildProject` is clean with 0 warnings;
the suite passes on the pinned destination.

**Check:** H1.

---

## 5. Validation

| ID | After | Check | Expect |
|---|---|---|---|
| H1 | 4.2 | **Pops, device.** With help not yet dismissed, open How to Play and scroll to the bottom. Tap "Got it, hide this", then Cancel. Tap it again, then Hide | Same as 1.0.3. Cancel leaves everything as it was. Hide closes the page, the toolbar `?` is gone, and How to Play is in the menu's last section, beside About |

---

## 6. Open decisions

None. §2.2 and §2.3 are Claude's recommendations, accepted with the request to write this
document. Pops may change either before the task runs.

---

## 7. Ledger row

**Platform & data**

| ID | Current ruling | Source → chain |
|---|---|---|
| D-145 | **The How to Play "Got it" button is SyLibUI's `HelpDismissButton`**: "Got it, hide this", then the alert "Hide the help button?", with the message "How to Play stays in the Menu, in the last section with About. You can open it any time." SyFive uses `.link`; Syderal uses `.prominent` (Syderal `24`). The How to Play pages stay app-owned. | `19` §2 (Pops, 11 Oct 2026; styles and wording *(rec.)*) |

---

## 8. Results log

| Item | Value |
|---|---|
| §4.1: SyLib total; Syderal build and total | **Done 11 Oct 2026.**
- **New:** `Sources/SyLibUI/Components/HelpDismissButton.swift`, as specified: `Style.link` / `.prominent`, the three public constants, the given initialiser, and the alert with Cancel / Hide. Four previews: link and prominent, each in light and dark.
- **Test:** `Tests/SyLibTests/SyLibUI/HelpDismissButtonTests.swift`, `theDefaultWordingIsPinned`. The suite is `@MainActor`, because the View's constants are main-actor isolated.
- **Docs:** `UI_COMPONENTS.md` has a `HelpDismissButton` section after `MoreMenu`, with an example of each style and the two adoption lines. `README.md`'s SyLibUI row lists `HelpDismissButton`.
- **Results:** SyLib **1132 in 120 suites, passed** (18's 1131 + 1), 0 warnings. Syderal builds with no source edit: **897 / 893 passed / 4 skipped / 0 failed**, 0 warnings. SyFive BuildProject clean |
| §4.2: SyFive suite | **Done 11 Oct 2026.** `HowToPlayView.swift`: `import SyLibUI` added. The button block is now `HelpDismissButton(style: .link, accentColor: theme.primaryAccent) { settings?.helpDismissed = true; dismiss() }.padding(.top, 4)` inside the same `if`. The `.alert("Hide the help button?", …)` modifier and the `showsDismissAlert` state are deleted. Both previews build; BuildProject clean, 0 warnings; **SyFive 19/19** on the pinned destination |
| **Deliberate change after §4.2 (Pops, 11 Oct 2026)** | **Made on purpose, overriding §2.2 and §4.1's button body.**
- `HelpDismissButton` has **no `Style`**: `.link` and `.prominent` are removed, so every app's button looks the same.
- It draws a SyLibUI **`CapsuleButton` in the `.accent` style** (tinted outline, tinted `.subheadline` label, size `.regular`), **centred across the available width** (`.frame(maxWidth: .infinity)`).
- `accentColor` stays optional and tints the capsule; nil uses the environment's tint.
- The initialiser is now `init(_ title:, accentColor:, alertTitle:, alertMessage:, onHide:)`.
- The alert, its wording and the three pinned constants are unchanged.
- SyFive's call drops `style: .link`. The previews are now Light and Dark.
- `UI_COMPONENTS.md` describes the single look, and its Syderal adoption line reads "Syderal `24`" without a style.
- **Follow-ups:** D-145 in §7 (not yet in the ledger) still names the two styles and needs rewording when pasted. Syderal's `24` plan may name `.prominent` and should drop it. |
| H1 | **Pass** (confirmed by Pops on device, 11 Oct 2026). This is the centred `CapsuleButton` look |
| Ledger | D-145 pasted 11 Oct 2026 under Platform & data, reworded for the single centred `CapsuleButton` look (no styles) |
