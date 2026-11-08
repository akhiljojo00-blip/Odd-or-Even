import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
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
import '../../data/supabase_match_repository.dart';

class OnlineGameplayScreen extends ConsumerStatefulWidget {
  final String matchId;

  const OnlineGameplayScreen({
    super.key,
    required this.matchId,
  });

  @override
  ConsumerState<OnlineGameplayScreen> createState() => _OnlineGameplayScreenState();
}

class _OnlineGameplayScreenState extends ConsumerState<OnlineGameplayScreen> {
  late final SupabaseMatchRepository _repo;
  Timer? _syncTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isRealtimeConnected = false;
  GameMatchState? _match;
  bool _isLoading = true;
  bool _hasSubmittedThisTurn = false;
  int? _stagedNumber;
  bool _showBallOutcome = false;
  int _lastResolvedBallCount = 0;
  bool _isFirstFetch = true;
  String? _currentUserId;
  String? _errorMessage;

  MatchPhase? _lastPhase;
  int? _lastInningsNo;
  int? _lastBallsBowled;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(supabaseMatchRepositoryProvider);
    _initMatch();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _repo.unsubscribeChannel(_realtimeChannel);
    super.dispose();
  }

  Future<void> _initMatch() async {
    _currentUserId = _repo.currentUserId ?? await _repo.ensureAuthenticatedUser();

    await _fetchLatestState();

    // Subscribe to instant Supabase Realtime channel
    if (_repo.isConfigured) {
      _realtimeChannel = _repo.subscribeToMatchChannel(
        matchId: widget.matchId,
        onStateChange: () {
          if (mounted) {
            _fetchLatestState();
          }
        },
        onStatusChange: (status) {
          if (mounted) {
            setState(() {
              _isRealtimeConnected = status == RealtimeSubscribeStatus.subscribed;
            });
          }
        },
      );
    }

    // High-responsiveness polling fallback (keeps authoritative state synchronized)
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchLatestState());
  }

  Future<void> _fetchLatestState() async {
    final match = await _repo.getMatch(widget.matchId);
    if (!mounted) return;
    if (match == null) {
      if (_match == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Match unavailable or access restricted. Please return to the online lobby.';
        });
      }
      return;
    }
    _errorMessage = null;

    // Detect authoritative phase or turn advancement and reset stale submission lock
    final phaseChanged = _lastPhase != null && _lastPhase != match.phase;
    final ballAdvanced = _lastBallsBowled != null && _lastBallsBowled != match.legalBallsBowled;
    final inningsChanged = _lastInningsNo != null && _lastInningsNo != match.currentInningsNo;

    if (phaseChanged || ballAdvanced || inningsChanged) {
      _hasSubmittedThisTurn = false;
      _stagedNumber = null;
    }
    _lastPhase = match.phase;
    _lastInningsNo = match.currentInningsNo;
    _lastBallsBowled = match.legalBallsBowled;

    // Check if new ball was resolved (only after initial load)
    if (_isFirstFetch) {
      _lastResolvedBallCount = match.ballHistory.length;
      _isFirstFetch = false;
    } else if (match.ballHistory.length > _lastResolvedBallCount) {
      _lastResolvedBallCount = match.ballHistory.length;
      setState(() {
        _showBallOutcome = true;
        _hasSubmittedThisTurn = false;
        _stagedNumber = null;
      });
      HapticsUtil.heavyImpact();
    }

    // Check if opponent requested a rematch from results screen
    final isFinished = match.phase == MatchPhase.matchFinished ||
        match.phase == MatchPhase.seriesFinished ||
        match.phase == MatchPhase.matchForfeited;
    if (isFinished && match.roomId != null) {
      final room = await _repo.getRoom(match.roomId!);
      if (room != null && room['active_match_id'] != null && room['active_match_id'] != widget.matchId) {
        final newMatchId = room['active_match_id'] as String;
        _syncTimer?.cancel();
        if (mounted) {
          context.go('/online-play/$newMatchId');
        }
        return;
      }
    }

    setState(() {
      _match = match;
      _isLoading = false;
    });
  }

  Future<void> _handleSubmitChoice(int choice) async {
    final match = _match;
    if (match == null || _hasSubmittedThisTurn) return;

    final turnType = match.phase == MatchPhase.tossInput ? 'toss' : 'ball';

    setState(() {
      _hasSubmittedThisTurn = true;
      _stagedNumber = choice;
    });
    HapticsUtil.mediumTap();

    final res = await _repo.submitChoice(
      matchId: widget.matchId,
      turnType: turnType,
      choice: choice,
    );

    // If submission failed (network error or server refusal), unlock submission state
    if (res == null) {
      if (mounted) {
        setState(() {
          _hasSubmittedThisTurn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit choice. Please check connection and try again.'),
            backgroundColor: GameColors.wicket,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Any resolution (toss, ball_resolved, innings_break, match_finished) fetches immediately
    if (res['status'] != 'waiting_for_opponent') {
      await _fetchLatestState();
    }
  }

  Future<void> _handleRoleSelection(CricketRole role) async {
    HapticsUtil.mediumTap();
    await _repo.selectRole(
      matchId: widget.matchId,
      role: role.name,
    );
    await _fetchLatestState();
  }

  Future<void> _handleStartSecondInnings() async {
    HapticsUtil.mediumTap();
    await _repo.startSecondInnings(widget.matchId);
    await _fetchLatestState();
  }

  Future<void> _handleRematch() async {
    HapticsUtil.mediumTap();
    final res = await _repo.requestRematch(widget.matchId);
    if (res != null && res['match_id'] != null) {
      final newMatchId = res['match_id'] as String;
      _syncTimer?.cancel();
      if (mounted) {
        context.go('/online-play/$newMatchId');
      }
    }
  }

  Future<void> _handleClaimTimeout() async {
    final match = _match;
    if (match == null) return;
    final opponent = match.getOpponentOf(_currentUserId ?? match.player1.id);
    await _repo.claimTimeout(
      matchId: widget.matchId,
      timedOutUserId: opponent.id,
    );
    await _fetchLatestState();
  }

  Future<void> _handleForfeit() async {
    await _repo.forfeitMatch(widget.matchId);
    await _fetchLatestState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: GameColors.background,
        body: Center(
          child: CircularProgressIndicator(color: GameColors.lime),
        ),
      );
    }

    if (_match == null) {
      return Scaffold(
        backgroundColor: GameColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GameColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: GameColors.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: GameColors.wicket, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'MATCH UNAVAILABLE',
                    style: GameTypography.headlineMedium.copyWith(color: GameColors.wicket),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Unable to connect to match.',
                    textAlign: TextAlign.center,
                    style: GameTypography.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/online-lobby'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.lime,
                      foregroundColor: GameColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('BACK TO LOBBY', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final match = _match!;
    final isFinished = match.phase == MatchPhase.matchFinished ||
        match.phase == MatchPhase.seriesFinished ||
        match.phase == MatchPhase.matchForfeited;

    if (isFinished && !_showBallOutcome) {
      return _buildResultsScreen(match);
    }

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRealtimeConnected ? GameColors.lime : GameColors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isRealtimeConnected ? 'LIVE MULTIPLAYER' : 'SYNCING DUEL',
              style: GameTypography.headlineMedium,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: GameColors.textMuted),
            tooltip: 'Forfeit match',
            onPressed: () => _confirmForfeit(context),
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
                      _buildPlayerHeader(match),
                      Expanded(child: _buildPhaseContent(context, match)),
                    ],
                  ),

                  // Authoritative Ball Outcome Overlay
                  if (_showBallOutcome && (match.lastBallEvent != null || match.ballHistory.isNotEmpty)) ...[
                    () {
                      final latestBall = match.lastBallEvent ?? match.ballHistory.last;
                      return Container(
                        color: Colors.black.withValues(alpha: 0.8),
                        child: BallOutcomeDialog(
                          ballEvent: latestBall,
                          batterName: match.getPlayerById(latestBall.batterId).name,
                          bowlerName: match.getPlayerById(latestBall.bowlerId).name,
                          onDismiss: () {
                            setState(() {
                              _showBallOutcome = false;
                            });
                          },
                        ),
                      );
                    }(),
                  ],
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
                ? (match.currentBatterId == match.player1.id ? CricketRole.bat : CricketRole.bowl)
                : null,
            seriesTarget: match.config.seriesTargetPoints,
          ),
          PlayerIdentityBadge(
            player: match.player2,
            isPlayer1: false,
            activeRole: match.phase.isInningsActive
                ? (match.currentBatterId == match.player2.id ? CricketRole.bat : CricketRole.bowl)
                : null,
            seriesTarget: match.config.seriesTargetPoints,
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context, GameMatchState match) {
    switch (match.phase) {
      case MatchPhase.tossInput:
        return _buildTossPhase(match);
      case MatchPhase.roleSelection:
        return _buildRoleSelectionPhase(match);
      case MatchPhase.firstInnings:
      case MatchPhase.secondInnings:
        return _buildActiveInningsPhase(match);
      case MatchPhase.inningsBreak:
        return _buildInningsBreakPhase(match);
      default:
        return const Center(child: CircularProgressIndicator(color: GameColors.lime));
    }
  }

  Widget _buildTossPhase(GameMatchState match) {
    return Column(
      children: [
        const Spacer(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GameColors.glassBorder),
          ),
          child: Column(
            children: [
              const Icon(Icons.change_circle_outlined, size: 48, color: GameColors.lime),
              const SizedBox(height: 12),
              Text('SIMULTANEOUS TOSS', style: GameTypography.headlineMedium.copyWith(color: GameColors.lime)),
              const SizedBox(height: 10),
              AnimatedCoinToss(
                outcome: match.player1.id == _currentUserId ? match.player1.parity : match.player2.parity,
                size: 76,
              ),
              const SizedBox(height: 10),
              Text(
                _hasSubmittedThisTurn
                    ? 'Toss choice submitted! Waiting for opponent...'
                    : 'Select your secret toss number (1 - ${match.config.maxChoice})',
                textAlign: TextAlign.center,
                style: GameTypography.bodyMedium,
              ),
              if (_hasSubmittedThisTurn) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: GameColors.lime),
              ],
            ],
          ),
        ),
        const Spacer(),

        CountdownTimerBar(
          key: ValueKey('toss_timer_${match.phase.name}'),
          totalSeconds: match.config.decisionTimerSeconds,
          onTimeout: _handleClaimTimeout,
        ),
        const SizedBox(height: 12),

        if (!_hasSubmittedThisTurn)
          NumberPad(
            selectedNumber: _stagedNumber,
            maxNumber: match.config.maxChoice,
            autoModeEnabled: match.config.autoModeEnabled,
            onAutoPick: () {
              setState(() => _stagedNumber = (1 + (DateTime.now().millisecond % match.config.maxChoice)));
            },
            onNumberSelected: (v) => setState(() => _stagedNumber = v),
            onConfirm: () {
              if (_stagedNumber != null) {
                _handleSubmitChoice(_stagedNumber!);
              }
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRoleSelectionPhase(GameMatchState match) {
    final isWinner = match.tossWinnerId == _currentUserId;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GameColors.lime),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, size: 52, color: GameColors.gold),
              const SizedBox(height: 16),
              Text(
                isWinner ? 'YOU WON THE TOSS!' : 'OPPONENT WON THE TOSS',
                textAlign: TextAlign.center,
                style: GameTypography.headlineMedium.copyWith(color: GameColors.gold),
              ),
              const SizedBox(height: 12),
              Text(
                isWinner
                    ? 'Choose your role for the 1st Innings:'
                    : 'Waiting for toss winner to choose Bat or Bowl...',
                textAlign: TextAlign.center,
                style: GameTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (isWinner)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleRoleSelection(CricketRole.bat),
                        icon: const Icon(Icons.sports_cricket),
                        label: const Text('BAT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameColors.lime,
                          foregroundColor: GameColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleRoleSelection(CricketRole.bowl),
                        icon: const Icon(Icons.sports_baseball),
                        label: const Text('BOWL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameColors.surfaceElevated,
                          foregroundColor: GameColors.textPrimary,
                          side: const BorderSide(color: GameColors.glassBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                )
              else
                const CircularProgressIndicator(color: GameColors.lime),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveInningsPhase(GameMatchState match) {
    final isBatter = match.currentBatterId == _currentUserId;

    return Column(
      children: [
        ScoreboardCard(matchState: match),
        BallHistoryStrip(balls: match.ballHistory),
        const Spacer(),

        // Role indicator with arcade gradient
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            gradient: isBatter
                ? const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF047857)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF78350F), Color(0xFF92400E)],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBatter ? GameColors.mint : GameColors.goldBright,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isBatter ? GameColors.emerald : GameColors.gold).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBatter ? Icons.sports_cricket : Icons.sports_baseball,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                isBatter ? 'YOU ARE BATTING (Score Runs)' : 'YOU ARE BOWLING (Seek Wicket)',
                style: GameTypography.caption.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        if (_hasSubmittedThisTurn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: GameColors.surfaceGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: GameColors.cyan.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.cyan.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: GameColors.cyanBright,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Choice submitted. Waiting for opponent...',
                    style: GameTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Authoritative resolution in progress',
                    style: GameTypography.caption.copyWith(color: GameColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else ...[
          CountdownTimerBar(
            key: ValueKey('innings_${match.currentInningsNo}_ball_${match.legalBallsBowled}'),
            totalSeconds: match.config.decisionTimerSeconds,
            onTimeout: _handleClaimTimeout,
          ),
          const SizedBox(height: 8),
          NumberPad(
            selectedNumber: _stagedNumber,
            maxNumber: match.config.maxChoice,
            autoModeEnabled: match.config.autoModeEnabled,
            onAutoPick: () {
              setState(() => _stagedNumber = (1 + (DateTime.now().millisecond % match.config.maxChoice)));
            },
            onNumberSelected: (v) => setState(() => _stagedNumber = v),
            onConfirm: () {
              if (_stagedNumber != null) {
                _handleSubmitChoice(_stagedNumber!);
              }
            },
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInningsBreakPhase(GameMatchState match) {
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
              Text('1ST INNINGS COMPLETED!', style: GameTypography.headlineMedium.copyWith(color: GameColors.gold)),
              const SizedBox(height: 12),
              Text(
                '1st Innings Score: ${match.firstInningsRuns} runs',
                style: GameTypography.bodyLarge,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: GameColors.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('TARGET: ${match.targetRuns} RUNS', style: GameTypography.displayMedium.copyWith(fontSize: 22, color: GameColors.lime)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleStartSecondInnings,
                style: ElevatedButton.styleFrom(backgroundColor: GameColors.lime),
                child: const Text('START 2ND INNINGS', style: TextStyle(color: GameColors.background, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen(GameMatchState match) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: MatchResultView(
        match: match,
        currentUserId: _currentUserId,
        onRematch: _handleRematch,
        onHome: () => context.go('/'),
      ),
    );
  }

  void _confirmForfeit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        title: const Text('Forfeit Match?'),
        content: const Text('Leaving or forfeiting now will award the match win to your opponent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: GameColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleForfeit();
            },
            style: ElevatedButton.styleFrom(backgroundColor: GameColors.wicket),
            child: const Text('Forfeit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
