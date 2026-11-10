import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/domain/ai/progressive_ai_engine.dart';
import '../../../game/domain/ai/ranked_ai_tier.dart';
import '../../../game/domain/engine/odd_or_even_engine.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/game_match_state.dart';
import '../../../game/domain/models/match_config.dart';
import '../../../game/domain/models/player_info.dart';
import '../../../history/data/match_history_repository.dart';
import '../../data/local_progression_repo.dart';
import '../../domain/logic/rank_calculator.dart';
import '../../domain/logic/xp_calculator.dart';
import '../../domain/models/career_stats.dart';
import '../../domain/models/rank_tier.dart';
import '../../domain/models/xp_progress.dart';

class VsComputerRankedState {
  final GameMatchState match;
  final VsComputerRankState rankState;
  final XpProgress xpProgress;
  final ModeCareerStats careerStats;
  final RankedAiTier aiTier;
  final bool isAiThinking;
  final bool showBallOutcomeOverlay;
  final bool isSettled;
  final RankTransitionResult? transitionResult;
  final XpCalculationResult? xpResult;
  final bool showPromotionDialog;
  final bool showDemotionDialog;
  final String humanPlayerId;
  final String computerPlayerId;

  const VsComputerRankedState({
    required this.match,
    required this.rankState,
    required this.xpProgress,
    required this.careerStats,
    required this.aiTier,
    this.isAiThinking = false,
    this.showBallOutcomeOverlay = false,
    this.isSettled = false,
    this.transitionResult,
    this.xpResult,
    this.showPromotionDialog = false,
    this.showDemotionDialog = false,
    this.humanPlayerId = 'human',
    this.computerPlayerId = 'computer',
  });

  VsComputerRankedState copyWith({
    GameMatchState? match,
    VsComputerRankState? rankState,
    XpProgress? xpProgress,
    ModeCareerStats? careerStats,
    RankedAiTier? aiTier,
    bool? isAiThinking,
    bool? showBallOutcomeOverlay,
    bool? isSettled,
    RankTransitionResult? transitionResult,
    XpCalculationResult? xpResult,
    bool? showPromotionDialog,
    bool? showDemotionDialog,
    String? humanPlayerId,
    String? computerPlayerId,
  }) {
    return VsComputerRankedState(
      match: match ?? this.match,
      rankState: rankState ?? this.rankState,
      xpProgress: xpProgress ?? this.xpProgress,
      careerStats: careerStats ?? this.careerStats,
      aiTier: aiTier ?? this.aiTier,
      isAiThinking: isAiThinking ?? this.isAiThinking,
      showBallOutcomeOverlay: showBallOutcomeOverlay ?? this.showBallOutcomeOverlay,
      isSettled: isSettled ?? this.isSettled,
      transitionResult: transitionResult ?? this.transitionResult,
      xpResult: xpResult ?? this.xpResult,
      showPromotionDialog: showPromotionDialog ?? this.showPromotionDialog,
      showDemotionDialog: showDemotionDialog ?? this.showDemotionDialog,
      humanPlayerId: humanPlayerId ?? this.humanPlayerId,
      computerPlayerId: computerPlayerId ?? this.computerPlayerId,
    );
  }
}

class VsComputerRankedNotifier extends StateNotifier<VsComputerRankedState> {
  final LocalProgressionRepository _progressionRepo;
  final MatchHistoryRepository _historyRepo;

  VsComputerRankedNotifier(this._progressionRepo, this._historyRepo)
      : super(
          VsComputerRankedState(
            match: OddOrEvenEngine.initializeMatch(
              config: const MatchConfig(maxChoice: 6),
              player1: const PlayerInfo(id: 'human', name: 'Player'),
              player2: const PlayerInfo(id: 'computer', name: 'Computer (Bronze AI)'),
            ),
            rankState: VsComputerRankState.initial(),
            xpProgress: XpEconomy.calculateProgress(0),
            careerStats: const ModeCareerStats(),
            aiTier: RankedAiTier.bronze,
          ),
        ) {
    loadInitialData();
  }

  /// Loads persisted offline progression state, XP progress, and career stats.
  Future<void> loadInitialData() async {
    final rank = await _progressionRepo.getVsComputerRankState();
    final xpProg = await _progressionRepo.getXpProgress();
    final stats = await _progressionRepo.getModeStats('vs_computer_ranked');
    final tierAi = RankedAiTier.fromRankTier(rank.tier);

    state = state.copyWith(
      rankState: rank,
      xpProgress: xpProg,
      careerStats: stats,
      aiTier: tierAi,
    );
  }

  /// Starts a fresh ranked match against the progressive AI corresponding to the player's rank.
  void startNewRankedMatch({
    required MatchConfig config,
    required String humanName,
  }) {
    final human = PlayerInfo(
      id: state.humanPlayerId,
      name: humanName.trim().isEmpty ? 'Player' : humanName.trim(),
    );

    final aiTitle = state.aiTier.title;
    final computer = PlayerInfo(
      id: state.computerPlayerId,
      name: 'Computer ($aiTitle)',
    );

    final initialMatch = OddOrEvenEngine.initializeMatch(
      config: config,
      player1: human,
      player2: computer,
    );

    state = state.copyWith(
      match: initialMatch,
      isSettled: false,
      transitionResult: null,
      xpResult: null,
      showPromotionDialog: false,
      showDemotionDialog: false,
      showBallOutcomeOverlay: false,
    );
  }

  /// Submits the human's toss number, prompts blind AI pick, and resolves toss.
  void submitTossChoice(int humanChoice) {
    if (state.match.phase != MatchPhase.tossInput) return;

    final aiChoice = ProgressiveAiEngine.generateTossChoiceForRank(
      maxChoice: state.match.config.maxChoice,
      rankTier: state.rankState.tier,
    );

    var resolvedMatch = OddOrEvenEngine.resolveToss(
      state: state.match,
      player1Choice: humanChoice,
      player2Choice: aiChoice,
    );

    // If Computer won the toss, AI chooses role immediately
    if (resolvedMatch.tossWinnerId == state.computerPlayerId) {
      final aiRole = ProgressiveAiEngine.selectCricketRoleForRank(
        rankTier: state.rankState.tier,
      );
      resolvedMatch = OddOrEvenEngine.selectRole(
        state: resolvedMatch,
        choosingPlayerId: state.computerPlayerId,
        chosenRole: aiRole,
      );
    }

    state = state.copyWith(match: resolvedMatch);
  }

  /// Human toss winner selects Bat or Bowl.
  void selectCricketRole(CricketRole role) {
    if (state.match.phase != MatchPhase.roleSelection) return;
    if (state.match.tossWinnerId != state.humanPlayerId) return;

    final updatedMatch = OddOrEvenEngine.selectRole(
      state: state.match,
      choosingPlayerId: state.humanPlayerId,
      chosenRole: role,
    );

    state = state.copyWith(match: updatedMatch);
  }

  /// Submits human ball number, generates blind AI pick, and resolves the ball.
  void submitBallChoice(int humanChoice) {
    if (!state.match.phase.isInningsActive) return;

    final isHumanBatter = state.match.currentBatterId == state.humanPlayerId;
    final aiRole = isHumanBatter ? CricketRole.bowl : CricketRole.bat;

    // CRITICAL: Progressive AI generates choice strictly from public match state!
    final aiChoice = ProgressiveAiEngine.generateBallChoiceForRank(
      rankTier: state.rankState.tier,
      aiRole: aiRole,
      maxChoice: state.match.config.maxChoice,
      currentInningsNo: state.match.currentInningsNo,
      currentInningsRuns: state.match.currentInningsRuns,
      targetRuns: state.match.targetRuns,
      ballHistory: state.match.ballHistory,
      humanPlayerId: state.humanPlayerId,
    );

    final batterChoice = isHumanBatter ? humanChoice : aiChoice;
    final bowlerChoice = isHumanBatter ? aiChoice : humanChoice;

    final updatedMatch = OddOrEvenEngine.resolveBall(
      state: state.match,
      batterChoice: batterChoice,
      bowlerChoice: bowlerChoice,
    );

    state = state.copyWith(
      match: updatedMatch,
      showBallOutcomeOverlay: true,
    );

    // If match ended, settle rewards atomically!
    if (updatedMatch.phase == MatchPhase.matchFinished ||
        updatedMatch.phase == MatchPhase.seriesFinished) {
      _settleRankedMatch(updatedMatch);
    }
  }

  /// Atomically settles match results, stars, XP, career stats, and persistence.
  Future<void> _settleRankedMatch(GameMatchState completedMatch) async {
    // Idempotency guard: prevent duplicate settlements
    if (state.isSettled) return;
    state = state.copyWith(isSettled: true);

    final bool isWin = completedMatch.winnerId == state.humanPlayerId;
    final bool isTie = completedMatch.resultType == MatchResultType.tie;
    final MatchOutcome outcome = isWin
        ? MatchOutcome.win
        : (isTie ? MatchOutcome.tie : MatchOutcome.loss);

    // 1. Calculate Rank Transition
    final rankTransition = RankCalculator.computeTransition(
      current: state.rankState,
      outcome: outcome,
    );

    // 2. Calculate XP
    final currentDailyXp = await _progressionRepo.getDailyXpEarned();
    final xpCalculation = XpCalculator.computeMatchXp(
      currentTotalXp: state.xpProgress.totalXp,
      isWin: isWin,
      isTie: isTie,
      legalBallsBowled: completedMatch.ballHistory.length,
      isPassAndPlay: false,
      isPromotion: rankTransition.isDivisionPromotion || rankTransition.isTierPromotion,
      dailyXpAccumulatedSoFar: currentDailyXp,
    );

    // 3. Update Career Stats
    int humanRuns = 0;
    int humanWickets = 0;
    for (final ball in completedMatch.ballHistory) {
      if (ball.batterId == state.humanPlayerId) {
        humanRuns += ball.runsScored;
      }
      if (ball.bowlerId == state.humanPlayerId && ball.isWicket) {
        humanWickets += 1;
      }
    }
    final wasChasing = completedMatch.battingFirstId != state.humanPlayerId;

    final updatedCareerStats = state.careerStats.recordMatch(
      isWin: isWin,
      isTie: isTie,
      runsScored: humanRuns,
      wicketsTaken: humanWickets,
      wasChasing: wasChasing,
      target: completedMatch.targetRuns,
    );

    // 4. Persist to Secure Storage
    await _progressionRepo.saveVsComputerRankState(rankTransition.newState);
    if (xpCalculation.totalXpAwarded > 0) {
      await _progressionRepo.addLocalXp(xpCalculation.totalXpAwarded);
    }
    await _progressionRepo.saveModeStats('vs_computer_ranked', updatedCareerStats);
    await _historyRepo.saveMatchRecord(completedMatch);

    // 5. Update Local State & Check Dialog Triggers
    final newAiTier = RankedAiTier.fromRankTier(rankTransition.newState.tier);
    final bool showPromo = rankTransition.isDivisionPromotion || rankTransition.isTierPromotion;
    final bool showDemo = rankTransition.isDemotion || rankTransition.shieldSaved;

    state = state.copyWith(
      rankState: rankTransition.newState,
      xpProgress: xpCalculation.newProgress,
      careerStats: updatedCareerStats,
      aiTier: newAiTier,
      transitionResult: rankTransition,
      xpResult: xpCalculation,
      showPromotionDialog: showPromo,
      showDemotionDialog: showDemo,
    );
  }

  void dismissPromotionDialog() {
    state = state.copyWith(showPromotionDialog: false);
  }

  void dismissDemotionDialog() {
    state = state.copyWith(showDemotionDialog: false);
  }

  void dismissBallOutcome() {
    state = state.copyWith(showBallOutcomeOverlay: false);
  }

  void startSecondInnings() {
    if (state.match.phase != MatchPhase.inningsBreak) return;
    final updatedMatch = OddOrEvenEngine.startSecondInnings(state.match);
    state = state.copyWith(match: updatedMatch);
  }

  void handleTimeout() {
    final updatedMatch = OddOrEvenEngine.handleTimeout(
      state: state.match,
      timedOutPlayerId: state.humanPlayerId,
    );
    state = state.copyWith(match: updatedMatch);
    if (updatedMatch.phase == MatchPhase.matchFinished ||
        updatedMatch.phase == MatchPhase.seriesFinished) {
      _settleRankedMatch(updatedMatch);
    }
  }

  int generateAutoNumber() {
    return Random().nextInt(state.match.config.maxChoice) + 1;
  }

  void requestRematch() {
    final rematch = OddOrEvenEngine.initializeRematch(previousState: state.match);
    state = state.copyWith(
      match: rematch,
      isSettled: false,
      transitionResult: null,
      xpResult: null,
      showPromotionDialog: false,
      showDemotionDialog: false,
      showBallOutcomeOverlay: false,
    );
  }
}

/// Riverpod Provider for VS Computer Ranked mode.
final vsComputerRankedGameProvider =
    StateNotifierProvider<VsComputerRankedNotifier, VsComputerRankedState>((ref) {
  final progressionRepo = ref.watch(localProgressionRepositoryProvider);
  final historyRepo = ref.watch(matchHistoryRepositoryProvider);
  return VsComputerRankedNotifier(progressionRepo, historyRepo);
});
