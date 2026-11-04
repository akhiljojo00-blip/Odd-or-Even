import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../data/match_history_repository.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(matchHistoryListProvider);

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('MATCH HISTORY', style: GameTypography.headlineMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: historyAsync.when(
          data: (records) {
            if (records.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, size: 64, color: GameColors.textMuted),
                    const SizedBox(height: 16),
                    Text('No matches played yet', style: GameTypography.headlineMedium.copyWith(color: GameColors.textMuted)),
                    const SizedBox(height: 6),
                    Text('Play an offline or online match to see stats here', style: GameTypography.caption),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final rec = records[index];
                final dateStr = '${rec.playedAt.day}/${rec.playedAt.month}/${rec.playedAt.year}';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GameColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GameColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            rec.resultSummary.toUpperCase(),
                            style: GameTypography.caption.copyWith(
                              color: GameColors.lime,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(dateStr, style: GameTypography.caption),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            rec.player1Name,
                            style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${rec.firstInningsRuns} runs',
                            style: GameTypography.bodyMedium.copyWith(color: GameColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            rec.player2Name,
                            style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${rec.secondInningsRuns} runs',
                            style: GameTypography.bodyMedium.copyWith(color: GameColors.textPrimary),
                          ),
                        ],
                      ),
                      if (rec.winnerName != null) ...[
                        const Divider(color: GameColors.glassBorder, height: 18),
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 14, color: GameColors.gold),
                            const SizedBox(width: 6),
                            Text(
                              'Winner: ${rec.winnerName}',
                              style: GameTypography.caption.copyWith(
                                color: GameColors.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: GameColors.lime)),
          error: (err, _) => Center(child: Text('Error loading history: $err', style: GameTypography.bodyMedium)),
        ),
      ),
    );
  }
}
