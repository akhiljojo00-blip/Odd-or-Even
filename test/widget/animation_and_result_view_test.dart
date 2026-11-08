import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/engine/odd_or_even_engine.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';
import 'package:odd_or_even/features/game/domain/models/game_match_state.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/game/domain/models/player_info.dart';
import 'package:odd_or_even/features/game/presentation/widgets/animated_coin_toss.dart';
import 'package:odd_or_even/features/game/presentation/widgets/match_result_view.dart';
import 'package:odd_or_even/features/game/presentation/widgets/scoreboard_card.dart';

void main() {
  group('AnimatedCoinToss Widget Tests', () {
    testWidgets('AnimatedCoinToss renders settled ODD outcome correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedCoinToss(
                outcome: Parity.odd,
                isFlipping: false,
              ),
            ),
          ),
        ),
      );

      // Advance animation to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));

      expect(find.text('ODD'), findsWidgets);
    });

    testWidgets('AnimatedCoinToss renders settled EVEN outcome correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedCoinToss(
                outcome: Parity.even,
                isFlipping: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));

      expect(find.text('EVEN'), findsWidgets);
    });
  });

  group('MatchResultView Widget Tests', () {
    late GameMatchState baseMatch;

    setUp(() {
      baseMatch = OddOrEvenEngine.initializeMatch(
        player1: const PlayerInfo(id: 'p1', name: 'Alice'),
        player2: const PlayerInfo(id: 'p2', name: 'Bob'),
        config: const MatchConfig(overs: 1, maxChoice: 6),
      );
    });

    testWidgets('MatchResultView renders VICTORY for winning player', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool rematchTapped = false;
      bool homeTapped = false;

      // Alice wins
      final winMatch = baseMatch.copyWith(
        phase: MatchPhase.matchFinished,
        winnerId: 'p1',
        firstInningsRuns: 18,
        currentInningsRuns: 10,
        resultType: MatchResultType.defenderWon,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchResultView(
              match: winMatch,
              currentUserId: 'p1',
              onRematch: () => rematchTapped = true,
              onHome: () => homeTapped = true,
            ),
          ),
        ),
      );

      // Pump animation frames
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('VICTORY!'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('BACK TO MAIN MENU'), findsOneWidget);

      await tester.ensureVisible(find.text('PLAY AGAIN'));
      await tester.tap(find.text('PLAY AGAIN'));
      expect(rematchTapped, isTrue);

      await tester.ensureVisible(find.text('BACK TO MAIN MENU'));
      await tester.tap(find.text('BACK TO MAIN MENU'));
      expect(homeTapped, isTrue);
    });

    testWidgets('MatchResultView renders DEFEAT for losing player', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final defeatMatch = baseMatch.copyWith(
        phase: MatchPhase.matchFinished,
        winnerId: 'p2',
        firstInningsRuns: 20,
        currentInningsRuns: 12,
        resultType: MatchResultType.defenderWon,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchResultView(
              match: defeatMatch,
              currentUserId: 'p1',
              onRematch: () {},
              onHome: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('DEFEAT'), findsOneWidget);
      expect(find.textContaining('Bob won this match'), findsOneWidget);
    });

    testWidgets('MatchResultView renders MATCH TIED! on tie outcome', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tieMatch = baseMatch.copyWith(
        phase: MatchPhase.matchFinished,
        winnerId: null,
        firstInningsRuns: 15,
        currentInningsRuns: 15,
        resultType: MatchResultType.tie,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchResultView(
              match: tieMatch,
              currentUserId: 'p1',
              onRematch: () {},
              onHome: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('MATCH TIED!'), findsOneWidget);
      expect(find.textContaining('Both players finished on exactly 15 runs'), findsOneWidget);
    });

    testWidgets('MatchResultView renders winner celebration for Pass & Play', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pnpMatch = baseMatch.copyWith(
        phase: MatchPhase.matchFinished,
        winnerId: 'p1',
        firstInningsRuns: 16,
        currentInningsRuns: 8,
        resultType: MatchResultType.defenderWon,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchResultView(
              match: pnpMatch,
              currentUserId: null, // Pass & Play
              onRematch: () {},
              onHome: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('ALICE WINS!'), findsOneWidget);
    });
  });

  group('ScoreboardCard Animation Tests', () {
    testWidgets('ScoreboardCard animates score updates and chase progress smoothly', (tester) async {
      final match = OddOrEvenEngine.initializeMatch(
        player1: const PlayerInfo(id: 'p1', name: 'Alice'),
        player2: const PlayerInfo(id: 'p2', name: 'Bob'),
        config: const MatchConfig(overs: 2, maxChoice: 6),
      ).copyWith(
        phase: MatchPhase.secondInnings,
        firstInningsRuns: 24,
        targetRuns: 25,
        currentInningsRuns: 12,
        currentInningsNo: 2,
        legalBallsBowled: 6,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreboardCard(matchState: match),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('TARGET: 25'), findsOneWidget);
      expect(find.text('Need 13 runs in 6 balls'), findsOneWidget);
      expect(find.text('OVERS: 1.0 / 2.0'), findsOneWidget);
    });
  });
}
