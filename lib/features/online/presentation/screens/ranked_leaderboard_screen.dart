import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../progression/domain/models/rank_tier.dart';
import '../../../progression/presentation/widgets/rank_emblem_widget.dart';
import '../../../progression/presentation/widgets/rank_stars_widget.dart';
import '../../domain/models/ranked_leaderboard_entry.dart';
import '../../domain/models/ranked_leaderboard_state.dart';
import '../controllers/ranked_leaderboard_controller.dart';

/// Screen displaying the server-authoritative Online Ranked public leaderboard.
/// Features Top 100 Grand Master highlights, user pinning, and real-time refreshes.
class RankedLeaderboardScreen extends ConsumerWidget {
  const RankedLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rankedLeaderboardProvider);
    final notifier = ref.read(rankedLeaderboardProvider.notifier);

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            HapticsUtil.lightTap();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          'RANKED LEADERBOARD',
          style: GameTypography.headlineMedium.copyWith(
            color: GameColors.goldBright,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: state.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: GameColors.goldBright),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Leaderboard',
            onPressed: state.isRefreshing
                ? null
                : () {
                    HapticsUtil.lightTap();
                    notifier.loadLeaderboard(isRefresh: true);
                  },
          ),
        ],
      ),
      bottomNavigationBar: const CreatorFooter(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: RefreshIndicator(
                color: GameColors.goldBright,
                backgroundColor: GameColors.surface,
                onRefresh: () async {
                  HapticsUtil.lightTap();
                  await notifier.loadLeaderboard(isRefresh: true);
                },
                child: state.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: GameColors.goldBright),
                      )
                    : state.errorMessage != null && state.entries.isEmpty
                        ? _buildErrorView(state.errorMessage!, notifier)
                        : _buildLeaderboardContent(context, state, notifier),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // LEADERBOARD CONTENT
  // =========================================================================

  Widget _buildLeaderboardContent(
    BuildContext context,
    RankedLeaderboardState state,
    RankedLeaderboardNotifier notifier,
  ) {
    if (state.entries.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.entries.length + 2, // 0: User Pinned Card, 1: Season Header, 2+: Entries
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildUserPinnedCard(context, state);
        }
        if (index == 1) {
          return _buildSeasonHeader(state);
        }

        final entry = state.entries[index - 2];
        final isCurrentUser = entry.userId == state.currentUserId;
        return _buildLeaderboardRow(context, entry, isCurrentUser);
      },
    );
  }

  // =========================================================================
  // USER PINNED CARD
  // =========================================================================

  Widget _buildUserPinnedCard(BuildContext context, RankedLeaderboardState state) {
    final userEntry = state.currentUserEntry;

    if (userEntry == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GameColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GameColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.military_tech_outlined, color: GameColors.goldBright, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAY RANKED TO RANK UP',
                    style: GameTypography.caption.copyWith(
                      color: GameColors.goldBright,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Complete ranked duels to earn MMR and claim your spot on the leaderboard!',
                    style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.goldBright,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                HapticsUtil.mediumTap();
                context.push('/ranked-matchmaking');
              },
              child: const Text('PLAY', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A164D), Color(0xFF170C2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameColors.goldBright, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: GameColors.goldBright.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Position Badge
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: GameColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              '#${userEntry.leaderboardRank}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User Emblem & Details
          RankEmblemWidget(
            tier: userEntry.tier,
            division: userEntry.division,
            size: 40,
            animate: false,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userEntry.displayName,
                      style: GameTypography.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: GameColors.goldBright.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GameColors.goldBright, width: 1),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: GameColors.goldBright,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${userEntry.fullRankLabel} • ${userEntry.mmr} MMR',
                  style: GameTypography.caption.copyWith(color: GameColors.textSecondary),
                ),
              ],
            ),
          ),

          // Win Rate Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${userEntry.winRate.toStringAsFixed(0)}% WIN',
                style: GameTypography.caption.copyWith(
                  color: GameColors.emerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${userEntry.totalRankedWins}W - ${userEntry.totalRankedMatches - userEntry.totalRankedWins}L',
                style: GameTypography.caption.copyWith(
                  color: GameColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SEASON HEADER
  // =========================================================================

  Widget _buildSeasonHeader(RankedLeaderboardState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: GameColors.goldBright, size: 18),
              const SizedBox(width: 6),
              Text(
                'TOP 100 DUELISTS',
                style: GameTypography.caption.copyWith(
                  color: GameColors.goldBright,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          if (state.grandMasterCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GameColors.goldBright.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GameColors.goldBright.withValues(alpha: 0.6)),
              ),
              child: Text(
                '${state.grandMasterCount} GRAND MASTERS',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: GameColors.goldBright,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // LEADERBOARD ROW
  // =========================================================================

  Widget _buildLeaderboardRow(
    BuildContext context,
    RankedLeaderboardEntry entry,
    bool isCurrentUser,
  ) {
    final rank = entry.leaderboardRank;
    final isTop3 = rank <= 3;
    final isGrandMaster = entry.tier == RankTier.grandMaster;

    final Color rankColor;
    if (rank == 1) {
      rankColor = GameColors.goldBright;
    } else if (rank == 2) {
      rankColor = const Color(0xFFE2E8F0); // Silver
    } else if (rank == 3) {
      rankColor = const Color(0xFFF97316); // Bronze / Amber
    } else {
      rankColor = GameColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? GameColors.royalPurple.withValues(alpha: 0.4)
            : GameColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? GameColors.goldBright.withValues(alpha: 0.8)
              : isGrandMaster
                  ? GameColors.goldMetallic.withValues(alpha: 0.5)
                  : GameColors.glassBorder,
          width: isCurrentUser || isGrandMaster ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Leaderboard Position
          SizedBox(
            width: 36,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rankColor,
                fontWeight: isTop3 ? FontWeight.w900 : FontWeight.w700,
                fontSize: isTop3 ? 16 : 14,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Rank Emblem
          RankEmblemWidget(
            tier: entry.tier,
            division: entry.division,
            size: 34,
            animate: false,
          ),
          const SizedBox(width: 12),

          // Player Name & Rank Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTypography.bodyLarge.copyWith(
                          color: isCurrentUser ? GameColors.goldBright : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: GameColors.goldBright.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: GameColors.goldBright,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      entry.fullRankLabel,
                      style: GameTypography.caption.copyWith(
                        color: isGrandMaster ? GameColors.goldBright : GameColors.textSecondary,
                        fontWeight: isGrandMaster ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    if (entry.tier.hasDivisions || entry.tier == RankTier.master) ...[
                      const SizedBox(width: 6),
                      RankStarsWidget(
                        tier: entry.tier,
                        stars: entry.stars,
                        starSize: 12,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // MMR & Win Count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.mmr} MMR',
                style: GameTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                '${entry.totalRankedWins}W (${entry.winRate.toStringAsFixed(0)}%)',
                style: GameTypography.caption.copyWith(
                  color: GameColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EMPTY & ERROR STATES
  // =========================================================================

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, color: GameColors.goldBright, size: 64),
            const SizedBox(height: 16),
            Text(
              'SEASON 1 COMMENCING',
              style: GameTypography.headlineMedium.copyWith(
                color: GameColors.goldBright,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No ranked duels completed yet. Play your first match to claim the #1 spot on the leaderboard!',
              textAlign: TextAlign.center,
              style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.goldBright,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                HapticsUtil.mediumTap();
                context.push('/ranked-matchmaking');
              },
              child: const Text('PLAY ONLINE RANKED', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message, RankedLeaderboardNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: GameColors.wicket, size: 56),
            const SizedBox(height: 16),
            Text(
              'FAILED TO LOAD',
              style: GameTypography.headlineMedium.copyWith(color: GameColors.wicket),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GameTypography.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.goldBright,
                foregroundColor: Colors.black,
              ),
              onPressed: () => notifier.loadLeaderboard(),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}
