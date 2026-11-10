-- =====================================================================
-- Migration 00005 Rollback: Online Ranked System Schema
-- =====================================================================
-- WARNING: DO NOT EXECUTE IN PRODUCTION UNLESS ROLLING BACK PHASE 5B.
-- This script tears down all Online Ranked tables, views, and policies.
-- Existing casual tables (game_rooms, matches, ball_events, player_profiles)
-- remain completely intact and preserved.
-- =====================================================================

-- 1. Drop Public Leaderboard View
DROP VIEW IF EXISTS public.v_ranked_leaderboard;

-- 2. Drop Ranked Tables in Dependency Order
DROP TABLE IF EXISTS public.ranked_abuse_events CASCADE;
DROP TABLE IF EXISTS public.ranked_season_history CASCADE;
DROP TABLE IF EXISTS public.ranked_daily_xp_tracking CASCADE;
DROP TABLE IF EXISTS public.ranked_matchmaking_queue CASCADE;
DROP TABLE IF EXISTS public.ranked_match_settlements CASCADE;
DROP TABLE IF EXISTS public.ranked_ball_events CASCADE;
DROP TABLE IF EXISTS public.ranked_pending_submissions CASCADE;
DROP TABLE IF EXISTS public.ranked_matches CASCADE;
DROP TABLE IF EXISTS public.online_ranked_stats CASCADE;
DROP TABLE IF EXISTS public.online_player_ranks CASCADE;
DROP TABLE IF EXISTS public.ranked_seasons CASCADE;

-- 3. Revert Casual Profile SEC-01 Policy (Restore Standard Profile Update)
DROP POLICY IF EXISTS "Users can update own profile cosmetics only" ON public.player_profiles;
CREATE POLICY "Users can update own profile" ON public.player_profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
GRANT UPDATE ON public.player_profiles TO authenticated;
