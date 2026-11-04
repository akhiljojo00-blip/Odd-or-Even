import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/game_match_state.dart';
import '../../../game/presentation/widgets/ball_history_strip.dart';
import '../../../game/presentation/widgets/ball_outcome_dialog.dart';
import '../../../game/presentation/widgets/countdown_timer_bar.dart';
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
  Timer? _syncTimer;
  GameMatchState? _match;
  bool _isLoading = true;
  bool _hasSubmittedThisTurn = false;
  int? _stagedNumber;
  bool _showBallOutcome = false;
  int _lastResolvedBallCount = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initMatch();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initMatch() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    _currentUserId = repo.currentUserId ?? await repo.ensureAuthenticatedUser();

    await _fetchLatestState();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchLatestState());
  }

  Future<void> _fetchLatestState() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    final match = await repo.getMatch(widget.matchId);
    if (!mounted || match == null) return;

    // Check if new ball was resolved
    if (match.ballHistory.length > _lastResolvedBallCount) {
      _lastResolvedBallCount = match.ballHistory.length;
      setState(() {
        _showBallOutcome = true;
        _hasSubmittedThisTurn = false;
        _stagedNumber = null;
      });
      HapticsUtil.heavyImpact();
    }

    setState(() {
      _match = match;
      _isLoading = false;
    });
  }

  Future<void> _handleSubmitChoice(int choice) async {
    final match = _match;
    if (match == null || _hasSubmittedThisTurn) return;

    final repo = ref.read(supabaseMatchRepositoryProvider);
    final turnType = match.phase == MatchPhase.tossInput ? 'toss' : 'ball';

    setState(() {
      _hasSubmittedThisTurn = true;
      _stagedNumber = choice;
    });
    HapticsUtil.mediumTap();

    final res = await repo.submitChoice(
      matchId: widget.matchId,
      turnType: turnType,
      choice: choice,
    );

    if (res != null && res['status'] == 'resolved') {
      await _fetchLatestState();
    }
  }

  Future<void> _handleRoleSelection(CricketRole role) async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    HapticsUtil.mediumTap();
    await repo.selectRole(
      matchId: widget.matchId,
      role: role.name,
    );
    await _fetchLatestState();
  }

  Future<void> _handleStartSecondInnings() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    HapticsUtil.mediumTap();
    await repo.startSecondInnings(widget.matchId);
    await _fetchLatestState();
  }

  Future<void> _handleRematch() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    HapticsUtil.mediumTap();
    final res = await repo.requestRematch(widget.matchId);
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
    final repo = ref.read(supabaseMatchRepositoryProvider);
    await repo.claimTimeout(
      matchId: widget.matchId,
      timedOutUserId: opponent.id,
    );
    await _fetchLatestState();
  }

  Future<void> _handleForfeit() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    await repo.forfeitMatch(widget.matchId);
    await _fetchLatestState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _match == null) {
      return const Scaffold(
        backgroundColor: GameColors.background,
        body: Center(
          child: CircularProgressIndicator(color: GameColors.lime),
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
        title: Text('LIVE MULTIPLAYER', style: GameTypography.headlineMedium),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: GameColors.textMuted),
            tooltip: 'Forfeit match',
            onPressed: () => _confirmForfeit(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildPlayerHeader(match),
                Expanded(child: _buildPhaseContent(context, match)),
              ],
            ),

            // Ball Outcome Overlay
            if (_showBallOutcome && match.ballHistory.isNotEmpty)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: BallOutcomeDialog(
                  ballEvent: match.ballHistory.last,
                  batterName: match.getPlayerById(match.ballHistory.last.batterId).name,
                  bowlerName: match.getPlayerById(match.ballHistory.last.bowlerId).name,
                  onDismiss: () {
                    setState(() {
                      _showBallOutcome = false;
                    });
                  },
                ),
              ),
          ],
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
              const SizedBox(height: 6),
              Text(
                _hasSubmittedThisTurn
                    ? 'Toss choice submitted! Waiting for opponent...'
                    : 'Select your secret toss number (1 - 10)',
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
          totalSeconds: match.config.decisionTimerSeconds,
          onTimeout: _handleClaimTimeout,
        ),
        const SizedBox(height: 12),

        if (!_hasSubmittedThisTurn)
          NumberPad(
            selectedNumber: _stagedNumber,
            autoModeEnabled: match.config.autoModeEnabled,
            onAutoPick: () {
              setState(() => _stagedNumber = (1 + (DateTime.now().millisecond % 10)));
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

        // Role indicator
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isBatter ? GameColors.lime.withOpacity(0.15) : GameColors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isBatter ? GameColors.lime : GameColors.amber),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isBatter ? Icons.sports_cricket : Icons.sports_baseball,
                  size: 18, color: isBatter ? GameColors.lime : GameColors.amber),
              const SizedBox(width: 8),
              Text(
                isBatter ? 'YOU ARE BATTING (Score Runs)' : 'YOU ARE BOWLING (Seek Wicket)',
                style: GameTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isBatter ? GameColors.lime : GameColors.amber,
                ),
              ),
            ],
          ),
        ),

        if (_hasSubmittedThisTurn)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircularProgressIndicator(color: GameColors.lime),
                const SizedBox(height: 12),
                Text('Choice submitted. Waiting for opponent...', style: GameTypography.bodyMedium),
              ],
            ),
          )
        else ...[
          CountdownTimerBar(
            totalSeconds: match.config.decisionTimerSeconds,
            onTimeout: _handleClaimTimeout,
          ),
          const SizedBox(height: 8),
          NumberPad(
            selectedNumber: _stagedNumber,
            autoModeEnabled: match.config.autoModeEnabled,
            onAutoPick: () {
              setState(() => _stagedNumber = (1 + (DateTime.now().millisecond % 10)));
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
                  color: GameColors.lime.withOpacity(0.15),
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
    final isSeriesFinished = match.phase == MatchPhase.seriesFinished;
    final winner = match.winnerId != null ? match.getPlayerById(match.winnerId!) : null;
    final isMeWinner = winner?.id == _currentUserId;
    final isTie = match.resultType == MatchResultType.tie;

    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: (isMeWinner ? GameColors.gold : GameColors.surfaceElevated).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: isMeWinner ? GameColors.gold : GameColors.textMuted, width: 2),
                  ),
                  child: Icon(
                    isTie ? Icons.handshake_rounded : (isMeWinner ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded),
                    size: 48,
                    color: isMeWinner ? GameColors.gold : GameColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isTie ? 'MATCH TIED!' : (isMeWinner ? 'VICTORY!' : 'DEFEAT'),
                textAlign: TextAlign.center,
                style: GameTypography.displayLarge.copyWith(
                  color: isTie ? GameColors.textPrimary : (isMeWinner ? GameColors.gold : GameColors.textSecondary),
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                match.resultType?.description ?? 'Match Completed',
                textAlign: TextAlign.center,
                style: GameTypography.bodyMedium,
              ),
              const SizedBox(height: 28),

              // Scorecard summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GameColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GameColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('1ST INNINGS', style: GameTypography.caption),
                        const SizedBox(height: 4),
                        Text('${match.firstInningsRuns}', style: GameTypography.scoreNumber.copyWith(fontSize: 28)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: GameColors.glassBorder),
                    Column(
                      children: [
                        Text('2ND INNINGS', style: GameTypography.caption),
                        const SizedBox(height: 4),
                        Text('${match.currentInningsRuns}', style: GameTypography.scoreNumber.copyWith(fontSize: 28)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              if (!isSeriesFinished) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _handleRematch,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('REMATCH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.lime,
                      foregroundColor: GameColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GameColors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('RETURN TO MAIN MENU', style: GameTypography.headlineMedium.copyWith(fontSize: 15, color: GameColors.textPrimary)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
