import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../data/match_history_repository.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'ALL';

  final List<String> _filters = [
    'ALL',
    'SOLO RANKED',
    'CASUAL AI',
    'PASS & PLAY',
    'ONLINE',
  ];

  bool _matchesFilter(MatchHistoryRecord rec) {
    if (_selectedFilter == 'ALL') return true;
    final label = rec.modeLabel.toUpperCase();
    if (_selectedFilter == 'SOLO RANKED') {
      return label.contains('RANKED');
    }
    if (_selectedFilter == 'CASUAL AI') {
      return label.contains('CASUAL') || (label.contains('COMPUTER') && !label.contains('RANKED'));
    }
    if (_selectedFilter == 'PASS & PLAY') {
      return label.contains('PASS');
    }
    if (_selectedFilter == 'ONLINE') {
      return label.contains('ONLINE') || label.contains('ROOM');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(matchHistoryListProvider);

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('MATCH HISTORY', style: GameTypography.headlineMedium.copyWith(letterSpacing: 1.5)),
        centerTitle: true,
      ),
      bottomNavigationBar: const CreatorFooter(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  // Filter Chips Bar
                  Container(
                    height: 48,
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final filter = _filters[idx];
                        final isSelected = _selectedFilter == filter;
                        return ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) {
                            HapticsUtil.lightTap();
                            setState(() => _selectedFilter = filter);
                          },
                          selectedColor: GameColors.gold,
                          backgroundColor: GameColors.surface,
                          side: BorderSide(
                            color: isSelected ? GameColors.goldBright : GameColors.glassBorder,
                          ),
                          labelStyle: GameTypography.caption.copyWith(
                            color: isSelected ? Colors.black : GameColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        );
                      },
                    ),
                  ),

                  // History Content
                  Expanded(
                    child: historyAsync.when(
                      data: (records) {
                        final filtered = records.where(_matchesFilter).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.history_toggle_off_rounded,
                                    size: 64,
                                    color: GameColors.textMuted,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No matches played yet',
                                    style: GameTypography.headlineMedium.copyWith(color: GameColors.textMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _selectedFilter == 'ALL'
                                        ? 'Play an offline or online match to see stats here'
                                        : 'No matches found under $_selectedFilter mode',
                                    style: GameTypography.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final rec = filtered[index];
                            final dateStr =
                                '${rec.playedAt.day.toString().padLeft(2, '0')}/${rec.playedAt.month.toString().padLeft(2, '0')}/${rec.playedAt.year}';

                            final isRanked = rec.modeLabel.contains('Ranked');
                            final badgeColor = isRanked
                                ? GameColors.goldBright
                                : (rec.modeLabel.contains('Online')
                                    ? GameColors.electricViolet
                                    : GameColors.cyanBright);

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
                                  // Top metadata row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          rec.modeLabel.toUpperCase(),
                                          style: GameTypography.caption.copyWith(
                                            color: badgeColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9.5,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Text(dateStr, style: GameTypography.caption),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Scores
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rec.player1Name,
                                          style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${rec.firstInningsRuns} runs',
                                        style: GameTypography.bodyMedium.copyWith(
                                          color: GameColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rec.player2Name,
                                          style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${rec.secondInningsRuns} runs',
                                        style: GameTypography.bodyMedium.copyWith(
                                          color: GameColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Winner & Result summary
                                  const Divider(color: GameColors.glassBorder, height: 20),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.emoji_events_rounded, size: 15, color: GameColors.gold),
                                          const SizedBox(width: 6),
                                          Text(
                                            rec.winnerName != null
                                                ? 'Winner: ${rec.winnerName}'
                                                : 'Draw / Tied',
                                            style: GameTypography.caption.copyWith(
                                              color: GameColors.gold,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        rec.resultSummary,
                                        style: GameTypography.caption.copyWith(
                                          color: GameColors.textMuted,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: GameColors.lime),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading history: $err',
                          style: GameTypography.bodyMedium,
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
