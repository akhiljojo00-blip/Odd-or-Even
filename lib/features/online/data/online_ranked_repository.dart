import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/online_player_rank.dart';
import '../domain/models/ranked_ball_event.dart';
import '../domain/models/ranked_exceptions.dart';
import '../domain/models/ranked_leaderboard_entry.dart';
import '../domain/models/ranked_match.dart';
import '../domain/models/ranked_match_settlement.dart';
import '../domain/models/ranked_matchmaking_state.dart';

/// Foundational repository providing server-authoritative Supabase access for Online Ranked multiplayer.
/// Adheres strictly to Zero Client Trust: All mutations occur through PostgreSQL RPCs.
class OnlineRankedRepository {
  final SupabaseClient? _injectedClient;

  OnlineRankedRepository({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Whether Supabase is configured with a valid non-placeholder URL.
  bool get isConfigured {
    final client = _client;
    if (client == null) return false;
    try {
      return client.rest.url.isNotEmpty &&
          !client.rest.url.contains('your-project-id');
    } catch (_) {
      return false;
    }
  }

  /// Authenticated user ID.
  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Ensures an authenticated session exists (anonymous sign-in fallback).
  Future<String?> ensureAuthenticatedUser() async {
    final client = _client;
    if (client == null) return null;

    try {
      if (client.auth.currentUser == null) {
        final authResponse = await client.auth.signInAnonymously();
        final uid = authResponse.user?.id;
        if (uid != null) {
          await _ensureProfileExists(client, uid);
        }
        return uid;
      }
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        await _ensureProfileExists(client, uid);
      }
      return uid;
    } on AuthException catch (e) {
      debugPrint('OnlineRankedRepository: AuthException during user authentication: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('OnlineRankedRepository: Unexpected error during authentication: $e');
      return null;
    }
  }

  Future<void> _ensureProfileExists(SupabaseClient client, String uid) async {
    try {
      final existing = await client
          .from('player_profiles')
          .select('id')
          .eq('id', uid)
          .maybeSingle();
      if (existing == null) {
        await client.from('player_profiles').upsert({
          'id': uid,
          'display_name': 'Player ${uid.length >= 4 ? uid.substring(0, 4) : uid}',
          'avatar_index': 0,
        });
      }
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error ensuring player profile exists: $e');
    }
  }

  /// Fetches basic player profile (display name, avatar) by user ID.
  Future<Map<String, dynamic>?> getPlayerProfile(String userId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client
          .from('player_profiles')
          .select('id, display_name, avatar_index')
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error fetching player profile: $e');
      return null;
    }
  }

  // =========================================================================
  // 1. DATA QUERIES (REST / VIEWS)
  // =========================================================================

  /// Fetches authoritative online rank and division details for the target user.
  Future<OnlinePlayerRank?> getPlayerRank([String? userId]) async {
    final client = _client;
    final uid = userId ?? currentUserId;
    if (client == null || uid == null) return null;

    try {
      final res = await client
          .from('online_player_ranks')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (res == null) return null;
      return OnlinePlayerRank.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException fetching rank: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error fetching rank: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Fetches authoritative batting and bowling statistics for the target user.
  Future<OnlineRankedStats?> getPlayerStats([String? userId]) async {
    final client = _client;
    final uid = userId ?? currentUserId;
    if (client == null || uid == null) return null;

    try {
      final res = await client
          .from('online_ranked_stats')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (res == null) return null;
      return OnlineRankedStats.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException fetching stats: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error fetching stats: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Fetches authoritative match state snapshot.
  Future<RankedMatch?> getMatch(String matchId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client
          .from('ranked_matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();
      if (res == null) return null;
      return RankedMatch.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException fetching match: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error fetching match: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Fetches historical resolved deliveries in strict chronological order.
  Future<List<RankedBallEvent>> getBallEvents(String matchId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client
          .from('ranked_ball_events')
          .select()
          .eq('match_id', matchId)
          .order('innings_no', ascending: true)
          .order('ball_no', ascending: true);
      final events = (res as List)
          .map((e) => RankedBallEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      events.sort((a, b) {
        if (a.inningsNo != b.inningsNo) {
          return a.inningsNo.compareTo(b.inningsNo);
        }
        return a.ballNo.compareTo(b.ballNo);
      });
      return events;
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException fetching ball events: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error fetching ball events: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Fetches match settlement record once match is completed.
  Future<RankedMatchSettlement?> getMatchSettlement(String matchId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client
          .from('ranked_match_settlements')
          .select()
          .eq('match_id', matchId)
          .maybeSingle();
      if (res == null) return null;
      return RankedMatchSettlement.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException fetching settlement: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error fetching settlement: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Fetches public leaderboard entries.
  Future<List<RankedLeaderboardEntry>> getLeaderboard({
    int limit = 100,
    int offset = 0,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client.rpc('rpc_get_ranked_leaderboard', params: {
        'p_limit': limit,
        'p_offset': offset,
      });

      if (res is List) {
        return res
            .map((e) => RankedLeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (_) {
      // Fallback directly to view query if RPC fails
      try {
        final fallbackRes = await client
            .from('v_ranked_leaderboard')
            .select()
            .range(offset, offset + limit - 1);
        return (fallbackRes as List)
            .map((e) => RankedLeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } on PostgrestException catch (e) {
        debugPrint('OnlineRankedRepository: PostgrestException fetching leaderboard: ${e.message}');
        throw RankedException.fromPostgrestException(e);
      } catch (e) {
        debugPrint('OnlineRankedRepository: Error fetching leaderboard: $e');
        throw RankedException.fromException(e);
      }
    }
  }

  // =========================================================================
  // 2. MATCHMAKING RPCS
  // =========================================================================

  /// Joins the ranked matchmaking queue.
  Future<RankedMatchmakingResult> joinMatchmaking() async {
    final client = _client;
    if (client == null) {
      return RankedMatchmakingResult.error('Supabase client is not configured');
    }

    try {
      final res = await client.rpc('rpc_join_ranked_matchmaking');
      return RankedMatchmakingResult.fromJson(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in joinMatchmaking: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in joinMatchmaking: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Polls current matchmaking queue status.
  Future<RankedMatchmakingResult> pollMatchmaking() async {
    final client = _client;
    if (client == null) {
      return RankedMatchmakingResult.error('Supabase client is not configured');
    }

    try {
      final res = await client.rpc('rpc_poll_ranked_matchmaking');
      return RankedMatchmakingResult.fromJson(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in pollMatchmaking: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in pollMatchmaking: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Cancels ranked matchmaking queue entry.
  Future<RankedMatchmakingResult> cancelMatchmaking() async {
    final client = _client;
    if (client == null) {
      return RankedMatchmakingResult.error('Supabase client is not configured');
    }

    try {
      final res = await client.rpc('rpc_cancel_ranked_matchmaking');
      return RankedMatchmakingResult.fromJson(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in cancelMatchmaking: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in cancelMatchmaking: $e');
      throw RankedException.fromException(e);
    }
  }

  // =========================================================================
  // 3. GAMEPLAY & STATE MACHINE RPCS
  // =========================================================================

  /// Submits a secret number choice (strictly 1 to 6) for either toss or ball.
  /// Never logs the secret choice.
  Future<Map<String, dynamic>> submitChoice({
    required String matchId,
    required String turnType,
    required int choice,
  }) async {
    if (choice < 1 || choice > 6) {
      throw const RankedException(
        code: RankedErrorCode.invalidChoice,
        message: 'Choice must be between 1 and 6',
      );
    }

    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_submit_choice', params: {
        'p_match_id': matchId,
        'p_turn_type': turnType,
        'p_choice': choice,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in submitChoice: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in submitChoice: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Toss winner selects role ('bat' or 'bowl').
  Future<Map<String, dynamic>> selectRole({
    required String matchId,
    required String role,
  }) async {
    final normalized = role.toLowerCase().trim();
    if (normalized != 'bat' && normalized != 'bowl') {
      throw const RankedException(
        code: RankedErrorCode.invalidRole,
        message: 'Role must be bat or bowl',
      );
    }

    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_select_role', params: {
        'p_match_id': matchId,
        'p_role': normalized,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in selectRole: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in selectRole: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Transitions match from innings break to second innings chase.
  Future<Map<String, dynamic>> startSecondInnings(String matchId) async {
    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_start_second_innings', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in startSecondInnings: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in startSecondInnings: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Sends periodic heartbeat to keep participant liveness fresh.
  Future<Map<String, dynamic>> sendHeartbeat(String matchId) async {
    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_heartbeat', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in sendHeartbeat: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in sendHeartbeat: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Reports opponent disconnect, triggering the 30-second grace window.
  Future<Map<String, dynamic>> reportDisconnect(String matchId) async {
    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_report_disconnect', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in reportDisconnect: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in reportDisconnect: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Reconnects a player during their active grace period.
  Future<Map<String, dynamic>> reconnect(String matchId) async {
    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_reconnect', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in reconnect: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in reconnect: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Claims timeout forfeit win when turn deadline or opponent grace window expires.
  Future<Map<String, dynamic>> claimTimeoutForfeit(String matchId) async {
    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_claim_timeout_forfeit', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in claimTimeoutForfeit: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in claimTimeoutForfeit: $e');
      throw RankedException.fromException(e);
    }
  }

  /// Concedes / surrenders the active match.
  Future<Map<String, dynamic>> surrender(String matchId) async {
    final client = _client;
    if (client == null) {
      throw const RankedException(
        code: RankedErrorCode.clientNotConfigured,
        message: 'Supabase client is not configured',
      );
    }

    try {
      final res = await client.rpc('rpc_ranked_surrender', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      debugPrint('OnlineRankedRepository: PostgrestException in surrender: ${e.message}');
      throw RankedException.fromPostgrestException(e);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error in surrender: $e');
      throw RankedException.fromException(e);
    }
  }

  // =========================================================================
  // 4. REALTIME CHANNEL HELPERS
  // =========================================================================

  /// Creates and subscribes a RealtimeChannel for an active match.
  RealtimeChannel? subscribeToMatchChannel({
    required String matchId,
    required VoidCallback onMatchChanged,
    required VoidCallback onBallEvent,
    void Function(RealtimeSubscribeStatus status)? onStatusChange,
  }) {
    final client = _client;
    if (client == null) return null;

    try {
      final channel = client.channel('ranked_match:$matchId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ranked_matches',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: matchId,
            ),
            callback: (_) => onMatchChanged(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'ranked_ball_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'match_id',
              value: matchId,
            ),
            callback: (_) => onBallEvent(),
          )
          .subscribe((status, [error]) {
            if (onStatusChange != null) {
              onStatusChange(status);
            }
          });
      return channel;
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error subscribing to match channel: $e');
      return null;
    }
  }

  /// Removes and unsubscribes a RealtimeChannel.
  Future<void> unsubscribeChannel(RealtimeChannel? channel) async {
    final client = _client;
    if (client == null || channel == null) return;
    try {
      await client.removeChannel(channel);
    } catch (e) {
      debugPrint('OnlineRankedRepository: Error removing channel: $e');
    }
  }
}

final onlineRankedRepositoryProvider = Provider<OnlineRankedRepository>((ref) {
  return OnlineRankedRepository();
});
