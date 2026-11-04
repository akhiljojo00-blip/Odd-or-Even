# Odd or Even - Project Overview

## 1. Executive Summary
**Odd or Even** is a competitive, premium mobile game inspired by the classic hand-cricket format. Two players select numbers simultaneously from `1` through `10`. The game features both offline local multiplayer (pass-and-play on a single device) and server-authoritative online real-time multiplayer powered by Supabase and PostgreSQL.

## 2. Product Vision & Goals
- **Fairness & Security:** Online gameplay is strictly server-authoritative. Player numbers are submitted into private isolation tables and evaluated atomically via PostgreSQL RPC transactions. Clients never report their own scores or dictate ball outcomes.
- **Player Experience:** High-end sports aesthetics (charcoal/midnight background, emerald/lime accents, gold highlights, coral/violet player differentiation), responsive controls, low latency, haptic feedback, and fluid animations.
- **Flexibility:** Supports Standard Mode (manual per-ball selection) and Fast Mode (auto number generation or preselection), pass-and-play offline mode with screen privacy handoff, and full online rooms/matchmaking.
- **Reliability:** Comprehensive disconnection tolerance with a 30-second grace period, pause-and-resume clocks, and full match state recovery after app backgrounding or network drops.

## 3. Supported Game Modes
1. **Offline Pass-and-Play:**
   - 100% playable on a single device with zero internet/backend dependency.
   - Screen privacy handoff ensures Player 1's secret number is never leaked to Player 2 before Player 2 locks in.
   - Configurable overs (1, 2, 5, or unlimited), decision timers (5–30 seconds, default 10), and series target points (1–10, default 6).
2. **Online Multiplayer:**
   - Private Room lobbies with 6-character room codes.
   - Fast 1v1 matchmaking queue.
   - Configuration agreement: both players must reconfirm proposed match settings before match start.
   - Authoritative PostgreSQL turn resolution and Supabase Realtime broadcast.
   - Reconnection recovery and graceful disconnect management.

## 4. Technology Stack
- **Framework:** Flutter 3.47+ / Dart 3.13+
- **State Management:** Riverpod 2.6+
- **Navigation:** GoRouter 14.8+
- **Backend / Database:** Supabase (Auth, PostgreSQL 15+, Realtime Channels, Row-Level Security, Database RPCs)
- **Local Storage:** `shared_preferences` for offline history, settings, and player profile caching.
- **Design System:** Custom Design Tokens (`GameColors`, `GameTypography`, `GameSpacing`, `GameElevation`).
