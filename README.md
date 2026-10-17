# SyFive

A Yatzy dice game for iPhone and iPad.

## Features

- **Full Yatzy rules** — upper/lower sections, bonus, Yatzy bonus, joker rules, undo
- **RealityKit 3D dice** — full PhysX physics, validated fair (p = 0.217 across 10k rolls)
- **Game Night** — SharePlay multiplayer via GroupActivities; host-authoritative sync
- **Match history** — per-match detail, score trends, head-to-head records
- **Player profiles** — stats, insights, consistency/style/risk/clutch profiles
- **House Records** — eight household title cards across all-games and head-to-head
- **Commentary** — optional AI-flavored commentary with four personalities (Steady, Snarky, Sports, Zen)
- **Feel system** — procedurally synthesized audio and CoreHaptics; no asset files
- **7 themes** — Midnight, Blossom, Ember, Forest, Ocean, Sunset, Paper

## Tech

- Swift / SwiftUI / SwiftData / CloudKit
- RealityKit (dice physics)
- GroupActivities (SharePlay)
- AVAudioEngine + AVSpeechSynthesizer
- CHHapticEngine
- [SyLib](https://github.com/waynemock/sylib-swift) — shared Swift package (SyLibCore, SyLibScoring, SyLibYatzy, SyLibDice, SyLibFeel, SyLibUI, SyLibDSP, SyLibCache, SyLibGameNight, SyLibGameNightMatch, SyLibCommentary, SyLibScoringData)

## Platforms

iOS 18.6+ / iPadOS 18.6+. macOS not supported.

## Documentation

In `SyFive/SyFive/Docs/Requirements/`:

- [`Docs/Requirements/00A_STUDIO_CONVENTIONS.md`](SyFive/SyFive/Docs/Requirements/00A_STUDIO_CONVENTIONS.md) — studio-level and canonical; cited rather than restated
- [`00B_SYFIVE_GUARDRAILS.md`](SyFive/SyFive/Docs/Requirements/00B_SYFIVE_GUARDRAILS.md) — SyFive's rails
- [`00_DECISION_LEDGER.md`](SyFive/SyFive/Docs/Requirements/00_DECISION_LEDGER.md) — HEAD for design rulings
