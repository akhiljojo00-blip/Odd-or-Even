import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/progression/data/local_progression_repo.dart';
import 'package:odd_or_even/features/progression/domain/models/career_stats.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalProgressionRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = LocalProgressionRepository(preferences: prefs);
  });

  group('LocalProgressionRepository - HMAC Tamper Resistance & Persistence Tests', () {
    test('Default load returns initial rank state when storage is empty', () async {
      final state = await repo.getVsComputerRankState();
      expect(state.tier, equals(RankTier.bronze));
      expect(state.division, equals(RankDivision.III));
      expect(state.stars, equals(0));
      expect(state.matchesPlayed, equals(0));
    });

    test('Legitimate state saves and loads with verified HMAC signature', () async {
      final testState = VsComputerRankState.initial().copyWith(
        tier: RankTier.gold,
        division: RankDivision.I,
        stars: 2,
        winStreak: 5,
        matchesPlayed: 14,
        matchesWon: 11,
      );

      await repo.saveVsComputerRankState(testState);

      final loaded = await repo.getVsComputerRankState();
      expect(loaded.tier, equals(RankTier.gold));
      expect(loaded.division, equals(RankDivision.I));
      expect(loaded.stars, equals(2));
      expect(loaded.winStreak, equals(5));
      expect(loaded.matchesPlayed, equals(14));
      expect(loaded.matchesWon, equals(11));
    });

    test('Tampering with VsComputerRankState JSON payload causes verification failure and quarantine', () async {
      final legitimateState = VsComputerRankState.initial().copyWith(
        tier: RankTier.silver,
        division: RankDivision.II,
        stars: 1,
      );

      await repo.saveVsComputerRankState(legitimateState);

      // Maliciously tamper with SharedPreferences directly (e.g. user edits save file to give themselves Grand Master)
      final prefs = await SharedPreferences.getInstance();
      final originalJson = prefs.getString('odd_or_even_vs_computer_rank_v1')!;
      final tamperedMap = jsonDecode(originalJson) as Map<String, dynamic>;
      tamperedMap['tier'] = 'grandMaster';
      tamperedMap['stars'] = 10;
      await prefs.setString('odd_or_even_vs_computer_rank_v1', jsonEncode(tamperedMap));

      // Attempt to load tampered state
      final loaded = await repo.getVsComputerRankState();

      // Tampered state must be rejected and reset to initial
      expect(loaded.tier, equals(RankTier.bronze));
      expect(loaded.stars, equals(0));

      // Quarantine log must record this event
      final quarantineLogs = await repo.getQuarantineLogs();
      expect(quarantineLogs.isNotEmpty, isTrue);
      expect(quarantineLogs.first['entity'], equals('VsComputerRankState'));
    });

    test('Tampering with Local XP directly causes verification failure and returns 0', () async {
      // Award legitimate 50 XP
      await repo.addLocalXp(50);
      final validXp = await repo.getLocalXp();
      expect(validXp, equals(50));

      // Maliciously overwrite raw integer without valid HMAC
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('odd_or_even_local_xp_v1', 999999);

      // Attempt to read tampered XP
      final loadedXp = await repo.getLocalXp();
      expect(loadedXp, equals(0)); // Rejected!

      final quarantineLogs = await repo.getQuarantineLogs();
      expect(quarantineLogs.any((log) => log['entity'] == 'LocalXp'), isTrue);
    });

    test('Daily XP cap correctly enforces 1500 XP maximum across consecutive awards', () async {
      final testDate = DateTime(2026, 11, 10);

      // Award 1000 XP
      final awarded1 = await repo.addLocalXp(1000, date: testDate);
      expect(awarded1, equals(1000));
      expect(await repo.getLocalXp(), equals(1000));
      expect(await repo.getDailyXpEarned(testDate), equals(1000));

      // Award 600 XP on same day -> only 500 should be accepted
      final awarded2 = await repo.addLocalXp(600, date: testDate);
      expect(awarded2, equals(500));
      expect(await repo.getLocalXp(), equals(1500));
      expect(await repo.getDailyXpEarned(testDate), equals(1500));

      // Additional awards on same day must be rejected (0 awarded)
      final awarded3 = await repo.addLocalXp(100, date: testDate);
      expect(awarded3, equals(0));
      expect(await repo.getLocalXp(), equals(1500));

      // Next day: cap resets
      final nextDay = DateTime(2026, 11, 11);
      final awardedNextDay = await repo.addLocalXp(50, date: nextDay);
      expect(awardedNextDay, equals(50));
      expect(await repo.getLocalXp(), equals(1550));
      expect(await repo.getDailyXpEarned(nextDay), equals(50));
    });

    test('ModeCareerStats saves and loads legitimately per game mode', () async {
      final initialStats = const ModeCareerStats().recordMatch(
        isWin: true,
        isTie: false,
        runsScored: 24,
        wicketsTaken: 1,
        wasChasing: true,
        target: 20,
      );

      await repo.saveModeStats('vs_computer_ranked', initialStats);

      final loadedStats = await repo.getModeStats('vs_computer_ranked');
      expect(loadedStats.matchesPlayed, equals(1));
      expect(loadedStats.matchesWon, equals(1));
      expect(loadedStats.totalRuns, equals(24));
      expect(loadedStats.totalWickets, equals(1));
      expect(loadedStats.highestScore, equals(24));
      expect(loadedStats.bestChase, equals(20));
      expect(loadedStats.currentStreak, equals(1));
    });
  });
}
