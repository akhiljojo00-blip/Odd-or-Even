import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/engine/odd_or_even_engine.dart';
import 'package:odd_or_even/features/game/domain/models/ball_event.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';
import 'package:odd_or_even/features/game/domain/models/game_match_state.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/game/domain/models/player_info.dart';
import 'package:odd_or_even/features/game/presentation/widgets/ball_outcome_dialog.dart';

void main() {
  group('Ball Resolution & Authoritative Display Regression Tests (Task A)', () {
    const p1 = PlayerInfo(id: 'usr_p1', name: 'Player 1');
    const p2 = PlayerInfo(id: 'usr_p2', name: 'Player 2');
    const config = MatchConfig(overs: 5, decisionTimerSeconds: 10, seriesTargetPoints: 6);

    GameMatchState setupActiveInnings({required bool p1Batting}) {
      var state = OddOrEvenEngine.initializeMatch(
        config: config,
        player1: p1.copyWith(parity: Parity.odd),
        player2: p2.copyWith(parity: Parity.even),
      );
      state = OddOrEvenEngine.resolveToss(
        state: state,
        player1Choice: 3,
        player2Choice: 4,
      );
      state = OddOrEvenEngine.selectRole(
        state: state,
        choosingPlayerId: state.tossWinnerId!,
        chosenRole: p1Batting ? CricketRole.bat : CricketRole.bowl,
      );
      return state;
    }

    test('Scenario 1: Batter 3, Bowler 8 -> +3 runs with exact numbers preserved', () {
      final state = setupActiveInnings(p1Batting: true);
      final next = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 3,
        bowlerChoice: 8,
      );

      expect(next.lastBallEvent, isNotNull);
      expect(next.lastBallEvent!.batterNumber, equals(3));
      expect(next.lastBallEvent!.bowlerNumber, equals(8));
      expect(next.lastBallEvent!.runsScored, equals(3));
      expect(next.lastBallEvent!.isWicket, isFalse);
      expect(next.currentInningsRuns, equals(3));
      expect(next.ballHistory.last.batterNumber, equals(3));
      expect(next.ballHistory.last.bowlerNumber, equals(8));
    });

    test('Scenario 2: Batter 9, Bowler 2 -> +9 runs with exact numbers preserved', () {
      final state = setupActiveInnings(p1Batting: true);
      final next = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 9,
        bowlerChoice: 2,
      );

      expect(next.lastBallEvent!.batterNumber, equals(9));
      expect(next.lastBallEvent!.bowlerNumber, equals(2));
      expect(next.lastBallEvent!.runsScored, equals(9));
      expect(next.lastBallEvent!.isWicket, isFalse);
      expect(next.currentInningsRuns, equals(9));
    });

    test('Scenario 3: Batter 4, Bowler 4 -> WICKET! runs 0 and innings completed', () {
      final state = setupActiveInnings(p1Batting: true);
      final next = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 4,
        bowlerChoice: 4,
      );

      expect(next.lastBallEvent!.batterNumber, equals(4));
      expect(next.lastBallEvent!.bowlerNumber, equals(4));
      expect(next.lastBallEvent!.isWicket, isTrue);
      expect(next.lastBallEvent!.runsScored, equals(0));
      expect(next.phase, equals(MatchPhase.inningsBreak));
    });

    test('Scenario 4: Batter 10, Bowler 1 -> +10 runs with boundary limits tested', () {
      final state = setupActiveInnings(p1Batting: true);
      final next = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 10,
        bowlerChoice: 1,
      );

      expect(next.lastBallEvent!.batterNumber, equals(10));
      expect(next.lastBallEvent!.bowlerNumber, equals(1));
      expect(next.lastBallEvent!.runsScored, equals(10));
      expect(next.lastBallEvent!.isWicket, isFalse);
      expect(next.currentInningsRuns, equals(10));
    });

    test('Multi-ball sequence prevents stale Ball 1 (7 and 5) from persisting', () {
      var state = setupActiveInnings(p1Batting: false); // Player 2 is batting!

      // Ball 1: Batter (Player 2) picks 7, Bowler (Player 1) picks 5 -> +7 runs
      state = OddOrEvenEngine.resolveBall(state: state, batterChoice: 7, bowlerChoice: 5);
      expect(state.ballHistory.length, equals(1));
      expect(state.lastBallEvent!.batterNumber, equals(7));
      expect(state.lastBallEvent!.bowlerNumber, equals(5));
      expect(state.currentInningsRuns, equals(7));

      // Ball 2: Batter picks 3, Bowler picks 8 -> +3 runs (Total 10 runs)
      // VERIFY: lastBallEvent must NOT display 7 and 5! It must display 3 and 8!
      state = OddOrEvenEngine.resolveBall(state: state, batterChoice: 3, bowlerChoice: 8);
      expect(state.ballHistory.length, equals(2));
      expect(state.lastBallEvent!.batterNumber, equals(3), reason: 'Must not display stale choice from Ball 1');
      expect(state.lastBallEvent!.bowlerNumber, equals(8), reason: 'Must not display stale choice from Ball 1');
      expect(state.lastBallEvent!.runsScored, equals(3));
      expect(state.ballHistory.last.batterNumber, equals(3));
      expect(state.ballHistory.last.bowlerNumber, equals(8));
      expect(state.currentInningsRuns, equals(10));

      // Ball 3: Batter picks 4, Bowler picks 4 -> WICKET!
      state = OddOrEvenEngine.resolveBall(state: state, batterChoice: 4, bowlerChoice: 4);
      expect(state.ballHistory.length, equals(3));
      expect(state.lastBallEvent!.batterNumber, equals(4));
      expect(state.lastBallEvent!.bowlerNumber, equals(4));
      expect(state.lastBallEvent!.isWicket, isTrue);
      expect(state.ballHistory.last.isWicket, isTrue);
    });

    test('PostgreSQL snake_case ball_events JSON deserialization preserves chronological order and lastBallEvent', () {
      // Simulate raw payload received from Supabase REST API
      final rawEvents = [
        {
          'innings_no': 1,
          'ball_no': 1,
          'batter_id': 'usr_p2',
          'bowler_id': 'usr_p1',
          'batter_number': 7,
          'bowler_number': 5,
          'runs_scored': 7,
          'is_wicket': false,
          'cumulative_runs': 7,
        },
        {
          'innings_no': 1,
          'ball_no': 2,
          'batter_id': 'usr_p2',
          'bowler_id': 'usr_p1',
          'batter_number': 3,
          'bowler_number': 8,
          'runs_scored': 3,
          'is_wicket': false,
          'cumulative_runs': 10,
        },
      ];

      final matchJson = {
        'id': 'match_abc_123',
        'phase': 'first_innings',
        'config': config.toJson(),
        'player1_id': 'usr_p1',
        'player2_id': 'usr_p2',
        'player1_parity': 'odd',
        'player2_parity': 'even',
        'current_batter_id': 'usr_p2',
        'current_bowler_id': 'usr_p1',
        'current_innings_runs': 10,
        'legal_balls_bowled': 2,
        'ballHistory': rawEvents,
      };

      final deserialized = GameMatchState.fromJson(matchJson);

      // Verify ballHistory has both balls in chronological sequence
      expect(deserialized.ballHistory.length, equals(2));
      expect(deserialized.ballHistory[0].batterNumber, equals(7));
      expect(deserialized.ballHistory[0].bowlerNumber, equals(5));
      expect(deserialized.ballHistory[1].batterNumber, equals(3));
      expect(deserialized.ballHistory[1].bowlerNumber, equals(8));

      // Verify lastBallEvent resolves to ball 2 (3 and 8), NOT ball 1 (7 and 5)
      expect(deserialized.lastBallEvent, isNotNull);
      expect(deserialized.lastBallEvent!.batterNumber, equals(3));
      expect(deserialized.lastBallEvent!.bowlerNumber, equals(8));
      expect(deserialized.lastBallEvent!.runsScored, equals(3));
    });

    test('Both Player 1 and Player 2 view exact identical authoritative resolved outcome', () {
      final ball = BallEvent(
        inningsNo: 1,
        ballNo: 1,
        batterId: 'usr_p2',
        bowlerId: 'usr_p1',
        batterNumber: 7,
        bowlerNumber: 5,
        runsScored: 7,
        isWicket: false,
        cumulativeRuns: 7,
      );

      final state = setupActiveInnings(p1Batting: false).copyWith(
        ballHistory: [ball],
        lastBallEvent: ball,
      );

      // From Player 1 perspective (bowler):
      final p1BatterName = state.getPlayerById(ball.batterId).name;
      final p1BowlerName = state.getPlayerById(ball.bowlerId).name;
      expect(p1BatterName, equals('Player 2'));
      expect(p1BowlerName, equals('Player 1'));
      expect(ball.batterNumber, equals(7));
      expect(ball.bowlerNumber, equals(5));

      // From Player 2 perspective (batter):
      final p2BatterName = state.getPlayerById(ball.batterId).name;
      final p2BowlerName = state.getPlayerById(ball.bowlerId).name;
      expect(p2BatterName, equals('Player 2'));
      expect(p2BowlerName, equals('Player 1'));
      expect(ball.batterNumber, equals(7));
      expect(ball.bowlerNumber, equals(5));

      // Both agree on exact values
      expect(p1BatterName, equals(p2BatterName));
      expect(p1BowlerName, equals(p2BowlerName));
    });

    test('PostgreSQL DESCENDING (reversed) ball_events array is sorted and lastBallEvent picks newest ball', () {
      // Simulate raw payload received when backend orders descending: [Ball 3, Ball 2, Ball 1]
      final descendingRawEvents = [
        {
          'innings_no': 1,
          'ball_no': 3,
          'batter_id': 'usr_p2',
          'bowler_id': 'usr_p1',
          'batter_number': 4,
          'bowler_number': 4,
          'runs_scored': 0,
          'is_wicket': true,
          'cumulative_runs': 10,
        },
        {
          'innings_no': 1,
          'ball_no': 2,
          'batter_id': 'usr_p2',
          'bowler_id': 'usr_p1',
          'batter_number': 3,
          'bowler_number': 8,
          'runs_scored': 3,
          'is_wicket': false,
          'cumulative_runs': 10,
        },
        {
          'innings_no': 1,
          'ball_no': 1,
          'batter_id': 'usr_p2',
          'bowler_id': 'usr_p1',
          'batter_number': 7,
          'bowler_number': 5,
          'runs_scored': 7,
          'is_wicket': false,
          'cumulative_runs': 7,
        },
      ];

      final matchJson = {
        'id': 'match_desc_test',
        'phase': 'innings_break',
        'config': config.toJson(),
        'player1_id': 'usr_p1',
        'player2_id': 'usr_p2',
        'ballHistory': descendingRawEvents,
      };

      final state = GameMatchState.fromJson(matchJson);

      // Must be sorted chronologically regardless of server arrival order
      expect(state.ballHistory.length, equals(3));
      expect(state.ballHistory[0].ballNo, equals(1));
      expect(state.ballHistory[0].batterNumber, equals(7));
      expect(state.ballHistory[0].bowlerNumber, equals(5));

      expect(state.ballHistory[1].ballNo, equals(2));
      expect(state.ballHistory[1].batterNumber, equals(3));
      expect(state.ballHistory[1].bowlerNumber, equals(8));

      expect(state.ballHistory[2].ballNo, equals(3));
      expect(state.ballHistory[2].batterNumber, equals(4));
      expect(state.ballHistory[2].bowlerNumber, equals(4));

      // Authoritative lastBallEvent MUST be Ball 3 (4 and 4), NEVER Ball 1 (7 and 5)
      expect(state.lastBallEvent, isNotNull);
      expect(state.lastBallEvent!.ballNo, equals(3));
      expect(state.lastBallEvent!.batterNumber, equals(4));
      expect(state.lastBallEvent!.bowlerNumber, equals(4));
      expect(state.lastBallEvent!.isWicket, isTrue);
    });

    test('GameMatchState roomId serialization and deserialization roundtrip', () {
      final state = setupActiveInnings(p1Batting: true).copyWith(roomId: 'room_xyz_789');
      expect(state.roomId, equals('room_xyz_789'));

      final json = state.toJson();
      expect(json['roomId'], equals('room_xyz_789'));

      final fromJson = GameMatchState.fromJson(json);
      expect(fromJson.roomId, equals('room_xyz_789'));
    });

    testWidgets('BallOutcomeDialog renders exact submitted numbers and runs scored (3 vs 8 -> +3)', (tester) async {
      final ballEvent = BallEvent(
        inningsNo: 1,
        ballNo: 2,
        batterId: 'usr_p2',
        bowlerId: 'usr_p1',
        batterNumber: 3,
        bowlerNumber: 8,
        runsScored: 3,
        isWicket: false,
        cumulativeRuns: 10,
      );

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BallOutcomeDialog(
              ballEvent: ballEvent,
              batterName: 'Player 2',
              bowlerName: 'Player 1',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and numbers
      expect(find.text('+3 RUNS SCORED!'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Batter number
      expect(find.text('8'), findsOneWidget); // Bowler number
      expect(find.text('BATTER'), findsOneWidget);
      expect(find.text('BOWLER'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.textContaining('Numbers differed!'), findsOneWidget);

      // Tap Continue
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('BallOutcomeDialog renders WICKET when choices match (4 vs 4 -> OUT)', (tester) async {
      final wicketEvent = BallEvent(
        inningsNo: 1,
        ballNo: 3,
        batterId: 'usr_p2',
        bowlerId: 'usr_p1',
        batterNumber: 4,
        bowlerNumber: 4,
        runsScored: 0,
        isWicket: true,
        cumulativeRuns: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BallOutcomeDialog(
              ballEvent: wicketEvent,
              batterName: 'Player 2',
              bowlerName: 'Player 1',
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify WICKET presentation
      expect(find.text('OUT! WICKET FALLEN!'), findsOneWidget);
      expect(find.text('4'), findsNWidgets(2)); // Both batter & bowler chose 4
      expect(find.textContaining('Numbers matched (4 == 4)! Batter is OUT.'), findsOneWidget);
    });

    test('GameMatchState safely handles unrecognized or null player IDs without throwing ArgumentError', () {
      const state = GameMatchState(
        matchId: 'test_match_safe_id',
        phase: MatchPhase.firstInnings,
        config: MatchConfig(),
        player1: PlayerInfo(id: 'p1_id', name: 'Alice'),
        player2: PlayerInfo(id: 'p2_id', name: 'Bob'),
        currentBatterId: 'p1_id',
        currentBowlerId: 'p2_id',
      );

      // Known IDs return real players
      expect(state.getPlayerById('p1_id').name, equals('Alice'));
      expect(state.getPlayerById('p2_id').name, equals('Bob'));
      expect(state.getOpponentOf('p1_id').name, equals('Bob'));
      expect(state.getOpponentOf('p2_id').name, equals('Alice'));

      // Unknown IDs return safe fallback without crashing
      final unknown = state.getPlayerById('unknown_uuid_123456');
      expect(unknown.id, equals('unknown_uuid_123456'));
      expect(unknown.name, isNotEmpty);

      final opponentFallback = state.getOpponentOf('unknown_uuid');
      expect(opponentFallback.id, equals('p2_id'));
    });
  });
}
