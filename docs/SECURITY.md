# Odd or Even - Security & Anti-Cheat Architecture

## 1. Threat Model & Mitigations

### 1.1 Secret Peeking (Timing & Network Sniffing)
- **Threat:** A malicious client listens to WebSocket payloads or database changes to read Player A's number before Player B submits.
- **Mitigation:**
  - `pending_submissions` has Row Level Security that denies `SELECT` to all public and authenticated roles (`USING (false)`).
  - Only `SECURITY DEFINER` PostgreSQL functions executed on the server have rights to inspect both numbers.
  - No secret number is broadcast until the ball is atomically resolved and committed to `ball_events`.

### 1.2 Score Tampering & Client Self-Reporting
- **Threat:** A modified client sends a payload claiming "I scored 10 runs" or "The opponent got out".
- **Mitigation:**
  - Clients only ever submit their own number choice (`1..10`).
  - The database calculates wickets, run sums, innings swaps, chase targets, and match winners inside PostgreSQL transactions.
  - Scores are read-only to clients.

### 1.3 Front-Running & Race Conditions
- **Threat:** Two simultaneous RPC submissions collide, or one player tries to change their choice after seeing a partial network response.
- **Mitigation:**
  - Database row-level locks (`SELECT ... FOR UPDATE`) are acquired on the `matches` row during turn evaluation.
  - A unique constraint on `(match_id, turn_type, innings_no, ball_no, user_id)` prevents a player from submitting more than once for a turn.
  - An optimistic version number is checked and incremented on every state mutation.

### 1.4 Impersonation & Authorization
- **Threat:** Player C joins or votes in a private match between Player A and Player B.
- **Mitigation:**
  - Every RPC verifies `auth.uid()`.
  - RPC calls check that `auth.uid()` matches either `player1_id` or `player2_id` of the referenced match.
  - Room joining enforces max 2 seats and locks against third-party entrants.

### 1.5 Denial of Service & Host Stalling
- **Threat:** A player goes idle when losing to stall the game indefinitely.
- **Mitigation:**
  - The server records `turn_deadline_at`.
  - The opponent can invoke `rpc_claim_timeout(match_id)`. If `now() > turn_deadline_at` and the delinquent player has not submitted, the timeout point is awarded.
  - After disconnect grace (30s) expires, `rpc_claim_forfeit(match_id)` can be invoked to claim an immediate win.
