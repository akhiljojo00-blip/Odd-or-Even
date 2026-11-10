import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/online_ranked_repository.dart';
import '../../domain/models/online_player_rank.dart';
import '../../domain/models/ranked_exceptions.dart';
import '../../domain/models/ranked_match.dart';
import '../../domain/models/ranked_matchmaking_state.dart';

/// State of the Online Ranked matchmaking process.
enum MatchmakingStatus {
  idle,
  joining,
  searching,
  matched,
  activeMatchRecovery,
  cancelling,
  cancelled,
  error,
}

/// UI State for the Online Ranked matchmaking screen.
class RankedMatchmakingUiState {
  final MatchmakingStatus status;
  final String? matchId;
  final RankedMatch? matchedMatch;
  final OnlinePlayerRank? playerRank;
  final int elapsedSeconds;
  final String? errorMessage;
  final RankedErrorCode? errorCode;
  final bool isNavigating;

  const RankedMatchmakingUiState({
    this.status = MatchmakingStatus.idle,
    this.matchId,
    this.matchedMatch,
    this.playerRank,
    this.elapsedSeconds = 0,
    this.errorMessage,
    this.errorCode,
    this.isNavigating = false,
  });

  bool get isIdle => status == MatchmakingStatus.idle;
  bool get isJoining => status == MatchmakingStatus.joining;
  bool get isSearching => status == MatchmakingStatus.searching;
  bool get isMatched => status == MatchmakingStatus.matched;
  bool get isActiveMatchRecovery => status == MatchmakingStatus.activeMatchRecovery;
  bool get isCancelling => status == MatchmakingStatus.cancelling;
  bool get isCancelled => status == MatchmakingStatus.cancelled;
  bool get isError => status == MatchmakingStatus.error;

  RankedMatchmakingUiState copyWith({
    MatchmakingStatus? status,
    String? matchId,
    RankedMatch? matchedMatch,
    OnlinePlayerRank? playerRank,
    int? elapsedSeconds,
    String? errorMessage,
    RankedErrorCode? errorCode,
    bool? isNavigating,
    bool clearError = false,
    bool clearMatch = false,
  }) {
    return RankedMatchmakingUiState(
      status: status ?? this.status,
      matchId: clearMatch ? null : (matchId ?? this.matchId),
      matchedMatch: clearMatch ? null : (matchedMatch ?? this.matchedMatch),
      playerRank: playerRank ?? this.playerRank,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      isNavigating: isNavigating ?? this.isNavigating,
    );
  }
}

/// Controller managing the Online Ranked matchmaking queue lifecycle.
/// Strictly enforces Zero Client Trust: all matching and pairings are server-authoritative.
class RankedMatchmakingNotifier extends StateNotifier<RankedMatchmakingUiState> {
  final OnlineRankedRepository _repository;

  Timer? _pollTimer;
  Timer? _queueTimer;
  DateTime? _queueJoinedAt;
  bool _isPolling = false;
  bool _isJoining = false;
  bool _isCancelling = false;
  bool _hasNavigated = false;
  int _consecutivePollErrors = 0;
  bool _isDisposed = false;

  RankedMatchmakingNotifier(this._repository)
      : super(const RankedMatchmakingUiState());

  /// Returns whether a match has been found and navigation is in progress.
  bool get hasNavigated => _hasNavigated;

  /// Initializes authentication, fetches the player's online rank, and joins queue.
  Future<void> initializeAndJoin() async {
    if (_isDisposed) return;
    if (_isJoining || state.isSearching || state.isMatched || state.isActiveMatchRecovery) {
      debugPrint('RankedMatchmakingNotifier: Queue join already in progress or searching');
      return;
    }

    _isJoining = true;
    _hasNavigated = false;
    _consecutivePollErrors = 0;

    state = state.copyWith(
      status: MatchmakingStatus.joining,
      clearError: true,
      clearMatch: true,
      isNavigating: false,
    );

    try {
      // 1. Ensure authenticated session
      final uid = await _repository.ensureAuthenticatedUser();
      if (_isDisposed) return;

      if (uid == null && !_repository.isConfigured) {
        state = state.copyWith(
          status: MatchmakingStatus.error,
          errorMessage: 'Online multiplayer is currently offline or unconfigured.',
          errorCode: RankedErrorCode.clientNotConfigured,
        );
        _isJoining = false;
        return;
      }

      if (uid == null) {
        state = state.copyWith(
          status: MatchmakingStatus.error,
          errorMessage: 'Authentication failed. Please check your network connection.',
          errorCode: RankedErrorCode.notAuthenticated,
        );
        _isJoining = false;
        return;
      }

      // 2. Fetch player rank profile for display
      try {
        final rank = await _repository.getPlayerRank(uid);
        if (!_isDisposed && rank != null) {
          state = state.copyWith(playerRank: rank);
        }
      } catch (e) {
        debugPrint('RankedMatchmakingNotifier: Non-fatal error loading player rank: $e');
      }

      // 3. Join authoritative queue via RPC
      final result = await _repository.joinMatchmaking();
      if (_isDisposed) return;

      await _handleMatchmakingResult(result);
    } on RankedException catch (e) {
      if (_isDisposed) return;
      _handleRankedException(e);
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        status: MatchmakingStatus.error,
        errorMessage: 'Failed to join matchmaking: $e',
        errorCode: RankedErrorCode.unknown,
      );
    } finally {
      _isJoining = false;
    }
  }

  /// Processes response from `rpc_join_ranked_matchmaking` or `rpc_poll_ranked_matchmaking`.
  Future<void> _handleMatchmakingResult(RankedMatchmakingResult result) async {
    switch (result.status) {
      case RankedMatchmakingStatus.matched:
        final matchId = result.matchId;
        if (matchId == null || matchId.isEmpty) {
          state = state.copyWith(
            status: MatchmakingStatus.error,
            errorMessage: 'Server reported match found, but returned an invalid match ID.',
            errorCode: RankedErrorCode.unknown,
          );
          return;
        }
        await _onMatchFound(matchId, isExistingActiveMatch: false);
        break;

      case RankedMatchmakingStatus.activeMatchExists:
        final matchId = result.matchId;
        if (matchId == null || matchId.isEmpty) {
          state = state.copyWith(
            status: MatchmakingStatus.error,
            errorMessage: 'Server indicated an active match exists, but match ID was missing.',
            errorCode: RankedErrorCode.unknown,
          );
          return;
        }
        await _onMatchFound(matchId, isExistingActiveMatch: true);
        break;

      case RankedMatchmakingStatus.queued:
        _startSearching();
        break;

      case RankedMatchmakingStatus.cancelled:
        _stopTimers();
        state = state.copyWith(status: MatchmakingStatus.cancelled);
        break;

      case RankedMatchmakingStatus.notQueued:
        _stopTimers();
        state = state.copyWith(
          status: MatchmakingStatus.error,
          errorMessage: 'Queue session expired or removed. Please search again.',
          errorCode: RankedErrorCode.unknown,
        );
        break;

      case RankedMatchmakingStatus.error:
        _stopTimers();
        state = state.copyWith(
          status: MatchmakingStatus.error,
          errorMessage: result.message ?? 'Matchmaking error encountered.',
          errorCode: RankedErrorCode.unknown,
        );
        break;

      case RankedMatchmakingStatus.idle:
        break;
    }
  }

  /// Initiates queue timer and periodic server polling.
  void _startSearching() {
    _stopTimers();
    _queueJoinedAt = DateTime.now();

    state = state.copyWith(
      status: MatchmakingStatus.searching,
      elapsedSeconds: 0,
      clearError: true,
    );

    // Queue elapsed timer (local display synced to start time)
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed || !state.isSearching) return;
      final joinedAt = _queueJoinedAt;
      if (joinedAt != null) {
        final elapsed = DateTime.now().difference(joinedAt).inSeconds;
        state = state.copyWith(elapsedSeconds: elapsed);
      }
    });

    // Authoritative polling timer (every 2.5 seconds, refreshing server heartbeat)
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _pollQueue();
    });
  }

  /// Polls server for match pairing status via `rpc_poll_ranked_matchmaking`.
  Future<void> _pollQueue() async {
    if (_isDisposed || !state.isSearching || _isPolling) return;
    _isPolling = true;

    try {
      final result = await _repository.pollMatchmaking();
      if (_isDisposed || !state.isSearching) return;

      _consecutivePollErrors = 0;
      await _handleMatchmakingResult(result);
    } catch (e) {
      if (_isDisposed || !state.isSearching) return;
      _consecutivePollErrors++;
      debugPrint('RankedMatchmakingNotifier: Poll error ($_consecutivePollErrors): $e');

      // Allow up to 3 transient network dropouts before showing error
      if (_consecutivePollErrors >= 3) {
        _stopTimers();
        state = state.copyWith(
          status: MatchmakingStatus.error,
          errorMessage: 'Lost connection to matchmaking server. Please check your network.',
          errorCode: RankedErrorCode.networkError,
        );
      }
    } finally {
      _isPolling = false;
    }
  }

  /// Handles match pairing confirmation or active match recovery.
  Future<void> _onMatchFound(String matchId, {required bool isExistingActiveMatch}) async {
    _stopTimers();

    state = state.copyWith(
      status: isExistingActiveMatch
          ? MatchmakingStatus.activeMatchRecovery
          : MatchmakingStatus.matched,
      matchId: matchId,
      clearError: true,
    );

    try {
      // Validate authoritative match state from PostgreSQL
      final match = await _repository.getMatch(matchId);
      if (_isDisposed) return;

      if (match == null) {
        state = state.copyWith(
          status: MatchmakingStatus.error,
          errorMessage: 'Match found but could not load authoritative match record.',
          errorCode: RankedErrorCode.matchNotFound,
        );
        return;
      }

      final uid = _repository.currentUserId;
      if (uid != null && !match.isParticipant(uid)) {
        state = state.copyWith(
          status: MatchmakingStatus.error,
          errorMessage: 'Authorization failed: You are not a registered participant in this match.',
          errorCode: RankedErrorCode.notParticipant,
        );
        return;
      }

      state = state.copyWith(matchedMatch: match);
    } catch (e) {
      if (_isDisposed) return;
      debugPrint('RankedMatchmakingNotifier: Error validating match details: $e');
      // Even if detailed fetch fails, preserve matchId so client can attempt reconnect on the gameplay screen
    }
  }

  /// Cancels matchmaking queue entry.
  Future<bool> cancelMatchmaking() async {
    if (_isDisposed) return true;
    if (_isCancelling || state.isCancelled || state.isIdle) return true;

    _isCancelling = true;
    _stopTimers();

    state = state.copyWith(status: MatchmakingStatus.cancelling);

    try {
      await _repository.cancelMatchmaking();
      if (!_isDisposed) {
        state = state.copyWith(
          status: MatchmakingStatus.cancelled,
          clearMatch: true,
        );
      }
      return true;
    } catch (e) {
      debugPrint('RankedMatchmakingNotifier: Non-fatal error cancelling queue: $e');
      if (!_isDisposed) {
        state = state.copyWith(status: MatchmakingStatus.cancelled);
      }
      return true;
    } finally {
      _isCancelling = false;
    }
  }

  /// Marks navigation as completed to prevent duplicate route pushes.
  void markNavigated() {
    _hasNavigated = true;
    state = state.copyWith(isNavigating: true);
  }

  /// Resets controller state back to idle.
  void reset() {
    _stopTimers();
    _isJoining = false;
    _isPolling = false;
    _isCancelling = false;
    _hasNavigated = false;
    _consecutivePollErrors = 0;
    state = const RankedMatchmakingUiState();
  }

  /// Handles application lifecycle resume without blindly re-joining queue.
  void handleAppResume() {
    if (_isDisposed) return;
    if (state.isSearching) {
      debugPrint('RankedMatchmakingNotifier: App resumed while searching; polling queue status');
      _pollQueue();
    }
  }

  void _handleRankedException(RankedException e) {
    String userMessage;
    switch (e.code) {
      case RankedErrorCode.notAuthenticated:
        userMessage = 'Authentication expired. Please sign in again.';
        break;
      case RankedErrorCode.clientNotConfigured:
        userMessage = 'Supabase client is not configured.';
        break;
      case RankedErrorCode.networkError:
        userMessage = 'Network connection failed. Please check your internet.';
        break;
      default:
        userMessage = e.message.isNotEmpty
            ? e.message
            : 'An unexpected matchmaking error occurred.';
    }

    state = state.copyWith(
      status: MatchmakingStatus.error,
      errorMessage: userMessage,
      errorCode: e.code,
    );
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _queueTimer?.cancel();
    _queueTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopTimers();
    super.dispose();
  }
}

final rankedMatchmakingProvider =
    StateNotifierProvider.autoDispose<RankedMatchmakingNotifier, RankedMatchmakingUiState>(
        (ref) {
  final repo = ref.watch(onlineRankedRepositoryProvider);
  return RankedMatchmakingNotifier(repo);
});
