-- =====================================================================
-- Migration 00001: Initial Schema for Odd or Even
-- =====================================================================

-- Enums
CREATE TYPE room_status AS ENUM ('waiting', 'ready', 'playing', 'finished', 'abandoned');
CREATE TYPE match_phase AS ENUM (
  'parity_assigned',
  'toss_input',
  'toss_reveal',
  'role_selection',
  'first_innings',
  'innings_break',
  'second_innings',
  'match_finished',
  'series_finished',
  'match_forfeited'
);
CREATE TYPE player_parity AS ENUM ('odd', 'even');
CREATE TYPE player_role AS ENUM ('bat', 'bowl');
CREATE TYPE match_result_type AS ENUM ('win', 'tie', 'forfeit');

-- Player Profiles
CREATE TABLE IF NOT EXISTS public.player_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  avatar_index INT NOT NULL DEFAULT 0,
  matches_played INT NOT NULL DEFAULT 0,
  matches_won INT NOT NULL DEFAULT 0,
  matches_lost INT NOT NULL DEFAULT 0,
  matches_tied INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Game Rooms
CREATE TABLE IF NOT EXISTS public.game_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_code VARCHAR(6) UNIQUE NOT NULL,
  host_user_id UUID NOT NULL REFERENCES public.player_profiles(id) ON DELETE CASCADE,
  guest_user_id UUID REFERENCES public.player_profiles(id) ON DELETE SET NULL,
  status room_status NOT NULL DEFAULT 'waiting',
  config JSONB NOT NULL DEFAULT '{"gameMode": "standard", "overs": null, "decisionTimerSeconds": 10, "seriesTargetPoints": 6}'::jsonb,
  host_confirmed BOOLEAN NOT NULL DEFAULT false,
  guest_confirmed BOOLEAN NOT NULL DEFAULT false,
  active_match_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 minutes')
);

CREATE INDEX IF NOT EXISTS idx_game_rooms_code ON public.game_rooms(room_code);
CREATE INDEX IF NOT EXISTS idx_game_rooms_host ON public.game_rooms(host_user_id);

-- Matches
CREATE TABLE IF NOT EXISTS public.matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.game_rooms(id) ON DELETE CASCADE,
  phase match_phase NOT NULL DEFAULT 'parity_assigned',
  version BIGINT NOT NULL DEFAULT 1,
  config JSONB NOT NULL,
  player1_id UUID NOT NULL REFERENCES public.player_profiles(id),
  player2_id UUID NOT NULL REFERENCES public.player_profiles(id),
  player1_parity player_parity NOT NULL,
  player2_parity player_parity NOT NULL,
  toss_winner_id UUID REFERENCES public.player_profiles(id),
  batting_first_id UUID REFERENCES public.player_profiles(id),
  current_innings_no SMALLINT NOT NULL DEFAULT 1,
  first_innings_runs INT NOT NULL DEFAULT 0,
  target_runs INT,
  current_batter_id UUID REFERENCES public.player_profiles(id),
  current_bowler_id UUID REFERENCES public.player_profiles(id),
  current_innings_runs INT NOT NULL DEFAULT 0,
  legal_balls_bowled INT NOT NULL DEFAULT 0,
  player1_timeout_points INT NOT NULL DEFAULT 0,
  player2_timeout_points INT NOT NULL DEFAULT 0,
  winner_id UUID REFERENCES public.player_profiles(id),
  result_type match_result_type,
  player1_series_score INT NOT NULL DEFAULT 0,
  player2_series_score INT NOT NULL DEFAULT 0,
  series_winner_id UUID REFERENCES public.player_profiles(id),
  turn_deadline_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_matches_room ON public.matches(room_id);
CREATE INDEX IF NOT EXISTS idx_matches_players ON public.matches(player1_id, player2_id);

-- Pending Submissions (Strictly Private)
CREATE TABLE IF NOT EXISTS public.pending_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  turn_type TEXT NOT NULL, -- 'toss' or 'ball'
  innings_no SMALLINT,
  ball_no INT,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  number_choice SMALLINT NOT NULL CHECK (number_choice >= 1 AND number_choice <= 10),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_pending_submission UNIQUE(match_id, turn_type, innings_no, ball_no, user_id)
);

-- Ball Events (Publicly Readable History for Resolved Balls)
CREATE TABLE IF NOT EXISTS public.ball_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  innings_no SMALLINT NOT NULL,
  ball_no INT NOT NULL,
  batter_id UUID NOT NULL REFERENCES public.player_profiles(id),
  bowler_id UUID NOT NULL REFERENCES public.player_profiles(id),
  batter_number SMALLINT NOT NULL CHECK (batter_number >= 1 AND batter_number <= 10),
  bowler_number SMALLINT NOT NULL CHECK (bowler_number >= 1 AND bowler_number <= 10),
  runs_scored SMALLINT NOT NULL,
  is_wicket BOOLEAN NOT NULL,
  cumulative_runs INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_match_ball UNIQUE (match_id, innings_no, ball_no)
);

CREATE INDEX IF NOT EXISTS idx_ball_events_match ON public.ball_events(match_id, innings_no);

-- Matchmaking Queue
CREATE TABLE IF NOT EXISTS public.matchmaking_queue (
  user_id UUID PRIMARY KEY REFERENCES public.player_profiles(id) ON DELETE CASCADE,
  config JSONB NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
