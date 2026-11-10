import '../models/rank_tier.dart';

enum MatchOutcome {
  win,
  loss,
  tie,
}

/// Detailed outcome summary of a rank calculation transition.
class RankTransitionResult {
  final VsComputerRankState previousState;
  final VsComputerRankState newState;
  final int starsDelta;
  final bool isDivisionPromotion;
  final bool isTierPromotion;
  final bool isDemotion;
  final bool shieldActivated;
  final bool shieldSaved;

  const RankTransitionResult({
    required this.previousState,
    required this.newState,
    required this.starsDelta,
    this.isDivisionPromotion = false,
    this.isTierPromotion = false,
    this.isDemotion = false,
    this.shieldActivated = false,
    this.shieldSaved = false,
  });
}

/// Pure domain logic for competitive star, division, and tier transitions.
class RankCalculator {
  /// Computes the new rank state following a completed match.
  static RankTransitionResult computeTransition({
    required VsComputerRankState current,
    required MatchOutcome outcome,
  }) {
    if (outcome == MatchOutcome.tie) {
      return RankTransitionResult(
        previousState: current,
        newState: current.copyWith(
          matchesPlayed: current.matchesPlayed + 1,
          lastPlayedAt: DateTime.now(),
        ),
        starsDelta: 0,
      );
    }

    if (outcome == MatchOutcome.win) {
      return _computeWin(current);
    } else {
      return _computeLoss(current);
    }
  }

  static RankTransitionResult _computeWin(VsComputerRankState current) {
    final newMatchesPlayed = current.matchesPlayed + 1;
    final newMatchesWon = current.matchesWon + 1;
    final newWinStreak = current.winStreak + 1;

    // Check streak bonus (+1 extra star for 3+ streak in Bronze, Silver, Gold)
    final bool getsStreakBonus = current.tier.hasStreakBonus && newWinStreak >= 3;
    final int starsToAward = getsStreakBonus ? 2 : 1;

    RankTier nextTier = current.tier;
    RankDivision nextDivision = current.division;
    int nextStars = current.stars + starsToAward;
    bool isDivisionPromo = false;
    bool isTierPromo = false;

    if (nextTier.hasDivisions) {
      // Bronze through Legend (3 stars per division)
      if (nextStars >= 3) {
        final overflowStars = nextStars - 3;
        if (nextDivision != RankDivision.I) {
          // Promote Division: III -> II or II -> I
          nextDivision = nextDivision.nextDivision!;
          nextStars = overflowStars;
          isDivisionPromo = true;
        } else {
          // Division I promo -> Next Tier Division III
          final higherTier = nextTier.nextTier;
          if (higherTier != null) {
            nextTier = higherTier;
            nextDivision = higherTier.hasDivisions ? RankDivision.III : RankDivision.I;
            nextStars = overflowStars;
            isTierPromo = true;
          } else {
            nextStars = 3; // Cap at max
          }
        }
      }
    } else if (nextTier == RankTier.master) {
      // Master tier (10 stars to Grand Master)
      if (nextStars >= 10) {
        nextTier = RankTier.grandMaster;
        nextStars = 0;
        isTierPromo = true;
      }
    }

    // Update peak tier / division
    RankTier peakT = current.peakTier;
    RankDivision peakD = current.peakDivision;
    if (nextTier.tierIndex > peakT.tierIndex) {
      peakT = nextTier;
      peakD = nextDivision;
    } else if (nextTier.tierIndex == peakT.tierIndex &&
        nextDivision.divisionNumber < peakD.divisionNumber) {
      // Lower division number = higher rank (I is higher than III)
      peakD = nextDivision;
    }

    final newState = current.copyWith(
      tier: nextTier,
      division: nextDivision,
      stars: nextStars,
      demotionShieldActive: false, // Reset shield on win
      peakTier: peakT,
      peakDivision: peakD,
      matchesPlayed: newMatchesPlayed,
      matchesWon: newMatchesWon,
      winStreak: newWinStreak,
      lastPlayedAt: DateTime.now(),
    );

    return RankTransitionResult(
      previousState: current,
      newState: newState,
      starsDelta: starsToAward,
      isDivisionPromotion: isDivisionPromo,
      isTierPromotion: isTierPromo,
    );
  }

  static RankTransitionResult _computeLoss(VsComputerRankState current) {
    final newMatchesPlayed = current.matchesPlayed + 1;
    final newMatchesWon = current.matchesWon;
    const int newWinStreak = 0;

    // Rule 1: Bronze has 0 star loss
    if (current.tier.hasZeroStarLoss) {
      return RankTransitionResult(
        previousState: current,
        newState: current.copyWith(
          matchesPlayed: newMatchesPlayed,
          matchesWon: newMatchesWon,
          winStreak: newWinStreak,
          lastPlayedAt: DateTime.now(),
        ),
        starsDelta: 0,
      );
    }

    // Rule 2: Normal star loss if stars > 0
    if (current.stars > 0) {
      return RankTransitionResult(
        previousState: current,
        newState: current.copyWith(
          stars: current.stars - 1,
          matchesPlayed: newMatchesPlayed,
          matchesWon: newMatchesWon,
          winStreak: newWinStreak,
          lastPlayedAt: DateTime.now(),
        ),
        starsDelta: -1,
      );
    }

    // Rule 3: Stars are 0 -> Check floors, shields, and demotion
    // Silver III and Gold III are absolute tier floors:
    final bool isAtAbsoluteTierFloor =
        (current.tier == RankTier.silver && current.division == RankDivision.III) ||
        (current.tier == RankTier.gold && current.division == RankDivision.III);

    if (isAtAbsoluteTierFloor) {
      return RankTransitionResult(
        previousState: current,
        newState: current.copyWith(
          stars: 0,
          matchesPlayed: newMatchesPlayed,
          matchesWon: newMatchesWon,
          winStreak: newWinStreak,
          lastPlayedAt: DateTime.now(),
        ),
        starsDelta: 0,
      );
    }

    // Rule 4: Tiers with Demotion Shield (Platinum through Master)
    if (current.tier.hasDemotionShield) {
      if (!current.demotionShieldActive) {
        // Shield absorbs the loss!
        return RankTransitionResult(
          previousState: current,
          newState: current.copyWith(
            demotionShieldActive: true,
            matchesPlayed: newMatchesPlayed,
            matchesWon: newMatchesWon,
            winStreak: newWinStreak,
            lastPlayedAt: DateTime.now(),
          ),
          starsDelta: 0,
          shieldActivated: true,
          shieldSaved: true,
        );
      }
    }

    // Rule 5: Demotion triggered (Shield already depleted or within division drop)
    RankTier demotedTier = current.tier;
    RankDivision demotedDivision = current.division;
    int demotedStars = 2; // Demote with 2 stars

    if (current.tier.hasDivisions) {
      if (current.division != RankDivision.III) {
        // Division demotion within same tier: I -> II or II -> III
        demotedDivision = current.division.previousDivision!;
      } else {
        // Tier demotion: Platinum III -> Gold I
        final lowerTier = current.tier.previousTier;
        if (lowerTier != null) {
          demotedTier = lowerTier;
          demotedDivision = RankDivision.I;
        }
      }
    } else if (current.tier == RankTier.master) {
      // Master drops to Legend I
      demotedTier = RankTier.legend;
      demotedDivision = RankDivision.I;
    } else if (current.tier == RankTier.grandMaster) {
      // Grand Master drops to Master with 9 stars
      demotedTier = RankTier.master;
      demotedStars = 9;
    }

    return RankTransitionResult(
      previousState: current,
      newState: current.copyWith(
        tier: demotedTier,
        division: demotedDivision,
        stars: demotedStars,
        demotionShieldActive: false,
        matchesPlayed: newMatchesPlayed,
        matchesWon: newMatchesWon,
        winStreak: newWinStreak,
        lastPlayedAt: DateTime.now(),
      ),
      starsDelta: -1,
      isDemotion: true,
    );
  }
}
