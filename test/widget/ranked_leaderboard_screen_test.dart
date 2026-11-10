import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/domain/models/online_player_rank.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_leaderboard_entry.dart';
import 'package:odd_or_even/features/online/presentation/screens/ranked_leaderboard_screen.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_emblem_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLeaderboardRepository extends OnlineRankedRepository {
  List<RankedLeaderboardEntry> mockEntries;
  String? mockUserId;
  OnlinePlayerRank? mockUserRank;
  Exception? errorToThrow;
  int getLeaderboardCallCount = 0;

  FakeLeaderboardRepository({
    this.mockEntries = const [],
    this.mockUserId,
    this.mockUserRank,
    this.errorToThrow,
  }) : super();

  @override
  bool get isConfigured => true;

  @override
  String? get currentUserId => mockUserId;

  @override
  Future<String?> ensureAuthenticatedUser() async => mockUserId;

  @override
  Future<OnlinePlayerRank?> getPlayerRank([String? uid]) async => mockUserRank;

  @override
  Future<List<RankedLeaderboardEntry>> getLeaderboard({int limit = 100, int offset = 0}) async {
    getLeaderboardCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return mockEntries;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget(OnlineRankedRepository repo) {
    return ProviderScope(
      overrides: [
        onlineRankedRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: RankedLeaderboardScreen(),
      ),
    );
  }

  group('RankedLeaderboardScreen Widget Tests', () {
    testWidgets('renders empty state when no ranked entries exist', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeLeaderboardRepository(
        mockEntries: const [],
        mockUserId: 'user-empty',
      );

      await tester.pumpWidget(buildTestableWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('RANKED LEADERBOARD'), findsOneWidget);
      expect(find.text('SEASON 1 COMMENCING'), findsOneWidget);
      expect(
        find.text('No ranked duels completed yet. Play your first match to claim the #1 spot on the leaderboard!'),
        findsOneWidget,
      );
      expect(find.text('PLAY ONLINE RANKED'), findsOneWidget);
    });

    testWidgets('renders Top 100 leaderboard with podium styling and GM badges', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final entries = [
        const RankedLeaderboardEntry(
          userId: 'p-1',
          displayName: 'ApexStriker',
          avatarIndex: 0,
          tier: RankTier.grandMaster,
          division: null,
          stars: 0,
          mmr: 2840,
          winStreak: 12,
          totalRankedWins: 45,
          totalRankedMatches: 50,
          leaderboardRank: 1,
        ),
        const RankedLeaderboardEntry(
          userId: 'p-2',
          displayName: 'SpinMaster',
          avatarIndex: 1,
          tier: RankTier.master,
          division: null,
          stars: 7,
          mmr: 2510,
          winStreak: 4,
          totalRankedWins: 38,
          totalRankedMatches: 48,
          leaderboardRank: 2,
        ),
        const RankedLeaderboardEntry(
          userId: 'p-3',
          displayName: 'BoundaryKing',
          avatarIndex: 2,
          tier: RankTier.diamond,
          division: RankDivision.I,
          stars: 4,
          mmr: 2190,
          winStreak: 1,
          totalRankedWins: 30,
          totalRankedMatches: 45,
          leaderboardRank: 3,
        ),
        const RankedLeaderboardEntry(
          userId: 'p-4',
          displayName: 'CasualChallenger',
          avatarIndex: 3,
          tier: RankTier.platinum,
          division: RankDivision.II,
          stars: 2,
          mmr: 1850,
          winStreak: 0,
          totalRankedWins: 20,
          totalRankedMatches: 35,
          leaderboardRank: 4,
        ),
      ];

      final repo = FakeLeaderboardRepository(
        mockEntries: entries,
        mockUserId: 'p-4',
      );

      await tester.pumpWidget(buildTestableWidget(repo));
      await tester.pumpAndSettle();

      // Screen Header & Season Header
      expect(find.text('RANKED LEADERBOARD'), findsOneWidget);
      expect(find.text('TOP 100 DUELISTS'), findsOneWidget);
      expect(find.text('1 GRAND MASTERS'), findsOneWidget);

      // Entries list
      expect(find.text('ApexStriker'), findsOneWidget);
      expect(find.text('SpinMaster'), findsOneWidget);
      expect(find.text('BoundaryKing'), findsOneWidget);
      // CasualChallenger is both in the pinned card and in row 4
      expect(find.text('CasualChallenger'), findsNWidgets(2));

      // Grand Master Badge / Label
      expect(find.text('Grand Master'), findsOneWidget);

      // MMR and Wins
      expect(find.text('2840 MMR'), findsOneWidget);
      expect(find.text('2510 MMR'), findsOneWidget);
      expect(find.text('2190 MMR'), findsOneWidget);
      expect(find.textContaining('1850 MMR'), findsWidgets);

      // Verify rank emblems exist
      expect(find.byType(RankEmblemWidget), findsWidgets);
    });

    testWidgets('displays pinned current user card when user is in the ladder', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final entries = [
        const RankedLeaderboardEntry(
          userId: 'other-user',
          displayName: 'OtherPlayer',
          avatarIndex: 0,
          tier: RankTier.master,
          division: null,
          stars: 3,
          mmr: 2400,
          winStreak: 2,
          totalRankedWins: 20,
          totalRankedMatches: 25,
          leaderboardRank: 1,
        ),
        const RankedLeaderboardEntry(
          userId: 'user-pinned',
          displayName: 'MyCompetitiveSelf',
          avatarIndex: 2,
          tier: RankTier.diamond,
          division: RankDivision.I,
          stars: 4,
          mmr: 2150,
          winStreak: 6,
          totalRankedWins: 32,
          totalRankedMatches: 40,
          leaderboardRank: 2,
        ),
      ];

      final repo = FakeLeaderboardRepository(
        mockEntries: entries,
        mockUserId: 'user-pinned',
      );

      await tester.pumpWidget(buildTestableWidget(repo));
      await tester.pumpAndSettle();

      // Pinned user card title and badge
      expect(find.text('#2'), findsWidgets);
      expect(find.text('MyCompetitiveSelf'), findsWidgets);
      expect(find.text('YOU'), findsNWidgets(2));
      expect(find.textContaining('2150 MMR'), findsWidgets);
      expect(find.text('80% WIN'), findsOneWidget);
    });

    testWidgets('displays unranked banner on pinned card when user is not on leaderboard', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final entries = [
        const RankedLeaderboardEntry(
          userId: 'other-user',
          displayName: 'OtherPlayer',
          avatarIndex: 0,
          tier: RankTier.master,
          division: null,
          stars: 3,
          mmr: 2400,
          winStreak: 2,
          totalRankedWins: 20,
          totalRankedMatches: 25,
          leaderboardRank: 1,
        ),
      ];

      final repo = FakeLeaderboardRepository(
        mockEntries: entries,
        mockUserId: 'unranked-user',
        mockUserRank: null,
      );

      await tester.pumpWidget(buildTestableWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('PLAY RANKED TO RANK UP'), findsOneWidget);
      expect(
        find.text('Complete ranked duels to earn MMR and claim your spot on the leaderboard!'),
        findsOneWidget,
      );
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('displays error state with retry button on failure', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeLeaderboardRepository(
        mockEntries: const [],
        errorToThrow: Exception('Database connection timeout'),
      );

      await tester.pumpWidget(buildTestableWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('FAILED TO LOAD'), findsOneWidget);
      expect(
        find.text('Unable to load leaderboard. Please check connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('RETRY'), findsOneWidget);

      // Tapping RETRY triggers another call
      repo.errorToThrow = null;
      repo.mockEntries = [
        const RankedLeaderboardEntry(
          userId: 'p-1',
          displayName: 'RecoveredPlayer',
          avatarIndex: 0,
          tier: RankTier.gold,
          division: RankDivision.I,
          stars: 2,
          mmr: 1500,
          winStreak: 1,
          totalRankedWins: 10,
          totalRankedMatches: 15,
          leaderboardRank: 1,
        ),
      ];

      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();

      expect(find.text('RecoveredPlayer'), findsOneWidget);
      expect(find.text('FAILED TO LOAD'), findsNothing);
    });

    testWidgets('app bar refresh button triggers reload', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeLeaderboardRepository(
        mockEntries: const [],
      );

      await tester.pumpWidget(buildTestableWidget(repo));
      await tester.pumpAndSettle();

      final initialCalls = repo.getLeaderboardCallCount;

      final refreshBtn = find.byTooltip('Refresh Leaderboard');
      expect(refreshBtn, findsOneWidget);

      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(repo.getLeaderboardCallCount, greaterThan(initialCalls));
    });
  });
}
