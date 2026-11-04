# Odd or Even - Implementation Roadmap

## Phase 0: Inspection & System Architecture (COMPLETED)
- Repository setup, environment diagnostic (Flutter 3.47.1, Dart 3.13.1, OpenJDK 25, Android SDK).
- Core documentation created (`PROJECT_OVERVIEW`, `ARCHITECTURE`, `GAME_RULES`, `GAME_STATE_MACHINE`, `MATCH_CONFIGURATION`, `DATABASE_SCHEMA`, `SECURITY`, `REALTIME_AND_NETWORKING`, `UI_UX_DESIGN_SYSTEM`).

## Phase 1: Flutter Foundation & Design System (IN PROGRESS)
- Core dependencies added (`flutter_riverpod`, `go_router`, `supabase_flutter`, `shared_preferences`, `uuid`, `google_fonts`).
- Design system tokens implemented (`GameColors`, `GameTypography`, `GameTheme`, reusable buttons, scoreboard widgets).
- Reusable domain models for rules, parity, innings, and match states.

## Phase 2: Complete Offline Pass-and-Play Game Engine
- Pure-Dart match engine implementation:
  - Random parity generator.
  - Toss evaluation.
  - Role selection (Bat / Bowl).
  - Ball resolution (Runs / Wicket).
  - Two innings transition and chase target logic.
  - Overs management (legal ball counting).
  - Decision timer & timeout point accounting.
  - Series scoring and rematch flow.
- Pass-and-play screen privacy handoff.
- Pass-and-play UI screens:
  - Offline setup screen (overs, timer, series target).
  - Toss screen.
  - In-game scoreboard & number selection pad.
  - Ball reveal overlay & wicket animation.
  - Innings break screen.
  - Match & series result screens.
  - Local history persistence via `shared_preferences`.
- Unit tests & widget tests for the complete offline journey.

## Phase 3: Supabase Backend Schema & Migration
- Version-controlled SQL migration scripts under `supabase/migrations/`:
  - `00001_initial_schema.sql`: tables, enums, constraints, indexes.
  - `00002_rls_security.sql`: row level security policies.
  - `00003_rpc_functions.sql`: room management, submissions, atomic ball resolution.

## Phase 4: Online Room System & Lobby Agreement
- Supabase client integration & guest authentication.
- Room creation (6-character code), room joining, host/guest presence.
- Two-player configuration agreement flow.

## Phase 5: Authoritative Online Multiplayer
- Online match manager listening to Supabase Realtime channels.
- Turn submission and atomic resolution RPC calls.
- Handling race conditions, timer synchronization, and disconnect grace.

## Phase 6: Reliability, Audio, Haptics & Polish
- Audio & haptics feedback integration.
- Match history view, scorecard breakdown, player profiles.
- End-to-end verification and test suite execution.
