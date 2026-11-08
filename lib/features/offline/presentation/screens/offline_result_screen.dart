import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // Glowing Arcade Trophy / Medal Icon
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              GameColors.goldBright.withValues(alpha: 0.35),
                              GameColors.gold.withValues(alpha: 0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: GameColors.goldBright, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: GameColors.gold.withValues(alpha: 0.5),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          isSeriesFinished
                              ? Icons.military_tech_rounded
                              : (isTie ? Icons.handshake_rounded : Icons.emoji_events_rounded),
                          size: 52,
                          color: GameColors.goldBright,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title Banner
                    ShaderMask(
                      shaderCallback: (bounds) => (isTie
                              ? const LinearGradient(colors: [Colors.white, Color(0xFFCBD5E1)])
                              : GameColors.goldGradient)
                          .createShader(bounds),
                      child: Text(
                        isSeriesFinished
                            ? 'SERIES CHAMPION!'
                            : (isTie
                                ? 'MATCH TIED!'
                                : (winner != null ? '${winner.name.toUpperCase()} WINS!' : 'MATCH COMPLETED')),
                        textAlign: TextAlign.center,
                        style: GameTypography.displayLarge.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isSeriesFinished
                          ? '${match.seriesWinner?.name ?? "Winner"} won the series by reaching ${match.config.seriesTargetPoints} points!'
                          : (match.resultType?.description ?? 'Match Complete'),
                      textAlign: TextAlign.center,
                      style: GameTypography.bodyMedium.copyWith(
                        color: GameColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Match Scorecard Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: GameColors.surfaceGradient,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: GameColors.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'MATCH SCORECARD',
                            style: GameTypography.caption.copyWith(
                              letterSpacing: 1.5,
                              color: GameColors.mint,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                              Container(width: 1, height: 48, color: GameColors.glassBorder),
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
                    const SizedBox(height: 14),

                    // Series Scoreboard Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
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
                                style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              Text(
                                '${match.player1.seriesScore} Wins',
                                style: GameTypography.caption.copyWith(color: GameColors.electricViolet, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: GameColors.goldGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'SERIES GOAL: ${match.config.seriesTargetPoints}',
                              style: GameTypography.caption.copyWith(
                                color: const Color(0xFF78350F),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                match.player2.name,
                                style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              Text(
                                '${match.player2.seriesScore} Wins',
                                style: GameTypography.caption.copyWith(color: GameColors.cyanBright, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    if (!isSeriesFinished) ...[
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticsUtil.mediumTap();
                            ref.read(offlineGameProvider.notifier).requestRematch();
                            context.go('/offline-play');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF84CC16), Color(0xFF10B981)]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: GameColors.lime.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'REMATCH',
                                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.white, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticsUtil.lightTap();
                          context.go('/');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: GameColors.glassBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          isSeriesFinished ? 'FINISH & RETURN HOME' : 'MAIN MENU',
                          style: GameTypography.headlineMedium.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: GameColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const CreatorFooter(padding: EdgeInsets.only(top: 4, bottom: 2)),
                  ],
                ),
              ),
            ),
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
        Text(
          label,
          style: GameTypography.caption.copyWith(color: GameColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          '$runs',
          style: GameTypography.scoreNumber.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          role,
          style: GameTypography.caption.copyWith(color: GameColors.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
