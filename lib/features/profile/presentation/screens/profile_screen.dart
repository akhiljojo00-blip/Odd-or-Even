import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../history/data/match_history_repository.dart';
import '../../../progression/domain/models/xp_progress.dart';
import '../../../progression/presentation/widgets/rank_emblem_widget.dart';
import '../../../progression/presentation/widgets/rank_stars_widget.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  int _avatarIndex = 0;
  bool _initialized = false;

  final List<IconData> _avatarIcons = const [
    Icons.sports_cricket,
    Icons.sports_baseball,
    Icons.emoji_events,
    Icons.bolt,
    Icons.shield,
    Icons.military_tech,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Player 1');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncWithState(ProfileProgressionState state) {
    if (!_initialized && !state.isLoading) {
      _nameController.text = state.displayName;
      _avatarIndex = state.avatarIndex;
      _initialized = true;
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    HapticsUtil.mediumTap();
    final success = await ref
        .read(profileProgressionProvider.notifier)
        .saveProfile(name, _avatarIndex);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Profile updated successfully!' : 'Failed to save profile.',
          ),
          backgroundColor: success ? GameColors.emerald : GameColors.wicket,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProgressionProvider);
    _syncWithState(profileState);

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'PLAYER PROFILE',
          style: GameTypography.headlineMedium.copyWith(letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: GameColors.textSecondary),
            tooltip: 'Refresh Profile',
            onPressed: () {
              HapticsUtil.lightTap();
              ref.read(profileProgressionProvider.notifier).loadProfile();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWidescreen = constraints.maxWidth >= 900;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWidescreen ? 1040 : 540),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: isWidescreen
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Identity, Level & Ranks
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildIdentityCard(profileState),
                                    const SizedBox(height: 18),
                                    _buildLevelProgressCard(profileState.xpProgress, profileState.dailyXpEarned),
                                    const SizedBox(height: 18),
                                    _buildRanksSection(profileState),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Right Column: Career Stats & Match History
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildCareerStatsSection(profileState),
                                    const SizedBox(height: 18),
                                    _buildRecentMatchesCard(profileState.matchHistory),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildIdentityCard(profileState),
                              const SizedBox(height: 18),
                              _buildLevelProgressCard(profileState.xpProgress, profileState.dailyXpEarned),
                              const SizedBox(height: 18),
                              _buildRanksSection(profileState),
                              const SizedBox(height: 22),
                              _buildCareerStatsSection(profileState),
                              const SizedBox(height: 22),
                              _buildRecentMatchesCard(profileState.matchHistory),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. IDENTITY & AVATAR CARD
  // =========================================================================
  Widget _buildIdentityCard(ProfileProgressionState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Active Avatar Circle
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    GameColors.lime.withValues(alpha: 0.3),
                    GameColors.surfaceElevated,
                  ],
                ),
                border: Border.all(color: GameColors.lime, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.lime.withValues(alpha: 0.25),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(
                _avatarIcons[_avatarIndex % _avatarIcons.length],
                size: 44,
                color: GameColors.lime,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Avatar Icon Selector Carousel
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_avatarIcons.length, (idx) {
              final isSelected = _avatarIndex == idx;
              return GestureDetector(
                onTap: () {
                  HapticsUtil.lightTap();
                  setState(() => _avatarIndex = idx);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? GameColors.lime : GameColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? GameColors.lime : GameColors.glassBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _avatarIcons[idx],
                    size: 18,
                    color: isSelected ? GameColors.background : GameColors.textSecondary,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Display Name Field
          TextField(
            controller: _nameController,
            style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle: const TextStyle(color: GameColors.lime),
              prefixIcon: const Icon(Icons.person_rounded, color: GameColors.lime, size: 20),
              filled: true,
              fillColor: GameColors.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: GameColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: GameColors.lime, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Save Profile Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [GameColors.lime, GameColors.cyanBright],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.lime.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: state.isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: GameColors.background,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: state.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: GameColors.background),
                      )
                    : Text(
                        'SAVE PROFILE',
                        style: GameTypography.headlineMedium.copyWith(
                          fontSize: 16,
                          color: GameColors.background,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. PLAYER LEVEL & XP PROGRESS CARD
  // =========================================================================
  Widget _buildLevelProgressCard(XpProgress xp, int dailyXp) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Level Title & Cap Row with Wrap to prevent RenderFlex overflow
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'LEVEL ${xp.level}',
                      style: GameTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${xp.totalXp} Total XP',
                    style: GameTypography.caption.copyWith(color: GameColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: GameColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GameColors.glassBorder),
                ),
                child: Text(
                  'Daily: $dailyXp / ${XpEconomy.maxDailyXpCap} XP',
                  style: GameTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: GameColors.goldBright,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: xp.progressFraction,
              minHeight: 10,
              backgroundColor: GameColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(GameColors.emerald),
            ),
          ),
          const SizedBox(height: 8),

          // XP Subtitle with Wrap
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${xp.currentLevelProgressXp} / ${xp.xpRequiredForNextLevel} XP',
                style: GameTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: GameColors.mint,
                ),
              ),
              Text(
                '${xp.xpToNextLevel} XP to Level ${xp.level + 1}',
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
  // 3. COMPETITIVE RANKS (SOLO & ONLINE)
  // =========================================================================
  Widget _buildRanksSection(ProfileProgressionState state) {
    final rank = state.vsRankState;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameColors.goldMetallic.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: GameColors.royalPurple.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'COMPETITIVE RANKS',
                style: GameTypography.caption.copyWith(
                  letterSpacing: 1.2,
                  color: GameColors.goldBright,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: GameColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GameColors.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'SOLO LADDER',
                  style: GameTypography.caption.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: GameColors.goldBright,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Solo Ranked Card
          Row(
            children: [
              RankEmblemWidget(
                tier: rank.tier,
                division: rank.division,
                size: 58,
                animate: true,
                showDivisionBadge: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.fullRankLabel,
                      style: GameTypography.headlineMedium.copyWith(
                        color: GameColors.goldBright,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    RankStarsWidget(
                      tier: rank.tier,
                      stars: rank.stars,
                      demotionShieldActive: rank.demotionShieldActive,
                      starSize: 16,
                      showLabel: true,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildSmallPill(
                          'Peak: ${rank.peakTier.displayName} ${rank.peakDivision.label}',
                          GameColors.cyanBright,
                        ),
                        if (rank.winStreak > 1)
                          _buildSmallPill(
                            'Streak: ${rank.winStreak}W',
                            GameColors.lime,
                          ),
                        if (rank.demotionShieldActive)
                          _buildSmallPill(
                            'Shield Protected',
                            const Color(0xFF38BDF8),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: GameColors.glassBorder, height: 26),

          // Online Ranked Section (Authoritative Zero Client Trust)
          _buildOnlineRankedCard(state),
        ],
      ),
    );
  }

  Widget _buildOnlineRankedCard(ProfileProgressionState state) {
    final onlineRank = state.onlineRank;

    if (onlineRank == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'ONLINE MULTIPLAYER',
                style: GameTypography.caption.copyWith(
                  color: GameColors.goldBright,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  HapticsUtil.lightTap();
                  context.push('/ranked-leaderboard');
                },
                icon: const Icon(Icons.emoji_events_outlined, size: 14, color: GameColors.goldBright),
                label: Text(
                  'LEADERBOARD',
                  style: GameTypography.caption.copyWith(
                    color: GameColors.goldBright,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'UNRANKED',
            style: GameTypography.headlineMedium.copyWith(
              color: GameColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.isOnlineConfigured
                ? 'Season 1 active. Play your first ranked match to calibrate your rank and MMR!'
                : 'Offline Mode (Local Play). Connect online to access the ranked ladder.',
            style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.goldBright,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              HapticsUtil.mediumTap();
              context.push('/ranked-matchmaking');
            },
            child: const Text('ENTER RANKED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      );
    }

    final divLabel = onlineRank.tier.hasDivisions && onlineRank.division != null
        ? ' ${onlineRank.division!.label}'
        : '';
    final fullLabel = '${onlineRank.tier.displayName.toUpperCase()}$divLabel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'ONLINE MULTIPLAYER',
              style: GameTypography.caption.copyWith(
                color: GameColors.goldBright,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                HapticsUtil.lightTap();
                context.push('/ranked-leaderboard');
              },
              icon: const Icon(Icons.emoji_events_outlined, size: 14, color: GameColors.goldBright),
              label: Text(
                'LEADERBOARD',
                style: GameTypography.caption.copyWith(
                  color: GameColors.goldBright,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            RankEmblemWidget(
              tier: onlineRank.tier,
              division: onlineRank.division,
              size: 52,
              animate: false,
              showDivisionBadge: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullLabel,
                    style: GameTypography.headlineMedium.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RankStarsWidget(
                    tier: onlineRank.tier,
                    stars: onlineRank.stars,
                    demotionShieldActive: onlineRank.demotionShieldActive,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildSmallPill('${onlineRank.mmr} MMR', GameColors.goldBright),
                      _buildSmallPill(
                        'Peak: ${onlineRank.peakTier.displayName} ${onlineRank.peakDivision?.label ?? ''}'.trim(),
                        GameColors.textSecondary,
                      ),
                      if (onlineRank.winStreak > 1)
                        _buildSmallPill('Streak: ${onlineRank.winStreak}W', GameColors.emerald),
                      if (onlineRank.totalRankedMatches > 0)
                        _buildSmallPill(
                          '${onlineRank.winRate.toStringAsFixed(0)}% Win (${onlineRank.totalRankedWins}W-${onlineRank.totalRankedLosses}L)',
                          GameColors.cyanBright,
                        ),
                      if (onlineRank.demotionShieldActive)
                        _buildSmallPill('Shield Protected', const Color(0xFF38BDF8)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GameTypography.caption.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // =========================================================================
  // 4. CAREER STATISTICS DASHBOARD
  // =========================================================================
  Widget _buildCareerStatsSection(ProfileProgressionState state) {
    final stats = state.currentStats;
    final winRate = stats.matchesPlayed > 0
        ? stats.winRate.toStringAsFixed(1)
        : '0.0';

    final modes = <Map<String, String>>[
      {'id': 'all', 'label': 'ALL MODES'},
      {'id': 'vs_computer_ranked', 'label': 'SOLO RANKED'},
      {'id': 'casual_vs_computer', 'label': 'CASUAL AI'},
      {'id': 'pass_and_play', 'label': 'PASS & PLAY'},
      {'id': 'online', 'label': 'ONLINE'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title matching existing widget tests exactly
        Text(
          'CAREER STATISTICS',
          style: GameTypography.caption.copyWith(
            letterSpacing: 1.2,
            color: GameColors.lime,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // Mode Filter Tabs
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: modes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final m = modes[idx];
              final isSelected = state.selectedStatsMode == m['id'];
              return ChoiceChip(
                label: Text(m['label']!),
                selected: isSelected,
                onSelected: (_) {
                  HapticsUtil.lightTap();
                  ref.read(profileProgressionProvider.notifier).setStatsMode(m['id']!);
                },
                selectedColor: GameColors.lime,
                backgroundColor: GameColors.surface,
                side: BorderSide(
                  color: isSelected ? GameColors.lime : GameColors.glassBorder,
                ),
                labelStyle: GameTypography.caption.copyWith(
                  color: isSelected ? GameColors.background : GameColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 10.5,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Primary 4-Stat Box (Matches, Wins, Losses, Tied)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: GameColors.surfaceGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GameColors.glassBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatItem('MATCHES', '${stats.matchesPlayed}', GameColors.textPrimary)),
                  Expanded(child: _buildStatItem('WINS', '${stats.matchesWon}', GameColors.lime)),
                  Expanded(child: _buildStatItem('LOSSES', '${stats.matchesLost}', GameColors.wicket)),
                  Expanded(child: _buildStatItem('TIED', '${stats.matchesTied}', GameColors.gold)),
                ],
              ),
              const Divider(color: GameColors.glassBorder, height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('WIN RATE', style: GameTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                  Text('$winRate%', style: GameTypography.headlineMedium.copyWith(color: GameColors.lime)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Advanced Performance Records (Runs, Wickets, High Score, Best Chase, Streaks)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GameColors.surfaceElevated.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GameColors.glassBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatItem('RUNS', '${stats.totalRuns}', GameColors.cyanBright)),
                  Expanded(child: _buildStatItem('WICKETS', '${stats.totalWickets}', GameColors.coral)),
                  Expanded(child: _buildStatItem('HIGH SCORE', '${stats.highestScore}', GameColors.goldBright)),
                ],
              ),
              const Divider(color: GameColors.glassBorder, height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'BEST CHASE',
                      stats.bestChase != null ? '${stats.bestChase}' : '-',
                      GameColors.mint,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'STREAK',
                      stats.currentStreak >= 0 ? '+${stats.currentStreak} W' : '${stats.currentStreak} L',
                      stats.currentStreak >= 0 ? GameColors.lime : GameColors.wicket,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'BEST STREAK',
                      '${stats.longestWinStreak} W',
                      GameColors.goldBright,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GameTypography.scoreNumber.copyWith(fontSize: 22, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GameTypography.caption.copyWith(fontSize: 10, letterSpacing: 0.5)),
      ],
    );
  }

  // =========================================================================
  // 5. RECENT MATCHES PREVIEW
  // =========================================================================
  Widget _buildRecentMatchesCard(List<MatchHistoryRecord> history) {
    final recent = history.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'RECENT MATCHES',
                style: GameTypography.caption.copyWith(
                  letterSpacing: 1.0,
                  color: GameColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              InkWell(
                onTap: () {
                  HapticsUtil.lightTap();
                  context.push('/history');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text(
                    'VIEW ALL',
                    style: TextStyle(
                      color: GameColors.cyanBright,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No recent matches played yet.',
                  style: GameTypography.caption.copyWith(color: GameColors.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final rec = recent[idx];
                final isWin = rec.winnerName != null &&
                    !rec.winnerName!.toLowerCase().contains('ai') &&
                    !rec.winnerName!.toLowerCase().contains('computer');

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: GameColors.surfaceElevated.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GameColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.modeLabel.toUpperCase(),
                              style: GameTypography.caption.copyWith(
                                fontSize: 9.5,
                                color: GameColors.goldBright,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${rec.player1Name} vs ${rec.player2Name}',
                              style: GameTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${rec.firstInningsRuns} - ${rec.secondInningsRuns}',
                            style: GameTypography.headlineMedium.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rec.winnerName != null ? (isWin ? 'VICTORY' : 'DEFEAT') : 'TIED',
                            style: GameTypography.caption.copyWith(
                              fontSize: 9.5,
                              color: rec.winnerName != null
                                  ? (isWin ? GameColors.lime : GameColors.wicket)
                                  : GameColors.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
