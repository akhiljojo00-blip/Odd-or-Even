import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/engine/odd_or_even_engine.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';
import 'package:odd_or_even/features/game/domain/models/game_match_state.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/game/domain/models/player_info.dart';

void main() {
  group('OddOrEvenEngine Tests', () {
    const playerA = PlayerInfo(id: 'p1', name: 'Alice');
    const playerB = PlayerInfo(id: 'p2', name: 'Bob');
    const config = MatchConfig(overs: 1, decisionTimerSeconds: 10, seriesTargetPoints: 2);

    test('Number validation: strictly 1 through 10', () {
      expect(OddOrEvenEngine.isValidChoice(0), isFalse);
      expect(OddOrEvenEngine.isValidChoice(-1), isFalse);
      expect(OddOrEvenEngine.isValidChoice(11), isFalse);
      expect(OddOrEvenEngine.isValidChoice(1), isTrue);
      expect(OddOrEvenEngine.isValidChoice(10), isTrue);
      expect(OddOrEvenEngine.isValidChoice(5), isTrue);
    });

    test('Match initialization assigns opposite parities randomly', () {
      final state = OddOrEvenEngine.initializeMatch(
        config: config,
        player1: playerA,
        player2: playerB,
      );

      expect(state.phase, MatchPhase.tossInput);
      expect(state.player1.parity, isNotNull);
      expect(state.player2.parity, isNotNull);
      expect(state.player1.parity, isNot(equals(state.player2.parity)));
    });

    test('Toss resolution calculates sum and awards toss to correct parity', () {
      // Force Player 1 to be ODD and Player 2 to be EVEN
      var state = OddOrEvenEngine.initializeMatch(
        config: config,
        player1: playerA.copyWith(parity: Parity.odd),
        player2: playerB.copyWith(parity: Parity.even),
      );
      state = state.copyWith(
        player1: state.player1.copyWith(parity: Parity.odd),
        player2: state.player2.copyWith(parity: Parity.even),
      );

      // P1: 3, P2: 4 -> Sum 7 (Odd) -> Player 1 (Odd) wins
      final oddTossState = OddOrEvenEngine.resolveToss(
        state: state,
        player1Choice: 3,
        player2Choice: 4,
      );
      expect(oddTossState.phase, MatchPhase.roleSelection);
      expect(oddTossState.tossWinnerId, 'p1');

      // P1: 4, P2: 6 -> Sum 10 (Even) -> Player 2 (Even) wins
      final evenTossState = OddOrEvenEngine.resolveToss(
        state: state,
        player1Choice: 4,
        player2Choice: 6,
      );
      expect(evenTossState.tossWinnerId, 'p2');
    });

    test('Role selection assigns batter and bowler correctly', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: config,
        player1: playerA.copyWith(parity: Parity.odd),
        player2: playerB.copyWith(parity: Parity.even),
      );
      state = state.copyWith(
        phase: MatchPhase.roleSelection,
        tossWinnerId: 'p1',
      );

      // P1 chooses BAT
      final batState = OddOrEvenEngine.selectRole(
        state: state,
        choosingPlayerId: 'p1',
        chosenRole: CricketRole.bat,
      );
      expect(batState.phase, MatchPhase.firstInnings);
      expect(batState.currentBatterId, 'p1');
      expect(batState.currentBowlerId, 'p2');

      // P1 chooses BOWL -> P2 bats, P1 bowls
      final bowlState = OddOrEvenEngine.selectRole(
        state: state,
        choosingPlayerId: 'p1',
        chosenRole: CricketRole.bowl,
      );
      expect(bowlState.currentBatterId, 'p2');
      expect(bowlState.currentBowlerId, 'p1');
    });

    test('Ball resolution: different numbers award runs to batter', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: null), // unlimited overs
        player1: playerA,
        player2: playerB,
      );
      state = state.copyWith(
        phase: MatchPhase.firstInnings,
        currentBatterId: 'p1',
        currentBowlerId: 'p2',
        currentInningsNo: 1,
        currentInningsRuns: 0,
      );

      // Batter chooses 6, Bowler chooses 2 -> 6 runs scored
      final ball1 = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 6,
        bowlerChoice: 2,
      );
      expect(ball1.currentInningsRuns, 6);
      expect(ball1.legalBallsBowled, 1);
      expect(ball1.lastBallEvent?.isWicket, isFalse);
      expect(ball1.lastBallEvent?.runsScored, 6);
    });

    test('First innings ends on wicket; target is score + 1', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: null),
        player1: playerA,
        player2: playerB,
      );
      state = state.copyWith(
        phase: MatchPhase.firstInnings,
        currentBatterId: 'p1',
        currentBowlerId: 'p2',
        currentInningsNo: 1,
        currentInningsRuns: 10,
        legalBallsBowled: 2,
      );

      // Batter chooses 5, Bowler chooses 5 -> OUT!
      final outState = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 5,
        bowlerChoice: 5,
      );
      expect(outState.phase, MatchPhase.inningsBreak);
      expect(outState.firstInningsRuns, 10);
      expect(outState.targetRuns, 11);
      expect(outState.lastBallEvent?.isWicket, isTrue);
      expect(outState.lastBallEvent?.runsScored, 0);
    });

    test('Second innings chase: batter reaches target -> Chaser Wins', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: null, seriesTargetPoints: 2),
        player1: playerA,
        player2: playerB,
      );
      state = state.copyWith(
        phase: MatchPhase.secondInnings,
        currentBatterId: 'p2',
        currentBowlerId: 'p1',
        currentInningsNo: 2,
        firstInningsRuns: 10,
        targetRuns: 11,
        currentInningsRuns: 8,
      );

      // Chaser scores 4 -> Total 12 >= Target 11 -> Win!
      final winState = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 4,
        bowlerChoice: 3,
      );
      expect(winState.phase, MatchPhase.matchFinished);
      expect(winState.winnerId, 'p2');
      expect(winState.resultType, MatchResultType.chaserWon);
      expect(winState.player2.seriesScore, 1);
    });

    test('Second innings chase: batter out below target -> Defender Wins', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: null, seriesTargetPoints: 2),
        player1: playerA,
        player2: playerB,
      );
      state = state.copyWith(
        phase: MatchPhase.secondInnings,
        currentBatterId: 'p2',
        currentBowlerId: 'p1',
        currentInningsNo: 2,
        firstInningsRuns: 15,
        targetRuns: 16,
        currentInningsRuns: 9,
      );

      // Batter: 7, Bowler: 7 -> Out at 9 runs (< 15) -> Defender (p1) wins!
      final outState = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 7,
        bowlerChoice: 7,
      );
      expect(outState.phase, MatchPhase.matchFinished);
      expect(outState.winnerId, 'p1');
      expect(outState.resultType, MatchResultType.defenderWon);
      expect(outState.player1.seriesScore, 1);
    });

    test('Second innings chase: batter out exactly equal to target-1 -> TIE', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: null, seriesTargetPoints: 2),
        player1: playerA,
        player2: playerB,
      );
      state = state.copyWith(
        phase: MatchPhase.secondInnings,
        currentBatterId: 'p2',
        currentBowlerId: 'p1',
        currentInningsNo: 2,
        firstInningsRuns: 12,
        targetRuns: 13,
        currentInningsRuns: 12, // Level scores
      );

      // Equal numbers -> OUT -> Score 12 == 12 -> TIE!
      final tieState = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 2,
        bowlerChoice: 2,
      );
      expect(tieState.phase, MatchPhase.matchFinished);
      expect(tieState.winnerId, isNull);
      expect(tieState.resultType, MatchResultType.tie);
      expect(tieState.player1.seriesScore, 0);
      expect(tieState.player2.seriesScore, 0);
    });

    test('Series target triggers seriesFinished phase', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: null, seriesTargetPoints: 2),
        player1: playerA.copyWith(seriesScore: 1), // 1 more win needed
        player2: playerB.copyWith(seriesScore: 0),
      );
      state = state.copyWith(
        phase: MatchPhase.secondInnings,
        currentBatterId: 'p1',
        currentBowlerId: 'p2',
        currentInningsNo: 2,
        firstInningsRuns: 5,
        targetRuns: 6,
        currentInningsRuns: 4,
      );

      // p1 scores 3 -> Total 7 >= 6 -> Win match and hit series target 2!
      final seriesEndState = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 3,
        bowlerChoice: 1,
      );
      expect(seriesEndState.phase, MatchPhase.seriesFinished);
      expect(seriesEndState.seriesWinnerId, 'p1');
      expect(seriesEndState.player1.seriesScore, 2);
    });

    test('Timeout awards 1 timeout point to opponent', () {
      final state = OddOrEvenEngine.initializeMatch(
        config: config,
        player1: playerA,
        player2: playerB,
      );

      // Player 1 times out
      final timeoutState = OddOrEvenEngine.handleTimeout(
        state: state,
        timedOutPlayerId: 'p1',
      );
      expect(timeoutState.player2.timeoutPoints, 1);
      expect(timeoutState.player1.timeoutPoints, 0);
    });

    test('Rematch resets match state and timeout points while preserving series score', () {
      var state = OddOrEvenEngine.initializeMatch(
        config: config,
        player1: playerA.copyWith(seriesScore: 1, timeoutPoints: 1),
        player2: playerB.copyWith(seriesScore: 0, timeoutPoints: 2),
      );
      state = state.copyWith(
        phase: MatchPhase.matchFinished,
        winnerId: 'p1',
        firstInningsRuns: 20,
        targetRuns: 21,
      );

      final rematch = OddOrEvenEngine.initializeRematch(previousState: state);
      expect(rematch.phase, MatchPhase.tossInput);
      expect(rematch.matchId, isNot(equals(state.matchId)));
      expect(rematch.player1.seriesScore, 1);
      expect(rematch.player2.seriesScore, 0);
      expect(rematch.player1.timeoutPoints, 0); // Correctly reset for fresh match
      expect(rematch.player2.timeoutPoints, 0);
      expect(rematch.firstInningsRuns, 0);
      expect(rematch.targetRuns, isNull);
      expect(rematch.winnerId, isNull);
    });

    test('First innings completes when configured overs limit is reached', () {
      // 1 over = 6 legal balls
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: 1),
        player1: playerA,
        player2: playerB,
      );
      state = state.copyWith(
        phase: MatchPhase.firstInnings,
        currentBatterId: 'p1',
        currentBowlerId: 'p2',
        currentInningsNo: 1,
        currentInningsRuns: 15,
        legalBallsBowled: 5, // Ball 6 incoming
      );

      // Ball 6 bowled: batter scores 4 without wicket
      final ball6State = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 4,
        bowlerChoice: 2,
      );
      expect(ball6State.phase, MatchPhase.inningsBreak);
      expect(ball6State.firstInningsRuns, 19);
      expect(ball6State.targetRuns, 20);
      expect(ball6State.legalBallsBowled, 6);
    });

    test('Second innings ends when configured overs limit is reached without hitting target', () {
      // 1 over = 6 balls, chaser scores 12 but target is 15 -> Defender wins
      var state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: 1, seriesTargetPoints: 2),
        player1: playerA,
        player2: playerB,
      );
      state = state.copyWith(
        phase: MatchPhase.secondInnings,
        currentBatterId: 'p2',
        currentBowlerId: 'p1',
        currentInningsNo: 2,
        firstInningsRuns: 14,
        targetRuns: 15,
        currentInningsRuns: 10,
        legalBallsBowled: 5, // Ball 6 incoming
      );

      // Ball 6: Batter scores 2 -> total 12 (< target 15) -> defender p1 wins!
      final endState = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 2,
        bowlerChoice: 1,
      );
      expect(endState.phase, MatchPhase.matchFinished);
      expect(endState.winnerId, 'p1');
      expect(endState.resultType, MatchResultType.defenderWon);
      expect(endState.player1.seriesScore, 1);
    });

    test('Player forfeit awards victory to opponent and updates series score', () {
      final state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(seriesTargetPoints: 2),
        player1: playerA,
        player2: playerB,
      );

      // Player 1 forfeits
      final forfeitState = OddOrEvenEngine.forfeitMatch(
        state: state,
        forfeitingPlayerId: 'p1',
      );
      expect(forfeitState.phase, MatchPhase.matchFinished);
      expect(forfeitState.winnerId, 'p2');
      expect(forfeitState.resultType, MatchResultType.forfeit);
      expect(forfeitState.player2.seriesScore, 1);

      // Duplicate forfeit has no effect
      final dupState = OddOrEvenEngine.forfeitMatch(
        state: forfeitState,
        forfeitingPlayerId: 'p1',
      );
      expect(dupState.phase, MatchPhase.matchFinished);
      expect(dupState.player2.seriesScore, 1);
    });

    test('GameMatchState JSON serialization and deserialization roundtrip', () {
      final state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: 2, decisionTimerSeconds: 15, seriesTargetPoints: 5),
        player1: playerA.copyWith(parity: Parity.odd, seriesScore: 2, timeoutPoints: 1),
        player2: playerB.copyWith(parity: Parity.even, seriesScore: 1, timeoutPoints: 0),
      );

      final jsonMap = state.toJson();
      final revived = GameMatchState.fromJson(jsonMap);

      expect(revived.matchId, state.matchId);
      expect(revived.phase, state.phase);
      expect(revived.config.overs, 2);
      expect(revived.config.decisionTimerSeconds, 15);
      expect(revived.player1.parity, state.player1.parity);
      expect(revived.player1.seriesScore, 2);
      expect(revived.player2.seriesScore, 1);
    });
  });
}
