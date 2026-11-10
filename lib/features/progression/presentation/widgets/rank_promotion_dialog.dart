import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../domain/models/rank_tier.dart';
import 'rank_emblem_widget.dart';
import 'rank_stars_widget.dart';

/// Modal dialog celebrating division and tier promotions in competitive play.
class RankPromotionDialog extends StatefulWidget {
  final RankTier previousTier;
  final RankDivision? previousDivision;
  final RankTier newTier;
  final RankDivision? newDivision;
  final int newStars;
  final int xpReward;
  final bool isTierPromotion;
  final VoidCallback onDismiss;

  const RankPromotionDialog({
    super.key,
    required this.previousTier,
    this.previousDivision,
    required this.newTier,
    this.newDivision,
    required this.newStars,
    this.xpReward = 50,
    this.isTierPromotion = false,
    required this.onDismiss,
  });

  @override
  State<RankPromotionDialog> createState() => _RankPromotionDialogState();
}

class _RankPromotionDialogState extends State<RankPromotionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    HapticsUtil.heavyImpact();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _newRankLabel {
    if (widget.newTier.hasDivisions && widget.newDivision != null) {
      return '${widget.newTier.displayName.toUpperCase()} ${widget.newDivision!.label}';
    }
    return widget.newTier.displayName.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF241042), Color(0xFF100522)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: GameColors.goldMetallic.withValues(alpha: 0.65),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.gold.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: GameColors.goldGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 16, color: Colors.black),
                        const SizedBox(width: 6),
                        Text(
                          widget.isTierPromotion ? 'TIER PROMOTION!' : 'PROMOTION!',
                          style: GameTypography.caption.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Rank transition display: [Old Emblem] -> [Arrow] -> [New Hero Emblem]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Old Rank
                      Opacity(
                        opacity: 0.65,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RankEmblemWidget(
                              tier: widget.previousTier,
                              division: widget.previousDivision,
                              size: 56,
                              animate: false,
                              showAura: false,
                              showDivisionBadge: true,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.previousTier.displayName,
                              style: GameTypography.caption.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Transition Arrow
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: GameColors.goldBright,
                        size: 24,
                      ),
                      const SizedBox(width: 14),

                      // New Hero Rank Emblem
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RankEmblemWidget(
                            tier: widget.newTier,
                            division: widget.newDivision,
                            size: 96,
                            animate: true,
                            showAura: true,
                            showDivisionBadge: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _newRankLabel,
                            style: GameTypography.headlineMedium.copyWith(
                              color: GameColors.goldBright,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Star progress
                  RankStarsWidget(
                    tier: widget.newTier,
                    stars: widget.newStars,
                    starSize: 22,
                    showLabel: true,
                  ),
                  const SizedBox(height: 16),

                  // XP Reward Pill
                  if (widget.xpReward > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: GameColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: GameColors.emerald.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 18, color: GameColors.emerald),
                          const SizedBox(width: 6),
                          Text(
                            '+${widget.xpReward} XP PROMOTION BONUS',
                            style: GameTypography.caption.copyWith(
                              color: GameColors.emerald,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticsUtil.lightTap();
                        widget.onDismiss();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'CONTINUE',
                        style: GameTypography.bodyLarge.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
