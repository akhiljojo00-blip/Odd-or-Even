import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/models/game_match_state.dart';

class ScoreboardCard extends StatelessWidget {
  final GameMatchState matchState;

  const ScoreboardCard({
    super.key,
    required this.matchState,
  });

  @override
  Widget build(BuildContext context) {
    final inningsNo = matchState.currentInningsNo;
    final currentScore = matchState.currentInningsRuns;
    final ballsBowled = matchState.legalBallsBowled;
    final oversStr = '${ballsBowled ~/ 6}.${ballsBowled % 6}';
    final maxOversStr = matchState.config.overs != null
        ? '${matchState.config.overs}.0'
        : '∞';

    final target = matchState.targetRuns;
    final needRuns = target != null ? target - currentScore : null;
    final ballsRemaining = matchState.config.maxBalls != null
        ? matchState.config.maxBalls! - ballsBowled
        : null;

    final chaseProgress = target != null && target > 0
        ? (currentScore / target).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF261448),
            Color(0xFF160B2C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GameColors.glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: GameColors.royalPurple.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Innings indicator & Overs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: inningsNo == 1
                      ? const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)])
                      : const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (inningsNo == 1 ? GameColors.emerald : GameColors.gold).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      inningsNo == 1 ? Icons.sports_cricket_rounded : Icons.flag_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      inningsNo == 1 ? '1ST INNINGS' : '2ND INNINGS (CHASE)',
                      style: GameTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 8, color: GameColors.cyanBright),
                    const SizedBox(width: 6),
                    Text(
                      'OVERS: $oversStr / $maxOversStr',
                      style: GameTypography.caption.copyWith(
                        color: GameColors.cyanBright,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Score: e.g. "24 / 0"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  '$currentScore',
                  key: ValueKey<int>(currentScore),
                  style: GameTypography.scoreNumber.copyWith(
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: GameColors.electricViolet.withValues(alpha: 0.6),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ 0',
                style: GameTypography.headlineLarge.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GameColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'RUNS (1 WICKET INNINGS)',
            style: GameTypography.caption.copyWith(
              color: GameColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontSize: 10.5,
            ),
          ),

          // Target or chase status
          if (target != null && inningsNo == 2) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GameColors.gold.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: GameColors.goldBright, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'TARGET: $target',
                            style: GameTypography.bodyMedium.copyWith(
                              color: GameColors.goldBright,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        needRuns != null && needRuns > 0
                            ? 'Need $needRuns runs${ballsRemaining != null ? ' in $ballsRemaining balls' : ''}'
                            : 'Target reached!',
                        style: GameTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: chaseProgress),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedValue, _) {
                        return LinearProgressIndicator(
                          value: animatedValue,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(GameColors.goldBright),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
