# SyFive — Commentator Design Spec

*Design authority for the optional spoken-commentary feature: the personality-pack
architecture, the event taxonomy, the settings UX (voice picker, preview, add-voices
flow), and the full copy library for all four launch personalities.*

> **Status:** Design agreed for **SyFive 1.0**. This document is the implementation brief
> for the Xcode Claude agent. It describes an App-layer feature that is **off by default**
> and, when enabled, narrates game events using iOS speech synthesis. Read the whole
> document; the architecture section and the copy library interlock (the pack structure is
> what makes the copy pure data).

---

## 0. Why this exists, and why it doesn't break the calm ethos

Game night wants a little theater. A commentator — dry, snarky, zen, or full sportscaster —
turns a quiet dice app into a party for the length of one evening, then vanishes when the
table goes quiet again.

The reconciliation with the Syzygy "calm, minimal, polished" ethos is entirely in the
gating:

- **Off is the out-of-box state.** The calm night-table player never hears a word. This is
  the same shape as the suggested-move highlight and the (deferred) shake-to-roll: a party
  trick you opt into, not a default you tolerate.
- **The user controls how much.** A level control runs from *Celebrations only* (just the
  signature moments) to *Play-by-play* (turn-by-turn). The floor of "on" is barely more
  than the existing Yatzy celebration; the ceiling is a full booth.
- **The snark is aimed at the dice, never the person.** See §11. Live banter and the
  neutral-to-affirming Player Insights layer are different rooms and must stay that way.

Silence remains the default. Everything below is what happens when someone flips it on.

---

## 1. Architecture — the pack *is* data

The single most important rule of this feature: **adding a personality must be adding one
data file and nothing else.** If a new personality requires touching the engine, the
architecture is wrong. Everything an author writes for a new pack is copy plus a handful of
prosody numbers.

### 1.1 Layer placement

This is **App-layer, top to bottom.** It imports `AVFoundation` (speech synthesis) and
observes `MatchController`. It never touches the Domain layer — the Domain stays
Foundation-only, and the commentator is as far from it as the dice engine is. It is a
**sibling to `DiceAudioController`** and follows the identical pattern the audio work
already established: a protocol with no-op defaults, and a concrete implementation assigned
only when the feature is enabled. A commentator-that-does-nothing when off; no branching
scattered through the game code.

```
App/
  Commentary/
    CommentaryEngine.swift        — selection + prosody + speech, the ONLY mechanism
    CommentaryEvent.swift         — the App-layer event enum + context payloads
    CommentaryPersonality.swift   — the pack type (id, prosody, line library)
    CommentaryLevel.swift         — Off / Celebrations / Highlights / PlayByPlay
    Packs/
      Pack+Sports.swift           — copy only
      Pack+Zen.swift              — copy only
      Pack+Steady.swift           — copy only
      Pack+Snarky.swift           — copy only
    Settings/
      CommentarySettingsView.swift
      VoicePickerView.swift
      AddVoicesSheet.swift
```

### 1.2 How events reach the engine

The commentator, the score audio, and the score haptics are all **observers of the same
turn-boundary event stream.** The events are computed by the code in `MatchController` that
*already* knows these things happened — the branch that awards the Yatzy bonus already
knows a bonus occurred; the completion path already resolves the winner and margin. Those
call sites emit a `CommentaryEvent`; they do not compute anything new for the commentator's
sake.

Keep this **lightweight.** A single sink — `MatchController` holds an optional
`(CommentaryEvent) -> Void` (or a tiny `CommentaryEventSink` protocol) and calls it at the
boundaries. **Do not build an event-bus framework.** Same discipline as not building the
`ScoringSystem` protocol before the second conformer exists: the three observers we have do
not justify infrastructure. If a fourth observer ever appears, revisit then.

```
MatchController  ──emits──▶  CommentaryEvent  ──▶  CommentaryEngine
                                                      │
                                          level gate (is event.tier ≤ userLevel?)
                                                      │
                                          select line (by event kind, exclude last-used)
                                                      │
                                          fill tokens → apply pack prosody
                                                      │
                                          speak (AVSpeechSynthesizer, ducked, VO-aware)
```

### 1.3 The pack type (the whole point)

```
struct CommentaryPersonality {
    let id: String                 // "sports", "zen", "steady", "snarky"
    let displayName: String        // "Sports", shown in settings
    let blurb: String              // one line describing the vibe, shown in settings
    let prosody: Prosody           // default delivery for this pack
    let previewLine: String        // the showcase line the Preview button speaks
    let lines: [CommentaryEventKind: [String]]   // event → phrasing variants (tokens inside)
}

struct Prosody {
    var rate: Float                // AVSpeechUtterance.rate, ~0.4–0.55
    var pitchMultiplier: Float     // 0.5–2.0, 1.0 = neutral
    var preUtteranceDelay: TimeInterval
    var postUtteranceDelay: TimeInterval
}
```

That is the entire surface a pack author touches: an id, a name, a blurb, four prosody
numbers, one preview line, and a dictionary of copy. No code. This is the correctness
criterion — the four launch packs in §10 are *only* the `lines` dictionary plus a prosody
row from §7.

### 1.4 The selection rule (organic, not repetitive)

TTS repeating the identical Yatzy line by the fourth five-of-a-kind feels worse than
silence. The engine's one behavioral rule:

- For a given event kind, filter to that kind's line array.
- **Exclude the line used last time for this same event kind** (track one `lastIndex` per
  event kind, per session — a tiny `[CommentaryEventKind: Int]`).
- Pick uniformly at random from the remainder.
- Fill tokens, apply prosody, speak.

With 20+ variants per event, "no immediate repeat" is enough to feel fresh across an entire
game night without a full shuffle-bag. If you want to go further later, a shuffle-bag
(exhaust all variants before repeating) is an additive change to the engine that needs no
change to any pack — but it is explicitly **not required for 1.0.**

### 1.5 Speech mechanics (get these right once)

- **`AVSpeechSynthesizer`**, one long-lived instance owned by the engine.
- **Voice** = `AVSpeechSynthesisVoice(identifier:)` from the user's chosen voice ID; fall
  back to `AVSpeechSynthesisVoice(language:)` for the device locale if the stored ID is no
  longer installed (a voice can be deleted in iOS Settings between launches).
- **Don't queue-flood.** If an event arrives while still speaking, **interrupt** for
  higher-tier events (a Yatzy shouldn't wait behind a play-by-play line) and **drop**
  same-or-lower-tier events (never build a backlog that talks over the next turn). Speech
  should always be *behind* the live game, never ahead of it.
- **Audio session:** use `.duck` (`.mixWithOthers` + `.duckOthers`) so someone's game-night
  playlist dims rather than stops. Never take `.playback` in a way that halts other audio.
- **VoiceOver:** if `UIAccessibility.isVoiceOverRunning`, **suppress commentary** (or at
  minimum never talk over it). The accessibility layer wins; we do not compete with it.

---

## 2. Event taxonomy & level tiers

Each event kind belongs to exactly one tier. The level control is a simple ceiling: play an
event when `event.tier ≤ userLevel`.

| Level (userLevel) | Plays |
|---|---|
| **Off** | nothing (feature disabled) |
| **Celebrations** | Celebration tier only |
| **Highlights** | Celebration + Highlight |
| **Play-by-Play** | Celebration + Highlight + PlayByPlay |

| Event kind | Tier | Fires when | Tokens exposed |
|---|---|---|---|
| `yatzyRolled` | Celebration | first five-of-a-kind scored as Yatzy (50) | `{player}` |
| `yatzyBonusEarned` | Celebration | each additional five-of-a-kind while Yatzy box holds a live 50 (+100) | `{player}` |
| `winnerDeclared` | Celebration | match completes with a single winner | `{winner}`, `{runnerUp}`, `{score}`, `{margin}` |
| `winnerTie` | Celebration | match completes tied at the top | `{winner}` (comma list), `{score}` |
| `upperBonusEarned` | Highlight | a player's upper section reaches 63 (+35) | `{player}` |
| `yatzyScratched` | Highlight | the Yatzy box is scored 0 (the poisoned box) | `{player}` |
| `bigTurn` | Highlight | a high-value category is scored (Large Straight, Full House, or a Yatzy-adjacent big number) | `{player}`, `{category}`, `{value}` |
| `leadChange` | Highlight | a new player takes sole possession of the lead mid-match | `{leader}`, `{runnerUp}` |
| `turnStart` | PlayByPlay | a player's turn begins | `{player}` |
| `categoryScored` | PlayByPlay | any routine category is scored | `{player}`, `{category}`, `{value}` |
| `categoryScratched` | PlayByPlay | a non-Yatzy category is scored 0 by choice | `{player}`, `{category}` |

Notes:
- `winnerDeclared` vs `winnerTie` are **separate kinds**, not one kind with a conditional,
  so the engine never branches on content — line selection stays "pick from the array for
  this kind." Margin flavor (blowout vs squeaker) rides inside `winnerDeclared` copy via the
  `{margin}` token and margin-agnostic phrasing; if you later want margin-specific packs,
  split into `winnerBlowout` / `winnerSqueaker` as new kinds — additive, no engine change.
- `bigTurn` and `categoryScored` can both be true for the same score. **`bigTurn` wins** (it
  is the higher tier); emit only one event per scoring action. The emit site picks the most
  interesting single event.

---

## 3. Token reference

Tokens are `{name}` placeholders the engine substitutes before speaking. A pack line may use
any token its event exposes (§2 table); unused tokens are simply absent. Keep lines readable
if a token is short.

| Token | Meaning | Example value |
|---|---|---|
| `{player}` | acting player's display name | "Xander" |
| `{winner}` | winning player's display name (comma list for ties) | "Mom" |
| `{runnerUp}` | second-place display name | "Dad" |
| `{leader}` | new leader's display name | "Bea" |
| `{score}` | relevant final score | "312" |
| `{margin}` | winning margin, points | "40" |
| `{category}` | scored category, display name | "Large Straight" |
| `{value}` | points scored this action | "40" |

**Display-name safety.** `{player}` etc. come from the Participant **display snapshot**
(`displayName` from `02_DATAMODEL_DESIGN.md` §2.7), so commentary keeps naming a player
correctly even after a roster rename or delete. Names are free text; TTS will pronounce them
as best it can — this is acceptable and not something to sanitize.

---

## 4. The four launch voices — character guide

Before the copy, a short brief on each pack's voice so any future line stays in character.

- **Sports** — the broadcast booth. Energetic, hyperbolic, sports clichés repurposed for
  dice. "Folks." "Ladies and gentlemen." Big verbs. Excited, never obnoxious. Reads fast.
- **Zen** — the mindful narrator. Calm, present-tense, gently wry serenity. Breath, stillness,
  non-attachment, a little nature. Slow and spacious. Never saccharine; a knowing lightness
  underneath the calm.
- **Steady** — the understated scorekeeper. Dry, factual, minimal, warm underneath. States
  what happened cleanly and moves on. Short. The "just the facts" register with a pulse.
- **Snarky** — the deadpan wit. Dry, playful, mock-dramatic. Ribs the *roll, the dice, the
  decision* — **never the person**. Clever, not cruel. Comic timing over volume.

---

## 5. Prosody defaults per personality

Concrete starting values. All are `DiceRoller.Config`-style tunables, not hardcoded; expect
a tuning pass by ear on device. `rate` is `AVSpeechUtterance.rate` (default ≈ 0.5).

| Pack | rate | pitchMultiplier | preUtteranceDelay | postUtteranceDelay |
|---|---|---|---|---|
| **Sports** | 0.54 | 1.08 | 0.05 s | 0.05 s |
| **Zen** | 0.42 | 0.96 | 0.35 s | 0.30 s |
| **Steady** | 0.50 | 1.00 | 0.10 s | 0.10 s |
| **Snarky** | 0.48 | 0.98 | 0.20 s | 0.15 s |

The Zen `preUtteranceDelay` and slow rate are load-bearing — the pause *is* the personality.
Snarky's small delay buys comic timing. Sports runs hot and quick.

---

## 6. Settings UX

A single **Commentary** section, premium and short (consistent with the Settings principle
in `02_DATAMODEL_DESIGN.md` §7). All controls are inert until the master toggle is on.

1. **Commentary — master toggle** (default **OFF**). Off = feature fully disabled, no engine
   instantiated.
2. **Level** — segmented or menu: *Celebrations · Highlights · Play-by-Play*. (Off is
   expressed by the master toggle, not a fourth level position, so "on but silent" is
   impossible.)
3. **Personality** — a list of the four packs, each showing `displayName` + `blurb`. Selection
   is a single choice.
4. **Voice** — see §6.1.
5. **Preview** — a prominent button that speaks the **selected personality's `previewLine`**
   in the **selected voice** with that pack's **prosody**. This is the "hear it" moment the
   user asked for: it exercises the real path (voice + personality + delivery), not a generic
   sample. Tapping again while speaking interrupts and restarts.
6. **Add more voices…** — opens the sheet in §6.2.

### 6.1 Voice picker

- List installed voices from `AVSpeechSynthesisVoice.speechVoices()`, grouped by language
  with the device locale surfaced first.
- **Flag enhanced/premium voices.** `voice.quality` is `.enhanced` / `.premium` vs
  `.default`; label the good ones ("Enhanced") and consider sorting them to the top. The
  compact default voices sound robotic — a bad look for a premium app — so gently steer
  toward the good ones without forcing.
- Each row has a small inline **play** control that previews that specific voice (using the
  current personality's `previewLine` so the character comes through).
- **Voice ID is arguably device-local.** Per the §7 "decide per-setting" principle from the
  data-model spec: a voice installed on the iPhone may not exist on the iPad, so storing the
  chosen voice ID in synced settings can point at nothing on another device. Recommendation:
  **store the voice ID device-locally** (UserDefaults), while **level and personality sync**
  (they're portable). On a device where the stored voice is missing, fall back to a sensible
  enhanced voice for the locale and let the user re-pick. *(This is an open decision — see
  §12.)*

### 6.2 The "Add more voices" sheet

This exists because **iOS provides no public deep link to the Voices pane.** The only
App-Store-safe navigation is `UIApplication.shared.open(URL(string:
UIApplication.openSettingsURLString)!)`, which opens **this app's** Settings page — not
Accessibility, and not Spoken Content. The `App-Prefs:root=…` URL schemes that appear to jump
straight to Accessibility are **private and risk App Store rejection.** Do not use them.

So the sheet carries the navigation the link can't:

- A short, friendly tutorial showing the exact tap path, e.g.:
  *Settings → Accessibility → Spoken Content → Voices → (choose a language) → download an
  Enhanced or Premium voice.*
- Present it as 3–4 clean steps (numbered rows or a tiny illustration per step), on brand:
  calm, spare, no clutter.
- A single button: **Open Settings** → `openSettingsURLString`. Set expectations honestly in
  one line of copy: this opens Settings; follow the steps above from there. (It lands on the
  app's page or Settings root depending on iOS version; the tutorial does the rest.)
- After the user returns, `speechVoices()` reflects any newly downloaded voice on next read,
  so the voice picker just shows more rows. No special refresh handshake needed beyond
  re-reading the list when the picker appears.

---

## 7. Platform gotchas (read before implementing)

- **Voice quality is OS-dependent and Apple's voices cannot be bundled.** You ship zero
  audio; you rent the OS's synthesizer. Enhanced voices must be downloaded by the user. Plan
  the UX around "nudge toward the good voices," not "guarantee a good voice."
- **VoiceOver coexistence.** Suppress or fully defer to VoiceOver when it's running (§1.5).
- **Audio session ducking**, not interruption (§1.5) — respect the game-night playlist.
- **Interrupt-vs-drop discipline** so speech never lags behind or talks over live play (§1.5).
- **Locale & pronunciation.** Player names and category names are read by the synth as-is;
  odd pronunciations are acceptable and not worth authoring `AVSpeechSynthesisIPANotation`
  overrides for in 1.0.
- **No deep link to Voices** (§6.2). The tutorial sheet is the mitigation, not a fallback.
- **Silence in Play-by-Play must still breathe.** With everything on, back-to-back turns can
  chatter. The interrupt-lower-tier rule plus per-event `postUtteranceDelay` keeps it from
  becoming a wall of speech; tune by ear.

---

## 8. Interaction with existing systems

- **The Yatzy celebration (SyFive.md §6).** The visual/haptic Yatzy moment already exists.
  Commentary layers *on top* of it — the `yatzyRolled` line rides alongside the rim-light
  push-in, it does not replace it. Time the utterance to land just after the title card so
  they don't collide; a small `preUtteranceDelay` on that event or an emit-after-animation
  hook handles it.
- **Score audio & haptics (IMPLEMENTATION_STATUS.md).** All three consume the same event
  stream (§1.2). Building the event emit sites cleanly for commentary pays off for the score
  chime and score haptic work too — one set of turn-boundary events, three observers.
- **Multiplayer (already shipped).** `leadChange` and `winnerDeclared`/`winnerTie` are free
  because turn sequencing, leader tracking, and tie detection already exist.

---

## 9. Copy library — conventions

Below: **20+ variants per event, per personality.** Rules the copy follows:

- **TTS-friendly:** plain sentences, commas and periods, no parentheticals or symbols the
  synth mangles. No emoji, no ALL CAPS (the synth spells or over-emphasizes them).
- **Token use** stays within each event's exposed tokens (§2).
- **Speakable length:** short enough to finish before the next beat of play.
- **In character** per §4.
- **Snarky targets the roll/decision, never the person** (§11).

The copy is presented as reference lists; in code each becomes an entry in the pack's
`lines[eventKind]` array verbatim.

---

## 10. The copy

### 10.1 `yatzyRolled` — first five of a kind, +50 *(Celebration)*

**Sports**
1. Yatzy! {player} brings the house down!
2. Five of a kind! {player} rolls the perfect one, folks!
3. Are you kidding me? {player} nails the Yatzy!
4. That is a Yatzy for {player}, and the crowd goes wild!
5. Textbook! Five dice, one face, all {player}!
6. {player} calls their shot and delivers a Yatzy!
7. Oh, {player} dialed that one up! Yatzy on the board!
8. Five for five! {player} with the roll of the night!
9. Send it! {player} lands the Yatzy clean!
10. History right there, folks. {player} rolls a Yatzy!
11. {player} steps up and drops fifty on us. Yatzy!
12. Unbelievable scenes! Yatzy for {player}!
13. That is what a Yatzy looks like, courtesy of {player}!
14. Boom! {player} clears the whole board with five of a kind!
15. {player} with the dagger. Yatzy, ballgame energy!
16. Five matching dice for {player} and this table is electric!
17. {player} came to play. That is a Yatzy!
18. Perfect roll, perfect timing, all {player}. Yatzy!
19. Right on the money! {player} rolls the fifty-pointer!
20. And there it is! {player} joins the Yatzy club!
21. {player} just made this look easy. Yatzy!

**Zen**
1. Five dice, one mind. {player} finds the Yatzy.
2. Everything settles into place for {player}. A Yatzy.
3. {player} rolls, and the dice agree. Yatzy.
4. Stillness, then five of a kind. Well done, {player}.
5. The path opened for {player}. A quiet fifty.
6. All five aligned. {player} receives a Yatzy.
7. {player} lets go, and the dice arrive together.
8. A moment of harmony. Five faces, one for {player}.
9. No forcing, only flow. {player} lands the Yatzy.
10. {player} breathes, and the dice fall as one.
11. Five as one. {player} meets the Yatzy.
12. The dice found their center for {player}.
13. What is meant to arrive, arrives. {player}, a Yatzy.
14. {player} rolls with an open hand. Five of a kind.
15. Presence rewarded. {player} takes the fifty.
16. Calm hands, five faces. A Yatzy for {player}.
17. {player} and the dice, briefly, in perfect agreement.
18. The moment ripened. {player} gathers a Yatzy.
19. Five dice at rest, all the same. Peace, and a Yatzy, for {player}.
20. {player} did nothing extra, and everything worked. Yatzy.
21. A small miracle on the table. {player}, five of a kind.

**Steady**
1. Yatzy for {player}. Fifty points.
2. {player} rolls five of a kind. That's a Yatzy.
3. There it is. Yatzy, {player}.
4. Five matching dice. {player} takes the fifty.
5. {player} lands the Yatzy.
6. Clean five of a kind for {player}.
7. That's a Yatzy on the board for {player}.
8. {player} gets it. Fifty on the Yatzy.
9. Five of a kind, {player}. Nicely done.
10. Yatzy. Good roll, {player}.
11. {player} rolls the big one. Yatzy.
12. All five agree. Yatzy for {player}.
13. {player} scores the Yatzy. Fifty.
14. That'll do it. Yatzy, {player}.
15. {player} with five of a kind.
16. Fifty points, {player}. Yatzy.
17. {player} closes the Yatzy box in style.
18. Five faces, one number. {player} takes it.
19. Solid. Yatzy for {player}.
20. {player} rolls a Yatzy. On the board.
21. There's the fifty. Well rolled, {player}.

**Snarky**
1. A Yatzy. {player} is going to be insufferable now.
2. Five of a kind. The dice clearly like {player} better than the rest of us.
3. Oh good, a Yatzy. {player} will remind everyone of this for weeks.
4. {player} rolls a Yatzy. Statistically rude.
5. Five matching dice. {player} did that on purpose, apparently.
6. A Yatzy for {player}. The rest of the table would like to lodge a complaint.
7. Well. {player} just peaked. Downhill from here.
8. Five of a kind. {player}, save some luck for the others.
9. A Yatzy. Somewhere a probability textbook is crying.
10. {player} lands the Yatzy and acts like it was skill.
11. Fifty points, and {player} definitely called it. Sure.
12. Five dice, one face. {player} is officially unbearable.
13. A Yatzy. {player} would like everyone to remember this moment forever.
14. The dice rolled over for {player}. Traitors.
15. {player} gets a Yatzy. The others are handling it beautifully. Not.
16. Five of a kind. {player} earned it, or bribed the dice. Unclear.
17. Congratulations to {player}, and condolences to everyone else.
18. A Yatzy. Cool, cool, totally fine, no notes.
19. {player} rolls five of a kind and the group chat will never recover.
20. Well rolled, {player}. Nobody's jealous. Everyone's jealous.
21. A Yatzy for {player}. The dice have chosen a favorite and it isn't you, reader.

---

### 10.2 `yatzyBonusEarned` — additional five of a kind, +100 *(Celebration)*

**Sports**
1. Another one?! {player} with the bonus Yatzy, plus a hundred!
2. {player} is on fire! Back-to-back five of a kind!
3. Stop it! {player} rolls ANOTHER Yatzy! Hundred more!
4. The bonus is live and {player} is cashing it! A hundred points!
5. {player} does it again, folks! Bonus Yatzy!
6. Lightning strikes twice for {player}! Plus one hundred!
7. Who does that? {player} does that! Another Yatzy!
8. {player} just added a hundred like it was nothing!
9. Encore! {player} rolls the bonus five of a kind!
10. That's a second Yatzy for {player} and the booth is losing it!
11. {player} keeps rolling and the points keep coming! Hundred more!
12. Absolute heater from {player}! Bonus Yatzy on the board!
13. {player} is in the zone! Another hundred, another Yatzy!
14. Ridiculous! {player} stacks a bonus Yatzy!
15. The hot hand stays hot! {player}, plus one hundred!
16. {player} with the repeat performance! Bonus points!
17. Again?! {player} cannot be stopped! Another Yatzy!
18. Cash it in, {player}! A hundred-point bonus Yatzy!
19. {player} rolls a second five of a kind! Unreal!
20. The bonus banner is up! {player} adds one hundred!
21. {player} just turned this into a highlight reel!

**Zen**
1. Again, the dice align for {player}. A hundred more, received quietly.
2. The flow continues. {player} finds another five of a kind.
3. What began, continues. {player} takes the bonus.
4. {player} stays present, and the dice return. A hundred points.
5. No grasping, only more. {player} earns the bonus Yatzy.
6. The stream keeps flowing for {player}. Another hundred.
7. {player} rolls again, and again it is five as one.
8. Abundance, without effort. {player} gathers a hundred.
9. The moment repeats itself gently. {player}, a bonus Yatzy.
10. {player} remains calm, and the dice remain kind. Plus one hundred.
11. Once more the faces agree. Well done, {player}.
12. {player} does not chase it, and it comes anyway.
13. The wave carries {player} a little further. A hundred more.
14. Stillness, then five of a kind. Twice now, {player}.
15. {player} accepts the bonus as it is given.
16. What is flowing does not stop for {player}. Another hundred.
17. Balance holds. {player} rolls a second Yatzy.
18. {player} breathes, and a hundred points arrive.
19. The dice keep their promise to {player}. Bonus Yatzy.
20. Again, effortless. {player} takes the hundred.
21. {player} and fortune, still walking together.

**Steady**
1. Another Yatzy for {player}. Hundred-point bonus.
2. {player} rolls a second five of a kind. Plus one hundred.
3. Bonus Yatzy, {player}. That's a hundred.
4. {player} does it again. Hundred points.
5. Second five of a kind for {player}. Bonus counts.
6. {player} adds a hundred. Bonus Yatzy.
7. There's another one. {player}, plus a hundred.
8. {player} stacks a bonus Yatzy. Well rolled.
9. Another five of a kind. Hundred to {player}.
10. {player} earns the Yatzy bonus. A hundred.
11. Repeat Yatzy for {player}. Points on top.
12. {player} keeps it going. Bonus hundred.
13. That's two now for {player}. Plus one hundred.
14. {player} rolls the bonus. Hundred points.
15. Another Yatzy on the board. {player}, a hundred.
16. {player} adds to the tally. Bonus five of a kind.
17. Second Yatzy, {player}. Counted.
18. {player} takes the hundred-point bonus.
19. Bonus Yatzy for {player}. Solid.
20. {player} does it twice. A hundred more.
21. There's the bonus, {player}. Hundred points.

**Snarky**
1. Another Yatzy. {player} is just showing off now.
2. A second five of a kind. {player}, leave some for the class.
3. Oh, a bonus Yatzy. {player} definitely needed the extra hundred.
4. {player} rolls another one. The dice have a clear agenda.
5. Two Yatzys. {player} is writing a book about it as we speak.
6. Bonus hundred for {player}. The others are thrilled. Visibly.
7. Again? {player}, this is getting embarrassing for everyone else.
8. A repeat Yatzy. {player} has clearly made a deal with someone.
9. {player} adds a hundred. Somewhere, math is offended.
10. Another five of a kind. {player} is not even trying to be humble.
11. Two in a game. {player} will mention this at the funeral.
12. Bonus Yatzy. {player}, the dice are practically autographing themselves.
13. {player} does it again. The table's morale is doing great. Not.
14. A second hundred. {player} is basically cheating with permission.
15. Encore Yatzy for {player}. Nobody asked, but here we are.
16. {player} rolls another. The other players have questions.
17. Two Yatzys. {player} is one away from being challenged to a duel.
18. Bonus points for {player}. Skill, luck, or witchcraft. Pick one.
19. Another one. {player} is speedrunning smugness.
20. {player} stacks a hundred. The dice know exactly what they're doing.
21. A repeat Yatzy. Truly inspiring. Truly annoying. Both, {player}.

---

### 10.3 `winnerDeclared` — match complete, single winner *(Celebration)*
*Tokens: `{winner}`, `{runnerUp}`, `{score}`, `{margin}`. Lines work for any margin; a few
reference `{margin}` generically.*

**Sports**
1. That's the ballgame! {winner} takes it with {score}!
2. Final score, {winner} on top! What a performance!
3. {winner} wins it, folks! {score} points and a trophy!
4. Ballgame! {winner} holds off {runnerUp} for the title!
5. {winner} closes it out! Champion, right here!
6. It's over, and {winner} stands alone! {score} to win!
7. {winner} brings it home by {margin}! Sensational!
8. Your winner tonight, {winner}, with {score}!
9. {winner} seals the deal! {runnerUp} left in second!
10. Final horn! {winner} is your champion!
11. {winner} finishes strong and takes the crown!
12. What a run by {winner}! Winner, {score} points!
13. {winner} did it! Edging {runnerUp} for the win!
14. Game, set, match, {winner}! {score} on the board!
15. {winner} climbs to the top! Champion by {margin}!
16. And {winner} takes it! The comeback complete!
17. {winner} wins the night! Textbook finish!
18. Final tally, {winner} on top with {score}!
19. {winner} outlasts the field! Your winner!
20. Champagne for {winner}! The title is theirs!
21. {winner} closes the show! {score} and the win!

**Zen**
1. The game rests. {winner} arrives at the top, with {score}.
2. All turns complete. {winner} holds the highest score.
3. {winner} finishes gently ahead. {score} points.
4. The path led here. {winner}, this game is yours.
5. Nothing left to roll. {winner} settles into first.
6. {winner} and {runnerUp} both played well. Tonight, {winner} leads.
7. The dice are still. {winner} carries the game, by {margin}.
8. Completion. {winner} takes the win, softly.
9. {winner} reaches the summit without hurry. {score}.
10. The final rest. {winner} on top.
11. A good game, well played by all. {winner} first.
12. {winner} closes the circle with {score}.
13. Effort and ease, in balance. {winner} wins.
14. The game exhales. {winner}, the winner.
15. {winner} arrives where the game was going. First place.
16. All is scored. {winner} holds the lead, {score}.
17. {runnerUp} pressed close. {winner} kept the calm, and the win.
18. {winner} finishes present and steady. The game is theirs.
19. Peace on the table. {winner} takes it.
20. The last die settles. {winner} wins, by {margin}.
21. Well played, everyone. {winner}, the quiet victor.

**Steady**
1. {winner} wins with {score}.
2. Final score, {winner} on top.
3. That's the game. {winner} takes it.
4. {winner} wins it. {score} points.
5. Winner, {winner}. Well played.
6. {winner} finishes first, ahead of {runnerUp}.
7. Game over. {winner} wins by {margin}.
8. {winner} takes the win with {score}.
9. That's it. {winner} on top.
10. {winner} closes it out. Winner.
11. Final tally, {winner} first.
12. {winner} wins. {runnerUp} second.
13. {score} for {winner}. That's the win.
14. {winner} takes the game.
15. Game's done. {winner} wins by {margin}.
16. {winner} finishes on top. {score}.
17. Winner tonight, {winner}.
18. {winner} holds the lead to the end.
19. That's the match. {winner} wins.
20. {winner} first, {runnerUp} close behind.
21. Final: {winner}, {score}. Nicely done.

**Snarky**
1. {winner} wins. Everyone act surprised.
2. And the winner is {winner}, who will absolutely bring this up again.
3. {winner} takes it by {margin}. {runnerUp} is fine. {runnerUp} is totally fine.
4. Congratulations, {winner}. The dice apologize to everyone else.
5. {winner} wins with {score}. A number they will have tattooed by morning.
6. It's over. {winner} won, and now we all have to hear about it.
7. {winner} on top. {runnerUp}, so close, which is somehow worse.
8. Winner, {winner}. Please contain your gloating. You won't.
9. {winner} takes it. The rematch demands are already forming.
10. {winner} wins by {margin}. Rounding up, that's a lot.
11. And {winner} closes it out. Humble in victory. Kidding. Not humble.
12. {winner} first. The dice have spoken and they were extremely biased.
13. {score} for the win. {winner} peaked at the perfect time. Annoying.
14. {winner} wins. {runnerUp} led for a while, which they'll mention forever.
15. Victory for {winner}. Everyone clap, some of you mean it.
16. {winner} takes the crown. It's a paper one, but still.
17. Game over. {winner} won. Physics remains undefeated.
18. {winner} on top by {margin}. Screenshot it, they will.
19. And that's a win for {winner}. The trash talk starts in three, two, one.
20. {winner} wins. {runnerUp} played great and lost anyway. Delightful.
21. Your champion, {winner}, who definitely won't rig the next one. Probably.

---

### 10.4 `winnerTie` — match complete, tie at the top *(Celebration)*
*Tokens: `{winner}` (comma-joined names), `{score}`. Rarer event; a focused set of 14.*

**Sports**
1. We've got a tie! {winner}, deadlocked at {score}!
2. Photo finish, folks! {winner} share the top!
3. No separation! {winner} tied at {score}!
4. Dead heat! {winner} both on top!
5. Unbelievable, a tie! {winner} split the crown!
6. Nobody blinks! {winner} finish level at {score}!
7. It's all square! {winner} tied for the win!
8. What a finish! {winner} can't be separated!
9. Even Steven! {winner} share it at {score}!
10. A tie for the ages! {winner} both champions!
11. Deadlocked! {winner} tied to the point!
12. They match to the number! {winner}, {score} apiece!
13. No winner alone tonight! {winner} share it!
14. A draw! {winner} both walk away on top!

**Zen**
1. Two paths, one summit. {winner} arrive together, at {score}.
2. A tie. {winner} share the game, and the peace.
3. No one ahead, no one behind. {winner}, level at {score}.
4. Balance itself. {winner} finish as equals.
5. The game holds no single winner. {winner} share it.
6. {winner} meet at the same place. {score} each.
7. Perfect symmetry. {winner} tied.
8. Neither above the other. {winner} rest as one.
9. A shared summit for {winner}. {score}.
10. The dice divided nothing. {winner} tie.
11. Equal effort, equal end. {winner}, together at {score}.
12. {winner} arrive side by side. A gentle tie.
13. No division tonight. {winner} share the win.
14. Stillness, and a tie. {winner}, both first.

**Steady**
1. It's a tie. {winner}, both at {score}.
2. {winner} finish level. {score} each.
3. Tie game. {winner} share the top.
4. {winner} tied at {score}.
5. No single winner. {winner} split it.
6. Even score. {winner} both first.
7. That's a tie, {winner}.
8. {winner} match at {score}.
9. Dead even. {winner} share the win.
10. {winner} tie it out. {score} apiece.
11. Same score. {winner}, both on top.
12. It's level. {winner} tied.
13. {winner} finish tied. {score}.
14. A draw. {winner} share it.

**Snarky**
1. A tie. Nobody wins, everybody argues.
2. {winner} tied at {score}. A rematch is now legally required.
3. It's a draw. {winner} will each claim they really won.
4. {winner} finish level. The universe declines to pick a favorite.
5. A tie. {winner}, please resolve this outside.
6. Deadlocked at {score}. {winner} both insufferable, equally.
7. {winner} tied. The dice took the coward's way out.
8. A draw. {winner} share the trophy, which is one trophy. Good luck.
9. {winner} match exactly. Somebody count again, surely.
10. It's even. {winner} both win, which means nobody gets to gloat properly.
11. A tie. {winner}, this is the worst possible outcome for peace.
12. {winner} at {score} apiece. Sudden death is the only civilized option.
13. Level game. {winner} will litigate this for years.
14. A tie. Congratulations to {winner}, and to chaos.

---

### 10.5 `upperBonusEarned` — upper section hits 63, +35 *(Highlight)*

**Sports**
1. {player} locks in the upper bonus! Thirty-five more!
2. There's the bonus! {player} cracks sixty-three!
3. {player} does the upper work and cashes in! Plus thirty-five!
4. Bonus secured! {player} banks the thirty-five!
5. {player} grinds it out and gets the upper bonus!
6. Smart play by {player}! The bonus is theirs!
7. {player} hits the number! Thirty-five-point bonus!
8. Upper section, handled! {player} takes the bonus!
9. {player} punches the ticket! Bonus points on the board!
10. That's the bonus for {player}! The fundamentals pay off!
11. {player} clears sixty-three and pockets thirty-five!
12. Bonus in the bank for {player}!
13. {player} plays it right and gets rewarded! Upper bonus!
14. There it is, the thirty-five! Nice work, {player}!
15. {player} secures the upper bonus like a pro!
16. Ballgame fundamentals from {player}! Bonus earned!
17. {player} tops the threshold! Thirty-five, please!
18. The upper bonus belongs to {player}!
19. {player} closes the upper section in style! Bonus!
20. Thirty-five points, courtesy of {player}'s discipline!

**Zen**
1. Patience rewarded. {player} earns the upper bonus.
2. {player} tended the small numbers, and the bonus arrived.
3. Steady work brings its gift. {player}, thirty-five points.
4. {player} reaches sixty-three, and the bonus follows.
5. Nothing rushed. {player} gathers the upper bonus.
6. The quiet effort pays. {player} takes the thirty-five.
7. {player} kept to the path, and the path gave back.
8. Small stones build the wall. {player} earns the bonus.
9. {player} arrives at sixty-three, gently. Bonus received.
10. The upper section, complete for {player}. Thirty-five.
11. {player} planted early and harvests now.
12. Attention to the little things. {player}, the bonus is yours.
13. {player} let the numbers add themselves. Bonus earned.
14. Diligence, made visible. {player} takes the thirty-five.
15. {player} crosses the threshold with ease. Bonus.
16. The upper bonus settles on {player}, well deserved.
17. {player} kept the balance up top, and it held. Bonus.
18. Slow and sure, {player} claims the thirty-five.
19. {player} finishes the upper work in peace.
20. Sixty-three, and beyond. {player} receives the bonus.

**Steady**
1. {player} earns the upper bonus. Thirty-five.
2. Upper bonus for {player}. Plus thirty-five.
3. {player} clears sixty-three. Bonus counts.
4. That's the bonus, {player}. Thirty-five points.
5. {player} banks the upper bonus.
6. Sixty-three reached. {player} takes thirty-five.
7. {player} gets the upper bonus. Good.
8. Upper section done. {player}, plus thirty-five.
9. {player} hits the threshold. Bonus.
10. Thirty-five to {player}. Upper bonus.
11. {player} secures the bonus. Nicely managed.
12. There's the bonus. {player}, thirty-five.
13. {player} tops sixty-three. Bonus earned.
14. Upper bonus, {player}. On the board.
15. {player} takes the thirty-five.
16. Bonus counted for {player}.
17. {player} finishes the upper section with the bonus.
18. That threshold's cleared. {player}, plus thirty-five.
19. {player} earns it. Upper bonus.
20. Thirty-five points. Well played, {player}.

**Snarky**
1. {player} got the upper bonus. Someone read the rules.
2. Thirty-five bonus points for {player}. The nerds call this strategy.
3. {player} cleared sixty-three. Suspiciously competent.
4. Upper bonus for {player}. Playing to win, are we.
5. {player} banks the thirty-five. Look who did their homework.
6. The bonus goes to {player}, who apparently planned ahead. Show-off.
7. {player} hit sixty-three. That's a lot of ones and twos of patience.
8. Bonus secured. {player} is taking this seriously now.
9. {player} gets thirty-five for good behavior. Rare.
10. Upper bonus, {player}. The tortoise strategy pays off.
11. {player} managed the boring section and got paid. Fine, well done.
12. Thirty-five points for {player}'s spreadsheet energy.
13. {player} cleared the threshold. Somebody's competitive.
14. The bonus lands with {player}, who definitely counted first.
15. {player} earns thirty-five. The upper section's revenge.
16. Upper bonus for {player}. Discipline. Gross.
17. {player} hit sixty-three exactly, probably on purpose. Menace.
18. Thirty-five bonus. {player} is playing chess, we're playing checkers.
19. {player} got the bonus and a smug little nod, no doubt.
20. Bonus points, {player}. The math homework paid off after all.

---

### 10.6 `yatzyScratched` — the Yatzy box scored 0, the poisoned box *(Highlight)*

**Sports**
1. Ohh, {player} scratches the Yatzy! No bonus insurance now!
2. Big swing! {player} zeroes out the Yatzy box!
3. That's a scratch on the Yatzy for {player}! Gutsy or grim, you decide!
4. {player} takes a zero on the Yatzy! The bonus door slams shut!
5. Yikes! {player} lets the Yatzy go for nothing!
6. {player} scratches the fifty-pointer! No safety net!
7. There goes the Yatzy box, zeroed by {player}!
8. {player} eats a zero up top! No more bonus chances!
9. Tough break, folks! {player} scratches the Yatzy!
10. {player} writes a zero where fifty could've been!
11. The Yatzy box is dead for {player}! Scratched!
12. {player} sacrifices the Yatzy! High-stakes stuff!
13. Zero on the Yatzy! {player} closes that door!
14. {player} scratches it! No bonus Yatzy in this player's future!
15. Painful! {player} takes nothing on the Yatzy!
16. {player} zeroes the big box! The gamble is on!
17. That's a scratch, {player}! The Yatzy's off the table!
18. {player} lets the fifty slip to zero!
19. No Yatzy for {player} tonight! Scratched clean!
20. {player} poisons the box! Zero on the Yatzy!

**Zen**
1. {player} releases the Yatzy, and takes nothing. Sometimes we let go.
2. A zero on the Yatzy. {player} chooses to release the fifty.
3. {player} scratches the box. What is empty stays empty. It is enough.
4. Not every door opens. {player} sets the Yatzy aside.
5. {player} accepts a zero. Attachment released.
6. The Yatzy passes by. {player} does not grasp it.
7. {player} lets the fifty go without regret. Or with some. That is honest.
8. A scratch. {player} makes peace with the empty box.
9. {player} closes the Yatzy quietly. No bonus will come. So it is.
10. Sometimes the roll asks for a sacrifice. {player} gives the Yatzy.
11. {player} takes the zero, and breathes. The game continues.
12. What could have been fifty becomes zero. {player} accepts it.
13. {player} scratches the box. Loss, held lightly.
14. The Yatzy is released by {player}. Onward, gently.
15. {player} lets it be zero. There is freedom in that too.
16. No Yatzy this game for {player}. The board narrows. Notice it.
17. {player} surrenders the fifty. A small letting-go.
18. The box empties by choice. {player} moves on.
19. {player} scratches the Yatzy, and the mind stays calm.
20. Zero, chosen freely by {player}. Even loss can be clean.

**Steady**
1. {player} scratches the Yatzy. Zero.
2. Zero on the Yatzy box for {player}.
3. {player} takes a zero up top. No Yatzy.
4. That's a scratch, {player}. Yatzy's gone.
5. {player} zeroes the Yatzy. No bonus after this.
6. Yatzy scratched. {player}, zero points there.
7. {player} lets the Yatzy go. Zero.
8. Zero in the Yatzy box. {player}'s call.
9. {player} scratches it. No bonus insurance now.
10. That box is closed at zero. {player}.
11. {player} takes nothing on the Yatzy.
12. Yatzy scratched to zero by {player}.
13. {player} zeroes the big box. Noted.
14. No Yatzy for {player}. Scratched.
15. {player} writes a zero on the Yatzy.
16. That's the Yatzy gone, {player}. Zero.
17. {player} closes the Yatzy at zero.
18. Zero it is. {player} scratches the Yatzy.
19. {player} passes on the fifty. Zero.
20. Yatzy box, zero. {player}.

**Snarky**
1. {player} scratched the Yatzy. Bold. Reckless. Both.
2. A zero on the Yatzy. {player} lives dangerously.
3. {player} just poisoned the box. No takebacks, no bonus, no mercy.
4. And {player} scratches the Yatzy. Future self will love that.
5. Zero on the fifty-pointer. {player} plays fast and loose.
6. {player} sacrifices the Yatzy. The dice noted your address.
7. A scratch. {player} said no thank you to a hundred future points.
8. {player} zeroes the Yatzy box. Chaos reigns.
9. {player} scratched it. Somewhere a strategy guide fainted.
10. Zero on the Yatzy. {player} is either a genius or not. Not.
11. {player} closes the bonus door and throws away the key.
12. A poisoned box, courtesy of {player}. Live footage of a decision.
13. {player} scratches the Yatzy. The other players say nothing. They're thrilled.
14. Zero. {player} gambled the fifty and the house always remembers.
15. {player} just gave up the Yatzy. Confidence or panic. We'll never know.
16. The Yatzy box, zeroed by {player}. Fortune favors the... not this.
17. {player} scratched it. Somewhere, a math teacher wept.
18. A zero on the Yatzy. {player} enjoys living without a safety net.
19. {player} poisons the box. The dice will absolutely hold a grudge.
20. Scratched. {player}, that's going to be a fun one to explain later.

---

### 10.7 `bigTurn` — high-value category scored (Large Straight / Full House / big number) *(Highlight)*
*Tokens: `{player}`, `{category}`, `{value}`.*

**Sports**
1. {player} drops a {category} for {value}! Big points!
2. That's a {category}! {player} banks {value}!
3. {player} with the {category}, worth {value}!
4. Huge turn! {player} scores {value} on the {category}!
5. {player} cashes the {category}! {value} on the board!
6. Order up! {player} completes the {category} for {value}!
7. {player} nails the {category}! That's {value}, folks!
8. Big number from {player}! {category}, {value} points!
9. {player} lines up the {category}! {value}!
10. There's the {category} for {player}! {value} points!
11. {player} delivers the {category}! {value} banked!
12. Textbook {category} by {player}! {value}!
13. {player} strikes gold! {category} for {value}!
14. {player} loads up the {category}! {value} points!
15. Momentum swing! {player} scores {value} on the {category}!
16. {player} with a statement {category}! {value}!
17. That'll move the needle! {player}, {category}, {value}!
18. {player} takes the {category} and runs! {value}!
19. Big-time roll! {player} banks {value} with the {category}!
20. {player} finishes the {category} in style! {value}!

**Zen**
1. {player} completes the {category}. {value} points, arriving in order.
2. The pattern reveals itself. {player}, a {category} for {value}.
3. {player} lets the dice fall into place. {category}, {value}.
4. Form emerges. {player} scores {value} on the {category}.
5. {player} finds the {category}. {value}, without strain.
6. A shape completed. {player} takes {value}.
7. {player} gathers the {category}, worth {value}. Well seen.
8. The dice arrange themselves for {player}. {category}, {value}.
9. {player} scores the {category}. {value} points, quietly earned.
10. Everything in sequence. {player}, {value} on the {category}.
11. {player} sees the pattern and takes it. {value}.
12. A {category} for {player}. {value}, received.
13. {player} completes the shape. {value} points.
14. The right pieces, in the right places. {player}, {value}.
15. {player} claims the {category}, worth {value}. Steady work.
16. Balance on the board. {player} scores {value}.
17. {player} finishes the {category} with a calm hand. {value}.
18. Order from the roll. {player}, {value} points.
19. {player} takes the {category}. {value}, no fuss.
20. The dice cooperate. {player} banks {value} on the {category}.

**Steady**
1. {player} scores the {category}. {value} points.
2. {category} for {player}. {value}.
3. {player} takes {value} on the {category}.
4. That's a {category}, {player}. {value}.
5. {player} banks the {category}. {value} points.
6. {value} for {player}. Nice {category}.
7. {player} completes the {category}. {value}.
8. Good turn. {player} scores {value}.
9. {player} lands the {category} for {value}.
10. {category}, {value}. Well played, {player}.
11. {player} adds {value} with the {category}.
12. That's {value} for {player}. {category}.
13. {player} takes the {category}. {value} on the board.
14. Solid {category} from {player}. {value}.
15. {player} scores {value}. Good spot.
16. {category} banked. {player}, {value}.
17. {player} moves up with a {category}. {value}.
18. {value} points, {player}. {category}.
19. {player} handles the {category}. {value}.
20. Nice one, {player}. {category} for {value}.

**Snarky**
1. {player} scores a {category} for {value}. Look at that, actual competence.
2. A {category} worth {value}. {player} is trying now. Concerning.
3. {player} banks {value} on the {category}. Suspiciously well played.
4. {value} points on the {category}. {player} means business, apparently.
5. {player} lands the {category}. {value}. Beginner's luck? Rude either way.
6. A big {category} from {player}. The rest of you might want to wake up.
7. {player} takes {value}. That {category} won't shut up about itself.
8. {category} for {value}. {player} is making the rest look decorative.
9. {player} scores {value}. The dice are cooperating a little too eagerly.
10. A {category}, {value} points. {player} found the good roll. Hoarding, really.
11. {player} banks the {category}. {value}. Someone's feeling themselves.
12. {value} on the {category}. {player}, save some points for the others.
13. {player} completes the {category}. {value}. Textbook. Insufferably so.
14. A {category} worth {value}. {player} is climbing. Ugh, effective.
15. {player} takes {value}. The {category} gods smiled. Favoritism, clearly.
16. {value} points, {player}. That {category} is going straight to your head.
17. {player} scores the {category}. {value}. Fine. That was good. Don't gloat.
18. A tidy {category} for {value}. {player} is peaking suspiciously well.
19. {player} banks {value}. The {category} came easy. Some people have all the luck.
20. {value} on the {category}. {player} is quietly running away with this. Quietly.

---

### 10.8 `leadChange` — a new player takes sole possession of the lead *(Highlight)*
*Tokens: `{leader}`, `{runnerUp}`.*

**Sports**
1. New leader! {leader} surges past {runnerUp}!
2. And {leader} takes the lead! What a swing!
3. {leader} moves to the front! {runnerUp} bumped to second!
4. Lead change! {leader} is your new front-runner!
5. {leader} storms into first! {runnerUp} gives chase!
6. There's the swing! {leader} on top now!
7. {leader} grabs the lead from {runnerUp}!
8. The order flips! {leader} leads!
9. {leader} vaults ahead! {runnerUp} in the rearview!
10. New number one! {leader} takes command!
11. {leader} snatches the lead! Game on!
12. {runnerUp} yields the top spot to {leader}!
13. {leader} is out front! The race is heating up!
14. And just like that, {leader} leads!
15. {leader} overtakes {runnerUp}! Momentum shift!
16. The lead is {leader}'s now! Big move!
17. {leader} pulls to the front! Watch out, {runnerUp}!
18. Changing of the guard! {leader} on top!
19. {leader} takes over first place!
20. {runnerUp} led, but now it's all {leader}!

**Zen**
1. The lead shifts, softly. {leader} moves ahead of {runnerUp}.
2. {leader} rises to the front. The game breathes and changes.
3. Nothing stays fixed. {leader} now leads.
4. {leader} steps ahead of {runnerUp}. The current turns.
5. The tide comes in for {leader}. First place, for now.
6. {leader} takes the lead, and holds it lightly.
7. Positions flow. {leader} ahead, {runnerUp} close.
8. {leader} moves forward. All places are temporary.
9. The front belongs to {leader} in this moment.
10. {leader} passes {runnerUp}. The river keeps moving.
11. A gentle shift. {leader} now leads.
12. {leader} rises without pushing. First place.
13. The lead changes hands, calmly. {leader} in front.
14. {leader} ahead now. {runnerUp} need not worry. It flows both ways.
15. {leader} takes the top, for as long as it lasts.
16. The game turns toward {leader}. First place.
17. {leader} steps into the lead, quietly.
18. Ahead and behind trade places. {leader} leads.
19. {leader} moves to first. Nothing is settled yet.
20. The lead rests with {leader} now. Watch it change again.

**Steady**
1. {leader} takes the lead. {runnerUp} to second.
2. New leader. {leader} in front.
3. {leader} moves ahead of {runnerUp}.
4. Lead change. {leader} on top.
5. {leader} is first now.
6. {leader} passes {runnerUp}. New leader.
7. That puts {leader} in the lead.
8. {leader} takes over first place.
9. {leader} ahead. {runnerUp} close.
10. Lead's changed. {leader} in front.
11. {leader} moves to first.
12. {runnerUp} drops to second. {leader} leads.
13. {leader} is out front now.
14. New front-runner. {leader}.
15. {leader} takes the top spot.
16. {leader} leads. {runnerUp} second.
17. That's a lead change. {leader}.
18. {leader} is first. Game's tightening.
19. {leader} in the lead now.
20. {leader} moves ahead. Noted.

**Snarky**
1. {leader} takes the lead. {runnerUp} did not care for that.
2. New leader, {leader}. The peace was nice while it lasted.
3. {leader} passes {runnerUp}. Betrayal, honestly.
4. And {leader} grabs the lead. {runnerUp} is fine. {runnerUp} is seething.
5. {leader} in front now. {runnerUp} would like a word.
6. Lead change. {leader} on top, and loving it too much.
7. {leader} overtakes {runnerUp}. The alliance is over.
8. {leader} takes first. {runnerUp}, that spot was warm.
9. {leader} leads now. Screenshot it, it won't last.
10. {runnerUp} loses the lead to {leader}. Awkward at the table.
11. {leader} muscles ahead. {runnerUp} is drafting a strongly worded rebuttal.
12. New number one, {leader}. {runnerUp} has entered their villain arc.
13. {leader} takes the lead. Enjoy the view, it's a rental.
14. {leader} ahead of {runnerUp} now. The tension is delicious.
15. {leader} steals first. {runnerUp} remembers this.
16. And {leader} leads. {runnerUp} would like to speak to the dice's manager.
17. {leader} up front. {runnerUp} pretending not to mind. Failing.
18. {leader} takes over. {runnerUp}, welcome to second.
19. {leader} leads now, briefly, probably, we'll see.
20. {leader} passes {runnerUp}. Somewhere a friendship strains.

---

### 10.9 `turnStart` — a player's turn begins *(Play-by-Play)*

**Sports**
1. {player} steps up to the tray!
2. Here comes {player}!
3. {player} is on the clock!
4. Up next, {player}!
5. {player} takes the dice!
6. It's {player}'s turn, folks!
7. {player} ready to roll!
8. All eyes on {player}!
9. {player} at the table!
10. Here's {player}!
11. {player} to the dice!
12. {player}'s up!
13. Let's see what {player} has!
14. {player} takes their shot!
15. The dice are {player}'s!
16. {player} on deck and rolling!
17. Over to {player}!
18. {player} enters the arena!
19. {player} steps in!
20. Time for {player}!

**Zen**
1. {player}'s turn. Breathe, then roll.
2. The dice come to {player}.
3. It is {player}'s moment now.
4. {player} takes the dice, gently.
5. Whenever you're ready, {player}.
6. The turn passes to {player}.
7. {player}, the table is yours.
8. Now {player}. No hurry.
9. {player} arrives at their turn.
10. The dice rest, waiting for {player}.
11. {player}, take your time.
12. A new turn opens for {player}.
13. {player} steps in, calm.
14. The moment is {player}'s.
15. {player}, roll when the mind is still.
16. Over to {player}, softly.
17. {player} receives the dice.
18. Presence, please, {player}. Your turn.
19. {player}'s turn begins.
20. The dice belong to {player} now.

**Steady**
1. {player}'s turn.
2. Up next, {player}.
3. {player}, you're up.
4. Over to {player}.
5. {player} takes the dice.
6. {player} rolls next.
7. It's {player}'s turn.
8. {player}, go ahead.
9. Now {player}.
10. {player} to roll.
11. {player}'s up.
12. Next is {player}.
13. {player} at the tray.
14. Your turn, {player}.
15. {player} takes over.
16. Here's {player}.
17. {player}, whenever you're ready.
18. Dice to {player}.
19. {player} steps up.
20. Turn goes to {player}.

**Snarky**
1. {player}'s turn. Try to make it count.
2. Up next, {player}. No pressure. Some pressure.
3. {player}, the dice await your questionable decisions.
4. It's {player}'s turn. Let's see the strategy. Or lack of.
5. {player} takes the dice. Good luck, you'll need it.
6. Over to {player}. The bar is low, clear it.
7. {player}, your moment to disappoint the dice.
8. {player}'s up. Fingers crossed, everyone.
9. Now {player}. Whenever the confidence arrives.
10. {player} rolls next. This should be interesting. Or not.
11. {player}, the tray is yours. Handle it.
12. Turn's yours, {player}. Don't overthink it, you will.
13. {player} steps up. Bold of you.
14. Here's {player}, live and probably unprepared.
15. {player}'s turn. The dice have low expectations.
16. Go on then, {player}. Amaze us. Or don't.
17. {player} takes over. History is watching, sort of.
18. {player}, roll the dice and pray.
19. Up you go, {player}. We believe in you. Mostly.
20. It's {player}'s turn. Set your expectations accordingly.

---

### 10.10 `categoryScored` — routine category scored *(Play-by-Play)*
*Tokens: `{player}`, `{category}`, `{value}`.*

**Sports**
1. {player} takes {value} on the {category}.
2. {category} for {player}, {value} points.
3. {player} banks {value} there.
4. On the board, {value} for {player}.
5. {player} scores the {category}. {value}.
6. That's {value} for {player}.
7. {player} plays the {category}. {value}.
8. {value} points, {player}!
9. {player} logs {value} on the {category}.
10. Solid, {value} for {player}.
11. {player} adds {value}.
12. {category}, {value}. {player} keeps moving.
13. {player} puts up {value}.
14. {value} in the books for {player}.
15. {player} takes care of the {category}. {value}.
16. Points for {player}, {value}!
17. {player} chalks up {value}.
18. That's the {category}, {value}, {player}.
19. {player} moves the total. {value}.
20. {value} more for {player}!

**Zen**
1. {player} takes {value} on the {category}. Onward.
2. The {category}, filled. {player}, {value}.
3. {player} places {value}, calmly.
4. A quiet {value} for {player}.
5. {player} scores the {category}. {value} points.
6. {value} added, without fuss. {player}.
7. {player} completes the {category}. {value}.
8. The board grows by {value}. {player}.
9. {player} sets down {value}, gently.
10. {category}, {value}. {player} moves on.
11. {player} takes what the roll offered. {value}.
12. A small step forward for {player}. {value}.
13. {player} fills the {category}. {value}.
14. {value} points, received. {player}.
15. {player} scores, no need for more. {value}.
16. The {category} settles at {value}. {player}.
17. {player} adds {value} and lets it be.
18. {value} for {player}. Enough for now.
19. {player} places the {category}. {value}.
20. A steady {value} for {player}.

**Steady**
1. {player} scores {value} on the {category}.
2. {category}, {value}. {player}.
3. {player} takes {value}.
4. {value} for {player}.
5. {player} fills the {category}. {value}.
6. That's {value}, {player}.
7. {player} logs the {category}. {value}.
8. {value} on the board. {player}.
9. {player} adds {value}.
10. {category} for {value}. {player}.
11. {player} scores there. {value}.
12. {value} points, {player}.
13. {player} takes the {category}. {value}.
14. Noted, {value} for {player}.
15. {player} moves up {value}.
16. {value}, {player}. {category}.
17. {player} handles the {category}. {value}.
18. That's {value} added. {player}.
19. {player} scores {value}.
20. {value} for {player}, {category}.

**Snarky**
1. {player} takes {value} on the {category}. Bold choice. We'll allow it.
2. {value} for the {category}. {player} is playing it safe. Yawn.
3. {player} scores {value}. Riveting stuff.
4. The {category} for {value}. {player} shrugs and moves on.
5. {value} points, {player}. Groundbreaking.
6. {player} fills the {category}. {value}. Adequate.
7. That's {value}, {player}. The crowd is stunned. Not.
8. {player} banks {value}. Living on the edge, clearly.
9. A {category} for {value}. {player} keeps the dream barely alive.
10. {value} points. {player}, you had to score somewhere.
11. {player} takes the {category}. {value}. Sure, why not.
12. {value} for {player}. Every little bit helps. Barely.
13. The {category}, {value}. {player} settles.
14. {player} logs {value}. The suspense is underwhelming.
15. {value} on the {category}. {player} plays the percentages. Cowardly.
16. {player} scores {value}. History will not remember this.
17. A {value} for {player}. Points are points, allegedly.
18. {player} takes {value} and calls it a day.
19. {value}, {player}. That'll... do something.
20. The {category} for {value}. {player} soldiers on. Barely.

---

### 10.11 `categoryScratched` — a non-Yatzy category scored 0 by choice *(Play-by-Play)*
*Tokens: `{player}`, `{category}`.*

**Sports**
1. {player} scratches the {category}. Zero there.
2. Nothing on the {category} for {player}.
3. {player} takes a zero on the {category}.
4. That's a scratch, {player}. {category}, zero.
5. {player} lets the {category} go.
6. Zero on the {category} for {player}.
7. {player} eats a goose egg on the {category}.
8. No points on the {category}, {player}.
9. {player} writes off the {category}.
10. A scratch on the {category} for {player}.
11. {player} zeroes the {category}.
12. {category}, zero. Tough one, {player}.
13. {player} sacrifices the {category}.
14. Nothing doing on the {category} for {player}.
15. {player} clears the {category} at zero.
16. Zero there, {player}. On to the next.
17. {player} bites the bullet on the {category}.
18. Scratch on the {category}, {player}.
19. {player} takes nothing on the {category}.
20. {category} goes empty for {player}.

**Zen**
1. {player} releases the {category}. Zero. It is fine.
2. A zero on the {category}. {player} lets it pass.
3. {player} sets the {category} aside, empty.
4. Not this one. {player} scratches the {category}.
5. {player} takes nothing, and takes it well.
6. The {category} goes to zero. {player} moves on.
7. {player} lets the {category} be empty. No harm.
8. A quiet zero for {player} on the {category}.
9. {player} releases the {category}. Onward.
10. Nothing here. {player} accepts the {category} as zero.
11. {player} scratches gently. {category}, zero.
12. Some rolls ask for nothing. {player} scratches the {category}.
13. {player} lets the {category} go without a fight.
14. A zero, chosen. {player} clears the {category}.
15. {player} makes peace with an empty {category}.
16. The {category} rests at zero. {player} continues.
17. {player} gives up the {category}, calmly.
18. Not every box fills. {player} scratches the {category}.
19. {player} takes the zero on the {category}, lightly.
20. An empty {category} for {player}. Enough said.

**Steady**
1. {player} scratches the {category}. Zero.
2. Zero on the {category}, {player}.
3. {player} takes nothing there.
4. {category}, zero. {player}.
5. {player} zeroes the {category}.
6. That's a scratch, {player}.
7. {player} lets the {category} go. Zero.
8. No points on the {category}. {player}.
9. {player} clears the {category} at zero.
10. Zero there for {player}.
11. {player} scratches the {category}.
12. {category} goes empty. {player}.
13. {player} takes a zero on the {category}.
14. Nothing on the {category}, {player}.
15. {player} writes off the {category}.
16. Zero, {player}. {category}.
17. {player} passes on the {category}. Zero.
18. That box is zero. {player}.
19. {player} scratches it. {category}.
20. Empty {category} for {player}.

**Snarky**
1. {player} scratches the {category}. That'll haunt them.
2. Zero on the {category}. {player} had bigger plans, clearly.
3. {player} takes a zero. Strategic. Allegedly.
4. A scratch on the {category}. {player} is gambling with the math.
5. {player} zeroes the {category}. Bold. Or panicked. Coin flip.
6. Nothing on the {category}. {player} will feel that later.
7. {player} sacrifices the {category}. The dice send their regards.
8. Zero there, {player}. Chalk it up to confidence.
9. {player} lets the {category} go. Future {player} is furious.
10. A goose egg on the {category}. {player} plays chess. Badly.
11. {player} scratches the {category}. Living the dream, minus points.
12. Zero. {player} decided the {category} was optional. It wasn't.
13. {player} clears the {category} at nothing. Efficient way to lose.
14. A scratch. {player}, the {category} deserved better.
15. {player} takes zero on the {category}. Somewhere a coach sighs.
16. Nothing on the {category}. {player} is manifesting a comeback. Good luck.
17. {player} zeroes it. The {category} will be missed. By the scoreboard.
18. A scratch, {player}. Bold to just give points away.
19. {player} passes on the {category}. Points are for other people, apparently.
20. Zero on the {category}. {player} is really committing to the bit.

---

## 11. Brand guardrails — the snark boundary

Snarky is the risky pack, and the guardrails are non-negotiable:

- **Target the roll, the dice, the decision, the luck — never the person.** "That Chance was
  a choice" is fine; anything about a player *as a person* (their intelligence, worth, looks)
  is the mean-Vegas energy the whole app exists to avoid. Every line in §10 Snarky is aimed at
  dice or decisions; keep future lines the same.
- **Rib everyone, favor no one.** Snark that consistently punches at the same player becomes
  bullying-by-RNG. Because targets are random per event, this mostly self-balances — keep it
  that way; never let copy assume who's "the loser."
- **Kind under the wit.** The read should be a friend who teases, not a heckler. When in
  doubt, dial toward affectionate.
- **Snark never leaves the live commentary room.** It must never bleed into Player Insights,
  history, or stats, which are locked neutral-to-affirming
  (`04_PLAYER_INSIGHTS_DESIGN.md`). Live banter and private self-review are different
  contexts. The commentary engine writes to the speaker, never to any stored player-facing
  read.
- **All four packs stay non-casino.** No slot-machine language, no "jackpot," no fake
  urgency, even in Sports. Sports is a *sportscaster*, not a Vegas floor.

---

## 12. Open decisions for Pops

1. **The fourth pack's name.** Spec uses **Steady**. Alternatives: *Classic* (clearest to
   users), *Plain*, *The Booth*. Your call. 
   Yes, use Steady
2. **Voice ID storage scope.** Recommendation: **voice ID device-local** (UserDefaults);
   **level + personality sync** (SwiftData). This follows the §7 data-model principle and
   avoids pointing at a voice that isn't installed on another device. Confirm, or choose to
   sync everything and accept graceful fallback. 
   Agreed
3. **Sample/preview line source.** Spec uses a dedicated `previewLine` per pack so the
   preview reliably showcases character. Confirm that over "preview a random event line."
   Yes, sample/preview line per back
4. **Interrupt policy fine-tuning.** Spec says higher-tier interrupts, same-or-lower drops.
   Confirm that's the feel you want at the *Play-by-Play* level, where it matters most, or
   whether you'd prefer everything to always finish (risking talk-over).
   Interruptions are fine, and better, no need to wait for the snark if you dont want to
5. **Yatzy-moment timing.** Confirm the `yatzyRolled` utterance should land *after* the
   existing title-card animation rather than during it (spec assumes after).
   Agreed

---

## 13. Definition of Done

- [ ] Master toggle **off by default**; no engine instantiated when off.
- [ ] Level control: Celebrations / Highlights / Play-by-Play, gating by tier.
- [ ] Four personality packs present, each purely a `lines` dictionary + prosody row +
      blurb + preview line — **no engine code per pack.**
- [ ] 20+ variants per event kind per pack (14+ for the rarer `winnerTie`), with a
      no-immediate-repeat selection rule.
- [ ] Voice picker lists installed voices, flags Enhanced/Premium, previews per voice.
- [ ] Preview button speaks selected voice + selected personality + pack prosody.
- [ ] "Add more voices" sheet: tutorial of the Settings path + Open Settings button
      (`openSettingsURLString` only; **no private `App-Prefs:` schemes**).
- [ ] Audio session ducks rather than interrupts other audio.
- [ ] Commentary suppressed/deferred when VoiceOver is running.
- [ ] Speech interrupts for higher-tier events, drops same-or-lower — never backlogs.
- [ ] Snarky copy targets rolls/decisions, never people; no snark reaches stored
      player-facing reads.
- [ ] Commentary layers on the existing Yatzy celebration without colliding with it.
- [ ] Domain layer untouched — feature is entirely App-layer, sibling to audio/haptics.
