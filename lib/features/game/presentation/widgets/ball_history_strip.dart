import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/models/ball_event.dart';

class BallHistoryStrip extends StatelessWidget {
  final List<BallEvent> balls;

  const BallHistoryStrip({
    super.key,
    required this.balls,
  });

  @override
  Widget build(BuildContext context) {
    if (balls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'First ball of the innings...',
          style: GameTypography.caption.copyWith(color: GameColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: balls.length,
        reverse: true, // Show most recent balls on the right / latest first
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final ball = balls[balls.length - 1 - index];
          return _buildBallBubble(ball);
        },
      ),
    );
  }

  Widget _buildBallBubble(BallEvent ball) {
    final isWicket = ball.isWicket;
    final runs = ball.runsScored;

    final Color bgColor;
    final Color textColor;
    final String label;

    if (isWicket) {
      bgColor = GameColors.wicket;
      textColor = Colors.white;
      label = 'W';
    } else if (runs == 0) {
      bgColor = GameColors.surfaceElevated;
      textColor = GameColors.textSecondary;
      label = '•';
    } else if (runs >= 6) {
      bgColor = GameColors.emerald;
      textColor = Colors.white;
      label = '$runs';
    } else {
      bgColor = GameColors.lime.withValues(alpha: 0.2);
      textColor = GameColors.lime;
      label = '$runs';
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isWicket ? Colors.white : Colors.transparent,
          width: isWicket ? 1.5 : 0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GameTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: isWicket ? 13 : 12,
        ),
      ),
    );
  }
}
