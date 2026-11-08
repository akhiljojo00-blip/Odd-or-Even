import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../game/domain/ai/computer_player_strategy.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/match_config.dart';
import '../controllers/vs_computer_game_controller.dart';

class VsComputerSetupScreen extends ConsumerStatefulWidget {
  const VsComputerSetupScreen({super.key});

  @override
  ConsumerState<VsComputerSetupScreen> createState() => _VsComputerSetupScreenState();
}

class _VsComputerSetupScreenState extends ConsumerState<VsComputerSetupScreen> {
  final _nameController = TextEditingController(text: 'Player');

  AiDifficulty _selectedDifficulty = AiDifficulty.medium;
  int _selectedMaxChoice = 6;
  GameMode _selectedMode = GameMode.standard;
  int? _selectedOvers; // null = unlimited
  int _selectedTimer = 10;
  int _selectedSeriesTarget = 6;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onStartMatch() {
    final config = MatchConfig(
      gameMode: _selectedMode,
      overs: _selectedOvers,
      decisionTimerSeconds: _selectedTimer,
      seriesTargetPoints: _selectedSeriesTarget,
      autoModeEnabled: _selectedMode == GameMode.fast,
      maxChoice: _selectedMaxChoice,
    );

    ref.read(vsComputerGameProvider.notifier).startNewGame(
          config: config,
          difficulty: _selectedDifficulty,
          humanName: _nameController.text,
        );

    context.go('/vs-computer-play');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('VS COMPUTER SETUP', style: GameTypography.headlineMedium),
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
                    _buildSectionTitle('YOUR PLAYER NAME'),
                    const SizedBox(height: 10),
                    _buildPlayerInput(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('AI DIFFICULTY'),
                    const SizedBox(height: 10),
                    _buildDifficultySelector(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('NUMBER SELECTION RANGE'),
                    const SizedBox(height: 10),
                    _buildNumberRangeSelector(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('GAME MODE'),
                    const SizedBox(height: 10),
                    _buildGameModeSelector(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('OVERS PER INNINGS'),
                    const SizedBox(height: 10),
                    _buildOversSelector(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('DECISION TIMER (SECONDS)'),
                    const SizedBox(height: 10),
                    _buildTimerSelector(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('SERIES TARGET WINS'),
                    const SizedBox(height: 10),
                    _buildSeriesTargetSelector(),
                    const SizedBox(height: 36),

                    SizedBox(
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [GameColors.lime, GameColors.cyanBright],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: GameColors.lime.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _onStartMatch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: GameColors.background,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'START VS COMPUTER',
                            style: GameTypography.headlineMedium.copyWith(
                              color: GameColors.background,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GameTypography.caption.copyWith(
        color: GameColors.lime,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPlayerInput() {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Your Name',
        labelStyle: const TextStyle(color: GameColors.player1Light),
        filled: true,
        fillColor: GameColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GameColors.player1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GameColors.player1.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Column(
      children: AiDifficulty.values.map((diff) {
        final isSelected = _selectedDifficulty == diff;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildChoiceChip(
            label: diff.label.toUpperCase(),
            subtitle: diff.description,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedDifficulty = diff),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumberRangeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildChoiceChip(
            label: '1 – 6 (DEFAULT)',
            subtitle: 'Fast arcade duel',
            isSelected: _selectedMaxChoice == 6,
            onTap: () => setState(() => _selectedMaxChoice = 6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildChoiceChip(
            label: '1 – 10 (CLASSIC)',
            subtitle: 'Wide range duel',
            isSelected: _selectedMaxChoice == 10,
            onTap: () => setState(() => _selectedMaxChoice = 10),
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildChoiceChip(
            label: 'STANDARD',
            subtitle: 'Manual per-ball',
            isSelected: _selectedMode == GameMode.standard,
            onTap: () => setState(() => _selectedMode = GameMode.standard),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildChoiceChip(
            label: 'FAST (AUTO)',
            subtitle: 'Auto-pick enabled',
            isSelected: _selectedMode == GameMode.fast,
            onTap: () => setState(() => _selectedMode = GameMode.fast),
          ),
        ),
      ],
    );
  }

  Widget _buildOversSelector() {
    final options = [
      (null, 'Unlimited'),
      (1, '1 Over'),
      (2, '2 Overs'),
      (5, '5 Overs'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = _selectedOvers == opt.$1;
        return ChoiceChip(
          label: Text(opt.$2),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedOvers = opt.$1),
          selectedColor: GameColors.lime,
          backgroundColor: GameColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? GameColors.background : GameColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimerSelector() {
    final timerOptions = [5, 10, 15, 20, 30];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: timerOptions.map((t) {
        final isSelected = _selectedTimer == t;
        return ChoiceChip(
          label: Text('${t}s'),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedTimer = t),
          selectedColor: GameColors.lime,
          backgroundColor: GameColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? GameColors.background : GameColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeriesTargetSelector() {
    final targets = [1, 3, 5, 6, 10];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: targets.map((target) {
        final isSelected = _selectedSeriesTarget == target;
        return ChoiceChip(
          label: Text('$target ${target == 1 ? "Win" : "Wins"}'),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedSeriesTarget = target),
          selectedColor: GameColors.gold,
          backgroundColor: GameColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? GameColors.background : GameColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? GameColors.lime.withValues(alpha: 0.15) : GameColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? GameColors.lime : GameColors.glassBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GameTypography.headlineMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? GameColors.lime : GameColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GameTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: GameColors.lime, size: 20),
          ],
        ),
      ),
    );
  }
}
