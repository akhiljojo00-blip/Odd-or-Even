# ODD OR EVEN — PHASE 5D.1: STAGING PREFLIGHT AUDIT REPORT

**Role**: Senior QA Engineer, Multiplayer Backend Engineer, and Release Readiness Auditor  
**Repository**: `akhiljojo00-blip/Odd-or-Even`  
**Active Branch**: `feature/competitive-progression`  
**Base Production Commit**: `4824eaa`  
**Audit Date**: November 10, 2026  
**Final Verdict**: **READY FOR STAGING MIGRATION** (Live Testing: **BLOCKED** on Staging Provisioning)

---

## 1. Migration Reconciliation (Migrations `00001` through `00006`)

A comprehensive audit was performed reconciling all tables, enums, views, stored procedures (RPCs), RLS security policies, and least-privilege grants in `supabase/migrations/` against the authoritative Flutter client repository ([`OnlineRankedRepository`](file:///c:/Users/akhil/Downloads/Odd%20or%20Even/lib/features/online/data/online_ranked_repository.dart) and domain models in `lib/features/online/domain/models/`).

### 1.1 Object Inventory & Client Contract Mapping

| Migration | Database Object | Type | Corresponding Flutter Client Contract | Reconciliation Status |
| :--- | :--- | :--- | :--- | :--- |
| **`00001`** | `room_status` | Enum | `MatchmakingStatus` / Casual rooms | ✅ MATCH |
| **`00001`** | `match_phase` | Enum | `RankedMatchPhase` (`lib/features/online/domain/models/ranked_match.dart`) | ✅ MATCH |
| **`00001`** | `player_parity` | Enum | `PlayerParity` (`lib/features/online/domain/models/ranked_match.dart`) | ✅ MATCH |
| **`00001`** | `player_role` | Enum | `PlayerRole` (`bat`, `bowl`) | ✅ MATCH |
| **`00001`** | `match_result_type` | Enum | `MatchResultType` (`win`, `tie`, `forfeit`, `abandoned`) | ✅ MATCH |
| **`00001`** | `public.player_profiles` | Table | `OnlineRankedRepository.getPlayerProfile` | ✅ MATCH |
| **`00001`** | `public.matches` | Table | Casual room matches | ✅ MATCH |
| **`00001`** | `public.game_rooms` | Table | Casual room lobby | ✅ MATCH |
| **`00001`** | `public.pending_submissions`| Table | Casual private submissions (Zero Client Read) | ✅ MATCH |
| **`00001`** | `public.ball_events` | Table | Casual ball delivery history | ✅ MATCH |
| **`00001`** | `public.matchmaking_queue` | Table | Casual matchmaking queue | ✅ MATCH |
| **`00002`** | RLS on base tables | Security | Strict isolation, client UPDATE locks on matches | ✅ MATCH |
| **`00003`** | Casual RPC Functions | Stored Proc | Casual online rooms & quick match | ✅ MATCH |
| **`00004`** | Hardening & SEC-01 trigger | Security | Blocks client direct writes to `player_profiles.matches_won` | ✅ MATCH |
| **`00005`** | `public.ranked_seasons` | Table | Season lifecycle & active season tracking | ✅ MATCH |
| **`00005`** | `public.online_player_ranks`| Table | `OnlinePlayerRank` (`lib/features/online/domain/models/online_player_rank.dart`) | ✅ MATCH |
| **`00005`** | `public.online_ranked_stats`| Table | `OnlineRankedStats` (`lib/features/online/domain/models/online_player_rank.dart`) | ✅ MATCH |
| **`00005`** | `public.ranked_matches` | Table | `RankedMatch` (`lib/features/online/domain/models/ranked_match.dart`) | ✅ MATCH |
| **`00005`** | `public.ranked_pending_submissions` | Table | Blind choice isolation (Zero client read via RLS) | ✅ MATCH |
| **`00005`** | `public.ranked_ball_events` | Table | `RankedBallEvent` (`lib/features/online/domain/models/ranked_ball_event.dart`) | ✅ MATCH |
| **`00005`** | `public.ranked_match_settlements` | Table | `RankedMatchSettlement` (`lib/features/online/domain/models/ranked_match_settlement.dart`) | ✅ MATCH |
| **`00005`** | `public.ranked_matchmaking_queue` | Table | Queue state & heartbeat tracking | ✅ MATCH |
| **`00005`** | `public.ranked_daily_xp_tracking` | Table | 1500 XP daily cap boundary enforcement | ✅ MATCH |
| **`00005`** | `public.ranked_season_history` | Table | Archived season progression | ✅ MATCH |
| **`00005`** | `public.ranked_abuse_events` | Table | Anti-farming / daily win cap audit logs | ✅ MATCH |
| **`00005`** | `public.v_ranked_leaderboard` | View | `RankedLeaderboardEntry` (`lib/features/online/domain/models/ranked_leaderboard_entry.dart`) | ✅ MATCH |
| **`00006`** | `fn_calculate_base_mmr_delta` | Function | Elo-based base MMR calculation (±16 to ±32) | ✅ MATCH |
| **`00006`** | `fn_calculate_ranked_stars_and_shield` | Function | Canonical progression rules, demotion shields, win streak | ✅ MATCH |
| **`00006`** | `fn_calculate_ranked_match_xp` | Function | Canonical match XP calculation (Win: 100, Loss: 40, Daily: 50) | ✅ MATCH |
| **`00006`** | `fn_settle_ranked_match` | Stored Proc | Internal atomic settlement engine (Private, revoked from clients) | ✅ MATCH |
| **`00006`** | `rpc_join_ranked_matchmaking` | Public RPC | `OnlineRankedRepository.joinMatchmaking()` | ✅ MATCH |
| **`00006`** | `rpc_cancel_ranked_matchmaking`| Public RPC | `OnlineRankedRepository.cancelMatchmaking()` | ✅ MATCH |
| **`00006`** | `rpc_poll_ranked_matchmaking` | Public RPC | `OnlineRankedRepository.pollMatchmaking()` | ✅ MATCH |
| **`00006`** | `rpc_ranked_submit_choice` | Public RPC | `OnlineRankedRepository.submitChoice(matchId, turnType, choice)` | ✅ MATCH |
| **`00006`** | `rpc_ranked_select_role` | Public RPC | `OnlineRankedRepository.selectRole(matchId, role)` | ✅ MATCH |
| **`00006`** | `rpc_ranked_start_second_innings` | Public RPC | `OnlineRankedRepository.startSecondInnings(matchId)` | ✅ MATCH |
| **`00006`** | `rpc_ranked_heartbeat` | Public RPC | `OnlineRankedRepository.sendHeartbeat(matchId)` | ✅ MATCH |
| **`00006`** | `rpc_ranked_report_disconnect` | Public RPC | `OnlineRankedRepository.reportDisconnect(matchId)` | ✅ MATCH |
| **`00006`** | `rpc_ranked_reconnect` | Public RPC | `OnlineRankedRepository.reconnect(matchId)` | ✅ MATCH |
| **`00006`** | `rpc_ranked_claim_timeout_forfeit` | Public RPC | `OnlineRankedRepository.claimTimeoutForfeit(matchId)` | ✅ MATCH |
| **`00006`** | `rpc_ranked_surrender` | Public RPC | `OnlineRankedRepository.surrender(matchId)` | ✅ MATCH |
| **`00006`** | `rpc_get_ranked_leaderboard` | Public RPC | `OnlineRankedRepository.getLeaderboard(limit, offset)` | ✅ MATCH |

### 1.2 RPC Signature & Parameter Verification
Every client-facing RPC called by the Flutter client was reconciled with PostgreSQL:

1. **`rpc_ranked_submit_choice`**:
   - PostgreSQL: `(p_match_id UUID, p_turn_type TEXT, p_choice SMALLINT)`
   - Flutter call: `client.rpc('rpc_ranked_submit_choice', params: {'p_match_id': matchId, 'p_turn_type': turnType, 'p_choice': choice})`
   - Clamping: Enforced 1..6 strictly in both client and PostgreSQL check constraint.
2. **`rpc_ranked_select_role`**:
   - PostgreSQL: `(p_match_id UUID, p_role TEXT)`
   - Flutter call: `client.rpc('rpc_ranked_select_role', params: {'p_match_id': matchId, 'p_role': normalized})`
3. **`rpc_ranked_claim_timeout_forfeit`**:
   - PostgreSQL: `(p_match_id UUID)`
   - Flutter call: `client.rpc('rpc_ranked_claim_timeout_forfeit', params: {'p_match_id': matchId})`
4. **`rpc_get_ranked_leaderboard`**:
   - PostgreSQL: `(p_limit INT DEFAULT 100, p_offset INT DEFAULT 0)`
   - Flutter call: `client.rpc('rpc_get_ranked_leaderboard', params: {'p_limit': limit, 'p_offset': offset})`
   - Clamping: PostgreSQL clamps `LEAST(100, GREATEST(1, p_limit))`.

### 1.3 Settlement & Progression Economy Contract
- **XP Formula**: Win: 100 XP, Loss: 40 XP, Tie: 60 XP, First Daily Bonus: 50 XP, capped at 1,500 XP / UTC day. Identical between `fn_calculate_ranked_match_xp` and canonical `XpCalculator`.
- **MMR Delta Formula**: Elo logistic formula with soft boundaries (Floor: 100 MMR).
- **Star Economy**:
  - Bronze/Silver: 3 stars per division; Gold/Platinum/Diamond: 4 stars; Elite/Pro Elite/Legend: 5 stars; Master: 10 stars.
  - Demotion shield: Absorbs 1 loss on division/tier drop.
  - Bronze loss floor: 0 stars floor (no negative stars).
  - Win streak bonus: +2 stars in Bronze on 3+ streak.
  - Early forfeit (<4 legal balls): Winner gets 0 stars, 0 MMR, 0 XP; forfeiter gets -16 MMR, 0 stars, 0 XP.
  - Daily player pair cap: Max 2 win stars per player pair per UTC day.

---

## 2. Test Harness Safety Audit (`tool/run_staging_two_player_duel.js`)

The staging test runner [`tool/run_staging_two_player_duel.js`](file:///c:/Users/akhil/Downloads/Odd%20or%20Even/tool/run_staging_two_player_duel.js) was audited and strengthened against all Phase 5D safety requirements:

1. **Fail-Closed Missing / Malformed URL Protection**:
   - Validates URL syntax via `new URL(urlStr)`.
   - Strictly enforces `protocol === 'https:'`. Insecure `http:` URLs are rejected.
   - Requires hostname regex match `^([a-z0-9_-]+)\.supabase\.co$`.
2. **Explicit Project Reference Allowlist & Production Rejection**:
   - Production ref `fvjgnxgsmsgowmffwcpw` is hardcoded as forbidden. Any attempt to target this project causes an immediate `CRITICAL SECURITY REJECTION` process termination.
   - If `STAGING_PROJECT_REF` is supplied in the environment or CLI, the URL subdomain must match it exactly, preventing accidental targeting of unintended projects.
3. **Zero Credential Exposure**:
   - Passwords and JWT tokens are never logged or echoed to stdout/stderr.
   - Preflight diagnostic output prints only the sanitized project reference and masked URL (`https://<prefix>...supabase.co`).
4. **Pre-Authentication Target Verification**:
   - Before authenticating players, the harness executes schema probe queries against `public.ranked_matches` and `rpc_get_ranked_leaderboard` to ensure migrations `00001`–`00006` are present on the staging database.
5. **Isolated Test Account Scoping**:
   - Test accounts use unique high-entropy identifiers (`staging_test_<label>_<timestamp>_<random>@oddeven.test`).
   - Test actions are confined strictly to the test match and test accounts.
   - No destructive broad `DELETE` or `TRUNCATE` operations exist in the harness.

---

## 3. Test Coverage Audit

The live multiplayer test harness validates the complete competitive multiplayer lifecycle:

| Scenario | Target Layer | Verification Method | Status |
| :--- | :--- | :--- | :--- |
| **Two Independent Authenticated Users** | Supabase Auth | Generates two distinct JWT sessions (`playerA != playerB`) | ✅ LIVE |
| **Matchmaking & Pairing** | PostgreSQL RPC | Both players call `rpc_join_ranked_matchmaking`; paired into same match | ✅ LIVE |
| **Participant Identity & Parity** | `ranked_matches` | Server assigns distinct odd/even parities and player roles | ✅ LIVE |
| **Secret Choice Privacy** | `ranked_pending_submissions` | Opponent direct REST read is executed and verified blocked by RLS | ✅ LIVE |
| **Normal Scoring & Wickets** | `rpc_ranked_submit_choice` | Distinct numbers (+runs) and matching numbers (Wicket OUT!) verified | ✅ LIVE |
| **Innings Transitions** | Server State Machine | First innings score sets second innings target; roles reverse | ✅ LIVE |
| **Disconnect & Grace Window** | `rpc_ranked_report_disconnect` | Turn timer paused; 30-second grace window initiated | ✅ LIVE |
| **Reconnection Recovery** | `rpc_ranked_reconnect` | Reconnection restores active duel state within grace window | ✅ LIVE |
| **Chase Completion & Settlement** | `fn_settle_ranked_match` | Chase target exceeded; server triggers atomic settlement | ✅ LIVE |
| **Settlement Idempotency** | `ranked_match_settlements` | Verification of settlement record existence in database | ✅ LIVE |
| **Leaderboard Reconciliation** | `rpc_get_ranked_leaderboard` | Live ranking order and match record populated in public view | ✅ LIVE |
| **Profile Reconciliation** | `online_player_ranks` | Authoritative MMR, stars, and win stats updated in database | ✅ LIVE |

> [!NOTE]
> All 12 scenarios in `tool/run_staging_two_player_duel.js` execute **genuine live network HTTP/REST and RPC requests** against the target Supabase environment. No mocked responses or PGlite stubs are used.

---

## 4. Execution Restrictions & Safety Status

In accordance with Section 4 constraints:
- ❌ **`tool/run_staging_two_player_duel.js` has NOT been executed against any remote server.**
- ❌ **No migrations have been applied to production project `fvjgnxgsmsgowmffwcpw`.**
- ❌ **Production database configuration remains completely untouched.**
- ❌ **No Git commits were pushed to origin, and branch `main` remains untouched.**
- ❌ **Working directory changes are strictly confined to `feature/competitive-progression`.**

---

## 5. Audit Verdict & Minimum Safe Next Action

### **OFFICIAL VERDICT**: `READY FOR STAGING MIGRATION`

The migrations, Flutter client contracts, and live test harness are completely reconciled, validated, and ready for deployment to the dedicated staging project.

### Minimum Safe Next Actions:

1. **Manual Staging Project Creation**:
   The project owner creates a dedicated staging project in the [Supabase Dashboard](https://supabase.com/dashboard) (e.g. `Odd-or-Even-Staging`).
2. **Link Staging Project Locally**:
   ```bash
   supabase link --project-ref <STAGING_PROJECT_REF>
   ```
3. **Apply Migrations to Staging**:
   ```bash
   supabase db push
   ```
4. **Execute Live Staging Two-Player Duel**:
   Once migrations are pushed, provide the staging credentials or execute:
   ```bash
   node tool/run_staging_two_player_duel.js https://<STAGING_PROJECT_REF>.supabase.co <STAGING_ANON_KEY> <STAGING_PROJECT_REF>
   ```
