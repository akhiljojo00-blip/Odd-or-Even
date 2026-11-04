# Odd or Even - Implementation Roadmap

## Phase 0: Inspection & System Architecture (COMPLETED)
- Repository setup, environment diagnostic (Flutter 3.47.1, Dart 3.13.1, OpenJDK 25, Android SDK).
- Core documentation created (`PROJECT_OVERVIEW`, `ARCHITECTURE`, `GAME_RULES`, `GAME_STATE_MACHINE`, `MATCH_CONFIGURATION`, `DATABASE_SCHEMA`, `SECURITY`, `REALTIME_AND_NETWORKING`, `UI_UX_DESIGN_SYSTEM`).

## Phase 1: Flutter Foundation & Design System (COMPLETED)
- Core dependencies added (`flutter_riverpod`, `go_router`, `supabase_flutter`, `shared_preferences`, `uuid`, `google_fonts`).
- Design system tokens implemented (`GameColors`, `GameTypography`, `GameTheme`, reusable buttons, scoreboard widgets).
- Reusable domain models for rules, parity, innings, and match states (`GameMatchState`, `BallEvent`, `MatchConfig`, `PlayerInfo`).

## Phase 2: Complete Offline Pass-and-Play Game Engine (COMPLETED)
- Pure-Dart match engine implementation (`OddOrEvenEngine`):
  - Random parity generator.
  - Toss evaluation.
  - Role selection (Bat / Bowl).
  - Ball resolution (Runs / Wicket).
  - Two innings transition and chase target logic (`target = first_score + 1`).
  - Overs management (configurable legal ball counting, innings completion on limit).
  - Decision timer & timeout point accounting.
  - Series scoring and rematch flow (clearing timeout points per match).
  - Forfeit match handling with series progression.
- Pass-and-play screen privacy handoff.
- Pass-and-play UI screens:
  - Offline setup screen (overs, timer, series target).
  - Toss screen.
  - In-game scoreboard & number selection pad.
  - Ball reveal overlay & wicket animation with post-dialog result transition.
  - Innings break screen.
  - Match & series result screens.
  - Local history persistence via `shared_preferences`.
- Unit tests & widget tests for the complete offline journey (23 automated tests passing).

## Phase 3: Supabase Backend Schema & Migration (COMPLETED)
- Version-controlled SQL migration scripts under `supabase/migrations/`:
  - `00001_initial_schema.sql`: tables, enums, constraints, indexes.
  - `00002_rls_security.sql`: row level security policies.
  - `00003_rpc_functions.sql`: room management, submissions, atomic ball resolution, 2nd innings start, series score tracking, player profile career statistics, rematch, claim timeout, forfeit, and instant matchmaking.

## Phase 4: Online Room System & Lobby Agreement (COMPLETED)
- Supabase client integration & anonymous guest authentication.
- Room creation (6-character code), room joining, host/guest presence.
- Two-player configuration agreement flow (`RoomScreen` at `/room/:id`).

## Phase 5: Authoritative Online Multiplayer & Matchmaking (COMPLETED)
- Online match manager with authoritative server snapshots (`OnlineGameplayScreen` at `/online-play/:id`).
- Real-time instant matchmaking queue and radar scanning (`MatchmakingScreen` at `/matchmaking`).
- Turn submission and atomic resolution RPC calls (`rpc_submit_choice`, `rpc_select_role`, `rpc_start_second_innings`, `rpc_request_rematch`, `rpc_claim_timeout`, `rpc_forfeit_match`).
- Handling race conditions, timer synchronization, and disconnect grace.

## Phase 6: Reliability, Audio, Haptics & Polish (COMPLETED)
- Audio & haptics feedback integration (`HapticsUtil`, `SoundUtil`).
- Match history view, scorecard breakdown, player profiles (`ProfileScreen` at `/profile`).
- End-to-end verification and test suite execution.
