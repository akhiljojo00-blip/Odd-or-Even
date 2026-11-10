import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/career_stats.dart';
import '../domain/models/rank_tier.dart';
import '../domain/models/xp_progress.dart';

/// Local offline progression repository.
///
/// Implements cryptographic HMAC-SHA256 signature verification over all
/// serialized offline progression data stored in [SharedPreferences].
///
/// Any manual tampering with the JSON payloads stored in local storage
/// results in signature verification failure, quarantining the corrupted
/// record and restoring the player's legitimate baseline state.
class LocalProgressionRepository {
  static const String _kVsComputerRankKey = 'odd_or_even_vs_computer_rank_v1';
  static const String _kVsComputerRankSigKey = 'odd_or_even_vs_computer_rank_sig_v1';

  static const String _kLocalXpKey = 'odd_or_even_local_xp_v1';
  static const String _kLocalXpSigKey = 'odd_or_even_local_xp_sig_v1';

  static const String _kDailyXpDateKey = 'odd_or_even_daily_xp_date_v1';
  static const String _kDailyXpAmountKey = 'odd_or_even_daily_xp_amount_v1';
  static const String _kDailyXpSigKey = 'odd_or_even_daily_xp_sig_v1';

  static const String _kModeStatsKeyPrefix = 'odd_or_even_mode_stats_v1';
  static const String _kModeStatsSigKeyPrefix = 'odd_or_even_mode_stats_sig_v1';

  static const String _kDisplayNameKey = 'odd_or_even_player_display_name_v1';
  static const String _kAvatarIndexKey = 'odd_or_even_player_avatar_index_v1';
  static const String _kInstallUuidKey = 'odd_or_even_install_uuid_v1';
  static const String _kQuarantineLogKey = 'odd_or_even_quarantine_log_v1';

  static const String _secretSalt = 'odd_or_even_cricket_duel_offline_progression_salt_2026';

  final SharedPreferences? _injectedPrefs;

  LocalProgressionRepository({SharedPreferences? preferences})
      : _injectedPrefs = preferences;

  Future<SharedPreferences> _getPrefs() async {
    return _injectedPrefs ?? await SharedPreferences.getInstance();
  }

  /// Retrieves or initializes a unique installation UUID to bind HMAC salts to the local device.
  Future<String> getDeviceSalt() async {
    final prefs = await _getPrefs();
    return _getDeviceSaltFromPrefs(prefs);
  }

  Future<String> _getDeviceSaltFromPrefs(SharedPreferences prefs) async {
    String? installUuid = prefs.getString(_kInstallUuidKey);
    if (installUuid == null || installUuid.isEmpty) {
      installUuid = _generateUuid();
      await prefs.setString(_kInstallUuidKey, installUuid);
    }
    return '$_secretSalt:$installUuid';
  }

  /// Generates HMAC-SHA256 signature for a given payload and device-bound salt.
  String computeHmacSignature(String payload, String salt) {
    final keyBytes = utf8.encode(salt);
    final payloadBytes = utf8.encode(payload);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(payloadBytes).toString();
  }

  /// Verifies whether a given signature matches the payload.
  bool verifyHmacSignature(String payload, String signature, String salt) {
    final expectedSignature = computeHmacSignature(payload, salt);
    return expectedSignature == signature;
  }

  // =========================================================================
  // VS COMPUTER RANK STATE
  // =========================================================================

  /// Loads the offline VS Computer rank state.
  /// If data was tampered or corrupted, restores [VsComputerRankState.initial()].
  Future<VsComputerRankState> getVsComputerRankState() async {
    final prefs = await _getPrefs();
    final salt = await _getDeviceSaltFromPrefs(prefs);

    final jsonStr = prefs.getString(_kVsComputerRankKey);
    final sig = prefs.getString(_kVsComputerRankSigKey);

    if (jsonStr == null || sig == null) {
      return VsComputerRankState.initial();
    }

    if (!verifyHmacSignature(jsonStr, sig, salt)) {
      // TAMPER DETECTED: Log quarantine and return fresh initial state
      await _logQuarantine(prefs, 'VsComputerRankState', jsonStr, sig);
      return VsComputerRankState.initial();
    }

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return VsComputerRankState.fromJson(map);
    } catch (_) {
      return VsComputerRankState.initial();
    }
  }

  /// Persists the offline VS Computer rank state with a fresh HMAC-SHA256 signature.
  Future<void> saveVsComputerRankState(VsComputerRankState state) async {
    final prefs = await _getPrefs();
    final salt = await _getDeviceSaltFromPrefs(prefs);

    final jsonStr = jsonEncode(state.toJson());
    final sig = computeHmacSignature(jsonStr, salt);

    await prefs.setString(_kVsComputerRankKey, jsonStr);
    await prefs.setString(_kVsComputerRankSigKey, sig);
  }

  // =========================================================================
  // LOCAL XP & PLAYER LEVEL
  // =========================================================================

  /// Loads the cumulative offline XP. If tampered, safely returns 0.
  Future<int> getLocalXp() async {
    final prefs = await _getPrefs();
    final salt = await _getDeviceSaltFromPrefs(prefs);

    final xp = prefs.getInt(_kLocalXpKey);
    final sig = prefs.getString(_kLocalXpSigKey);

    if (xp == null || sig == null) {
      return 0;
    }

    if (!verifyHmacSignature(xp.toString(), sig, salt)) {
      await _logQuarantine(prefs, 'LocalXp', xp.toString(), sig);
      return 0;
    }

    return max(0, xp);
  }

  /// Calculates the current [XpProgress] from verified local XP.
  Future<XpProgress> getXpProgress() async {
    final totalXp = await getLocalXp();
    return XpEconomy.calculateProgress(totalXp);
  }

  /// Returns the amount of XP earned so far on the specified [date].
  Future<int> getDailyXpEarned([DateTime? date]) async {
    final prefs = await _getPrefs();
    final salt = await _getDeviceSaltFromPrefs(prefs);
    final targetDateStr = _formatDate(date ?? DateTime.now());

    final storedDate = prefs.getString(_kDailyXpDateKey);
    final storedAmount = prefs.getInt(_kDailyXpAmountKey);
    final sig = prefs.getString(_kDailyXpSigKey);

    if (storedDate == null || storedAmount == null || sig == null) {
      return 0;
    }

    if (storedDate != targetDateStr) {
      return 0;
    }

    final payload = '$storedDate:$storedAmount';
    if (!verifyHmacSignature(payload, sig, salt)) {
      await _logQuarantine(prefs, 'DailyXp', payload, sig);
      return 0;
    }

    return max(0, storedAmount);
  }

  /// Awards offline XP to the player, clamped by the daily cap ([XpEconomy.maxDailyXpCap]).
  /// Returns the actual amount of XP added.
  Future<int> addLocalXp(int rawXp, {DateTime? date}) async {
    if (rawXp <= 0) return 0;
    final prefs = await _getPrefs();
    final salt = await _getDeviceSaltFromPrefs(prefs);
    final now = date ?? DateTime.now();
    final dateStr = _formatDate(now);

    final currentDaily = await getDailyXpEarned(now);
    final remainingCap = max(0, XpEconomy.maxDailyXpCap - currentDaily);
    final actualAwarded = min(rawXp, remainingCap);

    if (actualAwarded <= 0) {
      return 0;
    }

    // Update cumulative total XP
    final currentTotal = await getLocalXp();
    final newTotal = currentTotal + actualAwarded;
    final xpSig = computeHmacSignature(newTotal.toString(), salt);

    await prefs.setInt(_kLocalXpKey, newTotal);
    await prefs.setString(_kLocalXpSigKey, xpSig);

    // Update daily XP
    final newDaily = currentDaily + actualAwarded;
    final dailyPayload = '$dateStr:$newDaily';
    final dailySig = computeHmacSignature(dailyPayload, salt);

    await prefs.setString(_kDailyXpDateKey, dateStr);
    await prefs.setInt(_kDailyXpAmountKey, newDaily);
    await prefs.setString(_kDailyXpSigKey, dailySig);

    return actualAwarded;
  }

  // =========================================================================
  // CAREER STATS PER GAME MODE
  // =========================================================================

  /// Loads career stats for a given mode (e.g. 'vs_computer_ranked', 'casual').
  Future<ModeCareerStats> getModeStats(String mode) async {
    final prefs = await _getPrefs();
    final salt = await _getDeviceSaltFromPrefs(prefs);

    final jsonStr = prefs.getString('${_kModeStatsKeyPrefix}_$mode');
    final sig = prefs.getString('${_kModeStatsSigKeyPrefix}_$mode');

    if (jsonStr == null || sig == null) {
      return const ModeCareerStats();
    }

    if (!verifyHmacSignature(jsonStr, sig, salt)) {
      await _logQuarantine(prefs, 'ModeStats_$mode', jsonStr, sig);
      return const ModeCareerStats();
    }

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ModeCareerStats.fromJson(map);
    } catch (_) {
      return const ModeCareerStats();
    }
  }

  /// Persists career stats for a given mode with HMAC signature.
  Future<void> saveModeStats(String mode, ModeCareerStats stats) async {
    final prefs = await _getPrefs();
    final salt = await _getDeviceSaltFromPrefs(prefs);

    final jsonStr = jsonEncode(stats.toJson());
    final sig = computeHmacSignature(jsonStr, salt);

    await prefs.setString('${_kModeStatsKeyPrefix}_$mode', jsonStr);
    await prefs.setString('${_kModeStatsSigKeyPrefix}_$mode', sig);
  }

  // =========================================================================
  // LOCAL PLAYER IDENTITY
  // =========================================================================

  Future<String> getLocalDisplayName() async {
    final prefs = await _getPrefs();
    return prefs.getString(_kDisplayNameKey) ?? 'Player 1';
  }

  Future<void> saveLocalDisplayName(String name) async {
    final prefs = await _getPrefs();
    await prefs.setString(_kDisplayNameKey, name);
  }

  Future<int> getLocalAvatarIndex() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_kAvatarIndexKey) ?? 0;
  }

  Future<void> saveLocalAvatarIndex(int index) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_kAvatarIndexKey, index);
  }

  // =========================================================================
  // ALL MODE STATS AGGREGATION
  // =========================================================================

  /// Loads career statistics across all individual game modes and computes an aggregated summary.
  Future<Map<String, ModeCareerStats>> getAllModeStats() async {
    final ranked = await getModeStats('vs_computer_ranked');
    final casual = await getModeStats('casual_vs_computer');
    final passPlay = await getModeStats('pass_and_play');
    final online = await getModeStats('online');

    final totalMatches = ranked.matchesPlayed + casual.matchesPlayed + passPlay.matchesPlayed + online.matchesPlayed;
    final totalWon = ranked.matchesWon + casual.matchesWon + passPlay.matchesWon + online.matchesWon;
    final totalLost = ranked.matchesLost + casual.matchesLost + passPlay.matchesLost + online.matchesLost;
    final totalTied = ranked.matchesTied + casual.matchesTied + passPlay.matchesTied + online.matchesTied;
    final totalRuns = ranked.totalRuns + casual.totalRuns + passPlay.totalRuns + online.totalRuns;
    final totalWickets = ranked.totalWickets + casual.totalWickets + passPlay.totalWickets + online.totalWickets;
    final highest = [ranked.highestScore, casual.highestScore, passPlay.highestScore, online.highestScore].reduce(max);
    final longestStreak = [ranked.longestWinStreak, casual.longestWinStreak, passPlay.longestWinStreak, online.longestWinStreak].reduce(max);
    final bestChase = [ranked.bestChase, casual.bestChase, passPlay.bestChase, online.bestChase]
        .whereType<int>()
        .fold<int?>(null, (prev, elem) => prev == null ? elem : (elem > prev ? elem : prev));

    final overall = ModeCareerStats(
      matchesPlayed: totalMatches,
      matchesWon: totalWon,
      matchesLost: totalLost,
      matchesTied: totalTied,
      totalRuns: totalRuns,
      totalWickets: totalWickets,
      highestScore: highest,
      currentStreak: ranked.currentStreak,
      longestWinStreak: longestStreak,
      bestChase: bestChase,
    );

    return {
      'all': overall,
      'vs_computer_ranked': ranked,
      'casual_vs_computer': casual,
      'pass_and_play': passPlay,
      'online': online,
    };
  }

  // =========================================================================
  // QUARANTINE & SECURITY AUDIT
  // =========================================================================

  Future<void> _logQuarantine(
    SharedPreferences prefs,
    String entity,
    String payload,
    String invalidSig,
  ) async {
    final logs = prefs.getStringList(_kQuarantineLogKey) ?? [];
    final entry = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'entity': entity,
      'payloadPreview': payload.length > 80 ? payload.substring(0, 80) : payload,
      'invalidSig': invalidSig,
    });
    logs.insert(0, entry);
    if (logs.length > 20) {
      logs.removeLast();
    }
    await prefs.setStringList(_kQuarantineLogKey, logs);
  }

  /// Returns list of quarantined tampering events.
  Future<List<Map<String, dynamic>>> getQuarantineLogs() async {
    final prefs = await _getPrefs();
    final rawLogs = prefs.getStringList(_kQuarantineLogKey) ?? [];
    return rawLogs
        .map((entry) {
          try {
            return jsonDecode(entry) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Resets all local progression data (useful for testing or full data wipe).
  Future<void> resetAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_kVsComputerRankKey);
    await prefs.remove(_kVsComputerRankSigKey);
    await prefs.remove(_kLocalXpKey);
    await prefs.remove(_kLocalXpSigKey);
    await prefs.remove(_kDailyXpDateKey);
    await prefs.remove(_kDailyXpAmountKey);
    await prefs.remove(_kDailyXpSigKey);
    await prefs.remove(_kQuarantineLogKey);
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _generateUuid() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // Set UUID v4 variant
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Riverpod provider for [LocalProgressionRepository].
final localProgressionRepositoryProvider = Provider<LocalProgressionRepository>((ref) {
  return LocalProgressionRepository();
});
