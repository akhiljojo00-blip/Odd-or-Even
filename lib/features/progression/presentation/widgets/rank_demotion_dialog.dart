import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../domain/models/rank_tier.dart';
import 'rank_emblem_widget.dart';
import 'rank_stars_widget.dart';

/// Restrained modal dialog presented when a player is demoted or their demotion shield absorbs a loss.
class RankDemotionDialog extends StatefulWidget {
  final RankTier tier;
  final RankDivision? division;
  final int stars;
  final bool shieldAbsorbed;
  final VoidCallback onDismiss;

  const RankDemotionDialog({
    super.key,
    required this.tier,
    this.division,
    required this.stars,
    this.shieldAbsorbed = false,
    required this.onDismiss,
  });

  @override
  State<RankDemotionDialog> createState() => _RankDemotionDialogState();
}

class _RankDemotionDialogState extends State<RankDemotionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    HapticsUtil.mediumTap();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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

  String get _rankLabel {
    if (widget.tier.hasDivisions && widget.division != null) {
      return '${widget.tier.displayName.toUpperCase()} ${widget.division!.label}';
    }
    return widget.tier.displayName.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isShield = widget.shieldAbsorbed;
    final accentColor = isShield ? const Color(0xFF38BDF8) : const Color(0xFFF43F5E);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1338), Color(0xFF0D061A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.5),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status Header Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isShield ? Icons.shield_rounded : Icons.trending_down_rounded,
                          size: 15,
                          color: accentColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            isShield ? 'DEMOTION SHIELD ACTIVATED' : 'RANK DEMOTION',
                            overflow: TextOverflow.ellipsis,
                            style: GameTypography.caption.copyWith(
                              fontSize: 11,
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Current Rank Emblem
                  RankEmblemWidget(
                    tier: widget.tier,
                    division: widget.division,
                    size: 88,
                    animate: false,
                    showAura: true,
                    showDivisionBadge: true,
                  ),
                  const SizedBox(height: 12),

                  // Rank Label
                  Text(
                    _rankLabel,
                    style: GameTypography.headlineMedium.copyWith(
                      color: GameColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description note
                  Text(
                    isShield
                        ? 'Loss absorbed by your Demotion Shield. Win your next match to protect your tier!'
                        : 'Your rank has been adjusted. Fight your way back to promotion!',
                    textAlign: TextAlign.center,
                    style: GameTypography.bodyMedium.copyWith(
                      color: GameColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stars Widget
                  RankStarsWidget(
                    tier: widget.tier,
                    stars: widget.stars,
                    demotionShieldActive: isShield,
                    starSize: 20,
                    showLabel: true,
                  ),
                  const SizedBox(height: 24),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        HapticsUtil.lightTap();
                        widget.onDismiss();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor.withValues(alpha: 0.8), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'CONTINUE',
                        style: GameTypography.bodyLarge.copyWith(
                          color: GameColors.textPrimary,
                          fontWeight: FontWeight.w700,
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
