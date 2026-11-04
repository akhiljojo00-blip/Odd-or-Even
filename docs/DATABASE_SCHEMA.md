# Odd or Even - Database Schema & Supabase Architecture

## 1. Schema Design Overview

The database uses PostgreSQL 15+ hosted on Supabase.
All game progression operations are executed via PostgreSQL stored procedures (`SECURITY DEFINER` RPCs).
Row Level Security (RLS) is enabled on all tables to prevent unauthorized data reading and writing.

```
+--------------------+        +---------------------+
|  player_profiles   |<-------|     auth.users      |
+--------------------+        +---------------------+
          ^
          | (FK)
+--------------------+        +---------------------+
|     game_rooms     |<-------|   matchmaking_queue |
+--------------------+        +---------------------+
          | (1:N)
          v
+--------------------+ 1:N    +---------------------+
|      matches       |------->|    match_players    |
+--------------------+        +---------------------+
          | (1:N)
          +-------------------+---------------------+
          |                   |                     |
          v                   v                     v
+--------------------+ +--------------------+ +--------------------+
|  innings_records   | |pending_submissions | |    ball_events     |
+--------------------+ |  (STRICT PRIVATE)  | +--------------------+
                       +--------------------+
```

## 2. Table Definitions

### 2.1 `player_profiles`
- `id` (uuid, PK, references `auth.users(id) ON DELETE CASCADE`)
- `display_name` (text, not null)
- `avatar_index` (integer, default 0)
- `matches_played` (integer, default 0)
- `matches_won` (integer, default 0)
- `matches_lost` (integer, default 0)
- `matches_tied` (integer, default 0)
- `created_at` (timestamptz, default `now()`)
- `updated_at` (timestamptz, default `now()`)

### 2.2 `game_rooms`
- `id` (uuid, PK, default `gen_random_uuid()`)
- `room_code` (varchar(6), unique, not null)
- `host_user_id` (uuid, references `player_profiles(id)`)
- `guest_user_id` (uuid, references `player_profiles(id)`, nullable)
- `status` (text, e.g. `'waiting'`, `'ready'`, `'playing'`, `'finished'`, `'abandoned'`)
- `config` (jsonb, stores match settings)
- `host_ready` (boolean, default false)
- `guest_ready` (boolean, default false)
- `active_match_id` (uuid, nullable)
- `created_at` (timestamptz, default `now()`)
- `expires_at` (timestamptz, default `now() + interval '30 minutes'`)

### 2.3 `matches`
- `id` (uuid, PK, default `gen_random_uuid()`)
- `room_id` (uuid, references `game_rooms(id)`)
- `status` (text, e.g. `'active'`, `'completed'`, `'forfeited'`, `'abandoned'`)
- `phase` (text, e.g. `'parity_assigned'`, `'toss'`, `'first_innings'`, `'innings_break'`, `'second_innings'`, `'finished'`)
- `version` (bigint, default 1) -- used for optimistic concurrency & idempotency
- `config` (jsonb, not null)
- `player1_id` (uuid, references `player_profiles(id)`)
- `player2_id` (uuid, references `player_profiles(id)`)
- `player1_parity` (text: `'odd'` or `'even'`)
- `player2_parity` (text: `'odd'` or `'even'`)
- `toss_winner_id` (uuid, nullable)
- `batting_first_id` (uuid, nullable)
- `current_innings_no` (smallint, default 1)
- `first_innings_runs` (integer, default 0)
- `target_runs` (integer, nullable)
- `current_batter_id` (uuid, nullable)
- `current_bowler_id` (uuid, nullable)
- `player1_timeout_points` (integer, default 0)
- `player2_timeout_points` (integer, default 0)
- `winner_id` (uuid, nullable)
- `result_type` (text, e.g. `'win'`, `'tie'`, `'forfeit'`)
- `player1_series_score` (integer, default 0)
- `player2_series_score` (integer, default 0)
- `series_winner_id` (uuid, nullable)
- `turn_deadline_at` (timestamptz, nullable)
- `created_at` (timestamptz, default `now()`)
- `updated_at` (timestamptz, default `now()`)

### 2.4 `pending_submissions` (Strict Private Storage)
- `id` (uuid, PK, default `gen_random_uuid()`)
- `match_id` (uuid, references `matches(id) ON DELETE CASCADE`)
- `turn_type` (text: `'toss'` or `'ball'`)
- `innings_no` (smallint, nullable)
- `ball_no` (integer, nullable)
- `user_id` (uuid, references `auth.users(id)`)
- `number_choice` (smallint, check `choice >= 1 AND choice <= 10`)
- `created_at` (timestamptz, default `now()`)
- Constraint: `UNIQUE(match_id, turn_type, innings_no, ball_no, user_id)`
- **RLS POLICY:** No user can `SELECT` from this table. Submissions are inserted via secure RPC only and read exclusively by server-side resolution functions.

### 2.5 `ball_events` (Public History for Resolved Balls)
- `id` (uuid, PK, default `gen_random_uuid()`)
- `match_id` (uuid, references `matches(id) ON DELETE CASCADE`)
- `innings_no` (smallint, not null)
- `ball_no` (integer, not null)
- `batter_id` (uuid, references `player_profiles(id)`)
- `bowler_id` (uuid, references `player_profiles(id)`)
- `batter_number` (smallint, not null)
- `bowler_number` (smallint, not null)
- `runs_scored` (smallint, not null)
- `is_wicket` (boolean, not null)
- `cumulative_runs` (integer, not null)
- `created_at` (timestamptz, default `now()`)
- Constraint: `UNIQUE(match_id, innings_no, ball_no)`

### 2.6 `matchmaking_queue`
- `user_id` (uuid, PK, references `player_profiles(id)`)
- `config` (jsonb, requested match presets)
- `joined_at` (timestamptz, default `now()`)

## 3. Core RPC Functions
- `rpc_create_room(p_config jsonb)` -> returns `room_code`, `room_id`
- `rpc_join_room(p_code text)` -> joins room, updates status
- `rpc_confirm_room_config(p_room_id uuid, p_config jsonb)` -> checks both players, starts match if agreed
- `rpc_submit_choice(p_match_id uuid, p_turn_type text, p_choice int)` -> records submission, triggers resolution if both submitted
- `rpc_poll_or_resolve_ball(p_match_id uuid)` -> resolves toss or ball atomically
- `rpc_handle_disconnect(p_match_id uuid)` / `rpc_reconnect(p_match_id uuid)`
- `rpc_request_rematch(p_match_id uuid)`
