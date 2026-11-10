import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/app/router.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';
import 'package:odd_or_even/features/game/domain/models/game_match_state.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/game/domain/models/player_info.dart';
import 'package:odd_or_even/features/game/presentation/widgets/match_result_view.dart';
import 'package:odd_or_even/features/progression/domain/logic/rank_calculator.dart';
import 'package:odd_or_even/features/progression/domain/logic/xp_calculator.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/controllers/vs_computer_ranked_controller.dart';
import 'package:odd_or_even/features/progression/presentation/screens/vs_computer_ranked_gameplay_screen.dart';
import 'package:odd_or_even/features/progression/presentation/screens/vs_computer_ranked_setup_screen.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/ranked_progression_summary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VS Computer Ranked Mode Integration Tests', () {
    testWidgets('HomeScreen renders VS COMPUTER RANKED card and navigates to setup and play', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ODD OR EVEN'), findsOneWidget);
      expect(find.text('VS COMPUTER RANKED'), findsOneWidget);
      expect(find.text('RANKED'), findsOneWidget);

      // Scroll and Tap VS COMPUTER RANKED card
      await tester.ensureVisible(find.text('VS COMPUTER RANKED'));
      await tester.pump();
      await tester.tap(find.text('VS COMPUTER RANKED'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies navigation to VsComputerRankedSetupScreen
      expect(find.text('RANKED SOLO LADDER'), findsOneWidget);
      expect(find.text('NUMBER SELECTION RANGE'), findsOneWidget);
      expect(find.text('START RANKED MATCH'), findsOneWidget);

      // Tap START RANKED MATCH button
      await tester.ensureVisible(find.text('START RANKED MATCH'));
      await tester.pump();
      await tester.tap(find.text('START RANKED MATCH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Reaches VsComputerRankedGameplayScreen
      expect(find.text('RANKED DUEL'), findsOneWidget);
      expect(find.text('COIN TOSS DUEL'), findsOneWidget);
    });

    testWidgets('VsComputerRankedSetupScreen allows toggling number range 1-6 and 1-10', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VsComputerRankedSetupScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 to 6'), findsOneWidget);
      expect(find.text('1 to 10'), findsOneWidget);

      // Tap 1 to 10 chip
      await tester.ensureVisible(find.text('1 to 10'));
      await tester.pump();
      await tester.tap(find.text('1 to 10'));
      await tester.pump(const Duration(milliseconds: 100));

      // Switch back to 1 to 6
      await tester.ensureVisible(find.text('1 to 6'));
      await tester.pump();
      await tester.tap(find.text('1 to 6'));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('VsComputerRankedGameplayScreen initializes in toss phase and accepts choice', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VsComputerRankedGameplayScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('RANKED DUEL'), findsOneWidget);
      expect(find.text('COIN TOSS DUEL'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('COMPUTER'), findsOneWidget);

      // Select toss number 3
      await tester.ensureVisible(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 100));

      // Confirm button on NumberPad is labeled 'LOCK IN NUMBER 3'
      expect(find.text('LOCK IN NUMBER 3'), findsOneWidget);
      await tester.tap(find.text('LOCK IN NUMBER 3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // State progresses past toss input
      final match = container.read(vsComputerRankedGameProvider).match;
      expect(match.phase, isNot(MatchPhase.tossInput));
    });

    testWidgets('MatchResultView renders RankedProgressionSummaryCard cleanly without layout issues', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final finishedMatch = GameMatchState(
        matchId: 'ranked-test-01',
        phase: MatchPhase.matchFinished,
        config: const MatchConfig(maxChoice: 6),
        player1: const PlayerInfo(id: 'human', name: 'Master Player', seriesScore: 1),
        player2: const PlayerInfo(id: 'computer', name: 'AI Opponent', seriesScore: 0),
        winnerId: 'human',
        resultType: MatchResultType.chaserWon,
        firstInningsRuns: 15,
        currentInningsRuns: 16,
      );

      const rankState = VsComputerRankState(
        tier: RankTier.silver,
        division: RankDivision.II,
        stars: 2,
        winStreak: 3,
        peakTier: RankTier.silver,
        peakDivision: RankDivision.II,
      );

      final transition = RankCalculator.computeTransition(
        current: rankState,
        outcome: MatchOutcome.win,
      );

      final xpCalc = XpCalculator.computeMatchXp(
        currentTotalXp: 450,
        isWin: true,
        isTie: false,
        legalBallsBowled: 8,
        isPassAndPlay: false,
        isPromotion: false,
        dailyXpAccumulatedSoFar: 100,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MatchResultView(
                match: finishedMatch,
                currentUserId: 'human',
                onRematch: () {},
                onHome: () {},
                progressionCard: RankedProgressionSummaryCard(
                  rankState: rankState,
                  transitionResult: transition,
                  xpResult: xpCalc,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('VICTORY!'), findsOneWidget);
      expect(find.text('RANK PROGRESSION'), findsOneWidget);
      expect(find.text('+2 (Streak!)'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('BACK TO MAIN MENU'), findsOneWidget);
    });

    testWidgets('Navigation: Home -> Casual VS Computer Setup', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('VS COMPUTER'), findsOneWidget);
      expect(find.text('SOLO AI'), findsOneWidget);
      await tester.ensureVisible(find.text('VS COMPUTER'));
      await tester.pump();
      await tester.tap(find.text('VS COMPUTER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('VS COMPUTER SETUP'), findsOneWidget);
    });

    testWidgets('Navigation: Home -> Pass & Play Setup', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PASS & PLAY'), findsOneWidget);
      await tester.ensureVisible(find.text('PASS & PLAY'));
      await tester.pump();
      await tester.tap(find.text('PASS & PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('MATCH CONFIGURATION'), findsOneWidget);
    });

    testWidgets('Navigation: Home -> Online Rooms Lobby', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ONLINE ROOMS'), findsOneWidget);
      await tester.ensureVisible(find.text('ONLINE ROOMS'));
      await tester.pump();
      await tester.tap(find.text('ONLINE ROOMS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ONLINE MULTIPLAYER'), findsOneWidget);
    });
  });
}
