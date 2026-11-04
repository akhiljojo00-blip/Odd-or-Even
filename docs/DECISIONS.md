# Odd or Even - Architecture & Product Decisions

| Decision | Approved Value | Engineering Rationale |
|---|---|---|
| **Players** | Exactly 2 | Core hand-cricket mechanics are strictly 1v1 duel based. |
| **Number Range** | 1–10 | Classic 10-finger rules; 0 is strictly forbidden to preserve wicket parity. |
| **Parity Assignment** | Randomly assigned | Eliminates host/room-creator advantage. Both players receive parity from server/engine. |
| **Toss Winner Choice** | Bat or Bowl | Toss winner chooses their role; opponent takes the opposite role. |
| **Ball Resolution** | `batter != bowler -> batter scores; batter == bowler -> OUT` | Authentic finger cricket rule; bowler's number never contributes runs. |
| **Wickets per Innings** | Exactly 1 | 1 wicket ends the innings immediately. |
| **Innings Count** | 2 Innings | Standard cricket match structure. |
| **Chase Target** | `first_innings_runs + 1` | Standard cricket target formula. |
| **Overs / Balls** | 6 balls per over; configurable | Configurable to 1, 2, 5 overs or Unlimited (where wicket is the sole end condition). |
| **Game Modes** | Standard & Fast | Standard: manual per-ball; Fast: auto number selection supported. |
| **Decision Timer** | 10s default (5–30s allowed) | Fast-paced mobile gameplay without stalling. |
| **Timeout Point** | 1 timeout point to opponent | Recorded separately from batting runs. Does not cause instant forfeiture. |
| **Disconnect Grace** | 30 seconds | Allows temporary socket drops or background transitions without abrupt forfeits. |
| **Series Target** | 1–10 points (Default: 6) | 1 match win = 1 series point. First to hit target wins the series. |
| **Rematch Flow** | Fresh match, new toss | A rematch resets match scores and rolls a new toss while preserving series points. |
| **Online Authority** | Server Authoritative (PostgreSQL RPC) | Zero trust on client score reporting. Private submissions table with strict RLS. |
