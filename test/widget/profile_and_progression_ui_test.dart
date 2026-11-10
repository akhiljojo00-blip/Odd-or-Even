import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/core/widgets/creator_footer.dart';
import 'package:odd_or_even/features/history/data/match_history_repository.dart';
import 'package:odd_or_even/features/history/presentation/screens/history_screen.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/domain/models/online_player_rank.dart';
import 'package:odd_or_even/features/profile/presentation/screens/profile_screen.dart';
import 'package:odd_or_even/features/progression/data/local_progression_repo.dart';
import 'package:odd_or_even/features/progression/domain/models/career_stats.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_emblem_widget.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_stars_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeOnlineRankedRepoForProfile extends OnlineRankedRepository {
  final OnlinePlayerRank? mockRank;
  FakeOnlineRankedRepoForProfile({this.mockRank}) : super();

  @override
  bool get isConfigured => true;

  @override
  String? get currentUserId => 'u-auth-test';

  @override
  Future<String?> ensureAuthenticatedUser() async => 'u-auth-test';

  @override
  Future<OnlinePlayerRank?> getPlayerRank([String? uid]) async => mockRank;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileScreen & Progression UI Widget Tests', () {
    testWidgets('ProfileScreen renders default progression state, Level 1, Bronze I, and Career Stats',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();

      // Top title and navigation
      expect(find.text('PLAYER PROFILE'), findsOneWidget);
      expect(find.byType(CreatorFooter), findsOneWidget);

      // Identity section
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('SAVE PROFILE'), findsOneWidget);

      // Level and XP Section
      expect(find.text('LEVEL 1'), findsOneWidget);
      expect(find.text('0 Total XP'), findsOneWidget);
      expect(find.text('Daily: 0 / 1500 XP'), findsOneWidget);
      expect(find.text('0 / 100 XP'), findsOneWidget);

      // Ranked summary cards
      expect(find.text('COMPETITIVE RANKS'), findsOneWidget);
      expect(find.text('SOLO LADDER'), findsOneWidget);
      expect(find.text('Bronze III'), findsOneWidget);
      expect(find.byType(RankEmblemWidget), findsWidgets);
      expect(find.byType(RankStarsWidget), findsWidgets);
      expect(find.text('ONLINE MULTIPLAYER'), findsOneWidget);
      expect(find.text('UNRANKED'), findsOneWidget);

      // Career Stats
      expect(find.text('CAREER STATISTICS'), findsOneWidget);
      expect(find.text('ALL MODES'), findsOneWidget);
      expect(find.text('SOLO RANKED'), findsOneWidget);
      expect(find.text('CASUAL AI'), findsOneWidget);
      expect(find.text('PASS & PLAY'), findsOneWidget);

      // 4-Stat Box
      expect(find.text('MATCHES'), findsOneWidget);
      expect(find.text('WINS'), findsOneWidget);
      expect(find.text('LOSSES'), findsOneWidget);
      expect(find.text('TIED'), findsOneWidget);
      expect(find.text('WIN RATE'), findsOneWidget);

      // Advanced records
      expect(find.text('RUNS'), findsOneWidget);
      expect(find.text('WICKETS'), findsOneWidget);
      expect(find.text('HIGH SCORE'), findsOneWidget);
      expect(find.text('BEST CHASE'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget);
      expect(find.text('BEST STREAK'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders advanced rank, shields, and custom XP data correctly',
        (tester) async {
      final repo = LocalProgressionRepository();
      // Setup rank: Gold II, 2 stars, peak Platinum I, 5 winStreak, demotion shield
      await repo.saveVsComputerRankState(const VsComputerRankState(
        tier: RankTier.gold,
        division: RankDivision.II,
        stars: 2,
        winStreak: 5,
        peakTier: RankTier.platinum,
        peakDivision: RankDivision.I,
        demotionShieldActive: true,
      ));

      // Add 300 XP -> Level 3 (0..99 lvl 1, 100..249 lvl 2, 250..449 lvl 3)
      await repo.addLocalXp(300);
      await repo.saveLocalDisplayName('MasterBlaster');
      await repo.saveLocalAvatarIndex(3);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Allow async loadProfile to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('LEVEL 3'), findsOneWidget);
      expect(find.text('Gold II'), findsOneWidget);
      expect(find.text('Shield Protected'), findsOneWidget);
      expect(find.text('Streak: 5W'), findsOneWidget);
      expect(find.text('Peak: Platinum I'), findsOneWidget);
      expect(find.text('Daily: 300 / 1500 XP'), findsOneWidget);
    });

    testWidgets('ProfileScreen switches career statistics mode when tapping mode chips',
        (tester) async {
      final repo = LocalProgressionRepository();

      // Save ranked mode stats
      await repo.saveModeStats(
        'vs_computer_ranked',
        const ModeCareerStats(
          matchesPlayed: 25,
          matchesWon: 20,
          matchesLost: 5,
          matchesTied: 0,
          totalRuns: 280,
          totalWickets: 22,
          highestScore: 48,
          bestChase: 36,
          currentStreak: 4,
          longestWinStreak: 9,
        ),
      );

      // Save casual mode stats
      await repo.saveModeStats(
        'casual_vs_computer',
        const ModeCareerStats(
          matchesPlayed: 10,
          matchesWon: 6,
          matchesLost: 4,
          matchesTied: 0,
          totalRuns: 95,
          totalWickets: 8,
          highestScore: 32,
          bestChase: 24,
          currentStreak: 2,
          longestWinStreak: 4,
        ),
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 'ALL MODES' aggregates ranked + casual: 25 + 10 = 35 matches
      expect(find.text('35'), findsOneWidget); // Total Matches
      expect(find.text('26'), findsOneWidget); // Total Wins (20 + 6)
      expect(find.text('9'), findsOneWidget);  // Total Losses (5 + 4)

      // Scroll and Tap SOLO RANKED chip
      await tester.scrollUntilVisible(
        find.text('SOLO RANKED'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('SOLO RANKED'));
      await tester.pump();

      // Verify updated stats for Solo Ranked
      expect(find.text('25'), findsOneWidget); // Matches
      expect(find.text('20'), findsOneWidget); // Wins
      expect(find.text('5'), findsOneWidget);  // Losses
      expect(find.text('80.0%'), findsOneWidget); // Win rate
      expect(find.text('280'), findsOneWidget); // Runs
      expect(find.text('22'), findsOneWidget);  // Wickets
      expect(find.text('48'), findsOneWidget);  // High score
      expect(find.text('36'), findsOneWidget);  // Best chase
      expect(find.text('+4 W'), findsOneWidget); // Streak
      expect(find.text('9 W'), findsOneWidget);  // Best streak

      // Tap CASUAL AI chip
      await tester.tap(find.text('CASUAL AI'));
      await tester.pump();

      // Verify updated stats for Casual AI
      expect(find.text('10'), findsOneWidget); // Matches
      expect(find.text('6'), findsOneWidget);  // Wins
      expect(find.text('4'), findsOneWidget);  // Losses
      expect(find.text('60.0%'), findsOneWidget); // Win rate
      expect(find.text('95'), findsOneWidget);  // Runs
      expect(find.text('8'), findsOneWidget);   // Wickets
      expect(find.text('32'), findsOneWidget);  // High score
      expect(find.text('24'), findsOneWidget);  // Best chase
    });

    testWidgets('ProfileScreen allows updating display name and selecting avatar',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter new name
      final nameField = find.byType(TextField);
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'SuperStriker');
      await tester.pump();

      // Tap SAVE PROFILE button
      final saveBtn = find.text('SAVE PROFILE');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify success snackbar appears
      expect(find.text('Profile updated successfully!'), findsOneWidget);

      // Verify persisted value
      final repo = LocalProgressionRepository();
      final persistedName = await repo.getLocalDisplayName();
      expect(persistedName, equals('SuperStriker'));
    });

    testWidgets('ProfileScreen renders cleanly in responsive desktop widescreen (>= 900px)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both columns must exist without throwing RenderFlex overflows
      expect(find.text('PLAYER PROFILE'), findsOneWidget);
      expect(find.text('COMPETITIVE RANKS'), findsOneWidget);
      expect(find.text('CAREER STATISTICS'), findsOneWidget);
      expect(find.text('SAVE PROFILE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileScreen renders cleanly in compact mobile screen (< 900px)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PLAYER PROFILE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileScreen renders authoritative online ranked stats and separates from offline rank',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeOnlineRepo = FakeOnlineRankedRepoForProfile(
        mockRank: const OnlinePlayerRank(
          userId: 'u-auth-test',
          tier: RankTier.diamond,
          division: RankDivision.II,
          stars: 3,
          mmr: 2180,
          peakTier: RankTier.diamond,
          peakDivision: RankDivision.I,
          winStreak: 4,
          totalRankedMatches: 24,
          totalRankedWins: 18,
          totalRankedLosses: 6,
          demotionShieldActive: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineRankedRepositoryProvider.overrideWithValue(fakeOnlineRepo),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Online Multiplayer card displays authoritative online rank
      expect(find.text('ONLINE MULTIPLAYER'), findsOneWidget);
      expect(find.text('DIAMOND II'), findsOneWidget);
      expect(find.text('2180 MMR'), findsOneWidget);
      expect(find.text('Peak: Diamond I'), findsOneWidget);
      expect(find.text('Streak: 4W'), findsOneWidget);
      expect(find.text('75% Win (18W-6L)'), findsOneWidget);
      expect(find.text('Shield Protected'), findsWidgets);
      expect(find.text('LEADERBOARD'), findsOneWidget);

      // Verify Solo Ladder is completely distinct (default Bronze III)
      expect(find.text('SOLO LADDER'), findsOneWidget);
      expect(find.text('Bronze III'), findsOneWidget);
    });
  });

  group('HistoryScreen Filtering & Empty State Tests', () {
    testWidgets('HistoryScreen displays records and filters by game mode', (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final records = [
        MatchHistoryRecord(
          matchId: 'ranked-match-1',
          player1Name: 'Player 1',
          player2Name: 'GrandMaster AI',
          firstInningsRuns: 24,
          secondInningsRuns: 22,
          winnerName: 'Player 1',
          resultSummary: 'Player 1 won by 2 runs',
          playedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          gameMode: 'VS Computer Ranked',
        ),
        MatchHistoryRecord(
          matchId: 'casual-match-2',
          player1Name: 'Player 1',
          player2Name: 'Hard Computer',
          firstInningsRuns: 18,
          secondInningsRuns: 20,
          winnerName: 'Hard Computer',
          resultSummary: 'Hard Computer won by 2 wickets',
          playedAt: DateTime.now().subtract(const Duration(hours: 1)),
          gameMode: 'VS Computer (Casual)',
        ),
        MatchHistoryRecord(
          matchId: 'passplay-match-3',
          player1Name: 'Alice',
          player2Name: 'Bob',
          firstInningsRuns: 30,
          secondInningsRuns: 25,
          winnerName: 'Alice',
          resultSummary: 'Alice won by 5 runs',
          playedAt: DateTime.now().subtract(const Duration(hours: 3)),
          gameMode: 'Pass & Play',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchHistoryListProvider.overrideWith((ref) => Future.value(records)),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 'ALL' filter shows all 3 records + filter chips
      expect(find.text('VS COMPUTER RANKED'), findsOneWidget);
      expect(find.text('VS COMPUTER (CASUAL)'), findsOneWidget);
      expect(find.text('PASS & PLAY'), findsNWidgets(2)); // Chip + Card badge

      // Filter by 'SOLO RANKED'
      await tester.tap(find.text('SOLO RANKED'));
      await tester.pump();

      expect(find.text('VS COMPUTER RANKED'), findsOneWidget);
      expect(find.text('VS COMPUTER (CASUAL)'), findsNothing);
      expect(find.text('PASS & PLAY'), findsOneWidget); // Chip only

      // Filter by 'CASUAL AI'
      await tester.tap(find.text('CASUAL AI'));
      await tester.pump();

      expect(find.text('VS COMPUTER RANKED'), findsNothing);
      expect(find.text('VS COMPUTER (CASUAL)'), findsOneWidget);
      expect(find.text('PASS & PLAY'), findsOneWidget); // Chip only

      // Filter by 'PASS & PLAY'
      // Tap the filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'PASS & PLAY'));
      await tester.pump();

      expect(find.text('PASS & PLAY'), findsNWidgets(2)); // Chip + Card badge
      expect(find.text('VS COMPUTER RANKED'), findsNothing);

      // Filter by 'ONLINE' (empty state)
      // Drag horizontal chip row left to reveal the 'ONLINE' chip
      await tester.drag(find.byType(ListView).first, const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.widgetWithText(ChoiceChip, 'ONLINE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No matches found under ONLINE mode'), findsOneWidget);
      expect(find.text('No matches played yet'), findsOneWidget);
      expect(find.text('VS COMPUTER RANKED'), findsNothing);
      expect(find.text('VS COMPUTER (CASUAL)'), findsNothing);
    });
  });
}
