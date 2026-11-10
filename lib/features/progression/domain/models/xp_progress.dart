/// XP and Player Level Economy constants and calculations.
class XpEconomy {
  /// Base XP awarded for completing an eligible match.
  static const int matchCompletedXp = 20;

  /// Bonus XP awarded to the match winner.
  static const int matchWonBonusXp = 30;

  /// Bonus XP awarded for a tied match.
  static const int matchTiedBonusXp = 15;

  /// Bonus XP for completing a match that resulted in a loss.
  static const int matchLostBonusXp = 10;

  /// First eligible daily match bonus (awarded at most once per 24 hours).
  static const int firstDailyMatchXp = 20;

  /// Bonus XP awarded when promoting to a higher rank tier or division.
  static const int rankPromotionBonusXp = 50;

  /// Daily XP soft-cap to prevent bot and infinite farming.
  static const int maxDailyXpCap = 1500;

  /// Minimum legal deliveries for a match to be eligible for XP rewards.
  static const int minLegalBallsForXp = 4;

  /// Formula: XP required for next level = 100 + 50 * (current level - 1)
  static int xpRequiredForLevel(int level) {
    if (level < 1) return 100;
    return 100 + (50 * (level - 1));
  }

  /// Cumulative XP required to reach [level] from level 1 (at 0 XP).
  static int totalXpToReachLevel(int level) {
    if (level <= 1) return 0;
    int total = 0;
    for (int l = 1; l < level; l++) {
      total += xpRequiredForLevel(l);
    }
    return total;
  }

  /// Calculates player level and progress from cumulative [totalXp].
  static XpProgress calculateProgress(int totalXp) {
    final clampedXp = totalXp < 0 ? 0 : totalXp;
    int currentLevel = 1;
    int accumulatedXp = 0;

    while (true) {
      final requiredForNext = xpRequiredForLevel(currentLevel);
      if (accumulatedXp + requiredForNext > clampedXp) {
        final currentLevelProgressXp = clampedXp - accumulatedXp;
        final fraction = (currentLevelProgressXp / requiredForNext).clamp(0.0, 1.0);
        return XpProgress(
          level: currentLevel,
          totalXp: clampedXp,
          currentLevelBaseXp: accumulatedXp,
          currentLevelProgressXp: currentLevelProgressXp,
          xpRequiredForNextLevel: requiredForNext,
          progressFraction: fraction,
        );
      }
      accumulatedXp += requiredForNext;
      currentLevel++;
    }
  }
}

/// Represents player level and XP progression details.
class XpProgress {
  final int level;
  final int totalXp;
  final int currentLevelBaseXp;
  final int currentLevelProgressXp;
  final int xpRequiredForNextLevel;
  final double progressFraction;

  const XpProgress({
    required this.level,
    required this.totalXp,
    required this.currentLevelBaseXp,
    required this.currentLevelProgressXp,
    required this.xpRequiredForNextLevel,
    required this.progressFraction,
  });

  int get xpToNextLevel => xpRequiredForNextLevel - currentLevelProgressXp;

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'totalXp': totalXp,
      'currentLevelBaseXp': currentLevelBaseXp,
      'currentLevelProgressXp': currentLevelProgressXp,
      'xpRequiredForNextLevel': xpRequiredForNextLevel,
      'progressFraction': progressFraction,
    };
  }
}
