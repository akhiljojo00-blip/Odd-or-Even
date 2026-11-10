import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:odd_or_even/features/home/presentation/screens/home_screen.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/domain/models/online_player_rank.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_matchmaking_state.dart';
import 'package:odd_or_even/features/online/presentation/screens/ranked_match_lobby_screen.dart';
import 'package:odd_or_even/features/online/presentation/screens/ranked_matchmaking_screen.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_emblem_widget.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_stars_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRankedRepositoryForWidgets extends OnlineRankedRepository {
  bool configured = true;
  String? userId = 'u-widget-test';
  OnlinePlayerRank? rank = const OnlinePlayerRank(
    userId: 'u-widget-test',
    tier: RankTier.silver,
    division: RankDivision.I,
    stars: 3,
    mmr: 1220,
    peakTier: RankTier.silver,
    peakDivision: RankDivision.I,
  );
  RankedMatchmakingResult joinResult =
      const RankedMatchmakingResult(status: RankedMatchmakingStatus.queued);
  bool cancelCalled = false;

  FakeRankedRepositoryForWidgets() : super();

  @override
  bool get isConfigured => configured;

  @override
  String? get currentUserId => userId;

  @override
  Future<String?> ensureAuthenticatedUser() async => userId;

  @override
  Future<OnlinePlayerRank?> getPlayerRank([String? uid]) async => rank;

  @override
  Future<RankedMatchmakingResult> joinMatchmaking() async => joinResult;

  @override
  Future<RankedMatchmakingResult> cancelMatchmaking() async {
    cancelCalled = true;
    return const RankedMatchmakingResult(status: RankedMatchmakingStatus.cancelled);
  }

  @override
  Future<RankedMatch?> getMatch(String matchId) async {
    return RankedMatch(
      id: matchId,
      phase: RankedMatchPhase.tossInput,
      player1Id: 'u-widget-test',
      player2Id: 'opp-123',
      player1Parity: PlayerParity.odd,
      player2Parity: PlayerParity.even,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RankedMatchmakingScreen & Navigation Widget Tests', () {
    testWidgets('HomeScreen renders ONLINE RANKED card and navigates to ranked matchmaking',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRankedRepositoryForWidgets();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/ranked-matchmaking', builder: (context, state) => const RankedMatchmakingScreen()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineRankedRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the new ONLINE RANKED card exists alongside existing modes
      expect(find.text('ONLINE RANKED'), findsOneWidget);
      expect(find.text('ONLINE LADDER'), findsOneWidget);
      expect(find.text('PASS & PLAY'), findsOneWidget);
      expect(find.text('VS COMPUTER RANKED'), findsOneWidget);
      expect(find.text('QUICK MATCH'), findsOneWidget);

      // Tap ONLINE RANKED card
      await tester.ensureVisible(find.text('ONLINE RANKED'));
      await tester.tap(find.text('ONLINE RANKED'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should navigate to RankedMatchmakingScreen
      expect(find.byType(RankedMatchmakingScreen), findsOneWidget);
      expect(find.text('CANCEL SEARCH'), findsOneWidget);
    });

    testWidgets('RankedMatchmakingScreen renders player rank, timer, and cancel action',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRankedRepositoryForWidgets();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineRankedRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: RankedMatchmakingScreen(),
          ),
        ),
      );

      // Pump initial frame & post frame callback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // App bar & branding
      expect(find.text('ONLINE RANKED'), findsOneWidget);

      // Player rank card
      expect(find.text('Silver I'), findsOneWidget);
      expect(find.text('MMR: 1220 • Server Authenticated'), findsOneWidget);
      expect(find.byType(RankEmblemWidget), findsOneWidget);
      expect(find.byType(RankStarsWidget), findsOneWidget);

      // Searching status & timer
      expect(find.text('SEARCHING FOR OPPONENT...'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('STRICT MMR BAND (±200) • 2 OVERS • 1..6'), findsOneWidget);

      // Cancel button
      expect(find.text('CANCEL SEARCH'), findsOneWidget);
    });

    testWidgets('Tapping CANCEL SEARCH invokes repository cancellation and exits',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRankedRepositoryForWidgets();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineRankedRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: RankedMatchmakingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cancelButton = find.text('CANCEL SEARCH');
      expect(cancelButton, findsOneWidget);

      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeRepo.cancelCalled, isTrue);
    });

    testWidgets('Renders error view with Retry and Back buttons when matchmaking fails',
        (tester) async {
      final fakeRepo = FakeRankedRepositoryForWidgets();
      fakeRepo.configured = false;
      fakeRepo.userId = null; // Unconfigured & unauthenticated

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineRankedRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: RankedMatchmakingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Matchmaking Error'), findsOneWidget);
      expect(find.text('Retry Search'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.textContaining('offline or unconfigured'), findsOneWidget);
    });

    testWidgets('Renders match found view and triggers automatic route transition',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeRankedRepositoryForWidgets();
      fakeRepo.joinResult = const RankedMatchmakingResult(
        status: RankedMatchmakingStatus.matched,
        matchId: 'match-found-123',
      );

      final router = GoRouter(
        initialLocation: '/ranked-matchmaking',
        routes: [
          GoRoute(
            path: '/ranked-matchmaking',
            builder: (context, state) => const RankedMatchmakingScreen(),
          ),
          GoRoute(
            path: '/ranked-play/:id',
            builder: (context, state) => RankedMatchLobbyScreen(
              matchId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineRankedRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show match found
      expect(find.text('OPPONENT FOUND!'), findsOneWidget);

      // Wait for the route transition delay (600ms)
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));

      // Should reach RankedMatchLobbyScreen at /ranked-play/match-found-123
      expect(find.text('MATCH FOUND'), findsOneWidget);
      expect(find.text('Ranked Duel Ready'), findsOneWidget);
      expect(find.text('SERVER AUTHORITATIVE PAIRING'), findsOneWidget);
    });
  });
}
