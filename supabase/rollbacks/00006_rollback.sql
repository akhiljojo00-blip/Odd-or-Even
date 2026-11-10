-- =====================================================================
-- Migration 00006 Rollback: Online Ranked Settlement & RPCs
-- =====================================================================
-- WARNING: DO NOT EXECUTE IN PRODUCTION UNLESS ROLLING BACK PHASE 5B.
-- This script removes all Online Ranked RPCs and the settlement function.
-- Casual multiplayer tables and existing casual RPCs remain completely untouched.
-- =====================================================================

DROP FUNCTION IF EXISTS public.rpc_get_ranked_leaderboard(INT, INT);
DROP FUNCTION IF EXISTS public.rpc_ranked_surrender(UUID);
DROP FUNCTION IF EXISTS public.rpc_ranked_claim_timeout_forfeit(UUID);
DROP FUNCTION IF EXISTS public.rpc_ranked_reconnect(UUID);
DROP FUNCTION IF EXISTS public.rpc_ranked_report_disconnect(UUID);
DROP FUNCTION IF EXISTS public.rpc_ranked_heartbeat(UUID);
DROP FUNCTION IF EXISTS public.rpc_ranked_start_second_innings(UUID);
DROP FUNCTION IF EXISTS public.rpc_ranked_select_role(UUID, TEXT);
DROP FUNCTION IF EXISTS public.rpc_ranked_submit_choice(UUID, TEXT, INT);
DROP FUNCTION IF EXISTS public.rpc_poll_ranked_matchmaking();
DROP FUNCTION IF EXISTS public.rpc_cancel_ranked_matchmaking();
DROP FUNCTION IF EXISTS public.rpc_join_ranked_matchmaking();
DROP FUNCTION IF EXISTS public.fn_settle_ranked_match(UUID);
