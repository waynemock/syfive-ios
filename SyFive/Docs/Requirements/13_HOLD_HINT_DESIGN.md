# 13_HOLD_HINT_DESIGN.md
SyFive — Tray Hold-Hint (contextual "tap dice to hold" prompt)

**Status:** Locked. Ready for implementation.
**Supersessions:** None — net-new, additive UI. Does not modify scoring, dice, or persistence.

---

## 1. Problem

Players unfamiliar with Yatzy tap dice expecting to *re-roll* them, when tapping a die
toggles **Held** (removes it from the next roll). There's currently no in-tray guidance —
only the post-roll "Choose a category to score" hint, which teaches the wrong moment.

## 2. Locked Decision

Add a short, muted, state-driven hint **above the dice tray** that teaches hold behavior
exactly when it's relevant, then gets out of the way. No onboarding modal, no tooltip
with a dismiss button, no persistent banner — it must behave like the existing hint
pattern already used below the Roll button (`Choose a category to score`): quiet text
that appears and disappears purely as a function of game state.

### Copy
```
Tap dice to hold
```
Four words, imperative, no punctuation, no exclamation point (exclamation is reserved
for the Yatzy moment only — see `SyFive.md` §6).

### Placement
Centered, directly above the dice tray, between the turn header (`Turn 1/13`) and the
tray itself. Same text style/weight/color as the existing subdued hint text below the
Roll button — secondary/muted foreground, not bold, no background chip, no icon.

### Visibility logic (exact condition — do not simplify)

Show the hint if and only if **all** of the following are true:

```swift
rollsRemaining < 3        // at least one roll has happened this turn — values exist to hold
rollsRemaining > 0        // still rolls left — holding is only meaningful if another roll can happen
heldCount < 5             // not everything is already held — nothing left to teach
```

Where `heldCount` is the number of currently-held dice in the active game/match state.

This means:
- **First roll of a turn:** hidden (nothing rolled yet, nothing to hold).
- **After roll 1 or 2, with at least one die still unheld:** shown.
- **All 5 dice held:** hidden (they've clearly got it, or they're about to score).
- **After the final roll (`rollsRemaining == 0`):** hidden — the existing "Choose a
  category to score" hint owns that moment; the two hints must never show
  simultaneously.

### Rationale for state-driven (not one-time/dismissible)

A "seen once, never again" onboarding tip is wrong for this app's actual failure mode:
it's not that *the player* has never learned it — it's that a *different* person picks
up the device mid-game (pass-and-play, Game Night) and doesn't know the mechanic. The
hint should reappear naturally whenever the state calls for it, for whoever's holding
the phone. No persisted "hasSeenHoldHint" flag. No dismiss affordance.

## 3. Implementation Notes (for the Xcode agent)

- Purely a `View` layer change — no `GameModel`/`MatchController` changes needed. The
  three conditions above are already-published state (`rollsRemaining`, and a derived
  `heldCount` from existing `held` state). If `heldCount` doesn't already exist as a
  computed property, add it as a trivial computed var, not stored state.
- Insert as a `Text` view in the same view file that currently renders `Turn 1/13` and
  the tray (likely `DiceAreaView` or its parent — locate wherever `Choose a category to
  score` is currently rendered and mirror its exact font/color modifiers for visual
  consistency).
- Reserve layout space so the hint's appearance/disappearance doesn't cause the tray to
  jump vertically — either a fixed-height container that shows/hides text inside it, or
  accept the tray shifting by a small fixed amount. Prefer the fixed-height container;
  layout jumps read as "un-calm."
- Transition: a simple opacity fade (existing app transition style, if one exists for
  hint text) rather than a hard cut or slide. Keep it subtle — this is a whisper, not an
  alert.
- No new settings, no new persisted state, no new analytics event required for 1.0.

## 4. Validation Checklist

- [ ] Hint hidden on first roll of every turn.
- [ ] Hint appears after roll 1 if any die is unheld.
- [ ] Hint disappears the instant all 5 dice are held (before or after a subsequent roll).
- [ ] Hint disappears once `rollsRemaining == 0`, and never overlaps with the
      "Choose a category to score" hint.
- [ ] No layout jump in the tray position when the hint appears/disappears.
- [ ] Text style matches the existing below-button hint (font, weight, color) — visually
      reads as the same "voice."
- [ ] Verified on iPhone portrait and iPad layouts.

## 5. Invariants Quick Reference

- Hint text is static: `"Tap dice to hold"` — no variants, no personality-pack voice
  lines (this is UI chrome, not commentary).
- Never shown alongside the `Choose a category to score` hint.
- No dismiss control; no persisted "seen" state.
- Purely derived from existing `rollsRemaining` / held-dice state — no new model fields.

---

## Ledger row (paste into `00_DECISION_LEDGER.md`)

| Doc | Decision | Status |
|---|---|---|
| 03_HOLD_HINT_DESIGN.md | Contextual "Tap dice to hold" hint above tray, shown when `rollsRemaining < 3 && rollsRemaining > 0 && heldCount < 5`; state-driven, no dismiss, mirrors existing hint text style | Locked |
