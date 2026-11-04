import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/models/ball_event.dart';

class BallOutcomeDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isWicket = ballEvent.isWicket;
    final runs = ballEvent.runsScored;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: GameColors.surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isWicket ? GameColors.wicket : GameColors.emerald,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isWicket ? GameColors.wicket : GameColors.emerald).withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Outcome header banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: (isWicket ? GameColors.wicket : GameColors.emerald).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isWicket ? 'OUT! WICKET FALLEN!' : '+$runs RUNS SCORED!',
                style: GameTypography.headlineMedium.copyWith(
                  color: isWicket ? GameColors.wicket : GameColors.emerald,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Number showdown: Batter Number vs Bowler Number
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerChoiceColumn(
                  name: batterName,
                  role: 'BATTER',
                  number: ballEvent.batterNumber,
                  accentColor: GameColors.lime,
                ),
                Text(
                  'VS',
                  style: GameTypography.displayMedium.copyWith(
                    fontSize: 22,
                    color: GameColors.textMuted,
                  ),
                ),
                _buildPlayerChoiceColumn(
                  name: bowlerName,
                  role: 'BOWLER',
                  number: ballEvent.bowlerNumber,
                  accentColor: GameColors.amber,
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              isWicket
                  ? 'Numbers matched (${ballEvent.batterNumber} == ${ballEvent.bowlerNumber})! Innings over.'
                  : 'Numbers differed! Batter scores their chosen number ($runs).',
              textAlign: TextAlign.center,
              style: GameTypography.bodyMedium,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWicket ? GameColors.wicket : GameColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'CONTINUE',
                  style: GameTypography.headlineMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerChoiceColumn({
    required String name,
    required String role,
    required int number,
    required Color accentColor,
  }) {
    return Column(
      children: [
        Text(
          name,
          style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          role,
          style: GameTypography.caption.copyWith(color: accentColor),
        ),
        const SizedBox(height: 10),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: GameTypography.displayMedium.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }
}
