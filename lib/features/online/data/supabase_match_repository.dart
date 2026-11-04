import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../game/domain/models/ball_event.dart';
import '../../game/domain/models/game_match_state.dart';
import '../../game/domain/models/match_config.dart';

class SupabaseMatchRepository {
  bool get isConfigured {
    try {
      final client = Supabase.instance.client;
      return client.rest.url.isNotEmpty &&
          !client.rest.url.contains('your-project-id');
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Ensures an authenticated session exists (anonymous sign-in if needed).
  Future<String?> ensureAuthenticatedUser() async {
    final client = _client;
    if (client == null) return null;

    try {
      if (client.auth.currentUser == null) {
        final authResponse = await client.auth.signInAnonymously();
        return authResponse.user?.id;
      }
      return client.auth.currentUser?.id;
    } catch (e) {
      debugPrint('Supabase Auth error: $e');
      return null;
    }
  }

  /// Invokes `rpc_create_room` with configuration.
  Future<Map<String, dynamic>?> createRoom(MatchConfig config) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_create_room', params: {
        'p_config': config.toJson(),
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error creating room: $e');
      return null;
    }
  }

  /// Invokes `rpc_join_room` with room code.
  Future<Map<String, dynamic>?> joinRoom(String roomCode) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_join_room', params: {
        'p_code': roomCode.trim().toUpperCase(),
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error joining room: $e');
      return null;
    }
  }

  /// Mutual configuration agreement by room participant.
  Future<Map<String, dynamic>?> confirmRoomConfig(String roomId, MatchConfig config) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_confirm_room_config', params: {
        'p_room_id': roomId,
        'p_config': config.toJson(),
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error confirming room config: $e');
      return null;
    }
  }

  /// Fetches current room state.
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.from('game_rooms').select().eq('id', roomId).maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      debugPrint('Error fetching room: $e');
      return null;
    }
  }

  /// Fetches authoritative match state snapshot.
  Future<GameMatchState?> getMatch(String matchId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.from('matches').select().eq('id', matchId).maybeSingle();
      if (res == null) return null;

      final ballEvents = await getBallEvents(matchId);
      final map = Map<String, dynamic>.from(res);
      map['ballHistory'] = ballEvents.map((e) => e.toJson()).toList();
      return GameMatchState.fromJson(map);
    } catch (e) {
      debugPrint('Error fetching match: $e');
      return null;
    }
  }

  /// Submits number choice into private storage & triggers server resolution.
  Future<Map<String, dynamic>?> submitChoice({
    required String matchId,
    required String turnType,
    required int choice,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_submit_choice', params: {
        'p_match_id': matchId,
        'p_turn_type': turnType,
        'p_choice': choice,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error submitting choice: $e');
      return null;
    }
  }

  /// Role selection by toss winner (Bat or Bowl).
  Future<Map<String, dynamic>?> selectRole({
    required String matchId,
    required String role,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_select_role', params: {
        'p_match_id': matchId,
        'p_role': role.toLowerCase(),
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error selecting role: $e');
      return null;
    }
  }

  /// Advances from innings break to second innings chase.
  Future<Map<String, dynamic>?> startSecondInnings(String matchId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_start_second_innings', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error starting second innings: $e');
      return null;
    }
  }

  /// Requests a fresh rematch match keeping cumulative series score.
  Future<Map<String, dynamic>?> requestRematch(String matchId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_request_rematch', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error requesting rematch: $e');
      return null;
    }
  }

  /// Claims timeout point when opponent fails to submit in time.
  Future<Map<String, dynamic>?> claimTimeout({
    required String matchId,
    required String timedOutUserId,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_claim_timeout', params: {
        'p_match_id': matchId,
        'p_timed_out_user_id': timedOutUserId,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error claiming timeout: $e');
      return null;
    }
  }

  /// Forfeits the match (or claims opponent forfeit after disconnect grace).
  Future<Map<String, dynamic>?> forfeitMatch(String matchId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_forfeit_match', params: {
        'p_match_id': matchId,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error forfeiting match: $e');
      return null;
    }
  }

  /// Instant matchmaking join.
  Future<Map<String, dynamic>?> joinMatchmaking(MatchConfig config) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_join_matchmaking', params: {
        'p_config': config.toJson(),
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error joining matchmaking: $e');
      return null;
    }
  }

  /// Polls matchmaking status.
  Future<Map<String, dynamic>?> pollMatchmaking() async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('rpc_poll_matchmaking');
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Error polling matchmaking: $e');
      return null;
    }
  }

  /// Cancels matchmaking queue.
  Future<void> cancelMatchmaking() async {
    final client = _client;
    if (client == null) return;

    try {
      await client.rpc('rpc_cancel_matchmaking');
    } catch (e) {
      debugPrint('Error cancelling matchmaking: $e');
    }
  }

  /// Fetches historical resolved ball events.
  Future<List<BallEvent>> getBallEvents(String matchId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final res = await client
          .from('ball_events')
          .select()
          .eq('match_id', matchId)
          .order('innings_no')
          .order('ball_no');
      return (res as List).map((e) => BallEvent.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Error fetching ball events: $e');
      return [];
    }
  }

  /// Fetches player profile.
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.from('player_profiles').select().eq('id', userId).maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  /// Updates player profile.
  Future<void> updateProfile({required String displayName, int avatarIndex = 0}) async {
    final client = _client;
    final uid = currentUserId;
    if (client == null || uid == null) return;

    try {
      await client.from('player_profiles').upsert({
        'id': uid,
        'display_name': displayName,
        'avatar_index': avatarIndex,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  /// Subscribes to realtime Postgres updates for an active match.
  /// Notifies `onStateChange` instantly whenever the match record or new ball event is broadcast.
  RealtimeChannel? subscribeToMatchChannel({
    required String matchId,
    required VoidCallback onStateChange,
    void Function(RealtimeSubscribeStatus status)? onStatusChange,
  }) {
    final client = _client;
    if (client == null) return null;

    try {
      final channel = client.channel('match_channel:$matchId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'matches',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: matchId,
            ),
            callback: (payload) {
              onStateChange();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'ball_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'match_id',
              value: matchId,
            ),
            callback: (payload) {
              onStateChange();
            },
          )
          .subscribe((status, [error]) {
            if (onStatusChange != null) {
              onStatusChange(status);
            }
          });
      return channel;
    } catch (e) {
      debugPrint('Error subscribing to match realtime channel: $e');
      return null;
    }
  }

  /// Subscribes to realtime room status and configuration updates.
  RealtimeChannel? subscribeToRoomChannel({
    required String roomId,
    required VoidCallback onRoomUpdated,
  }) {
    final client = _client;
    if (client == null) return null;

    try {
      final channel = client.channel('room_channel:$roomId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'game_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: roomId,
            ),
            callback: (_) => onRoomUpdated(),
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('Error subscribing to room realtime channel: $e');
      return null;
    }
  }

  /// Safely removes/unsubscribes a realtime channel.
  Future<void> unsubscribeChannel(RealtimeChannel? channel) async {
    final client = _client;
    if (client == null || channel == null) return;
    try {
      await client.removeChannel(channel);
    } catch (e) {
      debugPrint('Error removing realtime channel: $e');
    }
  }
}

final supabaseMatchRepositoryProvider = Provider<SupabaseMatchRepository>((ref) {
  return SupabaseMatchRepository();
});
