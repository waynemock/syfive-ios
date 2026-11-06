# SyFive — App Store Copy & Listing Spec

*The copy suite, screenshot plan, and submission metadata for SyFive. This is the
paste-ready source of truth for App Store Connect. All copy blocks below are final unless
listed in Open Decisions (§7).*

**Version 1.1.0** · revised 11 October 2026 · **A living record, edited in place** (D-148, an
exception to D-001). Changes are listed in §10.

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

- **App Store name (30 char):** `SyFive: Yatzy Dice Game` — 23 chars
  - Store listing only. The home screen, app switcher and Settings show `SyFive`, from the
    target's product name. Same pattern as Syderal's `Syderal: Space Race Board Game`.
  - It puts "Yatzy", "dice" and "game" in the App Store's most heavily weighted search field.
- **Subtitle (30 char):** `Classic rules, real physics` — 27 chars
  - A sister line to Syderal's `Classic race, real rocketry`. Every word is new to the name.
- **1.0 values, for history:** name `SyFive`; subtitle `Classic Yatzy, real dice`.
- Both fields change only with a new version: entered with the 1.1.0 submission.

⚠️ **Trademark:** "Yahtzee" is a live Hasbro mark. It appears **nowhere** in the name,
subtitle, description, or keywords. "Yatzy" (European spelling) only. This is a hard rule.

---

## 2. Keywords (100 char, comma-separated, no spaces)

```
3d,tabletop,calm,offline,solitaire,family,roll,scorecard,minimal,shareplay,party,yacht,multiplayer
```

98 chars.

- Words already in the name or subtitle are indexed, so they are not repeated here. That
  dropped `yatzy`, `dice`, `physics` and `classic` from the 1.0 list.
- Added: `shareplay`, `multiplayer` and `party` (Game Night discoverability), and `yacht`
  (the game's old public-domain name, which people still search for).
- Never: `yahtzee` (Hasbro) or `kniffel` (another company's mark).
- If `board` or `strategy` is wanted, drop `minimal`, the weakest term. Only one of them fits.

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

1. ~~**Subtitle**~~ **Resolved (Pops, 11 Oct 2026):** `Classic rules, real physics`, with the
   store name `SyFive: Yatzy Dice Game` (§1).
2. **Deep-features beat:** keep the "And more when you go looking" paragraph (house records
   + insights named lightly) or cut it entirely and let those be pure in-app discovery. Kept
   in the current draft.
3. **Marketing/Support URLs:** confirm the exact Syzygy Softwerks URLs to enter.

---

## 8. Pre-submission checklist (blocking — verify before archive)

- [ ] `00B_SYFIVE_GUARDRAILS.md` §6 pre-archive checklist: every `AppConfig` debug flag
      `false`, `MARKETING_VERSION` set in both configurations, CloudKit Production matching
      Development
- [ ] Debug dice harness / batch UI unreachable in the archived build
- [ ] App Store name, subtitle and keywords entered as in §1–§2, with character counts as
      shown
- [ ] No "Yahtzee" string anywhere in listing metadata
- [ ] Privacy label attested as Data Not Collected (no analytics SDK present)
- [ ] Icon exported at all required sizes from the locked spec
- [ ] Four screenshots captured at required device resolutions
- [ ] Support + Marketing URLs live and reachable

---

## 9. Ledger rows (paste into `00_DECISION_LEDGER.md`)

- App Store (1.1.0): store name `SyFive: Yatzy Dice Game` (device name stays `SyFive`);
  subtitle `Classic rules, real physics`; keywords as §2, never repeating a name or subtitle
  word; "Yahtzee" prohibited in all listing metadata (Hasbro mark).
- App Store: description leads with provable-fairness differentiator (physics + 10k-roll
  validation), closes on calm/no-noise ethos.
- App Store: Game Night described as joining over FaceTime **or** Messages (corrects prior
  FaceTime-only assumption).
- App Store: screenshot count locked at **four** (dice tumble / two-player scorecard / Yatzy
  moment / dark ethos closer). Game Night deliberately not screenshotted.
- App Store: privacy label = Data Not Collected; age rating 4+; private CloudKit sync does
  not constitute collection.
- App Store: pre-submission gate — `00B` §6 (all `AppConfig` flags false, version, CloudKit),
  harness unreachable, before archive.
- **D-148:** `14_APPSTORE_COPY.md` is a living store record, edited in place with a version and
  changelog (§10). It is an exception to D-001, which keeps every other SyFive design document
  immutable. (Pops, 11 Oct 2026)

---

## 10. Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026 | First listing: name `SyFive`, subtitle `Classic Yatzy, real dice`, 91-char keywords |
| 1.1.0 | 11 Oct 2026 | §1: store name `SyFive: Yatzy Dice Game`; subtitle `Classic rules, real physics`. §2: keywords drop words now in the name or subtitle, and add `shareplay`, `party`, `yacht` and `multiplayer` (98 chars). §7.1 resolved. §8 points to `00B` §6. §9 rows updated; D-148 added (Pops) |
