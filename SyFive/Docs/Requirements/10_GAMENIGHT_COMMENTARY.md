# SyFive — Game Night Commentary Design Spec

*Design authority for how the shipped commentator system behaves inside Game Night:
the 1.0 single-announcer model carried over FaceTime audio, the option surface, the
suppression rules, and the fully-designed-but-deferred synced Shared Booth.*

> **Status:** Design agreed; all decisions locked (§7). Ships **with Game Night** (both
> are post-1.0). This document is the implementation brief for the Xcode Claude agent.
> Prerequisites: `06_MULTIDEVICE_DESIGN.md` (Game Night) and
> `09_COMMENTATOR_DESIGN.md`. The commentator system itself is
> implemented and shipped for local play; this doc governs only its Game Night
> behavior. §4 is a design record and is explicitly **not** for implementation.

---

## Supersessions

- **09 (implicit single-device assumption).** The commentator engine fires from local
  match events on the device that is playing. → **In Game Night, the engine is
  instantiated on the host's seated device only.** Guest and spectator devices never
  instantiate it (§3). Outside Game Night, 09 governs unchanged.
- **06 §13.1 ("Spectator theater audio — parked until the audio workstream
  exists").** → **Resolved for the commentary half only:** spectator devices produce
  no commentary audio in Game Night 1.0. The dice-*feel* half of that open decision
  (rattle/settle sounds during spectator replay, per `05_AUDIO_HAPTICS_DESIGN.md`)
  remains open and is untouched by this doc.
- **06 §2.1 (three join doors).** → **Extended, not overridden:** the two-device
  player pattern (§1.4) adds a same-account second-device join path as a
  verify-on-device item. The three doors stand.

Ledger rows for these appear at the end of this document, ready to paste.

---

## 0. Why this exists (context the agent must not lose)

The commentator system shipped and it works. The question this doc answers: **what
happens when the table is a FaceTime call?**

The full answer — a synced Shared Booth where the host draws every line once and each
remote room's device speaks it locally — was designed in detail and is recorded in §4.
It was then **deliberately deferred**, because a scope observation collapsed 1.0 to
nearly zero engineering: *if the call carries the announcer's voice, the shipped
implementation is already the implementation.* The host's device speaks exactly as it
does today; the announcer travels to remote rooms the same way the host's own voice
does. No new message kinds, no cue protocol, no per-room booth model.

The second observation locking the shape: **the primary use case is two devices per
player** — the FaceTime call on an iPad or Mac, the game on an iPhone. Even the host.
This configuration is not a complication; it is the *good* case, twice over:

1. **Acoustically** (§1.3): the announcer speaks from the game iPhone, enters the room
   as ordinary audio, and the call device's mic transmits it like any voice. Nothing
   fights the system echo canceller.
2. **Experientially**: the game never has to occupy the call device, so **full
   FaceTime video survives** — faces stay full-screen on the iPad while the game lives
   on the phone. The one-device player pays the picture-in-picture cost; the
   two-device player pays nothing.

Locked decisions, in the order they were made:

1. Game Night gets **synced-feeling commentary for remote rooms**; same-room devices
   need nothing special (one voice per room is the organizing principle).
2. The full synced design is the **Shared Booth** (one commentator for the table, one
   authoritative draw, same words everywhere) — designed in §4, **deferred**.
3. **1.0 = FaceTime-carried single announcer**: the host's seated device speaks; the
   call transports it. "Just need options" — the option surface is §2.
4. The **call device has no SyFive job in 1.0.** Joining SyFive on it is a user
   choice (spectator stage with FaceTime in PiP), never a requirement.

---

## 1. The 1.0 model — one announcer, carried by the call

### 1.1 Who speaks

Exactly one device in a Game Night session runs the commentator: **the host's seated
device**, using the host's own pack, level, and voice, exactly as in solo or
pass-and-play. There is no table-level pack negotiation, no guest configuration, and
no wire traffic — the commentary system does not appear in the 06 message table at
all.

### 1.2 What it narrates, and when

Nothing changes in the engine's event wiring: it hooks the host's `MatchController`
events as it does today. Because the host is the match authority, **every player's
actions land as host-side events** — a remote guest's score arrives via `scoreChosen`
→ host applies → the same event the engine already listens to fires. Remote rolls
reach the host as theater; the engine reacts when the host-side replay settles and
`rollResult` is applied.

Timing honesty, stated once: the announcer reacts when the *host's room* sees the
moment. A remote roller's own dice settle first; the call delivers the announcer's
reaction a beat later — a delayed-broadcast feel, like hearing the radio call after
watching the play. This is accepted 1.0 behavior, not a bug. The Yatzy utterance still
follows the host-side title card, per the 09 timing decision.

### 1.3 Acoustics — graded honestly

- **Two-device host (primary case): good.** The seated iPhone's TTS is room audio.
  The call device (iPad/Mac) picks it up on its mic and transmits it exactly as it
  transmits the host's voice. No AEC involvement — the echo canceller only scrubs
  audio the *call device itself* plays.
- **One-device host (call + game on the same device): degraded.** The device's own
  TTS is AEC reference audio and gets scrubbed from the outgoing mic — remote rooms
  hear the announcer mangled or not at all. Additionally, **Voice Isolation** mic mode
  suppresses non-primary-talker audio further; **Wide Spectrum** passes it. Apps
  cannot set mic mode — on any device — so this is guidance copy (§2.3), not
  automation. The degraded path is documented and validated as degraded (§6); no
  engineering fights it in 1.0.
- Remote guests with commentary tastes of their own change nothing: their engines are
  dormant in Game Night (§3), so there is exactly one announcer per table.

### 1.4 The two-device player pattern (recognized configuration)

- **Call device (iPad/Mac):** stays in FaceTime, full-screen video. In 1.0 it has no
  SyFive responsibilities. *Optionally*, its owner may join the session on it as an
  unseated spectator — the already-specced 06 spectator rendering (stage + browsable
  scorecards) with FaceTime video continuing in PiP. Their choice; guidance never
  requires it.
- **Game device (iPhone):** claims the seat, plays, and — if it is the host's — speaks.
- **Getting the iPhone into the session** when the call lives on the iPad: the system
  offers active SharePlay sessions to the same account's other devices (the documented
  pattern: start a session on one device, your other device is prompted to join). The
  **invite link remains the guaranteed door** regardless. Exact prompt behavior is a
  validation item (§6), not load-bearing spec.
- **Host start ergonomics** when the host's call is on their iPad: activation may need
  to originate from the call device — one tap of Start Game Night in SyFive on the
  iPad, then background SyFive to return to full-screen FaceTime; the session
  persists, and the host's iPhone joins as above. Verify on device (§6); if activation
  from the non-call iPhone works directly, prefer that and simplify the copy.
- SyFive 1.0 excludes macOS, so a **Mac call endpoint simply never runs SyFive** —
  which in the 1.0 model costs nothing (the call device has no job). Noted for the
  ledger: the two-device pattern is the first concrete argument for a post-1.0 Mac
  build (§4's booth role would make it genuinely useful).

---

## 2. The option surface

Small, per the design instruction ("just need options").

### 2.1 Table-setting commentary row

The host's table-setting screen carries one row: **"Commentary: {Pack} · {Level}"**
with an Off switch for the night. Defaults to the host's existing commentator
settings. Tapping the row adjusts pack/level **for this session only** — a
session-scoped override that does not rewrite the host's solo settings
*(locked — §7.1)*. Guests see the row's state read-only in
`tableState`-rendered table view, so everyone knows who's in the booth tonight; they
get no control (their control is the call itself — "Dad, turn that thing off").

### 2.2 Suppression visibility

Guest devices show nothing about commentary. No greyed-out settings, no "host controls
this" rows — absence, not disabled UI. A guest's own commentator settings remain
untouched and take effect the moment they play locally again.

### 2.3 Guidance copy (three strings, one sentence each — exemplars)

- Two-device tip, on the host's guidance screen: *"On a FaceTime call? Keep the call
  on your iPad and play on your iPhone — everyone sees everyone."*
- Wide Spectrum tip, shown only in the one-device configuration (a call is active on
  the playing device): *"For the table to hear the announcer, set your mic to Wide
  Spectrum in Control Center."*
- Join steering, on the call-device join affordance path: *"Playing? Join on your
  iPhone."*

Copy is calm, never technical beyond the Control Center pointer, and never implies the
one-device path is broken — it is quieter, not wrong.

---

## 3. Suppression rules (the whole 1.0 engineering)

- **Gate at instantiation, by role.** In a Game Night session, the commentator engine
  is constructed only where `role == .host` on the seated device. `TableReplica`
  devices and unseated spectators never construct it. This is a guard at the
  composition root, not conditionals sprinkled through the engine — the 09 engine
  itself remains Game-Night-ignorant.
- **No new event kinds, no wire changes.** The 06 message table is untouched.
- The 09 VoiceOver rule (commentary suppressed/deferred while VoiceOver runs) applies
  unchanged on the one device that speaks.
- The 09 audio-session rule (duck, don't interrupt) applies unchanged. **One-device
  host verify item:** TTS behavior while the same device hosts the FaceTime call
  (ducking interplay with the call's voice-chat session) — verify on device; if the
  system misbehaves, the fix is scoped to the one-device path only (§6).
- Snark targeting needs no change: the single announcer draws targets from the full
  seat list, remote seats included, so "rib everyone, favor no one" holds across the
  table with the existing per-event random draw.
- "Snark never leaves the live room" holds trivially — nothing new is stored,
  transmitted, or logged.

---

## 4. DEFERRED DESIGN RECORD — the synced Shared Booth (vNext)

> **Do not implement anything in this section.** It exists so the agreed design is not
> re-litigated when guest-side commentary is scheduled. Direction was agreed in the
> July 2026 design sessions; the §4.4 defaults table should be re-confirmed with Pops
> at scheduling time.

### 4.1 Why 1.0's model eventually wants replacing

The call-carried announcer is monophonic and host-flavored: remote rooms hear it at
call quality, a beat late, and always in the host's pack and the host's *room's* voice.
The Shared Booth gives every room its own full-quality, locally-rendered announcer
saying the same words at the same moment.

### 4.2 The organizing principle

**One voice per acoustic space.** A room needs exactly one announcer; each household on
the call is its own room and gets its own. Same-room extra devices stay silent — they
can already hear the booth.

### 4.3 Mechanism

- **One draw, by the host.** The host's Director makes every commentary decision
  exactly once — event, line variant, snark target — and broadcasts a `commentaryCue`.
  Single-draw is *required* by the snark rules: "rib everyone, favor no one" only
  self-balances with one random draw per event across all seats. No-immediate-repeat
  state lives on the host.
- **Text-in-cue.** The cue carries the resolved line text plus packID (for the prosody
  row) and tier. Version-proof — an older guest app never chokes on a variant index it
  doesn't have; unknown pack falls back to Steady prosody. Cues are ephemeral wire
  messages; nothing is stored.
- **Director / Voice split.** Director (event detection, line draw, repeat state) runs
  host-only; Voice (render a cue through local TTS with the device's own voice) runs
  on any speaking device. Solo play is both roles on one device. This split is the
  architecture the engine wanted anyway.
- **Table-level pack and level**, chosen at table-setting, default the host's —
  "a game has one announcer." Voice timbre stays device-local per the 09 storage
  decision: different rooms, same words, their own announcer's voice — radio
  affiliates. Level filtering is local: the cue carries tier; each device speaks it
  only if its local level includes it.
- **Timing self-aligns.** Speak on cue-arrival; rooms are acoustically isolated, so
  sub-second network skew is inaudible. Interrupt policy runs per speaking device on
  the cue stream. The Yatzy utterance waits for the *local* title card.

### 4.4 Booth assignment (defaults, no detection machinery)

| Device situation | Booth default |
|---|---|
| Unseated in-session device (the iPad/TV) | **ON** |
| Seated device that took the call sheet on itself (one-device player) | **ON** |
| Host device with no call active (in-person night) | **ON** |
| Seated device joined via tap, link, or same-account prompt | **OFF** |

One persistent, device-local toggle overrides everything. Known imperfection: a host
running two devices at home doubles until one toggle flip on night one —
self-correcting, accepted.

### 4.5 Acoustics in the booth model

The endpoint-as-booth configuration becomes the *ideal*: when the call device itself
speaks (unseated iPad in-session), its TTS is AEC reference audio and is scrubbed from
its outgoing mic — near-zero crosstalk. Where the endpoint can't run SyFive (Mac,
until a Mac build exists), the seated iPhone speaks and leaks into the call
uncancelled; the same-words design masks it — each far room hears its own booth first
(precedence) and the leak lands underneath as a faint slap of the *same line*. This
masking argument is why the Shared Booth is same-words (Fork A) and not
per-device-pack (Fork B).

### 4.6 What it costs

One additive message kind (`commentaryCue`), the Director/Voice refactor, the booth
toggle + defaults, table-setting pack/level as table state, and guest-side wiring of
Voice to `TableReplica`-delivered cues. Protocol-versioned via the 06 envelope as
usual.

---

## 5. Implementation stages (1.0; ordered, independently checkable)

1. **Role gate.** Engine constructed only on the host's seated device in Game Night;
   guests/spectators never construct it. *Check: full remote match produces zero
   utterances on every non-host device; host's utterances unchanged from solo.*
2. **Table-setting row.** Pack · Level display, session-scoped override, Off switch;
   read-only visibility to guests. *Check: override lasts the session, host's solo
   settings untouched afterward; Off silences the night.*
3. **Copy pass.** The three §2.3 strings, placed as specified. *Check: Wide Spectrum
   tip appears only when a call is active on the playing device.*
4. **One-device audio-session verification.** TTS + active call on the same device:
   confirm ducking behaves; scope any fix to this path only. *Check: by ear, per §6.*

---

## 6. Validation matrix additions (run with 06's matrix; two households minimum)

17. Two-device host: announcer clearly audible in remote rooms via the call; judged by
    ear at both ends.
18. Two-device *remote guest* (call on their iPad, game on their iPhone): host's
    announcer arrives on their call device normally; their own devices stay silent.
19. One-device host, Voice Isolation vs Wide Spectrum A/B: document the degradation;
    confirm the Wide Spectrum tip appears and helps.
20. Same-account join prompt: with the call and session on the iPad, verify the iPhone
    is offered the session; document the exact affordance. Invite link as fallback
    regardless.
21. Host start ergonomics: determine whether Game Night can be started from the
    non-call iPhone or requires one tap on the call iPad; align §2.3 copy with the
    answer.
22. Optional spectator join on the call iPad: stage renders with FaceTime video in
    PiP; leaving SyFive returns full-screen video; session persists.
23. Off switch mid-match: silences immediately; no utterance mid-word cutoffs beyond
    the 09 interrupt policy.
24. One-device host ducking interplay (§5.4): call audio and TTS coexist without the
    call dropping or TTS stalling.

---

## 7. Resolved decisions (locked by Pops)

1. **The table-row pack/level override is session-scoped.** The night's booth is the
   night's mood; solo settings are identity. The host's solo settings are never
   rewritten.
2. **The one-device degraded path ships as specified** — the Wide Spectrum copy line
   only, no in-app signal. It works, quieter; an alert would be furniture.

---

## 8. Invariants quick reference

- Exactly **one announcer per table** in 1.0: the host's seated device. Guests and
  spectators never instantiate the engine; gate at the composition root by role.
- **Zero wire changes.** No new message kinds; the 06 envelope and table are
  untouched. §4 is not implemented.
- The **call device has no SyFive job** in 1.0; spectator join on it is optional
  (stage + PiP), never required or steered toward.
- The 09 engine stays **Game-Night-ignorant**; all Game Night awareness lives at
  instantiation.
- 09 rules unchanged where the one announcer speaks: VoiceOver suppression, duck-don't-
  interrupt, no-immediate-repeat, snark targeting random across **all** seats, snark
  never stored or transmitted.
- Mic modes are user-set only; SyFive's tool is one line of copy.
- Dice-feel audio during spectator theater remains **open** under 06 §13.1 /
  `05_AUDIO_HAPTICS_DESIGN.md` — this doc governs commentary only.

---

## Ledger rows (paste into `00_DECISION_LEDGER.md`; adapt to its column format)

| Decision | Ruling | Source |
|---|---|---|
| Game Night commentary 1.0 | Single announcer: host's seated device, host's pack/level/voice; FaceTime call carries it to remote rooms | 10 §1 |
| Guest/spectator commentary in Game Night | Dormant — engine never instantiated off the host; no wire traffic | 10 §3 |
| Synced Shared Booth (cue protocol, Director/Voice, booth roles) | **Deferred, designed** — do not implement; re-confirm §4.4 table at scheduling | 10 §4 |
| Call device role in Game Night 1.0 | No SyFive job; optional unseated spectator join (stage + PiP) | 10 §1.4 |
| Two-device player pattern | Recognized primary configuration; preserves full FaceTime video; iPhone joins via invite link or same-account prompt (verify) | 10 §1.4, extends 06 §2.1 |
| Spectator theater audio (06 §13.1) | Commentary half resolved: none in 1.0. Dice-feel half still open | 10 Supersessions |
| Mic mode guidance | Wide Spectrum tip as copy only, one-device path only; never automated | 10 §2.3 |
| Table-row commentary override | Session-scoped for the night; host's solo settings never rewritten | 10 §7.1 |
| One-device announcer path | Ships as specified: copy line only, no in-app alert | 10 §7.2 |
