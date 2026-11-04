-- =====================================================================
-- Migration 00003: Authoritative RPC Stored Procedures
-- Odd or Even - Complete Server-Authoritative Logic & Lifecycle
-- =====================================================================

-- 1. Helper to generate random 6-character room codes
CREATE OR REPLACE FUNCTION public.fn_generate_room_code()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..6 LOOP
    code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN code;
END;
$$;

-- 2. Create Room RPC
CREATE OR REPLACE FUNCTION public.rpc_create_room(p_config JSONB DEFAULT '{}'::jsonb)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_room_code TEXT;
  v_room_id UUID;
  v_merged_config JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Ensure player profile exists
  INSERT INTO public.player_profiles (id, display_name)
  VALUES (v_user_id, 'Host ' || substr(v_user_id::text, 1, 4))
  ON CONFLICT (id) DO NOTHING;

  -- Default configuration fallbacks
  v_merged_config := jsonb_build_object(
    'gameMode', COALESCE(p_config->>'gameMode', 'standard'),
    'overs', (p_config->>'overs')::int,
    'decisionTimerSeconds', COALESCE((p_config->>'decisionTimerSeconds')::int, 10),
    'seriesTargetPoints', COALESCE((p_config->>'seriesTargetPoints')::int, 6)
  );

  v_room_code := public.fn_generate_room_code();

  INSERT INTO public.game_rooms (room_code, host_user_id, config, host_confirmed)
  VALUES (v_room_code, v_user_id, v_merged_config, true)
  RETURNING id INTO v_room_id;

  RETURN jsonb_build_object(
    'room_id', v_room_id,
    'room_code', v_room_code,
    'config', v_merged_config
  );
END;
$$;

-- 3. Join Room RPC
CREATE OR REPLACE FUNCTION public.rpc_join_room(p_code TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_room public.game_rooms%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.player_profiles (id, display_name)
  VALUES (v_user_id, 'Guest ' || substr(v_user_id::text, 1, 4))
  ON CONFLICT (id) DO NOTHING;

  SELECT * INTO v_room FROM public.game_rooms
  WHERE room_code = upper(trim(p_code)) AND status IN ('waiting', 'ready')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found or no longer available';
  END IF;

  IF v_room.host_user_id = v_user_id THEN
    RETURN jsonb_build_object('room_id', v_room.id, 'role', 'host', 'config', v_room.config);
  END IF;

  IF v_room.guest_user_id IS NOT NULL AND v_room.guest_user_id != v_user_id THEN
    RAISE EXCEPTION 'Room is already full';
  END IF;

  UPDATE public.game_rooms
  SET guest_user_id = v_user_id,
      status = 'ready',
      guest_confirmed = false
  WHERE id = v_room.id;

  RETURN jsonb_build_object(
    'room_id', v_room.id,
    'role', 'guest',
    'config', v_room.config
  );
END;
$$;

-- 4. Confirm Room Configuration & Launch Match
CREATE OR REPLACE FUNCTION public.rpc_confirm_room_config(p_room_id UUID, p_config JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_room public.game_rooms%ROWTYPE;
  v_match_id UUID;
  v_p1_parity player_parity;
  v_p2_parity player_parity;
  v_timer_sec INT;
BEGIN
  SELECT * INTO v_room FROM public.game_rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Room not found'; END IF;

  IF v_user_id = v_room.host_user_id THEN
    UPDATE public.game_rooms
    SET host_confirmed = true, config = p_config
    WHERE id = p_room_id;
  ELSIF v_user_id = v_room.guest_user_id THEN
    UPDATE public.game_rooms
    SET guest_confirmed = true, config = p_config
    WHERE id = p_room_id;
  ELSE
    RAISE EXCEPTION 'Not a participant in this room';
  END IF;

  -- Re-read room state
  SELECT * INTO v_room FROM public.game_rooms WHERE id = p_room_id;

  -- If both players confirmed, initialize official Match!
  IF v_room.host_confirmed AND v_room.guest_confirmed AND v_room.guest_user_id IS NOT NULL THEN
    IF random() < 0.5 THEN
      v_p1_parity := 'odd';
      v_p2_parity := 'even';
    ELSE
      v_p1_parity := 'even';
      v_p2_parity := 'odd';
    END IF;

    v_timer_sec := COALESCE((v_room.config->>'decisionTimerSeconds')::int, 10);

    INSERT INTO public.matches (
      room_id,
      phase,
      config,
      player1_id,
      player2_id,
      player1_parity,
      player2_parity,
      turn_deadline_at
    ) VALUES (
      v_room.id,
      'toss_input',
      v_room.config,
      v_room.host_user_id,
      v_room.guest_user_id,
      v_p1_parity,
      v_p2_parity,
      now() + (v_timer_sec || ' seconds')::interval
    )
    RETURNING id INTO v_match_id;

    UPDATE public.game_rooms
    SET status = 'playing', active_match_id = v_match_id
    WHERE id = v_room.id;

    RETURN jsonb_build_object('status', 'started', 'match_id', v_match_id);
  END IF;

  RETURN jsonb_build_object('status', 'waiting_for_opponent');
END;
$$;

-- 5. Submit Choice (Toss or Ball) & Trigger Atomic Resolution
CREATE OR REPLACE FUNCTION public.rpc_submit_choice(
  p_match_id UUID,
  p_turn_type TEXT,
  p_choice INT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_match public.matches%ROWTYPE;
  v_sub_count INT;
  v_p1_sub INT;
  v_p2_sub INT;
  v_sum INT;
  v_toss_winner UUID;
  v_timer_sec INT;
  v_batter_sub INT;
  v_bowler_sub INT;
  v_is_wicket BOOLEAN;
  v_runs_scored INT;
  v_new_total INT;
  v_target INT;
  v_winner UUID;
  v_loser UUID;
  v_p1_series INT;
  v_p2_series INT;
  v_series_target INT;
  v_series_winner UUID := NULL;
  v_match_phase match_phase;
BEGIN
  IF p_choice < 1 OR p_choice > 10 THEN
    RAISE EXCEPTION 'Number choice must be between 1 and 10';
  END IF;

  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_user_id != v_match.player1_id AND v_user_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_timer_sec := COALESCE((v_match.config->>'decisionTimerSeconds')::int, 10);

  -- Insert submission into private table
  INSERT INTO public.pending_submissions (
    match_id, turn_type, innings_no, ball_no, user_id, number_choice
  ) VALUES (
    p_match_id,
    p_turn_type,
    v_match.current_innings_no,
    v_match.legal_balls_bowled + 1,
    v_user_id,
    p_choice
  )
  ON CONFLICT (match_id, turn_type, innings_no, ball_no, user_id)
  DO UPDATE SET number_choice = EXCLUDED.number_choice;

  -- Count submissions for this turn
  SELECT count(*) INTO v_sub_count
  FROM public.pending_submissions
  WHERE match_id = p_match_id
    AND turn_type = p_turn_type
    AND innings_no IS NOT DISTINCT FROM v_match.current_innings_no
    AND ball_no IS NOT DISTINCT FROM (v_match.legal_balls_bowled + 1);

  -- If only 1 player has submitted, wait for opponent
  IF v_sub_count < 2 THEN
    RETURN jsonb_build_object('status', 'waiting_for_opponent');
  END IF;

  -- ATOMIC RESOLUTION: Both submissions are available!
  IF p_turn_type = 'toss' THEN
    SELECT number_choice INTO v_p1_sub
    FROM public.pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'toss' AND user_id = v_match.player1_id;

    SELECT number_choice INTO v_p2_sub
    FROM public.pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'toss' AND user_id = v_match.player2_id;

    v_sum := v_p1_sub + v_p2_sub;
    IF (v_sum % 2 = 1) THEN
      v_toss_winner := CASE WHEN v_match.player1_parity = 'odd' THEN v_match.player1_id ELSE v_match.player2_id END;
    ELSE
      v_toss_winner := CASE WHEN v_match.player1_parity = 'even' THEN v_match.player1_id ELSE v_match.player2_id END;
    END IF;

    UPDATE public.matches
    SET phase = 'role_selection',
        toss_winner_id = v_toss_winner,
        version = version + 1,
        turn_deadline_at = now() + (v_timer_sec || ' seconds')::interval,
        updated_at = now()
    WHERE id = p_match_id;

    RETURN jsonb_build_object(
      'status', 'resolved',
      'phase', 'role_selection',
      'player1_choice', v_p1_sub,
      'player2_choice', v_p2_sub,
      'sum', v_sum,
      'toss_winner_id', v_toss_winner
    );

  ELSIF p_turn_type = 'ball' THEN
    SELECT number_choice INTO v_batter_sub
    FROM public.pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'ball'
      AND innings_no = v_match.current_innings_no
      AND ball_no = (v_match.legal_balls_bowled + 1)
      AND user_id = v_match.current_batter_id;

    SELECT number_choice INTO v_bowler_sub
    FROM public.pending_submissions
    WHERE match_id = p_match_id AND turn_type = 'ball'
      AND innings_no = v_match.current_innings_no
      AND ball_no = (v_match.legal_balls_bowled + 1)
      AND user_id = v_match.current_bowler_id;

    IF v_batter_sub = v_bowler_sub THEN
      v_is_wicket := true;
      v_runs_scored := 0;
    ELSE
      v_is_wicket := false;
      v_runs_scored := v_batter_sub;
    END IF;

    v_new_total := v_match.current_innings_runs + v_runs_scored;

    -- Store resolved ball event in public history
    INSERT INTO public.ball_events (
      match_id, innings_no, ball_no, batter_id, bowler_id,
      batter_number, bowler_number, runs_scored, is_wicket, cumulative_runs
    ) VALUES (
      p_match_id, v_match.current_innings_no, v_match.legal_balls_bowled + 1,
      v_match.current_batter_id, v_match.current_bowler_id,
      v_batter_sub, v_bowler_sub, v_runs_scored, v_is_wicket, v_new_total
    );

    -- Innings 1 evaluation
    IF v_match.current_innings_no = 1 THEN
      IF v_is_wicket OR (v_match.config->>'overs' IS NOT NULL AND (v_match.legal_balls_bowled + 1) >= (v_match.config->>'overs')::int * 6) THEN
        v_target := v_new_total + 1;
        UPDATE public.matches
        SET phase = 'innings_break',
            first_innings_runs = v_new_total,
            target_runs = v_target,
            current_innings_no = 2,
            current_batter_id = v_match.current_bowler_id,
            current_bowler_id = v_match.current_batter_id,
            current_innings_runs = 0,
            legal_balls_bowled = 0,
            version = version + 1,
            turn_deadline_at = now() + (v_timer_sec || ' seconds')::interval,
            updated_at = now()
        WHERE id = p_match_id;

        RETURN jsonb_build_object(
          'status', 'innings_break',
          'batter_number', v_batter_sub,
          'bowler_number', v_bowler_sub,
          'runs_scored', v_runs_scored,
          'is_wicket', v_is_wicket,
          'first_innings_runs', v_new_total,
          'target', v_target
        );
      ELSE
        UPDATE public.matches
        SET current_innings_runs = v_new_total,
            legal_balls_bowled = legal_balls_bowled + 1,
            version = version + 1,
            turn_deadline_at = now() + (v_timer_sec || ' seconds')::interval,
            updated_at = now()
        WHERE id = p_match_id;

        RETURN jsonb_build_object(
          'status', 'ball_resolved',
          'batter_number', v_batter_sub,
          'bowler_number', v_bowler_sub,
          'runs_scored', v_runs_scored,
          'is_wicket', false,
          'current_score', v_new_total
        );
      END IF;

    -- Innings 2 evaluation (Chase)
    ELSE
      v_p1_series := v_match.player1_series_score;
      v_p2_series := v_match.player2_series_score;
      v_series_target := COALESCE((v_match.config->>'seriesTargetPoints')::int, 6);

      -- Check if target reached
      IF v_new_total >= v_match.target_runs THEN
        v_winner := v_match.current_batter_id;
        v_loser := v_match.current_bowler_id;

        IF v_winner = v_match.player1_id THEN
          v_p1_series := v_p1_series + 1;
          IF v_p1_series >= v_series_target THEN v_series_winner := v_winner; END IF;
        ELSE
          v_p2_series := v_p2_series + 1;
          IF v_p2_series >= v_series_target THEN v_series_winner := v_winner; END IF;
        END IF;

        v_match_phase := CASE WHEN v_series_winner IS NOT NULL THEN 'series_finished'::match_phase ELSE 'match_finished'::match_phase END;

        UPDATE public.matches
        SET phase = v_match_phase,
            current_innings_runs = v_new_total,
            legal_balls_bowled = legal_balls_bowled + 1,
            winner_id = v_winner,
            result_type = 'win',
            player1_series_score = v_p1_series,
            player2_series_score = v_p2_series,
            series_winner_id = v_series_winner,
            version = version + 1,
            updated_at = now()
        WHERE id = p_match_id;

        -- Update player profiles
        UPDATE public.player_profiles SET matches_played = matches_played + 1, matches_won = matches_won + 1, updated_at = now() WHERE id = v_winner;
        UPDATE public.player_profiles SET matches_played = matches_played + 1, matches_lost = matches_lost + 1, updated_at = now() WHERE id = v_loser;

        RETURN jsonb_build_object(
          'status', 'match_finished',
          'batter_number', v_batter_sub,
          'bowler_number', v_bowler_sub,
          'runs_scored', v_runs_scored,
          'is_wicket', false,
          'winner_id', v_winner,
          'result', 'chaser_won',
          'series_winner_id', v_series_winner
        );

      ELSIF v_is_wicket OR (v_match.config->>'overs' IS NOT NULL AND (v_match.legal_balls_bowled + 1) >= (v_match.config->>'overs')::int * 6) THEN
        IF v_new_total = v_match.first_innings_runs THEN
          -- Tie
          UPDATE public.matches
          SET phase = 'match_finished',
              current_innings_runs = v_new_total,
              legal_balls_bowled = legal_balls_bowled + 1,
              winner_id = NULL,
              result_type = 'tie',
              version = version + 1,
              updated_at = now()
          WHERE id = p_match_id;

          UPDATE public.player_profiles SET matches_played = matches_played + 1, matches_tied = matches_tied + 1, updated_at = now() WHERE id IN (v_match.player1_id, v_match.player2_id);

          RETURN jsonb_build_object(
            'status', 'match_finished',
            'batter_number', v_batter_sub,
            'bowler_number', v_bowler_sub,
            'runs_scored', v_runs_scored,
            'is_wicket', v_is_wicket,
            'winner_id', NULL,
            'result', 'tie'
          );
        ELSE
          -- Defender wins
          v_winner := v_match.current_bowler_id;
          v_loser := v_match.current_batter_id;

          IF v_winner = v_match.player1_id THEN
            v_p1_series := v_p1_series + 1;
            IF v_p1_series >= v_series_target THEN v_series_winner := v_winner; END IF;
          ELSE
            v_p2_series := v_p2_series + 1;
            IF v_p2_series >= v_series_target THEN v_series_winner := v_winner; END IF;
          END IF;

          v_match_phase := CASE WHEN v_series_winner IS NOT NULL THEN 'series_finished'::match_phase ELSE 'match_finished'::match_phase END;

          UPDATE public.matches
          SET phase = v_match_phase,
              current_innings_runs = v_new_total,
              legal_balls_bowled = legal_balls_bowled + 1,
              winner_id = v_winner,
              result_type = 'win',
              player1_series_score = v_p1_series,
              player2_series_score = v_p2_series,
              series_winner_id = v_series_winner,
              version = version + 1,
              updated_at = now()
          WHERE id = p_match_id;

          UPDATE public.player_profiles SET matches_played = matches_played + 1, matches_won = matches_won + 1, updated_at = now() WHERE id = v_winner;
          UPDATE public.player_profiles SET matches_played = matches_played + 1, matches_lost = matches_lost + 1, updated_at = now() WHERE id = v_loser;

          RETURN jsonb_build_object(
            'status', 'match_finished',
            'batter_number', v_batter_sub,
            'bowler_number', v_bowler_sub,
            'runs_scored', v_runs_scored,
            'is_wicket', v_is_wicket,
            'winner_id', v_winner,
            'result', 'defender_won',
            'series_winner_id', v_series_winner
          );
        END IF;
      ELSE
        -- Normal ball in chase
        UPDATE public.matches
        SET current_innings_runs = v_new_total,
            legal_balls_bowled = legal_balls_bowled + 1,
            version = version + 1,
            turn_deadline_at = now() + (v_timer_sec || ' seconds')::interval,
            updated_at = now()
        WHERE id = p_match_id;

        RETURN jsonb_build_object(
          'status', 'ball_resolved',
          'batter_number', v_batter_sub,
          'bowler_number', v_bowler_sub,
          'runs_scored', v_runs_scored,
          'is_wicket', false,
          'current_score', v_new_total
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object('status', 'unknown');
END;
$$;

-- 6. Select Bat or Bowl (Role Selection by Toss Winner)
CREATE OR REPLACE FUNCTION public.rpc_select_role(p_match_id UUID, p_role TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_match public.matches%ROWTYPE;
  v_timer_sec INT;
  v_batter UUID;
  v_bowler UUID;
BEGIN
  IF p_role != 'bat' AND p_role != 'bowl' THEN
    RAISE EXCEPTION 'Role must be either bat or bowl';
  END IF;

  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_user_id != v_match.toss_winner_id THEN
    RAISE EXCEPTION 'Only toss winner can select Bat or Bowl';
  END IF;

  v_timer_sec := COALESCE((v_match.config->>'decisionTimerSeconds')::int, 10);

  IF p_role = 'bat' THEN
    v_batter := v_user_id;
    v_bowler := CASE WHEN v_user_id = v_match.player1_id THEN v_match.player2_id ELSE v_match.player1_id END;
  ELSE
    v_bowler := v_user_id;
    v_batter := CASE WHEN v_user_id = v_match.player1_id THEN v_match.player2_id ELSE v_match.player1_id END;
  END IF;

  UPDATE public.matches
  SET phase = 'first_innings',
      batting_first_id = v_batter,
      current_batter_id = v_batter,
      current_bowler_id = v_bowler,
      current_innings_no = 1,
      current_innings_runs = 0,
      legal_balls_bowled = 0,
      version = version + 1,
      turn_deadline_at = now() + (v_timer_sec || ' seconds')::interval,
      updated_at = now()
  WHERE id = p_match_id;

  RETURN jsonb_build_object(
    'status', 'innings_started',
    'batter_id', v_batter,
    'bowler_id', v_bowler
  );
END;
$$;

-- 7. Start Second Innings RPC
CREATE OR REPLACE FUNCTION public.rpc_start_second_innings(p_match_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_match public.matches%ROWTYPE;
  v_timer_sec INT;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_user_id != v_match.player1_id AND v_user_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_match.phase != 'innings_break' THEN
    RAISE EXCEPTION 'Match is not in innings_break phase';
  END IF;

  v_timer_sec := COALESCE((v_match.config->>'decisionTimerSeconds')::int, 10);

  UPDATE public.matches
  SET phase = 'second_innings',
      turn_deadline_at = now() + (v_timer_sec || ' seconds')::interval,
      version = version + 1,
      updated_at = now()
  WHERE id = p_match_id;

  RETURN jsonb_build_object('status', 'second_innings_started');
END;
$$;

-- 8. Rematch RPC
CREATE OR REPLACE FUNCTION public.rpc_request_rematch(p_match_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_old_match public.matches%ROWTYPE;
  v_new_match_id UUID;
  v_p1_parity player_parity;
  v_p2_parity player_parity;
  v_timer_sec INT;
BEGIN
  SELECT * INTO v_old_match FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_user_id != v_old_match.player1_id AND v_user_id != v_old_match.player2_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_old_match.phase != 'match_finished' AND v_old_match.phase != 'series_finished' AND v_old_match.phase != 'match_forfeited' THEN
    RAISE EXCEPTION 'Cannot rematch while match is active';
  END IF;

  -- Re-roll parity randomly
  IF random() < 0.5 THEN
    v_p1_parity := 'odd';
    v_p2_parity := 'even';
  ELSE
    v_p1_parity := 'even';
    v_p2_parity := 'odd';
  END IF;

  v_timer_sec := COALESCE((v_old_match.config->>'decisionTimerSeconds')::int, 10);

  -- Create fresh match preserving series scores
  INSERT INTO public.matches (
    room_id,
    phase,
    config,
    player1_id,
    player2_id,
    player1_parity,
    player2_parity,
    player1_series_score,
    player2_series_score,
    turn_deadline_at
  ) VALUES (
    v_old_match.room_id,
    'toss_input',
    v_old_match.config,
    v_old_match.player1_id,
    v_old_match.player2_id,
    v_p1_parity,
    v_p2_parity,
    v_old_match.player1_series_score,
    v_old_match.player2_series_score,
    now() + (v_timer_sec || ' seconds')::interval
  ) RETURNING id INTO v_new_match_id;

  IF v_old_match.room_id IS NOT NULL THEN
    UPDATE public.game_rooms
    SET active_match_id = v_new_match_id, status = 'playing'
    WHERE id = v_old_match.room_id;
  END IF;

  RETURN jsonb_build_object('status', 'rematch_created', 'match_id', v_new_match_id);
END;
$$;

-- 9. Claim Timeout RPC
CREATE OR REPLACE FUNCTION public.rpc_claim_timeout(p_match_id UUID, p_timed_out_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_match public.matches%ROWTYPE;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_user_id != v_match.player1_id AND v_user_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_match.turn_deadline_at IS NOT NULL AND now() < v_match.turn_deadline_at THEN
    RAISE EXCEPTION 'Turn deadline has not yet expired';
  END IF;

  IF p_timed_out_user_id = v_match.player1_id THEN
    UPDATE public.matches
    SET player2_timeout_points = player2_timeout_points + 1,
        version = version + 1,
        updated_at = now()
    WHERE id = p_match_id;
  ELSIF p_timed_out_user_id = v_match.player2_id THEN
    UPDATE public.matches
    SET player1_timeout_points = player1_timeout_points + 1,
        version = version + 1,
        updated_at = now()
    WHERE id = p_match_id;
  END IF;

  RETURN jsonb_build_object('status', 'timeout_awarded');
END;
$$;

-- 10. Forfeit Match RPC
CREATE OR REPLACE FUNCTION public.rpc_forfeit_match(p_match_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_match public.matches%ROWTYPE;
  v_winner UUID;
  v_p1_series INT;
  v_p2_series INT;
  v_series_target INT;
  v_series_winner UUID := NULL;
  v_match_phase match_phase;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;

  IF v_user_id != v_match.player1_id AND v_user_id != v_match.player2_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_match.phase = 'match_finished' OR v_match.phase = 'series_finished' OR v_match.phase = 'match_forfeited' THEN
    RETURN jsonb_build_object('status', 'already_completed');
  END IF;

  v_winner := CASE WHEN v_user_id = v_match.player1_id THEN v_match.player2_id ELSE v_match.player1_id END;

  v_p1_series := v_match.player1_series_score;
  v_p2_series := v_match.player2_series_score;
  v_series_target := COALESCE((v_match.config->>'seriesTargetPoints')::int, 6);

  IF v_winner = v_match.player1_id THEN
    v_p1_series := v_p1_series + 1;
    IF v_p1_series >= v_series_target THEN v_series_winner := v_winner; END IF;
  ELSE
    v_p2_series := v_p2_series + 1;
    IF v_p2_series >= v_series_target THEN v_series_winner := v_winner; END IF;
  END IF;

  v_match_phase := CASE WHEN v_series_winner IS NOT NULL THEN 'series_finished'::match_phase ELSE 'match_forfeited'::match_phase END;

  UPDATE public.matches
  SET phase = v_match_phase,
      winner_id = v_winner,
      result_type = 'forfeit',
      player1_series_score = v_p1_series,
      player2_series_score = v_p2_series,
      series_winner_id = v_series_winner,
      version = version + 1,
      updated_at = now()
  WHERE id = p_match_id;

  UPDATE public.player_profiles SET matches_played = matches_played + 1, matches_won = matches_won + 1, updated_at = now() WHERE id = v_winner;
  UPDATE public.player_profiles SET matches_played = matches_played + 1, matches_lost = matches_lost + 1, updated_at = now() WHERE id = v_user_id;

  RETURN jsonb_build_object('status', 'match_forfeited', 'winner_id', v_winner);
END;
$$;

-- 11. Matchmaking Join RPC
CREATE OR REPLACE FUNCTION public.rpc_join_matchmaking(p_config JSONB DEFAULT '{}'::jsonb)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_opponent_id UUID;
  v_room_id UUID;
  v_match_id UUID;
  v_code TEXT;
  v_p1_parity player_parity;
  v_p2_parity player_parity;
  v_timer_sec INT;
  v_merged_config JSONB;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  INSERT INTO public.player_profiles (id, display_name)
  VALUES (v_user_id, 'Player ' || substr(v_user_id::text, 1, 4))
  ON CONFLICT (id) DO NOTHING;

  DELETE FROM public.matchmaking_queue WHERE joined_at < (now() - INTERVAL '5 minutes');

  SELECT user_id INTO v_opponent_id
  FROM public.matchmaking_queue
  WHERE user_id != v_user_id
  ORDER BY joined_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_opponent_id IS NOT NULL THEN
    DELETE FROM public.matchmaking_queue WHERE user_id IN (v_user_id, v_opponent_id);

    v_merged_config := jsonb_build_object(
      'gameMode', COALESCE(p_config->>'gameMode', 'standard'),
      'overs', (p_config->>'overs')::int,
      'decisionTimerSeconds', COALESCE((p_config->>'decisionTimerSeconds')::int, 10),
      'seriesTargetPoints', COALESCE((p_config->>'seriesTargetPoints')::int, 6)
    );

    v_code := public.fn_generate_room_code();

    INSERT INTO public.game_rooms (
      room_code, host_user_id, guest_user_id, status, config, host_confirmed, guest_confirmed
    ) VALUES (
      v_code, v_opponent_id, v_user_id, 'playing', v_merged_config, true, true
    ) RETURNING id INTO v_room_id;

    IF random() < 0.5 THEN
      v_p1_parity := 'odd'; v_p2_parity := 'even';
    ELSE
      v_p1_parity := 'even'; v_p2_parity := 'odd';
    END IF;

    v_timer_sec := COALESCE((v_merged_config->>'decisionTimerSeconds')::int, 10);

    INSERT INTO public.matches (
      room_id, phase, config, player1_id, player2_id, player1_parity, player2_parity, turn_deadline_at
    ) VALUES (
      v_room_id, 'toss_input', v_merged_config, v_opponent_id, v_user_id, v_p1_parity, v_p2_parity,
      now() + (v_timer_sec || ' seconds')::interval
    ) RETURNING id INTO v_match_id;

    UPDATE public.game_rooms SET active_match_id = v_match_id WHERE id = v_room_id;

    RETURN jsonb_build_object(
      'status', 'matched',
      'match_id', v_match_id,
      'room_id', v_room_id,
      'room_code', v_code
    );
  ELSE
    INSERT INTO public.matchmaking_queue (user_id, config, joined_at)
    VALUES (v_user_id, p_config, now())
    ON CONFLICT (user_id) DO UPDATE SET config = EXCLUDED.config, joined_at = now();

    RETURN jsonb_build_object('status', 'queued');
  END IF;
END;
$$;

-- 12. Matchmaking Poll RPC
CREATE OR REPLACE FUNCTION public.rpc_poll_matchmaking()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_match public.matches%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE (player1_id = v_user_id OR player2_id = v_user_id)
    AND created_at > (now() - INTERVAL '2 minutes')
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'matched',
      'match_id', v_match.id,
      'room_id', v_match.room_id
    );
  END IF;

  IF EXISTS (SELECT 1 FROM public.matchmaking_queue WHERE user_id = v_user_id) THEN
    RETURN jsonb_build_object('status', 'queued');
  END IF;

  RETURN jsonb_build_object('status', 'not_queued');
END;
$$;

-- 13. Matchmaking Cancel RPC
CREATE OR REPLACE FUNCTION public.rpc_cancel_matchmaking()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NOT NULL THEN
    DELETE FROM public.matchmaking_queue WHERE user_id = v_user_id;
  END IF;
  RETURN jsonb_build_object('status', 'cancelled');
END;
$$;
