import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/models/rank_tier.dart';

/// Renders the star progression and demotion shield indicators for a given rank state.
class RankStarsWidget extends StatelessWidget {
  final RankTier tier;
  final int stars;
  final bool demotionShieldActive;
  final double starSize;
  final bool showLabel;

  const RankStarsWidget({
    super.key,
    required this.tier,
    required this.stars,
    this.demotionShieldActive = false,
    this.starSize = 18.0,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tier == RankTier.grandMaster) {
      return _buildGrandMasterBadge();
    }

    if (tier == RankTier.master) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: _buildMasterStars(),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: _buildStandardDivisionStars(),
    );
  }

  Widget _buildStandardDivisionStars() {
    const int maxStars = 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < maxStars; i++) ...[
          if (i > 0) SizedBox(width: starSize * 0.25),
          _buildStarIcon(isFilled: i < stars),
        ],
        if (demotionShieldActive) ...[
          SizedBox(width: starSize * 0.4),
          _buildShieldIndicator(),
        ],
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            '$stars / $maxStars',
            style: GameTypography.caption.copyWith(color: GameColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildMasterStars() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: GameColors.surfaceElevated.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameColors.gold.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: starSize * 1.1, color: GameColors.goldBright),
          const SizedBox(width: 5),
          Text(
            '$stars / 10',
            style: GameTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: GameColors.goldBright,
            ),
          ),
          if (demotionShieldActive) ...[
            const SizedBox(width: 6),
            _buildShieldIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildGrandMasterBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFFFFD700)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'APEX TOP 100',
            style: GameTypography.caption.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarIcon({required bool isFilled}) {
    if (isFilled) {
      return Icon(
        Icons.star_rounded,
        size: starSize,
        color: GameColors.goldBright,
        shadows: [
          Shadow(
            color: GameColors.gold.withValues(alpha: 0.6),
            blurRadius: 6,
          ),
        ],
      );
    } else {
      return Icon(
        Icons.star_outline_rounded,
        size: starSize,
        color: GameColors.textMuted.withValues(alpha: 0.45),
      );
    }
  }

  Widget _buildShieldIndicator() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
      ),
      child: Tooltip(
        message: 'Demotion Shield Active (1 Loss Protected)',
        child: Icon(
          Icons.shield_rounded,
          size: starSize * 0.85,
          color: const Color(0xFF38BDF8),
        ),
      ),
    );
  }
}
