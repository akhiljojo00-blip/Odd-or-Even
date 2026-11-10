import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/data/ranked_realtime_manager.dart';
import 'package:odd_or_even/features/online/domain/models/online_player_rank.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_ball_event.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match_settlement.dart';
import 'package:odd_or_even/features/online/presentation/controllers/ranked_gameplay_controller.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';

class MockRankedGameplayRepository extends OnlineRankedRepository {
  String? authenticatedUid = 'user-p1';
  RankedMatch? matchRecord;
  OnlinePlayerRank? p1Rank;
  OnlinePlayerRank? p2Rank;
  Map<String, dynamic>? p1Profile = {'id': 'user-p1', 'display_name': 'Player 1', 'avatar_index': 0};
  Map<String, dynamic>? p2Profile = {'id': 'user-p2', 'display_name': 'Player 2', 'avatar_index': 1};
  List<RankedBallEvent> ballEvents = [];
  RankedMatchSettlement? settlementRecord;

  int submitChoiceCount = 0;
  int selectRoleCount = 0;
  int startSecondInningsCount = 0;
  int claimTimeoutCount = 0;
  int surrenderCount = 0;
  int sendHeartbeatCount = 0;
  int reconnectCount = 0;
  int reportDisconnectCount = 0;

  Map<String, dynamic> submitChoiceResponse = {'status': 'waiting_for_opponent'};
  Map<String, dynamic> selectRoleResponse = {'status': 'role_selected'};
  Map<String, dynamic> startSecondInningsResponse = {'status': 'second_innings_started'};
  Map<String, dynamic> claimTimeoutResponse = {'status': 'forfeit_claimed'};
  Map<String, dynamic> surrenderResponse = {'status': 'surrendered'};

  Exception? throwOnSubmit;
  Exception? throwOnSelectRole;

  MockRankedGameplayRepository() : super();

  @override
  String? get currentUserId => authenticatedUid;

  @override
  Future<String?> ensureAuthenticatedUser() async => authenticatedUid;

  @override
  Future<RankedMatch?> getMatch(String matchId) async => matchRecord;

  @override
  Future<OnlinePlayerRank?> getPlayerRank([String? userId]) async {
    if (userId == 'user-p1' || userId == null) return p1Rank;
    if (userId == 'user-p2') return p2Rank;
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getPlayerProfile(String userId) async {
    if (userId == 'user-p1') return p1Profile;
    if (userId == 'user-p2') return p2Profile;
    return null;
  }

  @override
  Future<List<RankedBallEvent>> getBallEvents(String matchId) async => ballEvents;

  @override
  Future<RankedMatchSettlement?> getMatchSettlement(String matchId) async => settlementRecord;

  @override
  Future<Map<String, dynamic>> submitChoice({
    required String matchId,
    required String turnType,
    required int choice,
  }) async {
    submitChoiceCount++;
    if (throwOnSubmit != null) throw throwOnSubmit!;
    return submitChoiceResponse;
  }

  @override
  Future<Map<String, dynamic>> selectRole({
    required String matchId,
    required String role,
  }) async {
    selectRoleCount++;
    if (throwOnSelectRole != null) throw throwOnSelectRole!;
    return selectRoleResponse;
  }

  @override
  Future<Map<String, dynamic>> startSecondInnings(String matchId) async {
    startSecondInningsCount++;
    return startSecondInningsResponse;
  }

  @override
  Future<Map<String, dynamic>> claimTimeoutForfeit(String matchId) async {
    claimTimeoutCount++;
    return claimTimeoutResponse;
  }

  @override
  Future<Map<String, dynamic>> surrender(String matchId) async {
    surrenderCount++;
    return surrenderResponse;
  }

  @override
  Future<Map<String, dynamic>> sendHeartbeat(String matchId) async {
    sendHeartbeatCount++;
    return {'status': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> reconnect(String matchId) async {
    reconnectCount++;
    return {'status': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> reportDisconnect(String matchId) async {
    reportDisconnectCount++;
    return {'status': 'grace_started'};
  }
}

class MockRankedRealtimeManager extends RankedRealtimeManager {
  bool subscribeCalled = false;
  String? subscribedMatchId;

  MockRankedRealtimeManager(super.repository);

  @override
  Future<void> subscribe({
    required String matchId,
    void Function(RankedMatch match)? onMatchUpdated,
    void Function(List<RankedBallEvent> events)? onBallEventsUpdated,
    void Function(RealtimeSyncStatus status)? onStatusChanged,
    void Function(Object error)? onError,
    bool enablePollingFallback = true,
    Duration pollingInterval = const Duration(seconds: 4),
  }) async {
    subscribeCalled = true;
    subscribedMatchId = matchId;
    this.onMatchUpdated = onMatchUpdated;
    this.onBallEventsUpdated = onBallEventsUpdated;
    this.onStatusChanged = onStatusChanged;
    this.onError = onError;
    onStatusChanged?.call(RealtimeSyncStatus.subscribed);
  }

  @override
  Future<void> unsubscribe() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRankedGameplayRepository mockRepo;
  late MockRankedRealtimeManager mockRealtime;
  late RankedMatch sampleTossMatch;
  late RankedMatch sampleInningsMatch;

  setUp(() {
    mockRepo = MockRankedGameplayRepository();
    mockRealtime = MockRankedRealtimeManager(mockRepo);

    mockRepo.p1Rank = const OnlinePlayerRank(
      userId: 'user-p1',
      tier: RankTier.gold,
      division: RankDivision.II,
      stars: 3,
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

    sampleTossMatch = const RankedMatch(
      id: 'match-100',
      phase: RankedMatchPhase.tossInput,
      player1Id: 'user-p1',
      player2Id: 'user-p2',
      player1Parity: PlayerParity.odd,
      player2Parity: PlayerParity.even,
    );

    sampleInningsMatch = const RankedMatch(
      id: 'match-100',
      phase: RankedMatchPhase.firstInnings,
      player1Id: 'user-p1',
      player2Id: 'user-p2',
      player1Parity: PlayerParity.odd,
      player2Parity: PlayerParity.even,
      tossWinnerId: 'user-p1',
      battingFirstId: 'user-p1',
      currentBatterId: 'user-p1',
      currentBowlerId: 'user-p2',
      currentInningsNo: 1,
      currentInningsRuns: 8,
      legalBallsBowled: 2,
    );
  });

  group('RankedGameplayNotifier - Initialization & Authorization', () {
    test('Successfully initializes active match and sets up realtime subscription', () async {
      mockRepo.matchRecord = sampleTossMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );

      // Await async init
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.match?.id, 'match-100');
      expect(notifier.state.currentUserId, 'user-p1');
      expect(notifier.state.isCallerPlayer1, isTrue);
      expect(notifier.state.isParticipant, isTrue);
      expect(notifier.state.myParity, PlayerParity.odd);
      expect(notifier.state.opponentParity, PlayerParity.even);
      expect(notifier.state.myRank?.tier, RankTier.gold);
      expect(notifier.state.opponentRank?.tier, RankTier.silver);
      expect(notifier.state.realtimeStatus, RealtimeSyncStatus.subscribed);
      expect(mockRealtime.subscribeCalled, isTrue);

      notifier.dispose();
    });

    test('Rejects non-participant with access restricted error', () async {
      mockRepo.authenticatedUid = 'intruder-999';
      mockRepo.matchRecord = sampleTossMatch;

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isParticipant, isFalse);
      expect(notifier.state.errorMessage, contains('Access denied'));

      notifier.dispose();
    });
  });

  group('RankedGameplayNotifier - Secret Submission Security', () {
    test('Valid choice 1..6 submits successfully without exposing choice to opponent', () async {
      mockRepo.matchRecord = sampleTossMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.submitChoice(4);

      expect(mockRepo.submitChoiceCount, 1);
      expect(notifier.state.hasSubmittedThisTurn, isTrue);
      expect(notifier.state.stagedChoice, 4);
      expect(notifier.state.isSubmitting, isFalse);

      notifier.dispose();
    });

    test('Rejects invalid numbers outside 1..6 immediately without RPC', () async {
      mockRepo.matchRecord = sampleTossMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.submitChoice(0);
      await notifier.submitChoice(7);

      expect(mockRepo.submitChoiceCount, 0);
      expect(notifier.state.hasSubmittedThisTurn, isFalse);

      notifier.dispose();
    });

    test('Prevents duplicate submissions while already submitted or submitting', () async {
      mockRepo.matchRecord = sampleTossMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.submitChoice(3);
      // Attempt immediate second submit
      await notifier.submitChoice(5);

      expect(mockRepo.submitChoiceCount, 1);
      expect(notifier.state.stagedChoice, 3);

      notifier.dispose();
    });
  });

  group('RankedGameplayNotifier - Turn Advancement & State Sync', () {
    test('Realtime match update unlocks submission lock when ball advances', () async {
      mockRepo.matchRecord = sampleInningsMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.submitChoice(5);
      expect(notifier.state.hasSubmittedThisTurn, isTrue);

      // Server resolves ball and emits match update with legalBallsBowled: 3
      final updatedMatch = RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.firstInnings,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
        currentBatterId: 'user-p1',
        currentBowlerId: 'user-p2',
        currentInningsNo: 1,
        currentInningsRuns: 13,
        legalBallsBowled: 3,
      );

      mockRealtime.onMatchUpdated?.call(updatedMatch);

      expect(notifier.state.match?.legalBallsBowled, 3);
      expect(notifier.state.hasSubmittedThisTurn, isFalse);
      expect(notifier.state.stagedChoice, isNull);

      notifier.dispose();
    });

    test('Realtime delivery event triggers ball outcome overlay and updates history', () async {
      mockRepo.matchRecord = sampleInningsMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      const newBall = RankedBallEvent(
        id: 'b-1',
        matchId: 'match-100',
        inningsNo: 1,
        ballNo: 3,
        batterId: 'user-p1',
        bowlerId: 'user-p2',
        batterNumber: 4,
        bowlerNumber: 2,
        runsScored: 4,
        isWicket: false,
        cumulativeRuns: 12,
      );

      mockRealtime.onBallEventsUpdated?.call([newBall]);

      expect(notifier.state.ballEvents.length, 1);
      expect(notifier.state.latestBallEvent?.runsScored, 4);
      expect(notifier.state.showBallOutcomeOverlay, isTrue);

      notifier.dismissBallOutcomeOverlay();
      expect(notifier.state.showBallOutcomeOverlay, isFalse);

      notifier.dispose();
    });
  });

  group('RankedGameplayNotifier - Role Selection & Innings Transitions', () {
    test('Toss winner selects bat role calling rpc_ranked_select_role', () async {
      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.roleSelection,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
        tossWinnerId: 'user-p1',
      );

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isTossWinner, isTrue);

      await notifier.selectRole('bat');
      expect(mockRepo.selectRoleCount, 1);

      notifier.dispose();
    });

    test('Innings break transition triggers startSecondInnings RPC', () async {
      mockRepo.matchRecord = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.inningsBreak,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
        firstInningsRuns: 24,
        targetRuns: 25,
      );

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.startSecondInnings();
      expect(mockRepo.startSecondInningsCount, 1);

      notifier.dispose();
    });
  });

  group('RankedGameplayNotifier - Disconnect, Timeout & Settlement', () {
    test('Timeout forfeit claim invokes rpc_ranked_claim_timeout_forfeit', () async {
      mockRepo.matchRecord = sampleInningsMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.claimTimeoutForfeit();
      expect(mockRepo.claimTimeoutCount, 1);

      notifier.dispose();
    });

    test('Surrender invokes rpc_ranked_surrender', () async {
      mockRepo.matchRecord = sampleInningsMatch;
      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.surrender();
      expect(mockRepo.surrenderCount, 1);

      notifier.dispose();
    });

    test('Match conclusion fetches authoritative settlement and updated rank', () async {
      mockRepo.settlementRecord = const RankedMatchSettlement(
        matchId: 'match-100',
        winnerId: 'user-p1',
        loserId: 'user-p2',
        p1StarsDelta: 1,
        p2StarsDelta: -1,
        p1MmrDelta: 24,
        p2MmrDelta: -24,
        p1XpAwarded: 150,
        p2XpAwarded: 50,
      );

      final finishedMatch = const RankedMatch(
        id: 'match-100',
        phase: RankedMatchPhase.matchFinished,
        player1Id: 'user-p1',
        player2Id: 'user-p2',
        player1Parity: PlayerParity.odd,
        player2Parity: PlayerParity.even,
        winnerId: 'user-p1',
        resultType: RankedResultType.runs,
      );
      mockRepo.matchRecord = finishedMatch;

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isCompleted, isTrue);
      expect(notifier.state.isWinner, isTrue);
      expect(notifier.state.settlement?.p1StarsDelta, 1);
      expect(notifier.state.settlement?.p1XpAwarded, 150);

      notifier.dispose();
    });

    test('Submission failure resyncs state and unlocks submission on genuine failure', () async {
      mockRepo.matchRecord = sampleTossMatch;
      mockRepo.throwOnSubmit = Exception('Network connection reset');

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.submitChoice(2);

      expect(notifier.state.hasSubmittedThisTurn, isFalse);
      expect(notifier.state.isSubmitting, isFalse);
      expect(notifier.state.errorMessage, isNotNull);

      notifier.dispose();
    });

    test('Player 2 perspective maps parity, opponent ID, and caller properties correctly', () async {
      mockRepo.authenticatedUid = 'user-p2';
      mockRepo.matchRecord = sampleInningsMatch;

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.currentUserId, 'user-p2');
      expect(notifier.state.isCallerPlayer1, isFalse);
      expect(notifier.state.myParity, PlayerParity.even);
      expect(notifier.state.opponentParity, PlayerParity.odd);
      expect(notifier.state.opponentId, 'user-p1');
      expect(notifier.state.isBatting, isFalse);
      expect(notifier.state.isBowling, isTrue);

      notifier.dispose();
    });

    test('App resume triggers rpc_ranked_reconnect and authoritative state resync', () async {
      mockRepo.matchRecord = sampleInningsMatch;

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mockRepo.reconnectCount, 1);

      notifier.dispose();
    });

    test('App pause triggers rpc_ranked_heartbeat before backgrounding', () async {
      mockRepo.matchRecord = sampleInningsMatch;

      final notifier = RankedGameplayNotifier(
        repository: mockRepo,
        manager: mockRealtime,
        matchId: 'match-100',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mockRepo.sendHeartbeatCount, 1);

      notifier.dispose();
    });
  });
}
