# Odd or Even - Canonical Game Rules

## 1. Baseline Rules

### 1.1 Valid Numbers
- Players select integers exclusively from `1` through `10`.
- `0` and negative values are strictly invalid.
- Selections outside `1..10` are rejected by validation before submission.

### 1.2 Parity Assignment
- Parity roles (**ODD** and **EVEN**) are assigned randomly between the two players.
- For online matches, the server assigns parities cryptographically when both players enter the match. Neither player can choose their parity to prevent host advantage.
- For offline pass-and-play matches, parity is chosen via a high-entropy local random generator.

### 1.3 The Toss
- Both players secretly submit a number from `1` to `10`.
- The sum of both numbers is calculated:
  - If `(sum % 2 == 1)`: The player assigned **ODD** wins the toss.
  - If `(sum % 2 == 0)`: The player assigned **EVEN** wins the toss.
- The toss winner selects their preferred role: **BAT** or **BOWL**.
- The opponent automatically receives the opposite role.

### 1.4 Batting & Bowling (Ball Resolution)
- On each ball, both players submit a number from `1` to `10` simultaneously.
- If `batter_number != bowler_number`:
  - The batting player scores runs equal to their selected `batter_number`.
  - The bowler's number never adds runs to either player.
- If `batter_number == bowler_number`:
  - The batting player is **OUT** (wicket fallen).
  - 0 runs are scored on this ball.
  - The innings immediately ends. (There is exactly 1 wicket per innings).

### 1.5 Two Innings & Chase Target
- **First Innings:** Player 1 bats, Player 2 bowls until a wicket falls or the configured ball limit (overs) is exhausted.
- **Chase Target:** `first_innings_runs + 1`.
- **Second Innings:** Roles reverse. Player 2 bats, Player 1 bowls.
- **Ending Conditions:**
  - If chasing score >= target: The chasing player immediately **WINS**.
  - If the chasing batter gets **OUT** before reaching target: The first-innings player **WINS**.
  - If the chasing batter gets **OUT** with score exactly equal to `first_innings_runs`: The match is a **TIE**.
  - If the configured overs/balls run out before reaching target: The first-innings player wins (or tie if scores are level).

### 1.6 Overs & Legal Balls
- 1 over = 6 legal balls.
- Configurable settings: `1 Over (6 balls)`, `2 Overs (12 balls)`, `5 Overs (30 balls)`, or `Unlimited Overs`.
- In Unlimited Overs, the innings ends exclusively when the wicket falls.

### 1.7 Game Modes: Standard vs Fast
- **Standard Mode:** Players submit each number individually ball-by-ball.
- **Fast Mode (Auto Mode):** Players can toggle Auto mode or pre-select choices for an over. Automatic numbers are generated securely (on the server for online, locally for offline) in the range `1..10`. Future unrevealed choices remain strictly hidden until the ball is actively resolved.

### 1.8 Timers and Timeout Points
- Decision timer per ball: Default `10s`, configurable between `5s` and `30s`.
- If a connected player times out without choosing a number:
  - The opponent is awarded **1 timeout point**.
  - Timeout points are tracked separately from batting runs.
  - Normal timeouts do not forfeit the match automatically. After 3 consecutive timeouts or when grace expires, the match can be forfeited.

### 1.9 Series Points & Match Target Points
- A series consists of multiple individual matches played until one player hits the Series Target.
- Configurable series target presets: `1, 3, 5, 6, 10` (Default: `6`).
- Each individual match win awards **1 series point** to the winner.
- A tied match awards `0` series points to both players.
- The first player to reach the series target wins the series.
- Batting runs and timeout points never get mixed into series points.

### 1.10 Rematch Flow
- A rematch creates a fresh match with a new match ID.
- Reset match scores, overs, and innings to 0.
- Re-roll random Odd/Even parity assignment.
- Conduct a brand new toss.
- Maintain cumulative series scores across rematches until a series winner is crowned or the lobby exits.
