import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/match_config.dart';
import '../controllers/vs_computer_ranked_controller.dart';
import '../widgets/rank_emblem_widget.dart';
import '../widgets/rank_stars_widget.dart';

class VsComputerRankedSetupScreen extends ConsumerStatefulWidget {
  const VsComputerRankedSetupScreen({super.key});

  @override
  ConsumerState<VsComputerRankedSetupScreen> createState() =>
      _VsComputerRankedSetupScreenState();
}

class _VsComputerRankedSetupScreenState
    extends ConsumerState<VsComputerRankedSetupScreen> {
  final _nameController = TextEditingController(text: 'Player');

  int _selectedMaxChoice = 6;
  int? _selectedOvers; // null = unlimited
  final int _selectedTimer = 10;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(vsComputerRankedGameProvider.notifier).loadInitialData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onStartRankedMatch() {
    HapticsUtil.mediumTap();

    final config = MatchConfig(
      gameMode: GameMode.standard,
      overs: _selectedOvers,
      decisionTimerSeconds: _selectedTimer,
      seriesTargetPoints: 6,
      autoModeEnabled: false,
      maxChoice: _selectedMaxChoice,
    );

    ref.read(vsComputerRankedGameProvider.notifier).startNewRankedMatch(
          config: config,
          humanName: _nameController.text,
        );

    context.go('/vs-computer-ranked-play');
  }

  @override
  Widget build(BuildContext context) {
    final vsRankedState = ref.watch(vsComputerRankedGameProvider);
    final rank = vsRankedState.rankState;
    final xp = vsRankedState.xpProgress;
    final aiTier = vsRankedState.aiTier;

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('RANKED SOLO LADDER', style: GameTypography.headlineMedium),
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
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Current Rank Header Banner
                    _buildCurrentRankBanner(rank, xp),
                    const SizedBox(height: 20),

                    // 2. AI Opponent Card (Progression Locked)
                    _buildAiOpponentCard(aiTier),
                    const SizedBox(height: 20),

                    // 3. Player Name Input
                    _buildSectionTitle('YOUR PLAYER NAME'),
                    const SizedBox(height: 8),
                    _buildPlayerInput(),
                    const SizedBox(height: 20),

                    // 4. Number Range Selector
                    _buildSectionTitle('NUMBER SELECTION RANGE'),
                    const SizedBox(height: 8),
                    _buildNumberRangeSelector(),
                    const SizedBox(height: 20),

                    // 5. Overs per Innings
                    _buildSectionTitle('OVERS PER INNINGS'),
                    const SizedBox(height: 8),
                    _buildOversSelector(),
                    const SizedBox(height: 28),

                    // 6. Start Ranked Match CTA Button
                    _buildStartButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentRankBanner(dynamic rank, dynamic xp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GameColors.goldMetallic.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: GameColors.royalPurple.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          RankEmblemWidget(
            tier: rank.tier,
            division: rank.division,
            size: 72,
            animate: true,
            showDivisionBadge: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rank.fullRankLabel,
                      style: GameTypography.headlineMedium.copyWith(
                        color: GameColors.goldBright,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GameColors.emerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GameColors.emerald.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        'Level ${xp.level}',
                        style: GameTypography.caption.copyWith(
                          color: GameColors.emerald,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RankStarsWidget(
                  tier: rank.tier,
                  stars: rank.stars,
                  demotionShieldActive: rank.demotionShieldActive,
                  starSize: 18,
                  showLabel: true,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: xp.progressFraction,
                    minHeight: 6,
                    backgroundColor: GameColors.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(GameColors.emerald),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiOpponentCard(dynamic aiTier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GameColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: GameColors.cyanBright.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 24, color: GameColors.cyanBright),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'AI Opponent: ',
                    style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
                    children: [
                      TextSpan(
                        text: aiTier.title,
                        style: GameTypography.bodyLarge.copyWith(
                          color: GameColors.cyanBright,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aiTier.description,
                  style: GameTypography.caption.copyWith(
                    color: GameColors.textMuted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GameTypography.caption.copyWith(
        color: GameColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildPlayerInput() {
    return Container(
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GameColors.glassBorder),
      ),
      child: TextField(
        controller: _nameController,
        style: GameTypography.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Enter your name',
          hintStyle: GameTypography.bodyMedium.copyWith(color: GameColors.textMuted),
          prefixIcon: const Icon(Icons.person_rounded, color: GameColors.gold),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildNumberRangeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildChoiceChip(
            title: '1 to 6',
            subtitle: 'Standard (Default)',
            isSelected: _selectedMaxChoice == 6,
            onTap: () => setState(() => _selectedMaxChoice = 6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildChoiceChip(
            title: '1 to 10',
            subtitle: 'Extended range',
            isSelected: _selectedMaxChoice == 10,
            onTap: () => setState(() => _selectedMaxChoice = 10),
          ),
        ),
      ],
    );
  }

  Widget _buildOversSelector() {
    final options = <int?>[1, 2, 3, 5, null];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((ov) {
        final isSelected = _selectedOvers == ov;
        final label = ov == null ? 'Unlimited' : '$ov ${ov == 1 ? "Over" : "Overs"}';
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedOvers = ov),
          selectedColor: GameColors.gold,
          backgroundColor: GameColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? Colors.black : GameColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChoiceChip({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticsUtil.lightTap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? GameColors.surfaceElevated : GameColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? GameColors.gold : GameColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GameTypography.bodyLarge.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? GameColors.goldBright : GameColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GameTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _onStartRankedMatch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: GameColors.gold.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  'START RANKED MATCH',
                  style: GameTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
