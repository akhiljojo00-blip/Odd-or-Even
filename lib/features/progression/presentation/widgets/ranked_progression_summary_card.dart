import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/logic/rank_calculator.dart';
import '../../domain/logic/xp_calculator.dart';
import '../../domain/models/rank_tier.dart';
import '../../domain/models/xp_progress.dart';
import 'rank_emblem_widget.dart';
import 'rank_stars_widget.dart';

/// Embedded summary card displayed inside MatchResultView for VS Computer Ranked matches.
class RankedProgressionSummaryCard extends StatelessWidget {
  final VsComputerRankState rankState;
  final RankTransitionResult? transitionResult;
  final XpCalculationResult? xpResult;

  const RankedProgressionSummaryCard({
    super.key,
    required this.rankState,
    this.transitionResult,
    this.xpResult,
  });

  @override
  Widget build(BuildContext context) {
    final starsDelta = transitionResult?.starsDelta ?? 0;
    final shieldSaved = transitionResult?.shieldSaved ?? false;
    final isStreak = transitionResult != null &&
        transitionResult!.newState.winStreak >= 3 &&
        starsDelta > 1;

    final xpAwarded = xpResult?.totalXpAwarded ?? 0;
    final xpProg = xpResult?.newProgress ?? XpEconomy.calculateProgress(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.goldMetallic.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RANK PROGRESSION',
                style: GameTypography.caption.copyWith(
                  fontWeight: FontWeight.w900,
                  color: GameColors.goldBright,
                  letterSpacing: 1.0,
                ),
              ),
              if (xpAwarded > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: GameColors.emerald.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GameColors.emerald.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '+$xpAwarded XP',
                    style: GameTypography.caption.copyWith(
                      color: GameColors.emerald,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Emblem & Rank Status Row
          Row(
            children: [
              RankEmblemWidget(
                tier: rankState.tier,
                division: rankState.division,
                size: 58,
                animate: false,
                showAura: false,
                showDivisionBadge: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rankState.fullRankLabel,
                      style: GameTypography.headlineMedium.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GameColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RankStarsWidget(
                      tier: rankState.tier,
                      stars: rankState.stars,
                      demotionShieldActive: rankState.demotionShieldActive,
                      starSize: 16,
                      showLabel: true,
                    ),
                  ],
                ),
              ),

              // Star Delta Pill
              _buildStarDeltaPill(starsDelta, shieldSaved, isStreak),
            ],
          ),
          const SizedBox(height: 14),

          // XP & Level Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level ${xpProg.level}',
                    style: GameTypography.caption.copyWith(
                      color: GameColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${xpProg.currentLevelProgressXp} / ${xpProg.xpRequiredForNextLevel} XP',
                    style: GameTypography.caption.copyWith(
                      color: GameColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: xpProg.progressFraction,
                  minHeight: 8,
                  backgroundColor: GameColors.surfaceElevated,
                  valueColor: const AlwaysStoppedAnimation<Color>(GameColors.emerald),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarDeltaPill(int starsDelta, bool shieldSaved, bool isStreak) {
    if (shieldSaved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF38BDF8)),
            const SizedBox(width: 4),
            Text(
              'Protected',
              style: GameTypography.caption.copyWith(
                color: const Color(0xFF38BDF8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    if (starsDelta > 0) {
      final text = isStreak ? '+$starsDelta (Streak!)' : '+$starsDelta';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: GameColors.gold.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GameColors.gold.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 14, color: GameColors.goldBright),
            const SizedBox(width: 4),
            Text(
              text,
              style: GameTypography.caption.copyWith(
                color: GameColors.goldBright,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    } else if (starsDelta < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: GameColors.wicket.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GameColors.wicket.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_outline_rounded, size: 14, color: GameColors.wicket),
            const SizedBox(width: 4),
            Text(
              '$starsDelta Star',
              style: GameTypography.caption.copyWith(
                color: GameColors.wicket,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: GameColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GameColors.glassBorder),
        ),
        child: Text(
          '0 Stars',
          style: GameTypography.caption.copyWith(
            color: GameColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
  }
}
