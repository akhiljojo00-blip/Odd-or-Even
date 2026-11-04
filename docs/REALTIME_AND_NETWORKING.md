# Odd or Even - Realtime and Networking Architecture

## 1. Network Transport Strategy
- **Transport Mechanism:** Supabase Realtime Channels (PostgreSQL WAL changes / Postgres Changes & Broadcast).
- **Primary Source of Truth:** PostgreSQL database tables (`matches`, `ball_events`).
- Realtime events are treated as **accelerators** for UI updates, not the single source of truth. If a realtime event is lost, client falls back to polling or refetches the authoritative match state.

## 2. Event Sequence for Each Ball

```
Player A                  Supabase Backend                 Player B
   |                             |                             |
   |-- submit_turn(num: 7) ----> | (Stores in pending_sub)     |
   |                             |                             |
   |                             | <---- submit_turn(num: 3) --|
   |                             |                             |
   |                             | [Atomic Resolution]         |
   |                             | 1. Lock match               |
   |                             | 2. Compare 7 vs 3 -> Run 7  |
   |                             | 3. Insert ball_events       |
   |                             | 4. Update match total score |
   |                             |                             |
   |<==== Broadcast 'ball_resolved' (7, 3, outcome: run, runs: 7) ====>|
   |                             |                             |
   |-- Animate outcome (1.5s) ---|                             |-- Animate outcome (1.5s) --
```

## 3. Reconnection & Snapshot Synchronization
When a client resumes from background or recovers from internet loss:
1. Re-authenticates anonymous or user session with Supabase Auth.
2. Checks for any active match ID stored in local cache or invokes `rpc_get_active_match()`.
3. Calls `rpc_get_match_snapshot(match_id)`:
   - Fetches current match state (`phase`, `current_innings_no`, `first_innings_runs`, `current_score`, `target_runs`, `turn_deadline_at`).
   - Fetches all resolved balls in `ball_events` for the current match.
   - Fetches player's own pending submission status (`has_submitted: true/false`).
4. Re-subscribes to Realtime channel `match:{match_id}`.
5. Re-synchronizes countdown timer relative to `turn_deadline_at - now()`.
