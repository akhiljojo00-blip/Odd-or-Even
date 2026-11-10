import '../models/xp_progress.dart';

class XpCalculationResult {
  final int baseMatchXp;
  final int outcomeBonusXp;
  final int dailyBonusXp;
  final int promotionBonusXp;
  final int totalXpAwarded;
  final int previousTotalXp;
  final int newTotalXp;
  final XpProgress previousProgress;
  final XpProgress newProgress;
  final int levelsGained;

  const XpCalculationResult({
    required this.baseMatchXp,
    required this.outcomeBonusXp,
    required this.dailyBonusXp,
    required this.promotionBonusXp,
    required this.totalXpAwarded,
    required this.previousTotalXp,
    required this.newTotalXp,
    required this.previousProgress,
    required this.newProgress,
    required this.levelsGained,
  });

  bool get didLevelUp => levelsGained > 0;
}

class XpCalculator {
  /// Computes the XP awarded for a match and the resulting level progression.
  static XpCalculationResult computeMatchXp({
    required int currentTotalXp,
    required bool isWin,
    required bool isTie,
    required int legalBallsBowled,
    required bool isPassAndPlay,
    bool isFirstDailyMatch = false,
    bool isPromotion = false,
    int dailyXpAccumulatedSoFar = 0,
  }) {
    // Anti-farming check 1: Pass & Play is 100% ineligible for XP (couch co-op)
    if (isPassAndPlay) {
      final prog = XpEconomy.calculateProgress(currentTotalXp);
      return XpCalculationResult(
        baseMatchXp: 0,
        outcomeBonusXp: 0,
        dailyBonusXp: 0,
        promotionBonusXp: 0,
        totalXpAwarded: 0,
        previousTotalXp: currentTotalXp,
        newTotalXp: currentTotalXp,
        previousProgress: prog,
        newProgress: prog,
        levelsGained: 0,
      );
    }

    // Anti-farming check 2: Minimum legal deliveries threshold
    if (legalBallsBowled < XpEconomy.minLegalBallsForXp) {
      final prog = XpEconomy.calculateProgress(currentTotalXp);
      return XpCalculationResult(
        baseMatchXp: 0,
        outcomeBonusXp: 0,
        dailyBonusXp: 0,
        promotionBonusXp: 0,
        totalXpAwarded: 0,
        previousTotalXp: currentTotalXp,
        newTotalXp: currentTotalXp,
        previousProgress: prog,
        newProgress: prog,
        levelsGained: 0,
      );
    }

    // Calculate award components
    const int baseXp = XpEconomy.matchCompletedXp; // 20
    final int outcomeXp = isWin
        ? XpEconomy.matchWonBonusXp // 30
        : (isTie ? XpEconomy.matchTiedBonusXp : XpEconomy.matchLostBonusXp); // 15 or 10
    final int dailyXp = isFirstDailyMatch ? XpEconomy.firstDailyMatchXp : 0; // 20
    final int promoXp = isPromotion ? XpEconomy.rankPromotionBonusXp : 0; // 50

    int uncappedTotal = baseXp + outcomeXp + dailyXp + promoXp;

    // Apply daily cap
    final remainingDailyAllowance = XpEconomy.maxDailyXpCap - dailyXpAccumulatedSoFar;
    int finalAwarded = uncappedTotal;
    if (remainingDailyAllowance <= 0) {
      finalAwarded = 0;
    } else if (finalAwarded > remainingDailyAllowance) {
      finalAwarded = remainingDailyAllowance;
    }

    final prevProgress = XpEconomy.calculateProgress(currentTotalXp);
    final newTotal = currentTotalXp + finalAwarded;
    final newProgress = XpEconomy.calculateProgress(newTotal);
    final levelsGained = newProgress.level - prevProgress.level;

    return XpCalculationResult(
      baseMatchXp: baseXp,
      outcomeBonusXp: outcomeXp,
      dailyBonusXp: dailyXp,
      promotionBonusXp: promoXp,
      totalXpAwarded: finalAwarded,
      previousTotalXp: currentTotalXp,
      newTotalXp: newTotal,
      previousProgress: prevProgress,
      newProgress: newProgress,
      levelsGained: levelsGained < 0 ? 0 : levelsGained,
    );
  }
}
