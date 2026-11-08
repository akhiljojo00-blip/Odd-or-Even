import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../game/domain/ai/computer_player_strategy.dart';
import '../../../game/domain/engine/odd_or_even_engine.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/game_match_state.dart';
import '../../../game/domain/models/match_config.dart';
import '../../../game/domain/models/player_info.dart';
import '../../../history/data/match_history_repository.dart';

class VsComputerGameState {
  final GameMatchState match;
  final AiDifficulty difficulty;
  final bool isAiThinking;
  final bool showBallOutcomeOverlay;
  final String humanPlayerId;
  final String computerPlayerId;

  const VsComputerGameState({
    required this.match,
    this.difficulty = AiDifficulty.medium,
    this.isAiThinking = false,
    this.showBallOutcomeOverlay = false,
    this.humanPlayerId = 'human',
    this.computerPlayerId = 'computer',
  });

  VsComputerGameState copyWith({
    GameMatchState? match,
    AiDifficulty? difficulty,
    bool? isAiThinking,
    bool? showBallOutcomeOverlay,
    String? humanPlayerId,
    String? computerPlayerId,
  }) {
    return VsComputerGameState(
      match: match ?? this.match,
      difficulty: difficulty ?? this.difficulty,
      isAiThinking: isAiThinking ?? this.isAiThinking,
      showBallOutcomeOverlay: showBallOutcomeOverlay ?? this.showBallOutcomeOverlay,
      humanPlayerId: humanPlayerId ?? this.humanPlayerId,
      computerPlayerId: computerPlayerId ?? this.computerPlayerId,
    );
  }
}

class VsComputerGameNotifier extends StateNotifier<VsComputerGameState> {
  final MatchHistoryRepository _historyRepo;

  VsComputerGameNotifier(this._historyRepo)
      : super(
          VsComputerGameState(
            match: OddOrEvenEngine.initializeMatch(
              config: const MatchConfig(maxChoice: 6),
              player1: const PlayerInfo(id: 'human', name: 'You'),
              player2: const PlayerInfo(id: 'computer', name: 'Computer (Medium)'),
            ),
          ),
        );

  /// Initializes a new single-player match against the local computer.
  void startNewGame({
    required MatchConfig config,
    required AiDifficulty difficulty,
    required String humanName,
  }) {
    final human = PlayerInfo(
      id: 'human',
      name: humanName.trim().isEmpty ? 'You' : humanName.trim(),
    );
    final computer = PlayerInfo(
      id: 'computer',
      name: 'Computer (${difficulty.label})',
    );

    final initialMatch = OddOrEvenEngine.initializeMatch(
      config: config,
      player1: human,
      player2: computer,
    );

    state = VsComputerGameState(
      match: initialMatch,
      difficulty: difficulty,
    );
  }

  /// Submits the human's toss number, prompts AI toss pick, and resolves toss.
  void submitTossChoice(int humanChoice) {
    if (state.match.phase != MatchPhase.tossInput) return;

    // AI independently selects its toss number
    final aiChoice = ComputerPlayerStrategy.generateTossChoice(
      maxChoice: state.match.config.maxChoice,
      difficulty: state.difficulty,
    );

    var resolvedMatch = OddOrEvenEngine.resolveToss(
      state: state.match,
      player1Choice: humanChoice,
      player2Choice: aiChoice,
    );

    // If Computer won the toss, AI automatically picks role immediately
    if (resolvedMatch.tossWinnerId == state.computerPlayerId) {
      final aiRole = ComputerPlayerStrategy.selectCricketRole(
        difficulty: state.difficulty,
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

    // CRITICAL: AI generates choice strictly from public state, NEVER accessing humanChoice!
    final aiChoice = ComputerPlayerStrategy.generateBallChoice(
      difficulty: state.difficulty,
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

    // Automatically persist completed match to local history
    if (updatedMatch.phase == MatchPhase.matchFinished ||
        updatedMatch.phase == MatchPhase.seriesFinished) {
      _historyRepo.saveMatchRecord(updatedMatch);
    }
  }

  /// Dismisses ball outcome dialog.
  void dismissBallOutcome() {
    state = state.copyWith(showBallOutcomeOverlay: false);
  }

  /// Advances from innings break to second innings.
  void startSecondInnings() {
    if (state.match.phase != MatchPhase.inningsBreak) return;
    final updatedMatch = OddOrEvenEngine.startSecondInnings(state.match);
    state = state.copyWith(match: updatedMatch);
  }

  /// Handles timer expiration when the human player fails to pick in time.
  void handleTimeout() {
    final updatedMatch = OddOrEvenEngine.handleTimeout(
      state: state.match,
      timedOutPlayerId: state.humanPlayerId,
    );
    state = state.copyWith(match: updatedMatch);
  }

  /// Automatically picks a random valid number for auto mode.
  int generateAutoNumber() {
    return Random().nextInt(state.match.config.maxChoice) + 1;
  }

  /// Starts a fresh rematch match keeping cumulative series score.
  void requestRematch() {
    final rematch = OddOrEvenEngine.initializeRematch(previousState: state.match);
    state = state.copyWith(
      match: rematch,
      showBallOutcomeOverlay: false,
    );
  }
}

final vsComputerGameProvider =
    StateNotifierProvider<VsComputerGameNotifier, VsComputerGameState>((ref) {
  final historyRepo = ref.watch(matchHistoryRepositoryProvider);
  return VsComputerGameNotifier(historyRepo);
});
