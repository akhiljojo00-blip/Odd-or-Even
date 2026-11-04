import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../game/domain/models/match_config.dart';

class SupabaseMatchRepository {
  bool get isConfigured {
    try {
      return Supabase.instance.client.auth.currentSession != null ||
          Supabase.instance.client.rest.url.isNotEmpty;
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

  /// Invokes `rpc_join_room` with code.
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
}

final supabaseMatchRepositoryProvider = Provider<SupabaseMatchRepository>((ref) {
  return SupabaseMatchRepository();
});
