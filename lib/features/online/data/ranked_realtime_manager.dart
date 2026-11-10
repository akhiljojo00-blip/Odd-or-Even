import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/ranked_ball_event.dart';
import '../domain/models/ranked_match.dart';
import 'online_ranked_repository.dart';

/// Connection and synchronization states for match realtime subscriptions.
enum RealtimeSyncStatus {
  disconnected,
  connecting,
  subscribed,
  error,
  closed,
}

/// Manages realtime match subscriptions, websocket reconconnections,
/// authoritative state resynchronization, and polling fallbacks.
/// Adheres strictly to Zero Client Trust: WebSockets notify changes,
/// but state is authoritatively resolved and synced via server queries.
class RankedRealtimeManager {
  final OnlineRankedRepository _repository;

  String? _activeMatchId;
  RealtimeChannel? _activeChannel;
  RealtimeSyncStatus _status = RealtimeSyncStatus.disconnected;
  Timer? _fallbackPollingTimer;
  bool _isDisposed = false;

  void Function(RankedMatch match)? onMatchUpdated;
  void Function(List<RankedBallEvent> events)? onBallEventsUpdated;
  void Function(RealtimeSyncStatus status)? onStatusChanged;
  void Function(Object error)? onError;

  RankedRealtimeManager(this._repository);

  /// Current subscribed match ID.
  String? get activeMatchId => _activeMatchId;

  /// Current realtime sync status.
  RealtimeSyncStatus get status => _status;

  /// True if currently subscribed to a live match channel.
  bool get isSubscribed => _status == RealtimeSyncStatus.subscribed;

  void _setStatus(RealtimeSyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_isDisposed) {
        onStatusChanged?.call(_status);
      }
    }
  }

  /// Subscribes to realtime updates for [matchId].
  /// Prevents duplicate subscriptions to the same match and tears down previous channels if switching.
  Future<void> subscribe({
    required String matchId,
    void Function(RankedMatch match)? onMatchUpdated,
    void Function(List<RankedBallEvent> events)? onBallEventsUpdated,
    void Function(RealtimeSyncStatus status)? onStatusChanged,
    void Function(Object error)? onError,
    bool enablePollingFallback = true,
    Duration pollingInterval = const Duration(seconds: 4),
  }) async {
    if (_isDisposed) return;

    // Attach listeners
    if (onMatchUpdated != null) this.onMatchUpdated = onMatchUpdated;
    if (onBallEventsUpdated != null) this.onBallEventsUpdated = onBallEventsUpdated;
    if (onStatusChanged != null) this.onStatusChanged = onStatusChanged;
    if (onError != null) this.onError = onError;

    // Prevent duplicate subscription if already active on the same match
    if (_activeMatchId == matchId && _status == RealtimeSyncStatus.subscribed && _activeChannel != null) {
      debugPrint('RankedRealtimeManager: Already subscribed to match $matchId');
      return;
    }

    // Safely unsubscribe any prior match channel
    if (_activeMatchId != null && _activeMatchId != matchId) {
      await unsubscribe();
    }

    _activeMatchId = matchId;
    _setStatus(RealtimeSyncStatus.connecting);

    // Initial authoritative state fetch to avoid waiting on websocket handshake
    await resyncAuthoritativeState();

    if (enablePollingFallback) {
      startPollingFallback(interval: pollingInterval);
    }

    // Subscribe to match channel via repository
    _activeChannel = _repository.subscribeToMatchChannel(
      matchId: matchId,
      onMatchChanged: () async {
        debugPrint('RankedRealtimeManager: Match change broadcast received for $matchId');
        await _handleMatchChange();
      },
      onBallEvent: () async {
        debugPrint('RankedRealtimeManager: Ball event broadcast received for $matchId');
        await _handleBallEventChange();
      },
      onStatusChange: (status) async {
        if (_isDisposed || _activeMatchId != matchId) return;

        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            debugPrint('RankedRealtimeManager: Channel subscribed for match $matchId');
            _setStatus(RealtimeSyncStatus.subscribed);
            // Authoritative resync immediately after connection or reconnection
            await resyncAuthoritativeState();
            break;
          case RealtimeSubscribeStatus.closed:
            debugPrint('RankedRealtimeManager: Channel closed for match $matchId');
            _setStatus(RealtimeSyncStatus.closed);
            break;
          case RealtimeSubscribeStatus.timedOut:
            debugPrint('RankedRealtimeManager: Channel timed out for match $matchId');
            _setStatus(RealtimeSyncStatus.error);
            this.onError?.call('Realtime subscription timed out. Falling back to authoritative sync.');
            break;
          case RealtimeSubscribeStatus.channelError:
            debugPrint('RankedRealtimeManager: Channel error for match $matchId');
            _setStatus(RealtimeSyncStatus.error);
            this.onError?.call('Realtime channel error. Relying on polling sync.');
            break;
        }
      },
    );

    if (_activeChannel == null) {
      // If client cannot open channel (e.g. offline or unconfigured), flag status but continue polling fallback
      _setStatus(RealtimeSyncStatus.error);
    }
  }

  /// Fetches authoritative state from PostgreSQL REST endpoints and notifies callbacks.
  Future<void> resyncAuthoritativeState() async {
    final matchId = _activeMatchId;
    if (matchId == null || _isDisposed) return;

    try {
      final matchFuture = _repository.getMatch(matchId);
      final ballsFuture = _repository.getBallEvents(matchId);

      final match = await matchFuture;
      final balls = await ballsFuture;

      if (!_isDisposed && _activeMatchId == matchId) {
        if (match != null) {
          onMatchUpdated?.call(match);
        }
        if (balls.isNotEmpty) {
          onBallEventsUpdated?.call(balls);
        }
      }
    } catch (e) {
      debugPrint('RankedRealtimeManager: Error during authoritative resync: $e');
      if (!_isDisposed) {
        onError?.call(e);
      }
    }
  }

  Future<void> _handleMatchChange() async {
    final matchId = _activeMatchId;
    if (matchId == null || _isDisposed) return;

    try {
      final match = await _repository.getMatch(matchId);
      if (!_isDisposed && _activeMatchId == matchId && match != null) {
        onMatchUpdated?.call(match);
      }
    } catch (e) {
      debugPrint('RankedRealtimeManager: Error updating match from broadcast: $e');
    }
  }

  Future<void> _handleBallEventChange() async {
    final matchId = _activeMatchId;
    if (matchId == null || _isDisposed) return;

    try {
      final balls = await _repository.getBallEvents(matchId);
      if (!_isDisposed && _activeMatchId == matchId) {
        onBallEventsUpdated?.call(balls);
      }
    } catch (e) {
      debugPrint('RankedRealtimeManager: Error updating ball events from broadcast: $e');
    }
  }

  /// Starts polling fallback timer to periodically guarantee zero dropped events.
  void startPollingFallback({Duration interval = const Duration(seconds: 4)}) {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer.periodic(interval, (_) async {
      if (_activeMatchId != null && !_isDisposed) {
        await resyncAuthoritativeState();
      }
    });
  }

  /// Stops polling fallback timer.
  void stopPollingFallback() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
  }

  /// Safely removes channel and stops synchronization.
  Future<void> unsubscribe() async {
    stopPollingFallback();
    final channel = _activeChannel;
    final hadActiveMatch = _activeMatchId != null;
    _activeChannel = null;
    _activeMatchId = null;

    if (channel != null || hadActiveMatch) {
      await _repository.unsubscribeChannel(channel);
    }
    _setStatus(RealtimeSyncStatus.closed);
  }

  /// Full resource disposal.
  Future<void> dispose() async {
    _isDisposed = true;
    onMatchUpdated = null;
    onBallEventsUpdated = null;
    onStatusChanged = null;
    onError = null;
    await unsubscribe();
  }
}

final rankedRealtimeManagerProvider = Provider<RankedRealtimeManager>((ref) {
  final repo = ref.watch(onlineRankedRepositoryProvider);
  final manager = RankedRealtimeManager(repo);
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});
