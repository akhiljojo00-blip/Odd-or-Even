import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/utils/sound_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../game/presentation/widgets/countdown_timer_bar.dart';
import '../../../game/presentation/widgets/number_pad.dart';
import '../../../progression/domain/models/rank_tier.dart';
import '../../../progression/presentation/widgets/rank_demotion_dialog.dart';
import '../../../progression/presentation/widgets/rank_emblem_widget.dart';
import '../../../progression/presentation/widgets/rank_promotion_dialog.dart';
import '../../../progression/presentation/widgets/rank_stars_widget.dart';
import '../../data/ranked_realtime_manager.dart';
import '../../domain/models/ranked_ball_event.dart';
import '../../domain/models/ranked_gameplay_state.dart';
import '../../domain/models/ranked_match.dart';
import '../controllers/ranked_gameplay_controller.dart';

/// Live server-authoritative Online Ranked gameplay screen.
/// Implements Zero Client Trust: All state, score, wickets, and settlement are authoritative in PostgreSQL.
class RankedGameplayScreen extends ConsumerStatefulWidget {
  final String matchId;

  const RankedGameplayScreen({
    super.key,
    required this.matchId,
  });

  @override
  ConsumerState<RankedGameplayScreen> createState() => _RankedGameplayScreenState();
}

class _RankedGameplayScreenState extends ConsumerState<RankedGameplayScreen> {
  int? _stagedNumber;
  bool _hasCheckedPromotionDialog = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rankedGameplayProvider(widget.matchId));
    final notifier = ref.read(rankedGameplayProvider(widget.matchId).notifier);

    // Audio, haptic feedback and promotion/demotion celebration handling
    ref.listen<RankedGameplayState>(rankedGameplayProvider(widget.matchId), (prev, next) {
      // 1. Audio and haptics on new ball resolution
      if (next.ballEvents.length > (prev?.ballEvents.length ?? 0)) {
        final latest = next.ballEvents.last;
        if (latest.isWicket) {
          HapticsUtil.heavyWicket();
          SoundUtil.playWicket();
        } else {
          HapticsUtil.lightTap();
          SoundUtil.playScore();
        }
      }

      // 2. Audio and haptics on match completion
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        if (next.isWinner) {
          HapticsUtil.victoryVibrate();
        } else {
          HapticsUtil.mediumTap();
        }
      }

      // 3. Promotion / Demotion detection after settlement
      if (next.isCompleted &&
          next.settlement != null &&
          next.myRank != null &&
          !_hasCheckedPromotionDialog) {
        _hasCheckedPromotionDialog = true;
        final initial = next.initialRankSnapshot;
        final current = next.myRank!;

        if (initial != null) {
          final isTierPromo = current.tier.tierIndex > initial.tier.tierIndex;
          final isDivPromo = !isTierPromo &&
              initial.division != null &&
              current.division != null &&
              current.division!.divisionNumber < initial.division!.divisionNumber;

          if (isTierPromo || isDivPromo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => RankPromotionDialog(
                  previousTier: initial.tier,
                  previousDivision: initial.division,
                  newTier: current.tier,
                  newDivision: current.division,
                  newStars: current.stars,
                  isTierPromotion: isTierPromo,
                  onDismiss: () => Navigator.of(ctx).pop(),
                ),
              );
            });
          } else {
            final isTierDemo = current.tier.tierIndex < initial.tier.tierIndex;
            final isDivDemo = !isTierDemo &&
                initial.division != null &&
                current.division != null &&
                current.division!.divisionNumber > initial.division!.divisionNumber;

            if (isTierDemo || isDivDemo) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => RankDemotionDialog(
                    tier: current.tier,
                    division: current.division,
                    stars: current.stars,
                    shieldAbsorbed: false,
                    onDismiss: () => Navigator.of(ctx).pop(),
                  ),
                );
              });
            }
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: _buildAppBar(state, notifier),
      bottomNavigationBar: const CreatorFooter(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: GameColors.goldBright),
                )
              : state.errorMessage != null && state.match == null
                  ? _buildErrorView(state.errorMessage!)
                  : _buildGameplayBody(state, notifier),
        ),
      ),
    );
  }

  // =========================================================================
  // APP BAR & HEADER
  // =========================================================================

  PreferredSizeWidget _buildAppBar(RankedGameplayState state, RankedGameplayNotifier notifier) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => _handleBackNavigation(context, state),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'RANKED DUEL',
            style: GameTypography.headlineMedium.copyWith(
              color: GameColors.goldBright,
              letterSpacing: 1.5,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          _buildConnectionIndicator(state.realtimeStatus),
        ],
      ),
      centerTitle: true,
      actions: [
        if (state.match != null && !state.isCompleted)
          IconButton(
            tooltip: 'Surrender Match',
            icon: const Icon(Icons.flag_outlined, color: GameColors.wicket),
            onPressed: () => _showSurrenderDialog(context, notifier),
          ),
      ],
    );
  }

  Widget _buildConnectionIndicator(RealtimeSyncStatus status) {
    final Color color;
    final String label;

    switch (status) {
      case RealtimeSyncStatus.subscribed:
        color = GameColors.emerald;
        label = 'LIVE';
        break;
      case RealtimeSyncStatus.connecting:
        color = GameColors.amber;
        label = 'SYNC';
        break;
      case RealtimeSyncStatus.disconnected:
      case RealtimeSyncStatus.error:
      case RealtimeSyncStatus.closed:
        color = GameColors.wicket;
        label = 'OFFLINE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BODY DISPATCHER
  // =========================================================================

  Widget _buildGameplayBody(RankedGameplayState state, RankedGameplayNotifier notifier) {
    if (state.isCompleted) {
      return _buildSettlementView(state, notifier);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Transient Error Banner
              if (state.errorMessage != null) ...[
                _buildTransientErrorBanner(state.errorMessage!, notifier),
                const SizedBox(height: 8),
              ],

              // 2. Opponent Disconnect Notice
              if (state.isOpponentDisconnected) ...[
                _buildDisconnectBanner(state, notifier),
                const SizedBox(height: 8),
              ],

              // 3. Player Header Matchup
              _buildPlayerMatchupRow(state),
              const SizedBox(height: 12),

              // 4. Scoreboard Card (for active or concluded innings)
              if (state.match?.phase != RankedMatchPhase.tossInput) ...[
                _buildScoreboardCard(state),
                const SizedBox(height: 10),
                _buildBallHistoryStrip(state.ballEvents),
                const SizedBox(height: 10),
              ],

              // 5. Decision Timer Bar & Timeout Claim
              if (!state.isCompleted) ...[
                _buildDecisionTimerSection(state, notifier),
                const SizedBox(height: 12),
              ],

              // 6. Interactive Game Phase Area
              _buildPhaseContent(state, notifier),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // PLAYER MATCHUP ROW
  // =========================================================================

  Widget _buildPlayerMatchupRow(RankedGameplayState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current Player
          Expanded(
            child: _buildPlayerProfileCard(
              displayName: state.myDisplayName,
              tier: state.myRank?.tier ?? RankTier.bronze,
              division: state.myRank?.division ?? RankDivision.I,
              stars: state.myRank?.stars ?? 0,
              parity: state.myParity,
              isBatting: state.isBatting,
              isBowling: state.isBowling,
              isCaller: true,
            ),
          ),
          // VS Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'VS',
              style: GameTypography.headlineMedium.copyWith(
                color: GameColors.goldBright,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Opponent
          Expanded(
            child: _buildPlayerProfileCard(
              displayName: state.opponentDisplayName,
              tier: state.opponentRank?.tier ?? RankTier.bronze,
              division: state.opponentRank?.division ?? RankDivision.I,
              stars: state.opponentRank?.stars ?? 0,
              parity: state.opponentParity,
              isBatting: !state.isBatting && state.isBowling,
              isBowling: state.isBatting && !state.isBowling,
              isCaller: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerProfileCard({
    required String displayName,
    required RankTier tier,
    required RankDivision? division,
    required int stars,
    required PlayerParity? parity,
    required bool isBatting,
    required bool isBowling,
    required bool isCaller,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isCaller ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCaller) ...[
              RankEmblemWidget(tier: tier, division: division, size: 36, animate: false),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isCaller ? GameColors.goldBright : Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            if (!isCaller) ...[
              const SizedBox(width: 8),
              RankEmblemWidget(tier: tier, division: division, size: 36, animate: false),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (parity != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (parity == PlayerParity.odd ? GameColors.cyanBright : GameColors.electricViolet)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (parity == PlayerParity.odd ? GameColors.cyanBright : GameColors.electricViolet)
                        .withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  parity.dbValue.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: parity == PlayerParity.odd ? GameColors.cyanBright : GameColors.electricViolet,
                  ),
                ),
              ),
            if (isBatting || isBowling) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isBatting ? GameColors.emerald : GameColors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isBatting ? GameColors.emerald : GameColors.amber).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  isBatting ? 'BAT' : 'BOWL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isBatting ? GameColors.emerald : GameColors.amber,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // SCOREBOARD & BALL HISTORY
  // =========================================================================

  Widget _buildScoreboardCard(RankedGameplayState state) {
    final match = state.match;
    if (match == null) return const SizedBox.shrink();

    final isInnings2 = match.currentInningsNo == 2;
    final balls = match.legalBallsBowled;
    final oversStr = '${balls ~/ 6}.${balls % 6}';
    final runs = match.currentInningsRuns;
    final target = match.targetRuns;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF261448), Color(0xFF160B2C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: GameColors.royalPurple.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Innings indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isInnings2 ? GameColors.amber.withValues(alpha: 0.2) : GameColors.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isInnings2 ? GameColors.amber : GameColors.emerald,
                    width: 1,
                  ),
                ),
                child: Text(
                  isInnings2 ? '2ND INNINGS (CHASE)' : '1ST INNINGS',
                  style: GameTypography.caption.copyWith(
                    color: isInnings2 ? GameColors.amber : GameColors.emerald,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                'OVERS: $oversStr / 2.0',
                style: GameTypography.caption.copyWith(
                  color: GameColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Score Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$runs',
                style: GameTypography.headlineLarge.copyWith(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RUNS',
                style: GameTypography.bodyMedium.copyWith(
                  color: GameColors.goldBright,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Target Info for Chase
          if (isInnings2 && target != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TARGET: $target',
                    style: GameTypography.caption.copyWith(
                      color: GameColors.goldBright,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Need ${target - runs} runs in ${12 - balls} balls',
                    style: GameTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBallHistoryStrip(List<RankedBallEvent> events) {
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'First ball of the innings...',
          style: GameTypography.caption.copyWith(color: GameColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true, // Latest ball on right
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final event = events[events.length - 1 - index];
          return _buildBallBubble(event);
        },
      ),
    );
  }

  Widget _buildBallBubble(RankedBallEvent event) {
    final isWicket = event.isWicket;
    final runs = event.runsScored;

    final Color bgColor;
    final String label;

    if (isWicket) {
      bgColor = GameColors.wicket;
      label = 'W';
    } else if (runs == 0) {
      bgColor = GameColors.surfaceElevated;
      label = '•';
    } else if (runs == 6) {
      bgColor = GameColors.emerald;
      label = '6';
    } else if (runs == 4) {
      bgColor = GameColors.cyanBright;
      label = '4';
    } else {
      bgColor = GameColors.electricViolet.withValues(alpha: 0.6);
      label = '$runs';
    }

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  // =========================================================================
  // DECISION TIMER & TIMEOUT CLAIM
  // =========================================================================

  Widget _buildDecisionTimerSection(RankedGameplayState state, RankedGameplayNotifier notifier) {
    final canClaim = state.canClaimTimeout;

    return Column(
      children: [
        CountdownTimerBar(
          totalSeconds: 20,
          onTimeout: () {},
          isPaused: state.isCompleted,
        ),
        if (canClaim) ...[
          const SizedBox(height: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.wicket,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: state.isClaimingTimeout ? null : () => notifier.claimTimeoutForfeit(),
            icon: state.isClaimingTimeout
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.timer_off_rounded, size: 18),
            label: Text(
              'CLAIM TIMEOUT FORFEIT WIN',
              style: GameTypography.caption.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // INTERACTIVE GAME PHASE CONTENT
  // =========================================================================

  Widget _buildPhaseContent(RankedGameplayState state, RankedGameplayNotifier notifier) {
    final phase = state.match?.phase ?? RankedMatchPhase.tossInput;

    switch (phase) {
      case RankedMatchPhase.tossInput:
        return _buildTossSection(state, notifier);
      case RankedMatchPhase.roleSelection:
        return _buildRoleSelectionSection(state, notifier);
      case RankedMatchPhase.firstInnings:
      case RankedMatchPhase.secondInnings:
        return _buildActiveInningsSection(state, notifier);
      case RankedMatchPhase.inningsBreak:
        return _buildInningsBreakSection(state, notifier);
      case RankedMatchPhase.matchFinished:
      case RankedMatchPhase.matchForfeited:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTossSection(RankedGameplayState state, RankedGameplayNotifier notifier) {
    final parityStr = (state.myParity?.dbValue ?? 'odd').toUpperCase();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GameColors.goldMetallic.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                'TOSS STAGE',
                style: GameTypography.caption.copyWith(
                  color: GameColors.goldBright,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You are $parityStr. Select 1 to 6. The sum determines the winner!',
                textAlign: TextAlign.center,
                style: GameTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.hasSubmittedThisTurn) ...[
          _buildWaitingForOpponentCard('Toss choice submitted! Waiting for opponent...'),
        ] else ...[
          NumberPad(
            selectedNumber: _stagedNumber,
            maxNumber: 6,
            isSubmitting: state.isSubmitting,
            onNumberSelected: (n) {
              setState(() => _stagedNumber = n);
              HapticsUtil.lightTap();
              SoundUtil.playTap();
            },
            onConfirm: () {
              if (_stagedNumber != null) {
                HapticsUtil.mediumTap();
                SoundUtil.playSubmit();
                notifier.submitChoice(_stagedNumber!);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildRoleSelectionSection(RankedGameplayState state, RankedGameplayNotifier notifier) {
    final isTossWinner = state.isTossWinner;

    if (!isTossWinner) {
      return _buildWaitingForOpponentCard(
        'Opponent won the toss and is choosing to Bat or Bowl...',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.goldBright, width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, color: GameColors.goldBright, size: 40),
          const SizedBox(height: 8),
          Text(
            'YOU WON THE TOSS!',
            style: GameTypography.headlineMedium.copyWith(
              color: GameColors.goldBright,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your role for the match:',
            style: GameTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: state.isSelectingRole ? null : () => notifier.selectRole('bat'),
                  icon: const Icon(Icons.sports_cricket_rounded),
                  label: Text(
                    'BAT FIRST',
                    style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.electricViolet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: state.isSelectingRole ? null : () => notifier.selectRole('bowl'),
                  icon: const Icon(Icons.sports_baseball_rounded),
                  label: Text(
                    'BOWL FIRST',
                    style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveInningsSection(RankedGameplayState state, RankedGameplayNotifier notifier) {
    if (state.hasSubmittedThisTurn) {
      return _buildWaitingForOpponentCard('Delivery choice submitted! Waiting for opponent...');
    }

    final roleLabel = state.isBatting ? 'YOU ARE BATTING' : 'YOU ARE BOWLING';
    final roleColor = state.isBatting ? GameColors.emerald : GameColors.amber;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: roleColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            roleLabel,
            style: GameTypography.caption.copyWith(
              color: roleColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 14),
        NumberPad(
          selectedNumber: _stagedNumber,
          maxNumber: 6,
          isSubmitting: state.isSubmitting,
          onNumberSelected: (n) {
            setState(() => _stagedNumber = n);
            HapticsUtil.lightTap();
            SoundUtil.playTap();
          },
          onConfirm: () {
            if (_stagedNumber != null) {
              HapticsUtil.mediumTap();
              SoundUtil.playSubmit();
              notifier.submitChoice(_stagedNumber!);
            }
          },
        ),
      ],
    );
  }

  Widget _buildInningsBreakSection(RankedGameplayState state, RankedGameplayNotifier notifier) {
    final match = state.match;
    final target = match?.targetRuns ?? ((match?.firstInningsRuns ?? 0) + 1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.goldMetallic, width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.flag_rounded, color: GameColors.amber, size: 36),
          const SizedBox(height: 8),
          Text(
            '1ST INNINGS COMPLETE',
            style: GameTypography.headlineMedium.copyWith(
              color: GameColors.goldBright,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1st Innings: ${match?.firstInningsRuns ?? 0} runs',
            style: GameTypography.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          Text(
            'Target to win: $target runs in 2 overs (12 balls)',
            style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.goldBright,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: state.isStartingSecondInnings ? null : () => notifier.startSecondInnings(),
            child: state.isStartingSecondInnings
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    'START 2ND INNINGS',
                    style: GameTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForOpponentCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: GameColors.goldBright),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GameTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SETTLEMENT VIEW (ZERO CLIENT TRUST)
  // =========================================================================

  Widget _buildSettlementView(RankedGameplayState state, RankedGameplayNotifier notifier) {
    final match = state.match;
    final settlement = state.settlement;
    final isWinner = state.isWinner;
    final isTie = state.isTie;
    final isForfeit = state.isForfeit;

    final String resultTitle;
    final Color resultColor;

    if (isTie) {
      resultTitle = 'MATCH TIED';
      resultColor = GameColors.amber;
    } else if (isWinner) {
      resultTitle = isForfeit ? 'VICTORY BY FORFEIT' : 'VICTORY';
      resultColor = GameColors.goldBright;
    } else {
      resultTitle = isForfeit ? 'DEFEAT BY FORFEIT' : 'DEFEAT';
      resultColor = GameColors.wicket;
    }

    final starsDelta = settlement != null
        ? settlement.starsDeltaFor(state.currentUserId ?? '', match?.player1Id ?? '')
        : 0;
    final mmrDelta = settlement != null
        ? settlement.mmrDeltaFor(state.currentUserId ?? '', match?.player1Id ?? '')
        : 0;
    final xpAwarded = settlement != null
        ? settlement.xpAwardedFor(state.currentUserId ?? '', match?.player1Id ?? '')
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Result Title
              Text(
                resultTitle,
                style: GameTypography.headlineLarge.copyWith(
                  color: resultColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),

              // Summary Breakdown Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GameColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GameColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Rank & Emblem
                    if (state.myRank != null) ...[
                      RankEmblemWidget(
                        tier: state.myRank!.tier,
                        division: state.myRank!.division,
                        size: 72,
                        animate: true,
                        showAura: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.myRank!.tier.displayName.toUpperCase()} ${state.myRank!.division?.label ?? ''}'.trim(),
                        style: GameTypography.headlineMedium.copyWith(
                          color: GameColors.goldBright,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RankStarsWidget(
                        tier: state.myRank!.tier,
                        stars: state.myRank!.stars,
                      ),
                      const Divider(color: GameColors.glassBorder, height: 32),
                    ],

                    // Progression Deltas Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDeltaPill(
                          label: 'STARS',
                          value: '${starsDelta >= 0 ? '+' : ''}$starsDelta',
                          color: starsDelta >= 0 ? GameColors.emerald : GameColors.wicket,
                        ),
                        _buildDeltaPill(
                          label: 'MMR',
                          value: '${mmrDelta >= 0 ? '+' : ''}$mmrDelta',
                          color: mmrDelta >= 0 ? GameColors.emerald : GameColors.wicket,
                        ),
                        _buildDeltaPill(
                          label: 'XP',
                          value: '+$xpAwarded',
                          color: GameColors.goldBright,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // View Leaderboard Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.surfaceElevated,
                    foregroundColor: GameColors.goldBright,
                    side: BorderSide(color: GameColors.goldBright.withValues(alpha: 0.6), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    HapticsUtil.lightTap();
                    context.push('/ranked-leaderboard');
                  },
                  icon: const Icon(Icons.emoji_events_outlined, size: 20),
                  label: Text(
                    'VIEW LEADERBOARD',
                    style: GameTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: GameColors.glassBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => context.go('/'),
                      child: Text(
                        'MAIN MENU',
                        style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameColors.goldBright,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => context.go('/ranked-matchmaking'),
                      child: Text(
                        'PLAY AGAIN',
                        style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.w900),
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

  Widget _buildDeltaPill({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: GameTypography.caption.copyWith(
            color: GameColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            value,
            style: GameTypography.headlineMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // OVERLAYS & BANNERS
  // =========================================================================

  Widget _buildTransientErrorBanner(String message, RankedGameplayNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.wicket.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.wicket),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: GameColors.wicket, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GameTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 16),
            onPressed: () => notifier.clearErrorMessage(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectBanner(RankedGameplayState state, RankedGameplayNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.amber),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: GameColors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Opponent disconnected! Waiting grace: ${state.opponentGraceRemainingSeconds}s',
              style: GameTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: GameColors.wicket, size: 56),
            const SizedBox(height: 16),
            Text(
              'ACCESS RESTRICTED',
              style: GameTypography.headlineMedium.copyWith(
                color: GameColors.wicket,
                fontWeight: FontWeight.w900,
              ),
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
              onPressed: () => context.go('/'),
              child: const Text('RETURN TO MENU'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ACTIONS & DIALOGS
  // =========================================================================

  void _handleBackNavigation(BuildContext context, RankedGameplayState state) {
    if (state.isCompleted) {
      context.go('/');
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: GameColors.surface,
          title: Text(
            'Leave Match?',
            style: GameTypography.headlineMedium.copyWith(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'Leaving an ongoing ranked match will not forfeit automatically, but your turn timer will continue running. Are you sure you want to return to the menu?',
            style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL', style: TextStyle(color: GameColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/');
              },
              child: const Text('LEAVE', style: TextStyle(color: GameColors.wicket)),
            ),
          ],
        ),
      );
    }
  }

  void _showSurrenderDialog(BuildContext context, RankedGameplayNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        title: Text(
          'Surrender Match?',
          style: GameTypography.headlineMedium.copyWith(color: GameColors.wicket, fontSize: 18),
        ),
        content: Text(
          'Surrendering will forfeit the match immediately. Your opponent will be awarded the win, and you will lose stars/MMR according to ranked rules.',
          style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: GameColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.wicket,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.surrender();
            },
            child: const Text('SURRENDER'),
          ),
        ],
      ),
    );
  }
}
