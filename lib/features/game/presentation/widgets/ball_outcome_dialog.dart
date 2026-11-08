import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../domain/models/ball_event.dart';

class BallOutcomeDialog extends StatefulWidget {
  final BallEvent ballEvent;
  final String batterName;
  final String bowlerName;
  final VoidCallback onDismiss;

  const BallOutcomeDialog({
    super.key,
    required this.ballEvent,
    required this.batterName,
    required this.bowlerName,
    required this.onDismiss,
  });

  @override
  State<BallOutcomeDialog> createState() => _BallOutcomeDialogState();
}

class _BallOutcomeDialogState extends State<BallOutcomeDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
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

  @override
  Widget build(BuildContext context) {
    final isWicket = widget.ballEvent.isWicket;
    final runs = widget.ballEvent.runsScored;
    final accentColor = isWicket ? GameColors.wicket : GameColors.emerald;

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF261348), Color(0xFF140827)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isWicket ? GameColors.wicket : GameColors.mint,
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isWicket ? GameColors.wicket : GameColors.emerald).withValues(alpha: 0.45),
                  blurRadius: 36,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Outcome Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isWicket
                        ? GameColors.wicketGradient
                        : const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.5),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWicket ? Icons.dangerous_rounded : Icons.sports_cricket_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isWicket ? 'OUT! WICKET FALLEN!' : '+$runs RUNS SCORED!',
                        style: GameTypography.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 17,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Number showdown: Batter Number vs Bowler Number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPlayerChoiceColumn(
                      name: widget.batterName,
                      role: 'BATTER',
                      roleIcon: Icons.sports_cricket,
                      number: widget.ballEvent.batterNumber,
                      accentColor: GameColors.mint,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GameColors.surface,
                            border: Border.all(color: GameColors.glassBorder, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'VS',
                            style: GameTypography.displayMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: GameColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildPlayerChoiceColumn(
                      name: widget.bowlerName,
                      role: 'BOWLER',
                      roleIcon: Icons.sports_baseball,
                      number: widget.ballEvent.bowlerNumber,
                      accentColor: GameColors.goldBright,
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Explanatory outcome text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isWicket
                        ? 'Numbers matched (${widget.ballEvent.batterNumber} == ${widget.ballEvent.bowlerNumber})! Batter is OUT.'
                        : 'Numbers differed! Batter scores their chosen number ($runs).',
                    textAlign: TextAlign.center,
                    style: GameTypography.bodyMedium.copyWith(
                      color: GameColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticsUtil.mediumTap();
                      widget.onDismiss();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: isWicket
                            ? GameColors.wicketGradient
                            : const LinearGradient(
                                colors: [Color(0xFF84CC16), Color(0xFF10B981)],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'CONTINUE',
                          style: GameTypography.headlineMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerChoiceColumn({
    required String name,
    required String role,
    required IconData roleIcon,
    required int number,
    required Color accentColor,
  }) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            name,
            style: GameTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roleIcon, size: 12, color: accentColor),
            const SizedBox(width: 4),
            Text(
              role,
              style: GameTypography.caption.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                accentColor.withValues(alpha: 0.35),
                accentColor.withValues(alpha: 0.1),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: GameTypography.displayMedium.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(color: accentColor, blurRadius: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
