# Odd or Even - Known Issues & Risk Register

## 1. Resolved Remediation Items (Post-Audit 2026-11-04)
- **Resolved (CRITICAL-01):** Missing `search_path` on SECURITY DEFINER functions.
  - *Resolution:* Patched all 13 stored procedures in `00004_security_and_reliability_fixes.sql` with explicit `SET search_path = public, pg_temp;`.
- **Resolved (CRITICAL-02):** `rpc_claim_timeout` spam vulnerability.
  - *Resolution:* Added `turn_timeout_claimed BOOLEAN NOT NULL DEFAULT false` to `matches` and transactional single-claim guard.
- **Resolved (HIGH-01):** Unilateral room config overwrite in `rpc_confirm_room_config`.
  - *Resolution:* Enforced mutual agreement; changing settings automatically resets the opponent's confirmation.
- **Resolved (HIGH-02):** Missing phase checks in `rpc_submit_choice`.
  - *Resolution:* Added strict validation for `toss_input` on toss submissions and `first_innings`/`second_innings` on ball submissions.
- **Resolved (HIGH-03):** Stale match collision in `rpc_poll_matchmaking`.
  - *Resolution:* Added active match filter `phase NOT IN ('match_finished', 'series_finished', 'match_forfeited')`.
- **Resolved (HIGH-04):** Polling-only online multiplayer.
  - *Resolution:* Implemented Supabase Realtime channel subscriptions (`client.channel()`) on `matches` and `ball_events` with polling retained strictly as a fallback.
- **Resolved (LOW-01):** 50 Flutter `.withOpacity()` deprecation warnings.
  - *Resolution:* Migrated 100% of usages to `.withValues(alpha: ...)`. Zero analyzer warnings.

## 2. Active Risks & Deployment Prerequisites
- **Issue:** Live cloud multi-device end-to-end testing against active remote Supabase project.
  - **Prerequisite:** Deploy migrations using `supabase db push` with production credentials, and configure `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`.
- **Issue:** Desktop/Web system audio limitations.
  - **Mitigation:** Wrap audio calls in safe abstractions with graceful fallbacks.

## 3. Unresolved / Future Scope
- Competitive ELO ranking system (deferred to post-V1 release).
- Push notifications for room invitations (V2 scope).
- Custom multi-track sound engineering (sound effects bundle).
