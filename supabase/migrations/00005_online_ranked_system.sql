-- =====================================================================
-- Migration 00005: Online Ranked System Schema & Security Architecture
-- =====================================================================
-- Target: Supabase / PostgreSQL 15+
-- Project: Odd or Even
-- Branch: feature/competitive-progression
-- Security: Server-Authoritative, Zero Client Trust, Least Privilege
-- =====================================================================

-- 1. Enum Extensions
-- Add 'abandoned' result type for mutual disconnect / simultaneous timeouts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type typ
    JOIN pg_enum enm ON enm.enumtypid = typ.oid
    WHERE typ.typname = 'match_result_type' AND enm.enumlabel = 'abandoned'
  ) THEN
    ALTER TYPE match_result_type ADD VALUE 'abandoned';
  END IF;
END $$;

-- 2. Ranked Seasons Table (Lifecycle & Archives)
CREATE TABLE IF NOT EXISTS public.ranked_seasons (
  id SERIAL PRIMARY KEY,
  season_number INT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_season_dates CHECK (ends_at > starts_at)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_season ON public.ranked_seasons(is_active) WHERE is_active = true;

-- Default Initial Season (Season 1)
INSERT INTO public.ranked_seasons (season_number, title, starts_at, ends_at, is_active)
VALUES (1, 'Inaugural Season', now(), now() + INTERVAL '90 days', true)
ON CONFLICT (season_number) DO NOTHING;

-- 3. Online Player Ranks (Authoritative Ranked Progression)
CREATE TABLE IF NOT EXISTS public.online_player_ranks (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp BIGINT NOT NULL DEFAULT 0,
  tier TEXT NOT NULL DEFAULT 'Bronze' CHECK (tier IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Elite', 'Pro Elite', 'Legend', 'Master', 'Grand Master')),
  division TEXT DEFAULT 'III' CHECK (division IN ('I', 'II', 'III') OR division IS NULL),
  stars INT NOT NULL DEFAULT 0,
  mmr INT NOT NULL DEFAULT 1000,
  peak_tier TEXT NOT NULL DEFAULT 'Bronze',
  peak_division TEXT DEFAULT 'III',
  peak_mmr INT NOT NULL DEFAULT 1000,
  win_streak INT NOT NULL DEFAULT 0,
  longest_win_streak INT NOT NULL DEFAULT 0,
  demotion_shield_active BOOLEAN NOT NULL DEFAULT false,
  total_ranked_matches INT NOT NULL DEFAULT 0,
  total_ranked_wins INT NOT NULL DEFAULT 0,
  total_ranked_losses INT NOT NULL DEFAULT 0,
  total_ranked_ties INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_valid_stars CHECK (stars >= 0 AND stars <= 10),
  CONSTRAINT chk_valid_mmr CHECK (mmr >= 100),
  CONSTRAINT chk_tier_division CHECK (
    (tier IN ('Master', 'Grand Master') AND division IS NULL) OR
    (tier NOT IN ('Master', 'Grand Master') AND division IN ('I', 'II', 'III'))
  )
);

CREATE INDEX IF NOT EXISTS idx_online_ranks_leaderboard ON public.online_player_ranks(mmr DESC, total_ranked_wins DESC, updated_at ASC);
CREATE INDEX IF NOT EXISTS idx_online_ranks_tier ON public.online_player_ranks(tier, division, stars DESC);

-- 4. Online Ranked Career Stats (Batting & Bowling Metrics)
CREATE TABLE IF NOT EXISTS public.online_ranked_stats (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_runs INT NOT NULL DEFAULT 0,
  total_wickets INT NOT NULL DEFAULT 0,
  highest_score INT NOT NULL DEFAULT 0,
  best_chase INT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_stats_nonnegative CHECK (total_runs >= 0 AND total_wickets >= 0 AND highest_score >= 0)
);

-- 5. Ranked Matches Table (Server-Authoritative Match State Machine)
CREATE TABLE IF NOT EXISTS public.ranked_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id INT REFERENCES public.ranked_seasons(id) ON DELETE SET NULL,
  phase match_phase NOT NULL DEFAULT 'toss_input',
  version BIGINT NOT NULL DEFAULT 1,
  config JSONB NOT NULL DEFAULT '{"number_range": 6, "overs": 2}'::jsonb,
  player1_id UUID NOT NULL REFERENCES auth.users(id),
  player2_id UUID NOT NULL REFERENCES auth.users(id),
  player1_parity player_parity NOT NULL,
  player2_parity player_parity NOT NULL,
  toss_winner_id UUID REFERENCES auth.users(id),
  batting_first_id UUID REFERENCES auth.users(id),
  current_innings_no SMALLINT NOT NULL DEFAULT 1,
  first_innings_runs INT NOT NULL DEFAULT 0,
  target_runs INT,
  current_batter_id UUID REFERENCES auth.users(id),
  current_bowler_id UUID REFERENCES auth.users(id),
  current_innings_runs INT NOT NULL DEFAULT 0,
  legal_balls_bowled INT NOT NULL DEFAULT 0,
  winner_id UUID REFERENCES auth.users(id),
  result_type match_result_type,
  turn_deadline_at TIMESTAMPTZ,
  player1_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  player2_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  p1_disconnected_at TIMESTAMPTZ,
  p2_disconnected_at TIMESTAMPTZ,
  p1_grace_expires_at TIMESTAMPTZ,
  p2_grace_expires_at TIMESTAMPTZ,
  p1_saved_turn_seconds INT,
  p2_saved_turn_seconds INT,
  p1_grace_remaining_seconds SMALLINT NOT NULL DEFAULT 30,
  p2_grace_remaining_seconds SMALLINT NOT NULL DEFAULT 30,
  p1_disconnect_count SMALLINT NOT NULL DEFAULT 0,
  p2_disconnect_count SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_distinct_players CHECK (player1_id != player2_id),
  CONSTRAINT chk_ranked_match_config CHECK ((config->>'number_range')::int = 6 AND (config->>'overs')::int = 2)
);

CREATE INDEX IF NOT EXISTS idx_ranked_matches_players ON public.ranked_matches(player1_id, player2_id);
CREATE INDEX IF NOT EXISTS idx_ranked_matches_active ON public.ranked_matches(phase) WHERE phase NOT IN ('match_finished', 'match_forfeited');

-- 6. Ranked Pending Submissions (Blind Submission Isolation - Zero Client SELECT)
CREATE TABLE IF NOT EXISTS public.ranked_pending_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.ranked_matches(id) ON DELETE CASCADE,
  turn_type TEXT NOT NULL, -- 'toss' or 'ball'
  innings_no SMALLINT,
  ball_no INT,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  number_choice SMALLINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_ranked_submission UNIQUE(match_id, turn_type, innings_no, ball_no, user_id),
  CONSTRAINT chk_ranked_choice CHECK (number_choice >= 1 AND number_choice <= 6)
);

-- 7. Ranked Ball Events (Public Delivery History - Simultaneously Revealed)
CREATE TABLE IF NOT EXISTS public.ranked_ball_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.ranked_matches(id) ON DELETE CASCADE,
  innings_no SMALLINT NOT NULL,
  ball_no INT NOT NULL,
  batter_id UUID NOT NULL REFERENCES auth.users(id),
  bowler_id UUID NOT NULL REFERENCES auth.users(id),
  batter_number SMALLINT NOT NULL,
  bowler_number SMALLINT NOT NULL,
  runs_scored SMALLINT NOT NULL,
  is_wicket BOOLEAN NOT NULL,
  cumulative_runs INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_ranked_ball UNIQUE(match_id, innings_no, ball_no)
);

CREATE INDEX IF NOT EXISTS idx_ranked_ball_events_match ON public.ranked_ball_events(match_id, innings_no);

-- 8. Ranked Match Settlements (Idempotency Table)
CREATE TABLE IF NOT EXISTS public.ranked_match_settlements (
  match_id UUID PRIMARY KEY REFERENCES public.ranked_matches(id) ON DELETE CASCADE,
  winner_id UUID REFERENCES auth.users(id),
  loser_id UUID REFERENCES auth.users(id),
  is_tie BOOLEAN NOT NULL DEFAULT false,
  is_forfeit BOOLEAN NOT NULL DEFAULT false,
  is_abandoned BOOLEAN NOT NULL DEFAULT false,
  legal_balls_bowled INT NOT NULL DEFAULT 0,
  is_early_forfeit BOOLEAN NOT NULL DEFAULT false,
  is_pair_star_capped BOOLEAN NOT NULL DEFAULT false,
  p1_stars_delta INT NOT NULL,
  p2_stars_delta INT NOT NULL,
  p1_mmr_delta INT NOT NULL,
  p2_mmr_delta INT NOT NULL,
  p1_xp_awarded INT NOT NULL,
  p2_xp_awarded INT NOT NULL,
  settled_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. Ranked Matchmaking Queue
CREATE TABLE IF NOT EXISTS public.ranked_matchmaking_queue (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  mmr INT NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ranked_queue_mmr ON public.ranked_matchmaking_queue(mmr, joined_at ASC);
CREATE INDEX IF NOT EXISTS idx_ranked_queue_heartbeat ON public.ranked_matchmaking_queue(heartbeat_at);

-- 10. Ranked Daily XP Tracking
CREATE TABLE IF NOT EXISTS public.ranked_daily_xp_tracking (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_date DATE NOT NULL DEFAULT ((now() AT TIME ZONE 'utc')::date),
  daily_xp_earned INT NOT NULL DEFAULT 0,
  first_daily_match_awarded BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, activity_date),
  CONSTRAINT chk_daily_xp_cap CHECK (daily_xp_earned >= 0 AND daily_xp_earned <= 1500)
);

-- 11. Ranked Season History (Archive for Past Seasons)
CREATE TABLE IF NOT EXISTS public.ranked_season_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id INT NOT NULL REFERENCES public.ranked_seasons(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  final_tier TEXT NOT NULL,
  final_division TEXT,
  final_stars INT NOT NULL,
  final_mmr INT NOT NULL,
  final_leaderboard_rank INT,
  total_matches INT NOT NULL DEFAULT 0,
  total_wins INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_season_user UNIQUE (season_id, user_id),
  CONSTRAINT chk_history_stars CHECK (final_stars >= 0 AND final_stars <= 10),
  CONSTRAINT chk_history_mmr CHECK (final_mmr >= 100)
);

-- 12. Ranked Abuse Events (Audit Logging for Capped Stars & Abuse Monitoring)
CREATE TABLE IF NOT EXISTS public.ranked_abuse_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL, -- 'pair_star_cap_reached', 'excessive_early_forfeits', etc.
  player1_id UUID NOT NULL REFERENCES auth.users(id),
  player2_id UUID NOT NULL REFERENCES auth.users(id),
  match_id UUID REFERENCES public.ranked_matches(id) ON DELETE CASCADE,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ranked_abuse_players ON public.ranked_abuse_events(player1_id, player2_id, created_at DESC);

-- =====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================

ALTER TABLE public.ranked_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.online_player_ranks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.online_ranked_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_pending_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_ball_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_match_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_matchmaking_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_daily_xp_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_season_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranked_abuse_events ENABLE ROW LEVEL SECURITY;

-- Read Policies
CREATE POLICY "Ranked seasons viewable by authenticated" ON public.ranked_seasons FOR SELECT TO authenticated USING (true);
CREATE POLICY "Player ranks viewable by authenticated" ON public.online_player_ranks FOR SELECT TO authenticated USING (true);
CREATE POLICY "Player stats viewable by authenticated" ON public.online_ranked_stats FOR SELECT TO authenticated USING (true);

CREATE POLICY "Participants view their ranked matches"
  ON public.ranked_matches FOR SELECT
  TO authenticated
  USING (auth.uid() = player1_id OR auth.uid() = player2_id);

CREATE POLICY "Participants view ranked ball events"
  ON public.ranked_ball_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.ranked_matches rm
      WHERE rm.id = ranked_ball_events.match_id
      AND (rm.player1_id = auth.uid() OR rm.player2_id = auth.uid())
    )
  );

CREATE POLICY "Participants view ranked match settlements"
  ON public.ranked_match_settlements FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.ranked_matches rm
      WHERE rm.id = ranked_match_settlements.match_id
      AND (rm.player1_id = auth.uid() OR rm.player2_id = auth.uid())
    )
  );

CREATE POLICY "Users view own daily XP" ON public.ranked_daily_xp_tracking FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Season history viewable by all authenticated" ON public.ranked_season_history FOR SELECT TO authenticated USING (true);

-- Matchmaking Queue Policies
CREATE POLICY "Users read own queue entry" ON public.ranked_matchmaking_queue FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users delete own queue entry" ON public.ranked_matchmaking_queue FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- =====================================================================
-- LEAST-PRIVILEGE GRANTS & ACCESS REVOCATIONS
-- =====================================================================

-- Revoke direct mutations on ranked tables from client roles
REVOKE INSERT, UPDATE, DELETE ON public.online_player_ranks FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.online_ranked_stats FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.ranked_matches FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.ranked_ball_events FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.ranked_match_settlements FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.ranked_seasons FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.ranked_season_history FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.ranked_daily_xp_tracking FROM authenticated, anon;
REVOKE ALL ON public.ranked_abuse_events FROM authenticated, anon;

-- Blind Submission Isolation (Zero Client Read)
REVOKE ALL ON public.ranked_pending_submissions FROM anon, authenticated;

-- Queue Grants (Authenticated users only read/delete own entry)
REVOKE ALL ON public.ranked_matchmaking_queue FROM anon;
GRANT SELECT, DELETE ON public.ranked_matchmaking_queue TO authenticated;

-- Table Select Grants
GRANT SELECT ON public.ranked_seasons TO authenticated, anon;
GRANT SELECT ON public.online_player_ranks TO authenticated, anon;
GRANT SELECT ON public.online_ranked_stats TO authenticated, anon;
GRANT SELECT ON public.ranked_matches TO authenticated;
GRANT SELECT ON public.ranked_ball_events TO authenticated;
GRANT SELECT ON public.ranked_match_settlements TO authenticated;
GRANT SELECT ON public.ranked_daily_xp_tracking TO authenticated;
GRANT SELECT ON public.ranked_season_history TO authenticated;

-- =====================================================================
-- PUBLIC LEADERBOARD PROJECTION (Anti-PII View)
-- =====================================================================
CREATE OR REPLACE VIEW public.v_ranked_leaderboard AS
SELECT 
  opr.user_id,
  pp.display_name,
  pp.avatar_index,
  opr.tier,
  opr.division,
  opr.stars,
  opr.mmr,
  opr.win_streak,
  opr.total_ranked_wins,
  opr.total_ranked_matches,
  DENSE_RANK() OVER (ORDER BY opr.mmr DESC, opr.total_ranked_wins DESC, opr.updated_at ASC) AS leaderboard_rank
FROM public.online_player_ranks opr
JOIN public.player_profiles pp ON pp.id = opr.user_id
WHERE opr.total_ranked_matches > 0;

GRANT SELECT ON public.v_ranked_leaderboard TO authenticated, anon;

-- =====================================================================
-- REMEDIATION OF SEC-01 (Lock Down Casual Profile Stats)
-- =====================================================================
-- Layer 1: Column-Level Privilege Revocation
REVOKE UPDATE ON public.player_profiles FROM authenticated;
GRANT UPDATE (display_name, avatar_index, updated_at) ON public.player_profiles TO authenticated;

-- Layer 2: RLS Row & Column Invariance Policy
DROP POLICY IF EXISTS "Users can update own profile" ON public.player_profiles;
CREATE POLICY "Users can update own profile cosmetics only"
  ON public.player_profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    matches_played IS NOT DISTINCT FROM (SELECT p.matches_played FROM public.player_profiles p WHERE p.id = auth.uid()) AND
    matches_won IS NOT DISTINCT FROM (SELECT p.matches_won FROM public.player_profiles p WHERE p.id = auth.uid()) AND
    matches_lost IS NOT DISTINCT FROM (SELECT p.matches_lost FROM public.player_profiles p WHERE p.id = auth.uid()) AND
    matches_tied IS NOT DISTINCT FROM (SELECT p.matches_tied FROM public.player_profiles p WHERE p.id = auth.uid())
  );
