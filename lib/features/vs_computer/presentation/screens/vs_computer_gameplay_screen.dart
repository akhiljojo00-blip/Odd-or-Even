import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/game_match_state.dart';
import '../../../game/presentation/widgets/animated_coin_toss.dart';
import '../../../game/presentation/widgets/ball_history_strip.dart';
import '../../../game/presentation/widgets/ball_outcome_dialog.dart';
import '../../../game/presentation/widgets/countdown_timer_bar.dart';
import '../../../game/presentation/widgets/match_result_view.dart';
import '../../../game/presentation/widgets/number_pad.dart';
import '../../../game/presentation/widgets/player_identity_badge.dart';
import '../../../game/presentation/widgets/scoreboard_card.dart';
import '../controllers/vs_computer_game_controller.dart';

class VsComputerGameplayScreen extends ConsumerStatefulWidget {
  const VsComputerGameplayScreen({super.key});

  @override
  ConsumerState<VsComputerGameplayScreen> createState() => _VsComputerGameplayScreenState();
}

class _VsComputerGameplayScreenState extends ConsumerState<VsComputerGameplayScreen> {
  int? _stagedNumber;
  UniqueKey _timerResetKey = UniqueKey();

  void _confirmExit(BuildContext context) {
    HapticsUtil.mediumTap();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GameColors.glassBorder),
        ),
        title: Text('Exit Match?', style: GameTypography.headlineMedium),
        content: Text(
          'Leaving will abandon the current match against the computer.',
          style: GameTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('STAY', style: TextStyle(color: GameColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GameColors.wicket),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            child: const Text('EXIT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vsState = ref.watch(vsComputerGameProvider);
    final match = vsState.match;
    final notifier = ref.read(vsComputerGameProvider.notifier);

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, color: GameColors.goldBright, size: 22),
            const SizedBox(width: 8),
            Text('VS COMPUTER', style: GameTypography.headlineMedium.copyWith(letterSpacing: 1.5)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GameColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GameColors.gold.withValues(alpha: 0.5)),
              ),
              child: Text(
                vsState.difficulty.label.toUpperCase(),
                style: GameTypography.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: GameColors.goldBright,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Leave Match',
            onPressed: () => _confirmExit(context),
          ),
        ],
      ),
      bottomNavigationBar: const CreatorFooter(padding: EdgeInsets.only(top: 4, bottom: 4)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // 1. Players header
                      _buildPlayerHeader(match),

                      // 2. Active Phase content
                      Expanded(
                        child: _buildPhaseContent(context, match, vsState, notifier),
                      ),
                    ],
                  ),

                  // 3. Ball outcome overlay dialog
                  if (vsState.showBallOutcomeOverlay && match.lastBallEvent != null)
                    Container(
                      color: Colors.black.withValues(alpha: 0.75),
                      child: BallOutcomeDialog(
                        ballEvent: match.lastBallEvent!,
                        batterName: match.getPlayerById(match.lastBallEvent!.batterId).name,
                        bowlerName: match.getPlayerById(match.lastBallEvent!.bowlerId).name,
                        onDismiss: () {
                          setState(() {
                            _stagedNumber = null;
                            _timerResetKey = UniqueKey();
                          });
                          notifier.dismissBallOutcome();
                        },
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

  Widget _buildPlayerHeader(GameMatchState match) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PlayerIdentityBadge(
            player: match.player1,
            isPlayer1: true,
            activeRole: match.phase.isInningsActive
                ? (match.currentBatterId == match.player1.id
                    ? CricketRole.bat
                    : CricketRole.bowl)
                : null,
            seriesTarget: match.config.seriesTargetPoints,
          ),
          PlayerIdentityBadge(
            player: match.player2,
            isPlayer1: false,
            activeRole: match.phase.isInningsActive
                ? (match.currentBatterId == match.player2.id
                    ? CricketRole.bat
                    : CricketRole.bowl)
                : null,
            seriesTarget: match.config.seriesTargetPoints,
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(
    BuildContext context,
    GameMatchState match,
    VsComputerGameState vsState,
    VsComputerGameNotifier notifier,
  ) {
    switch (match.phase) {
      case MatchPhase.tossInput:
        return _buildTossPhase(match, notifier);

      case MatchPhase.roleSelection:
        return _buildRoleSelectionPhase(match, notifier);

      case MatchPhase.firstInnings:
      case MatchPhase.secondInnings:
        return _buildInningsPhase(match, notifier);

      case MatchPhase.inningsBreak:
        return _buildInningsBreakPhase(match, notifier);

      case MatchPhase.matchFinished:
      case MatchPhase.seriesFinished:
      case MatchPhase.matchForfeited:
        return _buildResultsPhase(match, vsState, notifier);

      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  // ---------------- TOSS PHASE ----------------
  Widget _buildTossPhase(GameMatchState match, VsComputerGameNotifier notifier) {
    final humanParity = match.player1.parity ?? Parity.odd;
    final computerParity = match.player2.parity ?? Parity.even;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: GameColors.surfaceGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GameColors.cyan.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  'COIN TOSS DUEL',
                  style: GameTypography.headlineMedium.copyWith(
                    color: GameColors.cyanBright,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedCoinToss(
                  outcome: humanParity,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildParityPill('YOU', humanParity.label, GameColors.player1),
                    Text('VS', style: GameTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                    _buildParityPill('COMPUTER', computerParity.label, GameColors.player2),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Select your toss number. Both numbers will sum together.\nOdd sum awards toss to ${humanParity == Parity.odd ? "You" : "Computer"}. Even awards to ${humanParity == Parity.even ? "You" : "Computer"}.',
                  textAlign: TextAlign.center,
                  style: GameTypography.caption.copyWith(fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const Spacer(),

          CountdownTimerBar(
            key: _timerResetKey,
            totalSeconds: match.config.decisionTimerSeconds,
            onTimeout: notifier.handleTimeout,
          ),
          const SizedBox(height: 12),

          NumberPad(
            selectedNumber: _stagedNumber,
            maxNumber: match.config.maxChoice,
            autoModeEnabled: match.config.autoModeEnabled,
            onAutoPick: () {
              setState(() => _stagedNumber = notifier.generateAutoNumber());
            },
            onNumberSelected: (v) => setState(() => _stagedNumber = v),
            onConfirm: () {
              if (_stagedNumber != null) {
                final choice = _stagedNumber!;
                setState(() => _stagedNumber = null);
                notifier.submitTossChoice(choice);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildParityPill(String player, String parity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(player, style: GameTypography.caption.copyWith(fontSize: 10, color: color)),
          const SizedBox(height: 2),
          Text(parity, style: GameTypography.headlineMedium.copyWith(fontSize: 16, color: color)),
        ],
      ),
    );
  }

  // ---------------- ROLE SELECTION PHASE ----------------
  Widget _buildRoleSelectionPhase(GameMatchState match, VsComputerGameNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GameColors.lime, width: 2),
            boxShadow: [
              BoxShadow(
                color: GameColors.lime.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, color: GameColors.goldBright, size: 52),
              const SizedBox(height: 12),
              Text(
                'YOU WON THE TOSS!',
                style: GameTypography.headlineLarge.copyWith(color: GameColors.lime, fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role to start the first innings:',
                textAlign: TextAlign.center,
                style: GameTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.selectCricketRole(CricketRole.bat),
                      icon: const Icon(Icons.sports_cricket_rounded),
                      label: const Text('BAT FIRST'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameColors.mint,
                        foregroundColor: GameColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.selectCricketRole(CricketRole.bowl),
                      icon: const Icon(Icons.sports_baseball_rounded),
                      label: const Text('BOWL FIRST'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameColors.cyanBright,
                        foregroundColor: GameColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- INNINGS PHASE ----------------
  Widget _buildInningsPhase(GameMatchState match, VsComputerGameNotifier notifier) {
    final isHumanBatter = match.currentBatterId == 'human';

    return Column(
      children: [
        ScoreboardCard(matchState: match),
        const SizedBox(height: 8),

        BallHistoryStrip(balls: match.ballHistory),
        const SizedBox(height: 8),

        // Role indicator banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (isHumanBatter ? GameColors.lime : GameColors.cyan).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHumanBatter ? GameColors.lime : GameColors.cyan,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHumanBatter ? Icons.sports_cricket_rounded : Icons.sports_baseball_rounded,
                color: isHumanBatter ? GameColors.lime : GameColors.cyanBright,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isHumanBatter
                    ? 'YOU ARE BATTING (Score runs by dodging the computer)'
                    : 'YOU ARE BOWLING (Match the computer to take a wicket)',
                style: GameTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isHumanBatter ? GameColors.lime : GameColors.cyanBright,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),

        CountdownTimerBar(
          key: _timerResetKey,
          totalSeconds: match.config.decisionTimerSeconds,
          onTimeout: notifier.handleTimeout,
        ),
        const SizedBox(height: 8),

        NumberPad(
          selectedNumber: _stagedNumber,
          maxNumber: match.config.maxChoice,
          autoModeEnabled: match.config.autoModeEnabled,
          onAutoPick: () {
            setState(() => _stagedNumber = notifier.generateAutoNumber());
          },
          onNumberSelected: (v) => setState(() => _stagedNumber = v),
          onConfirm: () {
            if (_stagedNumber != null) {
              final choice = _stagedNumber!;
              setState(() => _stagedNumber = null);
              notifier.submitBallChoice(choice);
            }
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ---------------- INNINGS BREAK ----------------
  Widget _buildInningsBreakPhase(GameMatchState match, VsComputerGameNotifier notifier) {
    final firstInningsRuns = match.firstInningsRuns;
    final target = match.targetRuns ?? (firstInningsRuns + 1);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: GameColors.gold),
            boxShadow: [
              BoxShadow(
                color: GameColors.gold.withValues(alpha: 0.2),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_outline_rounded, color: GameColors.goldBright, size: 56),
              const SizedBox(height: 12),
              Text(
                'INNINGS BREAK',
                style: GameTypography.headlineLarge.copyWith(color: GameColors.goldBright, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              Text('1st Innings Complete', style: GameTypography.bodyMedium),
              const SizedBox(height: 4),
              Text(
                '$firstInningsRuns RUNS',
                style: GameTypography.displayLarge.copyWith(color: Colors.white, fontSize: 36),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: GameColors.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GameColors.lime),
                ),
                child: Text(
                  'TARGET TO WIN: $target RUNS',
                  style: GameTypography.headlineMedium.copyWith(color: GameColors.lime, fontSize: 16),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: notifier.startSecondInnings,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('START 2ND INNINGS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.lime,
                    foregroundColor: GameColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- RESULTS PHASE ----------------
  Widget _buildResultsPhase(
    GameMatchState match,
    VsComputerGameState vsState,
    VsComputerGameNotifier notifier,
  ) {
    return MatchResultView(
      match: match,
      currentUserId: vsState.humanPlayerId,
      onRematch: () {
        setState(() => _timerResetKey = UniqueKey());
        notifier.requestRematch();
      },
      onHome: () => context.go('/'),
    );
  }
}
