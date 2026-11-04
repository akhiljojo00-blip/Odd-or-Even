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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.surfaceElevated.withOpacity(0.8),
            GameColors.surface.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GameColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GameColors.emerald.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GameColors.emerald.withOpacity(0.5)),
                ),
                child: Text(
                  inningsNo == 1 ? '1ST INNINGS' : '2ND INNINGS (CHASE)',
                  style: GameTypography.caption.copyWith(
                    color: GameColors.emerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'OVERS: $oversStr / $maxOversStr',
                style: GameTypography.caption.copyWith(
                  color: GameColors.textSecondary,
                  letterSpacing: 1.0,
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
              Text(
                '$currentScore',
                style: GameTypography.scoreNumber.copyWith(
                  fontSize: 56,
                  color: GameColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ 0',
                style: GameTypography.headlineLarge.copyWith(
                  fontSize: 28,
                  color: GameColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'RUNS (1 WICKET INNINGS)',
            style: GameTypography.caption.copyWith(
              color: GameColors.textMuted,
              fontSize: 11,
            ),
          ),

          // Target or chase status
          if (target != null && inningsNo == 2) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: GameColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GameColors.gold.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: GameColors.gold, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'TARGET: $target',
                        style: GameTypography.bodyMedium.copyWith(
                          color: GameColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    needRuns != null && needRuns > 0
                        ? 'Need $needRuns runs${ballsRemaining != null ? ' in $ballsRemaining balls' : ''}'
                        : 'Target reached!',
                    style: GameTypography.caption.copyWith(
                      color: GameColors.textPrimary,
                      fontWeight: FontWeight.w600,
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
