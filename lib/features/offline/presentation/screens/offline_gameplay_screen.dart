import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/presentation/widgets/ball_history_strip.dart';
import '../../../game/presentation/widgets/ball_outcome_dialog.dart';
import '../../../game/presentation/widgets/countdown_timer_bar.dart';
import '../../../game/presentation/widgets/number_pad.dart';
import '../../../game/presentation/widgets/player_identity_badge.dart';
import '../../../game/presentation/widgets/scoreboard_card.dart';
import '../controllers/offline_game_controller.dart';
import 'offline_privacy_handoff_screen.dart';

class OfflineGameplayScreen extends ConsumerStatefulWidget {
  const OfflineGameplayScreen({super.key});

  @override
  ConsumerState<OfflineGameplayScreen> createState() => _OfflineGameplayScreenState();
}

class _OfflineGameplayScreenState extends ConsumerState<OfflineGameplayScreen> {
  int? _stagedNumber;
  UniqueKey _timerResetKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final offlineState = ref.watch(offlineGameProvider);
    final match = offlineState.match;

    // Check if finished -> navigate to results once ball outcome overlay is dismissed
    if ((match.phase == MatchPhase.matchFinished ||
            match.phase == MatchPhase.seriesFinished ||
            match.phase == MatchPhase.matchForfeited) &&
        !offlineState.showBallOutcomeOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/offline-result');
      });
    }

    // 1. Pass and play privacy handoff screen
    if (offlineState.waitingForHandoff) {
      return OfflinePrivacyHandoffScreen(
        nextPlayerName: offlineState.activeHandoffTargetPlayer,
        onReady: () {
          setState(() {
            _stagedNumber = null;
            _timerResetKey = UniqueKey();
          });
          ref.read(offlineGameProvider.notifier).acknowledgeHandoff();
        },
      );
    }

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('ODD OR EVEN', style: GameTypography.headlineMedium),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _confirmExit(context),
          ),
        ],
      ),
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
                      // 1. Player badges header
                      _buildPlayerHeader(match),

                      // 2. Active Phase content
                      Expanded(
                        child: _buildPhaseContent(context, match, offlineState),
                      ),
                    ],
                  ),

                  // 3. Ball outcome dialog overlay
                  if (offlineState.showBallOutcomeOverlay && match.lastBallEvent != null)
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
                          ref.read(offlineGameProvider.notifier).dismissBallOutcome();
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

  Widget _buildPlayerHeader(dynamic match) {
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
    dynamic match,
    OfflineGameState offlineState,
  ) {
    switch (match.phase) {
      case MatchPhase.tossInput:
        return _buildTossPhase(match, offlineState);

      case MatchPhase.roleSelection:
        return _buildRoleSelectionPhase(match);

      case MatchPhase.firstInnings:
      case MatchPhase.secondInnings:
        return _buildActiveInningsPhase(match, offlineState);

      case MatchPhase.inningsBreak:
        return _buildInningsBreakPhase(match);

      default:
        return const Center(child: CircularProgressIndicator(color: GameColors.lime));
    }
  }

  Widget _buildTossPhase(dynamic match, OfflineGameState offlineState) {
    // Determine who needs to submit toss number
    final isP1Turn = offlineState.p1PendingChoice == null;
    final activePlayer = isP1Turn ? match.player1 : match.player2;

    return Column(
      children: [
        const Spacer(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GameColors.glassBorder),
          ),
          child: Column(
            children: [
              const Icon(Icons.change_circle_outlined, size: 48, color: GameColors.lime),
              const SizedBox(height: 12),
              Text(
                'THE TOSS',
                style: GameTypography.headlineMedium.copyWith(color: GameColors.lime),
              ),
              const SizedBox(height: 8),
              Text(
                '${activePlayer.name} (${activePlayer.parity!.label})',
                style: GameTypography.displayMedium.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                'Select your secret toss number (1 - ${match.config.maxChoice})',
                style: GameTypography.bodyMedium,
              ),
            ],
          ),
        ),
        const Spacer(),

        CountdownTimerBar(
          key: ValueKey('toss_${activePlayer.id}'),
          resetKey: _timerResetKey,
          totalSeconds: match.config.decisionTimerSeconds,
          onTimeout: () {
            ref.read(offlineGameProvider.notifier).handleTimeout(activePlayer.id);
            // Default choice 5 on timeout
            ref.read(offlineGameProvider.notifier).submitChoice(
                  playerId: activePlayer.id,
                  choice: 5,
                );
          },
        ),
        const SizedBox(height: 12),

        NumberPad(
          selectedNumber: _stagedNumber,
          maxNumber: match.config.maxChoice,
          autoModeEnabled: match.config.autoModeEnabled,
          onAutoPick: () {
            setState(() {
              _stagedNumber = ref.read(offlineGameProvider.notifier).generateAutoNumber();
            });
          },
          onNumberSelected: (selectedVal) => setState(() => _stagedNumber = selectedVal),
          onConfirm: () {
            if (_stagedNumber != null) {
              ref.read(offlineGameProvider.notifier).submitChoice(
                    playerId: activePlayer.id,
                    choice: _stagedNumber!,
                  );
              setState(() => _stagedNumber = null);
            }
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRoleSelectionPhase(dynamic match) {
    final tossWinner = match.tossWinner!;
    final sum = (match.tossP1Choice ?? 0) + (match.tossP2Choice ?? 0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GameColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: GameColors.lime),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_rounded, size: 52, color: GameColors.gold),
                  const SizedBox(height: 16),
                  Text(
                    'TOSS WON BY ${tossWinner.name.toUpperCase()}!',
                    textAlign: TextAlign.center,
                    style: GameTypography.headlineMedium.copyWith(color: GameColors.gold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sum was $sum (${sum % 2 != 0 ? "ODD" : "EVEN"}) matching ${tossWinner.name}\'s parity.',
                    textAlign: TextAlign.center,
                    style: GameTypography.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'What would you like to do first?',
                    style: GameTypography.caption.copyWith(letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(offlineGameProvider.notifier)
                                .selectCricketRole(CricketRole.bat);
                          },
                          icon: const Icon(Icons.sports_cricket),
                          label: const Text('BAT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameColors.lime,
                            foregroundColor: GameColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(offlineGameProvider.notifier)
                                .selectCricketRole(CricketRole.bowl);
                          },
                          icon: const Icon(Icons.sports_baseball),
                          label: const Text('BOWL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameColors.surfaceElevated,
                            foregroundColor: GameColors.textPrimary,
                            side: const BorderSide(color: GameColors.glassBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveInningsPhase(dynamic match, OfflineGameState offlineState) {
    // Batter picks first, then Bowler
    final isBatterTurn = offlineState.p1PendingChoice == null;
    final activePlayer = isBatterTurn ? match.currentBatter! : match.currentBowler!;
    final activeRoleName = isBatterTurn ? 'BATTER' : 'BOWLER';

    return Column(
      children: [
        ScoreboardCard(matchState: match),
        BallHistoryStrip(balls: match.ballHistory),
        const Spacer(),

        // Active Turn banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isBatterTurn
                ? GameColors.lime.withValues(alpha: 0.15)
                : GameColors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBatterTurn ? GameColors.lime : GameColors.amber,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBatterTurn ? Icons.sports_cricket : Icons.sports_baseball,
                size: 18,
                color: isBatterTurn ? GameColors.lime : GameColors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                '${activePlayer.name.toUpperCase()} ($activeRoleName) TO SELECT',
                style: GameTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isBatterTurn ? GameColors.lime : GameColors.amber,
                ),
              ),
            ],
          ),
        ),

        CountdownTimerBar(
          key: ValueKey('ball_${match.legalBallsBowled}_${activePlayer.id}'),
          resetKey: _timerResetKey,
          totalSeconds: match.config.decisionTimerSeconds,
          onTimeout: () {
            ref.read(offlineGameProvider.notifier).handleTimeout(activePlayer.id);
            // Default pick 1 on timeout
            ref.read(offlineGameProvider.notifier).submitChoice(
                  playerId: activePlayer.id,
                  choice: 1,
                );
          },
        ),
        const SizedBox(height: 8),

        NumberPad(
          selectedNumber: _stagedNumber,
          maxNumber: match.config.maxChoice,
          autoModeEnabled: match.config.autoModeEnabled,
          onAutoPick: () {
            setState(() {
              _stagedNumber = ref.read(offlineGameProvider.notifier).generateAutoNumber();
            });
          },
          onNumberSelected: (selectedVal) => setState(() => _stagedNumber = selectedVal),
          onConfirm: () {
            if (_stagedNumber != null) {
              ref.read(offlineGameProvider.notifier).submitChoice(
                    playerId: activePlayer.id,
                    choice: _stagedNumber!,
                  );
              setState(() => _stagedNumber = null);
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInningsBreakPhase(dynamic match) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: GameColors.gold),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_cricket, size: 56, color: GameColors.gold),
              const SizedBox(height: 16),
              Text(
                '1ST INNINGS COMPLETED!',
                style: GameTypography.headlineMedium.copyWith(color: GameColors.gold),
              ),
              const SizedBox(height: 12),
              Text(
                '${match.currentBatter!.name} scored ${match.firstInningsRuns} runs.',
                textAlign: TextAlign.center,
                style: GameTypography.bodyLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: GameColors.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'TARGET: ${match.targetRuns} RUNS',
                  style: GameTypography.displayMedium.copyWith(
                    fontSize: 22,
                    color: GameColors.lime,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(offlineGameProvider.notifier).startSecondInnings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.lime,
                    foregroundColor: GameColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'START 2ND INNINGS (CHASE)',
                    style: GameTypography.headlineMedium.copyWith(
                      fontSize: 15,
                      color: GameColors.background,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        title: Text('Exit Match?', style: GameTypography.headlineMedium),
        content: Text(
          'Current match progress will be lost. Return to menu?',
          style: GameTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: GameColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            style: ElevatedButton.styleFrom(backgroundColor: GameColors.wicket),
            child: const Text('Exit Match', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
