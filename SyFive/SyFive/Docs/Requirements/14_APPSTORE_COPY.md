# SyFive — App Store Copy & Listing Spec

*The copy suite, screenshot plan, and submission metadata for SyFive 1.0. This is the
paste-ready source of truth for App Store Connect. All copy blocks below are final unless
listed in Open Decisions (§7).*

> **Status:** Copy locked pending three small Pops rulings (§7). Screenshot plan locked at
> four. Description reflects the confirmed full 1.0 feature set (dice, scorecard, Game Night
> over FaceTime + Messages, themes, commentary, house records, insights) — everything
> designed in this project is implemented and shipping.

---

## 0. Supersessions

- Supersedes all prior informal App Store copy discussion in this project.
- The earlier working assumption that Game Night was FaceTime-only is **corrected**: Game
  Night joins via FaceTime **or** Messages (and a shared activity link). Copy names both.
- The earlier draft filename `13_APPSTORE_COPY.md` is void — `13` is
  `HOUSE_RECORDS_DESIGN.md`. This document is `14`.

---

## 1. Name & subtitle

- **App name:** `SyFive`
- **Subtitle (30 char):** `Classic Yatzy, real dice` — 24 chars
  - Alt: `Real dice. Pure calm.` — 21 chars

⚠️ **Trademark:** "Yahtzee" is a live Hasbro mark. It appears **nowhere** in the name,
subtitle, description, or keywords. "Yatzy" (European spelling) only. This is a hard rule.

---

## 2. Keywords (100 char, comma-separated, no spaces)

```
yatzy,dice,3d,physics,tabletop,classic,calm,offline,solitaire,family,roll,scorecard,minimal
```

91 chars. Room to swap in `shareplay` or `messages` if the discoverability of Game Night
matters more than a term above — Pops's call.

---

## 3. Promotional text (170 char — editable anytime without review)

```
Real physics dice you can actually feel. No ads, no accounts, no noise — just five dice, a beautiful scorecard, and a game that respects your evening.
```

---

## 4. Description (paste as plain text — App Store Connect does not render markdown)

The section leads below are plain capitalized phrases, not bold. Blank lines between beats
are intentional.

```
Most dice apps pick a number, then animate it. SyFive doesn't.

Every roll is a real physics simulation — impulse, spin, collision, settle. The result isn't decided until the dice stop moving. Then we tested it across 10,000 rolls to prove it's fair, so you never have to wonder.

And then we spent just as long making it calm.

Five dice you can feel. They tumble, knock, rock to a stop, and catch the light on the final turn. Hold the ones you want, roll the rest, take your three rolls, and choose where the score goes.

Classic Yatzy, in full. Upper bonus, the lower categories, the Yatzy bonus, joker scoring — all of it. And a scorecard that's finally readable: available moves obvious, locked ones quiet, totals that settle instead of pop.

Game night, across any distance. Start a Game Night over FaceTime or Messages and pass the dice around the table — even when the table spans time zones.

Made your way. Seven themes, light and dark. Optional spoken commentary in four voices, off until you ask for it. Celebrations that mark the moment without shouting.

And more when you go looking. House records that honor everyone who's played instead of ranking them. A play-understanding layer that reads your game back to you in plain language. Never nagging, never loud.

No ads. No in-app purchases. No account. No tracking. No casino noise. Works fully offline — nothing leaves your devices except through your own iCloud.

Five dice. Pure calm.
```

---

## 5. Screenshots (4, portrait)

Four total — deliberately capped. Copy carries the features screenshots can't; the shot
list only has to carry the load-bearing claims. Game Night is intentionally **not** a
screenshot: it doesn't photograph without staging two devices and a live call, and the
description beat already conveys it.

| # | Shot | Caption | Effort |
|---|---|---|---|
| 1 | Dice mid-tumble, motion caught in air | *Real dice. Real physics. Real rolls.* | Near-zero — roll and capture mid-air |
| 2 | Two-player scorecard, two different themes | *A scorecard you can actually read.* | Low — reuse the game-night two-player setup |
| 3 | The Yatzy moment: settled five-of-a-kind, rim light up, title card | *Five of a kind. Fifty points. No confetti.* | Opportunistic — capture next real Yatzy |
| 4 | Fair Dice sheet| *Real physics. Proven fair.* | Near-zero — just capture the sheet|

Coverage: dice / scorecard+themes+multiplayer / signature moment+ethos / ethos closer.

**Caption treatment:** midnight background, one line, generous margins, device frames
floated rather than filling the slot. Same restraint as the icon.

---

## 6. Apple-required metadata (fill in App Store Connect regardless of copy)

- **Age rating:** 4+. No objectionable content of any kind.
- **Privacy nutrition label:** **Data Not Collected** (all-green). Private CloudKit sync is
  the user's own iCloud, not collection by the developer, and there is no analytics,
  account, or tracking. Confirm there is genuinely no third-party analytics SDK before
  attesting.
- **Support URL / Marketing URL:** Syzygy Softwerks site (confirm exact URLs — §7).
- **Category:** Games › Board (primary). Consider Games › Family as secondary.
- **Copyright:** `© 2026 Syzygy Softwerks LLC`

---

## 7. Open decisions (Pops resolves — do not assume)

1. **Subtitle:** `Classic Yatzy, real dice` (primary) vs `Real calm. Pure dice.`-style
   alt. Primary recommended for search (contains "Yatzy" + "dice").
2. **Deep-features beat:** keep the "And more when you go looking" paragraph (house records
   + insights named lightly) or cut it entirely and let those be pure in-app discovery. Kept
   in the current draft.
3. **Marketing/Support URLs:** confirm the exact Syzygy Softwerks URLs to enter.

---

## 8. Pre-submission checklist (blocking — verify before archive)

- [ ] `AppConfig.DebugDice.showHarness = false`
- [ ] `AppConfig.DebugDice.logRollDiagnostics = false`
- [ ] Debug dice harness / batch UI unreachable in the archived build
- [ ] No "Yahtzee" string anywhere in listing metadata
- [ ] Privacy label attested as Data Not Collected (no analytics SDK present)
- [ ] Icon exported at all required sizes from the locked spec
- [ ] Four screenshots captured at required device resolutions
- [ ] Support + Marketing URLs live and reachable

---

## 9. Ledger rows (paste into `00_DECISION_LEDGER.md`)

- App Store: app name `SyFive`; subtitle `Classic Yatzy, real dice`; "Yahtzee" prohibited in
  all listing metadata (Hasbro mark).
- App Store: description leads with provable-fairness differentiator (physics + 10k-roll
  validation), closes on calm/no-noise ethos.
- App Store: Game Night described as joining over FaceTime **or** Messages (corrects prior
  FaceTime-only assumption).
- App Store: screenshot count locked at **four** (dice tumble / two-player scorecard / Yatzy
  moment / dark ethos closer). Game Night deliberately not screenshotted.
- App Store: privacy label = Data Not Collected; age rating 4+; private CloudKit sync does
  not constitute collection.
- App Store: pre-submission gate — `showHarness` and `logRollDiagnostics` false, harness
  unreachable, before archive.
