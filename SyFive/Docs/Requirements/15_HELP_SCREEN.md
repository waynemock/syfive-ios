# 15_HELP_SCREEN.md — How to Play

**Status:** Design agreed. Implementation brief for the Xcode Claude agent. Scoped for **1.0**.

---

## Supersessions

| Supersedes | What changes |
|---|---|
| — | Net-new surface. No prior document describes a help or onboarding screen. |
| `02_DATAMODEL_DESIGN.md` §7 (Settings placement principle) | **Applied, not superseded.** `helpDismissed` is added as a field on the **existing synced SwiftData settings model**, not to `UserDefaults`. §7's rule — settings default to SwiftData so choices follow the user — is honored. No new model, no new schema decision. |

---

## 0. Why this exists

Players who have never played Yatzy cannot infer the ruleset from the board. The upper bonus, the legality of a deliberate zero, and the extra-Yatzy bonus are all invisible until they bite. This is a first-session comprehension problem, and the cheapest possible fix is static text.

It ships in 1.0 because it is text with no logic, no new schema, and no new game state. It stays static text **for exactly that reason** — the moment it grows coach marks, highlights, or an interactive walkthrough, it becomes a feature and moves to vNext.

---

## 1. Locked decisions

### L1 — Static text only
No interactive tutorial, no coach marks, no highlighted affordances, no first-launch interruption. A scrolling sheet of prose and a reference list. **Rationale:** calm ethos; a modal tutorial before the player has done anything is the opposite of the product. Discovery is handled by placement (L2), not by interruption.

### L2 — Toolbar affordance and surface scope
A `questionmark.circle` button in the **trailing** toolbar, positioned **inboard of the overflow menu** (menu stays outermost, per platform convention).

Present on the **main game screen only**. Not on the new-game / roster screen, not on Players, History, House Records, or Settings. Because Game Night guest devices render the main game screen, the `(?)` appears there too — that is the same surface, not an exception.

### L3 — Menu placement is two-state
The Help item is **always** in the overflow menu, regardless of dismissal state. Only its position changes.

| State | Menu position |
|---|---|
| **Undismissed** (default) | First item, in its own section, `Divider` below it, above everything else. |
| **Dismissed** | Moves into the **last section**, as its first item: *How to Play, About, App Store*. |

**Rationale:** dismissal de-emphasizes; it never removes. A player who dismissed help in week one and forgot the joker rule in week six must still find it.

**Coexistence with Game Night Help:** the menu already carries a separate **Game Night Help** item in the Game Night section. The two are deliberately distinct — one teaches Yatzy, the other explains the SharePlay session — and neither absorbs the other. Do not merge, cross-link, or relocate Game Night Help as part of this work.

### L4 — Dismissal: control, alert, and one-way behavior
A single control at the **end** of the help content, after the player has had the chance to read it. Label: **"Got it, hide this"**.

Tapping it presents a **confirmation alert** (§2.6). Confirming is **permanent for the account** — there is no restore control, no Settings toggle, and no way to bring the toolbar button back short of a fresh install.

Once dismissed, the footer control is **absent** from the sheet entirely — not disabled, not greyed. There is nothing left for it to do.

**Rationale:** the only person qualified to dismiss the instructions is someone who has seen them, so the control sits at the bottom. Because the action is one-way, an alert is the correct weight — and it must be a **confirmation** with Cancel, not an acknowledgment with OK. An OK-only alert informs the player where Help went *after* they have already lost the button, which is the worst of both. Cancel is what earns the interruption.

### L4a — Sheet chrome
The Help sheet has **both** a Done button in the title bar and standard swipe-to-dismiss.

**Rationale:** this makes Done the unambiguous primary action and demotes the footer control to what it is — a preference. A footer-only sheet would have made "Got it, hide this" read as the exit, and players would trip the one-way dismissal while trying to close the sheet.

### L5 — Dismissal state is synced
`helpDismissed: Bool`, default `false`, added as a field to the **existing synced SwiftData settings model**. No new model, no new container, no migration decision.

**Rationale:** this is a per-person preference, not device chrome. A player who has learned the game on their iPhone should not be re-offered the training wheels on their iPad. Hiding it once hides it everywhere.

**It is not tied to a `Player`.** It is not a `Participant` display field. It does not enter the domain layer — the Domain layer stays Foundation-only, per `02_DATAMODEL_DESIGN.md` §9.

### L6 — Never renders on the external display
Help never appears on Stage. Consistent with the House Records rule: Stage shows the game, not the device's chrome. If the sheet is open on the host device, Stage is unaffected and continues rendering the match.

### L7 — Vocabulary
The word **Yahtzee** appears nowhere in this content. The category is **Yatzy**; the extra-five-of-a-kind award is the **Yatzy bonus**. Hasbro's mark is prohibited in listing metadata and there is no reason to introduce it in-app.

### L8 — Content blocks, fixed order
Five blocks, in this order. Copy in §2.

1. The basics
2. The upper bonus
3. Taking a zero
4. Rolling another Yatzy
5. The categories (reference list)

**Rationale:** ordered by when a new player needs it. Blocks 2–4 are the three things that are invisible on the board and cause the "why did it do that?" reaction. The category reference is last because it is lookup material, not reading material.

### L9 — Help is inert
Opening the sheet does not pause, alter, or checkpoint game state. It does not trigger commentary. It does not fire haptics beyond standard sheet presentation. It is available mid-turn with dice on the table and changes nothing about them.

### L10 — English only for 1.0
The §2 copy is final shipping text, not a translation source. No localization pass in 1.0. If localization is ever scoped, these five blocks plus the alert are the app's largest string set and require a translator note carrying the L7 constraint.

---

## 2. Copy (verbatim — this is the shipping text)

### 2.1 The basics

> **How to Play**
>
> Roll the dice — up to three times a turn.
> Hold the ones you want to keep.
> When you're happy, score them in a category.
> Each category is used once. Fill all thirteen to finish.
> Highest total wins.

### 2.2 The upper bonus

> **The upper bonus**
>
> Score 63 or more across Ones through Sixes and you earn an extra 35 points.
>
> Three of each number gets you there.

> **Note to agent:** the second line is the teaching. "63" is an abstraction; "three of each" is a plan. Do not cut it for brevity.

### 2.3 Taking a zero

> **Taking a zero**
>
> Sometimes nothing fits. You can score any open category as a zero — it's a normal move, and sometimes the right one.

### 2.4 Rolling another Yatzy

> **Rolling another Yatzy**
>
> Roll five-of-a-kind again after scoring your first Yatzy and it's worth an extra 100 points.
>
> If the matching number box upstairs is still open, that's where it goes. Otherwise place it anywhere open and take the category's full value.
>
> One exception: if you scored your Yatzy as a zero, later five-of-a-kinds are ordinary rolls — no bonus, no special placement.

> **Note to agent:** all three paragraphs are load-bearing and match shipped behavior exactly.
> - ¶1 = the +100 tally on `Participant.yatzyBonus`, gated on the Yatzy box holding a live 50.
> - ¶2 = joker forced-placement priority. Matching upper box open → forced there. Otherwise any open lower category, FH/SS/LS paying fixed 25/30/40.
> - ¶3 = the strict-Hasbro poison rule (`02_DATAMODEL_DESIGN.md` §4.3). A scratched Yatzy disables **both** halves. "No bonus, no special placement" is deliberately explicit — "normal roll" alone left the joker half implicit.

### 2.5 The categories

> **Upper**
> **Ones – Sixes** — Count that number and add them up.
>
> **Lower**
> **Three of a Kind** — Three matching. Score the total of all five dice.
> **Four of a Kind** — Four matching. Score the total of all five dice.
> **Full House** — Three of one, two of another. 25 points.
> **Small Straight** — Four in a row. 30 points.
> **Large Straight** — Five in a row. 40 points.
> **Yatzy** — All five matching. 50 points.
> **Chance** — Anything at all. Score the total of all five dice.

### 2.6 Footer control and confirmation alert

**Footer control** — present only while `helpDismissed == false`, at the foot of the scrolling content:

> **Got it, hide this**

**Confirmation alert**, presented on tap:

> **Hide the help button?**
>
> How to Play stays in the Menu, in the last section with About. You can open it any time.
>
> **[Cancel]  [Hide]**

- **Cancel** — no state change, alert dismisses, sheet stays open.
- **Hide** — set `helpDismissed = true`, dismiss the alert and the sheet, remove the toolbar `(?)`, move the menu item to the last section.

The alert body names the destination precisely because the menu position genuinely changes at that moment. "In the Menu" alone would leave the player hunting the top of a list where the item no longer is.

Once `helpDismissed == true`, the footer control is not rendered. The sheet is content and Done only.

---

## 3. Implementation stages

1. **Content view.** A scrolling `ScrollView` of static text, §2 blocks in order, house typography. Theme-aware surfaces. Title bar with **Done**; swipe-to-dismiss enabled. No interactivity except the footer control. *Check: renders correctly at all Dynamic Type sizes, iPhone portrait and iPad.*
2. **Setting.** Add `helpDismissed: Bool = false` to the existing synced SwiftData settings model. *Check: survives relaunch; propagates to a second device.*
3. **Toolbar.** Conditional `(?)` in the trailing toolbar of the main game screen, inboard of the menu, bound to `helpDismissed == false`. *Check: appears/disappears live on state change without a view reload artifact; absent on all other screens.*
4. **Menu.** Two-position Help item per L3. *Check: undismissed renders as a lone first section with a divider; dismissed renders as *How to Play, About, App Store*; Game Night Help is untouched in both.*
5. **Footer + alert.** Control rendered only when undismissed; confirmation alert per §2.6. *Check: Cancel leaves state untouched; Hide applies all four effects; Done never mutates `helpDismissed`.*
6. **Accessibility pass.** Toolbar button `accessibilityLabel` = "How to Play" (never "question mark"). Headings marked as headings for rotor navigation. Category list read as a list, not a run-on. *Check: full VoiceOver traversal of the sheet, and the toolbar button announces correctly.*

---

## 4. Validation matrix

| # | Scenario | Expected |
|---|---|---|
| 1 | Fresh install | `(?)` in toolbar; Help is first menu item, own section |
| 2 | Tap `(?)` mid-turn with dice on table | Sheet opens; dice, rolls remaining, held state all unchanged on close |
| 3 | Tap "Got it, hide this" → **Cancel** | No state change; sheet remains open; `(?)` still present |
| 4 | Tap "Got it, hide this" → **Hide** | Sheet closes; `(?)` gone; Help now first item of last section, above About |
| 5 | Relaunch after dismissal | State persists |
| 6 | Second device, same account | `(?)` hidden there too after sync |
| 7 | Open Help from menu while dismissed | Content + Done only; no footer control anywhere in the sheet |
| 8 | Tap Done, then swipe-dismiss | Sheet closes both ways; `helpDismissed` unchanged by either |
| 9 | New game / roster, Players, History, House Records, Settings | No `(?)` on any of them |
| 10 | Game Night guest device | `(?)` present — guest renders the main game screen |
| 11 | Stage mode active, open Help on device | External display unaffected; continues rendering match |
| 12 | Commentary enabled, open Help | No commentary triggered by sheet presentation |
| 13 | Menu audit, both states | Game Night Help present and unmoved in its own section |
| 14 | Largest Dynamic Type | All copy readable, no truncation, category list wraps cleanly |
| 15 | VoiceOver | Toolbar button announces "How to Play"; headings navigable by rotor |
| 16 | All seven themes | Sheet surfaces and text meet contrast in light and dark |
| 17 | Text audit | The string "Yahtzee" appears nowhere in the bundle's help content |

---

## 5. Open decisions

None. All items resolved in design.

---

## 6. Invariants quick reference

- Static text only. No coach marks, no interactive tutorial, no first-launch modal — in 1.0 or after, without a new spec.
- Help is **always** in the overflow menu. Dismissal moves it; dismissal never removes it.
- Dismissal is **one-way and permanent per account**. There is no restore control anywhere in the app. The footer control is absent once dismissed, not disabled.
- The dismissal control exists in exactly one place: the foot of the Help sheet, behind a confirmation alert.
- `(?)` appears on the **main game screen only** — which includes Game Night guest devices, since that is the same screen.
- **Game Night Help is a separate item** and is not merged, moved, or cross-linked by this work.
- `helpDismissed` lives on the existing synced settings model. It never enters the domain layer, never attaches to a `Player`, never appears on a `Participant`.
- Help never renders on the external display.
- "Yahtzee" appears nowhere. The category is Yatzy; the award is the Yatzy bonus.
- Opening Help never mutates game state, triggers commentary, or writes a checkpoint.
- The §2 copy is the shipping text. Wording changes come back here first.

---

## 7. Ledger rows (paste into `00_DECISION_LEDGER.md`)

| Decision | Value | Source |
|---|---|---|
| How to Play surface | Ships in 1.0. Static text only; no tutorial, no coach marks, no first-launch modal | `15_HELP_SCREEN.md` §L1 |
| Help discovery | Trailing toolbar `(?)`, inboard of overflow menu | `15_HELP_SCREEN.md` §L2 |
| Help surface scope | Main game screen only — not roster/new-game or any other screen. Includes Game Night guest devices | `15_HELP_SCREEN.md` §L2 |
| Help menu placement | Always present. Undismissed → first item, own section. Dismissed → first item of last section, above About | `15_HELP_SCREEN.md` §L3 |
| Game Night Help | Remains a separate menu item; not merged with How to Play | `15_HELP_SCREEN.md` §L3 |
| Help dismissal | "Got it, hide this" at foot of sheet, behind a confirmation alert. **One-way and permanent**; no restore control | `15_HELP_SCREEN.md` §L4, §2.6 |
| Help sheet chrome | Done button in title bar **and** swipe-to-dismiss; Done is primary, footer control is a preference | `15_HELP_SCREEN.md` §L4a |
| `helpDismissed` storage | Field on the existing synced SwiftData settings model; syncs across devices. Applies `02_DATAMODEL_DESIGN.md` §7 | `15_HELP_SCREEN.md` §L5 |
| Help on external display | Never renders on Stage | `15_HELP_SCREEN.md` §L6 |
| Help vocabulary | "Yahtzee" prohibited in-app content as well as listing metadata | `15_HELP_SCREEN.md` §L7 |
| Help content scope | Five blocks: basics, upper bonus, taking a zero, second Yatzy, category reference | `15_HELP_SCREEN.md` §L8, §2 |
| Help localization | English only for 1.0; §2 copy is final shipping text, not a translation source | `15_HELP_SCREEN.md` §L10 |
