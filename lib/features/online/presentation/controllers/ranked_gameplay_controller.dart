import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/online_ranked_repository.dart';
import '../../data/ranked_realtime_manager.dart';
import '../../domain/models/online_player_rank.dart';
import '../../domain/models/ranked_ball_event.dart';
import '../../domain/models/ranked_exceptions.dart';
import '../../domain/models/ranked_gameplay_state.dart';
import '../../domain/models/ranked_match.dart';
import '../../domain/models/ranked_match_settlement.dart';

/// Controller managing live server-authoritative Online Ranked gameplay,
/// turn synchronization, local countdown presentation, disconnect grace, and match settlement.
class RankedGameplayNotifier extends StateNotifier<RankedGameplayState>
    with WidgetsBindingObserver {
  final OnlineRankedRepository _repo;
  final RankedRealtimeManager _realtimeManager;
  final String matchId;

  Timer? _localTickTimer;
  Timer? _heartbeatTimer;
  bool _isDisposed = false;
  int _consecutiveSyncErrors = 0;

  RankedGameplayNotifier({
    required OnlineRankedRepository repository,
    required RankedRealtimeManager manager,
    required this.matchId,
  })  : _repo = repository,
        _realtimeManager = manager,
        super(RankedGameplayState.initial()) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  // =========================================================================
  // INITIALIZATION & LIFECYCLE
  // =========================================================================

  Future<void> _init() async {
    try {
      final uid = _repo.currentUserId ?? await _repo.ensureAuthenticatedUser();
      if (uid == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to authenticate user session for ranked play.',
        );
        return;
      }
      state = state.copyWith(currentUserId: uid);

      // 1. Fetch initial match snapshot
      final match = await _repo.getMatch(matchId);
      if (match == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Ranked match not found or unavailable.',
        );
        return;
      }

      // 2. Authorize caller participation
      if (!match.isParticipant(uid)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Access denied: You are not a participant in this ranked match.',
        );
        return;
      }

      // 3. Fetch player ranks and profiles
      final opponentId = match.opponentId(uid);
      OnlinePlayerRank? myRank;
      OnlinePlayerRank? oppRank;
      Map<String, dynamic>? myProf;
      Map<String, dynamic>? oppProf;

      try {
        myRank = await _repo.getPlayerRank(uid);
        myProf = await _repo.getPlayerProfile(uid);
        if (opponentId != null) {
          oppRank = await _repo.getPlayerRank(opponentId);
          oppProf = await _repo.getPlayerProfile(opponentId);
        }
      } catch (e) {
        debugPrint('RankedGameplayNotifier: Error fetching profiles/ranks: $e');
      }

      // 4. Fetch initial ball events
      List<RankedBallEvent> ballEvents = [];
      try {
        ballEvents = await _repo.getBallEvents(matchId);
      } catch (e) {
        debugPrint('RankedGameplayNotifier: Error fetching initial ball events: $e');
      }

      // 5. Check if match is already settled
      RankedMatchSettlement? settlement;
      if (match.isCompleted) {
        try {
          settlement = await _repo.getMatchSettlement(matchId);
        } catch (e) {
          debugPrint('RankedGameplayNotifier: Error fetching initial settlement: $e');
        }
      }

      state = state.copyWith(
        match: match,
        myRank: myRank,
        opponentRank: oppRank,
        myProfile: myProf,
        opponentProfile: oppProf,
        ballEvents: ballEvents,
        settlement: settlement,
        initialRankSnapshot: myRank,
        isLoading: false,
      );

      // 6. Connect Realtime subscription with fallback
      await _setupRealtimeSubscription();

      // 7. Start timers (countdown presentation tick and periodic heartbeat)
      _startTickTimer();
      _startHeartbeatTimer();
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Initialization exception: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to initialize ranked match: $e',
        );
      }
    }
  }

  Future<void> _setupRealtimeSubscription() async {
    await _realtimeManager.subscribe(
      matchId: matchId,
      onMatchUpdated: (updatedMatch) {
        _handleMatchUpdated(updatedMatch);
      },
      onBallEventsUpdated: (events) {
        _handleBallEventsUpdated(events);
      },
      onStatusChanged: (status) {
        if (!_isDisposed) {
          state = state.copyWith(realtimeStatus: status);
        }
      },
      onError: (error) {
        debugPrint('RankedGameplayNotifier: Realtime error: $error');
      },
      enablePollingFallback: true,
      pollingInterval: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.resumed) {
      debugPrint('RankedGameplayNotifier: App resumed. Reconnecting to match $matchId...');
      _handleAppResume();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('RankedGameplayNotifier: App paused. Sending heartbeat...');
      _sendHeartbeat();
    }
  }

  Future<void> _handleAppResume() async {
    try {
      if (state.match != null && !state.match!.isCompleted) {
        await _repo.reconnect(matchId);
      }
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Error during resume reconnect: $e');
    }
    await resyncAuthoritativeState();
  }

  // =========================================================================
  // TIMERS & LOCAL SYNCHRONIZATION
  // =========================================================================

  void _startTickTimer() {
    _localTickTimer?.cancel();
    _localTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) return;
      _onTick();
    });
  }

  void _onTick() {
    final match = state.match;
    if (match == null || match.isCompleted) return;

    // 1. Calculate turn deadline remaining seconds
    int remainingSeconds = 20;
    if (match.turnDeadlineAt != null) {
      final diff = match.turnDeadlineAt!.difference(DateTime.now()).inSeconds;
      remainingSeconds = max(0, diff);
    }

    // 2. Calculate opponent disconnect grace
    final uid = state.currentUserId;
    bool oppDisconnected = false;
    int oppGraceSeconds = 30;

    if (uid != null) {
      oppDisconnected = match.isOpponentDisconnected(uid);
      final graceExpiresAt = match.opponentGraceExpiresAt(uid);
      if (oppDisconnected && graceExpiresAt != null) {
        oppGraceSeconds = max(0, graceExpiresAt.difference(DateTime.now()).inSeconds);
      } else {
        oppGraceSeconds = match.opponentGraceRemaining(uid);
      }
    }

    state = state.copyWith(
      remainingTurnSeconds: remainingSeconds,
      isOpponentDisconnected: oppDisconnected,
      opponentGraceRemainingSeconds: oppGraceSeconds,
    );
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_isDisposed) return;
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    if (state.match == null || state.match!.isCompleted) return;
    try {
      await _repo.sendHeartbeat(matchId);
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Heartbeat error: $e');
    }
  }

  // =========================================================================
  // AUTHORITATIVE STATE SYNCHRONIZATION
  // =========================================================================

  /// Authoritatively refreshes match state, ball events, and settlement from PostgreSQL.
  Future<void> resyncAuthoritativeState() async {
    if (_isDisposed) return;
    try {
      final updatedMatch = await _repo.getMatch(matchId);
      final events = await _repo.getBallEvents(matchId);

      if (updatedMatch != null) {
        _handleMatchUpdated(updatedMatch);
      }
      if (events.isNotEmpty) {
        _handleBallEventsUpdated(events);
      }
      _consecutiveSyncErrors = 0;
    } catch (e) {
      _consecutiveSyncErrors++;
      debugPrint('RankedGameplayNotifier: Sync error (streak: $_consecutiveSyncErrors): $e');
    }
  }

  void _handleMatchUpdated(RankedMatch newMatch) {
    if (_isDisposed) return;

    final oldMatch = state.match;

    // Detect turn advancement, phase shift, or innings change
    final phaseChanged = oldMatch != null && oldMatch.phase != newMatch.phase;
    final ballAdvanced = oldMatch != null && oldMatch.legalBallsBowled != newMatch.legalBallsBowled;
    final inningsChanged = oldMatch != null && oldMatch.currentInningsNo != newMatch.currentInningsNo;

    bool resetSubmissionLock = false;
    if (phaseChanged || ballAdvanced || inningsChanged) {
      resetSubmissionLock = true;
    }

    // Check if match completed -> trigger settlement fetch
    if (newMatch.isCompleted && state.settlement == null) {
      _fetchSettlement();
    }

    state = state.copyWith(
      match: newMatch,
      hasSubmittedThisTurn: resetSubmissionLock ? false : state.hasSubmittedThisTurn,
      stagedChoice: resetSubmissionLock ? null : state.stagedChoice,
      isSubmitting: resetSubmissionLock ? false : state.isSubmitting,
      isSelectingRole: resetSubmissionLock ? false : state.isSelectingRole,
      isStartingSecondInnings: resetSubmissionLock ? false : state.isStartingSecondInnings,
      clearStagedChoice: resetSubmissionLock,
    );
  }

  void _handleBallEventsUpdated(List<RankedBallEvent> events) {
    if (_isDisposed) return;

    final previousCount = state.ballEvents.length;
    if (events.length > previousCount) {
      // New delivery confirmed by server!
      final latest = events.last;
      state = state.copyWith(
        ballEvents: events,
        latestBallEvent: latest,
        showBallOutcomeOverlay: true,
        hasSubmittedThisTurn: false,
        isSubmitting: false,
        clearStagedChoice: true,
      );
    } else {
      state = state.copyWith(ballEvents: events);
    }
  }

  Future<void> _fetchSettlement() async {
    try {
      final settlement = await _repo.getMatchSettlement(matchId);
      final updatedRank = state.currentUserId != null
          ? await _repo.getPlayerRank(state.currentUserId!)
          : null;

      if (!_isDisposed) {
        state = state.copyWith(
          settlement: settlement,
          myRank: updatedRank ?? state.myRank,
        );
      }
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Error fetching settlement: $e');
    }
  }

  // =========================================================================
  // GAMEPLAY ACTIONS (ZERO CLIENT TRUST)
  // =========================================================================

  /// Submits player's secret number choice (strictly 1 to 6).
  /// Enforces idempotency and never logs secret choices.
  Future<void> submitChoice(int choice) async {
    if (choice < 1 || choice > 6) return;
    if (state.isSubmitting || state.hasSubmittedThisTurn) return;

    final match = state.match;
    if (match == null || match.isCompleted) return;

    final turnType = (match.phase == RankedMatchPhase.tossInput) ? 'toss' : 'ball';

    state = state.copyWith(
      isSubmitting: true,
      hasSubmittedThisTurn: true,
      stagedChoice: choice,
      clearErrorMessage: true,
    );

    try {
      final res = await _repo.submitChoice(
        matchId: matchId,
        turnType: turnType,
        choice: choice,
      );

      if (!_isDisposed) {
        state = state.copyWith(isSubmitting: false);

        // If turn resolved immediately (both submitted), resync server state
        if (res['status'] != 'waiting_for_opponent') {
          await resyncAuthoritativeState();
        }
      }
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Exception submitting choice');
      if (!_isDisposed) {
        // Reconcile authoritative state before unlocking to guard against network-dropped responses
        await resyncAuthoritativeState();

        // If turn did not advance, unlock client submission lock and display error
        final currentMatch = state.match;
        final turnDidAdvance = (turnType == 'toss' && currentMatch?.phase != RankedMatchPhase.tossInput) ||
            (turnType == 'ball' && currentMatch?.legalBallsBowled != match.legalBallsBowled);

        if (!turnDidAdvance) {
          state = state.copyWith(
            isSubmitting: false,
            hasSubmittedThisTurn: false,
            errorMessage: e is RankedException ? e.message : 'Failed to submit choice. Please try again.',
          );
        } else {
          state = state.copyWith(isSubmitting: false);
        }
      }
    }
  }

  /// Toss winner selects batting or bowling role ('bat' or 'bowl').
  Future<void> selectRole(String role) async {
    final match = state.match;
    if (match == null || match.phase != RankedMatchPhase.roleSelection) return;
    if (!state.isTossWinner || state.isSelectingRole) return;

    state = state.copyWith(isSelectingRole: true, clearErrorMessage: true);

    try {
      await _repo.selectRole(matchId: matchId, role: role);
      await resyncAuthoritativeState();
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Error selecting role: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isSelectingRole: false,
          errorMessage: e is RankedException ? e.message : 'Failed to select role.',
        );
      }
    }
  }

  /// Transitions match from innings break to second innings chase.
  Future<void> startSecondInnings() async {
    final match = state.match;
    if (match == null || match.phase != RankedMatchPhase.inningsBreak) return;
    if (state.isStartingSecondInnings) return;

    state = state.copyWith(isStartingSecondInnings: true, clearErrorMessage: true);

    try {
      await _repo.startSecondInnings(matchId);
      await resyncAuthoritativeState();
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Error starting second innings: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isStartingSecondInnings: false,
          errorMessage: e is RankedException ? e.message : 'Failed to start 2nd innings.',
        );
      }
    }
  }

  /// Claims timeout forfeit win when opponent grace window or turn deadline expires.
  Future<void> claimTimeoutForfeit() async {
    if (state.isClaimingTimeout || state.isCompleted) return;

    state = state.copyWith(isClaimingTimeout: true, clearErrorMessage: true);

    try {
      await _repo.claimTimeoutForfeit(matchId);
      await resyncAuthoritativeState();
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Error claiming timeout forfeit: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isClaimingTimeout: false,
          errorMessage: e is RankedException ? e.message : 'Unable to claim timeout forfeit.',
        );
      }
    }
  }

  /// Concedes / forfeits the active match.
  Future<void> surrender() async {
    if (state.isSurrendering || state.isCompleted) return;

    state = state.copyWith(isSurrendering: true, clearErrorMessage: true);

    try {
      await _repo.surrender(matchId);
      await resyncAuthoritativeState();
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Error surrendering match: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isSurrendering: false,
          errorMessage: e is RankedException ? e.message : 'Unable to surrender match.',
        );
      }
    }
  }

  /// Reports opponent disconnect if their heartbeats are stale.
  Future<void> reportOpponentDisconnect() async {
    if (state.isCompleted || state.isOpponentDisconnected) return;
    try {
      await _repo.reportDisconnect(matchId);
      await resyncAuthoritativeState();
    } catch (e) {
      debugPrint('RankedGameplayNotifier: Error reporting opponent disconnect: $e');
    }
  }

  /// Dismisses ball outcome animation/dialog.
  void dismissBallOutcomeOverlay() {
    if (!_isDisposed) {
      state = state.copyWith(showBallOutcomeOverlay: false);
    }
  }

  /// Clears transient error banner.
  void clearErrorMessage() {
    if (!_isDisposed) {
      state = state.copyWith(clearErrorMessage: true);
    }
  }

  // =========================================================================
  // DISPOSAL
  // =========================================================================

  @override
  void dispose() {
    _isDisposed = true;
    _localTickTimer?.cancel();
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _realtimeManager.dispose();
    super.dispose();
  }
}

/// Provider family for live Online Ranked gameplay controller scoped per [matchId].
final rankedGameplayProvider = StateNotifierProvider.autoDispose
    .family<RankedGameplayNotifier, RankedGameplayState, String>((ref, matchId) {
  final repo = ref.watch(onlineRankedRepositoryProvider);
  final realtimeManager = RankedRealtimeManager(repo);

  return RankedGameplayNotifier(
    repository: repo,
    manager: realtimeManager,
    matchId: matchId,
  );
});
