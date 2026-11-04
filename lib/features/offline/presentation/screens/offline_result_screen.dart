import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../game/domain/models/game_enums.dart';
import '../controllers/offline_game_controller.dart';

class OfflineResultScreen extends ConsumerWidget {
  const OfflineResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(offlineGameProvider);
    final match = offlineState.match;

    final isSeriesFinished = match.phase == MatchPhase.seriesFinished;
    final winner = match.matchWinner;
    final isTie = match.resultType == MatchResultType.tie;

    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Trophy / Medal Icon
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: GameColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: GameColors.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: GameColors.gold.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isSeriesFinished
                        ? Icons.military_tech_rounded
                        : (isTie ? Icons.handshake_rounded : Icons.emoji_events_rounded),
                    size: 48,
                    color: GameColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title Banner
              Text(
                isSeriesFinished
                    ? 'SERIES CHAMPION!'
                    : (isTie ? 'MATCH TIED!' : '${winner!.name.toUpperCase()} WINS!'),
                textAlign: TextAlign.center,
                style: GameTypography.displayLarge.copyWith(
                  fontSize: 28,
                  color: isTie ? GameColors.textPrimary : GameColors.gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSeriesFinished
                    ? '${match.seriesWinner!.name} won the series by reaching ${match.config.seriesTargetPoints} points!'
                    : (match.resultType?.description ?? 'Match Complete'),
                textAlign: TextAlign.center,
                style: GameTypography.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Match Scorecard Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GameColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GameColors.glassBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      'MATCH SCORECARD',
                      style: GameTypography.caption.copyWith(
                        letterSpacing: 1.2,
                        color: GameColors.lime,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInningsStat(
                          label: '1ST INNINGS',
                          runs: match.firstInningsRuns,
                          role: match.player1.id == match.battingFirstId
                              ? match.player1.name
                              : match.player2.name,
                        ),
                        Container(width: 1, height: 40, color: GameColors.glassBorder),
                        _buildInningsStat(
                          label: '2ND INNINGS',
                          runs: match.currentInningsRuns,
                          role: match.player1.id != match.battingFirstId
                              ? match.player1.name
                              : match.player2.name,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Series Scoreboard Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GameColors.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GameColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.player1.name,
                          style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${match.player1.seriesScore} Wins',
                          style: GameTypography.caption.copyWith(color: GameColors.player1Light),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: GameColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'SERIES GOAL: ${match.config.seriesTargetPoints}',
                        style: GameTypography.caption.copyWith(
                          color: GameColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          match.player2.name,
                          style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${match.player2.seriesScore} Wins',
                          style: GameTypography.caption.copyWith(color: GameColors.player2Light),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Action buttons
              if (!isSeriesFinished) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(offlineGameProvider.notifier).requestRematch();
                      context.go('/offline-play');
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('REMATCH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.lime,
                      foregroundColor: GameColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GameColors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isSeriesFinished ? 'FINISH & RETURN HOME' : 'MAIN MENU',
                    style: GameTypography.headlineMedium.copyWith(
                      fontSize: 15,
                      color: GameColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInningsStat({
    required String label,
    required int runs,
    required String role,
  }) {
    return Column(
      children: [
        Text(label, style: GameTypography.caption),
        const SizedBox(height: 4),
        Text(
          '$runs',
          style: GameTypography.scoreNumber.copyWith(
            fontSize: 32,
            color: GameColors.textPrimary,
          ),
        ),
        Text(role, style: GameTypography.caption.copyWith(color: GameColors.textSecondary)),
      ],
    );
  }
}
