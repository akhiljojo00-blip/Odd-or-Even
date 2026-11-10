-- =====================================================================
-- Migration 00006: Online Ranked Settlement & RPC Stored Procedures
-- =====================================================================
-- Target: Supabase / PostgreSQL 15+
-- Project: Odd or Even
-- Branch: feature/competitive-progression
-- Security: Server-Authoritative, Zero Client Trust, Least Privilege
-- =====================================================================

-- =====================================================================
-- 1. INTERNAL SETTLEMENT ENGINE (fn_settle_ranked_match)
-- =====================================================================
-- Strictly internal, non-exportable stored procedure.
-- Executed inside transactional RPC calls upon match conclusion.
CREATE OR REPLACE FUNCTION public.fn_settle_ranked_match(p_match_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_match public.ranked_matches%ROWTYPE;
  v_first_lock_id UUID;
  v_second_lock_id UUID;
  v_p1_rank public.online_player_ranks%ROWTYPE;
  v_p2_rank public.online_player_ranks%ROWTYPE;
  v_winner_id UUID;
  v_loser_id UUID;
  v_is_tie BOOLEAN;
  v_is_forfeit BOOLEAN;
  v_is_abandoned BOOLEAN;
  v_is_early_forfeit BOOLEAN;
  v_legal_balls INT;
  v_opponent_stars_today INT := 0;
  v_is_pair_star_capped BOOLEAN := false;
  
  -- Progression calculations
  v_p1_stars_delta INT := 0;
  v_p2_stars_delta INT := 0;
  v_p1_mmr_delta INT := 0;
  v_p2_mmr_delta INT := 0;
  v_p1_xp INT := 0;
  v_p2_xp INT := 0;
  
  -- Elo vars
  v_k1 INT;
  v_k2 INT;
  v_e1 FLOAT;
  v_e2 FLOAT;
  v_score1 FLOAT;
  v_score2 FLOAT;

  -- Player 1 intermediate state
  v_p1_is_win BOOLEAN := false;
  v_p1_is_loss BOOLEAN := false;
  v_p1_new_matches INT;
  v_p1_new_wins INT;
  v_p1_new_losses INT;
  v_p1_new_ties INT;
  v_p1_new_streak INT;
  v_p1_new_longest_streak INT;
  v_p1_new_tier TEXT;
  v_p1_new_div TEXT;
  v_p1_new_stars INT;
  v_p1_new_shield BOOLEAN;
  v_p1_peak_tier TEXT;
  v_p1_peak_div TEXT;
  v_p1_peak_mmr INT;
  v_p1_is_promo BOOLEAN := false;

  -- Player 2 intermediate state
  v_p2_is_win BOOLEAN := false;
  v_p2_is_loss BOOLEAN := false;
  v_p2_new_matches INT;
  v_p2_new_wins INT;
  v_p2_new_losses INT;
  v_p2_new_ties INT;
  v_p2_new_streak INT;
  v_p2_new_longest_streak INT;
  v_p2_new_tier TEXT;
  v_p2_new_div TEXT;
  v_p2_new_stars INT;
  v_p2_new_shield BOOLEAN;
  v_p2_peak_tier TEXT;
  v_p2_peak_div TEXT;
  v_p2_peak_mmr INT;
  v_p2_is_promo BOOLEAN := false;

  -- XP calculation helpers
  v_p1_daily_earned INT := 0;
  v_p1_daily_first BOOLEAN := false;
  v_p2_daily_earned INT := 0;
  v_p2_daily_first BOOLEAN := false;
  v_p1_base_xp INT := 0;
  v_p1_outcome_xp INT := 0;
  v_p1_daily_bonus INT := 0;
  v_p1_promo_bonus INT := 0;
  v_p1_uncapped_xp INT := 0;
  v_p1_rem_allowance INT := 0;
  v_p2_base_xp INT := 0;
  v_p2_outcome_xp INT := 0;
  v_p2_daily_bonus INT := 0;
  v_p2_promo_bonus INT := 0;
  v_p2_uncapped_xp INT := 0;
  v_p2_rem_allowance INT := 0;

  -- Career stats helpers
  v_p1_runs INT := 0;
  v_p1_wickets INT := 0;
  v_p2_runs INT := 0;
  v_p2_wickets INT := 0;
  v_p1_best_chase INT;
  v_p2_best_chase INT;
BEGIN
  -- 1. Acquire Match Row Lock First (Serializes concurrent settlement triggers)
  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  -- 2. Idempotency Check: if already settled, exit immediately
  IF EXISTS (SELECT 1 FROM public.ranked_match_settlements WHERE match_id = p_match_id) THEN
    RETURN;
  END IF;

  -- 2. Deterministic Row Locking (LEAST / GREATEST prevents deadlocks)
  IF v_match.player1_id < v_match.player2_id THEN
    v_first_lock_id := v_match.player1_id;
    v_second_lock_id := v_match.player2_id;
  ELSE
    v_first_lock_id := v_match.player2_id;
    v_second_lock_id := v_match.player1_id;
  END IF;

  -- Initialize rank and stats rows if missing
  INSERT INTO public.online_player_ranks (user_id) VALUES (v_first_lock_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.online_player_ranks (user_id) VALUES (v_second_lock_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.online_ranked_stats (user_id) VALUES (v_first_lock_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.online_ranked_stats (user_id) VALUES (v_second_lock_id) ON CONFLICT DO NOTHING;

  -- Lock both rank rows in deterministic UUID order
  PERFORM 1 FROM public.online_player_ranks WHERE user_id = v_first_lock_id FOR UPDATE;
  PERFORM 1 FROM public.online_player_ranks WHERE user_id = v_second_lock_id FOR UPDATE;

  SELECT * INTO v_p1_rank FROM public.online_player_ranks WHERE user_id = v_match.player1_id;
  SELECT * INTO v_p2_rank FROM public.online_player_ranks WHERE user_id = v_match.player2_id;

  v_winner_id := v_match.winner_id;
  v_is_tie := (v_match.result_type = 'tie');
  v_is_forfeit := (v_match.result_type = 'forfeit');
  v_is_abandoned := (v_match.result_type = 'abandoned' OR (v_winner_id IS NULL AND NOT v_is_tie));
  v_loser_id := CASE 
    WHEN v_is_tie OR v_is_abandoned THEN NULL 
    WHEN v_winner_id = v_match.player1_id THEN v_match.player2_id 
    ELSE v_match.player1_id 
  END;

  IF NOT v_is_tie AND NOT v_is_abandoned THEN
    v_p1_is_win := (v_winner_id = v_match.player1_id);
    v_p1_is_loss := NOT v_p1_is_win;
    v_p2_is_win := (v_winner_id = v_match.player2_id);
    v_p2_is_loss := NOT v_p2_is_win;
  END IF;

  -- Server-derived legal deliveries count
  SELECT count(*) INTO v_legal_balls FROM public.ranked_ball_events WHERE match_id = p_match_id;
  v_is_early_forfeit := (v_is_forfeit AND v_legal_balls < 4);

  -- 3. Elo / MMR Calculation (Section 12)
  v_k1 := CASE WHEN v_p1_rank.total_ranked_matches < 10 THEN 48 WHEN v_p1_rank.tier IN ('Master', 'Grand Master') THEN 24 ELSE 32 END;
  v_k2 := CASE WHEN v_p2_rank.total_ranked_matches < 10 THEN 48 WHEN v_p2_rank.tier IN ('Master', 'Grand Master') THEN 24 ELSE 32 END;

  v_e1 := 1.0 / (1.0 + 10.0 ^ ((v_p2_rank.mmr - v_p1_rank.mmr)::float / 400.0));
  v_e2 := 1.0 - v_e1;

  IF v_is_abandoned THEN
    -- Mutual timeout / abandonment: both suffer standard rating deduction
    v_p1_mmr_delta := -16;
    v_p2_mmr_delta := -16;
  ELSIF v_is_tie THEN
    v_score1 := 0.5; v_score2 := 0.5;
    v_p1_mmr_delta := round(v_k1 * (v_score1 - v_e1));
    v_p2_mmr_delta := round(v_k2 * (v_score2 - v_e2));
  ELSIF v_p1_is_win THEN
    v_score1 := 1.0; v_score2 := 0.0;
    v_p1_mmr_delta := GREATEST(10, round(v_k1 * (v_score1 - v_e1)));
    v_p2_mmr_delta := LEAST(-10, round(v_k2 * (v_score2 - v_e2)));
  ELSE
    v_score1 := 0.0; v_score2 := 1.0;
    v_p1_mmr_delta := LEAST(-10, round(v_k1 * (v_score1 - v_e1)));
    v_p2_mmr_delta := GREATEST(10, round(v_k2 * (v_score2 - v_e2)));
  END IF;

  -- Anti-farming override for Early Forfeits (< 4 deliveries)
  -- Approved Decision: Winner gets 0 MMR; forfeiter receives standard rating deduction
  IF v_is_early_forfeit THEN
    IF v_p1_is_win THEN
      v_p1_mmr_delta := 0;
      v_p2_mmr_delta := -16;
    ELSE
      v_p1_mmr_delta := -16;
      v_p2_mmr_delta := 0;
    END IF;
  END IF;

  -- Anti-collusion Opponent Daily Star Cap Check:
  -- Approved Decision: Strictly 2 win stars per player pair per UTC calendar day
  IF v_winner_id IS NOT NULL THEN
    SELECT COALESCE(SUM(CASE 
      WHEN rms.winner_id = v_winner_id THEN 
        CASE WHEN rms.winner_id = rm.player1_id THEN rms.p1_stars_delta ELSE rms.p2_stars_delta END
      ELSE 0 END), 0)
    INTO v_opponent_stars_today 
    FROM public.ranked_match_settlements rms
    JOIN public.ranked_matches rm ON rm.id = rms.match_id
    WHERE ((rm.player1_id = v_match.player1_id AND rm.player2_id = v_match.player2_id)
        OR (rm.player1_id = v_match.player2_id AND rm.player2_id = v_match.player1_id))
      AND (rms.settled_at AT TIME ZONE 'utc')::date = ((now() AT TIME ZONE 'utc')::date);

    v_is_pair_star_capped := (v_opponent_stars_today >= 2);
  END IF;

  -- 4. Canonical Progression Logic for Player 1 & Player 2
  v_p1_new_matches := v_p1_rank.total_ranked_matches + 1;
  v_p2_new_matches := v_p2_rank.total_ranked_matches + 1;
  v_p1_new_tier := v_p1_rank.tier;
  v_p1_new_div := CASE WHEN v_p1_rank.tier IN ('Master', 'Grand Master') THEN NULL ELSE COALESCE(v_p1_rank.division, 'III') END;
  v_p1_new_stars := v_p1_rank.stars;
  v_p1_new_shield := v_p1_rank.demotion_shield_active;
  v_p2_new_tier := v_p2_rank.tier;
  v_p2_new_div := CASE WHEN v_p2_rank.tier IN ('Master', 'Grand Master') THEN NULL ELSE COALESCE(v_p2_rank.division, 'III') END;
  v_p2_new_stars := v_p2_rank.stars;
  v_p2_new_shield := v_p2_rank.demotion_shield_active;

  -- ---------------- PLAYER 1 TRANSITION ----------------
  IF v_is_abandoned THEN
    v_p1_new_losses := v_p1_rank.total_ranked_losses + 1;
    v_p1_new_wins := v_p1_rank.total_ranked_wins;
    v_p1_new_ties := v_p1_rank.total_ranked_ties;
    v_p1_new_streak := 0;
    v_p1_new_longest_streak := v_p1_rank.longest_win_streak;
    v_p1_stars_delta := 0;
  ELSIF v_is_tie THEN
    v_p1_new_ties := v_p1_rank.total_ranked_ties + 1;
    v_p1_new_wins := v_p1_rank.total_ranked_wins;
    v_p1_new_losses := v_p1_rank.total_ranked_losses;
    v_p1_new_streak := v_p1_rank.win_streak; -- streak preserved on tie
    v_p1_new_longest_streak := v_p1_rank.longest_win_streak;
    v_p1_stars_delta := 0;
  ELSIF v_p1_is_win THEN
    v_p1_new_wins := v_p1_rank.total_ranked_wins + 1;
    v_p1_new_losses := v_p1_rank.total_ranked_losses;
    v_p1_new_ties := v_p1_rank.total_ranked_ties;
    v_p1_new_streak := v_p1_rank.win_streak + 1;
    v_p1_new_longest_streak := GREATEST(v_p1_rank.longest_win_streak, v_p1_new_streak);
    v_p1_new_shield := false; -- Reset shield on win

    IF v_is_early_forfeit OR v_is_pair_star_capped THEN
      -- Early forfeit or opponent daily star cap reached: 0 stars awarded
      v_p1_stars_delta := 0;
    ELSE
      -- Award 1 base star + streak bonus (+1 extra star on 3+ streak in Bronze, Silver, Gold)
      DECLARE
        v_potential_stars INT := CASE WHEN (v_p1_rank.tier IN ('Bronze', 'Silver', 'Gold') AND v_p1_new_streak >= 3) THEN 2 ELSE 1 END;
        v_stars_to_award INT := LEAST(v_potential_stars, GREATEST(0, 2 - v_opponent_stars_today));
        v_raw_stars INT;
        v_overflow INT;
      BEGIN
        IF v_stars_to_award <= 0 THEN
          v_is_pair_star_capped := true;
          v_stars_to_award := 0;
        END IF;

        v_raw_stars := v_p1_rank.stars + v_stars_to_award;
        v_p1_stars_delta := v_stars_to_award;

        IF v_p1_new_tier IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Elite', 'Pro Elite', 'Legend') THEN
          IF v_raw_stars >= 3 THEN
            v_overflow := v_raw_stars - 3;
            IF v_p1_new_div = 'III' THEN
              v_p1_new_div := 'II'; v_p1_new_stars := v_overflow; v_p1_is_promo := true;
            ELSIF v_p1_new_div = 'II' THEN
              v_p1_new_div := 'I'; v_p1_new_stars := v_overflow; v_p1_is_promo := true;
            ELSE -- Division I promotion to next Tier Division III
              v_p1_is_promo := true;
              v_p1_new_tier := CASE v_p1_new_tier
                WHEN 'Bronze' THEN 'Silver'
                WHEN 'Silver' THEN 'Gold'
                WHEN 'Gold' THEN 'Platinum'
                WHEN 'Platinum' THEN 'Diamond'
                WHEN 'Diamond' THEN 'Elite'
                WHEN 'Elite' THEN 'Pro Elite'
                WHEN 'Pro Elite' THEN 'Legend'
                WHEN 'Legend' THEN 'Master'
              END;
              IF v_p1_new_tier = 'Master' THEN
                v_p1_new_div := NULL; v_p1_new_stars := v_overflow;
              ELSE
                v_p1_new_div := 'III'; v_p1_new_stars := v_overflow;
              END IF;
            END IF;
          ELSE
            v_p1_new_stars := v_raw_stars;
          END IF;
        ELSIF v_p1_new_tier = 'Master' THEN
          -- Master requires 10 stars to unlock Grand Master eligibility
          IF v_raw_stars >= 10 THEN
            v_p1_new_tier := 'Grand Master'; v_p1_new_div := NULL; v_p1_new_stars := 0; v_p1_is_promo := true;
          ELSE
            v_p1_new_stars := v_raw_stars;
          END IF;
        ELSE -- Grand Master maintains 0 stars
          v_p1_new_stars := 0;
        END IF;
      END;
    END IF;
  ELSE -- P1 LOSS
    v_p1_new_losses := v_p1_rank.total_ranked_losses + 1;
    v_p1_new_wins := v_p1_rank.total_ranked_wins;
    v_p1_new_ties := v_p1_rank.total_ranked_ties;
    v_p1_new_streak := 0;
    v_p1_new_longest_streak := v_p1_rank.longest_win_streak;

    IF v_is_early_forfeit THEN
      -- Approved Decision: 0 stars for forfeiter on early forfeit
      v_p1_stars_delta := 0;
      v_p1_new_stars := v_p1_rank.stars;
    ELSIF v_p1_rank.tier = 'Bronze' THEN
      -- Zero star loss in Bronze
      v_p1_stars_delta := 0;
    ELSIF v_p1_rank.stars > 0 THEN
      -- Normal star decrement
      v_p1_new_stars := v_p1_rank.stars - 1;
      v_p1_stars_delta := -1;
    ELSIF (v_p1_rank.tier = 'Silver' AND v_p1_rank.division = 'III') OR (v_p1_rank.tier = 'Gold' AND v_p1_rank.division = 'III') THEN
      -- Silver III / Gold III absolute floors at 0 stars
      v_p1_new_stars := 0;
      v_p1_stars_delta := 0;
    ELSIF v_p1_rank.tier IN ('Platinum', 'Diamond', 'Elite', 'Pro Elite', 'Legend', 'Master') THEN
      IF NOT v_p1_rank.demotion_shield_active THEN
        -- Demotion shield absorbs loss!
        v_p1_new_shield := true;
        v_p1_new_stars := 0;
        v_p1_stars_delta := 0;
      ELSE
        -- Shield already depleted -> DEMOTION to lower division or tier with 2 stars
        v_p1_new_shield := false;
        v_p1_new_stars := 2;
        v_p1_stars_delta := -1;
        IF v_p1_rank.tier = 'Master' THEN
          v_p1_new_tier := 'Legend'; v_p1_new_div := 'I';
        ELSIF v_p1_new_div = 'I' THEN
          v_p1_new_div := 'II';
        ELSIF v_p1_new_div = 'II' THEN
          v_p1_new_div := 'III';
        ELSE -- Division III demotion to lower tier Division I
          v_p1_new_tier := CASE v_p1_new_tier
            WHEN 'Platinum' THEN 'Gold'
            WHEN 'Diamond' THEN 'Platinum'
            WHEN 'Elite' THEN 'Diamond'
            WHEN 'Pro Elite' THEN 'Elite'
            WHEN 'Legend' THEN 'Pro Elite'
          END;
          v_p1_new_div := 'I';
        END IF;
      END IF;
    ELSIF v_p1_rank.tier = 'Grand Master' THEN
      -- Grand Master drops to Master with 9 stars (no shield)
      v_p1_new_tier := 'Master';
      v_p1_new_div := NULL;
      v_p1_new_stars := 9;
      v_p1_stars_delta := -1;
      v_p1_new_shield := false;
    END IF;
  END IF;

  -- ---------------- PLAYER 2 TRANSITION ----------------
  IF v_is_abandoned THEN
    v_p2_new_losses := v_p2_rank.total_ranked_losses + 1;
    v_p2_new_wins := v_p2_rank.total_ranked_wins;
    v_p2_new_ties := v_p2_rank.total_ranked_ties;
    v_p2_new_streak := 0;
    v_p2_new_longest_streak := v_p2_rank.longest_win_streak;
    v_p2_stars_delta := 0;
  ELSIF v_is_tie THEN
    v_p2_new_ties := v_p2_rank.total_ranked_ties + 1;
    v_p2_new_wins := v_p2_rank.total_ranked_wins;
    v_p2_new_losses := v_p2_rank.total_ranked_losses;
    v_p2_new_streak := v_p2_rank.win_streak;
    v_p2_new_longest_streak := v_p2_rank.longest_win_streak;
    v_p2_stars_delta := 0;
  ELSIF v_p2_is_win THEN
    v_p2_new_wins := v_p2_rank.total_ranked_wins + 1;
    v_p2_new_losses := v_p2_rank.total_ranked_losses;
    v_p2_new_ties := v_p2_rank.total_ranked_ties;
    v_p2_new_streak := v_p2_rank.win_streak + 1;
    v_p2_new_longest_streak := GREATEST(v_p2_rank.longest_win_streak, v_p2_new_streak);
    v_p2_new_shield := false;

    IF v_is_early_forfeit OR v_is_pair_star_capped THEN
      v_p2_stars_delta := 0;
    ELSE
      DECLARE
        v_potential_stars INT := CASE WHEN (v_p2_rank.tier IN ('Bronze', 'Silver', 'Gold') AND v_p2_new_streak >= 3) THEN 2 ELSE 1 END;
        v_stars_to_award INT := LEAST(v_potential_stars, GREATEST(0, 2 - v_opponent_stars_today));
        v_raw_stars INT;
        v_overflow INT;
      BEGIN
        IF v_stars_to_award <= 0 THEN
          v_is_pair_star_capped := true;
          v_stars_to_award := 0;
        END IF;

        v_raw_stars := v_p2_rank.stars + v_stars_to_award;
        v_p2_stars_delta := v_stars_to_award;

        IF v_p2_new_tier IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Elite', 'Pro Elite', 'Legend') THEN
          IF v_raw_stars >= 3 THEN
            v_overflow := v_raw_stars - 3;
            IF v_p2_new_div = 'III' THEN
              v_p2_new_div := 'II'; v_p2_new_stars := v_overflow; v_p2_is_promo := true;
            ELSIF v_p2_new_div = 'II' THEN
              v_p2_new_div := 'I'; v_p2_new_stars := v_overflow; v_p2_is_promo := true;
            ELSE
              v_p2_is_promo := true;
              v_p2_new_tier := CASE v_p2_new_tier
                WHEN 'Bronze' THEN 'Silver'
                WHEN 'Silver' THEN 'Gold'
                WHEN 'Gold' THEN 'Platinum'
                WHEN 'Platinum' THEN 'Diamond'
                WHEN 'Diamond' THEN 'Elite'
                WHEN 'Elite' THEN 'Pro Elite'
                WHEN 'Pro Elite' THEN 'Legend'
                WHEN 'Legend' THEN 'Master'
              END;
              IF v_p2_new_tier = 'Master' THEN
                v_p2_new_div := NULL; v_p2_new_stars := v_overflow;
              ELSE
                v_p2_new_div := 'III'; v_p2_new_stars := v_overflow;
              END IF;
            END IF;
          ELSE
            v_p2_new_stars := v_raw_stars;
          END IF;
        ELSIF v_p2_new_tier = 'Master' THEN
          -- Master requires 10 stars to unlock Grand Master eligibility
          IF v_raw_stars >= 10 THEN
            v_p2_new_tier := 'Grand Master'; v_p2_new_div := NULL; v_p2_new_stars := 0; v_p2_is_promo := true;
          ELSE
            v_p2_new_stars := v_raw_stars;
          END IF;
        ELSE
          v_p2_new_stars := 0;
        END IF;
      END;
    END IF;
  ELSE -- P2 LOSS
    v_p2_new_losses := v_p2_rank.total_ranked_losses + 1;
    v_p2_new_wins := v_p2_rank.total_ranked_wins;
    v_p2_new_ties := v_p2_rank.total_ranked_ties;
    v_p2_new_streak := 0;
    v_p2_new_longest_streak := v_p2_rank.longest_win_streak;

    IF v_is_early_forfeit THEN
      -- Approved Decision: 0 stars for forfeiter on early forfeit
      v_p2_stars_delta := 0;
      v_p2_new_stars := v_p2_rank.stars;
    ELSIF v_p2_rank.tier = 'Bronze' THEN
      v_p2_stars_delta := 0;
    ELSIF v_p2_rank.stars > 0 THEN
      v_p2_new_stars := v_p2_rank.stars - 1;
      v_p2_stars_delta := -1;
    ELSIF (v_p2_rank.tier = 'Silver' AND v_p2_rank.division = 'III') OR (v_p2_rank.tier = 'Gold' AND v_p2_rank.division = 'III') THEN
      v_p2_new_stars := 0;
      v_p2_stars_delta := 0;
    ELSIF v_p2_rank.tier IN ('Platinum', 'Diamond', 'Elite', 'Pro Elite', 'Legend', 'Master') THEN
      IF NOT v_p2_rank.demotion_shield_active THEN
        v_p2_new_shield := true;
        v_p2_new_stars := 0;
        v_p2_stars_delta := 0;
      ELSE
        v_p2_new_shield := false;
        v_p2_new_stars := 2;
        v_p2_stars_delta := -1;
        IF v_p2_rank.tier = 'Master' THEN
          v_p2_new_tier := 'Legend'; v_p2_new_div := 'I';
        ELSIF v_p2_new_div = 'I' THEN
          v_p2_new_div := 'II';
        ELSIF v_p2_new_div = 'II' THEN
          v_p2_new_div := 'III';
        ELSE
          v_p2_new_tier := CASE v_p2_new_tier
            WHEN 'Platinum' THEN 'Gold'
            WHEN 'Diamond' THEN 'Platinum'
            WHEN 'Elite' THEN 'Diamond'
            WHEN 'Pro Elite' THEN 'Elite'
            WHEN 'Legend' THEN 'Pro Elite'
          END;
          v_p2_new_div := 'I';
        END IF;
      END IF;
    ELSIF v_p2_rank.tier = 'Grand Master' THEN
      v_p2_new_tier := 'Master';
      v_p2_new_div := NULL;
      v_p2_new_stars := 9;
      v_p2_stars_delta := -1;
      v_p2_new_shield := false;
    END IF;
  END IF;

  -- Peak Rank Updates for P1 and P2
  v_p1_peak_tier := v_p1_rank.peak_tier;
  v_p1_peak_div := v_p1_rank.peak_division;
  v_p1_peak_mmr := GREATEST(v_p1_rank.peak_mmr, v_p1_rank.mmr + v_p1_mmr_delta);
  IF (SELECT CASE v_p1_new_tier WHEN 'Grand Master' THEN 9 WHEN 'Master' THEN 8 WHEN 'Legend' THEN 7 WHEN 'Pro Elite' THEN 6 WHEN 'Elite' THEN 5 WHEN 'Diamond' THEN 4 WHEN 'Platinum' THEN 3 WHEN 'Gold' THEN 2 WHEN 'Silver' THEN 1 ELSE 0 END) > 
     (SELECT CASE v_p1_peak_tier WHEN 'Grand Master' THEN 9 WHEN 'Master' THEN 8 WHEN 'Legend' THEN 7 WHEN 'Pro Elite' THEN 6 WHEN 'Elite' THEN 5 WHEN 'Diamond' THEN 4 WHEN 'Platinum' THEN 3 WHEN 'Gold' THEN 2 WHEN 'Silver' THEN 1 ELSE 0 END) THEN
    v_p1_peak_tier := v_p1_new_tier; v_p1_peak_div := v_p1_new_div;
  ELSIF v_p1_new_tier = v_p1_peak_tier AND (SELECT CASE v_p1_new_div WHEN 'I' THEN 1 WHEN 'II' THEN 2 ELSE 3 END) < (SELECT CASE v_p1_peak_div WHEN 'I' THEN 1 WHEN 'II' THEN 2 ELSE 3 END) THEN
    v_p1_peak_div := v_p1_new_div;
  END IF;

  v_p2_peak_tier := v_p2_rank.peak_tier;
  v_p2_peak_div := v_p2_rank.peak_division;
  v_p2_peak_mmr := GREATEST(v_p2_rank.peak_mmr, v_p2_rank.mmr + v_p2_mmr_delta);
  IF (SELECT CASE v_p2_new_tier WHEN 'Grand Master' THEN 9 WHEN 'Master' THEN 8 WHEN 'Legend' THEN 7 WHEN 'Pro Elite' THEN 6 WHEN 'Elite' THEN 5 WHEN 'Diamond' THEN 4 WHEN 'Platinum' THEN 3 WHEN 'Gold' THEN 2 WHEN 'Silver' THEN 1 ELSE 0 END) > 
     (SELECT CASE v_p2_peak_tier WHEN 'Grand Master' THEN 9 WHEN 'Master' THEN 8 WHEN 'Legend' THEN 7 WHEN 'Pro Elite' THEN 6 WHEN 'Elite' THEN 5 WHEN 'Diamond' THEN 4 WHEN 'Platinum' THEN 3 WHEN 'Gold' THEN 2 WHEN 'Silver' THEN 1 ELSE 0 END) THEN
    v_p2_peak_tier := v_p2_new_tier; v_p2_peak_div := v_p2_new_div;
  ELSIF v_p2_new_tier = v_p2_peak_tier AND (SELECT CASE v_p2_new_div WHEN 'I' THEN 1 WHEN 'II' THEN 2 ELSE 3 END) < (SELECT CASE v_p2_peak_div WHEN 'I' THEN 1 WHEN 'II' THEN 2 ELSE 3 END) THEN
    v_p2_peak_div := v_p2_new_div;
  END IF;

  -- 5. Canonical XP Calculation & Daily Cap Enforcing
  IF v_legal_balls >= 4 AND NOT v_is_abandoned THEN
    -- P1 XP Calculation
    SELECT daily_xp_earned, first_daily_match_awarded INTO v_p1_daily_earned, v_p1_daily_first
    FROM public.ranked_daily_xp_tracking WHERE user_id = v_match.player1_id AND activity_date = ((now() AT TIME ZONE 'utc')::date);
    IF NOT FOUND THEN
      v_p1_daily_earned := 0; v_p1_daily_first := false;
      INSERT INTO public.ranked_daily_xp_tracking (user_id, activity_date) VALUES (v_match.player1_id, ((now() AT TIME ZONE 'utc')::date)) ON CONFLICT DO NOTHING;
    END IF;

    v_p1_base_xp := 20;
    v_p1_outcome_xp := CASE WHEN v_p1_is_win THEN 30 WHEN v_is_tie THEN 15 ELSE 10 END;
    v_p1_daily_bonus := CASE WHEN NOT v_p1_daily_first THEN 20 ELSE 0 END;
    v_p1_promo_bonus := CASE WHEN v_p1_is_promo THEN 50 ELSE 0 END;
    v_p1_uncapped_xp := v_p1_base_xp + v_p1_outcome_xp + v_p1_daily_bonus + v_p1_promo_bonus;
    v_p1_rem_allowance := GREATEST(0, 1500 - v_p1_daily_earned);
    v_p1_xp := LEAST(v_p1_uncapped_xp, v_p1_rem_allowance);

    UPDATE public.ranked_daily_xp_tracking
    SET daily_xp_earned = daily_xp_earned + v_p1_xp,
        first_daily_match_awarded = (first_daily_match_awarded OR (v_p1_daily_bonus > 0)),
        updated_at = now()
    WHERE user_id = v_match.player1_id AND activity_date = ((now() AT TIME ZONE 'utc')::date);

    -- P2 XP Calculation
    SELECT daily_xp_earned, first_daily_match_awarded INTO v_p2_daily_earned, v_p2_daily_first
    FROM public.ranked_daily_xp_tracking WHERE user_id = v_match.player2_id AND activity_date = ((now() AT TIME ZONE 'utc')::date);
    IF NOT FOUND THEN
      v_p2_daily_earned := 0; v_p2_daily_first := false;
      INSERT INTO public.ranked_daily_xp_tracking (user_id, activity_date) VALUES (v_match.player2_id, ((now() AT TIME ZONE 'utc')::date)) ON CONFLICT DO NOTHING;
    END IF;

    v_p2_base_xp := 20;
    v_p2_outcome_xp := CASE WHEN v_p2_is_win THEN 30 WHEN v_is_tie THEN 15 ELSE 10 END;
    v_p2_daily_bonus := CASE WHEN NOT v_p2_daily_first THEN 20 ELSE 0 END;
    v_p2_promo_bonus := CASE WHEN v_p2_is_promo THEN 50 ELSE 0 END;
    v_p2_uncapped_xp := v_p2_base_xp + v_p2_outcome_xp + v_p2_daily_bonus + v_p2_promo_bonus;
    v_p2_rem_allowance := GREATEST(0, 1500 - v_p2_daily_earned);
    v_p2_xp := LEAST(v_p2_uncapped_xp, v_p2_rem_allowance);

    UPDATE public.ranked_daily_xp_tracking
    SET daily_xp_earned = daily_xp_earned + v_p2_xp,
        first_daily_match_awarded = (first_daily_match_awarded OR (v_p2_daily_bonus > 0)),
        updated_at = now()
    WHERE user_id = v_match.player2_id AND activity_date = ((now() AT TIME ZONE 'utc')::date);
  END IF;

  -- 6. Record Settlement Idempotency Row
  INSERT INTO public.ranked_match_settlements (
    match_id, winner_id, loser_id, is_tie, is_forfeit, is_abandoned, legal_balls_bowled, is_early_forfeit,
    is_pair_star_capped, p1_stars_delta, p2_stars_delta, p1_mmr_delta, p2_mmr_delta, p1_xp_awarded, p2_xp_awarded, settled_at
  ) VALUES (
    p_match_id, v_winner_id, v_loser_id, v_is_tie, v_is_forfeit, v_is_abandoned, v_legal_balls, v_is_early_forfeit,
    v_is_pair_star_capped, v_p1_stars_delta, v_p2_stars_delta, v_p1_mmr_delta, v_p2_mmr_delta, v_p1_xp, v_p2_xp, now()
  );

  -- 7. Record Abuse Event if Daily Star Cap was Reached
  IF v_is_pair_star_capped THEN
    INSERT INTO public.ranked_abuse_events (event_type, player1_id, player2_id, match_id, details)
    VALUES (
      'pair_star_cap_reached',
      v_match.player1_id,
      v_match.player2_id,
      p_match_id,
      jsonb_build_object(
        'winner_id', v_winner_id,
        'stars_already_earned_today', v_opponent_stars_today,
        'action_taken', 'stars_clamped_to_zero'
      )
    );
  END IF;

  -- 8. Update Online Player Ranks Atomically
  UPDATE public.online_player_ranks
  SET total_xp = total_xp + v_p1_xp,
      tier = v_p1_new_tier,
      division = v_p1_new_div,
      stars = v_p1_new_stars,
      mmr = GREATEST(100, mmr + v_p1_mmr_delta),
      peak_tier = v_p1_peak_tier,
      peak_division = v_p1_peak_div,
      peak_mmr = v_p1_peak_mmr,
      win_streak = v_p1_new_streak,
      longest_win_streak = v_p1_new_longest_streak,
      demotion_shield_active = v_p1_new_shield,
      total_ranked_matches = v_p1_new_matches,
      total_ranked_wins = v_p1_new_wins,
      total_ranked_losses = v_p1_new_losses,
      total_ranked_ties = v_p1_new_ties,
      updated_at = now()
  WHERE user_id = v_match.player1_id;

  UPDATE public.online_player_ranks
  SET total_xp = total_xp + v_p2_xp,
      tier = v_p2_new_tier,
      division = v_p2_new_div,
      stars = v_p2_new_stars,
      mmr = GREATEST(100, mmr + v_p2_mmr_delta),
      peak_tier = v_p2_peak_tier,
      peak_division = v_p2_peak_div,
      peak_mmr = v_p2_peak_mmr,
      win_streak = v_p2_new_streak,
      longest_win_streak = v_p2_new_longest_streak,
      demotion_shield_active = v_p2_new_shield,
      total_ranked_matches = v_p2_new_matches,
      total_ranked_wins = v_p2_new_wins,
      total_ranked_losses = v_p2_new_losses,
      total_ranked_ties = v_p2_new_ties,
      updated_at = now()
  WHERE user_id = v_match.player2_id;

  -- 9. Update Career Batting & Bowling Stats
  SELECT COALESCE(sum(runs_scored), 0) INTO v_p1_runs FROM public.ranked_ball_events WHERE match_id = p_match_id AND batter_id = v_match.player1_id;
  SELECT count(*) INTO v_p1_wickets FROM public.ranked_ball_events WHERE match_id = p_match_id AND bowler_id = v_match.player1_id AND is_wicket = true;
  SELECT COALESCE(sum(runs_scored), 0) INTO v_p2_runs FROM public.ranked_ball_events WHERE match_id = p_match_id AND batter_id = v_match.player2_id;
  SELECT count(*) INTO v_p2_wickets FROM public.ranked_ball_events WHERE match_id = p_match_id AND bowler_id = v_match.player2_id AND is_wicket = true;

  v_p1_best_chase := CASE WHEN v_match.batting_first_id != v_match.player1_id AND v_p1_is_win THEN v_match.target_runs ELSE NULL END;
  v_p2_best_chase := CASE WHEN v_match.batting_first_id != v_match.player2_id AND v_p2_is_win THEN v_match.target_runs ELSE NULL END;

  UPDATE public.online_ranked_stats
  SET total_runs = total_runs + v_p1_runs,
      total_wickets = total_wickets + v_p1_wickets,
      highest_score = GREATEST(highest_score, v_p1_runs),
      best_chase = CASE WHEN v_p1_best_chase IS NOT NULL THEN GREATEST(COALESCE(best_chase, 0), v_p1_best_chase) ELSE best_chase END,
      updated_at = now()
  WHERE user_id = v_match.player1_id;

  UPDATE public.online_ranked_stats
  SET total_runs = total_runs + v_p2_runs,
      total_wickets = total_wickets + v_p2_wickets,
      highest_score = GREATEST(highest_score, v_p2_runs),
      best_chase = CASE WHEN v_p2_best_chase IS NOT NULL THEN GREATEST(COALESCE(best_chase, 0), v_p2_best_chase) ELSE best_chase END,
      updated_at = now()
  WHERE user_id = v_match.player2_id;

  -- 10. Clean up transient blind choices for this settled match
  DELETE FROM public.ranked_pending_submissions WHERE match_id = p_match_id;
END;
$$;

-- Revoke all execute privileges on internal settlement from client roles
REVOKE ALL ON FUNCTION public.fn_settle_ranked_match(UUID) FROM PUBLIC, anon, authenticated;

-- =====================================================================
-- 2. MATCHMAKING RPCS
-- =====================================================================

-- 2.1 Join Ranked Matchmaking Queue
CREATE OR REPLACE FUNCTION public.rpc_join_ranked_matchmaking()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_rank public.online_player_ranks%ROWTYPE;
  v_matched_user_id UUID;
  v_match_id UUID;
  v_p1_parity player_parity;
  v_p2_parity player_parity;
  v_season_id INT;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Ensure caller is not already in an active match
  IF EXISTS (
    SELECT 1 FROM public.ranked_matches
    WHERE (player1_id = v_caller_id OR player2_id = v_caller_id)
      AND phase NOT IN ('match_finished', 'match_forfeited')
  ) THEN
    SELECT id INTO v_match_id FROM public.ranked_matches
    WHERE (player1_id = v_caller_id OR player2_id = v_caller_id)
      AND phase NOT IN ('match_finished', 'match_forfeited')
    LIMIT 1;
    RETURN jsonb_build_object('status', 'active_match_exists', 'match_id', v_match_id);
  END IF;

  -- Ensure caller rank row exists
  INSERT INTO public.online_player_ranks (user_id)
  VALUES (v_caller_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT * INTO v_caller_rank FROM public.online_player_ranks WHERE user_id = v_caller_id;

  -- Try to match with an opponent in queue with MMR within +/- 200 band and fresh heartbeat (<= 45s)
  SELECT user_id INTO v_matched_user_id
  FROM public.ranked_matchmaking_queue
  WHERE user_id != v_caller_id
    AND heartbeat_at >= now() - INTERVAL '45 seconds'
    AND mmr BETWEEN (v_caller_rank.mmr - 200) AND (v_caller_rank.mmr + 200)
  ORDER BY joined_at ASC
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF v_matched_user_id IS NOT NULL THEN
    -- Opponent found: Remove opponent from queue and create match
    DELETE FROM public.ranked_matchmaking_queue WHERE user_id = v_matched_user_id;
    DELETE FROM public.ranked_matchmaking_queue WHERE user_id = v_caller_id;

    -- Random parity assignment
    IF random() < 0.5 THEN
      v_p1_parity := 'odd';
      v_p2_parity := 'even';
    ELSE
      v_p1_parity := 'even';
      v_p2_parity := 'odd';
    END IF;

    SELECT id INTO v_season_id FROM public.ranked_seasons WHERE is_active = true LIMIT 1;

    INSERT INTO public.ranked_matches (
      season_id, player1_id, player2_id, player1_parity, player2_parity,
      phase, turn_deadline_at, player1_heartbeat_at, player2_heartbeat_at
    ) VALUES (
      v_season_id, v_caller_id, v_matched_user_id, v_p1_parity, v_p2_parity,
      'toss_input', now() + INTERVAL '20 seconds', now(), now()
    ) RETURNING id INTO v_match_id;

    RETURN jsonb_build_object('status', 'matched', 'match_id', v_match_id);
  ELSE
    -- No immediate opponent: insert or update caller queue entry with fresh heartbeat
    INSERT INTO public.ranked_matchmaking_queue (user_id, mmr, joined_at, heartbeat_at)
    VALUES (v_caller_id, v_caller_rank.mmr, now(), now())
    ON CONFLICT (user_id) DO UPDATE SET mmr = EXCLUDED.mmr, heartbeat_at = now();

    RETURN jsonb_build_object('status', 'queued');
  END IF;
END;
$$;

-- 2.2 Cancel Matchmaking
CREATE OR REPLACE FUNCTION public.rpc_cancel_ranked_matchmaking()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM public.ranked_matchmaking_queue WHERE user_id = v_caller_id;
  RETURN jsonb_build_object('status', 'cancelled');
END;
$$;

-- 2.3 Poll Matchmaking Status
CREATE OR REPLACE FUNCTION public.rpc_poll_ranked_matchmaking()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match_id UUID;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Check if caller is in an active match
  SELECT id INTO v_match_id
  FROM public.ranked_matches
  WHERE (player1_id = v_caller_id OR player2_id = v_caller_id)
    AND phase NOT IN ('match_finished', 'match_forfeited')
  LIMIT 1;

  IF v_match_id IS NOT NULL THEN
    -- Ensure removed from queue
    DELETE FROM public.ranked_matchmaking_queue WHERE user_id = v_caller_id;
    RETURN jsonb_build_object('status', 'matched', 'match_id', v_match_id);
  END IF;

  -- Check if still in queue; if so, refresh heartbeat and confirm queued
  UPDATE public.ranked_matchmaking_queue
  SET heartbeat_at = now()
  WHERE user_id = v_caller_id;

  IF FOUND THEN
    RETURN jsonb_build_object('status', 'queued');
  END IF;

  RETURN jsonb_build_object('status', 'not_queued');
END;
$$;

-- =====================================================================
-- 3. GAMEPLAY & STATE MACHINE RPCS
-- =====================================================================

-- 3.1 Submit Secret Choice (Toss or Delivery)
CREATE OR REPLACE FUNCTION public.rpc_ranked_submit_choice(
  p_match_id UUID,
  p_turn_type TEXT,
  p_choice INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match public.ranked_matches%ROWTYPE;
  v_opponent_id UUID;
  v_p1_sub INT;
  v_p2_sub INT;
  v_batter_sub INT;
  v_bowler_sub INT;
  v_sum INT;
  v_toss_winner_id UUID;
  v_is_wicket BOOLEAN;
  v_runs_scored SMALLINT;
  v_new_innings_runs INT;
  v_new_legal_balls INT;
  v_ball_no INT;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate choice range: strictly 1 to 6
  IF p_choice < 1 OR p_choice > 6 THEN
    RAISE EXCEPTION 'Invalid choice: must be between 1 and 6';
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  -- Authorize participant
  IF v_caller_id != v_match.player1_id AND v_caller_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Caller is not a participant in this match';
  END IF;

  v_opponent_id := CASE WHEN v_caller_id = v_match.player1_id THEN v_match.player2_id ELSE v_match.player1_id END;

  -- Update caller heartbeat
  IF v_caller_id = v_match.player1_id THEN
    v_match.player1_heartbeat_at := now();
  ELSE
    v_match.player2_heartbeat_at := now();
  END IF;

  -- -------------------------------------------------------------
  -- CASE A: TOSS SUBMISSION
  -- -------------------------------------------------------------
  IF p_turn_type = 'toss' THEN
    IF v_match.phase != 'toss_input' THEN
      RAISE EXCEPTION 'Match is not in toss_input phase (current: %)', v_match.phase;
    END IF;

    -- Insert secret submission with unique constraint
    INSERT INTO public.ranked_pending_submissions (
      match_id, turn_type, innings_no, ball_no, user_id, number_choice
    ) VALUES (
      p_match_id, 'toss', 0, 0, v_caller_id, p_choice
    ) ON CONFLICT DO NOTHING;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Toss choice already submitted';
    END IF;

    -- Check if both players have submitted toss
    SELECT number_choice INTO v_p1_sub FROM public.ranked_pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'toss' AND user_id = v_match.player1_id;

    SELECT number_choice INTO v_p2_sub FROM public.ranked_pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'toss' AND user_id = v_match.player2_id;

    IF v_p1_sub IS NOT NULL AND v_p2_sub IS NOT NULL THEN
      -- Both submitted: Resolve toss
      v_sum := v_p1_sub + v_p2_sub;
      IF (v_sum % 2 = 1 AND v_match.player1_parity = 'odd') OR (v_sum % 2 = 0 AND v_match.player1_parity = 'even') THEN
        v_toss_winner_id := v_match.player1_id;
      ELSE
        v_toss_winner_id := v_match.player2_id;
      END IF;

      UPDATE public.ranked_matches
      SET phase = 'role_selection',
          toss_winner_id = v_toss_winner_id,
          turn_deadline_at = now() + INTERVAL '20 seconds',
          player1_heartbeat_at = v_match.player1_heartbeat_at,
          player2_heartbeat_at = v_match.player2_heartbeat_at,
          updated_at = now()
      WHERE id = p_match_id;

      RETURN jsonb_build_object(
        'status', 'toss_resolved',
        'p1_choice', v_p1_sub,
        'p2_choice', v_p2_sub,
        'sum', v_sum,
        'toss_winner_id', v_toss_winner_id
      );
    ELSE
      -- Waiting for opponent toss
      UPDATE public.ranked_matches
      SET player1_heartbeat_at = v_match.player1_heartbeat_at,
          player2_heartbeat_at = v_match.player2_heartbeat_at,
          updated_at = now()
      WHERE id = p_match_id;

      RETURN jsonb_build_object('status', 'waiting_for_opponent');
    END IF;

  -- -------------------------------------------------------------
  -- CASE B: BALL SUBMISSION
  -- -------------------------------------------------------------
  ELSIF p_turn_type = 'ball' THEN
    IF v_match.phase != 'first_innings' AND v_match.phase != 'second_innings' THEN
      RAISE EXCEPTION 'Match is not in an active innings phase (current: %)', v_match.phase;
    END IF;

    -- Verify caller is current batter or current bowler
    IF v_caller_id != v_match.current_batter_id AND v_caller_id != v_match.current_bowler_id THEN
      RAISE EXCEPTION 'Caller is not the current batter or bowler';
    END IF;

    v_ball_no := v_match.legal_balls_bowled + 1;

    -- Insert blind submission
    INSERT INTO public.ranked_pending_submissions (
      match_id, turn_type, innings_no, ball_no, user_id, number_choice
    ) VALUES (
      p_match_id, 'ball', v_match.current_innings_no, v_ball_no, v_caller_id, p_choice
    ) ON CONFLICT DO NOTHING;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Ball choice already submitted for this delivery';
    END IF;

    -- Check if both batter and bowler submitted
    SELECT number_choice INTO v_batter_sub FROM public.ranked_pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'ball' AND innings_no = v_match.current_innings_no
      AND ball_no = v_ball_no AND user_id = v_match.current_batter_id;

    SELECT number_choice INTO v_bowler_sub FROM public.ranked_pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'ball' AND innings_no = v_match.current_innings_no
      AND ball_no = v_ball_no AND user_id = v_match.current_bowler_id;

    IF v_batter_sub IS NOT NULL AND v_bowler_sub IS NOT NULL THEN
      -- Both submitted: Resolve delivery
      v_is_wicket := (v_batter_sub = v_bowler_sub);
      v_runs_scored := CASE WHEN v_is_wicket THEN 0 ELSE v_batter_sub END;
      v_new_innings_runs := v_match.current_innings_runs + v_runs_scored;
      v_new_legal_balls := v_ball_no;

      -- Insert into public ball events
      INSERT INTO public.ranked_ball_events (
        match_id, innings_no, ball_no, batter_id, bowler_id,
        batter_number, bowler_number, runs_scored, is_wicket, cumulative_runs
      ) VALUES (
        p_match_id, v_match.current_innings_no, v_new_legal_balls,
        v_match.current_batter_id, v_match.current_bowler_id,
        v_batter_sub, v_bowler_sub, v_runs_scored, v_is_wicket, v_new_innings_runs
      );

      -- Check First Innings Completion (Wicket OR 12 balls / 2 overs)
      IF v_match.current_innings_no = 1 THEN
        IF v_is_wicket OR v_new_legal_balls >= 12 THEN
          UPDATE public.ranked_matches
          SET phase = 'innings_break',
              first_innings_runs = v_new_innings_runs,
              target_runs = v_new_innings_runs + 1,
              current_innings_runs = v_new_innings_runs,
              legal_balls_bowled = v_new_legal_balls,
              turn_deadline_at = now() + INTERVAL '20 seconds',
              updated_at = now()
          WHERE id = p_match_id;

          RETURN jsonb_build_object(
            'status', 'first_innings_completed',
            'first_innings_runs', v_new_innings_runs,
            'target_runs', v_new_innings_runs + 1,
            'batter_number', v_batter_sub,
            'bowler_number', v_bowler_sub,
            'is_wicket', v_is_wicket
          );
        ELSE
          -- Continue First Innings
          UPDATE public.ranked_matches
          SET current_innings_runs = v_new_innings_runs,
              legal_balls_bowled = v_new_legal_balls,
              turn_deadline_at = now() + INTERVAL '20 seconds',
              updated_at = now()
          WHERE id = p_match_id;

          RETURN jsonb_build_object(
            'status', 'ball_resolved',
            'batter_number', v_batter_sub,
            'bowler_number', v_bowler_sub,
            'runs_scored', v_runs_scored,
            'is_wicket', v_is_wicket,
            'cumulative_runs', v_new_innings_runs,
            'legal_balls_bowled', v_new_legal_balls
          );
        END IF;

      -- Check Second Innings Completion
      ELSE
        -- Condition 1: Target reached by chasing batter -> Batter wins
        IF v_new_innings_runs >= v_match.target_runs THEN
          UPDATE public.ranked_matches
          SET phase = 'match_finished',
              winner_id = v_match.current_batter_id,
              result_type = 'win',
              current_innings_runs = v_new_innings_runs,
              legal_balls_bowled = v_new_legal_balls,
              turn_deadline_at = NULL,
              updated_at = now()
          WHERE id = p_match_id;

          -- Trigger transactional settlement
          PERFORM public.fn_settle_ranked_match(p_match_id);

          RETURN jsonb_build_object(
            'status', 'match_finished',
            'winner_id', v_match.current_batter_id,
            'result_type', 'win',
            'batter_number', v_batter_sub,
            'bowler_number', v_bowler_sub,
            'is_wicket', v_is_wicket,
            'final_runs', v_new_innings_runs
          );

        -- Condition 2: Wicket fallen OR 12 balls reached
        ELSIF v_is_wicket OR v_new_legal_balls >= 12 THEN
          IF v_new_innings_runs = (v_match.target_runs - 1) THEN
            -- Exact tie
            UPDATE public.ranked_matches
            SET phase = 'match_finished',
                winner_id = NULL,
                result_type = 'tie',
                current_innings_runs = v_new_innings_runs,
                legal_balls_bowled = v_new_legal_balls,
                turn_deadline_at = NULL,
                updated_at = now()
            WHERE id = p_match_id;

            PERFORM public.fn_settle_ranked_match(p_match_id);

            RETURN jsonb_build_object(
              'status', 'match_finished',
              'winner_id', NULL,
              'result_type', 'tie',
              'batter_number', v_batter_sub,
              'bowler_number', v_bowler_sub,
              'is_wicket', v_is_wicket,
              'final_runs', v_new_innings_runs
            );
          ELSE
            -- Defending bowler wins
            UPDATE public.ranked_matches
            SET phase = 'match_finished',
                winner_id = v_match.current_bowler_id,
                result_type = 'win',
                current_innings_runs = v_new_innings_runs,
                legal_balls_bowled = v_new_legal_balls,
                turn_deadline_at = NULL,
                updated_at = now()
            WHERE id = p_match_id;

            PERFORM public.fn_settle_ranked_match(p_match_id);

            RETURN jsonb_build_object(
              'status', 'match_finished',
              'winner_id', v_match.current_bowler_id,
              'result_type', 'win',
              'batter_number', v_batter_sub,
              'bowler_number', v_bowler_sub,
              'is_wicket', v_is_wicket,
              'final_runs', v_new_innings_runs
            );
          END IF;
        ELSE
          -- Continue Second Innings
          UPDATE public.ranked_matches
          SET current_innings_runs = v_new_innings_runs,
              legal_balls_bowled = v_new_legal_balls,
              turn_deadline_at = now() + INTERVAL '20 seconds',
              updated_at = now()
          WHERE id = p_match_id;

          RETURN jsonb_build_object(
            'status', 'ball_resolved',
            'batter_number', v_batter_sub,
            'bowler_number', v_bowler_sub,
            'runs_scored', v_runs_scored,
            'is_wicket', v_is_wicket,
            'cumulative_runs', v_new_innings_runs,
            'legal_balls_bowled', v_new_legal_balls,
            'target_runs', v_match.target_runs
          );
        END IF;
      END IF;
    ELSE
      -- Waiting for opponent choice
      UPDATE public.ranked_matches
      SET player1_heartbeat_at = v_match.player1_heartbeat_at,
          player2_heartbeat_at = v_match.player2_heartbeat_at,
          updated_at = now()
      WHERE id = p_match_id;

      RETURN jsonb_build_object('status', 'waiting_for_opponent');
    END IF;
  ELSE
    RAISE EXCEPTION 'Unknown turn type: %', p_turn_type;
  END IF;
END;
$$;

-- 3.2 Select Role RPC (Toss Winner Chooses Bat or Bowl)
CREATE OR REPLACE FUNCTION public.rpc_ranked_select_role(
  p_match_id UUID,
  p_role TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match public.ranked_matches%ROWTYPE;
  v_opponent_id UUID;
  v_batter_id UUID;
  v_bowler_id UUID;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_role != 'bat' AND p_role != 'bowl' THEN
    RAISE EXCEPTION 'Invalid role: must be bat or bowl';
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_match.phase != 'role_selection' THEN
    RAISE EXCEPTION 'Match is not in role_selection phase (current: %)', v_match.phase;
  END IF;

  IF v_caller_id != v_match.toss_winner_id THEN
    RAISE EXCEPTION 'Only the toss winner may select role';
  END IF;

  v_opponent_id := CASE WHEN v_caller_id = v_match.player1_id THEN v_match.player2_id ELSE v_match.player1_id END;

  IF p_role = 'bat' THEN
    v_batter_id := v_caller_id;
    v_bowler_id := v_opponent_id;
  ELSE
    v_batter_id := v_opponent_id;
    v_bowler_id := v_caller_id;
  END IF;

  UPDATE public.ranked_matches
  SET phase = 'first_innings',
      batting_first_id = v_batter_id,
      current_batter_id = v_batter_id,
      current_bowler_id = v_bowler_id,
      current_innings_no = 1,
      current_innings_runs = 0,
      legal_balls_bowled = 0,
      turn_deadline_at = now() + INTERVAL '20 seconds',
      updated_at = now()
  WHERE id = p_match_id;

  RETURN jsonb_build_object(
    'status', 'innings_started',
    'batter_id', v_batter_id,
    'bowler_id', v_bowler_id
  );
END;
$$;

-- 3.3 Start Second Innings RPC (Swaps Batter & Bowler)
CREATE OR REPLACE FUNCTION public.rpc_ranked_start_second_innings(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match public.ranked_matches%ROWTYPE;
  v_new_batter_id UUID;
  v_new_bowler_id UUID;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_caller_id != v_match.player1_id AND v_caller_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Caller is not a participant';
  END IF;

  IF v_match.phase != 'innings_break' THEN
    RAISE EXCEPTION 'Match is not in innings_break phase (current: %)', v_match.phase;
  END IF;

  -- Swap roles for 2nd innings
  v_new_batter_id := v_match.current_bowler_id;
  v_new_bowler_id := v_match.current_batter_id;

  UPDATE public.ranked_matches
  SET phase = 'second_innings',
      current_innings_no = 2,
      current_batter_id = v_new_batter_id,
      current_bowler_id = v_new_bowler_id,
      current_innings_runs = 0,
      legal_balls_bowled = 0,
      turn_deadline_at = now() + INTERVAL '20 seconds',
      updated_at = now()
  WHERE id = p_match_id;

  RETURN jsonb_build_object(
    'status', 'second_innings_started',
    'batter_id', v_new_batter_id,
    'bowler_id', v_new_bowler_id,
    'target_runs', v_match.target_runs
  );
END;
$$;

-- =====================================================================
-- 4. HEARTBEAT, DISCONNECT & TIMEOUT RPCS
-- =====================================================================

-- 4.1 Periodic Heartbeat
CREATE OR REPLACE FUNCTION public.rpc_ranked_heartbeat(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.ranked_matches
  SET player1_heartbeat_at = CASE WHEN player1_id = v_caller_id THEN now() ELSE player1_heartbeat_at END,
      player2_heartbeat_at = CASE WHEN player2_id = v_caller_id THEN now() ELSE player2_heartbeat_at END
  WHERE id = p_match_id AND (player1_id = v_caller_id OR player2_id = v_caller_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found or caller is not a participant';
  END IF;

  RETURN jsonb_build_object('status', 'ok', 'server_time', now());
END;
$$;

-- 4.2 Report Opponent Disconnect (Initiates 30s Grace Period)
CREATE OR REPLACE FUNCTION public.rpc_ranked_report_disconnect(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match public.ranked_matches%ROWTYPE;
  v_is_p1 BOOLEAN;
  v_opp_heartbeat TIMESTAMPTZ;
  v_opp_grace_rem INT;
  v_opp_disc_count INT;
  v_saved_seconds INT;
  v_grace_dur INT;
  v_ball_no INT;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_match.phase IN ('match_finished', 'match_forfeited') THEN
    RAISE EXCEPTION 'Match has already concluded';
  END IF;

  IF v_caller_id != v_match.player1_id AND v_caller_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Caller is not a participant';
  END IF;

  v_is_p1 := (v_caller_id = v_match.player1_id);
  v_opp_heartbeat := CASE WHEN v_is_p1 THEN v_match.player2_heartbeat_at ELSE v_match.player1_heartbeat_at END;
  v_opp_grace_rem := CASE WHEN v_is_p1 THEN v_match.p2_grace_remaining_seconds ELSE v_match.p1_grace_remaining_seconds END;
  v_opp_disc_count := CASE WHEN v_is_p1 THEN v_match.p2_disconnect_count ELSE v_match.p1_disconnect_count END;

  -- Guard 1: Caller heartbeat must be fresh (<= 10s)
  IF (v_is_p1 AND v_match.player1_heartbeat_at < now() - INTERVAL '10 seconds') OR
     (NOT v_is_p1 AND v_match.player2_heartbeat_at < now() - INTERVAL '10 seconds') THEN
    RAISE EXCEPTION 'Caller heartbeat is stale; cannot report opponent';
  END IF;

  -- Guard 2: Opponent heartbeat must be stale (> 15s)
  IF v_opp_heartbeat >= now() - INTERVAL '15 seconds' THEN
    RAISE EXCEPTION 'Opponent heartbeat is active; disconnect cannot be declared';
  END IF;

  -- Guard 3: Opponent must owe an active submission
  v_ball_no := v_match.legal_balls_bowled + 1;
  IF v_match.phase = 'toss_input' THEN
    IF EXISTS (SELECT 1 FROM public.ranked_pending_submissions WHERE match_id = p_match_id AND turn_type = 'toss' AND user_id = (CASE WHEN v_is_p1 THEN v_match.player2_id ELSE v_match.player1_id END)) THEN
      RAISE EXCEPTION 'Opponent has already submitted turn action; disconnection cannot be declared.';
    END IF;
  ELSIF v_match.phase = 'role_selection' THEN
    IF v_match.toss_winner_id != (CASE WHEN v_is_p1 THEN v_match.player2_id ELSE v_match.player1_id END) THEN
      RAISE EXCEPTION 'Opponent is not holding up role selection';
    END IF;
  ELSIF v_match.phase IN ('first_innings', 'second_innings') THEN
    IF EXISTS (SELECT 1 FROM public.ranked_pending_submissions WHERE match_id = p_match_id AND turn_type = 'ball' AND innings_no = v_match.current_innings_no AND ball_no = v_ball_no AND user_id = (CASE WHEN v_is_p1 THEN v_match.player2_id ELSE v_match.player1_id END)) THEN
      RAISE EXCEPTION 'Opponent has already submitted turn action; disconnection cannot be declared.';
    END IF;
  END IF;

  -- Check if opponent has exhausted disconnects or grace pool
  IF v_opp_grace_rem <= 0 OR v_opp_disc_count >= 2 THEN
    -- Instant forfeit win awarded to caller
    UPDATE public.ranked_matches
    SET phase = 'match_forfeited',
        winner_id = v_caller_id,
        result_type = 'forfeit',
        turn_deadline_at = NULL,
        updated_at = now()
    WHERE id = p_match_id;

    PERFORM public.fn_settle_ranked_match(p_match_id);

    RETURN jsonb_build_object('status', 'instant_forfeit_awarded', 'winner_id', v_caller_id);
  END IF;

  -- Calculate paused turn seconds
  IF v_match.turn_deadline_at IS NOT NULL THEN
    v_saved_seconds := GREATEST(5, EXTRACT(EPOCH FROM (v_match.turn_deadline_at - now()))::int);
  ELSE
    -- Double disconnect inheritance
    v_saved_seconds := COALESCE(CASE WHEN v_is_p1 THEN v_match.p1_saved_turn_seconds ELSE v_match.p2_saved_turn_seconds END, 20);
  END IF;

  v_grace_dur := LEAST(30, v_opp_grace_rem);

  IF v_is_p1 THEN
    UPDATE public.ranked_matches
    SET turn_deadline_at = NULL,
        p2_disconnected_at = now(),
        p2_grace_expires_at = now() + (v_grace_dur || ' seconds')::interval,
        p2_saved_turn_seconds = v_saved_seconds,
        p2_disconnect_count = p2_disconnect_count + 1,
        updated_at = now()
    WHERE id = p_match_id;
  ELSE
    UPDATE public.ranked_matches
    SET turn_deadline_at = NULL,
        p1_disconnected_at = now(),
        p1_grace_expires_at = now() + (v_grace_dur || ' seconds')::interval,
        p1_saved_turn_seconds = v_saved_seconds,
        p1_disconnect_count = p1_disconnect_count + 1,
        updated_at = now()
    WHERE id = p_match_id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'grace_period_started',
    'grace_duration_seconds', v_grace_dur,
    'expires_at', now() + (v_grace_dur || ' seconds')::interval
  );
END;
$$;

-- 4.3 Reconnect Within Grace Window
CREATE OR REPLACE FUNCTION public.rpc_ranked_reconnect(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match public.ranked_matches%ROWTYPE;
  v_is_p1 BOOLEAN;
  v_grace_expires_at TIMESTAMPTZ;
  v_disconnected_at TIMESTAMPTZ;
  v_saved_turn INT;
  v_elapsed INT;
  v_new_grace INT;
  v_other_in_grace BOOLEAN;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_match.phase IN ('match_finished', 'match_forfeited') THEN
    RAISE EXCEPTION 'Match has already ended';
  END IF;

  v_is_p1 := (v_caller_id = v_match.player1_id);
  v_grace_expires_at := CASE WHEN v_is_p1 THEN v_match.p1_grace_expires_at ELSE v_match.p2_grace_expires_at END;
  v_disconnected_at := CASE WHEN v_is_p1 THEN v_match.p1_disconnected_at ELSE v_match.p2_disconnected_at END;
  v_saved_turn := CASE WHEN v_is_p1 THEN v_match.p1_saved_turn_seconds ELSE v_match.p2_saved_turn_seconds END;

  IF v_grace_expires_at IS NULL THEN
    -- Player was not in grace
    RETURN jsonb_build_object('status', 'already_active');
  END IF;

  IF now() > v_grace_expires_at THEN
    RAISE EXCEPTION 'Grace period has expired';
  END IF;

  v_elapsed := GREATEST(0, EXTRACT(EPOCH FROM (now() - v_disconnected_at))::int);
  v_new_grace := GREATEST(0, (CASE WHEN v_is_p1 THEN v_match.p1_grace_remaining_seconds ELSE v_match.p2_grace_remaining_seconds END) - v_elapsed);
  v_other_in_grace := (CASE WHEN v_is_p1 THEN v_match.p2_grace_expires_at IS NOT NULL ELSE v_match.p1_grace_expires_at IS NOT NULL END);

  IF v_is_p1 THEN
    UPDATE public.ranked_matches
    SET p1_disconnected_at = NULL,
        p1_grace_expires_at = NULL,
        p1_grace_remaining_seconds = v_new_grace,
        turn_deadline_at = CASE WHEN NOT v_other_in_grace THEN now() + (v_saved_turn || ' seconds')::interval ELSE NULL END,
        player1_heartbeat_at = now(),
        updated_at = now()
    WHERE id = p_match_id;
  ELSE
    UPDATE public.ranked_matches
    SET p2_disconnected_at = NULL,
        p2_grace_expires_at = NULL,
        p2_grace_remaining_seconds = v_new_grace,
        turn_deadline_at = CASE WHEN NOT v_other_in_grace THEN now() + (v_saved_turn || ' seconds')::interval ELSE NULL END,
        player2_heartbeat_at = now(),
        updated_at = now()
    WHERE id = p_match_id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'reconnected',
    'remaining_grace', v_new_grace,
    'turn_resumed', NOT v_other_in_grace
  );
END;
$$;

-- 4.4 Claim Timeout / Forfeit Win (With Authoritative Delinquency Inspection)
CREATE OR REPLACE FUNCTION public.rpc_ranked_claim_timeout_forfeit(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match public.ranked_matches%ROWTYPE;
  v_opponent_id UUID;
  v_is_p1 BOOLEAN;
  v_ball_no INT;
  v_caller_sub INT;
  v_opp_sub INT;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_match.phase IN ('match_finished', 'match_forfeited') THEN
    RAISE EXCEPTION 'Match has already ended';
  END IF;

  IF v_caller_id != v_match.player1_id AND v_caller_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Caller is not a participant';
  END IF;

  v_is_p1 := (v_caller_id = v_match.player1_id);
  v_opponent_id := CASE WHEN v_is_p1 THEN v_match.player2_id ELSE v_match.player1_id END;

  -- Scenario A: Grace period expired
  IF (v_is_p1 AND v_match.p2_grace_expires_at IS NOT NULL AND now() > v_match.p2_grace_expires_at) OR
     (NOT v_is_p1 AND v_match.p1_grace_expires_at IS NOT NULL AND now() > v_match.p1_grace_expires_at) THEN
    -- Opponent grace expired: caller awarded forfeit win
    UPDATE public.ranked_matches
    SET phase = 'match_forfeited',
        winner_id = v_caller_id,
        result_type = 'forfeit',
        turn_deadline_at = NULL,
        updated_at = now()
    WHERE id = p_match_id;

    PERFORM public.fn_settle_ranked_match(p_match_id);
    RETURN jsonb_build_object('status', 'forfeit_awarded', 'winner_id', v_caller_id);

  -- Scenario B: Decision timer expired (Stall)
  ELSIF v_match.turn_deadline_at IS NOT NULL AND now() > v_match.turn_deadline_at THEN
    -- Delinquency verification
    IF v_match.phase = 'toss_input' THEN
      SELECT number_choice INTO v_caller_sub FROM public.ranked_pending_submissions WHERE match_id = p_match_id AND turn_type = 'toss' AND user_id = v_caller_id;
      SELECT number_choice INTO v_opp_sub FROM public.ranked_pending_submissions WHERE match_id = p_match_id AND turn_type = 'toss' AND user_id = v_opponent_id;
    ELSIF v_match.phase = 'role_selection' THEN
      IF v_match.toss_winner_id = v_caller_id THEN
        RAISE EXCEPTION 'Caller is delinquent (failed to select role in time)';
      ELSE
        -- Opponent failed to select role in time: caller wins
        UPDATE public.ranked_matches
        SET phase = 'match_forfeited',
            winner_id = v_caller_id,
            result_type = 'forfeit',
            turn_deadline_at = NULL,
            updated_at = now()
        WHERE id = p_match_id;

        PERFORM public.fn_settle_ranked_match(p_match_id);
        RETURN jsonb_build_object('status', 'forfeit_awarded', 'winner_id', v_caller_id);
      END IF;
    ELSIF v_match.phase IN ('first_innings', 'second_innings') THEN
      v_ball_no := v_match.legal_balls_bowled + 1;
      SELECT number_choice INTO v_caller_sub FROM public.ranked_pending_submissions WHERE match_id = p_match_id AND turn_type = 'ball' AND innings_no = v_match.current_innings_no AND ball_no = v_ball_no AND user_id = v_caller_id;
      SELECT number_choice INTO v_opp_sub FROM public.ranked_pending_submissions WHERE match_id = p_match_id AND turn_type = 'ball' AND innings_no = v_match.current_innings_no AND ball_no = v_ball_no AND user_id = v_opponent_id;
    END IF;

    -- Delinquency checks:
    IF v_caller_sub IS NOT NULL AND v_opp_sub IS NULL THEN
      -- Opponent is delinquent: caller wins
      UPDATE public.ranked_matches
      SET phase = 'match_forfeited',
          winner_id = v_caller_id,
          result_type = 'forfeit',
          turn_deadline_at = NULL,
          updated_at = now()
      WHERE id = p_match_id;

      PERFORM public.fn_settle_ranked_match(p_match_id);
      RETURN jsonb_build_object('status', 'forfeit_awarded', 'winner_id', v_caller_id);

    ELSIF v_caller_sub IS NULL AND v_opp_sub IS NOT NULL THEN
      RAISE EXCEPTION 'Caller is delinquent and cannot claim timeout forfeit';

    ELSE
      -- Neither submitted: mutual abandonment
      UPDATE public.ranked_matches
      SET phase = 'match_forfeited',
          winner_id = NULL,
          result_type = 'abandoned',
          turn_deadline_at = NULL,
          updated_at = now()
      WHERE id = p_match_id;

      PERFORM public.fn_settle_ranked_match(p_match_id);
      RETURN jsonb_build_object('status', 'match_abandoned');
    END IF;
  ELSE
    RAISE EXCEPTION 'Turn deadline or grace period has not expired yet';
  END IF;
END;
$$;

-- 4.5 Surrender / Concede Match
CREATE OR REPLACE FUNCTION public.rpc_ranked_surrender(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_match public.ranked_matches%ROWTYPE;
  v_winner_id UUID;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_match.phase IN ('match_finished', 'match_forfeited') THEN
    RAISE EXCEPTION 'Match has already ended';
  END IF;

  IF v_caller_id != v_match.player1_id AND v_caller_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Caller is not a participant';
  END IF;

  v_winner_id := CASE WHEN v_caller_id = v_match.player1_id THEN v_match.player2_id ELSE v_match.player1_id END;

  UPDATE public.ranked_matches
  SET phase = 'match_forfeited',
      winner_id = v_winner_id,
      result_type = 'forfeit',
      turn_deadline_at = NULL,
      updated_at = now()
  WHERE id = p_match_id;

  PERFORM public.fn_settle_ranked_match(p_match_id);

  RETURN jsonb_build_object('status', 'surrendered', 'winner_id', v_winner_id);
END;
$$;

-- 4.6 Get Public Leaderboard
CREATE OR REPLACE FUNCTION public.rpc_get_ranked_leaderboard(
  p_limit INT DEFAULT 100,
  p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(to_jsonb(r)), '[]'::jsonb) INTO v_result
  FROM (
    SELECT * FROM public.v_ranked_leaderboard
    LIMIT LEAST(100, GREATEST(1, p_limit))
    OFFSET GREATEST(0, p_offset)
  ) r;

  RETURN v_result;
END;
$$;

-- =====================================================================
-- 5. FUNCTION EXECUTION GRANTS
-- =====================================================================
-- Grant execute permissions solely on client interface RPCs
GRANT EXECUTE ON FUNCTION public.rpc_join_ranked_matchmaking() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_ranked_matchmaking() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_poll_ranked_matchmaking() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_submit_choice(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_select_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_start_second_innings(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_heartbeat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_report_disconnect(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_reconnect(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_claim_timeout_forfeit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_ranked_surrender(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_ranked_leaderboard(INT, INT) TO authenticated, anon;
