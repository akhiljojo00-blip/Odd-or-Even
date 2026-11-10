import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/progression/domain/logic/xp_calculator.dart';
import 'package:odd_or_even/features/progression/domain/models/xp_progress.dart';

void main() {
  group('XpCalculator - Domain Logic Unit Tests', () {
    test('Standard match win awards 50 XP (20 base + 30 win)', () {
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 0,
        isWin: true,
        isTie: false,
        legalBallsBowled: 6,
        isPassAndPlay: false,
      );

      expect(result.baseMatchXp, equals(20));
      expect(result.outcomeBonusXp, equals(30));
      expect(result.dailyBonusXp, equals(0));
      expect(result.promotionBonusXp, equals(0));
      expect(result.totalXpAwarded, equals(50));
      expect(result.newTotalXp, equals(50));
      expect(result.newProgress.level, equals(1));
      expect(result.newProgress.currentLevelProgressXp, equals(50));
      expect(result.newProgress.xpRequiredForNextLevel, equals(100));
      expect(result.newProgress.progressFraction, equals(0.5));
    });

    test('Standard match loss awards 30 XP (20 base + 10 loss)', () {
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 50,
        isWin: false,
        isTie: false,
        legalBallsBowled: 6,
        isPassAndPlay: false,
      );

      expect(result.baseMatchXp, equals(20));
      expect(result.outcomeBonusXp, equals(10));
      expect(result.totalXpAwarded, equals(30));
      expect(result.newTotalXp, equals(80));
    });

    test('Standard match tie awards 35 XP (20 base + 15 tie)', () {
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 0,
        isWin: false,
        isTie: true,
        legalBallsBowled: 6,
        isPassAndPlay: false,
      );

      expect(result.baseMatchXp, equals(20));
      expect(result.outcomeBonusXp, equals(15));
      expect(result.totalXpAwarded, equals(35));
    });

    test('First daily match adds +20 daily bonus XP', () {
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 0,
        isWin: true,
        isTie: false,
        legalBallsBowled: 6,
        isPassAndPlay: false,
        isFirstDailyMatch: true,
      );

      expect(result.dailyBonusXp, equals(20));
      expect(result.totalXpAwarded, equals(70)); // 20 + 30 + 20
    });

    test('Rank promotion adds +50 promotion bonus XP', () {
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 0,
        isWin: true,
        isTie: false,
        legalBallsBowled: 6,
        isPassAndPlay: false,
        isPromotion: true,
      );

      expect(result.promotionBonusXp, equals(50));
      expect(result.totalXpAwarded, equals(100)); // 20 + 30 + 50
    });

    test('Pass & Play matches strictly award 0 XP', () {
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 120,
        isWin: true,
        isTie: false,
        legalBallsBowled: 12,
        isPassAndPlay: true,
        isFirstDailyMatch: true,
        isPromotion: true,
      );

      expect(result.totalXpAwarded, equals(0));
      expect(result.newTotalXp, equals(120));
      expect(result.levelsGained, equals(0));
    });

    test('Matches terminated under 4 legal balls award 0 XP', () {
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 100,
        isWin: true,
        isTie: false,
        legalBallsBowled: 3,
        isPassAndPlay: false,
      );

      expect(result.totalXpAwarded, equals(0));
      expect(result.newTotalXp, equals(100));
    });

    test('Daily cap clamps awarded XP at 1500 XP maximum per day', () {
      // 1480 already earned today, match earns 50 uncapped -> only 20 awarded
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 1480,
        isWin: true,
        isTie: false,
        legalBallsBowled: 6,
        isPassAndPlay: false,
        dailyXpAccumulatedSoFar: 1480,
      );

      expect(result.totalXpAwarded, equals(20));
      expect(result.newTotalXp, equals(1500));

      // Subsequent match on same day at cap awards 0 XP
      final cappedResult = XpCalculator.computeMatchXp(
        currentTotalXp: 1500,
        isWin: true,
        isTie: false,
        legalBallsBowled: 6,
        isPassAndPlay: false,
        dailyXpAccumulatedSoFar: 1500,
      );

      expect(cappedResult.totalXpAwarded, equals(0));
      expect(cappedResult.newTotalXp, equals(1500));
    });

    test('Player level scales with arithmetic formula: 100 + 50 * (L - 1)', () {
      expect(XpEconomy.xpRequiredForLevel(1), equals(100));
      expect(XpEconomy.xpRequiredForLevel(2), equals(150));
      expect(XpEconomy.xpRequiredForLevel(3), equals(200));
      expect(XpEconomy.xpRequiredForLevel(4), equals(250));

      // Cumulative XP thresholds:
      // Level 1: 0 - 99 XP
      // Level 2: 100 - 249 XP
      // Level 3: 250 - 449 XP
      // Level 4: 450 - 699 XP
      expect(XpEconomy.totalXpToReachLevel(1), equals(0));
      expect(XpEconomy.totalXpToReachLevel(2), equals(100));
      expect(XpEconomy.totalXpToReachLevel(3), equals(250));
      expect(XpEconomy.totalXpToReachLevel(4), equals(450));

      final progLevel1 = XpEconomy.calculateProgress(99);
      expect(progLevel1.level, equals(1));
      expect(progLevel1.currentLevelProgressXp, equals(99));

      final progLevel2 = XpEconomy.calculateProgress(100);
      expect(progLevel2.level, equals(2));
      expect(progLevel2.currentLevelProgressXp, equals(0));
      expect(progLevel2.xpRequiredForNextLevel, equals(150));

      final progLevel3 = XpEconomy.calculateProgress(250);
      expect(progLevel3.level, equals(3));
      expect(progLevel3.currentLevelProgressXp, equals(0));
    });

    test('Level-up detection triggers when match crosses level threshold', () {
      // At 80 XP (Level 1), award 50 XP -> 130 XP (Level 2)
      final result = XpCalculator.computeMatchXp(
        currentTotalXp: 80,
        isWin: true,
        isTie: false,
        legalBallsBowled: 6,
        isPassAndPlay: false,
      );

      expect(result.previousProgress.level, equals(1));
      expect(result.newProgress.level, equals(2));
      expect(result.levelsGained, equals(1));
      expect(result.didLevelUp, isTrue);
    });
  });
}
