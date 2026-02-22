# Requirements — “Sydoku-quality” Yahtzee App (Working Spec)

This document captures the current product + technical direction for a Yahtzee/Yatzy-style dice game that feels “from the makers of Sydoku”: premium, calm, zero clutter, and tactile.

---

## Product Pillars

- **Premium and calm**: minimal UI, tasteful motion, readable typography, no visual noise.
- **Tactile delight**: dice feel physical, responsive, and satisfying.
- **No distractions**: no ads, no nags, no dark patterns.
- **Fast to play**: quick boot, quick new game, quick scoring.
- **Cross-device continuity**: current game + history follow you.

---

## 1.0 Feature Set

### Core Gameplay
- Classic Yahtzee/Yatzy mechanics:
  - 5 dice
  - Up to 3 rolls per turn
  - Player may **hold** any subset of dice between rolls
  - Choose a scoring category after rolling/holding
  - Category becomes locked after use
- Standard scorecard structure:
  - Upper section: Ones–Sixes
  - Upper bonus: standard threshold + bonus value (configurable later)
  - Lower section: 3/4 of a kind, Full House, Small/Large Straight, Yahtzee, Chance
- Optional rules (defer unless you want them for 1.0):
  - Yahtzee bonus
  - Joker rules / forced scoring variants

### “Feels like Sydoku” UX
- Clean scorecard with clear affordances:
  - Available categories are obvious
  - Locked categories visually subdued
  - Optional “suggested best move” (subtle and OFF by default)
- One-tap new game
- Settings screen that’s premium and short
- Basic history + stats (best score, recent games)

### Delight
- Dice feel alive:
  - Roll “rattle” + settle “thunk”
  - Hold toggles with a soft “lock” feel
  - Small animations that communicate state without clutter
- Optional “shake to roll” (OFF by default; decide later)

---

## Technical Direction

### Architecture (Recommended)
- **SwiftUI owns the app**
  - Scorecard UI, navigation, settings, history, stats
  - Game rules + state
  - Persistence (SwiftData recommended)
  - Accessibility
- **SpriteKit owns the dice tray**
  - Dice visuals + interaction (tap to hold)
  - Roll animation and “settled” behavior
  - Sends events back to SwiftUI

### Responsibilities and Data Flow
- SwiftUI is the source of truth:
  - dice values
  - held state
  - rolls remaining
  - scorecard state
  - turn progression
- SpriteKit is a specialized interaction surface:
  - renders dice state
  - animates roll
  - reports taps + final rolled values

Suggested bridge:
- `GameModel` (Observable / SwiftData-backed)
- `DiceTrayView` (SwiftUI wrapper) embeds `SpriteView(scene:)`
- `DiceScene` (SpriteKit) uses closures/delegate:
  - SwiftUI → SpriteKit: `setState(values:, held:)`, `roll(unheldOnly:)`
  - SpriteKit → SwiftUI: `didToggleHold(index:)`, `didFinishRoll(values:)`

---

## Dice Motion: Physics Level Decision

### Option A: Physics-Lite (Recommended for 1.0)
- Dice motion is **animated**, not fully simulated.
- Deterministic and stable across devices.
- Easier to tune to “premium”.
- Still looks great with strong easing + rotation + sound timing.

### Option B: Full Physics (Later)
- Real collisions and settling thresholds.
- More edge cases: jitter, overlap, inconsistent settle time.
- Requires snap-to-rest fallbacks + timeouts.

**Decision for 1.0:** Physics-Lite.

---

## Interaction Requirements

### Dice Tray
- Tap a die to toggle **Held**
  - Held dice are visually distinct (ring/lift/tint)
  - Held dice do not change on subsequent rolls
- Roll CTA
  - Shows rolls remaining (e.g., “Roll (2 left)”)
  - Disabled at 0 remaining
  - After final roll, prompt to choose a category

### Scorecard
- Tap category to assign score for the turn
- Locked categories are non-interactive
- Layout must work for:
  - iPhone portrait
  - iPad split view
  - macOS resizable windows

---

## Persistence / Sync

### Stored Data
- Current game (optional autosave)
- Completed games history
- Basic stats:
  - best score
  - average score
  - games played

### Sync Strategy
- SwiftData + iCloud/CloudKit preferred
- If sync adds risk, ship local in 1.0 and add sync in 1.1

---

## Audio + Haptics

### Sounds (Minimal, Premium)
- Roll rattle
- Settle thunk
- Hold toggle click
- Score confirm soft chime

### Haptics (iOS)
- Light tap on hold toggle
- Soft impact on settle
- Optional light confirm on scoring

### User Controls
- Sound on/off
- Haptics on/off

---

## Theming / Look & Feel

- Match Sydoku/SyFlux vibe:
  - strong typography
  - calm surfaces
  - tasteful color themes
  - minimal chrome
- Themes:
  - at least 2–3 presets for 1.0
  - light/dark support
  - dice + tray adapt to theme

---

## Platform Scope

- Primary: **iOS**
- Secondary: **iPadOS**, **macOS** (Catalyst or native SwiftUI)
- Watch/tvOS/visionOS: future exploration, not 1.0

---

## Proposed Build Order

1. **SwiftUI foundation**
   - `GameModel` rules + turn state
   - Scorecard UI + category locking
2. **Dice tray MVP**
   - SpriteKit dice tray
   - Tap-to-hold
   - Roll animation → returns values
3. **Polish**
   - sound + haptics
   - theme styling
   - accessibility pass
4. **History + stats**
   - completed game saving
   - best score + recent games
5. **Sync**
   - SwiftData/iCloud (if not already)

---

## Open Questions

- Naming: Yahtzee vs Yatzy (branding + legal considerations).
- Default ruleset specifics (bonus threshold, Yahtzee bonus/joker rules).
- Optional helper:
  - “suggest best score” (default OFF; keep calm)
- Multiplayer/pass-and-play:
  - likely 1.1+ unless core to your use case.

---

## Definition of Done (1.0)

- Full game playable start-to-finish with **correct scoring**.
- Reliable roll/hold behavior.
- Clean scorecard UX + satisfying dice tray interactions.
- Basic history + best score.
- Feels premium (the “Sydoku maker” bar).
