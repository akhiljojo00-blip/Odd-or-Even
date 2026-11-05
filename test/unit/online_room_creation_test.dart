import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/online/data/supabase_match_repository.dart';

void main() {
  group('Room Creation & RPC Signature Regression Tests', () {
    test('MatchConfig serializes with exact keys expected by rpc_create_room', () {
      const config = MatchConfig(
        gameMode: GameMode.standard,
        overs: 2,
        decisionTimerSeconds: 15,
        seriesTargetPoints: 6,
      );

      final json = config.toJson();

      // PostgreSQL rpc_create_room parses:
      // p_config->>'gameMode'
      // p_config->>'overs'
      // p_config->>'decisionTimerSeconds'
      // p_config->>'seriesTargetPoints'
      expect(json['gameMode'], equals('standard'));
      expect(json['overs'], equals(2));
      expect(json['decisionTimerSeconds'], equals(15));
      expect(json['seriesTargetPoints'], equals(6));
    });

    test('MatchConfig handles null overs for unlimited play', () {
      const config = MatchConfig(
        gameMode: GameMode.fast,
        overs: null,
      );

      final json = config.toJson();
      expect(json['gameMode'], equals('fast'));
      expect(json['overs'], isNull);
    });

    test('SupabaseMatchRepository exposes structured error fields', () {
      final repo = SupabaseMatchRepository();

      // Before any operation, errors are null
      expect(repo.lastAuthError, isNull);
      expect(repo.lastRoomError, isNull);
      expect(repo.lastErrorCode, isNull);
      expect(repo.lastErrorDetails, isNull);
      expect(repo.lastErrorHint, isNull);
    });

    test('SupabaseMatchRepository gracefully handles unconfigured state', () async {
      final repo = SupabaseMatchRepository();

      // When Supabase is unconfigured (empty URL / anon key):
      expect(repo.isConfigured, isFalse);

      final uid = await repo.ensureAuthenticatedUser();
      expect(uid, isNull);
      expect(repo.lastAuthError, contains('not initialized'));

      final room = await repo.createRoom(const MatchConfig());
      expect(room, isNull);
      expect(repo.lastRoomError, contains('not configured'));
    });
  });
}
