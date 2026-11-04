# Odd or Even - Testing Strategy & Quality Assurance

## 1. Multi-Tiered Verification Hierarchy

### 1.1 Pure Domain Engine Unit Tests
- `test/unit/game_engine_test.dart`:
  - Number validation: rejects `<= 0` and `> 10`.
  - Parity calculation: odd sum -> odd player wins toss, even sum -> even player wins toss.
  - Ball resolution:
    - Different numbers -> batter scores batter's number, bowler scores 0.
    - Equal numbers -> wicket fallen, 0 runs.
  - Innings logic:
    - First innings terminates on wicket or balls cap.
    - Target calculation: `first_innings_runs + 1`.
    - Chase completion: score reaches target -> chasing batter wins.
    - Chase failure: second wicket below target -> defender wins.
    - Tie match: second wicket equal to first innings score -> tie.
  - Timeout points: opponent gets 1 point, distinct from batting runs.
  - Series points: 1 point per match win, 0 for tie, series ends at configured target.
  - Rematch: initializes brand new match ID, re-randomizes parity, triggers new toss.

### 1.2 Widget & UI Integration Tests
- `test/widget/number_pad_test.dart`: Verifies all 10 buttons render and trigger callbacks.
- `test/widget/scoreboard_test.dart`: Verifies runs, target, overs, and timer rendering.
- `test/widget/offline_gameplay_flow_test.dart`: End-to-end simulated match from toss to result.

### 1.3 Backend RPC & Security Verification
- SQL migration syntax and constraint verification.
- RLS policy validation: ensures `pending_submissions` denies `SELECT` for authenticated users.
- Transaction idempotency: prevents duplicate submissions with the same idempotency key.

## 2. CI/CD Command Verification
- Formatting: `dart format --set-exit-if-changed .`
- Static Analysis: `dart analyze --fatal-infos`
- Test Suite: `flutter test --no-version-check --suppress-analytics`
