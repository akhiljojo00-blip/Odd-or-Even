-- =====================================================================
-- Migration 00002: Row Level Security (RLS) for Odd or Even
-- =====================================================================

-- Enable RLS on all tables
ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ball_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matchmaking_queue ENABLE ROW LEVEL SECURITY;

-- 1. player_profiles
-- Anyone can view profiles; users can only update their own profile.
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.player_profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.player_profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.player_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- 2. game_rooms
-- Anyone authenticated can view active rooms by code; participants can update
CREATE POLICY "Rooms viewable by authenticated users"
  ON public.game_rooms FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Host can insert room"
  ON public.game_rooms FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = host_user_id);

CREATE POLICY "Participants can update room"
  ON public.game_rooms FOR UPDATE
  TO authenticated
  USING (auth.uid() = host_user_id OR auth.uid() = guest_user_id);

-- 3. matches
-- Only match participants can view match state
CREATE POLICY "Participants can view their matches"
  ON public.matches FOR SELECT
  TO authenticated
  USING (auth.uid() = player1_id OR auth.uid() = player2_id);

-- Direct client updates to matches are FORBIDDEN (RPCs only)
CREATE POLICY "No direct client updates to matches"
  ON public.matches FOR UPDATE
  TO authenticated
  USING (false);

-- 4. pending_submissions
-- CRITICAL SECURITY RULE: No client can ever SELECT from pending_submissions
-- This guarantees Player A cannot inspect Player B's unrevealed number choice!
CREATE POLICY "Strict isolation: No direct client SELECT on pending submissions"
  ON public.pending_submissions FOR SELECT
  TO authenticated
  USING (false);

-- Submissions are handled via SECURITY DEFINER functions or direct own-row insert
CREATE POLICY "Users can insert only their own submission"
  ON public.pending_submissions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 5. ball_events
-- Match participants can read historical resolved balls
CREATE POLICY "Participants can view resolved ball events"
  ON public.ball_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = ball_events.match_id
      AND (m.player1_id = auth.uid() OR m.player2_id = auth.uid())
    )
  );

-- Direct insert/update/delete by clients forbidden
CREATE POLICY "No direct client modifications on ball_events"
  ON public.ball_events FOR INSERT
  TO authenticated
  WITH CHECK (false);

-- 6. matchmaking_queue
CREATE POLICY "Users can view own queue entry"
  ON public.matchmaking_queue FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own queue entry"
  ON public.matchmaking_queue FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own queue entry"
  ON public.matchmaking_queue FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
