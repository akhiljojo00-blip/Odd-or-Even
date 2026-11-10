import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/domain/models/online_player_rank.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match_settlement.dart';
import 'package:odd_or_even/features/online/presentation/controllers/ranked_gameplay_controller.dart';
import 'package:odd_or_even/features/online/presentation/screens/ranked_gameplay_screen.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';

import '../unit/online/ranked_gameplay_controller_test.dart';

Widget createTestableWidget({
  required Widget child,
  required MockRankedGameplayRepository repository,
  required MockRankedRealtimeManager realtimeManager,
  String matchId = 'match-100',
}) {
  return ProviderScope(
    overrides: [
      onlineRankedRepositoryProvider.overrideWithValue(repository),
      rankedGameplayProvider(matchId).overrideWith((ref) {
        return RankedGameplayNotifier(
          repository: repository,
          manager: realtimeManager,
          matchId: matchId,
        );
      }),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRankedGameplayRepository mockRepo;
  late MockRankedRealtimeManager mockRealtime;

  setUp(() {
    mockRepo = MockRankedGameplayRepository();
    mockRealtime = MockRankedRealtimeManager(mockRepo);

    mockRepo.p1Rank = const OnlinePlayerRank(
      userId: 'user-p1',
      tier: RankTier.gold,
      division: RankDivision.II,
      stars: 2,
      mmr: 1350,
      totalXp: 2500,
      peakTier: RankTier.gold,
      peakDivision: RankDivision.II,
    );
    mockRepo.p2Rank = const OnlinePlayerRank(
      userId: 'user-p2',
      tier: RankTier.silver,
      division: RankDivision.I,
      stars: 1,
      mmr: 1200,
      totalXp: 1800,
      peakTier: RankTier.silver,
      peakDivision: RankDivision.I,
    );
  });

  group('RankedGameplayScreen - Widget Tests', () {
    testWidgets('Renders loading spinner initially when match is loading', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Don't set matchRecord so it starts loading
      await tester.pumpWidget(
        createTestableWidget(
          child: const RankedGameplayScreen(matchId: 'match-100'),
          repository: mockRepo,
          realtimeManager: mockRealtime,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders access restricted error view when user is not a participant', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockRepo.authenticatedUid = 'intruder-user';
      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.tossInput,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const RankedGameplayScreen(matchId: 'match-100'),
          repository: mockRepo,
          realtimeManager: mockRealtime,
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('ACCESS RESTRICTED'), findsOneWidget);
      expect(find.text('RETURN TO MENU'), findsOneWidget);
    });

    testWidgets('Renders toss stage with parity indicator and 1..6 number pad', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.tossInput,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const RankedGameplayScreen(matchId: 'match-100'),
          repository: mockRepo,
          realtimeManager: mockRealtime,
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('RANKED DUEL'), findsOneWidget);
      expect(find.text('TOSS STAGE'), findsOneWidget);
      expect(find.textContaining('You are ODD'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('SELECT A NUMBER (1 - 6)'), findsOneWidget);

      await tester.tap(find.text('4'));
      await tester.pump();

      expect(find.text('LOCK IN NUMBER 4'), findsOneWidget);

      await tester.tap(find.text('LOCK IN NUMBER 4'));
      await tester.pump();

      expect(mockRepo.submitChoiceCount, 1);
    });

    testWidgets('Renders role selection buttons when caller won toss', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.roleSelection,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
        tossWinnerId: 'user-p1',
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const RankedGameplayScreen(matchId: 'match-100'),
          repository: mockRepo,
          realtimeManager: mockRealtime,
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('YOU WON THE TOSS!'), findsOneWidget);
      expect(find.text('BAT FIRST'), findsOneWidget);
      expect(find.text('BOWL FIRST'), findsOneWidget);

      await tester.tap(find.text('BAT FIRST'));
      await tester.pump();

      expect(mockRepo.selectRoleCount, 1);
    });

    testWidgets('Renders active innings scoreboard with score and overs', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.firstInnings,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
        currentBatterId: 'user-p1',
        currentBowlerId: 'user-p2',
        currentInningsNo: 1,
        currentInningsRuns: 16,
        legalBallsBowled: 4,
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const RankedGameplayScreen(matchId: 'match-100'),
          repository: mockRepo,
          realtimeManager: mockRealtime,
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('1ST INNINGS'), findsOneWidget);
      expect(find.text('OVERS: 0.4 / 2.0'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('YOU ARE BATTING'), findsOneWidget);
    });

    testWidgets('Renders concluded match settlement view with stars and MMR breakdown', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockRepo.settlementRecord = const RankedMatchSettlement(
        matchId: 'match-100',
        winnerId: 'user-p1',
        loserId: 'user-p2',
        p1StarsDelta: 1,
        p2StarsDelta: -1,
        p1MmrDelta: 25,
        p2MmrDelta: -25,
        p1XpAwarded: 150,
        p2XpAwarded: 50,
      );

      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.matchFinished,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
        winnerId: 'user-p1',
        resultType: RankedResultType.runs,
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const RankedGameplayScreen(matchId: 'match-100'),
          repository: mockRepo,
          realtimeManager: mockRealtime,
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('VICTORY'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget); // Stars delta
      expect(find.text('+25'), findsOneWidget); // MMR delta
      expect(find.text('+150'), findsOneWidget); // XP delta
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('MAIN MENU'), findsOneWidget);
    });

    testWidgets('Surrender flag button opens confirmation dialog and confirms surrender', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.firstInnings,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const RankedGameplayScreen(matchId: 'match-100'),
          repository: mockRepo,
          realtimeManager: mockRealtime,
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      final flagIcon = find.byIcon(Icons.flag_outlined);
      expect(flagIcon, findsOneWidget);

      await tester.tap(flagIcon);
      await tester.pumpAndSettle();

      expect(find.text('Surrender Match?'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'SURRENDER'));
      await tester.pump();

      expect(mockRepo.surrenderCount, 1);
    });
  });
}
