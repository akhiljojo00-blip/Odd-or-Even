import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/domain/models/online_player_rank.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_exceptions.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_matchmaking_state.dart';
import 'package:odd_or_even/features/online/presentation/controllers/ranked_matchmaking_controller.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';

class MockRankedRepository extends OnlineRankedRepository {
  bool configured = true;
  String? authenticatedUid = 'user-123';
  OnlinePlayerRank? rank;
  RankedMatchmakingResult joinResult =
      const RankedMatchmakingResult(status: RankedMatchmakingStatus.queued);
  RankedMatchmakingResult pollResult =
      const RankedMatchmakingResult(status: RankedMatchmakingStatus.queued);
  RankedMatchmakingResult cancelResult =
      const RankedMatchmakingResult(status: RankedMatchmakingStatus.cancelled);
  RankedMatch? matchRecord;
  int joinCallCount = 0;
  int pollCallCount = 0;
  int cancelCallCount = 0;
  int getMatchCallCount = 0;
  Exception? throwOnJoin;
  Exception? throwOnPoll;

  MockRankedRepository() : super();

  @override
  bool get isConfigured => configured;

  @override
  String? get currentUserId => authenticatedUid;

  @override
  Future<String?> ensureAuthenticatedUser() async => authenticatedUid;

  @override
  Future<OnlinePlayerRank?> getPlayerRank([String? userId]) async => rank;

  @override
  Future<RankedMatchmakingResult> joinMatchmaking() async {
    joinCallCount++;
    if (throwOnJoin != null) throw throwOnJoin!;
    return joinResult;
  }

  @override
  Future<RankedMatchmakingResult> pollMatchmaking() async {
    pollCallCount++;
    if (throwOnPoll != null) throw throwOnPoll!;
    return pollResult;
  }

  @override
  Future<RankedMatchmakingResult> cancelMatchmaking() async {
    cancelCallCount++;
    return cancelResult;
  }

  @override
  Future<RankedMatch?> getMatch(String matchId) async {
    getMatchCallCount++;
    return matchRecord;
  }
}

void main() {
  late MockRankedRepository mockRepo;
  late RankedMatchmakingNotifier notifier;

  setUp(() {
    mockRepo = MockRankedRepository();
    mockRepo.rank = const OnlinePlayerRank(
      userId: 'user-123',
      tier: RankTier.gold,
      division: RankDivision.II,
      stars: 2,
      mmr: 1350,
      peakTier: RankTier.platinum,
      peakDivision: RankDivision.I,
    );
    notifier = RankedMatchmakingNotifier(mockRepo);
  });

  tearDown(() {
    notifier.dispose();
  });

  group('RankedMatchmakingNotifier - Unit Tests', () {
    test('Initial state is idle with 0 elapsed seconds and no errors', () {
      expect(notifier.state.status, MatchmakingStatus.idle);
      expect(notifier.state.elapsedSeconds, 0);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.matchId, isNull);
      expect(notifier.hasNavigated, isFalse);
    });

    test('Successful queue join transitions to searching and fetches player rank', () async {
      await notifier.initializeAndJoin();

      expect(notifier.state.status, MatchmakingStatus.searching);
      expect(notifier.state.playerRank, isNotNull);
      expect(notifier.state.playerRank!.tier, RankTier.gold);
      expect(notifier.state.playerRank!.division, RankDivision.II);
      expect(notifier.state.playerRank!.fullRankLabel, 'Gold II');
      expect(mockRepo.joinCallCount, 1);
    });

    test('Immediate match found transitions directly to matched and validates participant', () async {
      mockRepo.joinResult = const RankedMatchmakingResult(
        status: RankedMatchmakingStatus.matched,
        matchId: 'match-xyz',
      );
      mockRepo.matchRecord = const RankedMatch(
        id: 'match-xyz',
        phase: RankedMatchPhase.tossInput,
        player1Id: 'user-123',
        player2Id: 'user-456',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
      );

      await notifier.initializeAndJoin();

      expect(notifier.state.status, MatchmakingStatus.matched);
      expect(notifier.state.matchId, 'match-xyz');
      expect(notifier.state.matchedMatch, isNotNull);
      expect(notifier.state.matchedMatch!.id, 'match-xyz');
      expect(mockRepo.getMatchCallCount, 1);
    });

    test('Active match recovery transitions to activeMatchRecovery and loads match', () async {
      mockRepo.joinResult = const RankedMatchmakingResult(
        status: RankedMatchmakingStatus.activeMatchExists,
        matchId: 'active-match-888',
      );
      mockRepo.matchRecord = const RankedMatch(
        id: 'active-match-888',
        phase: RankedMatchPhase.firstInnings,
        player1Id: 'user-123',
        player2Id: 'user-789',
        player1Parity: PlayerParity.even,
        player2Parity: PlayerParity.odd,
      );

      await notifier.initializeAndJoin();

      expect(notifier.state.status, MatchmakingStatus.activeMatchRecovery);
      expect(notifier.state.matchId, 'active-match-888');
      expect(notifier.state.matchedMatch, isNotNull);
      expect(notifier.state.matchedMatch!.phase, RankedMatchPhase.firstInnings);
    });

    test('Rejects match pairing if caller is not an authoritative participant', () async {
      mockRepo.joinResult = const RankedMatchmakingResult(
        status: RankedMatchmakingStatus.matched,
        matchId: 'stranger-match',
      );
      mockRepo.matchRecord = const RankedMatch(
        id: 'stranger-match',
        phase: RankedMatchPhase.tossInput,
        player1Id: 'other-player-1',
        player2Id: 'other-player-2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
      );

      await notifier.initializeAndJoin();

      expect(notifier.state.status, MatchmakingStatus.error);
      expect(notifier.state.errorCode, RankedErrorCode.notParticipant);
      expect(notifier.state.errorMessage, contains('not a registered participant'));
    });

    test('Duplicate join prevention: multiple calls do not duplicate join RPC', () async {
      await notifier.initializeAndJoin();
      // Second call while searching should be ignored
      await notifier.initializeAndJoin();

      expect(mockRepo.joinCallCount, 1);
    });

    test('Cancellation stops timers, calls cancel RPC, and updates status to cancelled', () async {
      await notifier.initializeAndJoin();
      expect(notifier.state.isSearching, isTrue);

      final success = await notifier.cancelMatchmaking();

      expect(success, isTrue);
      expect(notifier.state.status, MatchmakingStatus.cancelled);
      expect(mockRepo.cancelCallCount, 1);
    });

    test('Handles unconfigured client gracefully without crashing', () async {
      mockRepo.configured = false;
      mockRepo.authenticatedUid = null;

      await notifier.initializeAndJoin();

      expect(notifier.state.status, MatchmakingStatus.error);
      expect(notifier.state.errorCode, RankedErrorCode.clientNotConfigured);
      expect(notifier.state.errorMessage, contains('offline or unconfigured'));
      expect(mockRepo.joinCallCount, 0);
    });

    test('Handles authentication failure gracefully', () async {
      mockRepo.authenticatedUid = null;

      await notifier.initializeAndJoin();

      expect(notifier.state.status, MatchmakingStatus.error);
      expect(notifier.state.errorCode, RankedErrorCode.notAuthenticated);
      expect(notifier.state.errorMessage, contains('Authentication failed'));
      expect(mockRepo.joinCallCount, 0);
    });

    test('Handles join RPC exception and maps typed error', () async {
      mockRepo.throwOnJoin = const RankedException(
        code: RankedErrorCode.networkError,
        message: 'Socket connection reset',
      );

      await notifier.initializeAndJoin();

      expect(notifier.state.status, MatchmakingStatus.error);
      expect(notifier.state.errorCode, RankedErrorCode.networkError);
      expect(notifier.state.errorMessage, contains('Network connection failed'));
    });

    test('Poll failure tolerance: single poll error does not kick player from queue', () async {
      await notifier.initializeAndJoin();
      expect(notifier.state.isSearching, isTrue);

      // Simulate a single transient poll failure
      mockRepo.throwOnPoll = const RankedException(
        code: RankedErrorCode.networkError,
        message: 'Temporary packet drop',
      );

      // Trigger app resume which calls pollQueue
      notifier.handleAppResume();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Player should still be searching after 1 failure
      expect(notifier.state.isSearching, isTrue);
      expect(notifier.state.isError, isFalse);
    });

    test('Poll failure limit: 3 consecutive poll failures transitions to error', () async {
      await notifier.initializeAndJoin();
      expect(notifier.state.isSearching, isTrue);

      mockRepo.throwOnPoll = const RankedException(
        code: RankedErrorCode.networkError,
        message: 'Repeated timeout',
      );

      // Trigger 3 consecutive poll errors
      notifier.handleAppResume();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.handleAppResume();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.handleAppResume();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.status, MatchmakingStatus.error);
      expect(notifier.state.errorCode, RankedErrorCode.networkError);
    });

    test('Server-dropped queue (not_queued status) transitions to error', () async {
      await notifier.initializeAndJoin();
      expect(notifier.state.isSearching, isTrue);

      mockRepo.pollResult = const RankedMatchmakingResult(
        status: RankedMatchmakingStatus.notQueued,
      );

      notifier.handleAppResume();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.status, MatchmakingStatus.error);
      expect(notifier.state.errorMessage, contains('Queue session expired'));
    });

    test('Polling match discovery transitions from searching to matched', () async {
      await notifier.initializeAndJoin();
      expect(notifier.state.isSearching, isTrue);

      mockRepo.pollResult = const RankedMatchmakingResult(
        status: RankedMatchmakingStatus.matched,
        matchId: 'match-found-via-poll',
      );
      mockRepo.matchRecord = const RankedMatch(
        id: 'match-found-via-poll',
        phase: RankedMatchPhase.tossInput,
        player1Id: 'user-123',
        player2Id: 'user-999',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
      );

      notifier.handleAppResume();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.status, MatchmakingStatus.matched);
      expect(notifier.state.matchId, 'match-found-via-poll');
    });

    test('markNavigated prevents duplicate navigation executions', () {
      expect(notifier.hasNavigated, isFalse);
      notifier.markNavigated();
      expect(notifier.hasNavigated, isTrue);
      expect(notifier.state.isNavigating, isTrue);
    });

    test('reset clears timers, errors, and restores idle state', () async {
      await notifier.initializeAndJoin();
      notifier.markNavigated();

      notifier.reset();

      expect(notifier.state.status, MatchmakingStatus.idle);
      expect(notifier.hasNavigated, isFalse);
      expect(notifier.state.isNavigating, isFalse);
      expect(notifier.state.matchId, isNull);
    });
  });
}
