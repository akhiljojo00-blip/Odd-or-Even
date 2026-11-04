# Odd or Even - Match Configuration

## 1. Configurable Parameters

| Parameter | Type | Allowed Values | Default Value | Description |
|---|---|---|---|---|
| `gameMode` | Enum | `standard`, `fast` | `standard` | Standard requires manual per-ball picks; Fast supports auto number selection. |
| `overs` | Integer / Null | `1, 2, 5, null` (unlimited) | `null` (Unlimited) | Number of 6-ball overs per innings. In standard hand-cricket, 1 wicket ends an innings regardless of balls if unlimited. |
| `decisionTimerSeconds` | Integer | `5, 10, 15, 20, 30` | `10` | Time allotted to submit a number before a timeout is incurred. |
| `autoModeEnabled` | Boolean | `true, false` | `false` | Whether the client may auto-generate numbers. |
| `seriesTargetPoints` | Integer | `1, 3, 5, 6, 10` | `6` | Number of match wins required to win the overall series. |

## 2. Configuration Validation Rules
1. `overs`: Must be positive integer or `null` for unlimited. If set, max legal balls = `overs * 6`.
2. `decisionTimerSeconds`: Clamped to `[5, 30]`.
3. `seriesTargetPoints`: Clamped to `[1, 10]`.
4. Online Configuration Agreement:
   - When a host proposes or alters any parameter in `game_rooms`, both players must press "Confirm" on that exact snapshot.
   - Any change automatically invalidates prior confirmations and requires both players to re-confirm.
   - Match cannot start until `player1_confirmed == true && player2_confirmed == true`.
